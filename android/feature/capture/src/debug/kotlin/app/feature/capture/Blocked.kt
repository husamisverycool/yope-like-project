package app.feature.capture

import androidx.compose.ui.text.font.FontWeight

/**
 * DEBUG builds only: review values for elements whose token is BLOCKED (docs/SCREENS_BRIEF.md
 * rule 1), so the layout can be reviewed. The release source set defines every value as absent,
 * so release builds omit these elements. Each value names its token and how it was obtained.
 */
internal object Blocked {
    /**
     * `daily.capture.fontWeight.countdown` (BLOCKED). The token's closing step, done for Android:
     * Roboto '1' rendered per weight, stem ÷ digit height = Thin 0.036, Light 0.082, Regular
     * 0.128, Medium 0.164, Bold 0.198, Black 0.232; the reference ratio is 0.19–0.20 → Bold.
     * Pending promotion into design/tokens by the lead; release builds omit the countdown.
     */
    val countdownWeight: FontWeight? = FontWeight.Bold

    /**
     * `chat.voice.layout.recording` (BLOCKED): the voice-note recorder's presentation. Debug
     * builds show the mic so the voice-note flow (one note on every chosen group's post) can be
     * exercised; the mic draws no recording state. Release builds hide the mic and its coach.
     */
    const val voiceNoteRecorder: Boolean = true
}
