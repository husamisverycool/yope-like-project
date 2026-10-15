package app.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.Action
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.appwidget.state.getAppWidgetState
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Box
import androidx.glance.layout.ContentScale
import androidx.glance.layout.fillMaxSize
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.glance.unit.ColorProvider
import app.links.DeepLinkIntents
import app.model.DeepLink
import app.model.WidgetSnapshot
import java.io.File
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Styling around the photo comes from tokens ([TokenPhotoWidgetSlots], surface `widget.android`);
 * nothing here invents a value. The interface's own defaults draw only the photo.
 */
interface PhotoWidgetSlots {
    /** Drawn over the photo (sender, caption, group name …) for the given size class. */
    @Composable fun Overlay(snapshot: WidgetSnapshot, sizeClass: WidgetSizeClass) {}

    /** Shown when the widget has no group yet ([groupId] null) or the group has no photo yet. */
    @Composable fun Empty(groupId: String?, sizeClass: WidgetSizeClass) {}

    /** Behind the photo (e.g. while it loads); null draws nothing. */
    val background: ColorProvider? get() = null

    /** The widget's one TalkBack label (the whole widget is one element). Default: the caption. */
    fun contentDescription(context: Context, snapshot: WidgetSnapshot?, groupId: String?): String? = snapshot?.caption

    /**
     * Whether a tap opens the camera for [groupId] (`camera.fromwidget`); otherwise it opens the
     * configuration activity. Default: whenever a group is bound.
     */
    fun opensCamera(context: Context, snapshot: WidgetSnapshot?, groupId: String?): Boolean = groupId != null

    companion object {
        /** The token styling; replaceable (tests). */
        @Volatile var current: PhotoWidgetSlots = TokenPhotoWidgetSlots
    }
}

/** Per-widget state: which group a widget shows. */
object WidgetBinding {
    val GROUP_ID = stringPreferencesKey("group_id")
    /** Bumped whenever the group's rendition changes, so a running Glance session recomposes. */
    val REVISION = longPreferencesKey("revision")

    suspend fun groupOf(context: Context, id: GlanceId): String? =
        getAppWidgetState(context, PreferencesGlanceStateDefinition, id)[GROUP_ID]

    /** Binds the widget [appWidgetId] to [groupId] and renders it. */
    suspend fun bind(context: Context, appWidgetId: Int, groupId: String) {
        val id = GlanceAppWidgetManager(context).getGlanceIdBy(appWidgetId)
        updateAppWidgetState(context, id) {
            it[GROUP_ID] = groupId
            it[REVISION] = (it[REVISION] ?: 0L) + 1
        }
        WidgetLayouts.widgetFor(context, id).update(context, id)
    }

    /** Every placed widget, of every layout, showing [groupId]. */
    suspend fun widgetsShowing(context: Context, groupId: String): List<Pair<GlanceAppWidget, GlanceId>> {
        val manager = GlanceAppWidgetManager(context)
        return WidgetLayouts.all.flatMap { layout ->
            manager.getGlanceIds(layout.widgetClass).filter { groupOf(context, it) == groupId }.map { layout.create() to it }
        }
    }

    /** Groups some placed widget shows (for pruning renditions nobody can see). */
    suspend fun boundGroups(context: Context): Set<String> {
        val manager = GlanceAppWidgetManager(context)
        return WidgetLayouts.all.flatMap { manager.getGlanceIds(it.widgetClass) }.mapNotNull { groupOf(context, it) }.toSet()
    }

    /** Re-renders every placed widget of every layout (e.g. after sign-out or leaving groups). */
    suspend fun refreshAll(context: Context) {
        WidgetLayouts.all.forEach { it.create().updateAll(context) }
    }

    /** Re-renders every widget showing [groupId]. */
    suspend fun refresh(context: Context, groupId: String) {
        for ((widget, id) in widgetsShowing(context, groupId)) {
            updateAppWidgetState(context, id) { it[REVISION] = (it[REVISION] ?: 0L) + 1 }
            widget.update(context, id)
        }
    }
}

/** The widget layouts the app offers. Each has its own GlanceAppWidget + receiver. */
object WidgetLayouts {
    class Layout(val widgetClass: Class<out GlanceAppWidget>, val create: () -> GlanceAppWidget)

    val groupPhoto = Layout(GroupPhotoWidget::class.java, ::GroupPhotoWidget)
    val all: List<Layout> = listOf(groupPhoto)

    suspend fun widgetFor(context: Context, id: GlanceId): GlanceAppWidget {
        val manager = GlanceAppWidgetManager(context)
        return all.firstOrNull { id in manager.getGlanceIds(it.widgetClass) }?.create?.invoke() ?: GroupPhotoWidget()
    }
}

/**
 * The group photo widget: the group's newest photo (or the day's collage) filling the widget.
 * Tapping it opens the camera for that group (`app://camera?group=<id>`, surface
 * `camera.fromwidget`); an unbound widget opens its configuration.
 */
class GroupPhotoWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Responsive(WidgetSizeClass.breakpoints)
    override val stateDefinition = PreferencesGlanceStateDefinition

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val store = WidgetFileStore.default(context)
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        provideContent {
            val state = currentState<Preferences>()
            PhotoWidgetContent(
                store = store,
                groupId = state[WidgetBinding.GROUP_ID],
                revision = state[WidgetBinding.REVISION] ?: 0L,
                appWidgetId = appWidgetId,
            )
        }
    }

    /**
     * The widget picker's generated preview (Android 15+, `widget.android` → widget provider):
     * the newest rendition this device holds, else the loading placeholder.
     */
    override suspend fun providePreview(context: Context, widgetCategory: Int) {
        val store = WidgetFileStore.default(context)
        val newest = store.groups().mapNotNull { runCatching { store.read(it) }.getOrNull() }.maxByOrNull { it.postedAtEpochMillis }
        provideContent {
            PhotoWidgetContent(store = store, groupId = newest?.groupId, revision = 0L, appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID, preview = true)
        }
    }
}

class GroupPhotoWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = GroupPhotoWidget()
}

@Composable
internal fun PhotoWidgetContent(store: WidgetFileStore, groupId: String?, revision: Long, appWidgetId: Int, preview: Boolean = false) {
    val context = LocalContext.current
    val size = LocalSize.current
    val sizeClass = WidgetSizeClass.of(size)
    val slots = PhotoWidgetSlots.current
    // Reads are keyed by revision: the worker bumps it after every committed write.
    val snapshot = remember(groupId, revision) { groupId?.let { runCatching { store.read(it) }.getOrNull() } }
    val density = context.resources.displayMetrics.density
    val widthPx = (size.width.value * density).roundToInt()
    val heightPx = (size.height.value * density).roundToInt()
    val bitmap = remember(snapshot, widthPx, heightPx) {
        snapshot?.let { WidgetBitmaps.decodeCropped(store.photo(it), widthPx, heightPx) }
    }
    // A preview (widget picker) shows the newest photo, or the loading placeholder; never "set up".
    val emptyGroup = if (preview && snapshot == null) null else groupId

    var modifier = GlanceModifier.fillMaxSize().appWidgetBackground()
    if (!preview) modifier = modifier.clickable(tapAction(context, groupId.takeIf { slots.opensCamera(context, snapshot, groupId) }, appWidgetId))
    slots.contentDescription(context, snapshot, groupId)?.let { label -> modifier = modifier.semantics { contentDescription = label } }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        // PLATFORM: the launcher's own widget corner radius.
        modifier = modifier.cornerRadius(android.R.dimen.system_app_widget_background_radius)
    }
    slots.background?.let { modifier = modifier.background(it) }

    Box(modifier = modifier) {
        if (snapshot != null && bitmap != null) {
            Image(
                provider = ImageProvider(bitmap),
                // The root carries the widget's one TalkBack label (slots.contentDescription).
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = GlanceModifier.fillMaxSize(),
            )
            slots.Overlay(snapshot, sizeClass)
        } else if (preview) {
            PreviewPlaceholder(slots, sizeClass)
        } else {
            slots.Empty(emptyGroup, sizeClass)
        }
    }
}

/** The loading placeholder without member avatars (the picker preview has no group). */
@Composable
private fun PreviewPlaceholder(slots: PhotoWidgetSlots, sizeClass: WidgetSizeClass) {
    if (slots === TokenPhotoWidgetSlots) TokenPhotoWidgetSlots.Placeholder() else slots.Empty(null, sizeClass)
}

private fun tapAction(context: Context, groupId: String?, appWidgetId: Int): Action {
    val link = groupId?.let { DeepLinkIntents.intent(context, DeepLink.Camera(it)) }
    if (link != null) return actionStartActivity(link)
    val configure = Intent(context, WidgetConfigureActivity::class.java)
        .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        .setData(android.net.Uri.parse("widget://configure/$appWidgetId")) // unique per widget
    return actionStartActivity(configure)
}

/** Decodes renditions at the widget's pixel size, so bitmaps stay within RemoteViews' memory budget. */
object WidgetBitmaps {
    fun decodeCropped(file: File, widthPx: Int, heightPx: Int): Bitmap? {
        if (!file.isFile || widthPx <= 0 || heightPx <= 0) return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= widthPx && bounds.outHeight / (sample * 2) >= heightPx) sample *= 2
        val decoded = BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = sample }) ?: return null
        return centerCrop(decoded, widthPx, heightPx)
    }

    /** Scales [src] to cover [w]×[h] and crops the centre (what ContentScale.Crop shows). */
    fun centerCrop(src: Bitmap, w: Int, h: Int): Bitmap {
        val scale = max(w.toFloat() / src.width, h.toFloat() / src.height)
        if (scale >= 1f) return src // never upscale; Glance scales the smaller bitmap to fill
        val sw = max(w, (src.width * scale).roundToInt())
        val sh = max(h, (src.height * scale).roundToInt())
        val scaled = Bitmap.createScaledBitmap(src, sw, sh, true)
        if (scaled !== src) src.recycle()
        val cropped = Bitmap.createBitmap(scaled, (sw - w) / 2, (sh - h) / 2, w, h)
        if (cropped !== scaled) scaled.recycle()
        return cropped
    }
}
