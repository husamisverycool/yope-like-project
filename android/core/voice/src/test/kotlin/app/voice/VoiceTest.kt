package app.voice

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.shadows.ShadowLooper
import java.io.File

@RunWith(AndroidJUnit4::class)
class VoiceTest {
    private val context: Context = ApplicationProvider.getApplicationContext()

    @Test fun levelsAreNormalisedAmplitudes() {
        assertEquals(0f, Waveform.level(0))
        assertEquals(1f, Waveform.level(Waveform.MAX_AMPLITUDE))
        assertEquals(1f, Waveform.level(Int.MAX_VALUE))
        assertEquals(0f, Waveform.level(-5))
    }

    @Test fun barsResampleToAFixedCountUsingPeaks() {
        assertEquals(listOf(0.5f, 0.9f), Waveform.bars(listOf(0.1f, 0.5f, 0.9f, 0.2f), 2))
        assertEquals(listOf(0f, 0f, 0f), Waveform.bars(emptyList(), 3))
        val stretched = Waveform.bars(listOf(0.3f, 0.7f), 4)
        assertEquals(4, stretched.size)
        assertEquals(listOf(0.3f, 0.3f, 0.7f, 0.7f), stretched)
    }

    @Test fun recordingReportsDurationInMillisAndSamplesLevels() {
        var now = 1_000L
        val recorder = VoiceRecorder(context, clock = { now })
        val out = File(context.cacheDir, "voice/note.m4a")
        recorder.start(out, samplingIntervalMs = 50)
        assertTrue(recorder.isRecording)
        ShadowLooper.idleMainLooper()
        now += 2_345
        val note = recorder.stop()
        assertNotNull(note)
        assertEquals(2_345L, note!!.durationMs)
        assertTrue(note.waveform.isNotEmpty())
        assertFalse(recorder.isRecording)
        recorder.release()
    }

    @Test fun cancelDiscardsTheFile() {
        val recorder = VoiceRecorder(context)
        val out = File(context.cacheDir, "voice/cancel.m4a").apply { parentFile!!.mkdirs(); writeText("partial") }
        recorder.start(out, samplingIntervalMs = 50)
        recorder.cancel()
        assertFalse(out.exists())
        assertTrue(recorder.levels.value.isEmpty())
        recorder.release()
    }
}
