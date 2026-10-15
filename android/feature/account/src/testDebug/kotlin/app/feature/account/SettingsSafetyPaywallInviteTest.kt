package app.feature.account

import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.error.ApiError
import app.data.error.DataError
import app.data.model.MemberRole
import app.data.model.ReportTargetKind
import app.designsystem.generated.Tokens
import app.feature.account.invite.HttpInvitePreviewClient
import app.feature.account.invite.InstallReferrerParser
import app.feature.account.invite.InviteJoinState
import app.feature.account.invite.InviteJoinViewModel
import app.feature.account.invite.InvitePreviewResult
import app.feature.account.paywall.PaywallMessage
import app.feature.account.paywall.PaywallViewModel
import app.feature.account.paywall.PlanPeriod
import app.feature.account.paywall.PlansStatus
import app.feature.account.paywall.PremiumResult
import app.feature.account.paywall.periodUnit
import app.feature.account.safety.BlockViewModel
import app.feature.account.safety.ReportPhase
import app.feature.account.safety.ReportTarget
import app.feature.account.safety.ReportViewModel
import app.feature.account.settings.ManageSubscription
import app.feature.account.settings.SettingsAccountViewModel
import app.feature.account.settings.SettingsBlockedViewModel
import app.feature.account.settings.SettingsNotificationsViewModel
import app.feature.account.testing.FakeAccountBackend
import app.feature.account.testing.FakePremium
import app.feature.account.testing.FakeStores
import app.feature.account.testing.fakeEnvironment
import app.model.AppRoute
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.time.LocalTime
import java.util.Locale

@RunWith(AndroidJUnit4::class)
class SettingsSafetyPaywallInviteTest {
    @get:Rule val main = MainDispatcherRule()

    private fun world() = FakeAccountBackend().apply {
        signIn()
        profile(meId, "Ana Lima")
        profile("u-sam", "Sam Lee")
        group("g1", "Sunday dinners")
        member("g1", meId, MemberRole.Admin)
        member("g1", "u-sam")
    }

    // settings.notifications -------------------------------------------------------------------------

    @Test fun groupToggleIsOptimisticAndReverts() = runTest(main.dispatcher) {
        val backend = world().apply { failures["setMuted"] = DataError.Network }
        val vm = SettingsNotificationsViewModel(fakeEnvironment(backend))
        assertFalse(vm.state.value.groups!!.single().muted)
        vm.setGroupOn("g1", on = false)
        assertFalse(vm.state.value.groups!!.single().muted)
        assertTrue(vm.state.value.error)
    }

    @Test fun quietHoursSaveBothTimesWithTheDeviceZone() = runTest(main.dispatcher) {
        val backend = world()
        val vm = SettingsNotificationsViewModel(fakeEnvironment(backend))
        vm.setQuietOn(true)
        vm.setStart(LocalTime.of(22, 0))
        assertNull(backend.notificationSettings)
        vm.setEnd(LocalTime.of(7, 0))
        assertEquals(LocalTime.of(22, 0), backend.notificationSettings!!.quietStart)
        assertEquals("UTC", backend.notificationSettings!!.timeZone)
        vm.setQuietOn(false)
        assertNull(backend.notificationSettings!!.quietStart)
    }

    // settings.account / settings.blocked -----------------------------------------------------------

    @Test fun deleteAccountConfirmationThenAuthPhone() = runTest(main.dispatcher) {
        val backend = world()
        val vm = SettingsAccountViewModel(fakeEnvironment(backend))
        val events = vm.recordEvents(backgroundScope)
        vm.askDelete()
        assertTrue(vm.state.value.confirmDelete)
        vm.delete()
        assertTrue(backend.accountDeleted)
        assertEquals(AppRoute.AuthPhone, events.navigations().single().route)
        assertEquals(Tokens.Haptics.globalWarning, events.haptics().first())
    }

    @Test fun deleteAccountErrorKeepsTheAccount() = runTest(main.dispatcher) {
        val backend = world().apply { failures["deleteAccount"] = DataError.Network }
        val vm = SettingsAccountViewModel(fakeEnvironment(backend))
        vm.delete()
        assertTrue(vm.state.value.deleteError)
        assertFalse(backend.accountDeleted)
    }

