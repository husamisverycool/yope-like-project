package app.feature.account

import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.error.ApiError
import app.data.error.DataError
import app.data.model.GroupKind
import app.data.model.MemberRole
import app.data.realtime.GroupEvent
import app.designsystem.generated.Tokens
import app.feature.account.groups.CreateError
import app.feature.account.groups.FeedItem
import app.feature.account.groups.GroupActions
import app.feature.account.groups.GroupCreateViewModel
import app.feature.account.groups.GroupFeedViewModel
import app.feature.account.groups.GroupInviteViewModel
import app.feature.account.groups.GroupSettingsViewModel
import app.feature.account.groups.GroupsListViewModel
import app.feature.account.groups.RowSubtitle
import app.feature.account.groups.SettingsSection
import app.feature.account.testing.FakeAccountBackend
import app.feature.account.testing.fakeEnvironment
import app.model.AppRoute
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import app.feature.account.common.AccountEvent
import app.designsystem.R
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.time.Duration
import java.time.LocalTime

@RunWith(AndroidJUnit4::class)
class GroupsViewModelsTest {
    @get:Rule val main = MainDispatcherRule()

    @After fun clearProcessCache() = GroupsListViewModel.Details.byGroup.clear()

    /** Me + Sam in "Sunday dinners" (with posts) and me alone in "Roomies" (none). */
    private fun world() = FakeAccountBackend().apply {
        signIn()
        profile(meId, "Ana Lima")
        profile("u-sam", "Sam Lee")
        group("g1", "Sunday dinners", createdAt = now.minus(Duration.ofDays(9)))
        member("g1", meId, MemberRole.Admin)
        member("g1", "u-sam", joinedAt = now.minus(Duration.ofDays(8)))
        post("g1", meId, now.minus(Duration.ofHours(5)))
        post("g1", "u-sam", now.minus(Duration.ofHours(2)), caption = "dinner")
        group("g2", "Roomies", GroupKind.Roommates, createdAt = now.minus(Duration.ofDays(1)))
        member("g2", meId, MemberRole.Admin)
    }

    // groups.list -----------------------------------------------------------------------------------

    @Test fun listShowsNewestActivityFirstWithSubtitles() = runTest(main.dispatcher) {
        val vm = GroupsListViewModel(fakeEnvironment(world()))
        val rows = vm.state.value.rows!!
        assertEquals(listOf("g1", "g2"), rows.map { it.id })
        assertEquals("Sam", (rows[0].subtitle as RowSubtitle.SentPic).firstName)
        assertEquals(RowSubtitle.NoPics, rows[1].subtitle)
        assertEquals("g1", vm.state.value.cover!!.groupId)
    }

    @Test fun ownNewestPostReadsNewPic() = runTest(main.dispatcher) {
        val backend = world().apply { post("g1", meId, now.minus(Duration.ofMinutes(5))) }
        val vm = GroupsListViewModel(fakeEnvironment(backend))
        assertTrue(vm.state.value.rows!!.first().subtitle is RowSubtitle.NewPic)
    }

    @Test fun emptyErrorAndOfflineWithCache() = runTest(main.dispatcher) {
        val empty = FakeAccountBackend().apply { signIn() }
        assertEquals(emptyList<Any>(), GroupsListViewModel(fakeEnvironment(empty)).state.value.rows)

        val failing = FakeAccountBackend().apply { signIn(); failures["myGroups"] = DataError.Unexpected("x") }
        val error = GroupsListViewModel(fakeEnvironment(failing)).state.value
        assertNull(error.rows)
        assertFalse(error.offline)

        val cached = world().apply { cachedGroups = groups.values.toList(); failures["myGroups"] = DataError.Network }
        val offline = GroupsListViewModel(fakeEnvironment(cached)).state.value
        assertEquals(2, offline.rows!!.size)
        assertTrue(offline.offline)
    }

