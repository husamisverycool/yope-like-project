package app.feature.account

import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.error.ApiError
import app.data.error.DataError
import app.data.model.GroupKind
import app.data.model.MemberRole
import app.data.realtime.GroupEvent
import app.designsystem.generated.Tokens
import app.feature.account.groups.CreateError
import app.feature.account.groups.CreateStep
import app.feature.account.groups.GroupPhoto
import app.feature.account.groups.GroupWeek
import app.feature.account.groups.GroupActions
import app.feature.account.groups.GroupCreateViewModel
import app.feature.account.groups.GroupFeedViewModel
import app.feature.account.groups.GroupInviteViewModel
import app.feature.account.groups.GroupSettingsViewModel
import app.feature.account.groups.GroupsListViewModel
import app.feature.account.groups.RowSubtitle
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
        // No posts in a group you created: "you created the group".
        assertEquals(RowSubtitle.CreatedByYou, rows[1].subtitle)
        // The member stack in joining order (me, then Sam); no count anywhere.
        assertEquals(2, rows[0].avatars.size)
    }

    @Test fun groupCreatedBySomeoneElseNamesTheCreator() = runTest(main.dispatcher) {
        val backend = world().apply {
            group("g3", "Book club", createdBy = "u-sam", createdAt = now.minus(Duration.ofDays(2)))
            member("g3", "u-sam", MemberRole.Admin)
            member("g3", meId)
        }
        val vm = GroupsListViewModel(fakeEnvironment(backend))
        assertEquals(RowSubtitle.CreatedBy("Sam"), vm.state.value.rows!!.first { it.id == "g3" }.subtitle)
    }

    @Test fun ownNewestPostReadsNewPic() = runTest(main.dispatcher) {
        val backend = world().apply { post("g1", meId, now.minus(Duration.ofMinutes(5))) }
        val vm = GroupsListViewModel(fakeEnvironment(backend))
        assertEquals(RowSubtitle.NewPic, vm.state.value.rows!!.first().subtitle)
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
        assertEquals(CreateStep.Type, vm.state.value.step)
        // Choosing a template is choosing the kind, then step B (cover and name).
        vm.onKind(GroupKind.Family)
        assertEquals(CreateStep.Details, vm.state.value.step)
        assertFalse(vm.state.value.canSubmit)
        vm.onName("  Book club ")
        vm.submit()
        val created = backend.groups.values.single()
        assertEquals("Book club", created.name)
        assertEquals(GroupKind.Family, created.kind)
        val nav = events.navigations().single()
        assertEquals(AppRoute.Group(created.id), nav.route)
        assertTrue(nav.popCurrent)
        assertEquals(listOf(Tokens.Haptics.globalSelect, Tokens.Haptics.globalSuccess), events.haptics())
    }

    @Test fun templateRowOpensTheNameStepAndNamesPast80AreTooLong() = runTest(main.dispatcher) {
        val vm = GroupCreateViewModel(fakeEnvironment(FakeAccountBackend().apply { signIn() }), null, GroupKind.Roommates)
        assertEquals(CreateStep.Details, vm.state.value.step)
        assertTrue(vm.state.value.kindPreset)
        vm.backToType()
        assertEquals(CreateStep.Details, vm.state.value.step)
        vm.onName("x".repeat(81))
        assertTrue(vm.state.value.tooLong)
        assertFalse(vm.state.value.canSubmit)
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
        assertEquals(CreateStep.Details, vm.state.value.step)
        assertEquals("Sunday dinners", vm.state.value.name)
        vm.onName("Sunday suppers")
        vm.submit()
        assertEquals("Sunday suppers", backend.groups.getValue("g1").name)
    }

    // groups.invite ---------------------------------------------------------------------------------

    @Test fun linkSharingIsTurnedOnExplicitlyThenReset() = runTest(main.dispatcher) {
        val backend = world()
        val vm = GroupInviteViewModel(fakeEnvironment(backend), "g1")
        // No live invite of yours: link off until "Turn on link sharing".
        assertNull(vm.state.value.invite)
        assertFalse(vm.state.value.loading)
        assertNull(vm.link())
        vm.turnOn()
        val first = vm.state.value.invite!!
        assertEquals(1, backend.calls.count { it == "createInvite" })
        assertEquals("https://invite.example.test/i/" + first.token, vm.link())
        // Reset: the old link is revoked and a new one made.
        vm.reset()
        assertEquals(listOf("createInvite", "revokeInvite", "createInvite"), backend.calls.filter { it == "createInvite" || it == "revokeInvite" })
        assertNotNull(vm.state.value.invite)
    }

    @Test fun turnOffIsOptimisticWithRollback() = runTest(main.dispatcher) {
        val backend = world()
        val vm = GroupInviteViewModel(fakeEnvironment(backend), "g1")
        vm.turnOn()
        backend.failures["revokeInvite"] = DataError.Network
        val events = vm.recordEvents(backgroundScope)
        vm.askTurnOff()
        assertTrue(vm.state.value.confirmTurnOff)
        vm.turnOff()
        assertNotNull(vm.state.value.invite)
        assertEquals(listOf(Tokens.Haptics.globalWarning, Tokens.Haptics.globalError), events.haptics())
        backend.failures.remove("revokeInvite")
        vm.turnOff()
        assertNull(vm.state.value.invite)
        assertEquals(listOf(AccountEvent.Toast(R.string.groups_invite_link_turnedoff)), events.toasts())
    }

    @Test fun readFailureIsTheErrorStateAndOfflineItsOwn() = runTest(main.dispatcher) {
        val failing = world().apply { failures["activeInvites"] = DataError.Unexpected("x") }
        assertTrue(GroupInviteViewModel(fakeEnvironment(failing), "g1").state.value.error)
        val offline = world().apply { failures["activeInvites"] = DataError.Network }
        val state = GroupInviteViewModel(fakeEnvironment(offline), "g1").state.value
        assertTrue(state.offline)
        assertFalse(state.error)
    }

    @Test fun fullGroupShowsTheFullState() = runTest(main.dispatcher) {
        val backend = world().apply { config = config.copy(maxGroupMembers = 2) }
        assertTrue(GroupInviteViewModel(fakeEnvironment(backend), "g1").state.value.full)
    }

    // groups.screen ---------------------------------------------------------------------------------

    @Test fun feedHasPhotosNewestFirstWithAuthors() = runTest(main.dispatcher) {
        val backend = world()
        val vm = GroupFeedViewModel(fakeEnvironment(backend), "g1")
        val photos = vm.state.value.photos!!
        assertEquals("dinner", photos.first().post.caption)
        assertEquals("Sam", photos.first().authorFirstName)
        assertFalse(photos.first().mine)
        assertTrue(photos.last().mine)
        assertEquals(2, vm.state.value.memberAvatars.size)
        assertTrue(vm.state.value.isCreator)
    }

    @Test fun createdGroupWithoutPostsIsTheCreatedState() = runTest(main.dispatcher) {
        val vm = GroupFeedViewModel(fakeEnvironment(world()), "g2")
        assertEquals(emptyList<GroupPhoto>(), vm.state.value.photos)
        assertTrue(vm.state.value.isCreator)
    }

    @Test fun groupWeekStartsOnMondayInTheGroupZone() {
        val thursday = java.time.LocalDate.of(2026, 10, 15)
        assertEquals(java.time.LocalDate.of(2026, 10, 12), GroupWeek.start(thursday))
        assertEquals(java.time.LocalDate.of(2026, 10, 18), GroupWeek.end(thursday))
        assertEquals(42, GroupWeek.number(thursday))
    }

    @Test fun removedMemberSeesTheRemovedState() = runTest(main.dispatcher) {
        val backend = world().apply { members.getValue("g1").removeAll { it.userId == meId } }
        assertTrue(GroupFeedViewModel(fakeEnvironment(backend), "g1").state.value.removed)
    }

    // groups.settings -------------------------------------------------------------------------------

    @Test fun muteIsOptimisticAndRevertsWithTheErrorAlert() = runTest(main.dispatcher) {
        val backend = world().apply { failures["setMuted"] = DataError.Network }
        val vm = GroupSettingsViewModel(fakeEnvironment(backend), "g1")
        assertTrue(vm.state.value.isAdmin)
        vm.setMuted(true)
        assertFalse(vm.state.value.muted)
        assertTrue(vm.state.value.failed)
        vm.dismissAlert()
        backend.failures.remove("setMuted")
        vm.setMuted(true)
        assertTrue(vm.state.value.muted)
        assertFalse(vm.state.value.failed)
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
        assertTrue(vm.state.value.failed)
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
