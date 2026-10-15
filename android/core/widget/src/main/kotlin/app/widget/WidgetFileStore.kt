package app.widget

import android.content.Context
import app.model.DeepLinkCodec
import app.model.WidgetSnapshot
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.OutputStream
import java.nio.file.AtomicMoveNotSupportedException
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.time.Instant
import java.util.UUID

/**
 * Widget renditions on disk, one directory per group:
 *
 * ```
 * <root>/<groupId>/snapshot.json     the WidgetSnapshot the widget renders
 * <root>/<groupId>/p-<time>-<n>.jpg  the rendition it points to
 * <root>/<groupId>/a-<time>-<n>.jpg  the sender's avatar (optional)
 * ```
 *
 * Writes are atomic: files are written to a temp name, flushed to disk, then renamed into place;
 * `snapshot.json` is swapped last, so a reader never sees a snapshot pointing at a missing or
 * partial file. Unreferenced files are pruned after each swap.
 */
class WidgetFileStore(val root: File) {

    /** What the worker knows about an incoming rendition before downloading it. */
    data class Incoming(
        val groupId: String,
        val groupName: String,
        val kind: WidgetSnapshot.Kind,
        val postedAt: Instant,
        val sourceId: String?,
        val senderName: String?,
        val caption: String?,
    ) {
        internal fun snapshot(photoFile: String, avatarFile: String?) = WidgetSnapshot(
            groupId = groupId,
            groupName = groupName,
            photoFile = photoFile,
            senderName = senderName,
            senderAvatarFile = avatarFile,
            caption = caption,
            kind = kind,
            postedAtEpochMillis = postedAt.toEpochMilli(),
            sourceId = sourceId,
        )
    }

    private val lock = Any()

    fun groupDir(groupId: String): File {
        require(DeepLinkCodec.isId(groupId)) { "invalid group id" }
        return File(root, groupId)
    }

    /** The group's current snapshot, or null when there is none or its photo is missing. */
    fun read(groupId: String): WidgetSnapshot? {
        val file = File(groupDir(groupId), SNAPSHOT)
        if (!file.isFile) return null
        val snapshot = try {
            WidgetSnapshot.fromJson(file.readText())
        } catch (_: IOException) {
            null
        } ?: return null
        if (snapshot.groupId != groupId || !photo(snapshot).isFile) return null
        return snapshot
    }

    fun photo(snapshot: WidgetSnapshot): File = File(groupDir(snapshot.groupId), safeName(snapshot.photoFile))

    fun avatar(snapshot: WidgetSnapshot): File? =
        snapshot.senderAvatarFile?.let { File(groupDir(snapshot.groupId), safeName(it)) }?.takeIf(File::isFile)

    /** Whether [incoming] would replace what the group's widget shows now (newest wins). */
    fun accepts(incoming: Incoming): Boolean = incoming.snapshot(PLACEHOLDER, null).supersedes(read(incoming.groupId))

    /**
     * Stores a rendition and makes it current. [writePhoto] (and [writeAvatar]) stream the bytes;
     * an exception from them leaves the store unchanged. Returns the new snapshot, or null when
     * [incoming] is not newer than the current one (nothing is written).
     */
    fun write(
        incoming: Incoming,
        writePhoto: (OutputStream) -> Unit,
        writeAvatar: ((OutputStream) -> Unit)? = null,
    ): WidgetSnapshot? {
        val dir = groupDir(incoming.groupId)
        // Download outside the lock into temp files, then commit under it.
        dir.mkdirs()
        val stamp = "${incoming.postedAt.toEpochMilli()}-${UUID.randomUUID().toString().take(SUFFIX_LENGTH)}"
        val photoTmp = writeTemp(dir, writePhoto)
        val avatarTmp = try {
            writeAvatar?.let { writeTemp(dir, it) }
        } catch (_: IOException) {
            null // the avatar is optional; the photo still goes up
        }
        try {
            synchronized(lock) {
                val current = read(incoming.groupId)
                val photoName = "$PHOTO_PREFIX$stamp$EXT"
                val avatarName = avatarTmp?.let { "$AVATAR_PREFIX$stamp$EXT" }
                val snapshot = incoming.snapshot(photoName, avatarName)
                if (!snapshot.supersedes(current)) return null
                move(photoTmp, File(dir, photoName))
                if (avatarTmp != null && avatarName != null) move(avatarTmp, File(dir, avatarName))
                writeAtomically(File(dir, SNAPSHOT)) { it.write(snapshot.toJson().toByteArray()) }
                prune(incoming.groupId)
                return snapshot
            }
        } finally {
            photoTmp.delete()
            avatarTmp?.delete()
        }
    }

