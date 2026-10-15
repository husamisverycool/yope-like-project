package app.widget

import android.content.Context
import android.os.Build
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.ForegroundInfo
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import app.model.DeepLinkCodec
import app.model.PushMessage
import app.model.WidgetSnapshot
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.IOException
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant

/** One widget refresh: what to download and what it is. */
data class WidgetUpdateRequest(
    val groupId: String,
    val groupName: String,
    val renditionUrl: String,
    val kind: WidgetSnapshot.Kind,
    val postedAt: Instant,
    val sourceId: String?,
    val senderName: String?,
    val senderAvatarUrl: String?,
    val caption: String?,
) {
    val incoming: WidgetFileStore.Incoming
        get() = WidgetFileStore.Incoming(groupId, groupName, kind, postedAt, sourceId, senderName, caption)

    fun toData(): Data = Data.Builder()
        .putString(K_GROUP, groupId)
        .putString(K_GROUP_NAME, groupName)
        .putString(K_URL, renditionUrl)
        .putString(K_KIND, kind.name)
        .putLong(K_POSTED_AT, postedAt.toEpochMilli())
        .putString(K_SOURCE, sourceId)
        .putString(K_SENDER, senderName)
        .putString(K_AVATAR, senderAvatarUrl)
        .putString(K_CAPTION, caption)
        .build()

    companion object {
        private const val K_GROUP = "widget.group"
        private const val K_GROUP_NAME = "widget.groupName"
        private const val K_URL = "widget.url"
        private const val K_KIND = "widget.kind"
        private const val K_POSTED_AT = "widget.postedAt"
        private const val K_SOURCE = "widget.source"
        private const val K_SENDER = "widget.sender"
        private const val K_AVATAR = "widget.avatar"
        private const val K_CAPTION = "widget.caption"

        fun from(message: PushMessage.WidgetUpdate) = WidgetUpdateRequest(
            groupId = message.groupId,
            groupName = message.groupName,
            renditionUrl = message.renditionUrl,
            kind = message.kind,
            postedAt = message.postedAt,
            sourceId = message.sourceId,
            senderName = message.senderName,
            senderAvatarUrl = message.senderAvatarUrl,
            caption = message.caption,
        )

        fun fromData(data: Data): WidgetUpdateRequest? {
            val group = data.getString(K_GROUP)?.takeIf(DeepLinkCodec::isId) ?: return null
            val url = data.getString(K_URL) ?: return null
            val kind = data.getString(K_KIND)?.let { k -> WidgetSnapshot.Kind.entries.firstOrNull { it.name == k } } ?: return null
            if (!data.hasKeyWithValueOfType(K_POSTED_AT, Long::class.javaObjectType)) return null
            return WidgetUpdateRequest(
                groupId = group,
                groupName = data.getString(K_GROUP_NAME).orEmpty(),
                renditionUrl = url,
                kind = kind,
                postedAt = Instant.ofEpochMilli(data.getLong(K_POSTED_AT, 0)),
                sourceId = data.getString(K_SOURCE),
                senderName = data.getString(K_SENDER),
                senderAvatarUrl = data.getString(K_AVATAR),
                caption = data.getString(K_CAPTION),
            )
        }
    }
}

/** Fetches a rendition from its signed URL. */
fun interface RenditionDownloader {
    /** Streams the body into [out]. Throws [HttpStatusException] for non-200 responses. */
    @Throws(IOException::class)
    fun download(url: String, out: OutputStream)
}

class HttpStatusException(val status: Int) : IOException("HTTP $status")

/** HTTPS only: renditions come from short-lived signed storage URLs. */
class HttpsRenditionDownloader : RenditionDownloader {
    override fun download(url: String, out: OutputStream) {
        val parsed = URL(url)
        if (parsed.protocol != "https") throw IOException("rendition URL must be https")
        val connection = parsed.openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = CONNECT_TIMEOUT_MS
            connection.readTimeout = READ_TIMEOUT_MS
            connection.instanceFollowRedirects = false
            val status = connection.responseCode
            if (status != HttpURLConnection.HTTP_OK) throw HttpStatusException(status)
            connection.inputStream.use { input ->
                val buffer = ByteArray(BUFFER_BYTES)
                var total = 0L
                while (true) {
                    val n = input.read(buffer)
                    if (n < 0) break
                    total += n
                    if (total > MAX_BYTES) throw IOException("rendition too large")
                    out.write(buffer, 0, n)
                }
            }
        } finally {
            connection.disconnect()
        }
    }

    private companion object {
        // Transport limits for a single widget-sized JPEG (not design values).
        const val CONNECT_TIMEOUT_MS = 15_000
        const val READ_TIMEOUT_MS = 30_000
        const val BUFFER_BYTES = 64 * 1024
        const val MAX_BYTES = 16L * 1024 * 1024
    }
}

