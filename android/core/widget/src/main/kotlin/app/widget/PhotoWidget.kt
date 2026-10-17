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
import androidx.datastore.preferences.core.booleanPreferencesKey
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
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.ContentScale
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.size
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.glance.unit.ColorProvider
import app.links.DeepLinkIntents
import app.model.DeepLink
import app.model.DeepLinkCodec
import app.model.WidgetSnapshot
import app.model.WidgetStyle
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
    /**
     * `camera.capture` with [groupId] preselected (`app://camera?group=<id>`, `camera.fromwidget`); null: the camera with
     * nobody preselected (a friend widget or All Groups without a photo yet).
     */
    data class Camera(val groupId: String?) : WidgetTap

    /** The memory in the photo viewer (`widget.memories`: `app://post?group=<id>&post=<id>`). */
    data class Post(val groupId: String, val postId: String) : WidgetTap

    /** The group's same-moment collage the widget shows (its photo of the day): `app://collage?group=<id>&collage=<id>`. */
    data class Collage(val groupId: String, val collageId: String) : WidgetTap

    /** The configuration activity (no group, or the group is gone). */
    data object Configure : WidgetTap

    /** The app itself (signed out: the app opens on sign-in). */
    data object App : WidgetTap
}

/** The home-screen photo widgets the configuration activity sets up (one receiver each, [WidgetLayouts]). */
enum class WidgetKind {
    /** Group Updates (`widget.android`): one group, or All Groups. */
    Group,

    /** Friend Updates (`widget.friend`): one person. */
    Friend,

    /** Your Memories (`widget.memories`): only a style to choose. */
    Memories,
}

/**
 * What the configuration activity chose for a widget: the group ([groupId], or [allGroups]) of a group widget, the
 * person ([personId]) of a friend widget, and every photo widget's [style] (`widget.styles`).
 */
data class WidgetChoice(
    val groupId: String? = null,
    val allGroups: Boolean = false,
    val personId: String? = null,
    val style: WidgetStyle = WidgetStyle.default,
)

/** Per-widget state: which group (or person) a widget shows, and its style. */
object WidgetBinding {
    val GROUP_ID = stringPreferencesKey("group_id")
    /** Bumped whenever the group's rendition changes, so a running Glance session recomposes. */
    val REVISION = longPreferencesKey("revision")
    /** A group widget showing the newest item across every group (`widget.home.small.layout.allGroups`). */
    val ALL_GROUPS = booleanPreferencesKey("all_groups")
    /** The person a friend widget follows (`widget.friend`). */
    val PERSON_ID = stringPreferencesKey("person_id")
    /** The widget's style ([WidgetStyle.wire]; none: Photo). */
    val STYLE = stringPreferencesKey("style")

    private suspend fun stateOf(context: Context, id: GlanceId): Preferences =
        getAppWidgetState(context, PreferencesGlanceStateDefinition, id)

    suspend fun groupOf(context: Context, id: GlanceId): String? = stateOf(context, id)[GROUP_ID]

    /** Binds the widget [appWidgetId] to [groupId] and renders it. */
    suspend fun bind(context: Context, appWidgetId: Int, groupId: String) = bind(context, appWidgetId, WidgetChoice(groupId = groupId))

    /** Binds the widget [appWidgetId] to [choice] (replacing what it showed) and renders it. */
    suspend fun bind(context: Context, appWidgetId: Int, choice: WidgetChoice) {
        val id = GlanceAppWidgetManager(context).getGlanceIdBy(appWidgetId)
        updateAppWidgetState(context, id) {
            if (choice.groupId != null && !choice.allGroups) it[GROUP_ID] = choice.groupId else it.remove(GROUP_ID)
            if (choice.allGroups) it[ALL_GROUPS] = true else it.remove(ALL_GROUPS)
            if (choice.personId != null) it[PERSON_ID] = choice.personId else it.remove(PERSON_ID)
            it[STYLE] = choice.style.wire
            it[REVISION] = (it[REVISION] ?: 0L) + 1
        }
        WidgetLayouts.widgetFor(context, id).update(context, id)
    }

