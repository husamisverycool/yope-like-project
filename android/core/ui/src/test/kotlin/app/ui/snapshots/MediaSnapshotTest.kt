package app.ui.snapshots

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.input.TextFieldValue
import app.designsystem.generated.Tokens
import app.ui.components.Avatar
import app.ui.components.AvatarStack
import app.ui.components.BlurredBackdrop
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.components.CommentRow
import app.ui.components.FullBleedMediaPage
import app.ui.components.HeaderAction
import app.ui.components.MediaPill
import app.ui.components.NewBadge
import app.ui.components.PageDots
import app.ui.components.PlanCard
import app.ui.components.PlanCardPager
import app.ui.components.PositionPill
import app.ui.components.PremiumPill
import app.ui.components.RecapCard
import app.ui.components.ReplyBar
import app.ui.components.TabBar
import app.ui.components.TabBarItem
import app.ui.components.UnreadDot
import app.ui.components.VideoDurationPill
import app.ui.components.ViewerFooter
import app.ui.components.ViewerHeader
import app.ui.components.ViewerPage
import app.ui.components.ViewerPhoto
import app.ui.foundation.DsImage
import app.ui.system.DsMenuItem
import app.ui.text.TextRoles
import org.junit.Test

/** C-22 viewer, C-23 avatars, C-24 badges, C-25 chips, C-34 backdrop cards, C-35 full-bleed media page. */
class MediaSnapshotTest(appearance: Appearance) : SnapshotTest(appearance) {
    private val menu = listOf(DsMenuItem("Save", {}, Tokens.Icons.globalDownload), DsMenuItem("Delete", {}, Tokens.Icons.globalTrash, destructive = true))

    @Test fun c22Header() = snap("c22-viewer", "header-position", surface = Surface.Media) {
        ViewerHeader("olson", avatar(2), {}, "Close", week = "Week 49", position = "3 of 4", positionDescription = "Photo 3 of 4", menu = menu, moreContentDescription = "More")
    }

    @Test fun c22Page() = snapScreen("c22-viewer", "page", surface = Surface.Media) {
        ViewerPage(
            header = { ViewerHeader("olson", avatar(2), {}, "Close", week = "Week 49", position = "3 of 4", menu = menu, moreContentDescription = "More") },
            photo = { ViewerPhoto(portrait(11), "Photo by olson, Tuesday", {}, {}, "Next", "Previous", previousFraction = PREVIOUS_ZONE) },
            footer = { ViewerFooter(location = "Mexico City", date = "Tuesday, December 5") },
            comments = {
                CommentRow("elton", "so good", avatar(4), Modifier.padding(vertical = Tokens.Sizes.globalScreenMargin), timestamp = "2h")
                ReplyBar(TextFieldValue(""), {}, "Add a comment…", "Comment", avatar(0), trailing = HeaderAction(Tokens.Icons.globalMore, "More", {}))
            },
        )
    }