    /**
     * Deletes files in the group's directory that the current snapshot does not reference,
     * keeping the [keepPrevious] most recent previous photos so a widget host still decoding the
     * previous rendition never loses it mid-read.
     */
    fun prune(groupId: String, keepPrevious: Int = 1) = synchronized(lock) {
        val dir = groupDir(groupId)
        val files = dir.listFiles() ?: return@synchronized
        val current = read(groupId)
        val referenced = setOfNotNull(SNAPSHOT, current?.photoFile, current?.senderAvatarFile)
        val unreferenced = files.filter { it.name !in referenced }
        val keep = unreferenced.filter { it.name.startsWith(PHOTO_PREFIX) }
            .sortedByDescending { it.name.removePrefix(PHOTO_PREFIX).substringBefore('-').toLongOrNull() ?: 0L }
            .take(keepPrevious)
            .toSet()
        unreferenced.filter { file ->
            // A temp file may belong to a write() still downloading; only stale ones are leftovers.
            if (file.name.startsWith(TEMP_PREFIX)) file.isStale() else file !in keep
        }.forEach { it.deleteRecursively() }
    }

    /** Removes every group not in [groupIds] (e.g. groups the person has left). */
    fun retainGroups(groupIds: Set<String>) = synchronized(lock) {
        root.listFiles()?.filter { it.isDirectory && it.name !in groupIds }?.forEach { it.deleteRecursively() }
    }

    fun remove(groupId: String) = synchronized(lock) { groupDir(groupId).deleteRecursively() }

    fun groups(): Set<String> = root.listFiles()?.filter { it.isDirectory && DeepLinkCodec.isId(it.name) }?.map { it.name }?.toSet().orEmpty()

    private fun writeTemp(dir: File, write: (OutputStream) -> Unit): File {
        val tmp = File.createTempFile(TEMP_PREFIX, ".part", dir)
        try {
            FileOutputStream(tmp).use { out ->
                write(out)
                out.flush()
                out.fd.sync()
            }
            if (tmp.length() == 0L) throw IOException("empty rendition")
            return tmp
        } catch (e: Throwable) {
            tmp.delete()
            throw e
        }
    }

    private fun writeAtomically(target: File, write: (OutputStream) -> Unit) {
        val tmp = writeTemp(target.parentFile!!, write)
        move(tmp, target)
    }

    private fun move(from: File, to: File) {
        try {
            Files.move(from.toPath(), to.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
        } catch (_: AtomicMoveNotSupportedException) {
            Files.move(from.toPath(), to.toPath(), StandardCopyOption.REPLACE_EXISTING)
        }
    }

    private fun File.isStale(): Boolean = System.currentTimeMillis() - lastModified() > STALE_TEMP_MILLIS

    /** Snapshot file names come from our own JSON; still never let one escape the directory. */
    private fun safeName(name: String): String {
        require(name.isNotEmpty() && '/' !in name && '\\' !in name && name != "." && name != "..") { "invalid file name" }
        return name
    }

    companion object {
        const val SNAPSHOT = "snapshot.json"
        private const val PHOTO_PREFIX = "p-"
        private const val AVATAR_PREFIX = "a-"
        private const val TEMP_PREFIX = "tmp-"
        private const val EXT = ".jpg"
        private const val PLACEHOLDER = "pending"
        private const val SUFFIX_LENGTH = 8
        /** A temp file older than this was left by a killed process. */
        private const val STALE_TEMP_MILLIS = 60 * 60 * 1000L

        /** Kept out of backups: renditions are re-downloadable and per-device. */
        fun default(context: Context): WidgetFileStore = WidgetFileStore(File(context.noBackupFilesDir, "widgets"))
    }
}
