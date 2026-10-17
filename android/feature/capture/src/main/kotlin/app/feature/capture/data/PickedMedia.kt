package app.feature.capture.data

import android.content.Context
import android.net.Uri
import app.data.model.MediaKind
import app.media.ImageEncoder
import java.io.File
import java.time.LocalDate

/**
 * A photo or video picked in the system Photo Picker (`camera.capture` → library) or shared from another app
 * (`share.in`), copied into the capture directory, with the day it was taken ([TakenOn]; null when unknown).
 */
data class PickedFile(val file: File, val kind: MediaKind, val takenOn: LocalDate? = null)

/**
 * Copies [uri] into the capture directory; images lose their location tags (`ImageEncoder.stripLocation`). [index] keeps
 * the names of one selection apart (they are copied within the same millisecond). [fallbackType] is the share intent's
 * type, for providers that report none. Only images and videos are taken ([imagesAndVideosOnly]: a shared item of another
 * type is left out); null when the item cannot be read.
 */
internal fun importPicked(
    context: Context,
    uri: Uri,
    index: Int = 0,
    fallbackType: String? = null,
    imagesAndVideosOnly: Boolean = false,
): PickedFile? {
    val type = runCatching { context.contentResolver.getType(uri) }.getOrNull()?.takeIf { it.isNotBlank() } ?: fallbackType.orEmpty()
    val video = type.startsWith("video/")
    if (imagesAndVideosOnly && !video && !type.startsWith("image/")) return null
    val file = File(CaptureHandoff.dir(context), "pick-${System.currentTimeMillis()}-$index.${if (video) "mp4" else "jpg"}")
    return try {
        context.contentResolver.openInputStream(uri)?.use { input -> file.outputStream().use { input.copyTo(it) } } ?: return null
        // The day first (MediaStore, else the file's own capture date); then the location tags go (the date stays).
        val takenOn = TakenOn.read(context, uri, file, video)
        if (!video) runCatching { ImageEncoder.stripLocation(file) }
        PickedFile(file, if (video) MediaKind.Video else MediaKind.Photo, takenOn)
    } catch (_: Exception) {
        file.delete()
        null
    }
}
