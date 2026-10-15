package app.data.media

import app.data.error.DataError
import app.data.error.DataException
import app.data.error.dataCall
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.storage.UploadData
import io.github.jan.supabase.storage.UploadStatus
import io.github.jan.supabase.storage.storage
import io.github.jan.supabase.storage.uploadAsFlow
import io.ktor.http.ContentType
import io.ktor.util.cio.readChannel
import java.io.File
import kotlin.time.Duration

/** Uploads one object; [onProgress] receives (bytes sent, total bytes). */
fun interface ObjectUploader {
    suspend fun upload(path: String, file: File, contentType: String, onProgress: (Long, Long) -> Unit)
}

/** Creates signed read URLs. Paths that cannot be read are left out of the result. */
fun interface UrlSigner {
    suspend fun sign(paths: List<String>, ttl: Duration): Map<String, String>
}

/** Storage access through storage-kt (bucket `media`). */
class MediaStorage(private val client: SupabaseClient) : ObjectUploader, UrlSigner {
    private val bucket get() = client.storage.from(StoragePaths.BUCKET)

    /**
     * Streams [file] to [path] (insert only, never upsert: docs/API.md §7). Throws
     * [DataError.Storage] with [app.data.error.StorageFailure.AlreadyExists] when the object exists.
     */
    override suspend fun upload(path: String, file: File, contentType: String, onProgress: (Long, Long) -> Unit) {
        require(StoragePaths.isSafe(path)) { "unsafe storage path" }
        require(contentType in StoragePaths.ALLOWED_CONTENT_TYPES) { "content type not allowed by the bucket" }
        if (!file.isFile || !file.canRead()) throw DataException(DataError.FileUnavailable)
        val size = file.length()
        dataCall {
            bucket.uploadAsFlow(path, UploadData(file.readChannel(), size)) {
                upsert = false
                this.contentType = ContentType.parse(contentType)
            }.collect { status ->
                when (status) {
                    is UploadStatus.Progress -> onProgress(status.totalBytesSend, if (status.contentLength > 0) status.contentLength else size)
                    is UploadStatus.Success -> onProgress(size, size)
                }
            }
        }
    }

    suspend fun uploadBytes(path: String, bytes: ByteArray, contentType: String) {
        require(StoragePaths.isSafe(path)) { "unsafe storage path" }
        dataCall {
            bucket.upload(path, bytes) {
                upsert = false
                this.contentType = ContentType.parse(contentType)
            }
        }
    }

    /** Only avatars may be deleted by their owner (§7); everything else is deleted by the worker. */
    suspend fun deleteOwnAvatar(path: String) {
        require(path.startsWith("avatars/")) { "only avatars can be deleted by clients" }
        dataCall { bucket.delete(path) }
    }

    /**
     * Batch-signs [paths]. Storage answers `signedURL: null` for an object the caller cannot read,
     * which storage-kt's batch call cannot decode, so a failed batch falls back to one call per path
     * and leaves the unreadable ones out.
     */
    override suspend fun sign(paths: List<String>, ttl: Duration): Map<String, String> {
        if (paths.isEmpty()) return emptyMap()
        val batch = try {
            bucket.createSignedUrls(ttl, paths).associate { it.path to it.signedURL }
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (_: Exception) {
            null
        }
        if (batch != null) return batch
        val out = LinkedHashMap<String, String>()
        for (path in paths) {
            try {
                out[path] = bucket.createSignedUrl(path, ttl)
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e
            } catch (e: Exception) {
                val error = app.data.error.ErrorMapping.map(e)
                if (error == DataError.Network) throw DataException(error, e)
            }
        }
        return out
    }

    /** Downloads an object you can read (e.g. to hand a rendition to a widget). */
    suspend fun download(path: String): ByteArray = dataCall { bucket.downloadAuthenticated(path) }
}