    @Test fun c23Sizes() = snap("c23-avatars", "sizes") {
        Row(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin), horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillGap), verticalAlignment = Alignment.CenterVertically) {
            listOf(
                Tokens.Sizes.globalAvatarSmall, Tokens.Sizes.globalAvatarList, Tokens.Sizes.globalAvatarComment, Tokens.Sizes.globalAvatarPicker,
                Tokens.Sizes.globalAvatarHeader, Tokens.Sizes.globalAvatarProfile, Tokens.Sizes.globalAvatarGrid,
            ).forEachIndexed { i, size -> Avatar(avatar(i), size) }
        }
    }

    @Test fun c23FallbacksAndStack() = snap("c23-avatars", "fallback-stack") {
        Row(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin), horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalCardGap), verticalAlignment = Alignment.CenterVertically) {
            Avatar(null, Tokens.Sizes.globalAvatarProfile)
            Avatar(null, Tokens.Sizes.globalAvatarProfile, fallbackIcon = Tokens.Icons.globalGroup)
            Avatar(null, Tokens.Sizes.globalAvatarSmall)
            AvatarStack(listOf(avatar(0), avatar(1), avatar(2), null))
        }
    }

    @Test fun c24Badges() = snap("c24-badges", "new-and-dot") {
        Row(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin), horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalCardGap), verticalAlignment = Alignment.CenterVertically) {
            NewBadge("new")
            UnreadDot()
            Box(Modifier.size(Tokens.Sizes.globalStripTileWidth, Tokens.Sizes.globalStripTileHeight).clip(RoundedCornerShape(Tokens.Radii.globalCard))) {
                DsImage(portrait(6), null, Modifier.fillMaxSize())
                NewBadge("new", Modifier.align(Alignment.TopEnd).padding(top = Tokens.Sizes.globalBadgeInset, end = Tokens.Sizes.globalBadgeInset))
            }
        }
    }

    @Test fun c25Chips() = snap("c25-chips", "duration-premium-position", surface = Surface.Photo) {
        Box(Modifier.fillMaxWidth().height(Tokens.Sizes.globalFriendCardWidth)) {
            DsImage(landscape(12), null, Modifier.fillMaxSize())
            Row(Modifier.align(Alignment.Center), horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalPillGap), verticalAlignment = Alignment.CenterVertically) {
                VideoDurationPill("1:00", "One minute video")
                PremiumPill("FREE")
                PositionPill("3 of 4")
            }
        }
    }

    @Test fun c34RecapCard() = snap("c34-backdrop-card", "recap-card", surface = Surface.Photo) {
        Box(Modifier.fillMaxWidth().height(Tokens.Sizes.globalFriendCardHeight + Tokens.Sizes.globalFriendCardWidth / 2)) {
            BlurredBackdrop(portrait(3), blurRadius = Tokens.Sizes.globalScreenMargin * 2)
            Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalScreenMargin)) {
                RecapCard(List(6) { square(it + 10) }, columns = 3, cornerRadius = Tokens.Radii.globalCard, modifier = Modifier.size(Tokens.Sizes.globalFriendCardWidth, Tokens.Sizes.globalFriendCardWidth + Tokens.Sizes.globalButtonHeight), year = "2023", name = "isareyes", domain = "example.app")
                PageDots(3, 0, "Page 1 of 3", onMedia = true)
                MediaPill("Share", {})
            }
        }
    }

    @Test fun c34PlanCards() = snap("c34-backdrop-card", "plan-card-pager", surface = Surface.Photo) {
        Box(Modifier.fillMaxWidth().height(Tokens.Sizes.globalFriendCardHeight)) {
            BlurredBackdrop(portrait(9), blurRadius = Tokens.Sizes.globalScreenMargin * 2)
            CircleIconButton(Tokens.Icons.globalClose, "Close", {}, Modifier.padding(Tokens.Sizes.globalScreenMargin), style = CircleButtonStyle.GlassSmall)
            PlanCardPager(2, Modifier.align(Alignment.Center)) { i, _ ->
                PlanCard(if (i == 0) "Claim" else "Continue", {}) {
                    Text(if (i == 0) "1 Year Free" else "Monthly", style = TextRoles.displaySmall, color = Tokens.Colors.globalTextPrimary)
                    Text("Recaps, Rewind and more for your group.", style = TextRoles.body, color = Tokens.Colors.globalTextPrimary)
                }
            }
        }
    }

    @Test fun c35FullBleed() = snapScreen("c35-full-bleed-media", "rewind", surface = Surface.Media) {
        FullBleedMediaPage(
            photo = story(1),
            photoDescription = "Dinner with the family, May 1, 2019",
            title = "May 1, 2019",
            subtitle = "On this week",
            onTitleClick = {},
            titleClickLabel = "Choose a date",
            menu = menu,
            moreContentDescription = "More",
            leading = HeaderAction(Tokens.Icons.globalShare, "Share", {}),
            trailing = HeaderAction(Tokens.Icons.globalRandom, "Random memory", {}),
            centre = { CircleIconButton(Tokens.Icons.globalPlay, "Play", {}, style = CircleButtonStyle.GlassLarge) },
            tabBar = {
                TabBar(
                    listOf(
                        TabBarItem(Tokens.Icons.globalHome, "Home"),
                        TabBarItem(Tokens.Icons.globalGroup, "Friends"),
                        TabBarItem(Tokens.Icons.globalRewind, "Rewind"),
                        TabBarItem(Tokens.Icons.globalActivity, "Activity"),
                        TabBarItem(Tokens.Icons.globalWall, "Profile"),
                    ),
                    2,
                    {},
                    overMedia = true,
                )
            },
        )
    }

    private companion object {
        /** Test value for the viewer's back zone (the real one is a viewer-spec mechanics value). */
        const val PREVIOUS_ZONE = 0.3f
    }
}