/**
 * Downloads a widget rendition, stores it, and re-renders every widget showing that group.
 * A 4xx (e.g. an expired signed URL) fails without retry — the next push carries a fresh URL;
 * network errors and 5xx retry with WorkManager's backoff.
 */
class WidgetUpdateWorker(
    context: Context,
    params: WorkerParameters,
    private val downloader: RenditionDownloader,
    private val store: WidgetFileStore,
    private val refresh: suspend (Context, String) -> Unit = WidgetBinding::refresh,
) : CoroutineWorker(context, params) {

    /** Used by WorkManager's default factory. */
    constructor(context: Context, params: WorkerParameters) :
        this(context, params, HttpsRenditionDownloader(), WidgetFileStore.default(context))

    override suspend fun doWork(): Result {
        val request = WidgetUpdateRequest.fromData(inputData) ?: return Result.failure()
        return try {
            val written = withContext(Dispatchers.IO) {
                if (!store.accepts(request.incoming)) return@withContext null
                store.write(
                    incoming = request.incoming,
                    writePhoto = { out -> downloader.download(request.renditionUrl, out) },
                    writeAvatar = request.senderAvatarUrl?.let { url -> { out -> downloader.download(url, out) } },
                )
            }
            if (written != null) refresh(applicationContext, request.groupId)
            Result.success()
        } catch (e: HttpStatusException) {
            if (e.status in CLIENT_ERRORS) Result.failure() else retryOrFail()
        } catch (_: IOException) {
            retryOrFail()
        }
    }

    private fun retryOrFail(): Result = if (runAttemptCount + 1 < MAX_ATTEMPTS) Result.retry() else Result.failure()

    /**
     * Expedited work on Android 11 and lower runs as a foreground service: the "Updating
     * widget..." notification (`widget.arrival`). Requested only when one can be shown
     * ([WidgetUpdateScheduler.enqueue]).
     */
    override suspend fun getForegroundInfo(): ForegroundInfo {
        val notification = WidgetRefreshNotification.build(applicationContext)
            ?: throw IllegalStateException("no small icon for the widget refresh notification")
        return ForegroundInfo(WidgetRefreshNotification.NOTIFICATION_ID, notification)
    }

    companion object {
        private const val MAX_ATTEMPTS = 5
        private val CLIENT_ERRORS = 400..499
    }
}

object WidgetUpdateScheduler {
    const val TAG = "widget-update"

    fun uniqueWorkName(groupId: String) = "widget-update:$groupId"

    /**
     * [canShowForegroundNotification]: below API 31 expedited work runs as a foreground service,
     * which shows the "Updating widget..." notification (`widget.arrival`); without a small icon
     * for it the refresh runs as regular work there (FCM high-priority delivery already lifts
     * background limits).
     */
    fun request(request: WidgetUpdateRequest, expedited: Boolean, canShowForegroundNotification: Boolean = false): OneTimeWorkRequest =
        OneTimeWorkRequestBuilder<WidgetUpdateWorker>()
            .setInputData(request.toData())
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .addTag(TAG)
            .apply {
                if (expedited && (!WidgetRefreshNotification.neededFor() || canShowForegroundNotification)) {
                    setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                }
            }
            .build()

    /**
     * Queues a refresh. Requests for one group run in order (APPEND), so an out-of-order push
     * cannot cancel a newer download; the store keeps whichever is newest.
     */
    fun enqueue(context: Context, request: WidgetUpdateRequest, expedited: Boolean) {
        WorkManager.getInstance(context).enqueueUniqueWork(
            uniqueWorkName(request.groupId),
            ExistingWorkPolicy.APPEND_OR_REPLACE,
            request(request, expedited, WidgetRefreshNotification.isAvailable(context)),
        )
    }
}
