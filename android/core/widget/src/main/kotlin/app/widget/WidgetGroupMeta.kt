package app.widget

import app.designsystem.generated.Tokens
import app.model.DeepLinkCodec
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.OutputStream

/**
 * What a widget knows about its group besides the rendition ([WidgetFileStore]): written when the
 * person chooses the group in the configuration activity, before the widget is bound.
 *
 * - [content]: whether the group has a photo yet. [Content.Unknown] while the newest rendition is
 *   being fetched (the widget shows the loading placeholder, `widget.home.small` → States →
 *   loading); [Content.NoPhotos] once the group is known to have none (the empty state).
 * - [members]: up to three members for the loading placeholder
 *   (`Tokens.Layouts.WidgetHomeSmallLayoutPlaceholderAvatars.max`), each with its avatar file or
 *   null when the member has no avatar.
 *
 * A bound widget whose group has no entry here was never prepared, or its group was left, removed
 * or signed out of ([WidgetFileStore.retainGroups] drops the entry): it shows "not set up".
 * Kept next to the rendition store (never inside it: the store prunes unknown files).
 */
class WidgetGroupMeta(val root: File) {
    enum class Content { Unknown, HasPhotos, NoPhotos }

    private val lock = Any()

    private fun dir(groupId: String): File {
        require(DeepLinkCodec.isId(groupId)) { "invalid group id" }
        return File(root, groupId)
    }

    /** Whether the configuration activity prepared [groupId] (and it was not dropped since). */
    fun isPrepared(groupId: String): Boolean = File(dir(groupId), STATE).isFile

    fun content(groupId: String): Content = readState(groupId)?.optString(KEY_CONTENT)
        ?.let { name -> Content.entries.firstOrNull { it.name == name } } ?: Content.Unknown

    /** The placeholder's members in order: each one's avatar file, or null for a member without one. */
    fun members(groupId: String): List<File?> {
        val flags = readState(groupId)?.optJSONArray(KEY_MEMBERS) ?: return emptyList()
        return (0 until minOf(flags.length(), MAX_AVATARS)).map { i ->
            File(dir(groupId), "$AVATAR_PREFIX$i$EXT").takeIf { flags.optBoolean(i) && it.isFile }
        }
    }

    /** Creates (or resets) the entry: content unknown, no members yet. */
    fun prepare(groupId: String) = synchronized(lock) {
        dir(groupId).deleteRecursively()
        writeState(groupId, Content.Unknown, emptyList())
    }

    fun setContent(groupId: String, content: Content) = synchronized(lock) {
        writeState(groupId, content, memberFlags(groupId))
    }

    /**
     * Stores the placeholder's members: one writer per member (null = no avatar). A writer that
     * throws leaves that member's avatar out (the placeholder draws the no-avatar circle).
     */
    fun setMembers(groupId: String, avatars: List<((OutputStream) -> Unit)?>) = synchronized(lock) {
        val dir = dir(groupId).apply { mkdirs() }
        val flags = avatars.take(MAX_AVATARS).mapIndexed { i, write ->
            val file = File(dir, "$AVATAR_PREFIX$i$EXT")
            file.delete()
            write != null && try {
                writeAtomically(file, write)
                true
            } catch (_: IOException) {
                false
            }
        }
        writeState(groupId, content(groupId), flags)
    }

    /** Drops every group not in [groupIds] (left, removed, signed out). */
    fun retain(groupIds: Set<String>) = synchronized(lock) {
        root.listFiles()?.filter { it.isDirectory && it.name !in groupIds }?.forEach { it.deleteRecursively() }
    }

    fun remove(groupId: String) = synchronized(lock) { dir(groupId).deleteRecursively(); Unit }

    private fun memberFlags(groupId: String): List<Boolean> {
        val flags = readState(groupId)?.optJSONArray(KEY_MEMBERS) ?: return emptyList()
        return (0 until flags.length()).map { flags.optBoolean(it) }
    }

    private fun readState(groupId: String): JSONObject? {
        val file = File(dir(groupId), STATE)
        if (!file.isFile) return null
        return try {
            JSONObject(file.readText())
        } catch (_: Exception) {
            null
        }
    }

    private fun writeState(groupId: String, content: Content, members: List<Boolean>) {
        val dir = dir(groupId).apply { mkdirs() }
        val json = JSONObject().put(KEY_CONTENT, content.name).put(KEY_MEMBERS, JSONArray(members))
        writeAtomically(File(dir, STATE)) { it.write(json.toString().toByteArray()) }
    }

    private fun writeAtomically(target: File, write: (OutputStream) -> Unit) {
        val tmp = File(target.parentFile, ".${target.name}.part")
        try {
            FileOutputStream(tmp).use { out ->
                write(out)
                out.fd.sync()
            }
            if (tmp.length() == 0L) throw IOException("empty file")
            if (!tmp.renameTo(target)) {
                target.delete()
                if (!tmp.renameTo(target)) throw IOException("rename failed")
            }
        } finally {
            tmp.delete()
        }
    }

    companion object {
        /** The placeholder shows at most this many member avatars. */
        val MAX_AVATARS: Int = Tokens.Layouts.WidgetHomeSmallLayoutPlaceholderAvatars.max.toInt()
        private const val STATE = "state.json"
        private const val KEY_CONTENT = "content"
        private const val KEY_MEMBERS = "members"
        private const val AVATAR_PREFIX = "m-"
        private const val EXT = ".jpg"

        /** The meta directory that belongs to [store] (a sibling of its root). */
        fun of(store: WidgetFileStore): WidgetGroupMeta = WidgetGroupMeta(File(store.root.parentFile, store.root.name + "-meta"))
    }
}
