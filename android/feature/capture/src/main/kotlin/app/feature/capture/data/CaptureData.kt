package app.feature.capture.data

import android.content.Context
import app.data.DataGraph
import app.data.error.DataError
import app.data.error.DataException
import app.data.media.upload.NewPost
import app.data.media.upload.UploadProgress
import app.data.model.Collage
import app.data.model.DailyInvitation
import app.data.model.Developing
import app.data.model.Group
import app.data.model.Media
import app.data.model.Post
import app.data.model.Profile
import app.data.offline.DataState
import app.data.repo.Member
import app.data.model.DayMemory
import app.data.model.PersonPhoto
import app.data.model.WidgetPerson
import app.feature.capture.share.ShareTargets
import app.feature.capture.widget.CameraShortcuts
import app.widget.HttpsRenditionDownloader
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.time.LocalDate
import java.time.ZoneId

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

    /** `uploads.discard`: withdraws a draft that was not posted (the send's "Cancel"). */
    fun discardDraft(draftId: String)

    /** Device reachability. */
    val online: Flow<Boolean>

    suspend fun invitation(invitationId: String): DailyInvitation?

    /**
     * `open_invitations` (migration 0035): your groups' daily invitations open now, soonest to close first; empty when
     * none or unreadable (camera.sendto then shows no countdown and the post is an ordinary post).
     */
    suspend fun openInvitations(): List<DailyInvitation> = emptyList()

    suspend fun group(groupId: String): Group?

    suspend fun collageForInvitation(invitationId: String): Collage?

    /** The collage by its id (a widget's collage of the day), to find its invitation; null when gone or unreadable. */
    suspend fun collageById(collageId: String): Collage? = null

    /**
     * Storage path of the collage's first photo (`post_ids[0]`, its display rendition): the recap preview's
     * backdrop (collage.view, MERGE_DECISIONS L-7). Null when the post or its media is gone.
     */
    suspend fun collageFirstPhotoPath(collage: Collage): String?

    /** The newest post or ready collage of [groupId] for its widget; null when the group has none. */
    suspend fun newestForWidget(groupId: String): NewestForWidget?

    /** Members of [groupId] in joining order with their profiles. */
    suspend fun members(groupId: String): List<Member>

    /** Downloads a signed URL into [target] (atomic). */
    suspend fun download(url: String, target: File)

    /** The signed-in member's first name (for "Back and front photos from {name}"); null when unknown. */
    suspend fun myFirstName(): String?

    /** `my_developing()` (camera.overnight, docs/API.md §14.3): whether your photos are developing and the next reveal; never a number. */
    suspend fun myDeveloping(): Developing

    // The friend and memories widgets (migration 0036; design/surfaces/widget.friend.md, widget.memories.md). Null: the
    // answer is not known (offline, failed), so the widgets keep what they show.

    /** The ids of the person's groups (All Groups keeps every group's item up to date). */
    suspend fun myGroupIds(): Set<String>? = null

    /** `widget_people()`: the friend widget's picker — everyone who shares a group, minus blocks. */
    suspend fun widgetPeople(): List<WidgetPerson>? = null

    /** `newest_photos_of(person)`: their posts and the photos they tagged themselves in, newest first. */
    suspend fun newestPhotosOf(userId: String): List<PersonPhoto>? = null

    /** `my_memories(from, days, zone)`: the person's own memory per day. */
    suspend fun myMemories(from: LocalDate, days: Int, zone: ZoneId): List<DayMemory>? = null

    /** The premium entitlement when it is known (the widgets' styles, `widget.styles`); null when it could not be read. */
    suspend fun premiumOrNull(): Boolean? = null

    /** Records a send to [groupIds] (the launcher's per-group camera shortcuts, `camera.quickaccess`). */
    fun recordSend(groupIds: List<String>) = Unit

    /**
     * `public_app_config.batch_max_photos` (migration 0051): the most photos one selection (one post of several photos)
     * may hold — the library picker's and share.in's limit; null when it could not be read (one photo then).
     */
    suspend fun batchMaxPhotos(): Int? = null
}

/** The app's [CaptureData] over the process-wide [DataGraph]; [context] publishes the launcher's camera shortcuts. */
class GraphCaptureData(private val graph: DataGraph, private val context: Context? = null) : CaptureData {
    /** `batch_max_photos` once read (kept for this instance). */
    @Volatile private var batchLimit: Int? = null

