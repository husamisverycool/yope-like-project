package app.media

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.exifinterface.media.ExifInterface
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import kotlin.math.max

/** Output limits for an upload. The caller passes the values the backend accepts. */
data class EncodeOptions(val maxLongEdgePx: Int, val jpegQuality: Int) {
    init {
        require(maxLongEdgePx > 0)
        require(jpegQuality in 0..100)
    }
}

data class EncodedImage(val file: File, val width: Int, val height: Int)

/**
 * Prepares photos for upload: honours EXIF orientation, downscales so the long edge fits, and
 * re-encodes as JPEG. Re-encoding writes no EXIF block at all, so no location (the app never
 * records location), device or timestamp metadata leaves the device.
 */
object ImageEncoder {

    /** [open] is called more than once (EXIF, bounds, pixels), returning a fresh stream each time. */
    fun encode(open: () -> InputStream, output: File, options: EncodeOptions): EncodedImage {
        val orientation = open().use { input ->
            try {
                ExifInterface(input).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            } catch (_: IOException) {
                ExifInterface.ORIENTATION_NORMAL
            }
        }
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        open().use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw IOException("not an image")

        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= options.maxLongEdgePx) sample *= 2
        val decoded = open().use { BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample }) }
            ?: throw IOException("could not decode image")

        val scale = minOf(1f, options.maxLongEdgePx.toFloat() / max(decoded.width, decoded.height))
        val matrix = orientationMatrix(orientation).apply { if (scale < 1f) postScale(scale, scale) }
        val result = if (matrix.isIdentity) decoded else {
            Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true).also { if (it !== decoded) decoded.recycle() }
        }
        try {
            writeAtomically(output) { out -> if (!result.compress(Bitmap.CompressFormat.JPEG, options.jpegQuality, out)) throw IOException("encode failed") }
            return EncodedImage(output, result.width, result.height)
        } finally {
            result.recycle()
        }
    }

    fun encode(context: Context, uri: Uri, output: File, options: EncodeOptions): EncodedImage =
        encode({ context.contentResolver.openInputStream(uri) ?: throw IOException("cannot open $uri") }, output, options)

    fun encode(file: File, output: File, options: EncodeOptions): EncodedImage = encode({ file.inputStream() }, output, options)

    /** Removes every GPS tag from a JPEG in place (for files kept without re-encoding). */
    fun stripLocation(file: File) {
        val exif = ExifInterface(file)
        GPS_TAGS.forEach { exif.setAttribute(it, null) }
        exif.saveAttributes()
    }

    /** All `ExifInterface.TAG_GPS_*` names, read from the library so none is missed. */
    val GPS_TAGS: List<String> by lazy {
        ExifInterface::class.java.fields
            .filter { it.name.startsWith("TAG_GPS_") && it.type == String::class.java }
            .map { it.get(null) as String }
    }

    private fun orientationMatrix(orientation: Int) = Matrix().apply {
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> postRotate(QUARTER_TURN)
            ExifInterface.ORIENTATION_ROTATE_180 -> postRotate(HALF_TURN)
            ExifInterface.ORIENTATION_ROTATE_270 -> postRotate(-QUARTER_TURN)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { postRotate(QUARTER_TURN); postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_TRANSVERSE -> { postRotate(-QUARTER_TURN); postScale(-1f, 1f) }
        }
    }

    private fun writeAtomically(target: File, write: (FileOutputStream) -> Unit) {
        target.parentFile?.mkdirs()
        val tmp = File(target.parentFile, ".${target.name}.part")
        try {
            FileOutputStream(tmp).use { out ->
                write(out)
                out.fd.sync()
            }
            if (!tmp.renameTo(target)) throw IOException("rename failed")
        } finally {
            tmp.delete()
        }
    }

    private const val QUARTER_TURN = 90f
    private const val HALF_TURN = 180f
}

/**
 * Importing from the photo library through the system Photo Picker: no permission is needed,
 * and only what the person picks is shared with the app.
 */
object PhotoImport {
    val imagesOnly: PickVisualMediaRequest = PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
    val imagesAndVideos: PickVisualMediaRequest = PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageAndVideo)

    /** Contract for one item (`rememberLauncherForActivityResult(PhotoImport.single())`). */
    fun single() = ActivityResultContracts.PickVisualMedia()

    /** Contract for up to [maxItems] items. */
    fun multiple(maxItems: Int) = ActivityResultContracts.PickMultipleVisualMedia(maxItems)

    /** Whether the system picker is present (older devices fall back to the document picker). */
    fun isSystemPickerAvailable(context: Context): Boolean = ActivityResultContracts.PickVisualMedia.isPhotoPickerAvailable(context)

    /** Copies a picked image into [output], prepared for upload. */
    fun import(context: Context, uri: Uri, output: File, options: EncodeOptions): EncodedImage =
        ImageEncoder.encode(context, uri, output, options)
}
