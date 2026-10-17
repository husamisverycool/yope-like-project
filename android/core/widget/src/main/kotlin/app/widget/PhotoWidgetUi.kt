// Surfaces: widget.android (Glance, every size) — the Android form of widget.home.small / .medium /
// .large (one layout filling 2×2 … 4×4) — and widget.arrival (the new image replaces the old one
// instantly; Glance swaps content without a transition).
// Visual reference: Retro's own Glance widgets (APK 2026.10.1150): references/auto/retro/apk/
// widget_preview_journals.webp (Albums: name over album title — ours: name over group name),
// widget_preview_friends.webp, widget_preview_memories.webp; excerpts §"Glance widget" (22-dp
// corners, state glyph in a 48-dp box tinted white 85 %). Mechanics: Locket (newest photo per
// group, tap → camera). Decisions: design/MERGE_DECISIONS.md RC-9 … RC-11.
package app.widget

import android.content.Context
import android.graphics.Bitmap
import android.os.Build
import android.view.View
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.Dp
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ContentScale
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import app.designsystem.DsAppearance
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.model.WidgetSnapshot
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale

/**
 * What the widget shows when it has no rendition, decided from its binding and [WidgetGroupMeta]
 * (`widget.android` / `widget.home.small` → States).
 */
sealed interface WidgetEmptyState {
    /** Just added (or nothing cached yet): `color.global.backgroundDeep`, no content. */
    data object Loading : WidgetEmptyState

    /** The configured group has no photo yet: state column, `widget.home.small.empty.noPhotos`. */
    data object NoPhotos : WidgetEmptyState

    /** No group chosen, or the group is gone (left, removed): tap → configuration; `empty.setUp`. */
    data object NotSetUp : WidgetEmptyState

    /** Nobody is signed in on this device: tap → the app (sign-in); `empty.signedOut`. */
    data object SignedOut : WidgetEmptyState

    companion object {
        fun of(groupId: String?, meta: WidgetGroupMeta): WidgetEmptyState = when {
            meta.isSignedOut() -> SignedOut
            groupId == null || !meta.isPrepared(groupId) -> NotSetUp
            meta.content(groupId) == WidgetGroupMeta.Content.NoPhotos -> NoPhotos
            else -> Loading
        }

        /**
         * An All Groups widget without an item (`widget.home.small.layout.allGroups`): signed out; no group prepared (none
         * joined, or all left) → not set up; a group still being looked up → loading; else no photos in any group.
         */
        fun ofAllGroups(meta: WidgetGroupMeta): WidgetEmptyState {
            if (meta.isSignedOut()) return SignedOut
            val groups = meta.preparedGroups()
            return when {
                groups.isEmpty() -> NotSetUp
                groups.any { meta.content(it) != WidgetGroupMeta.Content.NoPhotos } -> Loading
                else -> NoPhotos
            }
        }

        /**
         * A friend widget without a photo (`widget.friend` → States): no friend chosen, or they share no group any more /
         * a block → not set up; looked up with nothing to show → no photos; not looked up yet → loading.
         */
        fun ofFriend(personId: String?, slot: WidgetSlotStore.State?, signedOut: Boolean): WidgetEmptyState = when {
            signedOut -> SignedOut
            personId == null || slot == WidgetSlotStore.State.Gone -> NotSetUp
            slot == WidgetSlotStore.State.None -> NoPhotos
            else -> Loading
        }

        /** The memories widget without a photo (`widget.memories` → States): the day looked up with none → empty; else loading. */
        fun ofMemories(slot: WidgetSlotStore.State, signedOut: Boolean): WidgetEmptyState = when {
            signedOut -> SignedOut
            slot == WidgetSlotStore.State.None -> NoPhotos
            else -> Loading
        }
    }
}

/** The state lines of one widget kind (copy keys): "not set up" and "no photos". */
data class WidgetStateLines(val setUp: Int, val noPhotos: Int) {
    companion object {
        /** `widget.home.small.empty.*` (Group Updates, All Groups). */
        val group = WidgetStateLines(R.string.widget_home_small_empty_setup, R.string.widget_home_small_empty_nophotos)

        /** `widget.friend.empty.*`. */
        val friend = WidgetStateLines(R.string.widget_friend_empty_setup, R.string.widget_friend_empty_nophotos)

        /** `widget.memories.empty.none` (a memories widget is never "not set up"). */
        val memories = WidgetStateLines(R.string.widget_home_small_empty_setup, R.string.widget_memories_empty_none)
    }
}

