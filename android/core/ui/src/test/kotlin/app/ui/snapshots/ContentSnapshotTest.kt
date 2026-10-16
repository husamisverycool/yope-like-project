package app.ui.snapshots

import androidx.compose.foundation.layout.Column
import androidx.compose.ui.Modifier
import app.designsystem.generated.Tokens
import app.ui.components.Capsule
import app.ui.components.CapsuleStyle
import app.ui.components.DayTile
import app.ui.components.FriendCard
import app.ui.components.FriendCardPager
import app.ui.components.FriendCardSpec
import app.ui.components.GridCell
import app.ui.components.HeaderAction
import app.ui.components.PeopleGrid
import app.ui.components.PeopleRow
import app.ui.components.PersonCell
import app.ui.components.PhotoGrid
import app.ui.components.ProfileAction
import app.ui.components.ProfileHeader
import app.ui.components.ProfileInfo
import app.ui.components.SectionHeader
import app.ui.components.ThumbnailRow
import app.ui.components.ThumbnailRowSpacing
import app.ui.components.WeekSection
import app.ui.components.WeekStrip
import app.ui.components.WeekStripOrder
import app.ui.components.subtitleWithActor
import app.ui.system.DsMenuItem
import org.junit.Test

/** C-15 thumbnail row, C-16 people row, C-17 week strip, C-18 friend card, C-19 profile header, C-20 section header, C-21 grids. */
class ContentSnapshotTest(appearance: Appearance) : SnapshotTest(appearance) {
    private val add = HeaderAction(Tokens.Icons.globalAdd, "Add photos", {})

    @Test fun c15Rows() = snap("c15-thumbnail-row", "rows") {
        Column(verticalArrangement = ThumbnailRowSpacing) {
            ThumbnailRow("Mexico City", subtitleWithActor("daniel shared photos", "daniel"), portrait(1), {}, avatars = listOf(avatar(0), avatar(1), avatar(2)), add = add)
            ThumbnailRow("Sunday dinners", subtitleWithActor("ana added you", "ana"), portrait(4), {}, add = add)
            ThumbnailRow("Roomies", null, null, {})
        }
    }

    @Test fun c16Request() = snap("c16-people-row", "request") {
        PeopleRow("elton", avatar(4), line = "Elton Cah", actions = {
            Capsule("Accept", {}, Modifier.weight(1f), style = CapsuleStyle.Primary)
            Capsule("Decide Later", {}, Modifier.weight(1f))
        })
    }

    @Test fun c16MemberAndUnread() = snap("c16-people-row", "member-unread") {
        Column(verticalArrangement = ThumbnailRowSpacing) {
            PeopleRow("isareyes", avatar(5), line = "Isabel Reyes", onClick = {})
            PeopleRow("daniel", avatar(6), line = "shared photos", timestamp = "2h", unread = true, onClick = {})
            PeopleRow("olson", null, line = "Ola Olson", onClick = {})
        }
    }

    @Test fun c16Comment() = snap("c16-people-row", "comment", surface = Surface.Media) {
        PeopleRow("elton", avatar(4), line = "so good", timestamp = "2h", avatarSize = Tokens.Sizes.globalAvatarComment, onMedia = true)
    }

    private fun weekDays(withPhotos: Boolean): List<DayTile> = listOf("Mon", "Tue", "Wed", "Thu", "Fri").mapIndexed { i, d ->
        if (withPhotos && i % 2 == 0) {
            DayTile.Photo("p$i", portrait(i), d, "$d, October ${20 + i}, photo", onClick = {})
        } else {
            DayTile.Empty("e$i", "Oct", "${20 + i}", d, "$d, October ${20 + i}, no photos", onClick = {})
        }
    }

    @Test fun c17Populated() = snap("c17-week-strip", "populated-add-last") {
        WeekStrip(WeekStripOrder.withAdd(weekDays(withPhotos = true), DayTile.Add("Add a photo", {})))
    }

    @Test fun c17EmptyWeek() = snap("c17-week-strip", "empty-add-first") {
        WeekStrip(WeekStripOrder.withAdd(weekDays(withPhotos = false), DayTile.Add("Add a photo", {})))
    }

    @Test fun c17Placeholders() = snap("c17-week-strip", "placeholder-loading") { WeekStrip(List(4) { DayTile.Placeholder("ph$it") }) }

