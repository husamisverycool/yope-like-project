// Surfaces: widget.android (Glance, all sizes) — the Android form of widget.home.small / .medium /
// .large (2×2, 4×2, 4×4 placements of one layout, MERGE_DECISIONS C-20) — and widget.arrival
// (the new image replaces the old one instantly).
// References: references/auto/locket/play/locket-play-01.png, locket-play-02.png, locket-play-04.png;
// references/auto/locket/store/locket-store-03.png (caption pill), locket-store-06.png;
// references/auto/locket/frames/locket-tt-7168613044728155438-15.133s-widget-placeholder-just-added.jpg
// (loading placeholder); Locket APK 1.243.0 res/layout/widget.xml, widget_empty.xml (dp values).
package app.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.ContentScale
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.model.WidgetSnapshot
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * What the widget shows when it has no rendition, decided from its binding and [WidgetGroupMeta]
 * (`widget.android` → States).
 */
sealed interface WidgetEmptyState {
    /** Just added: the newest rendition is being fetched. Up to three member avatars. */
    data class Loading(val members: List<java.io.File?>) : WidgetEmptyState

    /** The configured group has no photo yet. */
    data object NoPhotos : WidgetEmptyState

    /** No group chosen, or the group is gone (left, removed, signed out): tap sets it up. */
    data object NotSetUp : WidgetEmptyState

    companion object {
        fun of(groupId: String?, meta: WidgetGroupMeta): WidgetEmptyState = when {
            groupId == null || !meta.isPrepared(groupId) -> NotSetUp
            meta.content(groupId) == WidgetGroupMeta.Content.NoPhotos -> NoPhotos
            else -> Loading(meta.members(groupId))
        }
    }
}

/**
 * The group photo widget's styling from tokens (`widget.android`): the sender avatar and caption
 * pill over the photo, the loading placeholder, the empty and not-set-up states, and the
 * widget's one TalkBack label. Every value is a `Tokens.*` constant; the empty-state label is not
 * drawn because its color is BLOCKED (`widget.home.small.color.emptyLabel`) — TalkBack still reads it.
 */
object TokenPhotoWidgetSlots : PhotoWidgetSlots {

