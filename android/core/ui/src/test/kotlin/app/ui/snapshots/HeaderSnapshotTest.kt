package app.ui.snapshots

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.TextFieldValue
import app.designsystem.generated.Tokens
import app.ui.components.CircleButtonStyle
import app.ui.components.CircleIconButton
import app.ui.components.HeaderAction
import app.ui.components.HeaderIconButton
import app.ui.components.PushedHeader
import app.ui.components.RelativeWeekPill
import app.ui.components.ScreenHeader
import app.ui.components.SearchField
import app.ui.components.TabBar
import app.ui.components.TabBarItem
import app.ui.foundation.DsImage
import org.junit.Test

/** C-01 root header, C-02 pushed header, C-03 relative-week pill, C-04 tab bar, C-11 icon buttons. */
class HeaderSnapshotTest(appearance: Appearance) : SnapshotTest(appearance) {
    private val actions = listOf(
        HeaderAction(Tokens.Icons.globalAlbums, "Albums", {}),
        HeaderAction(Tokens.Icons.globalChats, "Messages", {}),
    )

    @Test fun c01TitleOnly() = snap("c01-screen-header", "title") { ScreenHeader("Albums") }

    @Test fun c01TitleWithGlyphs() = snap("c01-screen-header", "glyphs") { ScreenHeader("Week 43", actions = actions) }

    @Test fun c01WithRelativeWeekPill() = snap("c01-screen-header", "relative-week") {
        ScreenHeader("Week 42", actions = actions, accessory = { RelativeWeekPill("Last Week") }, accessoryGap = Tokens.Sizes.globalPillGap)
    }

    @Test fun c01LongTitleWraps() = snap("c01-screen-header", "long-title") { ScreenHeader("Sunday dinners at grandma's", actions = actions) }

    @Test fun c01FontScale200() = snap("c01-screen-header", "font-scale-200", fontScale = 2f) { ScreenHeader("Week 43", actions = actions) }

    @Test fun c02Pushed() = snap("c02-pushed-header", "back-title") { PushedHeader("Friends", onBack = {}, backContentDescription = "Back") }

    @Test fun c02PushedWithGlyphAndSearch() = snap("c02-pushed-header", "glyph-search") {
        PushedHeader(
            "Albums",
            onBack = {},
            backContentDescription = "Back",
            actions = listOf(HeaderAction(Tokens.Icons.globalNewAlbum, "New album", {})),
            below = { SearchField(TextFieldValue(""), {}, placeholder = "Search", accessibilityLabel = "Search albums") },
        )
    }

    @Test fun c03Pill() = snap("c03-relative-week-pill", "last-week", width = null) {
        Box(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin)) { RelativeWeekPill("Last Week") }
    }

    private val tabs = listOf(
        TabBarItem(Tokens.Icons.globalHome, "Home"),
        TabBarItem(Tokens.Icons.globalGroup, "Friends"),
        TabBarItem(Tokens.Icons.globalRewind, "Rewind"),
        TabBarItem(Tokens.Icons.globalActivity, "Activity", unread = true, unreadDescription = "new activity"),
        TabBarItem(Tokens.Icons.globalWall, "Profile"),
    )

    @Test fun c04HomeSelected() = snap("c04-tab-bar", "home-selected") { TabBar(tabs.map { it.copy(unread = false) }, 0, {}) }

    @Test fun c04UnreadActivity() = snap("c04-tab-bar", "unread-dot") { TabBar(tabs, 4, {}) }

    @Test fun c04OverMedia() = snap("c04-tab-bar", "over-photo", surface = Surface.Photo) {
        Box(Modifier.fillMaxWidth().height(Tokens.Sizes.globalFriendCardWidth)) {
            DsImage(landscape(2), null, Modifier.fillMaxWidth().height(Tokens.Sizes.globalFriendCardWidth))
            app.ui.foundation.PhotoScrimOverlay()
            Box(Modifier.align(androidx.compose.ui.Alignment.BottomCenter)) { TabBar(tabs, 2, {}, overMedia = true) }
        }
    }

    @Composable
    private fun CircleRow(content: @Composable () -> Unit) {
        Row(Modifier.padding(horizontal = Tokens.Sizes.globalScreenMargin), horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalCardGap)) { content() }
    }

    @Test fun c11BareGlyphs() = snap("c11-icon-buttons", "bare-glyphs") {
        CircleRow {
            HeaderIconButton(Tokens.Icons.globalAlbums, "Albums", {})
            HeaderIconButton(Tokens.Icons.globalChats, "Messages", {})
            HeaderIconButton(Tokens.Icons.globalMore, "More", {})
            HeaderIconButton(Tokens.Icons.globalBack, "Back", {}, enabled = false)
        }
    }

    @Test fun c11CirclesOnPage() = snap("c11-icon-buttons", "circle-on-page") {
        CircleRow {
            CircleIconButton(Tokens.Icons.globalAdd, "Add", {})
            CircleIconButton(Tokens.Icons.globalClose, "Close", {})
        }
    }

    @Test fun c11CirclesOnMedia() = snap("c11-icon-buttons", "circle-on-media", surface = Surface.Media) {
        CircleRow {
            CircleIconButton(Tokens.Icons.globalClose, "Close", {}, style = CircleButtonStyle.OnMedia)
            CircleIconButton(Tokens.Icons.globalEdit, "Edit", {}, style = CircleButtonStyle.OnMedia)
        }
    }

    @Test fun c11GlassOverPhoto() = snap("c11-icon-buttons", "glass-over-photo", surface = Surface.Photo) {
        Box(Modifier.fillMaxWidth().height(Tokens.Sizes.globalFriendCardWidth / 2 + Tokens.Sizes.globalCircleButtonLarge)) {
            DsImage(landscape(5), null, Modifier.fillMaxWidth().height(Tokens.Sizes.globalFriendCardWidth / 2 + Tokens.Sizes.globalCircleButtonLarge))
            Box(Modifier.padding(Tokens.Sizes.globalScreenMargin)) {
                CircleRow {
                    CircleIconButton(Tokens.Icons.globalMore, "More", {}, style = CircleButtonStyle.Glass)
                    CircleIconButton(Tokens.Icons.globalShare, "Share", {}, style = CircleButtonStyle.GlassLarge)
                    CircleIconButton(Tokens.Icons.globalRandom, "Random", {}, style = CircleButtonStyle.GlassLarge)
                    CircleIconButton(Tokens.Icons.globalClose, "Close", {}, style = CircleButtonStyle.GlassSmall)
                }
            }
        }
    }

}