    /** Every placed widget, of every layout, showing [groupId] — All Groups widgets show every group. */
    suspend fun widgetsShowing(context: Context, groupId: String): List<Pair<GlanceAppWidget, GlanceId>> {
        val manager = GlanceAppWidgetManager(context)
        return WidgetLayouts.all.flatMap { layout ->
            manager.getGlanceIds(layout.widgetClass).filter {
                val state = stateOf(context, it)
                state[GROUP_ID] == groupId || state[ALL_GROUPS] == true
            }.map { layout.create() to it }
        }
    }

    /** Groups some placed widget shows (for pruning renditions nobody can see). */
    suspend fun boundGroups(context: Context): Set<String> {
        val manager = GlanceAppWidgetManager(context)
        return WidgetLayouts.all.flatMap { manager.getGlanceIds(it.widgetClass) }.mapNotNull { groupOf(context, it) }.toSet()
    }

    /** Whether an All Groups widget is placed (the app then keeps every group's item up to date). */
    suspend fun hasAllGroups(context: Context): Boolean =
        GlanceAppWidgetManager(context).getGlanceIds(GroupPhotoWidget::class.java).any { stateOf(context, it)[ALL_GROUPS] == true }

    /** The people placed friend widgets follow. */
    suspend fun followedPeople(context: Context): Set<String> =
        GlanceAppWidgetManager(context).getGlanceIds(FriendPhotoWidget::class.java).mapNotNull { stateOf(context, it)[PERSON_ID] }.toSet()

    /** Re-renders every placed widget of every layout (e.g. after sign-out, leaving groups, or premium changing). */
    suspend fun refreshAll(context: Context) {
        val manager = GlanceAppWidgetManager(context)
        for (layout in WidgetLayouts.all) {
            val widget = layout.create()
            for (id in manager.getGlanceIds(layout.widgetClass)) {
                updateAppWidgetState(context, id) { it[REVISION] = (it[REVISION] ?: 0L) + 1 }
            }
            widget.updateAll(context)
        }
    }

    /** Re-renders every widget showing [groupId]. */
    suspend fun refresh(context: Context, groupId: String) {
        for ((widget, id) in widgetsShowing(context, groupId)) {
            updateAppWidgetState(context, id) { it[REVISION] = (it[REVISION] ?: 0L) + 1 }
            widget.update(context, id)
        }
    }

    /** Re-renders every friend widget following [personId]. */
    suspend fun refreshPerson(context: Context, personId: String) {
        val manager = GlanceAppWidgetManager(context)
        for (id in manager.getGlanceIds(FriendPhotoWidget::class.java)) {
            if (stateOf(context, id)[PERSON_ID] != personId) continue
            updateAppWidgetState(context, id) { it[REVISION] = (it[REVISION] ?: 0L) + 1 }
            FriendPhotoWidget().update(context, id)
        }
    }

    /** Re-renders every placed widget of [layout]. */
    suspend fun refreshLayout(context: Context, layout: WidgetLayouts.Layout) {
        val manager = GlanceAppWidgetManager(context)
        val widget = layout.create()
        for (id in manager.getGlanceIds(layout.widgetClass)) {
            updateAppWidgetState(context, id) { it[REVISION] = (it[REVISION] ?: 0L) + 1 }
            widget.update(context, id)
        }
    }
}

/** The widget layouts the app offers. Each has its own GlanceAppWidget + receiver. */
object WidgetLayouts {
    class Layout(
        val widgetClass: Class<out GlanceAppWidget>,
        val create: () -> GlanceAppWidget,
        val kind: WidgetKind = WidgetKind.Group,
        /** The receiver's class name: the provider the launcher names when it opens the configuration activity. */
        val receiverClassName: String? = null,
    )

