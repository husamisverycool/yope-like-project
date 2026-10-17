package app.widget

import app.model.DeepLinkCodec
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
 *   being fetched (the widget shows the loading state, `widget.home.small` → States → loading);
 *   [Content.NoPhotos] once the group is known to have none (the empty state).
 * - [isSignedOut]: nobody is signed in on this device (every widget shows the signed-out state,
 *   `widget.home.small.empty.signedOut`; a tap opens the app's sign-in).
 *
 * A bound widget whose group has no entry here was never prepared, or its group was left or
 * removed ([WidgetFileStore.retainGroups] drops the entry): it shows "not set up".
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

    /** Creates (or resets) the entry: content unknown. */
    fun prepare(groupId: String) = synchronized(lock) {
        dir(groupId).deleteRecursively()
        writeState(groupId, Content.Unknown)
    }

    fun setContent(groupId: String, content: Content) = synchronized(lock) {
        writeState(groupId, content)
    }

    /** Whether the device is signed out (a marker next to the group entries). */
    fun isSignedOut(): Boolean = File(root, SIGNED_OUT).isFile

    /** Records the session: signed out shows `empty.signedOut` on every widget until someone signs in. */
    fun setSignedOut(signedOut: Boolean) = synchronized(lock) {
        val marker = File(root, SIGNED_OUT)
        if (signedOut) {
            root.mkdirs()
            if (!marker.isFile) writeAtomically(marker) { it.write(SIGNED_OUT.toByteArray()) }
        } else {
            marker.delete()
        }
        Unit
    }

    /**
     * Whether the signed-in person has premium (`widget.styles`: a premium style draws Photo without it; docs/
     * WIDGET_REFRESH.md "Android keeps a marker next to the widget metadata"). Written by the app whenever it learns the
     * entitlement; false until then and after signing out.
     */
    fun isPremium(): Boolean = File(root, PREMIUM).isFile

    fun setPremium(premium: Boolean) = synchronized(lock) {
        val marker = File(root, PREMIUM)
        if (premium) {
            root.mkdirs()
            if (!marker.isFile) writeAtomically(marker) { it.write(PREMIUM.toByteArray()) }
        } else {
            marker.delete()
        }
        Unit
    }

    /** The groups the configuration activity or the app prepared (an All Groups widget draws from these). */
    fun preparedGroups(): Set<String> =
        root.listFiles()?.filter { it.isDirectory && DeepLinkCodec.isId(it.name) && File(it, STATE).isFile }?.map { it.name }?.toSet().orEmpty()

    /** Drops every group not in [groupIds] (left, removed, signed out). */
    fun retain(groupIds: Set<String>) = synchronized(lock) {
        root.listFiles()?.filter { it.isDirectory && it.name !in groupIds }?.forEach { it.deleteRecursively() }
    }

    fun remove(groupId: String) = synchronized(lock) { dir(groupId).deleteRecursively(); Unit }

    private fun readState(groupId: String): JSONObject? {
        val file = File(dir(groupId), STATE)
        if (!file.isFile) return null
        return try {
            JSONObject(file.readText())
        } catch (_: Exception) {
            null
        }
    }

    private fun writeState(groupId: String, content: Content) {
        val dir = dir(groupId).apply { mkdirs() }
        val json = JSONObject().put(KEY_CONTENT, content.name)
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
        private const val STATE = "state.json"
        private const val SIGNED_OUT = "signed-out"
        private const val PREMIUM = "premium"
        private const val KEY_CONTENT = "content"

        /** The meta directory that belongs to [store] (a sibling of its root). */
        fun of(store: WidgetFileStore): WidgetGroupMeta = WidgetGroupMeta(File(store.root.parentFile, store.root.name + "-meta"))
    }
}
