// Surface: share.in — the share sheet's per-group targets (design/surfaces/share.in.md "Per-group targets"). Mechanics:
// Android sharing shortcuts (https://developer.android.com/training/sharing/receive#sharing-shortcuts-api): a long-lived
// dynamic shortcut per group, in the share-target category of res/xml/shortcuts.xml (app module), pushed with
// ShortcutManagerCompat.pushDynamicShortcut when the person posts to the group or opens it. Picking one in the share sheet
// sends ACTION_SEND / ACTION_SEND_MULTIPLE to MainActivity with EXTRA_SHORTCUT_ID; [ShareIn] reads the group from it and
// send-to opens with that group preselected. The camera's launcher shortcuts (widget/CameraShortcuts) are separate ids and
// keep their slots: these use what the platform's per-activity limit leaves.
package app.feature.capture.share

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import androidx.compose.ui.graphics.toArgb
import androidx.core.content.edit
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import app.data.model.Group
import app.designsystem.DsAppearance
import app.designsystem.generated.Tokens
import app.feature.capture.data.CaptureData
import app.feature.capture.data.CaptureDataProvider
import app.feature.capture.widget.CameraShortcuts
import app.links.DeepLinkIntents
import app.model.DeepLink
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.io.File
import java.util.Locale
import kotlin.math.max
import kotlin.math.min

object ShareTargets {
    /** The share-target category of res/xml/shortcuts.xml (app module); the two must match. */
    const val CATEGORY = "app.sharetarget.category.GROUP"

    private const val ID_PREFIX = "share-group-"
    private const val PREFS = "share_targets"
    private const val KEY_RECENT = "recent"

    /** The adaptive icon's full size (the platform's 108 dp, developer.android.com adaptive icons). */
    private const val ADAPTIVE_ICON_DP = 108 // provenance-ok: PLATFORM adaptive icon canvas
    /** Its safe zone (72 of 108 dp): the initials stay inside it whatever mask the launcher applies. */
    private const val SAFE_ZONE_DP = 72 // provenance-ok: PLATFORM adaptive icon safe zone

    fun shortcutId(groupId: String) = ID_PREFIX + groupId

    /** The group of a share target's shortcut id (`EXTRA_SHORTCUT_ID`); null for any other id (the camera's, a stranger's). */
    fun groupIdOf(shortcutId: String?): String? {
        val id = shortcutId?.takeIf { it.startsWith(ID_PREFIX) }?.removePrefix(ID_PREFIX) ?: return null
        return id.takeIf { it.isNotEmpty() && it.length <= 64 && it.all { c -> c.isLetterOrDigit() && c.code < 128 || c == '-' } } // provenance-ok: id length bound, not UI
    }

    /** The groups with a share target, newest first. */
    fun recent(context: Context): List<String> =
        prefs(context).getString(KEY_RECENT, null)?.split(',')?.filter { it.isNotEmpty() }.orEmpty()

    /** Slots left for share targets: the per-activity limit minus the static camera shortcut and the camera's group ones. */
    fun capacity(context: Context): Int =
        (runCatching { ShortcutManagerCompat.getMaxShortcutCountPerActivity(context) }.getOrDefault(0) - 1 - CameraShortcuts.MAX_GROUPS).coerceAtLeast(0)

    /** Icon downloads and shortcut writes outlive the screen that asked: the process's scope. */
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /** The person opened [groupId]'s screen (groups.screen). */
    fun recordOpen(context: Context, groupId: String) {
        val app = context.applicationContext
        scope.launch { runCatching { record(app, listOf(groupId), CaptureDataProvider.get(app)) } }
    }

    /** The person posted to or opened [groupIds]: each becomes (or stays) a share target, the newest first. */
    suspend fun record(context: Context, groupIds: List<String>, data: CaptureData) {
        val app = context.applicationContext
        val capacity = capacity(app)
        if (capacity == 0 || groupIds.isEmpty()) return
        val groups = groupIds.distinct().take(capacity).mapNotNull { id -> runCatching { data.group(id) }.getOrNull() }
            .filter { it.name.isNotBlank() }
        if (groups.isEmpty()) return
        val ordered = (groups.map { it.id } + recent(app)).distinct()
        save(app, ordered.take(capacity))
        remove(app, ordered.drop(capacity))
        // Oldest first, so the newest is pushed last (the share sheet ranks by recency).
        for (group in groups.asReversed()) {
            val shortcut = shortcut(app, group, icon(app, group, data)) ?: continue
            runCatching { ShortcutManagerCompat.pushDynamicShortcut(app, shortcut) }
        }
    }