/**
 * The group photo widget's Retro styling from tokens (`widget.android`, anatomy `widget.home.small`):
 * the photo with the bottom scrim, the white name-over-group text stack at the bottom-trailing
 * corner, the state column (camera glyph + one line, white 85 % on black) and the widget's one
 * TalkBack label. Every value is a `Tokens.*` constant. The widget is a media surface: it looks the
 * same in light and dark, so its colours come from `Tokens.ColorsLight` / `Tokens.ColorsDark`
 * through day/night [ColorProvider]s (Glance has no `DsTheme`).
 */
object TokenPhotoWidgetSlots : PhotoWidgetSlots {

    /** `color.global.backgroundDeep` (the states' background), day / night. */
    override val background: ColorProvider
        get() = ColorProvider(day = Tokens.ColorsLight.globalBackgroundDeep, night = Tokens.ColorsDark.globalBackgroundDeep)

    /** The photo with `layout.global.photoScrim` drawn in, rounded on Android < 12 (no `cornerRadius` there). */
    override fun photo(context: Context, photo: Bitmap, widgetWidthPx: Int): Bitmap {
        val scrim = Tokens.Layouts.GlobalPhotoScrim
        val end = WidgetColors.pick(context) { it.globalScrim }
        val withScrim = WidgetArt.withScrim(photo, end.copy(alpha = scrim.startOpacity), end.copy(alpha = scrim.endOpacity), scrim.startAt)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) return withScrim
        // Below Android 12 RemoteViews cannot clip: the corners are cut into the bitmap itself.
        val radiusPx = WidgetArt.px(context, Tokens.Radii.widgetAndroidRadiusWidget) * withScrim.width / widgetWidthPx.coerceAtLeast(1)
        return WidgetArt.rounded(withScrim, radiusPx)
    }

    @Composable
    override fun Overlay(snapshot: WidgetSnapshot, sizeClass: WidgetSizeClass) {
        val context = LocalContext.current
        val widgetSize = LocalSize.current
        val overlay = Tokens.Layouts.WidgetHomeSmallLayoutOverlay
        // Line 1 the poster's first name, line 2 the group name; a collage: the group name alone.
        val lines = if (snapshot.kind == WidgetSnapshot.Kind.Collage) {
            listOf(snapshot.groupName)
        } else {
            listOfNotNull(firstName(snapshot.senderName), snapshot.groupName)
        }.map(String::trim).filter(String::isNotEmpty)
        if (lines.isEmpty()) return
        // Each line truncates at the leading inset `size.global.screenMargin`.
        val widthPx = WidgetArt.px(context, widgetSize.width - Tokens.Sizes.globalScreenMargin)
        val stack = WidgetArt.textStack(
            context,
            lines = lines,
            widthPx = widthPx,
            trailingInset = Dp(overlay.trailingInset),
            lastBaselineFromBottom = Dp(overlay.lastBaselineFromBottom),
            linePitch = Dp(overlay.linePitch),
            textSize = Tokens.FontSizes.widgetHomeSmallFontSizeOverlay,
            weight = Tokens.FontWeights.widgetHomeSmallFontWeightOverlay,
            color = WidgetColors.pick(context) { it.globalTextOnMedia },
            rtl = context.resources.configuration.layoutDirection == View.LAYOUT_DIRECTION_RTL,
        ) ?: return
        Box(modifier = GlanceModifier.fillMaxSize(), contentAlignment = Alignment.BottomEnd) {
            Image(
                ImageProvider(stack.bitmap),
                contentDescription = null,
                modifier = GlanceModifier.size(stack.widthDp, stack.heightDp),
            )
        }
    }

    @Composable
    override fun Empty(groupId: String?, sizeClass: WidgetSizeClass) {
        val context = LocalContext.current
        EmptyState(WidgetEmptyState.of(groupId, WidgetGroupMeta.of(WidgetFileStore.default(context))))
    }

    /** [state] drawn (`widget.home.small` → States) with [lines]' copy; signed out is shared by every kind. */
    @Composable
    internal fun EmptyState(state: WidgetEmptyState, lines: WidgetStateLines = WidgetStateLines.group) {
        val context = LocalContext.current
        when (state) {
            WidgetEmptyState.Loading -> StateBackground()
            WidgetEmptyState.NoPhotos -> StateColumn(context.getString(lines.noPhotos))
            WidgetEmptyState.NotSetUp -> StateColumn(context.getString(lines.setUp))
            WidgetEmptyState.SignedOut -> StateColumn(context.getString(R.string.widget_home_small_empty_signedout))
        }
    }

    /** The one TalkBack label of [state] (the state line; none while loading). */
    internal fun emptyLabel(context: Context, state: WidgetEmptyState, lines: WidgetStateLines = WidgetStateLines.group): String? = when (state) {
        WidgetEmptyState.NotSetUp -> context.getString(lines.setUp)
        WidgetEmptyState.NoPhotos -> context.getString(lines.noPhotos)
        WidgetEmptyState.SignedOut -> context.getString(R.string.widget_home_small_empty_signedout)
        WidgetEmptyState.Loading -> null
    }

    /** An All Groups widget's tap without an item: signed out → the app; not set up → configuration; else the camera. */
    internal fun allGroupsTap(context: Context, meta: WidgetGroupMeta = WidgetGroupMeta.of(WidgetFileStore.default(context))): WidgetTap =
        when (WidgetEmptyState.ofAllGroups(meta)) {
            WidgetEmptyState.SignedOut -> WidgetTap.App
            WidgetEmptyState.NotSetUp -> WidgetTap.Configure
            WidgetEmptyState.Loading, WidgetEmptyState.NoPhotos -> WidgetTap.Camera(null)
        }

    override fun tap(context: Context, snapshot: WidgetSnapshot?, groupId: String?): WidgetTap {
        val meta = WidgetGroupMeta.of(WidgetFileStore.default(context))
        return when {
            meta.isSignedOut() -> WidgetTap.App
            groupId == null -> WidgetTap.Configure
            // the collage of the day opens that collage; a photo opens the camera (camera.fromwidget)
            snapshot != null && snapshot.kind == WidgetSnapshot.Kind.Collage && snapshot.sourceId != null -> WidgetTap.Collage(groupId, snapshot.sourceId!!)
            snapshot != null -> WidgetTap.Camera(groupId)
            WidgetEmptyState.of(groupId, meta) == WidgetEmptyState.NotSetUp -> WidgetTap.Configure
            else -> WidgetTap.Camera(groupId)
        }
    }

    override fun contentDescription(context: Context, snapshot: WidgetSnapshot?, groupId: String?): String? {
        if (snapshot == null) return emptyLabel(context, WidgetEmptyState.of(groupId, WidgetGroupMeta.of(WidgetFileStore.default(context))))
        val group = snapshot.groupName
        if (snapshot.kind == WidgetSnapshot.Kind.Collage) {
            return context.getString(R.string.widget_home_small_a11y_collage, group, collageDate(snapshot))
        }
        return context.getString(R.string.widget_home_small_a11y_photo, firstName(snapshot.senderName).orEmpty(), group)
    }

    /** The first word of `display_name` (`widget.home.small.layout.overlay` line 1). */
    internal fun firstName(displayName: String?): String? =
        displayName?.trim()?.split(Regex("\\s+"))?.firstOrNull()?.takeIf { it.isNotEmpty() }

    /** `{date}` of the collage: the invitation day in the locale's long date form (collage.view.title). */
    private fun collageDate(snapshot: WidgetSnapshot): String =
        DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(Locale.getDefault())
            .format(snapshot.postedAt.atZone(ZoneId.systemDefault()))

    /** The loading placeholder (the widget picker's preview without content). */
    @Composable
    internal fun Placeholder() = StateBackground()

    /** `color.global.backgroundDeep` edge to edge, no content (the loading state); the countdown widget's states too. */
    @Composable
    internal fun StateBackground(content: @Composable () -> Unit = {}) {
        val context = LocalContext.current
        val size = LocalSize.current
        var modifier = GlanceModifier.fillMaxSize()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) modifier = modifier.background(background)
        Box(modifier = modifier, contentAlignment = Alignment.Center) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                // Below Android 12 the rounded background is a bitmap (RemoteViews cannot clip).
                Image(
                    ImageProvider(
                        WidgetArt.roundedFill(
                            context,
                            width = size.width,
                            height = size.height,
                            radius = Tokens.Radii.widgetAndroidRadiusWidget,
                            color = WidgetColors.pick(context) { it.globalBackgroundDeep },
                        ),
                    ),
                    contentDescription = null,
                    contentScale = ContentScale.FillBounds,
                    modifier = GlanceModifier.fillMaxSize(),
                )
            }
            content()
        }
    }

    /**
     * The state column (`widget.home.small` → States): [icon] (`icon.global.camera`; the countdown widget's
     * `icon.global.calendar`) at `size.global.icon` in a `size.global.minTouchTarget.android` box (its padding the
     * difference, 12 dp), then the [line] (none: the glyph alone) in `widget.home.small.fontSize.overlay`, both tinted
     * `widget.home.small.color.stateTint`, centred, up to 2 lines.
     */
    @Composable
    internal fun StateColumn(line: String?, icon: ImageVector = Tokens.Icons.globalCamera) {
        val context = LocalContext.current
        val tint = WidgetColors.pick(context) { it.widgetHomeSmallColorStateTint }
        val box = Tokens.Sizes.globalMinTouchTargetAndroid
        val glyph = WidgetArt.glyph(context, icon, box = box, glyph = Tokens.Sizes.globalIcon, color = tint)
        StateBackground {
            Column(
                modifier = GlanceModifier.fillMaxSize().padding(horizontal = Tokens.Sizes.globalScreenMargin),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Image(ImageProvider(glyph), contentDescription = null, modifier = GlanceModifier.size(box))
                if (line != null) Text(
                    line,
                    maxLines = STATE_MAX_LINES,
                    style = TextStyle(
                        color = ColorProvider(day = Tokens.ColorsLight.widgetHomeSmallColorStateTint, night = Tokens.ColorsDark.widgetHomeSmallColorStateTint),
                        fontSize = Tokens.FontSizes.widgetHomeSmallFontSizeOverlay,
                        fontWeight = WidgetArt.glanceWeight(Tokens.FontWeights.widgetHomeSmallFontWeightOverlay),
                        textAlign = TextAlign.Center,
                    ),
                )
            }
        }
    }

    /** "centred, up to 2 lines" (`widget.home.small` → States). */
    private const val STATE_MAX_LINES = 2 // provenance-ok: line count from the spec text, not a size
}

