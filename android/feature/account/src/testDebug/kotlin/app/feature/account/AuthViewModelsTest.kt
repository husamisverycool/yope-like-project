package app.feature.account

import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.error.ApiError
import app.data.error.AuthFailure
import app.data.error.DataError
import app.designsystem.generated.Tokens
import app.feature.account.auth.AgeGateViewModel
import app.feature.account.auth.CodeError
import app.feature.account.auth.CodeViewModel
import app.feature.account.auth.DateEntryPattern
import app.feature.account.auth.PhoneError
import app.feature.account.auth.PhoneNumbers
import app.feature.account.auth.PhoneViewModel
import app.feature.account.auth.ProfileError
import app.feature.account.auth.ProfileViewModel
import app.feature.account.platform.AgeRefusal
import app.feature.account.testing.FakeAccountBackend
import app.feature.account.testing.FakeStores
import app.feature.account.testing.fakeEnvironment
import app.model.AppRoute
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.time.LocalDate
import java.util.Locale

@RunWith(AndroidJUnit4::class)
class AuthViewModelsTest {
    @get:Rule val main = MainDispatcherRule()

    // auth.phone ------------------------------------------------------------------------------------

    @Test fun phonePrefillsTheRegionCallingCodeAndWaitsForDigits() = runTest(main.dispatcher) {
        val vm = PhoneViewModel(fakeEnvironment())
        assertEquals("+1", vm.state.value.phone)
        assertFalse(vm.state.value.canContinue)
        vm.onPhoneChange("+1 415")
        assertTrue(vm.state.value.canContinue)
    }

