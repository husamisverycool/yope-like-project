package app.feature.memory.share

import android.content.ClipData
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import app.feature.memory.R
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/** The module's FileProvider (own subclass, so it never collides with another module's provider). */
class MemoryFileProvider : FileProvider(R.xml.memory_file_paths)

/** Files the memory screens hand to other apps: under `cacheDir/memory-share/`. */
object MemoryFiles {
    private const val DIR = "memory-share"

    fun dir(context: Context): File = File(context.cacheDir, DIR).apply { mkdirs() }

    /** `${applicationId}.memory.files` (src/main/AndroidManifest.xml). */
    fun authority(context: Context): String = context.packageName + ".memory.files"

    fun uriFor(context: Context, file: File): Uri = FileProvider.getUriForFile(context, authority(context), file)

    /**
     * The system share sheet for one file (`layout.year.story.shareSheet`: ACTION_SEND with a content://
     * URI and FLAG_GRANT_READ_URI_PERMISSION). The chooser title is the system's own.
     */
    fun shareIntent(uri: Uri, mimeType: String): Intent {
        val send = Intent(Intent.ACTION_SEND)
            .setType(mimeType)
            .putExtra(Intent.EXTRA_STREAM, uri)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        send.clipData = ClipData.newRawUri(null, uri)
        return Intent.createChooser(send, null).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }

    /** Downloads [url] to [target] (kept when it already exists). */
    suspend fun download(url: String, target: File): File = withContext(Dispatchers.IO) {
        if (target.isFile && target.length() > 0) return@withContext target
        val tmp = File(target.parentFile, target.name + ".part")
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.inputStream.use { input -> tmp.outputStream().use { input.copyTo(it) } }
        } finally {
            connection.disconnect()
        }
        if (!tmp.renameTo(target)) {
            tmp.copyTo(target, overwrite = true)
            tmp.delete()
        }
        target
    }

    /**
     * Saves an MP4 into the shared Movies collection (`MediaStore.Video`): no permission on API 29+;
     * API 26-28 need WRITE_EXTERNAL_STORAGE (asked by the caller first).
     */
    suspend fun saveVideo(context: Context, file: File, displayName: String): Boolean = withContext(Dispatchers.IO) {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, MIME_MP4)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_MOVIES)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
        }
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        else MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        val item = runCatching { resolver.insert(collection, values) }.getOrNull() ?: return@withContext false
        val ok = runCatching {
            resolver.openOutputStream(item)?.use { out -> file.inputStream().use { it.copyTo(out) } } != null
        }.getOrDefault(false)
        if (!ok) {
            runCatching { resolver.delete(item, null, null) }
            return@withContext false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            resolver.update(item, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
        }
        true
    }

    const val MIME_MP4 = "video/mp4"
    const val MIME_PNG = "image/png"
}
