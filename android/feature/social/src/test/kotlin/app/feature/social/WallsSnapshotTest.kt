package app.feature.social

import app.data.model.Collage
import app.data.model.RenderStatus
import app.data.model.WallItem
import app.data.model.WallItemKind
import app.feature.social.FakeSocialData.Companion.ANA
import app.feature.social.FakeSocialData.Companion.BASE
import app.feature.social.FakeSocialData.Companion.GROUP
import app.feature.social.FakeSocialData.Companion.ME
import app.feature.social.walls.BrowseState
import app.feature.social.walls.BrowseViewModel
import app.feature.social.walls.WallMemberContent
import app.feature.social.walls.WallMineContent
import app.feature.social.walls.WallNav
import app.feature.social.walls.WallState
import app.feature.social.walls.WallViewModel
import app.feature.social.walls.WallsBrowseContent
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneOffset

/** walls.mine, walls.member, walls.browse per state; each primary state also in dark. */
class WallsSnapshotTest : SnapshotBase() {
    private val nav = WallNav({}, {}, { _, _, _ -> }, { _, _ -> }, {}, {}, {}, {}, {})
    private val zone = ZoneOffset.UTC

    private fun mine(state: WallState, data: FakeSocialData = FakeSocialData(), dark: Boolean = false) =
        snap(data, dark = dark) { WallMineContent(state, nav, {}, {}, zone = zone, today = TODAY) }

    private fun member(state: WallState, data: FakeSocialData = FakeSocialData(), dark: Boolean = false, menu: Boolean = false, screen: Boolean = false) =
        snap(data, dark = dark, screen = screen) { WallMemberContent(state, ANA, nav, {}, {}, zone = zone, today = TODAY, menuOpen = menu) }

    private fun browse(state: BrowseState, data: FakeSocialData = FakeSocialData(), dark: Boolean = false, query: String = "") =
        snap(data, dark = dark) { WallsBrowseContent(state, nav, {}, {}, initialQuery = query) }

    private fun mineState(): Pair<FakeSocialData, WallState> {
        val data = FakeSocialData().apply { seedWallWeeks(ME) }
        return data to WallViewModel(data, ME).state.value
    }

    @Test fun mineContent() {
        val (data, state) = mineState()
        mine(state, data)
    }

    @Test fun mineContentDark() {
        val (data, state) = mineState()
        mine(state, data, dark = true)
    }

    @Test fun mineLoading() = mine(WallState(person = FakeSocialData.profile(ME, "Sam Rivera")))

    /** No photos at all: the current week (add + seven dated days), then "Welcome to Week 42!" and its CTA. */
    @Test fun mineEmpty() = mine(WallState(phase = WallState.Phase.Ready, person = FakeSocialData.profile(ME, "Sam Rivera")))

    @Test fun mineError() = mine(WallState(phase = WallState.Phase.Error, person = FakeSocialData.profile(ME, "Sam Rivera")))

    /** Offline with nothing cached: the error line (cached sections show as content). */
    @Test fun mineOffline() = mine(WallState(phase = WallState.Phase.OfflineEmpty, person = FakeSocialData.profile(ME, "Sam Rivera")))

    @Test fun memberContent() {
        val data = FakeSocialData().apply { seedWallWeeks(ANA) }
        member(WallViewModel(data, ANA).state.value, data)
    }

    @Test fun memberContentDark() {
        val data = FakeSocialData().apply { seedWallWeeks(ANA) }
        member(WallViewModel(data, ANA).state.value, data, dark = true)
    }

    /** The "•••" capsule's menu: Report Profile · Block Profile (red). */
    @Test fun memberMenu() {
        val data = FakeSocialData().apply { seedWallWeeks(ANA) }
        member(WallViewModel(data, ANA).state.value, data, menu = true, screen = true)
    }

    @Test fun memberEmpty() = member(WallState(phase = WallState.Phase.Ready, person = FakeSocialData.profile(ANA, "Ana Lima")))

    @Test fun memberLoading() = member(WallState(person = FakeSocialData.profile(ANA, "Ana Lima")))

    @Test fun memberError() = member(WallState(phase = WallState.Phase.Error, person = FakeSocialData.profile(ANA, "Ana Lima")))

    private fun browseState(): Pair<FakeSocialData, BrowseState> {
        val data = FakeSocialData().apply { seedPeople() }
        return data to BrowseViewModel(data).state.value
    }

    @Test fun browseContent() {
        val (data, state) = browseState()
        browse(state, data)
    }

    @Test fun browseContentDark() {
        val (data, state) = browseState()
        browse(state, data, dark = true)
    }

    @Test fun browseLoading() = browse(BrowseState())

    @Test fun browseEmpty() = browse(BrowseState(phase = BrowseState.Phase.Ready, alone = true))

    @Test fun browseNoResults() {
        val (data, state) = browseState()
        browse(state.copy(query = "zz"), data, query = "zz")
    }

    @Test fun browseError() = browse(BrowseState(phase = BrowseState.Phase.Error))

    companion object {
        /** Wednesday of ISO week 42 (Monday 12 October 2026). */
        val TODAY: LocalDate = LocalDate.parse("2026-10-14")
    }
}

/** A wall across three weeks: this week Mon + Tue; last week four days; the week before two days and a collage. */
fun FakeSocialData.seedWallWeeks(userId: String) {
    seedGroup()
    val days = listOf("2026-10-12", "2026-10-13", "2026-10-05", "2026-10-07", "2026-10-08", "2026-10-10", "2026-09-29", "2026-10-02")
    val items = days.mapIndexed { i, d ->
        val at = LocalDate.parse(d).atTime(18, 0).toInstant(ZoneOffset.UTC)
        val p = addPhoto("wall-$userId-${i + 1}", userId, at)
        WallItem(WallItemKind.Post, p.id, p.mediaId, null, listOf(GROUP), p.createdAt)
    }.toMutableList()
    collages["c-1"] = Collage("c-1", GROUP, "inv-1", "A", items.take(3).mapNotNull { it.postId }, "g/$GROUP/collages/c-1/1/display-1.jpg", null, null, RenderStatus.Ready, BASE, BASE)
    items += WallItem(WallItemKind.Collage, null, null, "c-1", listOf(GROUP), LocalDate.parse("2026-10-03").atTime(20, 0).toInstant(ZoneOffset.UTC))
    walls[userId] = items.sortedByDescending { it.createdAt }.toMutableList()
}

/** Seven more people sharing groups with me (the Friends grid), with walls for the order approximation. */
fun FakeSocialData.seedPeople() {
    seedGroup()
    val names = listOf("Chloe Martin", "Dev Patel", "Femi Ade", "Grace Kim", "Hugo Silva", "Iris Novak", "Jonah Reyes")
    val extra = names.mapIndexed { i, n -> FakeSocialData.profile("u-x$i", n) }
    extra.forEach { profiles[it.id] = it }
    members[GROUP]?.addAll(extra.mapIndexed { i, p -> app.data.repo.Member(app.data.model.GroupMember(GROUP, p.id, app.data.model.MemberRole.Member, false, BASE.plusSeconds(10L + i)), p) })
}