    val groupPhoto = Layout(GroupPhotoWidget::class.java, ::GroupPhotoWidget, WidgetKind.Group, GroupPhotoWidgetReceiver::class.java.name)
    val friendPhoto = Layout(FriendPhotoWidget::class.java, ::FriendPhotoWidget, WidgetKind.Friend, FriendPhotoWidgetReceiver::class.java.name)
    val memories = Layout(MemoriesWidget::class.java, ::MemoriesWidget, WidgetKind.Memories, MemoriesWidgetReceiver::class.java.name)
    val all: List<Layout> = listOf(groupPhoto, friendPhoto, memories)

    suspend fun widgetFor(context: Context, id: GlanceId): GlanceAppWidget {
        val manager = GlanceAppWidgetManager(context)
        return all.firstOrNull { id in manager.getGlanceIds(it.widgetClass) }?.create?.invoke() ?: GroupPhotoWidget()
    }

    /** Which kind of widget [appWidgetId] is (from its provider); a group widget when unknown. */
    fun kindOf(context: Context, appWidgetId: Int): WidgetKind {
        val provider = runCatching { AppWidgetManager.getInstance(context).getAppWidgetInfo(appWidgetId)?.provider?.className }.getOrNull()
        return all.firstOrNull { it.receiverClassName != null && it.receiverClassName == provider }?.kind ?: WidgetKind.Group
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
                allGroups = state[WidgetBinding.ALL_GROUPS] == true,
                style = WidgetStyle.fromWire(state[WidgetBinding.STYLE]),
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

/**
 * The group photo widget's content. [allGroups]: the newest item across every group this device holds
 * (`widget.home.small.layout.allGroups`), the tap following that item's group. [style] is the widget's chosen style
 * (`widget.styles`): a premium style without premium draws Photo, and the tap opens the paywall first.
 */
@Composable
internal fun PhotoWidgetContent(
    store: WidgetFileStore,
    groupId: String?,
    revision: Long,
    appWidgetId: Int,
    preview: Boolean = false,
    allGroups: Boolean = false,
    style: WidgetStyle = WidgetStyle.default,
) {
    val context = LocalContext.current
    val size = LocalSize.current
    val sizeClass = WidgetSizeClass.of(size)
    val slots = PhotoWidgetSlots.current
    val meta = WidgetGroupMeta.of(store)
    val premium = meta.isPremium()
    val drawn = style.drawn(premium)
    // Reads are keyed by revision: the worker bumps it after every committed write.
    val snapshot = remember(groupId, allGroups, revision) {
        if (allGroups) newestAcross(store) else groupId?.let { runCatching { store.read(it) }.getOrNull() }
    }
    // The group whose item is shown: for All Groups, the item's own group.
    val shownGroup = if (allGroups) snapshot?.groupId else groupId
    val density = context.resources.displayMetrics.density
    val widthPx = (size.width.value * density).roundToInt()
    val heightPx = (size.height.value * density).roundToInt()
    val bitmap = remember(snapshot, widthPx, heightPx, drawn) {
        snapshot?.let { styledPhoto(context, slots, store.photo(it), widthPx, heightPx, drawn) }
    }
    // A preview (widget picker) shows the newest photo, or the loading placeholder; never "set up".
    val emptyGroup = if (preview && snapshot == null) null else groupId

    var modifier = GlanceModifier.fillMaxSize().appWidgetBackground()
    if (!preview) {
        val tap = if (allGroups && snapshot == null) TokenPhotoWidgetSlots.allGroupsTap(context, meta) else slots.tap(context, snapshot, shownGroup)
        modifier = modifier.clickable(widgetTapAction(context, tap, appWidgetId, locked = style.isLocked(premium) && !meta.isSignedOut()))
    }
    val label = if (allGroups && snapshot == null) TokenPhotoWidgetSlots.emptyLabel(context, WidgetEmptyState.ofAllGroups(meta)) else slots.contentDescription(context, snapshot, shownGroup)
    label?.let { modifier = modifier.semantics { contentDescription = it } }
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
            StyleOverlay(drawn, snapshot) { slots.Overlay(snapshot, sizeClass) }
        } else if (preview) {
            PreviewPlaceholder(slots, sizeClass)
        } else if (allGroups) {
            TokenPhotoWidgetSlots.EmptyState(WidgetEmptyState.ofAllGroups(meta))
        } else {
            slots.Empty(emptyGroup, sizeClass)
        }
    }
}

