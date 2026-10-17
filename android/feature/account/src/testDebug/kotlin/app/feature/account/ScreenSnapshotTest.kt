package app.feature.account

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.test.onLast
import androidx.compose.ui.test.performScrollToNode
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.error.DataError
import app.data.model.Group
import app.data.model.GroupInvite
import app.data.model.GroupKind
import app.data.model.Post
import app.data.model.ReportTargetKind
import app.designsystem.LocalReduceMotionOverride
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.auth.AgeGateScreen
import app.feature.account.auth.AgeGateUiState
import app.feature.account.auth.CodeError
import app.feature.account.auth.CodeScreen
import app.feature.account.auth.CodeUiState
import app.feature.account.auth.DateEntryPattern
import app.feature.account.auth.PhoneError
import app.feature.account.auth.PhoneScreen
import app.feature.account.auth.PhoneUiState
import app.feature.account.auth.ProfileError
import app.feature.account.auth.ProfileScreen
import app.feature.account.auth.ProfileStep
import app.feature.account.auth.ProfileUiState
import app.feature.account.groups.BirthdayRequestRow
import app.feature.account.groups.CreateError
import app.feature.account.groups.CreateStep
import app.feature.account.groups.FeedEntryCard
import app.feature.account.groups.GroupCreateScreen
import app.feature.account.groups.GroupCreateUiState
import app.feature.account.groups.GroupFeedScreen
import app.feature.account.groups.GroupFeedUiState
import app.feature.account.groups.GROUP_INVITE_LIST_TAG
import app.feature.account.groups.GroupInviteActions
import app.feature.account.groups.GroupInviteScreen
import app.feature.account.groups.GroupInviteUiState
import app.feature.account.groups.GroupPhoto
import app.feature.account.groups.GroupRow
import app.feature.account.groups.GroupScreenActions
import app.feature.account.groups.GroupSettingsActions
import app.feature.account.groups.GroupSettingsScreen
import app.feature.account.groups.GroupSettingsUiState
import app.feature.account.groups.GroupsListScreen
import app.feature.account.groups.GroupsListUiState
import app.feature.account.groups.LeaveGroupDialog
import app.feature.account.groups.MemberRow
import app.feature.account.groups.RowSubtitle
import app.feature.account.groups.TimeDialog
import app.feature.account.invite.InviteJoinScreen
import app.feature.account.invite.InviteJoinState
import app.feature.account.invite.InviteJoinUiState
import app.feature.account.invite.InvitePreviewResult
import app.feature.account.onboarding.NotificationsPermissionScreen
import app.feature.account.onboarding.WidgetPreview
import app.feature.account.onboarding.WidgetScreen
import app.feature.account.paywall.PaywallActions
import app.feature.account.paywall.PaywallMessage
import app.feature.account.paywall.PaywallScreen
import app.feature.account.paywall.PaywallUiState
import app.feature.account.paywall.PaywallWelcome
import app.feature.account.paywall.PlanOption
import app.feature.account.paywall.PlanPeriod
import app.feature.account.paywall.PlansStatus
import app.feature.account.platform.AgeRefusal
import app.feature.account.platform.DeviceContact
import app.feature.account.platform.LegalLinks
import app.feature.account.safety.BlockConfirmation
import app.feature.account.safety.BlockUiState
import app.feature.account.safety.ReportFlow
import app.feature.account.safety.ReportPhase
import app.feature.account.safety.ReportTarget
import app.feature.account.safety.ReportUiState
import app.feature.account.settings.BlockedPerson
import app.feature.account.settings.GroupToggle
import app.feature.account.settings.PermissionRow
import app.feature.account.settings.SettingsAccountActions
import app.feature.account.settings.SettingsAccountScreen
import app.feature.account.settings.SettingsAccountUiState
import app.feature.account.settings.SettingsBlockedScreen
import app.feature.account.settings.SettingsBlockedUiState
import app.feature.account.settings.SettingsNotificationsScreen
import app.feature.account.settings.SettingsNotificationsUiState
import app.feature.account.settings.SettingsRootActions
import app.feature.account.settings.SettingsRootScreen
import app.feature.account.settings.SettingsRootUiState
import app.feature.account.settings.SubscriptionState
import app.feature.account.testing.fakeEnvironment
import app.testing.SamplePhotos
import app.ui.components.EmptyState
import app.ui.components.EmptyStateAction
import app.ui.system.SystemAlertDialog
import app.ui.theme.AppTheme
import coil3.SingletonImageLoader
import com.github.takahirom.roborazzi.captureScreenRoboImage
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.util.Locale