    @Test fun nameSaveFailureRestoresTheName() = runTest(main.dispatcher) {
        val backend = world().apply { failures["updateDisplayName"] = DataError.Network }
        val vm = SettingsAccountViewModel(fakeEnvironment(backend))
        vm.saveName("Ana B")
        assertEquals("Ana Lima", vm.state.value.name)
        assertTrue(vm.state.value.nameError)
    }

    @Test fun unblockRemovesTheRow() = runTest(main.dispatcher) {
        val backend = world().apply { blocks += app.data.model.Block(meId, "u-sam", now) }
        val vm = SettingsBlockedViewModel(fakeEnvironment(backend))
        val person = vm.state.value.people!!.single()
        assertEquals("Sam Lee", person.name)
        vm.unblock(person)
        assertEquals(emptyList<Any>(), vm.state.value.people)
        assertTrue(backend.blocks.isEmpty())
    }

    // safety ----------------------------------------------------------------------------------------

    @Test fun reportPostSendsTheKindAsReasonWhenNoDetails() = runTest(main.dispatcher) {
        val backend = world()
        val post = backend.post("g1", "u-sam", backend.now)
        val vm = ReportViewModel(fakeEnvironment(backend), ReportTarget(ReportTargetKind.Post, post.id, "g1", null))
        assertEquals("Sam", vm.state.value.firstName)
        vm.submit()
        assertEquals(ReportPhase.Sent, vm.state.value.phase)
        assertEquals(Triple(ReportTargetKind.Post, post.id, "post"), backend.reports.single())
        assertEquals("u-sam", vm.state.value.target.personId)
    }

    @Test fun reportTargetGoneAndError() = runTest(main.dispatcher) {
        val backend = world().apply { failures["report"] = DataError.Api(ApiError.TargetNotFound, "target_not_found", 404, null) }
        val vm = ReportViewModel(fakeEnvironment(backend), ReportTarget(ReportTargetKind.User, "u-sam", "g1", "u-sam"))
        vm.onDetails("details")
        vm.submit()
        assertEquals(ReportPhase.NotFound, vm.state.value.phase)
        backend.failures["report"] = DataError.Network
        val again = ReportViewModel(fakeEnvironment(backend), ReportTarget(ReportTargetKind.User, "u-sam", "g1", "u-sam"))
        again.onDetails("kept")
        again.submit()
        assertEquals(ReportPhase.Error, again.state.value.phase)
        assertEquals("kept", again.state.value.details)
    }

    @Test fun blockErrorKeepsTheDialog() = runTest(main.dispatcher) {
        val backend = world().apply { failures["block"] = DataError.Network }
        val vm = BlockViewModel(fakeEnvironment(backend), "u-sam")
        assertEquals("Sam", vm.state.value.firstName)
        vm.block()
        assertTrue(vm.state.value.error)
        assertFalse(vm.state.value.blocking)
    }

    // paywall ---------------------------------------------------------------------------------------

    @Test fun plansLoadYearlyDefaultAndPendingPurchase() = runTest(main.dispatcher) {
        val premium = FakePremium().apply { purchaseResult = PremiumResult.Pending }
        val vm = PaywallViewModel(fakeEnvironment(world(), premium = premium))
        assertEquals(PlansStatus.Ready, vm.state.value.status)
        assertEquals(PlanPeriod.Yearly, vm.state.value.selectedPlan!!.period)
        vm.select(PlanPeriod.Monthly)
        assertEquals("$3.99", vm.state.value.selectedPlan!!.price)
        vm.purchase(android.app.Activity())
        assertEquals(PaywallMessage.Pending, vm.state.value.message)
    }

    @Test fun plansUnavailableAndRestoreNothing() = runTest(main.dispatcher) {
        val premium = FakePremium().apply { plans = emptyList() }
        val vm = PaywallViewModel(fakeEnvironment(world(), premium = premium))
        assertEquals(PlansStatus.Unavailable, vm.state.value.status)
        vm.restore()
        assertEquals(PaywallMessage.NothingToRestore, vm.state.value.message)
    }