    override fun groups(): Flow<DataState<List<Group>>> = graph.groups.observeMyGroups()

    override suspend fun signedUrls(paths: Collection<String>): Map<String, String> = graph.signedUrls.urls(paths)

    override suspend fun isPremium(): Boolean = try {
        graph.entitlements.isPremium()
    } catch (_: DataException) {
        false
    }

    override fun enqueue(post: NewPost): String = graph.uploads.enqueue(post).also { recordSend(post.groupIds) }

    override fun recordSend(groupIds: List<String>) {
        val app = context?.applicationContext ?: return
        graph.scope.launch { runCatching { CameraShortcuts.recordSend(app, groupIds) { id -> graph.groups.group(id) } } }
        // share.in: the groups posted to become the share sheet's per-group targets.
        graph.scope.launch { runCatching { ShareTargets.record(app, groupIds, this@GraphCaptureData) } }
    }

    override suspend fun myGroupIds(): Set<String>? = orNull { graph.groups.myGroups().map { it.id }.toSet() }

    override suspend fun widgetPeople(): List<WidgetPerson>? = orNull { graph.widgets.people() }

    override suspend fun newestPhotosOf(userId: String): List<PersonPhoto>? = orNull { graph.widgets.newestPhotosOf(userId) }

    override suspend fun myMemories(from: LocalDate, days: Int, zone: ZoneId): List<DayMemory>? = orNull { graph.widgets.memories(from, days, zone) }

    override suspend fun premiumOrNull(): Boolean? = if (graph.auth.currentUserId == null) null else orNull { graph.entitlements.isPremium() }

    override suspend fun batchMaxPhotos(): Int? = batchLimit ?: orNull { graph.appConfig.publicConfig().batchMaxPhotos }?.also { batchLimit = it }

    override fun progress(draftId: String): Flow<UploadProgress> = graph.uploads.progress(draftId)

    override fun retry(draftId: String) = graph.uploads.retry(draftId)

    override fun discardDraft(draftId: String) = graph.uploads.discard(draftId)

    override val online: Flow<Boolean> get() = graph.connectivity.online

    override suspend fun invitation(invitationId: String): DailyInvitation? = graph.invitations.invitation(invitationId)

    override suspend fun openInvitations(): List<DailyInvitation> = graph.invitations.openInvitations()

    override suspend fun group(groupId: String): Group? = graph.groups.group(groupId)

    override suspend fun collageForInvitation(invitationId: String): Collage? = graph.invitations.collageForInvitation(invitationId)

    override suspend fun collageById(collageId: String): Collage? = graph.invitations.collage(collageId)

    override suspend fun collageFirstPhotoPath(collage: Collage): String? {
        val post = collage.postIds.firstOrNull()?.let { graph.posts.post(it) } ?: return null
        return graph.posts.mediaOf(post)?.imagePath(Media.Rendition.Display)
    }

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

    override suspend fun myFirstName(): String? = runCatching { graph.profiles.me().firstName }.getOrNull()

    override suspend fun myDeveloping(): Developing = graph.posts.myDeveloping()
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
    override fun discardDraft(draftId: String) = Unit
    override val online: Flow<Boolean> get() = flowOf(false)
    override suspend fun invitation(invitationId: String): DailyInvitation? = null
    override suspend fun group(groupId: String): Group? = null
    override suspend fun collageForInvitation(invitationId: String): Collage? = null
    override suspend fun collageFirstPhotoPath(collage: Collage): String? = null
    override suspend fun newestForWidget(groupId: String): NewestForWidget? = null
    override suspend fun members(groupId: String): List<Member> = emptyList()
    override suspend fun download(url: String, target: File) = throw DataException(DataError.NotConfigured)
    override suspend fun myFirstName(): String? = null
    override suspend fun myDeveloping(): Developing = Developing(developing = false, revealAt = null)
}

/** Supplies the process's [CaptureData]; tests set [override]. */
object CaptureDataProvider {
    @Volatile var override: CaptureData? = null

    fun get(context: Context): CaptureData =
        override ?: DataGraph.get(context.applicationContext)?.let { GraphCaptureData(it, context.applicationContext) } ?: UnconfiguredCaptureData
}

/** [block]'s answer, or null when it failed (offline, signed out, a server error); cancellation still propagates. */
private suspend inline fun <T> orNull(block: () -> T): T? = try {
    block()
} catch (e: CancellationException) {
    throw e
} catch (_: Exception) {
    null
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
