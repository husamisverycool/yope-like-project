package app.feature.capture

import androidx.compose.ui.text.font.FontWeight

/**
 * Release builds: elements whose token is BLOCKED are omitted (docs/SCREENS_BRIEF.md rule 1).
 * The debug source set holds the review values and their provenance.
 */
internal object Blocked {
    /** `daily.capture.fontWeight.countdown` is BLOCKED: the countdown is not drawn. */
    val countdownWeight: FontWeight? = null

    /** `chat.voice.layout.recording` is BLOCKED: no voice-note recorder (mic and coach hidden). */
    const val voiceNoteRecorder: Boolean = false
}