    @Composable
    override fun Overlay(snapshot: WidgetSnapshot, sizeClass: WidgetSizeClass) {
        // "Bottom row (photo only, not on the collage)".
        if (snapshot.kind != WidgetSnapshot.Kind.Photo) return
        val context = LocalContext.current
        val widgetSize = LocalSize.current
        val store = WidgetFileStore.default(context)
        val margin = Tokens.Sizes.widgetAndroidSizeOverlayMargin
        val avatarSize = Tokens.Sizes.widgetAndroidSizeAvatar
        val gap = Tokens.Sizes.widgetAndroidSizeCaptionGap
        val avatar = WidgetArt.avatar(
            context,
            file = store.avatar(snapshot),
            diameter = avatarSize,
            placeholderTop = Tokens.Colors.widgetAndroidColorAvatarPlaceholderTop,
            placeholderBottom = Tokens.Colors.widgetAndroidColorAvatarPlaceholderBottom,
            ringWidth = Tokens.Sizes.widgetHomeSmallSizeAvatarRing,
            ringColor = Tokens.Colors.widgetHomeSmallColorAvatarRing,
        )
        // The pill truncates at the trailing edge minus the overlay margin.
        val pillMax = WidgetArt.px(context, widgetSize.width - margin - avatarSize - gap - margin)
        val pill = snapshot.caption?.trim()?.takeIf { it.isNotEmpty() }?.let { caption ->
            WidgetArt.captionPill(
                context,
                text = caption,
                maxWidthPx = pillMax,
                height = Tokens.Sizes.widgetHomeSmallSizeCaptionHeight,
                padding = Tokens.Sizes.widgetHomeSmallSizeCaptionPadding,
                fill = Tokens.Colors.widgetHomeSmallColorCaptionPill,
                textColor = Tokens.Colors.globalTextPrimary,
                textSize = Tokens.FontSizes.widgetHomeSmallFontSizeCaption,
                weight = Tokens.FontWeights.widgetHomeSmallFontWeightCaption,
            )
        }
        Box(
            modifier = GlanceModifier.fillMaxSize().padding(start = margin, bottom = margin, end = margin),
            contentAlignment = Alignment.BottomStart,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Image(ImageProvider(avatar), contentDescription = null, modifier = GlanceModifier.size(avatarSize))
                if (pill != null) {
                    Spacer(GlanceModifier.width(gap))
                    Image(ImageProvider(pill.bitmap), contentDescription = null, modifier = GlanceModifier.size(pill.widthDp.dp, pill.heightDp.dp))
                }
            }
        }
    }

    @Composable
    override fun Empty(groupId: String?, sizeClass: WidgetSizeClass) {
        val context = LocalContext.current
        when (val state = WidgetEmptyState.of(groupId, WidgetGroupMeta.of(WidgetFileStore.default(context)))) {
            is WidgetEmptyState.Loading -> LoadingPlaceholder(context, state.members)
            WidgetEmptyState.NoPhotos, WidgetEmptyState.NotSetUp -> EmptyStack(context)
        }
    }

    /** Not set up (no group, or the group is gone) → the configuration activity; else the camera. */
    override fun opensCamera(context: Context, snapshot: WidgetSnapshot?, groupId: String?): Boolean =
        groupId != null && (snapshot != null || WidgetEmptyState.of(groupId, WidgetGroupMeta.of(WidgetFileStore.default(context))) != WidgetEmptyState.NotSetUp)

    override fun contentDescription(context: Context, snapshot: WidgetSnapshot?, groupId: String?): String? {
        if (snapshot == null) {
            return when (WidgetEmptyState.of(groupId, WidgetGroupMeta.of(WidgetFileStore.default(context)))) {
                WidgetEmptyState.NotSetUp -> context.getString(R.string.widget_home_small_empty_setup)
                WidgetEmptyState.NoPhotos -> context.getString(R.string.widget_home_small_empty_nophotos)
                is WidgetEmptyState.Loading -> null
            }
        }
        val group = snapshot.groupName
        if (snapshot.kind == WidgetSnapshot.Kind.Collage) {
            return context.getString(R.string.widget_home_small_a11y_collage, group, collageDate(snapshot))
        }
        val name = snapshot.senderName?.trim()?.split(Regex("\\s+"))?.firstOrNull().orEmpty()
        val caption = snapshot.caption?.trim()?.takeIf { it.isNotEmpty() }
        return if (caption != null) {
            context.getString(R.string.widget_home_small_a11y_photowithcaption, name, group, caption)
        } else {
            context.getString(R.string.widget_home_small_a11y_photo, name, group)
        }
    }

    /** `{date}` of the collage: its day in 'd Month' form (collage.view.title). */
    private fun collageDate(snapshot: WidgetSnapshot): String =
        DateTimeFormatter.ofPattern(COLLAGE_DATE_PATTERN, Locale.getDefault()).format(snapshot.postedAt.atZone(ZoneId.systemDefault()))

    /** collage.view.title: "{date} = daily_invitations.local_date, 'd Month'" ('26 May'). */
    private const val COLLAGE_DATE_PATTERN = "d MMMM"

    /** The loading placeholder with no member avatars (the widget picker's preview). */
    @Composable
    internal fun Placeholder() = LoadingPlaceholder(LocalContext.current, emptyList())

    @Composable
    private fun LoadingPlaceholder(context: Context, members: List<java.io.File?>) {
        val avatars = Tokens.Layouts.WidgetHomeSmallLayoutPlaceholderAvatars
        val diameter: Dp = avatars.diameter.dp
        Box(modifier = GlanceModifier.fillMaxSize(), contentAlignment = Alignment.BottomStart) {
            Image(
                ImageProvider(WidgetArt.verticalGradient(Tokens.Colors.widgetHomeSmallColorPlaceholderTop, Tokens.Colors.widgetHomeSmallColorPlaceholderBottom)),
                contentDescription = null,
                contentScale = ContentScale.FillBounds,
                modifier = GlanceModifier.fillMaxSize(),
            )
            if (members.isNotEmpty()) {
                Row(modifier = GlanceModifier.padding(start = avatars.inset.dp, bottom = avatars.inset.dp)) {
                    members.take(avatars.max.toInt()).forEachIndexed { index, file ->
                        if (index > 0) Spacer(GlanceModifier.width(avatars.gap.dp))
                        val bitmap = WidgetArt.avatar(
                            context,
                            file = file,
                            diameter = diameter,
                            placeholderTop = Tokens.Colors.widgetAndroidColorAvatarPlaceholderTop,
                            placeholderBottom = Tokens.Colors.widgetAndroidColorAvatarPlaceholderBottom,
                            ringWidth = null,
                            ringColor = null,
                        )
                        Image(ImageProvider(bitmap), contentDescription = null, modifier = GlanceModifier.size(diameter))
                    }
                }
            }
        }
    }

    @Composable
    private fun EmptyStack(context: Context) {
        val empty = Tokens.Layouts.WidgetHomeSmallLayoutEmpty
        Box(modifier = GlanceModifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Image(
                ImageProvider(WidgetArt.verticalGradient(Tokens.Colors.widgetHomeSmallColorEmptyTop, Tokens.Colors.widgetHomeSmallColorEmptyBottom)),
                contentDescription = null,
                contentScale = ContentScale.FillBounds,
                modifier = GlanceModifier.fillMaxSize(),
            )
            val stack = WidgetArt.emptyStack(
                context,
                ring = empty.ring.dp,
                ringStroke = empty.ringStroke.dp,
                ringColor = Tokens.Colors.widgetHomeSmallColorEmptyRing,
                circle = empty.circle.dp,
                circleColor = Tokens.Colors.widgetHomeSmallColorEmptyCircle,
                glyph = Tokens.Icons.globalGallery,
                glyphWidth = empty.glyphWidth.dp,
                glyphHeight = empty.glyphHeight.dp,
                glyphColor = Tokens.Colors.globalTextPrimary,
            )
            // The label (empty.label sp, empty.labelGap below) is not drawn: its color is BLOCKED.
            Image(ImageProvider(stack), contentDescription = null, modifier = GlanceModifier.size(empty.ring.dp))
        }
    }
}