    @Test fun phoneSendsTheCodeAndPushesAuthCode() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend()
        val env = fakeEnvironment(backend)
        val vm = PhoneViewModel(env)
        val events = vm.recordEvents(backgroundScope)
        vm.onPhoneChange("+1 415 555 0100")
        vm.submit()
        assertEquals(listOf("requestOtp"), backend.calls)
        assertEquals("+14155550100", env.signUp.phoneE164)
        assertEquals(AppRoute.AuthCode, events.navigations().single().route)
        assertTrue(Tokens.Haptics.globalSuccess in events.haptics())
        assertFalse(vm.state.value.sending)
    }

    @Test fun phoneErrorsAreKeptInStateWithTheErrorHaptic() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend()
        val vm = PhoneViewModel(fakeEnvironment(backend))
        val events = vm.recordEvents(backgroundScope)
        vm.onPhoneChange("+1 12")
        vm.submit()
        assertEquals(PhoneError.InvalidNumber, vm.state.value.error)
        assertTrue(backend.calls.isEmpty())

        backend.failures["requestOtp"] = DataError.Auth(AuthFailure.RateLimited, null)
        vm.onPhoneChange("+1 415 555 0100")
        vm.submit()
        assertEquals(PhoneError.RateLimited, vm.state.value.error)

        backend.failures["requestOtp"] = DataError.Network
        vm.submit()
        assertTrue(vm.state.value.offline)
        assertTrue(events.haptics().all { it == Tokens.Haptics.globalError })
    }

    @Test fun phoneShowsOfflineFromConnectivity() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend()
        val vm = PhoneViewModel(fakeEnvironment(backend))
        backend.onlineState.value = false
        assertTrue(vm.state.value.offline)
        backend.onlineState.value = true
        assertFalse(vm.state.value.offline)
    }

    @Test fun phoneNumberNormalisation() {
        assertEquals("+14155550100", PhoneNumbers.toE164("+1 (415) 555-0100", "US"))
        assertNull(PhoneNumbers.toE164("+1 12", "US"))
        assertEquals("+44", PhoneNumbers.prefill("gb"))
        assertEquals("+", PhoneNumbers.prefill(null))
    }

    // auth.code -------------------------------------------------------------------------------------

    private fun codeEnv(backend: FakeAccountBackend, stores: FakeStores = FakeStores()) = fakeEnvironment(backend, stores).also {
        it.signUp.phoneE164 = backend.phone
        it.signUp.codeSentAtMillis = backend.now.toEpochMilli()
    }

    @Test fun wrongCodeClearsTheFieldAndKeepsTheBlockedError() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend()
        val vm = CodeViewModel(codeEnv(backend))
        vm.onCodeChange("000000")
        vm.submit()
        assertEquals(CodeError.Wrong, vm.state.value.error)
        assertEquals("", vm.state.value.code)
    }

    @Test fun newAccountGoesToTheAgeGate() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend()
        val vm = CodeViewModel(codeEnv(backend))
        val events = vm.recordEvents(backgroundScope)
        vm.onCodeChange("123456")
        vm.submit()
        val nav = events.navigations().single()
        assertEquals(AppRoute.AuthAgeGate, nav.route)
        assertTrue(nav.clearStack)
    }

    @Test fun returningAccountSkipsOnboardingAndJoinsAPendingInvite() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend().apply { ageConfirmed = true; profile(meId, "Ana Lima") }
        val stores = FakeStores().apply { pendingInviteToken = "AbCdEfGhIjKlMnOpQrStUvWx" }
        val vm = CodeViewModel(codeEnv(backend, stores))
        val events = vm.recordEvents(backgroundScope)
        vm.onCodeChange("123456")
        vm.submit()
        assertEquals(AppRoute.InviteJoin("AbCdEfGhIjKlMnOpQrStUvWx"), events.navigations().single().route)
        assertTrue(stores.isOnboardingDone(backend.meId))
    }

    @Test fun rateLimitedAndResendLock() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend().apply { failures["verifyOtp"] = DataError.Auth(AuthFailure.RateLimited, null) }
        val vm = CodeViewModel(codeEnv(backend))
        assertTrue(vm.state.value.resendLocked)
        vm.onCodeChange("123456")
        vm.submit()
        assertEquals(CodeError.TooMany, vm.state.value.error)
        advanceTimeBy(Tokens.Durations.authCodeDurationResendLock.toLong() + 1)
        assertFalse(vm.state.value.resendLocked)
        vm.resend()
        assertTrue(vm.state.value.resendLocked)
        assertTrue("requestOtp" in backend.calls)
    }

    // auth.agegate ----------------------------------------------------------------------------------

    @Test fun datePatternFollowsTheLocale() {
        val us = DateEntryPattern.of(Locale.US)
        assertEquals("mm/dd/yyyy", us.placeholder)
        assertEquals("03/1", us.format("031"))
        assertEquals(LocalDate.of(2001, 3, 14), us.parse("03142001"))
        assertNull(us.parse("02302001"))
        val de = DateEntryPattern.of(Locale.GERMANY)
        assertEquals("dd.mm.yyyy", de.placeholder)
    }

    @Test fun ageConfirmedWithOptInGoesToTheProfile() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend().apply { signIn(); profile(meId, "") }
        val vm = AgeGateViewModel(fakeEnvironment(backend), DateEntryPattern.of(Locale.US))
        val events = vm.recordEvents(backgroundScope)
        vm.onDigits("03142001")
        vm.onOptIn(true)
        assertTrue(vm.canContinue)
        vm.submit()
        assertEquals(LocalDate.of(2001, 3, 14) to true, backend.birthday)
        assertEquals(AppRoute.AuthProfile, events.navigations().single().route)
    }

    @Test fun ageGateNotConfiguredFailsClosed() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend().apply {
            signIn()
            failures["confirmAge"] = DataError.Api(ApiError.AgeGateNotConfigured, "age_gate_not_configured", 503, null)
        }
        val vm = AgeGateViewModel(fakeEnvironment(backend), DateEntryPattern.of(Locale.US))
        vm.onDigits("03142001")
        vm.submit()
        assertTrue(vm.state.value.notConfigured)
    }

    @Test fun underAgeIsRememberedDeletesTheAccountAndSignsOut() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend().apply {
            signIn()
            failures["confirmAge"] = DataError.Api(ApiError.UnderMinimumAge, "under_minimum_age", 403, null)
        }
        val stores = FakeStores()
        val vm = AgeGateViewModel(fakeEnvironment(backend, stores), DateEntryPattern.of(Locale.US))
        vm.onDigits("03142020")
        vm.submit()
        assertEquals(AgeRefusal(13), vm.state.value.refusal)
        assertEquals(AgeRefusal(13), stores.refusal)
        assertTrue(backend.accountDeleted)
        assertNull(backend.currentUserId)
        // A new view model (going back / relaunch) starts in the refusal.
        assertEquals(AgeRefusal(13), AgeGateViewModel(fakeEnvironment(backend, stores), DateEntryPattern.of(Locale.US)).state.value.refusal)
    }

    // auth.profile ----------------------------------------------------------------------------------

    @Test fun profileSavesTheNameThenAsksForNotificationsOnAndroid13() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend().apply { signIn(); profile(meId, "") }
        val vm = ProfileViewModel(fakeEnvironment(backend, sdkInt = 33))
        val events = vm.recordEvents(backgroundScope)
        vm.onName("  Ana Lima ")
        vm.submit()
        assertEquals("Ana Lima", backend.profiles.getValue(backend.meId).displayName)
        assertEquals(AppRoute.PermissionNotifications, events.navigations().single().route)
    }

    @Test fun profileSkipsTheNotificationsStepBeforeAndroid13() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend().apply { signIn(); profile(meId, "") }
        val vm = ProfileViewModel(fakeEnvironment(backend, sdkInt = 32))
        val events = vm.recordEvents(backgroundScope)
        vm.onName("Ana")
        vm.submit()
        assertEquals(AppRoute.OnboardingWidget, events.navigations().single().route)
    }

    @Test fun avatarUploadFailureEmptiesTheAvatarAndKeepsContinue() = runTest(main.dispatcher) {
        val backend = FakeAccountBackend().apply {
            signIn()
            profile(meId, "")
            failures["setAvatar"] = DataError.Storage(app.data.error.StorageFailure.Forbidden, 403, null)
        }
        val vm = ProfileViewModel(fakeEnvironment(backend))
        vm.onName("Ana")
        vm.onPicked(android.net.Uri.parse("content://picked/1"))
        assertTrue(vm.state.value.avatar != null)
        vm.submit()
        assertNull(vm.state.value.avatar)
        assertEquals(ProfileError.Upload, vm.state.value.error)
        assertTrue(vm.state.value.canContinue)
    }
}
