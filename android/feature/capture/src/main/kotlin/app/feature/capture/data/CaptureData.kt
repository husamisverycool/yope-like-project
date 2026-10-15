package app.feature.capture.data

import android.content.Context
import app.data.DataGraph
import app.data.error.DataError
import app.data.error.DataException
import app.data.media.upload.NewPost
import app.data.media.upload.UploadProgress
import app.data.model.Collage
import app.data.model.DailyInvitation
import app.data.model.Group
import app.data.model.Media
import app.data.model.Post
import app.data.model.Profile
import app.data.offline.DataState
import app.data.repo.Member
import app.widget.HttpsRenditionDownloader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

/** The newest thing a group's widget should show (`widget.home.small` → Elements → photo / collage). */
data class NewestForWidget(
    val renditionPath: String,
    val isCollage: Boolean,
    val sourceId: String,
    val postedAt: java.time.Instant,
    val senderName: String?,
    val senderAvatarPath: String?,
    val caption: String?,
)

/**
 * Everything the capture screens read and write, over the data layer (core:data). An interface
 * so view models are tested with fakes; [CaptureDataProvider] supplies the app's.
 */
interface CaptureData {
    /** The person's groups, cache first then network (offline renders the cached list). */
    fun groups(): Flow<DataState<List<Group>>>

    /** Signed read URLs (1 h); unreadable paths are absent. */
    suspend fun signedUrls(paths: Collection<String>): Map<String, String>

    /** Premium entitlement (video posts only). False when unknown. */
    suspend fun isPremium(): Boolean

    /** `uploads.enqueue`: copies the files, persists the draft, sends with WorkManager (works offline, resumes). */
    fun enqueue(post: NewPost): String

    fun progress(draftId: String): Flow<UploadProgress>

    fun retry(draftId: String)

    /** Device reachability. */
    val online: Flow<Boolean>

    suspend fun invitation(invitationId: String): DailyInvitation?

    suspend fun group(groupId: String): Group?

    suspend fun collageForInvitation(invitationId: String): Collage?

    /** The newest post or ready collage of [groupId] for its widget; null when the group has none. */
    suspend fun newestForWidget(groupId: String): NewestForWidget?

    /** Members of [groupId] in joining order with their profiles. */
    suspend fun members(groupId: String): List<Member>

    /** Downloads a signed URL into [target] (atomic). */
    suspend fun download(url: String, target: File)
}

/** The app's [CaptureData] over the process-wide [DataGraph]. */
class GraphCaptureData(private val graph: DataGraph) : CaptureData {
    override fun groups(): Flow<DataState<List<Group>>> = graph.groups.observeMyGroups()

    override suspend fun signedUrls(paths: Collection<String>): Map<String, String> = graph.signedUrls.urls(paths)

    override suspend fun isPremium(): Boolean = try {
        graph.entitlements.isPremium()
    } catch (_: DataException) {
        false
    }

    override fun enqueue(post: NewPost): String = graph.uploads.enqueue(post)

    override fun progress(draftId: String): Flow<UploadProgress> = graph.uploads.progress(draftId)

    override fun retry(draftId: String) = graph.uploads.retry(draftId)

    override val online: Flow<Boolean> get() = graph.connectivity.online

    override suspend fun invitation(invitationId: String): DailyInvitation? = graph.invitations.invitation(invitationId)

    override suspend fun group(groupId: String): Group? = graph.groups.group(groupId)

    override suspend fun collageForInvitation(invitationId: String): Collage? = graph.invitations.collageForInvitation(invitationId)

    override suspend fun newestForWidget(groupId: String): NewestForWidget? {
        val post: Post? = graph.posts.feed(groupId, limit = 1).firstOrNull()
        val collage: Collage? = graph.invitations.collages(groupId, limit = 1).firstOrNull()
        val collageAt = collage?.composedAt
        if (collage != null && collageAt != null && collage.widgetPath != null && (post == null || collageAt.isAfter(post.createdAt))) {
            return NewestForWidget(collage.widgetPath!!, isCollage = true, sourceId = collage.id, postedAt = collageAt, senderName = null, senderAvatarPath = null, caption = null)
        }
        if (post == null) return null
        val media: Media = graph.posts.mediaOf(post) ?: return null
        val author: Profile? = graph.profiles.profiles(listOf(post.authorId)).firstOrNull()
        return NewestForWidget(
            renditionPath = media.imagePath(Media.Rendition.Widget),
            isCollage = false,
            sourceId = post.id,
            postedAt = post.createdAt,
            senderName = author?.firstName,
            senderAvatarPath = author?.avatarPath,
            caption = post.caption,
        )
    }

    override suspend fun members(groupId: String): List<Member> = graph.groups.members(groupId)

    override suspend fun download(url: String, target: File) = downloadTo(url, target)
}

/** Used while config/app.json has no Supabase project: nothing loads, nothing sends. */
object UnconfiguredCaptureData : CaptureData {
    override fun groups(): Flow<DataState<List<Group>>> =
        flowOf(DataState(null, DataState.Source.None, null, refreshing = false, error = DataError.NotConfigured))

    override suspend fun signedUrls(paths: Collection<String>): Map<String, String> = emptyMap()
    override suspend fun isPremium(): Boolean = false
    override fun enqueue(post: NewPost): String = throw DataException(DataError.NotConfigured)
    override fun progress(draftId: String): Flow<UploadProgress> = flowOf(UploadProgress.Failed(DataError.NotConfigured))
    override fun retry(draftId: String) = Unit
    override val online: Flow<Boolean> get() = flowOf(false)
    override suspend fun invitation(invitationId: String): DailyInvitation? = null
    override suspend fun group(groupId: String): Group? = null
    override suspend fun collageForInvitation(invitationId: String): Collage? = null
    override suspend fun newestForWidget(groupId: String): NewestForWidget? = null
    override suspend fun members(groupId: String): List<Member> = emptyList()
    override suspend fun download(url: String, target: File) = throw DataException(DataError.NotConfigured)
}

/** Supplies the process's [CaptureData]; tests set [override]. */
object CaptureDataProvider {
    @Volatile var override: CaptureData? = null

    fun get(context: Context): CaptureData =
        override ?: DataGraph.get(context.applicationContext)?.let(::GraphCaptureData) ?: UnconfiguredCaptureData
}

/** Streams a signed HTTPS URL into [target] through a temp file. */
internal suspend fun downloadTo(url: String, target: File) = withContext(Dispatchers.IO) {
    target.parentFile?.mkdirs()
    val tmp = File(target.parentFile, ".${target.name}.part")
    try {
        try {
            FileOutputStream(tmp).use { out -> HttpsRenditionDownloader().download(url, out) }
        } catch (e: IOException) {
            throw DataException(DataError.Network, e)
        }
        if (!tmp.renameTo(target)) {
            target.delete()
            if (!tmp.renameTo(target)) throw DataException(DataError.FileUnavailable)
        }
    } finally {
        tmp.delete()
    }
}
