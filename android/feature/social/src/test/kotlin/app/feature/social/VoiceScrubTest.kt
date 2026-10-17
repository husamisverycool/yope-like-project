package app.feature.social

import app.feature.social.chat.VoiceScrub
import org.junit.Assert.assertEquals
import org.junit.Test

/** chat.voice — seeking a note by dragging along its waveform and by TalkBack steps (`chat.voice.layout.scrub`). */
class VoiceScrubTest {
    @Test
    fun dragAndStepPositions() {
        // The waveform starts 30 px in and is 154 px wide; right to left it ends 30 px before the trailing edge.
        assertEquals(30f, VoiceScrub.waveformMinX(250f, 30f, 154f, rightToLeft = false), 0f)
        assertEquals(66f, VoiceScrub.waveformMinX(250f, 30f, 154f, rightToLeft = true), 0f)
        assertEquals(0.5f, VoiceScrub.fraction(107f, 30f, 154f), 0.0001f)
        assertEquals(0f, VoiceScrub.fraction(0f, 30f, 154f), 0f)
        assertEquals(1f, VoiceScrub.fraction(400f, 30f, 154f), 0f)

        // 5-s steps on a 20-s note: a quarter each way, clamped to the note; unknown length: no move.
        assertEquals(0.75f, VoiceScrub.step(0.5f, 20_000, forward = true, stepMs = 5_000f), 0.0001f)
        assertEquals(0f, VoiceScrub.step(0.1f, 20_000, forward = false, stepMs = 5_000f), 0f)
        assertEquals(1f, VoiceScrub.step(0.9f, 20_000, forward = true, stepMs = 5_000f), 0f)
        assertEquals(0.3f, VoiceScrub.step(0.3f, 0, forward = true, stepMs = 5_000f), 0f)
    }
}