/**
 * Every account surface per state (docs/SCREENS_BRIEF.md rule 7; Pass 4): every state in light, the primary state of each
 * surface also in dark, rendered from the screens' stateless composables at 393 × 852 dp (the references' 393-pt width),
 * xhdpi, Reduce Motion off, real sample photos (`fixtures/photos`, `app.testing.SamplePhotos`). Baselines:
 * `src/test/snapshots/<surface-id>/<state>-<light|dark>.png` (`./gradlew :feature:account:recordRoborazziDebug`).
 * Debug build: BLOCKED copy shows with the literal `{app_name}` placeholder (release omits those elements). Names, numbers
 * and times below are test data. Toasts (C-26) are the platform's `Toast` and are not drawn by the app.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class ScreenSnapshotTest {
    @get:Rule val compose = createComposeRule()

    private val zone = ZoneId.of("UTC")

    /** Thursday of ISO week 42 (the week starts Monday 12 October). */
    private val now = Instant.parse("2026-10-15T17:00:00Z")
    private val legal = LegalLinks("https://example.test/terms", "https://example.test/privacy", "help@example.test")
    private val noop: () -> Unit = {}
    private val context get() = ApplicationProvider.getApplicationContext<android.content.Context>()

    /** Storage URLs in the fixtures are sample-photo URLs, answered by a Coil loader without network. */
    @Before fun photos() = SingletonImageLoader.setUnsafe(SamplePhotos.imageLoader(ApplicationProvider.getApplicationContext()))

    @After fun resetPhotos() = SingletonImageLoader.reset()

    private fun photo(name: String) = SamplePhotos.url(name)

    /**
     * Renders [content] (light, or [dark]), runs [act] (a tap that opens a sheet or an alert), lets [settleMs] of animation
     * pass (sheets and pages need their enter transition; the default is one frame so spinners stop on the same frame) and
     * records `<surface>/<state>-<light|dark>.png`.
     */
    private fun snap(
        surface: String,
        state: String,
        dark: Boolean = false,
        settleMs: Long = FRAME_MS,
        trueBlack: Boolean = false,
        act: (() -> Unit)? = null,
        content: @Composable () -> Unit,
    ) {
        compose.mainClock.autoAdvance = false
        compose.setContent {
            CompositionLocalProvider(LocalAccountEnvironment provides fakeEnvironment(), LocalReduceMotionOverride provides false) {
                AppTheme(dark = dark, trueBlack = trueBlack) { content() }
            }
        }
        compose.mainClock.advanceTimeBy(FRAME_MS)
        if (act != null) {
            // Scrolls and taps animate: the clock runs while they play out (infinite animations do not block idling).
            compose.mainClock.autoAdvance = true
            act()
            compose.waitForIdle()
            compose.mainClock.autoAdvance = false
            compose.mainClock.advanceTimeBy(SHEET_MS)
        }
        compose.mainClock.advanceTimeBy(settleMs)
        captureScreenRoboImage("src/test/snapshots/$surface/$state-${if (dark) "dark" else "light"}.png")
    }

    private fun tap(text: Int) = compose.onNodeWithText(context.getString(text)).performClick()

    // auth.phone ------------------------------------------------------------------------------------
    private val form = PhoneUiState(landing = false, phone = "+1 ", prefill = "+1 ", region = "US")
    private val filled = form.copy(phone = "+1 415-555-0100")
    private fun phone(state: PhoneUiState) = @Composable { PhoneScreen(state, {}, noop, noop, noop, noop, focusOnAppear = false) }
    @Test fun phoneLanding() = snap("auth.phone", "landing", content = phone(PhoneUiState()))
    @Test fun phoneLandingDark() = snap("auth.phone", "landing", dark = true, content = phone(PhoneUiState()))
    @Test fun phoneForm() = snap("auth.phone", "form", content = phone(form))
    @Test fun phoneFormDark() = snap("auth.phone", "form-filled", dark = true, content = phone(filled))
    @Test fun phoneFilled() = snap("auth.phone", "form-filled", content = phone(filled))
    @Test fun phoneSending() = snap("auth.phone", "sending", content = phone(filled.copy(sending = true)))
    @Test fun phoneInvalidNumber() = snap("auth.phone", "invalidNumber", content = phone(form.copy(phone = "+1 12", error = PhoneError.InvalidNumber)))
    @Test fun phoneRateLimited() = snap("auth.phone", "rateLimited", content = phone(filled.copy(error = PhoneError.RateLimited)))
    @Test fun phoneSendFailed() = snap("auth.phone", "sendFailed", content = phone(filled.copy(error = PhoneError.SendFailed)))
    @Test fun phoneOffline() = snap("auth.phone", "offline", content = phone(form.copy(offline = true)))
    @Test fun phoneCountryList() = snap("auth.phone", "countryList", settleMs = SHEET_MS, content = phone(filled.copy(pickingCountry = true)))

    // auth.code -------------------------------------------------------------------------------------
    private val code = CodeUiState(phoneDisplay = "+1 415-555-0100")
    private fun codeScreen(state: CodeUiState) = @Composable { CodeScreen(state, {}, noop, noop, noop, noop, focusOnAppear = false) }
    @Test fun codeDefault() = snap("auth.code", "default", content = codeScreen(code))
    @Test fun codeDefaultDark() = snap("auth.code", "default", dark = true, content = codeScreen(code))
    @Test fun codeFilledResend() = snap("auth.code", "filled-resendEnabled", content = codeScreen(code.copy(code = "123456", resendLocked = false)))
    @Test fun codeVerifying() = snap("auth.code", "verifying", content = codeScreen(code.copy(code = "123456", verifying = true)))
    @Test fun codeWrong() = snap("auth.code", "wrong", content = codeScreen(code.copy(error = CodeError.Wrong)))
    @Test fun codeExpired() = snap("auth.code", "expired", content = codeScreen(code.copy(error = CodeError.Expired)))
    @Test fun codeService() = snap("auth.code", "serviceError", content = codeScreen(code.copy(code = "123456", error = CodeError.Service)))
    @Test fun codeTooMany() = snap("auth.code", "tooMany", content = codeScreen(code.copy(error = CodeError.TooMany)))
    @Test fun codeOffline() = snap("auth.code", "offline", content = codeScreen(code.copy(offline = true)))

    // auth.agegate ----------------------------------------------------------------------------------
    private val us = DateEntryPattern.of(Locale.US)
    private fun age(state: AgeGateUiState, canContinue: Boolean = false) = @Composable { AgeGateScreen(state, us, canContinue, {}, {}, noop, noop, focusOnAppear = false) }
    @Test fun ageDefault() = snap("auth.agegate", "default", content = age(AgeGateUiState()))
    @Test fun ageDefaultDark() = snap("auth.agegate", "default", dark = true, content = age(AgeGateUiState()))
    @Test fun ageFilledOptIn() = snap("auth.agegate", "filled-optIn", content = age(AgeGateUiState(digits = "03142001", optIn = true), canContinue = true))
    @Test fun ageChecking() = snap("auth.agegate", "checking", content = age(AgeGateUiState(digits = "03142001", checking = true)))
    @Test fun ageInvalid() = snap("auth.agegate", "invalidDate", content = age(AgeGateUiState(digits = "02302001", invalidDate = true)))
    @Test fun ageNotConfigured() = snap("auth.agegate", "notConfigured", content = age(AgeGateUiState(notConfigured = true)))
    @Test fun ageUnderAge() = snap("auth.agegate", "underAge", content = age(AgeGateUiState(refusal = AgeRefusal(13))))
    @Test fun ageOffline() = snap("auth.agegate", "offline", content = age(AgeGateUiState(offline = true)))

    // auth.profile ----------------------------------------------------------------------------------
    private val named = ProfileUiState(name = "Ana Lima")
    private val photoStep = named.copy(step = ProfileStep.Photo)
    private fun profile(state: ProfileUiState, avatar: Any? = null) = @Composable { ProfileScreen(state, {}, noop, noop, noop, avatarImage = avatar, focusOnAppear = false) }
    @Test fun profileName() = snap("auth.profile", "name", content = profile(ProfileUiState()))
    @Test fun profileNameDark() = snap("auth.profile", "name-filled", dark = true, content = profile(named))
    @Test fun profileNameFilled() = snap("auth.profile", "name-filled", content = profile(named))
    @Test fun profileNameTooLong() = snap("auth.profile", "name-tooLong", content = profile(ProfileUiState(name = "Ana Lima ".repeat(10))))
    @Test fun profileSavingName() = snap("auth.profile", "name-saving", content = profile(named.copy(saving = true)))
    @Test fun profileNameFailed() = snap("auth.profile", "name-failed", content = profile(named.copy(error = ProfileError.Save)))
    @Test fun profilePhotoEmpty() = snap("auth.profile", "photo-empty", content = profile(photoStep))
    @Test fun profilePhotoEmptyDark() = snap("auth.profile", "photo-chosen", dark = true, content = profile(photoStep, photo("avatar-01")))
    @Test fun profilePhotoChosen() = snap("auth.profile", "photo-chosen", content = profile(photoStep, photo("avatar-01")))
    @Test fun profileUploading() = snap("auth.profile", "photo-uploading", content = profile(photoStep.copy(saving = true), photo("avatar-01")))
    @Test fun profileUploadFailed() = snap("auth.profile", "photo-uploadFailed", content = profile(photoStep.copy(error = ProfileError.Upload)))
    @Test fun profileOffline() = snap("auth.profile", "offline", content = profile(ProfileUiState(offline = true)))

    // onboarding.permission.* -----------------------------------------------------------------------
    @Test fun notificationsDefault() = snap("onboarding.permission.notifications", "default") { NotificationsPermissionScreen(showSkip = true, onContinue = noop, onSkip = noop) }
    @Test fun notificationsDefaultDark() = snap("onboarding.permission.notifications", "default", dark = true) { NotificationsPermissionScreen(showSkip = true, onContinue = noop, onSkip = noop) }
    @Test fun notificationsNoSkip() = snap("onboarding.permission.notifications", "api32-noSkip") { NotificationsPermissionScreen(showSkip = false, onContinue = noop, onSkip = noop) }

    /**
     * The denied blocks are drawn in place by their hosts (camera.capture, photo.viewer) on the media surface: here the same
     * composition — C-27 with the media colours on `color.global.backgroundDeep`, in both appearances.
     */
    @Composable
    private fun DeniedOnMedia(icon: androidx.compose.ui.graphics.vector.ImageVector, title: Int, detail: Int, button: Int) {
        AppTheme(dark = true) {
            Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep), contentAlignment = Alignment.Center) {
                EmptyState(stringResource(title), stringResource(detail), action = EmptyStateAction(stringResource(button), noop), icon = icon)
            }
        }
    }
    private val cameraDenied = @Composable {
        DeniedOnMedia(Tokens.Icons.globalCamera, R.string.onboarding_permission_camera_denied_title, R.string.onboarding_permission_camera_denied_detail, R.string.onboarding_permission_camera_denied_button)
    }
    private val photosDenied = @Composable {
        DeniedOnMedia(Tokens.Icons.globalDownload, R.string.onboarding_permission_photos_denied_title, R.string.onboarding_permission_photos_denied_detail, R.string.onboarding_permission_photos_denied_button)
    }
    @Test fun cameraDeniedLight() = snap("onboarding.permission.camera", "denied", content = cameraDenied)
    @Test fun cameraDeniedDark() = snap("onboarding.permission.camera", "denied", dark = true, content = cameraDenied)
    @Test fun cameraRationale() = snap("onboarding.permission.camera", "rationale") {
        rationaleOver(R.string.system_permissions_rationale_camera_title, R.string.system_permissions_rationale_camera_message, R.string.system_permissions_rationale_continue)
    }
    @Test fun photosDeniedLight() = snap("onboarding.permission.photos", "denied", content = photosDenied)
    @Test fun photosDeniedDark() = snap("onboarding.permission.photos", "denied", dark = true, content = photosDenied)

    // onboarding.permission.contacts lives in groups.invite (its Contacts section).
    // The Contacts section sits under the link controls: each render scrolls the sheet to it.
    // The sheet is a lazy list: scroll it until the node is composed and shown.
    private fun scrollTo(text: Int): () -> Unit = scrollToText(context.getString(text))
    private fun scrollToText(text: String): () -> Unit = { compose.onNodeWithTag(GROUP_INVITE_LIST_TAG).performScrollToNode(hasText(text)) }
    @Test fun contactsNotAsked() = snap("onboarding.permission.contacts", "notAsked", act = scrollTo(R.string.onboarding_permission_contacts_card_button), content = inviteScreen(linkOn))
    @Test fun contactsNotAskedDark() = snap("onboarding.permission.contacts", "notAsked", dark = true, act = scrollTo(R.string.onboarding_permission_contacts_card_button), content = inviteScreen(linkOn))
    @Test fun contactsGranted() = snap("onboarding.permission.contacts", "granted", act = scrollToText("Zoe Park"), content = inviteScreen(withContacts))
    @Test fun contactsNone() = snap("onboarding.permission.contacts", "noContacts", act = scrollTo(R.string.groups_invite_contacts_empty), content = inviteScreen(linkOn.copy(contactsGranted = true, contacts = emptyList())))
    @Test fun contactsRationale() = snap("onboarding.permission.contacts", "rationale", act = scrollTo(R.string.onboarding_permission_contacts_card_button)) {
        inviteScreen(linkOn)()
        SystemAlertDialog(
            stringResource(R.string.system_permissions_rationale_contacts_title),
            stringResource(R.string.system_permissions_rationale_contacts_message),
            stringResource(R.string.system_permissions_rationale_continue),
            noop,
            stringResource(R.string.system_permissions_rationale_notnow),
            noop,
        )
    }

    // onboarding.widget -----------------------------------------------------------------------------
    private val widgetSteps @Composable get() = listOf(
        stringResource(R.string.onboarding_widget_step_android_1),
        stringResource(R.string.onboarding_widget_step_android_2),
        stringResource(R.string.onboarding_widget_step_android_3),
    )
    private val widgetPreview = WidgetPreview(photo("dinner-pizza-cheers-3x4"), "Sam")
    @Test fun widgetDefault() = snap("onboarding.widget", "default") { WidgetScreen(widgetSteps, widgetPreview, noop, noop) }
    @Test fun widgetDefaultDark() = snap("onboarding.widget", "default", dark = true) { WidgetScreen(widgetSteps, widgetPreview, noop, noop) }
    @Test fun widgetNoPhoto() = snap("onboarding.widget", "noPhotoYet") { WidgetScreen(widgetSteps, null, noop, noop) }
    @Test fun widgetFromSettings() = snap("onboarding.widget", "fromSettings") { WidgetScreen(widgetSteps, widgetPreview, noop, noop, onBack = noop) }

    // system.permissions ----------------------------------------------------------------------------
    @Composable
    private fun rationaleOver(title: Int, message: Int, confirm: Int) {
        Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep))
        SystemAlertDialog(stringResource(title), stringResource(message), stringResource(confirm), noop, stringResource(R.string.system_permissions_rationale_notnow), noop)
    }
    @Test fun rationaleMicrophone() = snap("system.permissions", "rationale-microphone") {
        rationaleOver(R.string.system_permissions_rationale_microphone_title, R.string.system_permissions_rationale_microphone_message, R.string.system_permissions_rationale_continue)
    }
    @Test fun rationaleMicrophoneDark() = snap("system.permissions", "rationale-microphone", dark = true) {
        rationaleOver(R.string.system_permissions_rationale_microphone_title, R.string.system_permissions_rationale_microphone_message, R.string.system_permissions_rationale_continue)
    }
    @Test fun rationaleNotifications() = snap("system.permissions", "rationale-notifications") {
        rationaleOver(R.string.system_permissions_rationale_notifications_title, R.string.system_permissions_rationale_notifications_message, R.string.system_permissions_rationale_continue)
    }
    @Test fun permanentlyDenied() = snap("system.permissions", "permanentlyDenied-camera") {
        rationaleOver(R.string.system_permissions_rationale_camera_title, R.string.system_permissions_rationale_camera_message, R.string.system_permissions_opensettings)
    }

    // groups.list -----------------------------------------------------------------------------------
    private val faces = listOf(photo("avatar-01"), photo("avatar-02"), photo("avatar-06"), photo("avatar-04"))
    private val rows = listOf(
        GroupRow("g1", "Sunday Dinners", photo("dinner-long-table-3x4"), RowSubtitle.SentPic("Sam"), now.minusSeconds(7200), faces),
        GroupRow("g2", "Roomies", photo("movie-night-couch-4x3"), RowSubtitle.NewPic, now.minusSeconds(18000), faces.take(3)),
        GroupRow("g3", "Lima Family", photo("family-dinner-4x3"), RowSubtitle.CreatedBy("Rui"), now.minusSeconds(86400), listOf(photo("avatar-06"), null)),
        GroupRow("g4", "Book Club", null, RowSubtitle.CreatedByYou, now.minusSeconds(3 * 86400L), listOf(photo("avatar-01"))),
    )
    private fun list(state: GroupsListUiState) = @Composable { GroupsListScreen(state, noop, {}, {}, noop, {}) }
    @Test fun listLoading() = snap("groups.list", "loading", content = list(GroupsListUiState()))
    @Test fun listDefault() = snap("groups.list", "default", content = list(GroupsListUiState(rows = rows, refreshing = false)))
    @Test fun listDefaultDark() = snap("groups.list", "default", dark = true, content = list(GroupsListUiState(rows = rows, refreshing = false)))
    /** Settings → True Black on (Android, owner decision 21): the dark page in `color.global.background.android.trueBlack`. */
    @Test fun listDefaultTrueBlack() = snap("groups.list", "default-trueBlack", dark = true, trueBlack = true, content = list(GroupsListUiState(rows = rows, refreshing = false)))
    @Test fun listEmpty() = snap("groups.list", "empty", content = list(GroupsListUiState(rows = emptyList(), refreshing = false)))
    @Test fun listError() = snap("groups.list", "error", content = list(GroupsListUiState(refreshing = false, error = DataError.Unexpected("x"))))
    @Test fun listOffline() = snap("groups.list", "offline", content = list(GroupsListUiState(refreshing = false, error = DataError.Network)))
    @Test fun listOfflineCached() = snap("groups.list", "offline-cached", content = list(GroupsListUiState(rows = rows, refreshing = false, error = DataError.Network)))

    // groups.create ---------------------------------------------------------------------------------
    private val details = GroupCreateUiState(step = CreateStep.Details, kind = GroupKind.Friends)
    private fun create(state: GroupCreateUiState, cover: Any? = state.coverImage) = @Composable { GroupCreateScreen(state, noop, {}, {}, noop, noop, coverImage = cover) }
    @Test fun createType() = snap("groups.create", "stepA", content = create(GroupCreateUiState()))
    @Test fun createTypeDark() = snap("groups.create", "stepA", dark = true, content = create(GroupCreateUiState()))
    @Test fun createDetails() = snap("groups.create", "stepB", content = create(details))
    @Test fun createDetailsDark() = snap("groups.create", "stepB-filled", dark = true, content = create(details.copy(name = "Sunday Dinners"), photo("dinner-long-table-3x4")))
    @Test fun createFilled() = snap("groups.create", "stepB-filled", content = create(details.copy(name = "Sunday Dinners"), photo("dinner-long-table-3x4")))
    @Test fun createPreset() = snap("groups.create", "stepB-preset", content = create(details.copy(kind = GroupKind.Family, kindPreset = true)))
    @Test fun createTooLong() = snap("groups.create", "stepB-tooLong", content = create(details.copy(name = "Sunday Dinners ".repeat(6))))
    @Test fun createCreating() = snap("groups.create", "creating", content = create(details.copy(name = "Sunday Dinners", working = true), photo("dinner-long-table-3x4")))
    @Test fun createFailed() = snap("groups.create", "createFailed", content = create(details.copy(name = "Sunday Dinners", error = CreateError.Failed)))
    @Test fun createCoverFailed() = snap("groups.create", "coverFailed", content = create(details.copy(name = "Sunday Dinners", error = CreateError.Cover)))
    @Test fun createOffline() = snap("groups.create", "offline", content = create(details.copy(name = "Sunday Dinners", error = CreateError.Offline)))
    private val edit = GroupCreateUiState(editGroupId = "g1", step = CreateStep.Details, kindPreset = true, name = "Sunday Dinners", currentCoverUrl = photo("dinner-long-table-3x4"))
    @Test fun createEdit() = snap("groups.create", "edit", content = create(edit))
    @Test fun createSaveFailed() = snap("groups.create", "saveFailed", content = create(edit.copy(error = CreateError.SaveFailed)))

    // groups.invite ---------------------------------------------------------------------------------
    private val liveInvite = GroupInvite("i1", "g1", "AbCdEfGhIjKlMnOpQrStUvWx", "u-me", now, null, null)
    private val invite = GroupInviteUiState(groupName = "Sunday Dinners", coverUrl = photo("dinner-long-table-3x4"), loading = false, maxMembers = 30)
    private val linkOn = invite.copy(invite = liveInvite)
    private val withContacts = linkOn.copy(
        contactsGranted = true,
        contacts = listOf(
            DeviceContact("1", "Ana Lima", "+14155550101", null),
            DeviceContact("2", "Rui Costa", "+14155550102", null),
            DeviceContact("3", "Sam Lee", "+14155550103", null),
            DeviceContact("4", "Zoe Park", "+14155550104", null),
        ),
        invited = setOf("2"),
    )
    private fun inviteScreen(state: GroupInviteUiState) = @Composable { GroupInviteScreen(state, GroupInviteActions()) }
    @Test fun inviteLoading() = snap("groups.invite", "loading", content = inviteScreen(invite.copy(loading = true)))
    @Test fun inviteLinkOff() = snap("groups.invite", "linkOff", content = inviteScreen(invite))
    @Test fun inviteLinkOn() = snap("groups.invite", "linkOn", content = inviteScreen(linkOn))
    @Test fun inviteLinkOnDark() = snap("groups.invite", "linkOn", dark = true, content = inviteScreen(linkOn))
    @Test fun inviteCreating() = snap("groups.invite", "creating", content = inviteScreen(invite.copy(creating = true)))
    @Test fun inviteFull() = snap("groups.invite", "full", content = inviteScreen(invite.copy(full = true)))
    @Test fun inviteError() = snap("groups.invite", "error", content = inviteScreen(invite.copy(error = true)))
    @Test fun inviteOffline() = snap("groups.invite", "offline", content = inviteScreen(invite.copy(error = true, offline = true)))
    @Test fun inviteTurnOff() = snap("groups.invite", "turnOffAlert", content = inviteScreen(linkOn.copy(confirmTurnOff = true)))
    @Test fun inviteNoCover() = snap("groups.invite", "linkOn-noCover-family", content = inviteScreen(linkOn.copy(coverUrl = null, kind = GroupKind.Family, groupName = "Lima Family")))

    // The QR card (owner decision 17): the recap preview over the sheet — the group's cover blurred, the card, Save, Share.
    private val qrLink = "https://example.test/i/AbCdEfGhIjKlMnOpQrStUvWx"
    private fun qrScreen(state: GroupInviteUiState) = @Composable { GroupInviteScreen(state, GroupInviteActions(), qrLink = qrLink) }
    @Test fun inviteQr() = snap("groups.invite", "qr", content = qrScreen(linkOn))
    @Test fun inviteQrDark() = snap("groups.invite", "qr", dark = true, content = qrScreen(linkOn))
    @Test fun inviteQrNoCover() = snap("groups.invite", "qr-noCover", content = qrScreen(linkOn.copy(coverUrl = null, groupName = "Lima Family")))

    // groups.screen ---------------------------------------------------------------------------------
    private val group = Group("g1", "Sunday Dinners", GroupKind.Friends, "covers/g1.jpg", "UTC", LocalTime.of(9, 0), LocalTime.of(21, 0), false, "u-me", now.minusSeconds(40 * 86400L), now)
    private val members = listOf(photo("avatar-01"), photo("avatar-02"), photo("avatar-06"), photo("avatar-04"), null, photo("avatar-09"))
    private fun post(id: String, author: String, at: String) = Post(id, "m$id", "g1", author, null, null, null, null, true, null, Instant.parse(at))
    private fun item(id: String, author: String, first: String, face: String, at: String, picture: String) =
        GroupPhoto(post(id, author, at), photo(picture), first, photo(face), mine = author == "u-me")
    private val photos = listOf(
        item("p1", "u-sam", "Sam", "avatar-02", "2026-10-15T14:00:00Z", "dinner-pizza-cheers-3x4"),
        item("p2", "u-me", "Ana", "avatar-01", "2026-10-14T19:30:00Z", "friends-picnic-blanket-3x4"),
        item("p3", "u-rui", "Rui", "avatar-06", "2026-10-13T09:10:00Z", "coffee-latte-heart-3x4"),
        item("p4", "u-sam", "Sam", "avatar-02", "2026-10-12T16:45:00Z", "hike-meadow-trail-3x4"),
        item("p5", "u-rui", "Rui", "avatar-06", "2026-10-10T20:00:00Z", "campfire-woods-3x4"),
        item("p6", "u-sam", "Sam", "avatar-02", "2026-10-10T13:00:00Z", "picnic-spread-3x4"),
        item("p7", "u-me", "Ana", "avatar-01", "2026-10-10T11:00:00Z", "friends-stairs-laughing-3x4"),
        item("p8", "u-zoe", "Zoe", "avatar-04", "2026-10-09T18:00:00Z", "dinner-toast-candles-3x4"),
        item("p9", "u-rui", "Rui", "avatar-06", "2026-10-09T10:00:00Z", "autumn-path-3x4"),
    )
    private val feedState = GroupFeedUiState(group = group, coverUrl = photo("dinner-long-table-3x4"), photos = photos, isCreator = true, memberAvatars = members)
    private fun feed(state: GroupFeedUiState, entries: Boolean = false) = @Composable {
        GroupFeedScreen(
            state,
            now,
            zone,
            GroupScreenActions(),
            birthdayRows = {
                if (entries) BirthdayRequestRow(stringResource(R.string.birthday_request_title, "Zoe"), stringResource(R.string.birthday_request_due, "Oct 20"), photo("avatar-04"), noop)
            },
            feedCards = {
                if (entries) {
                    FeedEntryCard(Tokens.Icons.globalRewind, stringResource(R.string.onthisday_entry_title), stringResource(R.string.onthisday_entry_subtitle, "Sunday Dinners"), stringResource(R.string.onthisday_entry_button), null, noop)
                    FeedEntryCard(Tokens.Icons.globalRecap, stringResource(R.string.year_story_entry_title), stringResource(R.string.year_story_entry_subtitle, "2025"), stringResource(R.string.year_story_entry_button), null, noop)
                }
            },
        )
    }
    @Test fun feedLoading() = snap("groups.screen", "loading", content = feed(GroupFeedUiState(group = group, coverUrl = photo("dinner-long-table-3x4"))))
    @Test fun feedDefault() = snap("groups.screen", "default", content = feed(feedState))
    @Test fun feedDefaultDark() = snap("groups.screen", "default", dark = true, content = feed(feedState))
    @Test fun feedEntries() = snap("groups.screen", "default-memoryEntries", content = feed(feedState, entries = true))
    // birthday.tribute entry (MERGE FV-3): the honoree's video card in the feed pager — `icon.global.video`, the poster
    // (the title card), the birthday in the memory date format, the "Play" pill.
    private fun tributeCard(title: @Composable () -> String) = @Composable {
        Box(Modifier.fillMaxSize().background(app.ui.foundation.PageRoles.page).padding(start = Tokens.Sizes.globalScreenMargin)) {
            FeedEntryCard(Tokens.Icons.globalVideo, title(), "Dec 12, 2026", stringResource(R.string.birthday_tribute_entry_button), photo("dinner-toast-candles-3x4"), noop)
        }
    }
    @Test fun feedTributeCard() = snap("groups.screen", "tributeCard", content = tributeCard { stringResource(R.string.birthday_tribute_title) })
    @Test fun feedTributeCardDark() = snap("groups.screen", "tributeCard", dark = true, content = tributeCard { stringResource(R.string.birthday_tribute_title) })
    @Test fun feedTributeCardContributor() = snap("groups.screen", "tributeCard-contributor", content = tributeCard { stringResource(R.string.birthday_tribute_title_member, "Zoe") })
    @Test fun feedCreated() = snap("groups.screen", "created", content = feed(feedState.copy(photos = emptyList(), memberAvatars = members.take(1))))
    @Test fun feedEmpty() = snap("groups.screen", "empty", content = feed(feedState.copy(photos = emptyList(), isCreator = false)))
    @Test fun feedQuietWeek() = snap("groups.screen", "quietWeek", content = feed(feedState.copy(photos = photos.drop(4))))
    @Test fun feedError() = snap("groups.screen", "error", content = feed(GroupFeedUiState(group = group, coverUrl = photo("dinner-long-table-3x4"), memberAvatars = members, error = DataError.Unexpected("x"))))
    @Test fun feedOffline() = snap("groups.screen", "offline", content = feed(GroupFeedUiState(group = group, coverUrl = photo("dinner-long-table-3x4"), error = DataError.Network)))
    @Test fun feedRemoved() = snap("groups.screen", "removed", content = feed(GroupFeedUiState(group = group, removed = true)))

    // groups.settings -------------------------------------------------------------------------------
    private val memberRows = listOf(
        MemberRow("u-me", "Ana Lima", "Ana", photo("avatar-01"), admin = true, you = true),
        MemberRow("u-sam", "Sam Lee", "Sam", photo("avatar-02"), admin = false, you = false),
        MemberRow("u-rui", "Rui Costa", "Rui", photo("avatar-06"), admin = true, you = false),
        MemberRow("u-zoe", "Zoe Park", "Zoe", null, admin = false, you = false),
    )
    private val settings = GroupSettingsUiState(group = group, members = memberRows, isAdmin = true)
    private fun groupSettings(state: GroupSettingsUiState) = @Composable { GroupSettingsScreen(state, GroupSettingsActions()) }
    @Test fun groupSettingsLoading() = snap("groups.settings", "loading", content = groupSettings(GroupSettingsUiState()))
    @Test fun groupSettingsAdmin() = snap("groups.settings", "default-admin", content = groupSettings(settings))
    @Test fun groupSettingsAdminDark() = snap("groups.settings", "default-admin", dark = true, content = groupSettings(settings))
    @Test fun groupSettingsMember() = snap("groups.settings", "member", content = groupSettings(settings.copy(isAdmin = false, muted = true, group = group.copy(invitationPaused = true))))
    @Test fun groupSettingsFailed() = snap("groups.settings", "changeFailed", content = groupSettings(settings.copy(failed = true)))
    @Test fun groupSettingsInvalid() = snap("groups.settings", "invalidWindow", content = groupSettings(settings.copy(invalidWindow = true)))
    @Test fun groupSettingsOffline() = snap("groups.settings", "offline", content = groupSettings(settings.copy(online = false)))
    @Test fun groupSettingsLeave() = snap("groups.settings", "leaveAlert") {
        groupSettings(settings)()
        LeaveGroupDialog("Sunday Dinners", last = false, onConfirm = noop, onDismiss = noop)
    }
    @Test fun groupSettingsLeaveLast() = snap("groups.settings", "leaveAlert-lastMember") {
        groupSettings(settings.copy(members = memberRows.take(1)))()
        LeaveGroupDialog("Sunday Dinners", last = true, onConfirm = noop, onDismiss = noop)
    }
    @Test fun groupSettingsHours() = snap("groups.settings", "hoursPicker", settleMs = SHEET_MS) {
        groupSettings(settings)()
        TimeDialog(stringResource(R.string.settings_notifications_quiethours_start), LocalTime.of(9, 0), onCancel = noop) {}
    }

    // settings.root ---------------------------------------------------------------------------------
    private val rootState = SettingsRootUiState(name = "Ana Lima", phone = "+1 415-555-0100", avatar = photo("avatar-01"), subscription = SubscriptionState.None)
    private val granted = listOf(
        PermissionRow(R.string.settings_root_permissions_camera, false),
        PermissionRow(R.string.settings_root_permissions_microphone, false),
        PermissionRow(R.string.settings_root_permissions_contacts, false),
        PermissionRow(R.string.settings_root_permissions_notifications, false),
    )
    private fun root(state: SettingsRootUiState, permissions: List<PermissionRow> = granted) = @Composable { SettingsRootScreen(state, legal, permissions, "1.0 (1)", SettingsRootActions()) }
    @Test fun settingsRoot() = snap("settings.root", "default", content = root(rootState))
    @Test fun settingsRootDark() = snap("settings.root", "default", dark = true, content = root(rootState))
    /**
     * The Appearance section (Android only) with True Black on, in the true-black dark appearance it selects (owner
     * decision 21); `default-dark` shows it off on Retro's default #1C1C1E page.
     */
    @Test fun settingsRootTrueBlack() = snap("settings.root", "trueBlackOn", dark = true, trueBlack = true, content = root(rootState.copy(trueBlack = true)))
    @Test fun settingsRootLoading() = snap("settings.root", "subscriptionLoading", content = root(rootState.copy(subscription = SubscriptionState.Loading)))
    @Test fun settingsRootSubscriber() = snap("settings.root", "subscriber-annual", content = root(rootState.copy(subscription = SubscriptionState.Annual)))
    @Test fun settingsRootDenied() = snap("settings.root", "permissionsDenied-scrolled", act = { compose.onNodeWithText(context.getString(R.string.settings_root_permissions_notifications)).performScrollTo() }) {
        root(rootState, granted.mapIndexed { i, row -> row.copy(denied = i % 2 == 0) })()
    }
    @Test fun settingsRootSigningOut() = snap("settings.root", "signingOut-scrolled", act = { compose.onNodeWithText(context.getString(R.string.settings_root_version)).performScrollTo() }) {
        root(rootState.copy(signingOut = true))()
    }
    @Test fun settingsRootSignOutAlert() = snap("settings.root", "signOutAlert", act = {
        compose.onNodeWithText(context.getString(R.string.settings_root_signout)).performScrollTo()
        tap(R.string.settings_root_signout)
    }) { root(rootState)() }

    // settings.notifications ------------------------------------------------------------------------
    private val notif = SettingsNotificationsUiState(
        groups = listOf(
            GroupToggle("g1", "Sunday Dinners", false, photo("dinner-long-table-3x4")),
            GroupToggle("g2", "Roomies", true, photo("movie-night-couch-4x3")),
            GroupToggle("g3", "Lima Family", false, null),
        ),
        quietStart = LocalTime.of(22, 0),
        quietEnd = LocalTime.of(7, 0),
        quietOn = true,
        loaded = true,
    )
    private fun notifications(state: SettingsNotificationsUiState, off: Boolean = false) = @Composable { SettingsNotificationsScreen(state, off, noop, noop, { _, _ -> }, {}, {}, {}, noop) }
    @Test fun notificationsLoading() = snap("settings.notifications", "loading", content = notifications(SettingsNotificationsUiState()))
    @Test fun notificationsSettingsDefault() = snap("settings.notifications", "default", content = notifications(notif))
    @Test fun notificationsSettingsDefaultDark() = snap("settings.notifications", "default", dark = true, content = notifications(notif))
    @Test fun notificationsSystemOff() = snap("settings.notifications", "permissionOff", content = notifications(notif.copy(quietOn = false, quietStart = null, quietEnd = null), off = true))
    @Test fun notificationsNoGroups() = snap("settings.notifications", "noGroups", content = notifications(notif.copy(groups = emptyList())))
    @Test fun notificationsError() = snap("settings.notifications", "changeFailed", content = notifications(notif.copy(error = true)))
    // Pause All on: the second footer line "Until 12:00 AM" (the next local midnight)
    private val pauseEnd = java.time.LocalDate.of(2026, 10, 16).atStartOfDay(java.time.ZoneId.systemDefault()).toInstant()
    @Test fun notificationsPaused() = snap("settings.notifications", "paused", content = notifications(notif.copy(pausedUntil = pauseEnd)))
    @Test fun notificationsPausedDark() = snap("settings.notifications", "paused", dark = true, content = notifications(notif.copy(pausedUntil = pauseEnd)))
    /** camera.overnight's switch ("Developed Photos") turned off, scrolled into view. */
    @Test fun notificationsOvernightOff() = snap("settings.notifications", "overnightOff", act = { compose.onNodeWithText(context.getString(R.string.camera_overnight_settings_row)).performScrollTo() }, content = notifications(notif.copy(overnightOn = false)))

    // settings.account ------------------------------------------------------------------------------
    private val account = SettingsAccountUiState(name = "Ana Lima", avatar = photo("avatar-01"), hasPhoto = true, phone = "+1 415-555-0100", birthday = LocalDate.of(2001, 7, 5))
    private fun accountScreen(state: SettingsAccountUiState) = @Composable { SettingsAccountScreen(state, SettingsAccountActions()) }
    @Test fun accountDefault() = snap("settings.account", "default", content = accountScreen(account))
    @Test fun accountDefaultDark() = snap("settings.account", "default", dark = true, content = accountScreen(account))
    @Test fun accountNoPhoto() = snap("settings.account", "noPhoto-noBirthday", content = accountScreen(account.copy(avatar = null, hasPhoto = false, birthday = null)))
    @Test fun accountPhotoSheet() = snap("settings.account", "photoSheet", act = { tap(R.string.settings_account_photo) }, content = accountScreen(account))
    @Test fun accountSavingPhoto() = snap("settings.account", "savingPhoto", content = accountScreen(account.copy(savingPhoto = true)))
    @Test fun accountEditName() = snap("settings.account", "editName", settleMs = SHEET_MS, content = accountScreen(account.copy(editingName = true)))
    @Test fun accountSavingName() = snap("settings.account", "editName-saving", settleMs = SHEET_MS, content = accountScreen(account.copy(editingName = true, savingName = true)))
    @Test fun accountSaveError() = snap("settings.account", "saveFailed", content = accountScreen(account.copy(saveError = true)))
    @Test fun accountConfirm() = snap("settings.account", "deleteConfirm", content = accountScreen(account.copy(confirmDelete = true)))
    @Test fun accountConfirmPremium() = snap("settings.account", "deleteConfirm-premium", content = accountScreen(account.copy(confirmDelete = true, premium = true)))
    @Test fun accountDeleting() = snap("settings.account", "deleting", content = accountScreen(account.copy(deleting = true)))
    @Test fun accountDeleteError() = snap("settings.account", "deleteFailed", content = accountScreen(account.copy(deleteError = true)))
    @Test fun accountCameraDenied() = snap("settings.account", "cameraDenied", content = accountScreen(account.copy(cameraDenied = true)))

    // settings.blocked ------------------------------------------------------------------------------
    private val blockedPeople = listOf(
        BlockedPerson("u1", "Sam Lee", photo("avatar-02"), "Sam"),
        BlockedPerson("u2", "Zoe Park", photo("avatar-04"), "Zoe"),
        BlockedPerson("u3", null, null),
    )
    private fun blocked(state: SettingsBlockedUiState) = @Composable { SettingsBlockedScreen(state, noop, {}, noop) }
    @Test fun blockedLoading() = snap("settings.blocked", "loading", content = blocked(SettingsBlockedUiState()))
    @Test fun blockedList() = snap("settings.blocked", "default", content = blocked(SettingsBlockedUiState(people = blockedPeople)))
    @Test fun blockedListDark() = snap("settings.blocked", "default", dark = true, content = blocked(SettingsBlockedUiState(people = blockedPeople)))
    @Test fun blockedEmpty() = snap("settings.blocked", "empty", content = blocked(SettingsBlockedUiState(people = emptyList())))
    @Test fun blockedError() = snap("settings.blocked", "error", content = blocked(SettingsBlockedUiState(error = true)))
    @Test fun blockedUnblockFailed() = snap("settings.blocked", "unblockFailed", content = blocked(SettingsBlockedUiState(people = blockedPeople, unblockFailed = true)))

    // safety.report ---------------------------------------------------------------------------------
    private val postTarget = ReportTarget(ReportTargetKind.Post, "p1", "g1", "u-sam")
    private fun report(state: ReportUiState) = @Composable {
        feed(feedState)()
        ReportFlow(state, noop, {}, noop, noop, {})
    }
    @Test fun reportPost() = snap("safety.report", "reasons-post", settleMs = SHEET_MS, content = report(ReportUiState(postTarget, firstName = "Sam", groupName = "Sunday Dinners")))
    @Test fun reportPostDark() = snap("safety.report", "reasons-post", dark = true, settleMs = SHEET_MS, content = report(ReportUiState(postTarget, firstName = "Sam", groupName = "Sunday Dinners")))
    @Test fun reportUser() = snap("safety.report", "reasons-user", settleMs = SHEET_MS, content = report(ReportUiState(ReportTarget(ReportTargetKind.User, "u-sam", "g1", "u-sam"), firstName = "Sam")))
    @Test fun reportGroup() = snap("safety.report", "reasons-group", settleMs = SHEET_MS, content = report(ReportUiState(ReportTarget(ReportTargetKind.Group, "g1", "g1", null), groupName = "Sunday Dinners")))
    @Test fun reportMessage() = snap("safety.report", "reasons-message", settleMs = SHEET_MS, content = report(ReportUiState(ReportTarget(ReportTargetKind.Message, "m1", "g1", "u-sam"), firstName = "Sam")))
    @Test fun reportNextSteps() = snap("safety.report", "nextSteps", settleMs = SHEET_MS, content = report(ReportUiState(postTarget, phase = ReportPhase.NextSteps, firstName = "Sam", groupName = "Sunday Dinners")))
    @Test fun reportConfirmLeave() = snap("safety.report", "confirmLeave", content = report(ReportUiState(postTarget, phase = ReportPhase.ConfirmLeave, firstName = "Sam", groupName = "Sunday Dinners")))
    @Test fun reportSending() = snap("safety.report", "sending", content = report(ReportUiState(postTarget, phase = ReportPhase.Sending, firstName = "Sam")))
    @Test fun reportError() = snap("safety.report", "failed", content = report(ReportUiState(postTarget, phase = ReportPhase.Error, firstName = "Sam")))
    @Test fun reportGone() = snap("safety.report", "targetGone", content = report(ReportUiState(postTarget, phase = ReportPhase.NotFound)))

    // safety.block ----------------------------------------------------------------------------------
    private fun block(state: BlockUiState) = @Composable {
        feed(feedState)()
        BlockConfirmation(state, noop, noop)
    }
    @Test fun blockConfirm() = snap("safety.block", "confirming", content = block(BlockUiState("Sam")))
    @Test fun blockConfirmDark() = snap("safety.block", "confirming", dark = true, content = block(BlockUiState("Sam")))
    @Test fun blockBlocking() = snap("safety.block", "blocking", content = block(BlockUiState("Sam", blocking = true)))
    @Test fun blockError() = snap("safety.block", "failed", content = block(BlockUiState("Sam", error = true)))

    // paywall ---------------------------------------------------------------------------------------
    /** Owner decision 7: $3.99 a month; $35.99 a year with a 1-week free trial (Play's free-trial offer, the locale's words). */
    private val plans = listOf(PlanOption(PlanPeriod.Monthly, "$3.99", null), PlanOption(PlanPeriod.Yearly, "$35.99", null, trialDuration = "1 week"))
    private val ready = PaywallUiState(plans = plans, status = PlansStatus.Ready, media = photo("friends-beach-hug-4x5"))
    private fun paywall(state: PaywallUiState) = @Composable { PaywallScreen(state, legal, PaywallActions()) }
    @Test fun paywallLoading() = snap("paywall", "loading", content = paywall(PaywallUiState(media = photo("friends-beach-hug-4x5"))))
    @Test fun paywallReady() = snap("paywall", "default", content = paywall(ready))
    @Test fun paywallReadyDark() = snap("paywall", "default", dark = true, content = paywall(ready))
    @Test fun paywallNoMedia() = snap("paywall", "default-noPhoto-historyLimited", content = paywall(ready.copy(media = null, historyLimited = true)))
    @Test fun paywallUnavailable() = snap("paywall", "productsUnavailable", content = paywall(PaywallUiState(status = PlansStatus.Unavailable, media = photo("friends-beach-hug-4x5"))))
    @Test fun paywallOffline() = snap("paywall", "offline", content = paywall(PaywallUiState(status = PlansStatus.Offline, media = photo("friends-beach-hug-4x5"))))
    @Test fun paywallNoTrial() = snap("paywall", "default-noTrial", content = paywall(ready.copy(plans = plans.map { PlanOption(it.period, it.price, null) })))
    /** The Monthly card in view (the plan pager's second card; its billing line follows in the footer). */
    @Test fun paywallMonthly() = snap("paywall", "monthly", act = {
        compose.onAllNodes(androidx.compose.ui.test.hasScrollToIndexAction()).onLast().performScrollToIndex(1)
    }, content = paywall(ready))
    @Test fun paywallPurchasing() = snap("paywall", "purchasing", content = paywall(ready.copy(purchasing = PlanPeriod.Yearly)))
    @Test fun paywallRestoreOffline() = snap("paywall", "restoreOffline", content = paywall(ready.copy(message = PaywallMessage.Offline)))
    @Test fun paywallFailed() = snap("paywall", "purchaseFailed", content = paywall(ready.copy(message = PaywallMessage.PurchaseFailed)))
    @Test fun paywallPending() = snap("paywall", "pending", content = paywall(ready.copy(message = PaywallMessage.Pending)))
    @Test fun paywallRestoreNone() = snap("paywall", "nothingToRestore", content = paywall(ready.copy(message = PaywallMessage.NothingToRestore)))
    @Test fun paywallWelcome() = snap("paywall", "welcome", content = paywall(ready.copy(welcome = PaywallWelcome.Purchased)))
    @Test fun paywallRestored() = snap("paywall", "welcome-restored", content = paywall(ready.copy(welcome = PaywallWelcome.Restored)))

    // invite.web (Android join path) ----------------------------------------------------------------
    private val preview = InvitePreviewResult.Valid(
        groupName = "Sunday Dinners",
        groupKind = GroupKind.Friends,
        inviterFirstName = "Sam",
        coverUrl = photo("dinner-long-table-3x4"),
        inviterAvatarUrl = photo("avatar-02"),
        memberAvatars = listOf(photo("avatar-02"), photo("avatar-06"), photo("avatar-04"), null),
    )
    private fun join(state: InviteJoinUiState) = @Composable { InviteJoinScreen(state, noop, noop, onTerms = noop, onPrivacy = noop) }
    @Test fun inviteJoinLoading() = snap("invite.web", "android-loading", content = join(InviteJoinUiState()))
    @Test fun inviteJoinReady() = snap("invite.web", "android-valid", content = join(InviteJoinUiState(InviteJoinState.Ready, preview)))
    @Test fun inviteJoinReadyDark() = snap("invite.web", "android-valid", dark = true, content = join(InviteJoinUiState(InviteJoinState.Ready, preview)))
    @Test fun inviteJoinOpening() = snap("invite.web", "android-opening", content = join(InviteJoinUiState(InviteJoinState.Ready, preview, opening = true)))
    @Test fun inviteJoinNoCover() = snap("invite.web", "android-valid-noCover", content = join(InviteJoinUiState(InviteJoinState.Ready, preview.copy(coverUrl = null, memberAvatars = emptyList()))))
    @Test fun inviteJoinUnavailable() = snap("invite.web", "android-unavailable", content = join(InviteJoinUiState(InviteJoinState.Unavailable)))
    @Test fun inviteJoinNotFound() = snap("invite.web", "android-notFound", content = join(InviteJoinUiState(InviteJoinState.NotFound)))
    @Test fun inviteJoinFull() = snap("invite.web", "android-full", content = join(InviteJoinUiState(InviteJoinState.Full, preview)))
    @Test fun inviteJoinError() = snap("invite.web", "android-error", content = join(InviteJoinUiState(InviteJoinState.Error)))
    @Test fun inviteJoinRateLimited() = snap("invite.web", "android-rateLimited", content = join(InviteJoinUiState(InviteJoinState.RateLimited)))
    @Test fun inviteJoinOffline() = snap("invite.web", "android-offline", content = join(InviteJoinUiState(InviteJoinState.Offline)))

    private companion object {
        /** One frame after composition (fixed, so the spinner frame is the same on every run). */
        const val FRAME_MS = 16L

        /** Long enough for a sheet's or a page's enter transition. */
        const val SHEET_MS = 1_000L
    }
}