/** The widget's colours outside composition: `Tokens.ColorsLight` / `Tokens.ColorsDark` by the context's appearance. */
internal object WidgetColors {
    fun <T> pick(context: Context, read: (Palette) -> T): T =
        if (DsAppearance.isDark(context)) read(Palette.Dark) else read(Palette.Light)

    /** The two generated palettes behind one reader. */
    sealed interface Palette {
        val globalBackgroundDeep: androidx.compose.ui.graphics.Color
        val globalScrim: androidx.compose.ui.graphics.Color
        val globalTextOnMedia: androidx.compose.ui.graphics.Color
        val widgetHomeSmallColorStateTint: androidx.compose.ui.graphics.Color
        val globalBackdropDim: androidx.compose.ui.graphics.Color
        val widgetStylesColorFrame: androidx.compose.ui.graphics.Color

        data object Light : Palette {
            override val globalBackgroundDeep get() = Tokens.ColorsLight.globalBackgroundDeep
            override val globalScrim get() = Tokens.ColorsLight.globalScrim
            override val globalTextOnMedia get() = Tokens.ColorsLight.globalTextOnMedia
            override val widgetHomeSmallColorStateTint get() = Tokens.ColorsLight.widgetHomeSmallColorStateTint
            override val globalBackdropDim get() = Tokens.ColorsLight.globalBackdropDim
            override val widgetStylesColorFrame get() = Tokens.ColorsLight.widgetStylesColorFrame
        }

        data object Dark : Palette {
            override val globalBackgroundDeep get() = Tokens.ColorsDark.globalBackgroundDeep
            override val globalScrim get() = Tokens.ColorsDark.globalScrim
            override val globalTextOnMedia get() = Tokens.ColorsDark.globalTextOnMedia
            override val widgetHomeSmallColorStateTint get() = Tokens.ColorsDark.widgetHomeSmallColorStateTint
            override val globalBackdropDim get() = Tokens.ColorsDark.globalBackdropDim
            override val widgetStylesColorFrame get() = Tokens.ColorsDark.widgetStylesColorFrame
        }
    }
}
