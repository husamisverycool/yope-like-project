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
import java.util.UUID

/**
 * The friend and memories widgets' photos (design/surfaces/widget.friend.md, widget.memories.md; docs/WIDGET_REFRESH.md
 * "Friend and memories widgets"), one directory per slot — a followed person's id, or a day (`2026-10-17`):
 *
 * ```
 * <root>/<slot>/snapshot.json     the WidgetSnapshot the widget renders (groupId: the photo's group)
 * <root>/<slot>/p-<time>-<n>.jpg  its rendition
 * <root>/<slot>/none              looked up: nothing to show (the empty state)
 * <root>/<slot>/gone              the person is no longer someone to show (no shared group, a block: "not set up")
 * ```
 *
 * A slot with none of these was not looked up yet (the loading state). Writes are atomic as [WidgetFileStore]'s (temp
 * file, flush, rename; `snapshot.json` last). Unlike the group store the newest does not always win: the server's answer
 * replaces the slot ([write]), and only the push path keeps the newest ([FriendWidgets.copyFromGroup]). Kept out of backups.
 */
class WidgetSlotStore(val root: File) {
    /** What a slot holds. */
    enum class State { Unknown, Shown, None, Gone }

    private val lock = Any()

    fun slotDir(slot: String): File {
        require(DeepLinkCodec.isId(slot)) { "invalid slot" }
        return File(root, slot)
    }

    /** The slot's snapshot, or null when there is none or its photo is missing. */
    fun read(slot: String): WidgetSnapshot? {
        val file = File(slotDir(slot), SNAPSHOT)
        if (!file.isFile) return null
        val snapshot = try {
            WidgetSnapshot.fromJson(file.readText())
        } catch (_: IOException) {
            null
        } ?: return null
        return snapshot.takeIf { photo(slot, it).isFile }
    }

    fun photo(slot: String, snapshot: WidgetSnapshot): File = File(slotDir(slot), safeName(snapshot.photoFile))

    fun state(slot: String): State {
        if (read(slot) != null) return State.Shown
        val dir = slotDir(slot)
        return when {
            File(dir, NONE).isFile -> State.None
            File(dir, GONE).isFile -> State.Gone
            else -> State.Unknown
        }
    }

    /**
     * Makes [snapshot] the slot's photo ([writePhoto] streams the rendition; an exception leaves the slot unchanged).
     * Its avatar is not kept (the widget draws none). Returns the stored snapshot.
     */
    fun write(slot: String, snapshot: WidgetSnapshot, writePhoto: (OutputStream) -> Unit): WidgetSnapshot {
        val dir = slotDir(slot).apply { mkdirs() }
        val tmp = writeTemp(dir, writePhoto)
        try {
            synchronized(lock) {
                val name = "$PHOTO_PREFIX${snapshot.postedAtEpochMillis}-${UUID.randomUUID().toString().take(SUFFIX_LENGTH)}$EXT"
                val stored = snapshot.copy(photoFile = name, senderAvatarFile = null)
                move(tmp, File(dir, name))
                val json = writeTemp(dir) { it.write(stored.toJson().toByteArray()) }
                move(json, File(dir, SNAPSHOT))
                File(dir, NONE).delete()
                File(dir, GONE).delete()
                prune(dir, keep = name)
                return stored
            }
        } finally {
            tmp.delete()
        }
    }

    /** Looked up, nothing to show: the empty state. */
    fun markNone(slot: String) = mark(slot, NONE)

    /** The person is no longer someone the viewer may follow: "not set up". */
    fun markGone(slot: String) = mark(slot, GONE)

    private fun mark(slot: String, marker: String) = synchronized(lock) {
        val dir = slotDir(slot)
        dir.deleteRecursively()
        dir.mkdirs()
        File(dir, marker).writeText(marker)
        Unit
    }

    /** Forgets the slot (it reads as not looked up). */
    fun remove(slot: String) = synchronized(lock) { slotDir(slot).deleteRecursively(); Unit }

    fun slots(): Set<String> = root.listFiles()?.filter { it.isDirectory && DeepLinkCodec.isId(it.name) }?.map { it.name }?.toSet().orEmpty()

    /** Drops every slot not in [slots] (a widget nobody follows any more, a day gone by). */
    fun retain(slots: Set<String>) = synchronized(lock) {
        root.listFiles()?.filter { it.isDirectory && it.name !in slots }?.forEach { it.deleteRecursively() }
        Unit
    }

    /** Forgets the slots showing [sourceId] (a deleted photo); returns them. */
    fun removeSource(sourceId: String): Set<String> = removeWhere { it.sourceId == sourceId }

    /** Forgets the slots showing a photo of a group not in [groupIds] (a group left); returns them. */
    fun retainGroups(groupIds: Set<String>): Set<String> = removeWhere { it.groupId !in groupIds }

    private fun removeWhere(match: (WidgetSnapshot) -> Boolean): Set<String> = synchronized(lock) {
        slots().filter { slot -> read(slot)?.let(match) == true }.onEach { slotDir(it).deleteRecursively() }.toSet()
    }

    /** Signed out: nothing of the last person stays. */
    fun clear() = synchronized(lock) { root.deleteRecursively(); Unit }

    /** Keeps the current photo and the one before it (a widget host may still be decoding it), as [WidgetFileStore.prune]. */
    private fun prune(dir: File, keep: String) {
        val photos = dir.listFiles()?.filter { it.name.startsWith(PHOTO_PREFIX) && it.name != keep }.orEmpty()
            .sortedByDescending { it.name.removePrefix(PHOTO_PREFIX).substringBefore('-').toLongOrNull() ?: 0L }
        photos.drop(1).forEach { it.delete() }
        dir.listFiles()?.filter { it.name.startsWith(TEMP_PREFIX) && System.currentTimeMillis() - it.lastModified() > STALE_TEMP_MILLIS }
            ?.forEach { it.delete() }
    }

    private fun writeTemp(dir: File, write: (OutputStream) -> Unit): File {
        val tmp = File.createTempFile(TEMP_PREFIX, ".part", dir)
        try {
            FileOutputStream(tmp).use { out ->
                write(out)
                out.flush()
                out.fd.sync()
            }
            if (tmp.length() == 0L) throw IOException("empty file")
            return tmp
        } catch (e: Throwable) {
            tmp.delete()
            throw e
        }
    }

    private fun move(from: File, to: File) {
        try {
            Files.move(from.toPath(), to.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
        } catch (_: AtomicMoveNotSupportedException) {
            Files.move(from.toPath(), to.toPath(), StandardCopyOption.REPLACE_EXISTING)
        }
    }

    private fun safeName(name: String): String {
        require(name.isNotEmpty() && '/' !in name && '\\' !in name && name != "." && name != "..") { "invalid file name" }
        return name
    }

    companion object {
        const val SNAPSHOT = "snapshot.json"
        private const val NONE = "none"
        private const val GONE = "gone"
        private const val PHOTO_PREFIX = "p-"
        private const val TEMP_PREFIX = "tmp-"
        private const val EXT = ".jpg"
        private const val SUFFIX_LENGTH = 8
        /** A temp file older than this was left by a killed process. */
        private const val STALE_TEMP_MILLIS = 60 * 60 * 1000L

        /** Followed friends' photos, one slot per person (`widget.friend`). */
        fun friends(context: Context): WidgetSlotStore = WidgetSlotStore(File(context.noBackupFilesDir, "widgets-friends"))

        /** Your memories, one slot per day (`widget.memories`). */
        fun memories(context: Context): WidgetSlotStore = WidgetSlotStore(File(context.noBackupFilesDir, "widgets-memories"))
    }
}