    @Test fun realtimeInsertUpdatesTheCard() = runTest(main.dispatcher) {
        val backend = world()
        val vm = GroupsListViewModel(fakeEnvironment(backend))
        val fresh = backend.post("g2", "u-sam", backend.now)
        backend.member("g2", "u-sam")
        backend.events.emit(GroupEvent.PostInserted("g2", fresh))
        assertEquals("g2", vm.state.value.rows!!.first().id)
    }

    @Test fun leavingIsOptimisticAndRestoredOnFailure() = runTest(main.dispatcher) {
        val backend = world().apply { failures["leaveGroup"] = DataError.Network }
        val env = fakeEnvironment(backend, scope = backgroundScope)
        val vm = GroupsListViewModel(env)
        var failed = false
        GroupActions.leave(env, "g2") { failed = true }
        testScheduler.advanceUntilIdle()
        assertTrue(failed)
        assertEquals(listOf("g1", "g2"), vm.state.value.rows!!.map { it.id })

        backend.failures.remove("leaveGroup")
        GroupActions.leave(env, "g2")
        assertEquals(listOf("g1"), vm.state.value.rows!!.map { it.id })
    }

    // groups.create ---------------------------------------------------------------------------------

    @Test fun createPushesTheNewGroup() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend().apply { signIn() }
        val vm = GroupCreateViewModel(fakeEnvironment(backend), null)
        val events = vm.recordEvents(backgroundScope)
        assertFalse(vm.state.value.canSubmit)
        vm.onName("  Book club ")
        vm.onKind(GroupKind.Family)
        vm.submit()
        val created = backend.groups.values.single()
        assertEquals("Book club", created.name)
        assertEquals(GroupKind.Family, created.kind)
        val nav = events.navigations().single()
        assertEquals(AppRoute.Group(created.id), nav.route)
        assertTrue(nav.popCurrent)
        assertTrue(Tokens.Haptics.globalSuccess in events.haptics())
    }

    @Test fun createFailureKeepsTheBlockedError() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend().apply { signIn(); failures["createGroup"] = DataError.Api(ApiError.InvalidName, "invalid_name", 400, null) }
        val vm = GroupCreateViewModel(fakeEnvironment(backend), null)
        vm.onName("x")
        vm.submit()
        assertEquals(CreateError.Failed, vm.state.value.error)
        assertFalse(vm.state.value.working)
    }

    @Test fun editModePrefillsAndSaves() = runTest(main.dispatcher) {
        val backend = world()
        val vm = GroupCreateViewModel(fakeEnvironment(backend), "g1")
        assertEquals("Sunday dinners", vm.state.value.name)
        vm.onName("Sunday suppers")
        vm.submit()
        assertEquals("Sunday suppers", backend.groups.getValue("g1").name)
    }

    // groups.invite ---------------------------------------------------------------------------------

    @Test fun shareCreatesOneInviteAndReusesIt() = runTest(main.dispatcher) {
        val backend = world()
        val vm = GroupInviteViewModel(fakeEnvironment(backend), "g1")
        val links = mutableListOf<String>()
        vm.share { url, _ -> links += url }
        vm.share { url, _ -> links += url }
        assertEquals(1, backend.calls.count { it == "createInvite" })
        assertEquals(listOf("https://invite.example.test/i/AbCdEfGhIjKlMnOpQrStUvWx"), links.distinct())
        assertNotNull(vm.state.value.invite)
        assertTrue(vm.state.value.canTurnOff)
    }

    @Test fun turnOffIsOptimisticWithRollback() = runTest(main.dispatcher) {
        val backend = world()
        val vm = GroupInviteViewModel(fakeEnvironment(backend), "g1")
        vm.share { _, _ -> }
        backend.failures["revokeInvite"] = DataError.Network
        val events = vm.recordEvents(backgroundScope)
        vm.askTurnOff()
        vm.turnOff()
        assertNotNull(vm.state.value.invite)
        assertEquals(listOf(Tokens.Haptics.globalWarning, Tokens.Haptics.globalError), events.haptics())
        backend.failures.remove("revokeInvite")
        vm.turnOff()
        assertNull(vm.state.value.invite)
        assertEquals(listOf(AccountEvent.Toast(R.string.groups_invite_link_turnedoff)), events.toasts())
    }

    @Test fun fullGroupShowsTheFullState() = runTest(main.dispatcher) {
        val backend = world().apply { config = config.copy(maxGroupMembers = 2) }
        assertTrue(GroupInviteViewModel(fakeEnvironment(backend), "g1").state.value.full)
    }

    // groups.screen ---------------------------------------------------------------------------------

    @Test fun feedHasPostsNewestFirstAndJoinPills() = runTest(main.dispatcher) {
        val backend = world()
        val vm = GroupFeedViewModel(fakeEnvironment(backend), "g1")
        val items = vm.state.value.items!!
        assertTrue(items.first() is FeedItem.Photo)
        assertEquals("dinner", (items.first() as FeedItem.Photo).post.caption)
        assertTrue(items.any { it is FeedItem.Joined && it.firstName == "Sam" })
        assertTrue(vm.state.value.isCreator)
    }

    @Test fun createdGroupWithoutPostsIsTheCreatedState() = runTest(main.dispatcher) {
        val vm = GroupFeedViewModel(fakeEnvironment(world()), "g2")
        assertEquals(emptyList<FeedItem>(), vm.state.value.items)
        assertTrue(vm.state.value.isCreator)
        assertEquals(emptyList<String>(), vm.state.value.otherNames)
    }

    @Test fun removedMemberSeesTheRemovedState() = runTest(main.dispatcher) {
        val backend = world().apply { members.getValue("g1").removeAll { it.userId == meId } }
        assertTrue(GroupFeedViewModel(fakeEnvironment(backend), "g1").state.value.removed)
    }

    // groups.settings -------------------------------------------------------------------------------

    @Test fun muteIsOptimisticAndRevertsWithTheSectionError() = runTest(main.dispatcher) {
        val backend = world().apply { failures["setMuted"] = DataError.Network }
        val vm = GroupSettingsViewModel(fakeEnvironment(backend), "g1")
        assertTrue(vm.state.value.isAdmin)
        vm.setMuted(true)
        assertFalse(vm.state.value.muted)
        assertEquals(SettingsSection.Notifications, vm.state.value.errorIn)
        backend.failures.remove("setMuted")
        vm.setMuted(true)
        assertTrue(vm.state.value.muted)
        assertNull(vm.state.value.errorIn)
    }

    @Test fun invitationHoursInvalidWindowShowsItsFooter() = runTest(main.dispatcher) {
        val backend = world().apply { failures["setInvitationHours"] = DataError.Api(ApiError.InvalidWakingWindow, "invalid_waking_window", 400, null) }
        val vm = GroupSettingsViewModel(fakeEnvironment(backend), "g1")
        vm.setHours(LocalTime.of(9, 0), LocalTime.of(9, 1))
        assertTrue(vm.state.value.invalidWindow)
        assertNull(vm.state.value.group!!.wakingStart)
    }

    @Test fun removeMemberRollsBack() = runTest(main.dispatcher) {
        val backend = world().apply { failures["removeMember"] = DataError.Network }
        val vm = GroupSettingsViewModel(fakeEnvironment(backend), "g1")
        val sam = vm.state.value.members!!.first { it.userId == "u-sam" }
        vm.remove(sam)
        assertTrue(vm.state.value.members!!.any { it.userId == "u-sam" })
        assertEquals(SettingsSection.Members, vm.state.value.errorIn)
    }

    @Test fun leaveFromSettingsGoesHome() = runTest(main.dispatcher) {
        val backend = world()
        val env = fakeEnvironment(backend, scope = backgroundScope)
        val vm = GroupSettingsViewModel(env, "g1")
        val events = vm.recordEvents(backgroundScope)
        vm.leave()
        testScheduler.advanceUntilIdle()
        assertEquals(AppRoute.GroupsList, events.navigations().single().route)
        assertTrue("g1" in env.optimistic.leftGroups.value)
        assertTrue("leaveGroup" in backend.calls)
    }
}
