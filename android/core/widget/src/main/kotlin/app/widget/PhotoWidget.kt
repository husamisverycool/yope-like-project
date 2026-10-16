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
import app.designsystem.generated.Tokens
import java.io.File
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Styling around the photo comes from tokens ([TokenPhotoWidgetSlots], surface `widget.android`);
 * nothing here invents a value. The interface's own defaults draw only the photo.
 */
interface PhotoWidgetSlots {
    /** Drawn over the photo (the text stack …) for the given size class. */
    @Composable fun Overlay(snapshot: WidgetSnapshot, sizeClass: WidgetSizeClass) {}

    /** Shown when the widget has no rendition: loading, empty, not set up, signed out. */
    @Composable fun Empty(groupId: String?, sizeClass: WidgetSizeClass) {}

    /** Behind everything (the states' background); null draws nothing. */
    val background: ColorProvider? get() = null

    /**
     * The decoded photo (already cropped to the widget's aspect) as the widget shows it, e.g. with
     * a scrim drawn in. [widgetWidthPx] is the widget's width in pixels (the photo may be smaller).
     */
    fun photo(context: Context, photo: Bitmap, widgetWidthPx: Int): Bitmap = photo

    /** The widget's one TalkBack label (the whole widget is one element). Default: the caption. */
    fun contentDescription(context: Context, snapshot: WidgetSnapshot?, groupId: String?): String? = snapshot?.caption

    /** Where a tap goes (`camera.fromwidget`). Default: the camera whenever a group is bound. */
    fun tap(context: Context, snapshot: WidgetSnapshot?, groupId: String?): WidgetTap =
        if (groupId != null) WidgetTap.Camera(groupId) else WidgetTap.Configure

    companion object {
        /** The token styling; replaceable (tests). */
        @Volatile var current: PhotoWidgetSlots = TokenPhotoWidgetSlots
    }
}

/** What tapping the widget opens. */
sealed interface WidgetTap {
    /** `camera.capture` with [groupId] preselected (`app://camera?group=<id>`, `camera.fromwidget`). */
    data class Camera(val groupId: String) : WidgetTap

    /** The configuration activity (no group, or the group is gone). */
    data object Configure : WidgetTap

    /** The app itself (signed out: the app opens on sign-in). */
    data object App : WidgetTap
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
        snapshot?.let { WidgetBitmaps.decodeCropped(store.photo(it), widthPx, heightPx) }?.let { slots.photo(context, it, widthPx) }
    }
    // A preview (widget picker) shows the newest photo, or the loading placeholder; never "set up".
    val emptyGroup = if (preview && snapshot == null) null else groupId

    var modifier = GlanceModifier.fillMaxSize().appWidgetBackground()
    if (!preview) modifier = modifier.clickable(tapAction(context, slots.tap(context, snapshot, groupId), appWidgetId))
    slots.contentDescription(context, snapshot, groupId)?.let { label -> modifier = modifier.semantics { contentDescription = label } }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        // `widget.android.radius.widget` on the root (Android 12+ clips children to it); below 12
        // the slots cut the corners into their bitmaps.
        modifier = modifier.cornerRadius(Tokens.Radii.widgetAndroidRadiusWidget)
    }

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

/** The loading placeholder (the picker preview has no group). */
@Composable
private fun PreviewPlaceholder(slots: PhotoWidgetSlots, sizeClass: WidgetSizeClass) {
    if (slots === TokenPhotoWidgetSlots) TokenPhotoWidgetSlots.Placeholder() else slots.Empty(null, sizeClass)
}

private fun tapAction(context: Context, tap: WidgetTap, appWidgetId: Int): Action {
    when (tap) {
        is WidgetTap.Camera -> DeepLinkIntents.intent(context, DeepLink.Camera(tap.groupId))?.let { return actionStartActivity(it) }
        WidgetTap.App -> context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { return actionStartActivity(it) }
        WidgetTap.Configure -> Unit
    }
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

    /**
     * Crops the centre of [src] to the [w]×[h] aspect (what ContentScale.Crop shows) and scales it
     * down to [w]×[h] when larger. Never upscales: Glance scales a smaller bitmap to fill. The
     * result always has the widget's aspect, so whatever the slots draw into it lines up.
     */
    fun centerCrop(src: Bitmap, w: Int, h: Int): Bitmap {
        val target = w.toFloat() / h
        val cropW = min(src.width, (src.height * target).roundToInt()).coerceAtLeast(1)
        val cropH = min(src.height, (src.width / target).roundToInt()).coerceAtLeast(1)
        val cropped = if (cropW == src.width && cropH == src.height) src else Bitmap.createBitmap(src, (src.width - cropW) / 2, (src.height - cropH) / 2, cropW, cropH)
        if (cropped !== src) src.recycle()
        if (cropped.width <= w) return cropped
        val scaled = Bitmap.createScaledBitmap(cropped, w, h, true)
        if (scaled !== cropped) cropped.recycle()
        return scaled
    }
}
