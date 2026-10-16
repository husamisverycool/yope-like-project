package app.voice

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.shadows.ShadowLooper
import java.io.File

/** A recorder without hardware: segments are files, time is a counter, the level a fixed peak. */
class FakeEngine : RecordingEngine {
    val log = ArrayList<String>()
    var openTimeMs = 0L
    var peak = 0.5f
    var refuseResume = false
    val deleted = ArrayList<File>()
    private var open: File? = null

    override fun startSegment(file: File) {
        file.parentFile?.mkdirs()
        file.writeText("segment")
        log += "start ${file.name}"
        open = file
        openTimeMs = 0L
    }

    override fun pauseSegment() { log += "pause" }

    override fun resumeSegment(): Boolean {
        log += if (refuseResume) "resume refused" else "resume"
        return !refuseResume
    }

    override fun stopSegment(): Long? {
        log += "stop"
        val ms = openTimeMs
        openTimeMs = 0L
        open = null
        return ms
    }

    override val segmentTimeMs: Long get() = if (open == null) 0L else openTimeMs
    override fun samplePeak(): Float = peak
    override fun deleteFile(file: File) {
        deleted += file
        file.delete()
    }
}

/** C-36 levels (Telegram's 100 five-bit values) and the recording state machine (owner decision 16). */
class VoiceLevelsTest {
    @Test fun amplitudesAreLinearLevels() {
        assertEquals(0f, VoiceLevels.level(0))
        assertEquals(1f, VoiceLevels.level(VoiceLevels.MAX_AMPLITUDE))
        assertEquals(1f, VoiceLevels.level(Int.MAX_VALUE))
        assertEquals(0f, VoiceLevels.level(-5))
    }

    @Test fun reduceKeepsOneHundredFiveBitValues() {
        val levels = VoiceLevels.reduce(List(333) { (it % 37) / 36f })
        assertEquals(100, levels.size)
        assertTrue(VoiceLevels.isValid(levels))
    }

    @Test fun reduceScalesToOnePointEightTimesTheMeanBucketPeak() {
        val peaks = MutableList(100) { 0.1f }
        peaks[10] = 0.9f
        peaks[60] = 0.9f
        val levels = VoiceLevels.reduce(peaks)
        assertEquals(31, levels[10])
        assertEquals(31, levels[60])
        // mean = (2 × 0.9 + 98 × 0.1) / 100 = 0.116; scale = 0.2088; 0.1 × 31 / 0.2088 = 14.8
        assertEquals(14, levels[0])
    }

    @Test fun silenceStaysLowAndEmptyIsSilence() {
        assertEquals(setOf(2), VoiceLevels.reduce(List(400) { 0.005f }).toSet())
        assertEquals(List(100) { 0 }, VoiceLevels.reduce(emptyList()))
        assertTrue(VoiceLevels.isValid(VoiceLevels.reduce(listOf(Float.NaN, -1f, 4f, Float.POSITIVE_INFINITY))))
    }

    @Test fun shortRecordingsRepeatSamplesAcrossBuckets() {
        val levels = VoiceLevels.reduce(listOf(0.05f, 0.5f, 0.05f, 0.9f))
        assertEquals(levels[0], levels[24])
        assertEquals(31, levels[75])
        assertTrue(levels[50] < levels[75])
    }

    @Test fun validity() {
        assertTrue(VoiceLevels.isValid(List(100) { 31 }))
        assertFalse(VoiceLevels.isValid(List(99) { 31 }))
        assertFalse(VoiceLevels.isValid(List(100) { 32 }))
        assertFalse(VoiceLevels.isValid(null))
    }
}

class RecordingSessionTest {
    private var counter = 0
    private fun session(engine: FakeEngine) = RecordingSession(engine) { File("/tmp/seg-${++counter}.m4a") }

    @Test fun pauseAndContinueUseThePlatformPauseOnOneSegment() {
        val engine = FakeEngine()
        val s = session(engine)
        s.start()
        engine.openTimeMs = 1200
        s.pause()
        assertEquals(RecordingSession.State.Paused, s.state)
        assertEquals(1200L, s.elapsedMs)
        s.resume()
        engine.openTimeMs = 3000
        val result = s.finish()
        assertEquals(listOf("start seg-1.m4a", "pause", "resume", "stop"), engine.log)
        assertEquals(listOf("seg-1.m4a"), result.segments.map { it.name })
        assertEquals(3000L, result.durationMs)
        assertEquals(RecordingSession.State.Idle, s.state)
    }

    @Test fun previewClosesTheSegmentAndContinuingStartsANewOne() {
        val engine = FakeEngine()
        val s = session(engine)
        s.start()
        engine.openTimeMs = 2000
        s.pause()
        assertEquals(listOf("seg-1.m4a"), s.finishDraft().map { it.name })
        assertEquals(1, s.finishDraft().size)
        s.resume()
        engine.openTimeMs = 1500
        assertEquals(3500L, s.elapsedMs)
        val result = s.finish()
        assertEquals(listOf("seg-1.m4a", "seg-2.m4a"), result.segments.map { it.name })
        assertEquals(3500L, result.durationMs)
        assertEquals(listOf("start seg-1.m4a", "pause", "stop", "start seg-2.m4a", "stop"), engine.log)
    }