    /** The person's group list loaded ([groupIds]): the targets of groups gone (left, deleted) are removed. */
    fun sync(context: Context, groupIds: Set<String>) {
        val app = context.applicationContext
        val before = recent(app)
        val gone = before.filter { it !in groupIds }
        if (gone.isEmpty()) return
        save(app, before - gone.toSet())
        remove(app, gone)
    }

    /** Signed out: no group of the last person stays in the share sheet. */
    fun clear(context: Context) {
        val app = context.applicationContext
        val published = runCatching { ShortcutManagerCompat.getDynamicShortcuts(app) }.getOrDefault(emptyList())
            .mapNotNull { groupIdOf(it.id) }
        val all = (recent(app) + published).distinct()
        save(app, emptyList())
        remove(app, all)
    }

    internal fun shortcut(context: Context, group: Group, icon: IconCompat?): ShortcutInfoCompat? {
        // A tap on it outside the share sheet (a launcher listing dynamic shortcuts) opens the camera for the group.
        val intent = DeepLinkIntents.intent(context, DeepLink.Camera(group.id)) ?: return null
        val builder = ShortcutInfoCompat.Builder(context, shortcutId(group.id))
            .setShortLabel(group.name)
            .setLongLived(true)
            .setCategories(setOf(CATEGORY))
            .setIntent(intent)
            // After the camera's group shortcuts in a launcher's list.
            .setRank(CameraShortcuts.MAX_GROUPS)
        icon?.let(builder::setIcon)
        return builder.build()
    }

    /** The group's cover photo, else its initials on `color.global.control` (as an avatar without a photo). */
    private suspend fun icon(context: Context, group: Group, data: CaptureData): IconCompat? {
        val size = (ADAPTIVE_ICON_DP * context.resources.displayMetrics.density).toInt().coerceAtLeast(1)
        val cover = group.coverPath?.let { path -> runCatching { coverBitmap(context, group.id, path, size, data) }.getOrNull() }
        val bitmap = cover ?: runCatching { initialsBitmap(context, group.name, size) }.getOrNull() ?: return null
        return IconCompat.createWithAdaptiveBitmap(bitmap)
    }

    private suspend fun coverBitmap(context: Context, groupId: String, path: String, size: Int, data: CaptureData): Bitmap? {
        val url = data.signedUrls(listOf(path))[path] ?: return null
        val file = File(File(context.cacheDir, "share-targets"), "$groupId.img")
        try {
            data.download(url, file)
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(file.path, bounds)
            var sample = 1
            while (min(bounds.outWidth, bounds.outHeight) / (sample * 2) >= size) sample *= 2
            val decoded = BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = sample }) ?: return null
            // Centre square, aspect-filled (as the avatar's crop).
            val side = min(decoded.width, decoded.height)
            val square = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val left = (decoded.width - side) / 2
            val top = (decoded.height - side) / 2
            Canvas(square).drawBitmap(decoded, Rect(left, top, left + side, top + side), Rect(0, 0, size, size), Paint(Paint.FILTER_BITMAP_FLAG))
            decoded.recycle()
            return square
        } finally {
            file.delete()
        }
    }

    private fun initialsBitmap(context: Context, name: String, size: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(DsAppearance.pickSystem(Tokens.ColorsLight.globalControl, Tokens.ColorsDark.globalControl).toArgb())
        val text = initials(name)
        if (text.isEmpty()) return bitmap
        val safe = SAFE_ZONE_DP * context.resources.displayMetrics.density
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = DsAppearance.pickSystem(Tokens.ColorsLight.globalTextSecondary, Tokens.ColorsDark.globalTextSecondary).toArgb()
            textAlign = Paint.Align.CENTER
            textSize = safe / 2 // provenance-ok: two letters fill the safe zone's width
        }
        val width = paint.measureText(text)
        if (width > safe) paint.textSize = paint.textSize * safe / max(width, 1f)
        val baseline = size / 2f - (paint.descent() + paint.ascent()) / 2
        canvas.drawText(text, size / 2f, baseline, paint)
        return bitmap
    }

    /** The first letter of the name's first two words ("Book club" → "BC"). */
    internal fun initials(name: String): String =
        name.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }.take(2)
            .mapNotNull { word -> word.firstOrNull { it.isLetterOrDigit() }?.toString() }
            .joinToString("").uppercase(Locale.getDefault())

    private fun remove(context: Context, groupIds: List<String>) {
        if (groupIds.isEmpty()) return
        val ids = groupIds.map(::shortcutId)
        runCatching { ShortcutManagerCompat.removeDynamicShortcuts(context, ids) }
        runCatching { ShortcutManagerCompat.removeLongLivedShortcuts(context, ids) }
    }

    private fun save(context: Context, groupIds: List<String>) {
        prefs(context).edit { putString(KEY_RECENT, groupIds.joinToString(",")) }
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
