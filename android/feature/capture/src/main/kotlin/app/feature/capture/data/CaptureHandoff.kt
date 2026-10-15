package app.feature.capture.data

import android.content.Context
import app.data.model.MediaKind
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.io.File

/** A capture (or library pick) waiting to be sent from `camera.sendto`. */
data class CapturedMedia(
    val kind: MediaKind,
    val file: File,
    val width: Int?,
    val height: Int?,
    /** Video length (required for `video`). */
    val durationMs: Int?,
    val fromLibrary: Boolean,
)

/**
 * Hands the capture from `camera.capture` to `camera.sendto` (no mandatory edit step between them),
 * with the group the camera was opened for (`app://camera?group=`, group screen, chat).
 * Files live in [dir]; the upload queue copies them, so they are deleted after sending or ✕.
 */
class CaptureHandoff {
    /**
     * [replyToPostId]: a reply to a photo with a photo (`photo.viewer` → camera,
     * `SocialHandoff.REPLY_TO_POST_ID`): it goes to exactly the replied post's group.
     */
    data class Pending(val media: CapturedMedia, val contextGroupId: String?, val replyToPostId: String? = null)

    private val state = MutableStateFlow<Pending?>(null)
    val pending: StateFlow<Pending?> = state.asStateFlow()

    fun put(media: CapturedMedia, contextGroupId: String?, replyToPostId: String? = null) {
        state.value?.media?.file?.takeIf { it != media.file }?.delete()
        state.value = Pending(media, contextGroupId, replyToPostId)
    }

    /** Drops the capture and its file (✕ on send-to, or after it was queued). */
    fun discard() {
        state.value?.media?.file?.delete()
        state.value = null
    }

    /** Forgets the capture without deleting its file (the upload queue already copied it). */
    fun clear() {
        state.value = null
    }

    companion object {
        /** One per process: the camera and send-to destinations share it. */
        val process: CaptureHandoff = CaptureHandoff()

        fun dir(context: Context): File = File(context.cacheDir, "capture").apply { mkdirs() }
    }
}
