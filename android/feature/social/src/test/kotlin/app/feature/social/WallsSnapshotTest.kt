package app.feature.social

import app.data.model.Profile
import app.feature.social.FakeSocialData.Companion.ANA
import app.feature.social.FakeSocialData.Companion.ME
import app.feature.social.walls.BrowsePerson
import app.feature.social.walls.BrowseState
import app.feature.social.walls.BrowseViewModel
import app.feature.social.walls.WallMemberContent
import app.feature.social.walls.WallMineContent
import app.feature.social.walls.WallNav
import app.feature.social.walls.WallState
import app.feature.social.walls.WallViewModel
import app.feature.social.walls.WallsBrowseContent
import org.junit.Test

/** walls.mine, walls.member, walls.browse per state. */
class WallsSnapshotTest : SnapshotBase() {
    private val nav = WallNav({}, {}, { _, _, _ -> }, { _, _ -> }, {}, {})

    @Test fun mineContent() {
        val data = FakeSocialData().apply { seedWall(ME, 14) }
        val vm = WallViewModel(data, ME)
        snap(data) { WallMineContent(vm.state.value, null, nav) }
    }

    @Test fun mineLoading() = snap { WallMineContent(WallState(), null, nav) }
    @Test fun mineEmpty() = snap { WallMineContent(WallState(phase = WallState.Phase.Ready), null, nav) }
    @Test fun mineError() = snap { WallMineContent(WallState(phase = WallState.Phase.Error), null, nav) }
    @Test fun mineOffline() = snap { WallMineContent(WallState(phase = WallState.Phase.OfflineEmpty), null, nav) }

    @Test fun memberContent() {
        val data = FakeSocialData().apply { seedWall(ANA, 8) }
        val vm = WallViewModel(data, ANA)
        snap(data) { WallMemberContent(vm.state.value, null, nav) }
    }

    @Test fun memberEmpty() {
        val ana = FakeSocialData.profile(ANA, "Ana Lima")
        snap { WallMemberContent(WallState(phase = WallState.Phase.Ready, person = ana), null, nav) }
    }

    @Test fun memberLoading() = snap { WallMemberContent(WallState(person = FakeSocialData.profile(ANA, "Ana Lima")), null, nav) }

    @Test fun memberError() = snap { WallMemberContent(WallState(phase = WallState.Phase.Error, person = FakeSocialData.profile(ANA, "Ana Lima")), null, nav) }

    @Test fun browseContent() {
        val data = FakeSocialData().apply { seedWall(ME, 10) }
        repeat(4) { i -> data.profiles["u-x$i"] = FakeSocialData.profile("u-x$i", listOf("Chloe Park", "Dev Shah", "Our band group", "Femi Ade")[i]) }
        data.members[FakeSocialData.GROUP]!!.addAll(data.profiles.values.filter { it.id.startsWith("u-x") }.map { p ->
            app.data.repo.Member(app.data.model.GroupMember(FakeSocialData.GROUP, p.id, app.data.model.MemberRole.Member, false, FakeSocialData.BASE), p)
        })
        val vm = BrowseViewModel(data)
        val loader = vm.wall.value!!
        snap(data) { WallsBrowseContent(vm.state.value, loader, loader.state.value, nav, {}, {}) }
    }

    @Test fun browseAlone() {
        val me = FakeSocialData.profile(ME, "Sam Rivera")
        snap { WallsBrowseContent(BrowseState(phase = BrowseState.Phase.Ready, people = listOf(BrowsePerson(me, true)), selected = ME, alone = true), null, WallState(phase = WallState.Phase.Ready), nav, {}, {}) }
    }

    @Test fun browseLoading() = snap { WallsBrowseContent(BrowseState(), null, WallState(), nav, {}, {}) }

    @Test fun browseError() = snap { WallsBrowseContent(BrowseState(phase = BrowseState.Phase.Error), null, WallState(), nav, {}, {}) }

    @Suppress("unused")
    private fun person(p: Profile) = BrowsePerson(p, false)
}