    @Test fun billingLinePeriodAndPlaySubscriptionCenter() {
        assertEquals("month", periodUnit(PlanPeriod.Monthly, Locale.US))
        assertEquals("year", periodUnit(PlanPeriod.Yearly, Locale.US))
        assertEquals("https://play.google.com/store/account/subscriptions?package=com.example", ManageSubscription.url("com.example", null))
        assertEquals("https://play.google.com/store/account/subscriptions?sku=premium_yearly&package=com.example", ManageSubscription.url("com.example", "premium_yearly"))
    }

    // invite install path ---------------------------------------------------------------------------

    @Test fun referrerParsing() {
        assertEquals("AbCdEfGhIjKlMnOpQrStUvWx", InstallReferrerParser.inviteToken("invite_token=AbCdEfGhIjKlMnOpQrStUvWx"))
        assertEquals("AbCdEfGhIjKlMnOpQrStUvWx", InstallReferrerParser.inviteToken("utm_source=x&invite_token%3DAbCdEfGhIjKlMnOpQrStUvWx"))
        assertNull(InstallReferrerParser.inviteToken("utm_source=google-play&utm_medium=organic"))
        assertNull(InstallReferrerParser.inviteToken("invite_token=../../x"))
    }

    @Test fun previewJsonParsing() {
        val ok = HttpInvitePreviewClient.parse("""{"group_name":"Lima family","group_kind":"family","inviter_first_name":"Ana","cover":null,"members":[],"theme":{}}""")
        assertEquals(InvitePreviewResult.Valid("Lima family", app.data.model.GroupKind.Family, "Ana"), ok)
        assertEquals(InvitePreviewResult.Error, HttpInvitePreviewClient.parse("{}"))
    }

    @Test fun signedOutInviteKeepsTheTokenAndGoesToSignUp() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend()
        val stores = FakeStores()
        val vm = InviteJoinViewModel(fakeEnvironment(backend, stores), "AbCdEfGhIjKlMnOpQrStUvWx")
        val events = vm.recordEvents(backgroundScope)
        testScheduler.advanceUntilIdle()
        assertEquals("AbCdEfGhIjKlMnOpQrStUvWx", stores.pendingInviteToken)
        assertTrue(events.navigations().isEmpty() || events.navigations().single().route == AppRoute.AuthPhone)
    }

    @Test fun expiredInviteFromThePreviewEndsAndForgetsTheToken() = runTest(main.dispatcher) {
        val stores = FakeStores()
        val vm = InviteJoinViewModel(fakeEnvironment(FakeAccountBackend(), stores, preview = InvitePreviewResult.Unavailable), "AbCdEfGhIjKlMnOpQrStUvWx")
        assertEquals(InviteJoinState.Unavailable, vm.state.value)
        assertNull(stores.pendingInviteToken)
    }

    @Test fun onboardedMemberJoinsAndLandsInTheGroup() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend().apply {
            signIn(); ageConfirmed = true; profile(meId, "Ana Lima")
            group("g9", "Book club", createdBy = "u-sam")
            member("g9", "u-sam", MemberRole.Admin)
            invites += app.data.model.GroupInvite("i1", "g9", "AbCdEfGhIjKlMnOpQrStUvWx", "u-sam", now, now.plusSeconds(3600), null)
        }
        val stores = FakeStores().apply { onboarded += backend.meId }
        val vm = InviteJoinViewModel(fakeEnvironment(backend, stores), "AbCdEfGhIjKlMnOpQrStUvWx")
        val events = vm.recordEvents(backgroundScope)
        assertEquals(listOf(AppRoute.GroupsList, AppRoute.Group("g9")), events.navigations().map { it.route })
        assertNull(stores.pendingInviteToken)
    }

    @Test fun fullGroupAtJoinTime() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend().apply {
            signIn(); ageConfirmed = true; profile(meId, "Ana")
            failures["joinGroup"] = DataError.Api(ApiError.GroupFull, "group_full", 409, null)
        }
        val stores = FakeStores().apply { onboarded += backend.meId }
        val vm = InviteJoinViewModel(fakeEnvironment(backend, stores), "AbCdEfGhIjKlMnOpQrStUvWx")
        assertEquals(InviteJoinState.Full, vm.state.value)
    }
}
