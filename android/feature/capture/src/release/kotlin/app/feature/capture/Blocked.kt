package app.feature.capture

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp

/**
 * Release builds: elements whose token is BLOCKED are omitted (docs/SCREENS_BRIEF.md rule 1).
 * The debug source set holds the review values and their provenance.
 */
internal object Blocked {
    /** `daily.capture.fontWeight.countdown` is BLOCKED: the countdown is not drawn. */
    val countdownWeight: FontWeight? = null

    /** `chat.voice.layout.recording` is BLOCKED: no voice-note recorder (mic and coach hidden). */
    const val voiceNoteRecorder: Boolean = false

    /** `camera.sendto.color.messageField` (BLOCKED): message field and mic circle drawn without a fill. */
    val messageFieldFill: Color? = null

    /** `daily.capture.color.overlayControl` (BLOCKED): retake circle and audience chip without a fill. */
    val overlayControlFill: Color? = null

    /** `collage.share.color.pill` (BLOCKED): the share pill without its frosted fill. */
    val sharePillFill: Color? = null

    /** `camera.capture.size.recordingOutline` (BLOCKED): no outline while recording. */
    val recordingOutline: Dp? = null

    /** `camera.sendto.duration.toastVisible` (BLOCKED): no "posted in …" / "saved" toast. */
    val toastVisibleMillis: Long? = null

    /** `camera.sendto.size.captionMaxLength` (BLOCKED): no UI limit (the server bound applies). */
    val captionMaxLength: Int? = null
}
