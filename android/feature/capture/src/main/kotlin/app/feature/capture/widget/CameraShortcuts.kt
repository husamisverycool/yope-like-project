// Surface: camera.quickaccess — the launcher shortcuts (long-press on the app icon) that open the camera
// (design/surfaces/camera.quickaccess.md → Android launcher shortcuts; token camera.quickaccess.layout.entries →
// androidShortcuts: "one static shortcut (camera) and up to 3 dynamic shortcuts for the groups most recently sent to,
// newest first (4 in all)"). Platform: https://developer.android.com/develop/ui/views/launch/shortcuts and
// …/shortcuts/best-practices. The static one is app/src/main/res/xml/shortcuts.xml.
package app.feature.capture.widget

import android.content.Context
import androidx.core.content.edit
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import app.data.model.Group
import app.designsystem.R
import app.links.DeepLinkIntents
import app.model.DeepLink
import org.json.JSONArray
import org.json.JSONObject

/**
 * The dynamic launcher shortcuts, one per group recently sent to: short label the group's name, long label
 * `camera.quickaccess.shortcut.groupLong` ("Take photo for {group}"), the camera with that group preselected
 * (`app://camera?group=<id>`, as a widget tap). Pushed after each send ([recordSend]); a group no longer in the person's
 * list is removed when the list loads ([sync]); signing out removes them all ([clear]).
 */
object CameraShortcuts {
    /** "up to 3 dynamic shortcuts" (token `camera.quickaccess.layout.entries` → androidShortcuts). */
    const val MAX_GROUPS = 3

    /** The adaptive icon (`drawable/ic_shortcut_camera` of the app module: the glyph on the app icon's background); set at app start. */
    @Volatile var iconRes: Int? = null

    /** A group a shortcut opens the camera for. */
    data class Entry(val groupId: String, val name: String)

    private const val PREFS = "camera_shortcuts"
    private const val KEY_RECENT = "recent"
    private const val KEY_ID = "id"
    private const val KEY_NAME = "name"
    private const val ID_PREFIX = "camera-group-"

    /** The groups most recently sent to, newest first. */
    fun recent(context: Context): List<Entry> {
        val raw = prefs(context).getString(KEY_RECENT, null) ?: return emptyList()
        return runCatching {
            val array = JSONArray(raw)
            (0 until array.length()).mapNotNull { i ->
                val o = array.optJSONObject(i) ?: return@mapNotNull null
                val id = o.optString(KEY_ID)
                if (id.isEmpty()) null else Entry(id, o.optString(KEY_NAME))
            }
        }.getOrDefault(emptyList())
    }

    /** The order after a send to [sent]: those first, then the earlier ones, at most [MAX_GROUPS]. */
    fun order(sent: List<Entry>, earlier: List<Entry>): List<Entry> = (sent + earlier).distinctBy { it.groupId }.take(MAX_GROUPS)

    /** A send to [groupIds]: they become the newest shortcuts ([lookup] gives each group's current name). */
    suspend fun recordSend(context: Context, groupIds: List<String>, lookup: suspend (String) -> Group?) {
        val app = context.applicationContext
        val earlier = recent(app)
        val sent = groupIds.distinct().take(MAX_GROUPS).mapNotNull { id ->
            val name = runCatching { lookup(id)?.name }.getOrNull() ?: earlier.firstOrNull { it.groupId == id }?.name
            name?.takeIf { it.isNotBlank() }?.let { Entry(id, it) }
        }
        val recent = order(sent, earlier)
        save(app, recent)
        publish(app, recent)
    }

    /** The person's group list loaded ([groupIds]): shortcuts of groups gone (left, deleted) are removed. */
    fun sync(context: Context, groupIds: Set<String>) {
        val app = context.applicationContext
        val before = recent(app)
        val recent = before.filter { it.groupId in groupIds }
        if (recent == before) return
        save(app, recent)
        publish(app, recent)
        val gone = before.filter { it.groupId !in groupIds }.map { shortcutId(it.groupId) }
        if (gone.isNotEmpty()) runCatching { ShortcutManagerCompat.disableShortcuts(app, gone, null) }
    }

    /** Signed out: no group of the last person stays in the launcher. */
    fun clear(context: Context) {
        val app = context.applicationContext
        val before = recent(app).map { shortcutId(it.groupId) }
        save(app, emptyList())
        runCatching { ShortcutManagerCompat.removeAllDynamicShortcuts(app) }
        if (before.isNotEmpty()) runCatching { ShortcutManagerCompat.disableShortcuts(app, before, null) }
    }

    fun shortcutId(groupId: String) = ID_PREFIX + groupId

    private fun publish(context: Context, entries: List<Entry>) {
        val shortcuts = entries.take(MAX_GROUPS).mapIndexedNotNull { rank, entry -> shortcut(context, entry, rank) }
        runCatching { ShortcutManagerCompat.setDynamicShortcuts(context, shortcuts) }
    }

    internal fun shortcut(context: Context, entry: Entry, rank: Int): ShortcutInfoCompat? {
        if (entry.name.isBlank()) return null
        val intent = DeepLinkIntents.intent(context, DeepLink.Camera(entry.groupId)) ?: return null
        val builder = ShortcutInfoCompat.Builder(context, shortcutId(entry.groupId))
            .setShortLabel(entry.name)
            .setLongLabel(context.getString(R.string.camera_quickaccess_shortcut_grouplong, entry.name))
            .setIntent(intent)
            .setRank(rank)
        iconRes?.let { builder.setIcon(IconCompat.createWithResource(context, it)) }
        return builder.build()
    }

    private fun save(context: Context, recent: List<Entry>) {
        val array = JSONArray()
        recent.forEach { array.put(JSONObject().put(KEY_ID, it.groupId).put(KEY_NAME, it.name)) }
        prefs(context).edit { putString(KEY_RECENT, array.toString()) }
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
