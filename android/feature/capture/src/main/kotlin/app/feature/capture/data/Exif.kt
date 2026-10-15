package app.feature.capture.data

import android.media.ExifInterface
import java.io.File

/** Degrees a JPEG must turn to stand upright (EXIF orientation); 0 when unknown. */
internal fun exifRotation(file: File): Int = runCatching {
    when (ExifInterface(file.path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
        ExifInterface.ORIENTATION_ROTATE_90, ExifInterface.ORIENTATION_TRANSPOSE -> QUARTER
        ExifInterface.ORIENTATION_ROTATE_180 -> HALF
        ExifInterface.ORIENTATION_ROTATE_270, ExifInterface.ORIENTATION_TRANSVERSE -> THREE_QUARTERS
        else -> 0
    }
}.getOrDefault(0)

private const val QUARTER = 90
private const val HALF = 180
private const val THREE_QUARTERS = 270