    @Test fun c17SinglePhoto() = snap("c17-week-strip", "single-tile") { WeekStrip(listOf(DayTile.Photo("only", portrait(7), "Sun", "Sunday, October 26, photo"))) }

    @Test fun c17FontScale150() = snap("c17-week-strip", "font-scale-150", fontScale = 1.5f) {
        WeekStrip(WeekStripOrder.withAdd(weekDays(withPhotos = true), DayTile.Add("Add a photo", {})))
    }

    @Test fun c18CardWithBadge() = snap("c18-friend-card", "new-badge", width = null) {
        Column(Modifier) { FriendCard("olson", avatar(2), card(3), "olson's week, new photos", {}, badge = "new") }
    }

    @Test fun c18CardSeen() = snap("c18-friend-card", "no-badge", width = null) { FriendCard("isareyes", null, card(9), "isareyes's week", {}) }

    @Test fun c18Pager() = snap("c18-friend-card", "pager") {
        FriendCardPager(
            listOf(
                FriendCardSpec("a", "olson", avatar(2), card(3), "olson's week, new photos", {}, badge = "new"),
                FriendCardSpec("b", "isareyes", avatar(3), card(10), "isareyes's week", {}),
            ),
        )
    }

    @Test fun c19Full() = snap("c19-profile-header", "full") {
        ProfileHeader(
            name = "isareyes",
            avatar = avatar(3),
            avatarDescription = "Isabel Reyes",
            realName = "Isabel Reyes",
            info = listOf(
                ProfileInfo(Tokens.Icons.globalLocation, "Mexico City"),
                ProfileInfo(Tokens.Icons.globalCalendar, "Joined June 2024"),
                ProfileInfo(Tokens.Icons.globalCamera, "Last photo Tuesday"),
            ),
            actions = listOf(ProfileAction("Recaps", {}), ProfileAction("Share Profile", {})),
            settings = HeaderAction(Tokens.Icons.globalSettings, "Settings", {}),
        )
    }

    @Test fun c19Minimal() = snap("c19-profile-header", "minimal") { ProfileHeader(name = "olson", avatar = null, avatarDescription = "olson") }

    private val weekMenu = listOf(DsMenuItem("Share Week", {}, Tokens.Icons.globalShare), DsMenuItem("Delete", {}, Tokens.Icons.globalTrash, destructive = true))

    @Test fun c20WeekRange() = snap("c20-section-header", "week-range") {
        SectionHeader("Week 27", range = "Jul 3 - 9", accessibilityLabel = "Week 27, July 3 to 9", menu = weekMenu, moreContentDescription = "More")
    }

    @Test fun c20CurrentWeek() = snap("c20-section-header", "current-week") { SectionHeader("Week 43", menu = weekMenu, moreContentDescription = "More") }

    @Test fun c20Dated() = snap("c20-section-header", "dated") { SectionHeader("January 25, 2024", menu = weekMenu, moreContentDescription = "More") }

    @Test fun c21WeekList() = snap("c21-grids", "week-list") {
        Column {
            WeekSection("Week 43", WeekStripOrder.withAdd(weekDays(withPhotos = true), DayTile.Add("Add a photo", {})), menu = weekMenu, moreContentDescription = "More")
            WeekSection("Week 42", weekDays(withPhotos = true).filterIsInstance<DayTile.Photo>(), range = "Oct 13 - 19", menu = weekMenu, moreContentDescription = "More", afterContent = true)
        }
    }

    @Test fun c21AlbumGrid() = snap("c21-grids", "album-grid-3") {
        Column {
            SectionHeader("January 25, 2024", menu = weekMenu, moreContentDescription = "More")
            PhotoGrid(List(7) { GridCell(it, square(it), "Photo $it", {}) }, columns = 3)
        }
    }

    @Test fun c21PickerGrid() = snap("c21-grids", "picker-grid-4") { PhotoGrid(List(8) { GridCell(it, square(it + 3), "Photo $it", {}) }, columns = 4, contentPadding = Tokens.Radii.globalPhoto) }

    @Test fun c21PeopleGrid() = snap("c21-grids", "people-grid") { PeopleGrid(List(5) { PersonCell(it, listOf("olson", "isareyes", "daniel", "elton", "ana")[it], if (it == 4) null else avatar(it), {}) }) }
}
