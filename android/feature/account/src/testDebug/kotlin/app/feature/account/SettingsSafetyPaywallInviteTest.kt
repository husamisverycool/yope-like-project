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
import app.feature.account.paywall.PaywallWelcome
import app.feature.account.paywall.Perk
import app.feature.account.paywall.PlanPeriod
import app.feature.account.paywall.PlansStatus
import app.feature.account.paywall.PremiumResult
import app.feature.account.paywall.TrialDuration
import app.feature.account.paywall.periodUnit
import app.feature.account.safety.BlockViewModel
import app.feature.account.safety.ReportPhase
import app.feature.account.safety.ReportReasons
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
import app.feature.account.common.AccountEvent
import app.designsystem.R
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
        assertEquals(listOf(AccountEvent.Toast(R.string.settings_account_deleted_toast)), events.toasts())
    }

    @Test fun deleteAccountErrorKeepsTheAccount() = runTest(main.dispatcher) {
        val backend = world().apply { failures["deleteAccount"] = DataError.Network }
        val vm = SettingsAccountViewModel(fakeEnvironment(backend))
        vm.delete()
        assertTrue(vm.state.value.deleteError)
        assertFalse(backend.accountDeleted)
    }

    @Test fun editFullNameSavesAndCloses() = runTest(main.dispatcher) {
        val backend = world()
        val vm = SettingsAccountViewModel(fakeEnvironment(backend))
        vm.openName()
        assertTrue(vm.state.value.editingName)
        vm.saveName("  Ana B ")
        assertEquals("Ana B", vm.state.value.name)
        assertFalse(vm.state.value.editingName)
        assertEquals("Ana B", backend.profiles.getValue(backend.meId).displayName)
    }

    @Test fun nameSaveFailureKeepsThePageAndShowsTheAlert() = runTest(main.dispatcher) {
        val backend = world().apply { failures["updateDisplayName"] = DataError.Network }
        val vm = SettingsAccountViewModel(fakeEnvironment(backend))
        vm.openName()
        vm.saveName("Ana B")
        assertEquals("Ana Lima", vm.state.value.name)
        assertTrue(vm.state.value.editingName)
        assertTrue(vm.state.value.saveError)
    }

    @Test fun birthdayRowShowsTheSavedDateAndPhotoRemoves() = runTest(main.dispatcher) {
        val backend = world().apply { birthday = java.time.LocalDate.of(2001, 3, 14) to true; profile(meId, "Ana Lima", "avatars/u-me/a.jpg") }
        val vm = SettingsAccountViewModel(fakeEnvironment(backend))
        assertEquals(java.time.LocalDate.of(2001, 3, 14), vm.state.value.birthday)
        assertTrue(vm.state.value.hasPhoto)
        vm.removePhoto()
        assertFalse(vm.state.value.hasPhoto)
        assertTrue("removeAvatar" in backend.calls)
    }

    @Test fun unblockRemovesTheRow() = runTest(main.dispatcher) {
        val backend = world().apply { blocks += app.data.model.Block(meId, "u-sam", now) }
        val vm = SettingsBlockedViewModel(fakeEnvironment(backend))
        val person = vm.state.value.people!!.single()
        assertEquals("Sam Lee", person.name)
        val events = vm.recordEvents(backgroundScope)
        vm.unblock(person)
        assertEquals(listOf(AccountEvent.Toast(R.string.safety_block_undone, listOf("Sam"))), events.toasts())
        assertEquals(emptyList<Any>(), vm.state.value.people)
        assertTrue(backend.blocks.isEmpty())
    }

    @Test fun unblockFailureKeepsTheRowWithTheAlert() = runTest(main.dispatcher) {
        val backend = world().apply { blocks += app.data.model.Block(meId, "u-sam", now); failures["unblock"] = DataError.Network }
        val vm = SettingsBlockedViewModel(fakeEnvironment(backend))
        vm.unblock(vm.state.value.people!!.single())
        assertEquals(1, vm.state.value.people!!.size)
        assertTrue(vm.state.value.unblockFailed)
        assertFalse(vm.state.value.error)
    }

    // safety ----------------------------------------------------------------------------------------

    @Test fun reportReasonFilesAtOnceWithItsEnglishText() = runTest(main.dispatcher) {
        val backend = world()
        val post = backend.post("g1", "u-sam", backend.now)
        val vm = ReportViewModel(fakeEnvironment(backend), ReportTarget(ReportTargetKind.Post, post.id, "g1", null))
        val events = vm.recordEvents(backgroundScope)
        assertEquals("Sam", vm.state.value.firstName)
        val reasons = ReportReasons.of(ReportTargetKind.Post)
        assertEquals(listOf("I don't like it", "Nudity or sexual activity", "Other"), reasons.map { it.wire })
        vm.choose(reasons[1])
        assertEquals(Triple(ReportTargetKind.Post, post.id, "Nudity or sexual activity"), backend.reports.single())
        assertEquals(listOf(AccountEvent.Toast(R.string.safety_report_sent_title)), events.toasts())
        assertTrue(AccountEvent.Back in events)
        assertEquals("u-sam", vm.state.value.target.personId)
    }

    @Test fun dontLikeItFilesNothingAndOffersNextSteps() = runTest(main.dispatcher) {
        val backend = world()
        val post = backend.post("g1", "u-sam", backend.now)
        val vm = ReportViewModel(fakeEnvironment(backend, scope = backgroundScope), ReportTarget(ReportTargetKind.Post, post.id, "g1", null))
        val events = vm.recordEvents(backgroundScope)
        vm.choose(ReportReasons.of(ReportTargetKind.Post).first())
        assertEquals(ReportPhase.NextSteps, vm.state.value.phase)
        assertTrue(backend.reports.isEmpty())
        vm.askLeave()
        vm.leave()
        assertEquals(listOf(AccountEvent.Toast(R.string.safety_report_left)), events.toasts())
        assertEquals(AppRoute.GroupsList, events.navigations().single().route)
    }

    @Test fun reportTargetGoneAndError() = runTest(main.dispatcher) {
        val backend = world().apply { failures["report"] = DataError.Api(ApiError.TargetNotFound, "target_not_found", 404, null) }
        val vm = ReportViewModel(fakeEnvironment(backend), ReportTarget(ReportTargetKind.User, "u-sam", "g1", "u-sam"))
        vm.choose(ReportReasons.of(ReportTargetKind.User).first())
        assertEquals(ReportPhase.NotFound, vm.state.value.phase)
        backend.failures["report"] = DataError.Network
        val again = ReportViewModel(fakeEnvironment(backend), ReportTarget(ReportTargetKind.User, "u-sam", "g1", "u-sam"))
        again.choose(ReportReasons.of(ReportTargetKind.User).last())
        assertEquals(ReportPhase.Error, again.state.value.phase)
    }

    @Test fun blockShowsTheToastAndGoesBack() = runTest(main.dispatcher) {
        val backend = world()
        val vm = BlockViewModel(fakeEnvironment(backend), "u-sam")
        val events = vm.recordEvents(backgroundScope)
        vm.block()
        assertEquals(listOf(AccountEvent.Toast(R.string.safety_block_done, listOf("Sam"))), events.toasts())
        assertTrue(AccountEvent.Back in events)
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

    @Test fun plansLoadAnnualFirstAndPendingPurchase() = runTest(main.dispatcher) {
        val premium = FakePremium().apply { purchaseResult = PremiumResult.Pending }
        val vm = PaywallViewModel(fakeEnvironment(world(), premium = premium))
        assertEquals(PlansStatus.Ready, vm.state.value.status)
        assertEquals(listOf(PlanPeriod.Yearly, PlanPeriod.Monthly), vm.state.value.orderedPlans.map { it.period })
        val monthly = vm.state.value.orderedPlans.last()
        assertEquals("$3.99", monthly.price)
        vm.purchase(android.app.Activity(), monthly)
        assertEquals(PaywallMessage.Pending, vm.state.value.message)
    }

    @Test fun purchaseDoneShowsTheWelcomeAndHistoryPerkFollowsTheConfig() = runTest(main.dispatcher) {
        val vm = PaywallViewModel(fakeEnvironment(world(), premium = FakePremium()))
        assertFalse(Perk.History in vm.state.value.perks)
        vm.purchase(android.app.Activity(), vm.state.value.orderedPlans.first())
        assertEquals(PaywallWelcome.Purchased, vm.state.value.welcome)
    }

    @Test fun plansUnavailableAndRestoreNothing() = runTest(main.dispatcher) {
        val premium = FakePremium().apply { plans = emptyList() }
        val vm = PaywallViewModel(fakeEnvironment(world(), premium = premium))
        assertEquals(PlansStatus.Unavailable, vm.state.value.status)
        vm.restore()
        assertEquals(PaywallMessage.NothingToRestore, vm.state.value.message)
    }

    @Test fun theAnnualTrialReachesTheCardAndOnlyThePurchasingPlanIsBusy() = runTest(main.dispatcher) {
        // Owner decision 7: the fake store answers $35.99 a year with a 1-week trial, $3.99 a month.
        val premium = FakePremium().apply { purchaseResult = PremiumResult.Cancelled }
        val vm = PaywallViewModel(fakeEnvironment(world(), premium = premium))
        val (yearly, monthly) = vm.state.value.orderedPlans
        assertEquals("$35.99" to "1 week", yearly.price to yearly.trialDuration)
        assertEquals("$3.99", monthly.price)
        assertNull(monthly.trialDuration)
        assertNull(vm.state.value.purchasing)
        vm.purchase(android.app.Activity(), monthly)
        // Cancelled by the person: nothing changes (no message, nothing busy).
        assertNull(vm.state.value.purchasing)
        assertNull(vm.state.value.message)
    }

    @Test fun purchaseMarksItsPlanBusyUntilTheStoreAnswers() = runTest(main.dispatcher) {
        val answer = kotlinx.coroutines.CompletableDeferred<PremiumResult>()
        val premium = object : app.feature.account.paywall.PremiumGateway by FakePremium() {
            override suspend fun purchase(activity: android.app.Activity, plan: app.feature.account.paywall.PlanOption) = answer.await()
        }
        val env = fakeEnvironment(world()).let {
            app.feature.account.AccountEnvironment(it.backend, it.stores, it.inviteLinks, it.invitePreview, premium, it.contacts, it.images, it.legal, it.clock, it.zone)
        }
        val vm = PaywallViewModel(env)
        vm.purchase(android.app.Activity(), vm.state.value.orderedPlans.first())
        assertEquals(PlanPeriod.Yearly, vm.state.value.purchasing)
        // A second tap while the store sheet is up does nothing.
        vm.purchase(android.app.Activity(), vm.state.value.orderedPlans.last())
        assertEquals(PlanPeriod.Yearly, vm.state.value.purchasing)
        answer.complete(PremiumResult.Failed)
        assertNull(vm.state.value.purchasing)
        assertEquals(PaywallMessage.PurchaseFailed, vm.state.value.message)
    }

    @Test fun restoreOutcomes() = runTest(main.dispatcher) {
        val backend = world()
        val premium = FakePremium()
        val vm = PaywallViewModel(fakeEnvironment(backend, premium = premium))
        premium.restoreResult = PremiumResult.Done to true
        vm.restore()
        assertEquals(PaywallWelcome.Restored, vm.state.value.welcome)
        val again = PaywallViewModel(fakeEnvironment(backend, premium = premium))
        premium.restoreResult = PremiumResult.Failed to false
        again.restore()
        assertEquals(PaywallMessage.NothingToRestore, again.state.value.message)
        again.dismissMessage()
        backend.onlineState.value = false
        again.restore()
        assertEquals(PaywallMessage.Offline, again.state.value.message)
    }

    @Test fun trialDurationIsTheStorePeriodInTheLocalesWords() {
        assertEquals("1 week", TrialDuration.format("P1W", Locale.US))
        assertEquals("7 days", TrialDuration.format("P7D", Locale.US))
        assertEquals("1 month", TrialDuration.format("P1M", Locale.US))
        assertEquals("1 week", TrialDuration.format("P1W", Locale.UK))
        // French CLDR joins number and unit with a no-break space.
        assertEquals("1 semaine", TrialDuration.format("P1W", Locale.FRANCE)?.replace('\u00A0', ' ')?.replace('\u202F', ' '))
        assertNull(TrialDuration.format("P0D", Locale.US))
        assertNull(TrialDuration.format("PT12H", Locale.US))
        assertNull(TrialDuration.format("1 week", Locale.US))
    }

    // settings.root ----------------------------------------------------------------------------------

    @Test fun trueBlackIsKeptOnTheDeviceAndFollowedByTheScreen() = runTest(main.dispatcher) {
        val appearance = app.ui.theme.MemoryAppearanceSettings()
        val vm = app.feature.account.settings.SettingsRootViewModel(fakeEnvironment(world(), appearance = appearance))
        assertFalse(vm.state.value.trueBlack)
        vm.setTrueBlack(true)
        assertTrue(appearance.trueBlack.value)
        assertTrue(vm.state.value.trueBlack)
        vm.setTrueBlack(false)
        assertFalse(vm.state.value.trueBlack)
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
        val full = HttpInvitePreviewClient.parse(
            """{"group_name":"Lima family","group_kind":"family","inviter_first_name":"Ana","cover":{"url":"https://x/i/t/cover.jpg","width":3,"height":4},""" +
                """"members":[{"first_name":"Ana","avatar_url":"https://x/i/t/avatar/0.jpg"},{"first_name":"Rui","avatar_url":null}],"theme":{}}""",
        ) as InvitePreviewResult.Valid
        assertEquals("https://x/i/t/cover.jpg", full.coverUrl)
        assertEquals(listOf("https://x/i/t/avatar/0.jpg", null), full.memberAvatars)
        assertEquals(InvitePreviewResult.Error, HttpInvitePreviewClient.parse("{}"))
    }

    @Test fun signedOutInviteShowsTheCardThenLetsGoSignsUp() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend()
        val stores = FakeStores()
        val vm = InviteJoinViewModel(fakeEnvironment(backend, stores), "AbCdEfGhIjKlMnOpQrStUvWx")
        val events = vm.recordEvents(backgroundScope)
        testScheduler.advanceUntilIdle()
        assertEquals(InviteJoinState.Ready, vm.state.value.phase)
        assertTrue(events.navigations().isEmpty())
        vm.go()
        testScheduler.advanceUntilIdle()
        assertEquals("AbCdEfGhIjKlMnOpQrStUvWx", stores.pendingInviteToken)
        assertEquals(AppRoute.AuthPhone, events.navigations().single().route)
    }

    @Test fun expiredInviteFromThePreviewEndsAndForgetsTheToken() = runTest(main.dispatcher) {
        val stores = FakeStores()
        val vm = InviteJoinViewModel(fakeEnvironment(FakeAccountBackend(), stores, preview = InvitePreviewResult.Unavailable), "AbCdEfGhIjKlMnOpQrStUvWx")
        assertEquals(InviteJoinState.Unavailable, vm.state.value.phase)
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
        vm.go()
        assertEquals(listOf(AppRoute.GroupsList, AppRoute.Group("g9")), events.navigations().map { it.route })
        assertNull(stores.pendingInviteToken)
    }

    @Test fun fullGroupAtJoinTime() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend().apply {
            signIn(); ageConfirmed = true; profile(meId, "Ana")
            failures["joinGroup"] = DataError.Api(ApiError.GroupFull, "group_full", 409, null)
        }
        val stores = FakeStores().apply { onboarded += backend.meId }
        // The pending invite at the end of onboarding joins without a second tap.
        val vm = InviteJoinViewModel(fakeEnvironment(backend, stores), "AbCdEfGhIjKlMnOpQrStUvWx", autoJoin = true)
        assertEquals(InviteJoinState.Full, vm.state.value.phase)
    }
}
