package app.data.media.upload

import app.data.model.DataJson
import app.data.model.MediaKind
import app.data.model.NewMedia
import kotlinx.serialization.Serializable
import java.io.File
import java.io.FileOutputStream

/** One file of a post: where it is on the device, where it goes in storage, and its type. */
@Serializable
data class DraftFile(
    val localPath: String,
    val storagePath: String,
    val contentType: String,
    val size: Long,
)

/**
 * A post being sent (recipe 9.4), persisted so the upload survives process death and retries:
 * files → `media` row → `create_post`. Progress fields record what is already done.
 */
@Serializable
data class PostDraft(
    /** = the client-generated media id (UUID v4). */
    val mediaId: String,
    val ownerId: String,
    val kind: MediaKind,
    val original: DraftFile,
    val front: DraftFile? = null,
    val motion: DraftFile? = null,
    val voice: DraftFile? = null,
    val width: Int? = null,
    val height: Int? = null,
    val frontWidth: Int? = null,
    val frontHeight: Int? = null,
    val durationMs: Int? = null,
    val groupIds: List<String>,
    val caption: String? = null,
    val voiceDurationMs: Int? = null,
    val invitationId: String? = null,
    val replyToPostId: String? = null,
    // Progress.
    val uploaded: Set<String> = emptySet(),
    val mediaInserted: Boolean = false,
    val postIds: List<String>? = null,
    /** Set when the upload failed for good (a typed error name, for the screens). */
    val failure: String? = null,
) {
    val id: String get() = mediaId

    val files: List<DraftFile> get() = listOfNotNull(original, front, motion, voice)

    val totalBytes: Long get() = files.sumOf { it.size }

    val uploadedBytes: Long get() = files.filter { it.storagePath in uploaded }.sumOf { it.size }

    fun newMedia(): NewMedia = NewMedia(
        id = mediaId,
        kind = kind,
        originalPath = original.storagePath,
        frontOriginalPath = front?.storagePath,
        motionPath = motion?.storagePath,
        width = width,
        height = height,
        frontWidth = frontWidth,
        frontHeight = frontHeight,
        durationMs = durationMs,
    )
}

/** Drafts on disk: `<root>/<mediaId>/draft.json` plus the files copied next to it. */
class UploadStore(val root: File) {
    private val lock = Any()

    fun dir(draftId: String): File {
        require(ID.matches(draftId)) { "invalid draft id" }
        return File(root, draftId)
    }

    fun save(draft: PostDraft) = synchronized(lock) {
        val dir = dir(draft.id).apply { mkdirs() }
        val tmp = File(dir, "$DRAFT.tmp")
        FileOutputStream(tmp).use { out ->
            out.write(DataJson.encodeToString(PostDraft.serializer(), draft).toByteArray(Charsets.UTF_8))
            out.fd.sync()
        }
        val target = File(dir, DRAFT)
        if (!tmp.renameTo(target)) {
            target.delete()
            tmp.renameTo(target)
        }
    }

    fun load(draftId: String): PostDraft? = synchronized(lock) {
        val file = File(dir(draftId), DRAFT)
        if (!file.isFile) return null
        try {
            DataJson.decodeFromString(PostDraft.serializer(), file.readText(Charsets.UTF_8))
        } catch (_: Exception) {
            null
        }
    }

    /** Every stored draft (pending or failed), for an "unsent" list. */
    fun all(): List<PostDraft> = root.listFiles()?.filter { it.isDirectory }?.mapNotNull { load(it.name) }.orEmpty()

    /** Deletes the draft and its copied files. */
    fun delete(draftId: String) = synchronized(lock) { dir(draftId).deleteRecursively(); Unit }

    private companion object {
        const val DRAFT = "draft.json"
        val ID = Regex("[A-Za-z0-9-]+")
    }
}
