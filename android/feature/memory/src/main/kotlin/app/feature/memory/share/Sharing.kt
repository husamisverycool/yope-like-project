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
    fun shareIntent(uri: Uri, mimeType: String, title: String? = null, label: String? = null): Intent {
        val send = Intent(Intent.ACTION_SEND)
            .setType(mimeType)
            .putExtra(Intent.EXTRA_STREAM, uri)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        // The Sharesheet's preview: EXTRA_TITLE is its title, the clip's label its description (Android 10+).
        if (title != null) send.putExtra(Intent.EXTRA_TITLE, title)
        send.clipData = ClipData.newRawUri(label, uri)
        return Intent.createChooser(send, null).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    }

    /**
     * Saves a JPEG into the shared Pictures collection (`MediaStore.Images`): no permission on API 29+; API 26-28
     * need WRITE_EXTERNAL_STORAGE (asked by the caller first).
     */
    suspend fun saveImage(context: Context, file: File, displayName: String): Boolean =
        insert(context, file, displayName, MIME_JPEG, Environment.DIRECTORY_PICTURES, images = true)

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
    suspend fun saveVideo(context: Context, file: File, displayName: String): Boolean =
        insert(context, file, displayName, MIME_MP4, Environment.DIRECTORY_MOVIES, images = false)

    private suspend fun insert(context: Context, file: File, displayName: String, mime: String, directory: String, images: Boolean): Boolean = withContext(Dispatchers.IO) {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.MediaColumns.RELATIVE_PATH, directory)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
        }
        val collection = when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && images -> MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            images -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            else -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        }
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
    const val MIME_JPEG = "image/jpeg"
}

/** Save / share of a memory's original photo (Android services behind an interface for tests). */
interface PhotoFiles {
    /** Saves the photo at [url] to the photo library; false on failure. */
    suspend fun save(url: String, postId: String): Boolean

    /** A content:// URI of the downloaded photo for the share sheet, or null. */
    suspend fun shareUri(url: String, postId: String): Uri?
}

/** [PhotoFiles] over [MemoryFiles]: one cached download per post. */
class AndroidPhotoFiles(context: Context) : PhotoFiles {
    private val app = context.applicationContext

    private suspend fun file(url: String, postId: String): File? =
        app.feature.memory.common.attempt { MemoryFiles.download(url, File(MemoryFiles.dir(app), "memory-$postId.jpg")) }.getOrNull()

    override suspend fun save(url: String, postId: String): Boolean {
        val file = file(url, postId) ?: return false
        return MemoryFiles.saveImage(app, file, file.name)
    }

    override suspend fun shareUri(url: String, postId: String): Uri? = file(url, postId)?.let { MemoryFiles.uriFor(app, it) }
}