    @Test fun aRefusedResumeStartsANewSegment() {
        val engine = FakeEngine()
        val s = session(engine)
        s.start()
        engine.openTimeMs = 800
        s.pause()
        engine.refuseResume = true
        s.resume()
        assertEquals(RecordingSession.State.Recording, s.state)
        assertEquals(listOf("start seg-1.m4a", "pause", "resume refused", "stop", "start seg-2.m4a"), engine.log)
        assertEquals(800L, s.elapsedMs)
    }

    @Test fun levelsAreSampledOnlyWhileRecording() {
        val engine = FakeEngine()
        val s = session(engine)
        s.sample()
        assertTrue(s.peaks.isEmpty())
        s.start()
        s.sample()
        s.sample()
        s.pause()
        s.sample()
        assertEquals(2, s.peaks.size)
        s.resume()
        engine.peak = 1f
        s.sample()
        assertEquals(listOf(0.5f, 0.5f, 1f), s.peaks)
        val result = s.finish()
        assertTrue(VoiceLevels.isValid(result.levels))
        assertEquals(12, result.levels.first())
        assertEquals(25, result.levels.last())
    }

    @Test fun cancelDeletesEverySegment() {
        val engine = FakeEngine()
        val s = session(engine)
        s.start()
        s.pause()
        s.finishDraft()
        s.resume()
        s.cancel()
        assertEquals(listOf("seg-1.m4a", "seg-2.m4a"), engine.deleted.map { it.name })
        assertEquals(RecordingSession.State.Idle, s.state)
        s.cancel()
        assertEquals(2, engine.deleted.size)
    }

    @Test fun invalidTransitionsThrow() {
        val s = session(FakeEngine())
        assertThrows { s.pause() }
        assertThrows { s.resume() }
        assertThrows { s.finish() }
        assertThrows { s.finishDraft() }
        s.start()
        assertThrows { s.start() }
        assertThrows { s.resume() }
        assertThrows { s.finishDraft() }
    }

    private fun assertThrows(block: () -> Unit) {
        val thrown = runCatching(block).exceptionOrNull()
        assertTrue("expected an exception", thrown is IllegalStateException)
    }
}

@RunWith(AndroidJUnit4::class)
class VoiceRecorderTest {
    private val context: Context = ApplicationProvider.getApplicationContext()

    private fun recorder(engine: FakeEngine, joined: MutableList<List<File>>) = VoiceRecorder(
        context,
        engine = engine,
        joiner = { segments, out ->
            joined += segments
            out.parentFile?.mkdirs()
            out.writeText("joined")
        },
        directory = File(context.cacheDir, "voice-test"),
    )

    @Test fun recordPauseContinueAndStopWithLevels() = runBlocking {
        val engine = FakeEngine()
        val joined = ArrayList<List<File>>()
        val r = recorder(engine, joined)
        r.start()
        assertTrue(r.isRecording)
        assertEquals(RecordingSession.State.Recording, r.state.value)
        ShadowLooper.idleMainLooper()
        engine.openTimeMs = 2_345
        r.pause()
        assertEquals(RecordingSession.State.Paused, r.state.value)
        assertEquals(2_345L, r.elapsedMs.value)
        assertEquals(100, r.levels.value.size, "the draft's waveform")
        r.resume()
        val note = r.stop()
        assertNotNull(note)
        assertEquals(2_345L, note!!.durationMs)
        assertTrue(VoiceLevels.isValid(note.levels))
        assertTrue(joined.isEmpty(), "one segment: nothing to join")
        assertFalse(r.isRecording)
        assertTrue(r.levels.value.isEmpty())
        r.release()
    }

    @Test fun aPreviewedAndContinuedDraftIsJoinedOnce() = runBlocking {
        val engine = FakeEngine()
        val joined = ArrayList<List<File>>()
        val r = recorder(engine, joined)
        r.start()
        engine.openTimeMs = 1_000
        r.pause()
        val first = r.draftFile()
        assertTrue(first.exists())
        assertTrue(joined.isEmpty(), "a one-segment draft plays as is")
        r.resume()
        engine.openTimeMs = 500
        r.pause()
        val draft = r.draftFile()
        assertEquals(1, joined.size, "two segments: joined for the preview")
        assertEquals(draft, r.draftFile(), "the same draft is not joined again")
        val note = r.stop()!!
        assertEquals(draft, note.file, "the joined draft is the note")
        assertEquals(1, joined.size)
        assertEquals(1_500L, note.durationMs)
        r.release()
    }

    @Test fun cancelDiscardsEverything() = runBlocking {
        val engine = FakeEngine()
        val r = recorder(engine, ArrayList())
        r.start()
        r.pause()
        val draft = r.draftFile()
        r.cancel()
        assertFalse(draft.exists())
        assertTrue(r.levels.value.isEmpty())
        assertNull(r.stop())
        r.release()
    }

    private fun assertEquals(expected: Any?, actual: Any?, message: String) = org.junit.Assert.assertEquals(message, expected, actual)
}