/** The newest item across every group the store holds (All Groups). */
internal fun newestAcross(store: WidgetFileStore): WidgetSnapshot? =
    store.groups().mapNotNull { runCatching { store.read(it) }.getOrNull() }.maxByOrNull { it.postedAtEpochMillis }

/**
 * The photo as [style] draws it at the widget's pixel size: Photo and Date — the photo cropped to the widget with the
 * slots' treatment (the scrim); Frame — the print on its blurred backdrop ([WidgetStyleArt.frame]).
 */
internal fun styledPhoto(context: Context, slots: PhotoWidgetSlots, file: File, widthPx: Int, heightPx: Int, style: WidgetStyle): Bitmap? = when (style) {
    WidgetStyle.Photo, WidgetStyle.Date -> WidgetBitmaps.decodeCropped(file, widthPx, heightPx)?.let { slots.photo(context, it, widthPx) }
    WidgetStyle.Frame -> WidgetStyleArt.frame(context, file, widthPx, heightPx)
}

/**
 * What a style draws over the photo: Photo — the name stack ([stack]); Date — the date title top-leading, then the stack;
 * Frame — nothing (Retro's print carries no text).
 */
@Composable
internal fun StyleOverlay(style: WidgetStyle, snapshot: WidgetSnapshot, stack: @Composable () -> Unit) {
    when (style) {
        WidgetStyle.Photo -> stack()
        WidgetStyle.Date -> {
            DateTitle(snapshot)
            stack()
        }
        WidgetStyle.Frame -> Unit
    }
}

/** The Date style's title (`widget.styles.layout.date`) at the widget's top-leading corner. */
@Composable
private fun DateTitle(snapshot: WidgetSnapshot) {
    val context = LocalContext.current
    val width = LocalSize.current.width
    val title = remember(snapshot, width) { WidgetStyleArt.dateTitle(context, WidgetStyleArt.dateText(snapshot), width) } ?: return
    Box(modifier = GlanceModifier.fillMaxSize(), contentAlignment = Alignment.TopStart) {
        Image(ImageProvider(title.bitmap), contentDescription = null, modifier = GlanceModifier.size(title.widthDp, title.heightDp))
    }
}

/** The loading placeholder (the picker preview has no group). */
@Composable
private fun PreviewPlaceholder(slots: PhotoWidgetSlots, sizeClass: WidgetSizeClass) {
    if (slots === TokenPhotoWidgetSlots) TokenPhotoWidgetSlots.Placeholder() else slots.Empty(null, sizeClass)
}

/**
 * The click action of [tap]. [locked]: the widget's style needs premium the person does not have (`widget.styles` →
 * Locked) — the link becomes `app://premium?perk=widgets&to=…`, which opens the paywall at the widgets perk when the
 * session's one prompt is still available and the widget's own place otherwise. The configuration is never wrapped.
 */
internal fun widgetTapAction(context: Context, tap: WidgetTap, appWidgetId: Int, locked: Boolean = false): Action {
    val link: DeepLink? = when (tap) {
        is WidgetTap.Camera -> DeepLink.Camera(tap.groupId)
        is WidgetTap.Collage -> DeepLink.Collage(tap.groupId, tap.collageId)
        is WidgetTap.Post -> DeepLink.Post(tap.groupId, tap.postId)
        WidgetTap.App, WidgetTap.Configure -> null
    }
    if (locked && tap != WidgetTap.Configure) {
        DeepLinkIntents.intent(context, DeepLink.Premium(DeepLinkCodec.PERK_WIDGETS, link))?.let { return actionStartActivity(it) }
    }
    when (tap) {
        is WidgetTap.Camera, is WidgetTap.Collage, is WidgetTap.Post -> link?.let { DeepLinkIntents.intent(context, it) }?.let { return actionStartActivity(it) }
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
