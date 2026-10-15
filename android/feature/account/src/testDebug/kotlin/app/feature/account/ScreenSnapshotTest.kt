package app.feature.account

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.painter.ColorPainter
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.data.error.DataError
import app.data.model.Group
import app.data.model.GroupInvite
import app.data.model.GroupKind
import app.data.model.Post
import app.data.model.ReportTargetKind
import app.designsystem.LocalReduceMotionOverride
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
import app.feature.account.auth.ProfileUiState
import app.feature.account.groups.CoverPhoto
import app.feature.account.groups.FeedItem
import app.feature.account.groups.GroupCreateScreen
import app.feature.account.groups.GroupCreateUiState
import app.feature.account.groups.GroupFeedScreen
import app.feature.account.groups.GroupFeedUiState
import app.feature.account.groups.GroupInviteScreen
import app.feature.account.groups.GroupInviteUiState
import app.feature.account.groups.GroupProfileScreen
import app.feature.account.groups.GroupRow
import app.feature.account.groups.GroupSettingsActions
import app.feature.account.groups.GroupSettingsScreen
import app.feature.account.groups.GroupSettingsUiState
import app.feature.account.groups.GroupsListScreen
import app.feature.account.groups.GroupsListUiState
import app.feature.account.groups.LeaveGroupDialog
import app.feature.account.groups.MemberRow
import app.feature.account.groups.RowSubtitle
import app.feature.account.groups.SettingsSection
import app.feature.account.invite.InviteJoinScreen
import app.feature.account.invite.InviteJoinState
import app.feature.account.onboarding.NotificationsPermissionScreen
import app.feature.account.onboarding.WidgetScreen
import app.feature.account.paywall.PaywallMessage
import app.feature.account.paywall.PaywallScreen
import app.feature.account.paywall.PaywallUiState
import app.feature.account.paywall.PlanOption
import app.feature.account.paywall.PlanPeriod
import app.feature.account.paywall.PlanSheet
import app.feature.account.paywall.PlansStatus
import app.feature.account.paywall.WelcomeSheet
import app.feature.account.platform.DeviceContact
import app.feature.account.platform.LegalLinks
import app.feature.account.safety.BlockConfirmation
import app.feature.account.safety.BlockUiState
import app.feature.account.safety.ReportContent
import app.feature.account.safety.ReportPhase
import app.feature.account.safety.ReportTarget
import app.feature.account.safety.ReportUiState
import app.feature.account.settings.BlockedPerson
import app.feature.account.settings.GroupToggle
import app.feature.account.settings.SettingsAccountScreen
import app.feature.account.settings.SettingsAccountUiState
import app.feature.account.settings.SettingsBlockedScreen
import app.feature.account.settings.SettingsBlockedUiState
import app.feature.account.settings.SettingsNotificationsScreen
import app.feature.account.settings.SettingsNotificationsUiState
import app.feature.account.settings.SettingsRootScreen
import app.feature.account.testing.fakeEnvironment
import app.ui.components.PermissionCard
import app.ui.permissions.PermissionRationale
import app.ui.system.SystemAlertDialog
import app.ui.theme.AppTheme
import com.github.takahirom.roborazzi.captureScreenRoboImage
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId
import java.util.Locale

/**
 * One snapshot per account screen per state (docs/SCREENS_BRIEF.md rule 7), rendered from the
 * screens' stateless composables at 393 × 852 dp (the references' 393-pt width), xhdpi. Baselines:
 * `src/test/snapshots/<surface-id>/<state>.png` (`./gradlew :feature:account:recordRoborazziDebug`).
 * Debug build: BLOCKED copy shows with the literal `{app_name}` placeholder. Names, numbers and
 * times below are test data.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(qualifiers = "w393dp-h852dp-xhdpi")
class ScreenSnapshotTest {
    @get:Rule val compose = createComposeRule()

    private val zone = ZoneId.of("UTC")
    private val now = Instant.parse("2026-10-15T17:00:00Z")
    private val legal = LegalLinks("https://example.test/terms", "https://example.test/privacy", null)
    private val noop: () -> Unit = {}

    private fun snap(surface: String, state: String, content: @Composable () -> Unit) {
        compose.mainClock.autoAdvance = false
        compose.setContent {
            CompositionLocalProvider(LocalAccountEnvironment provides fakeEnvironment(), LocalReduceMotionOverride provides false) {
                AppTheme { content() }
            }
        }
        compose.mainClock.advanceTimeBy(FRAME_MS)
        captureScreenRoboImage("src/test/snapshots/$surface/$state.png")
    }

    // auth.phone ------------------------------------------------------------------------------------
    @Test fun phoneDefault() = snap("auth.phone", "default") { PhoneScreen(PhoneUiState(phone = "+1", prefill = "+1"), {}, noop, noop, noop, noop, focusOnAppear = false) }
    @Test fun phoneFilled() = snap("auth.phone", "filled") { PhoneScreen(PhoneUiState(phone = "+1 415 555 0100", prefill = "+1"), {}, noop, noop, noop, noop, focusOnAppear = false) }
    @Test fun phoneSending() = snap("auth.phone", "sending") { PhoneScreen(PhoneUiState(phone = "+1 415 555 0100", prefill = "+1", sending = true), {}, noop, noop, noop, noop, focusOnAppear = false) }
    @Test fun phoneInvalidNumber() = snap("auth.phone", "invalidNumber-blocked") { PhoneScreen(PhoneUiState(phone = "+1 12", prefill = "+1", error = PhoneError.InvalidNumber), {}, noop, noop, noop, noop, focusOnAppear = false) }
    @Test fun phoneOffline() = snap("auth.phone", "offline") { PhoneScreen(PhoneUiState(offline = true), {}, noop, noop, noop, noop, focusOnAppear = false) }

    // auth.code -------------------------------------------------------------------------------------
    private val code = CodeUiState(phoneDisplay = "+1 415-555-0100")
    @Test fun codeDefault() = snap("auth.code", "default") { CodeScreen(code, {}, noop, noop, noop, noop, focusOnAppear = false) }
    @Test fun codeFilledResendOpen() = snap("auth.code", "filled-resendEnabled") { CodeScreen(code.copy(code = "123456", resendLocked = false), {}, noop, noop, noop, noop, focusOnAppear = false) }
    @Test fun codeVerifying() = snap("auth.code", "verifying") { CodeScreen(code.copy(code = "123456", verifying = true), {}, noop, noop, noop, noop, focusOnAppear = false) }
    @Test fun codeWrong() = snap("auth.code", "wrong-blocked") { CodeScreen(code.copy(error = CodeError.Wrong), {}, noop, noop, noop, noop, focusOnAppear = false) }
    @Test fun codeOffline() = snap("auth.code", "offline") { CodeScreen(code.copy(offline = true), {}, noop, noop, noop, noop, focusOnAppear = false) }

    // auth.agegate ----------------------------------------------------------------------------------
    private val us = DateEntryPattern.of(Locale.US)
    @Test fun ageDefault() = snap("auth.agegate", "default") { AgeGateScreen(AgeGateUiState(), us, false, {}, {}, noop, noop, focusOnAppear = false) }
    @Test fun ageFilledOptIn() = snap("auth.agegate", "filled-optIn") { AgeGateScreen(AgeGateUiState(digits = "03142001", optIn = true), us, true, {}, {}, noop, noop, focusOnAppear = false) }
    @Test fun ageChecking() = snap("auth.agegate", "checking") { AgeGateScreen(AgeGateUiState(digits = "03142001", checking = true), us, false, {}, {}, noop, noop, focusOnAppear = false) }
    @Test fun ageInvalid() = snap("auth.agegate", "invalidDate-blocked") { AgeGateScreen(AgeGateUiState(digits = "02302001", invalidDate = true), us, false, {}, {}, noop, noop, focusOnAppear = false) }
    @Test fun ageNotConfigured() = snap("auth.agegate", "notConfigured") { AgeGateScreen(AgeGateUiState(notConfigured = true), us, false, {}, {}, noop, noop, focusOnAppear = false) }
    @Test fun ageUnderAge() = snap("auth.agegate", "underAge") { AgeGateScreen(AgeGateUiState(refusal = app.feature.account.platform.AgeRefusal(13)), us, false, {}, {}, noop, noop, focusOnAppear = false) }
    @Test fun ageOffline() = snap("auth.agegate", "offline") { AgeGateScreen(AgeGateUiState(offline = true), us, false, {}, {}, noop, noop, focusOnAppear = false) }

    // auth.profile ----------------------------------------------------------------------------------
    @Test fun profileDefault() = snap("auth.profile", "default") { ProfileScreen(ProfileUiState(), {}, noop, noop, noop) }
    @Test fun profileFilled() = snap("auth.profile", "filled-photo") { ProfileScreen(ProfileUiState(name = "Ana Lima"), {}, noop, noop, noop, avatarImage = ColorPainter(Tokens.Colors.globalAccentSecondary)) }
    @Test fun profileSaving() = snap("auth.profile", "saving") { ProfileScreen(ProfileUiState(name = "Ana Lima", saving = true), {}, noop, noop, noop) }
    @Test fun profileUploadFailed() = snap("auth.profile", "uploadFailed-blocked") { ProfileScreen(ProfileUiState(name = "Ana Lima", error = ProfileError.Upload), {}, noop, noop, noop) }
    @Test fun profileOffline() = snap("auth.profile", "offline") { ProfileScreen(ProfileUiState(offline = true), {}, noop, noop, noop) }

    // onboarding ------------------------------------------------------------------------------------
    @Test fun notificationsAndroid13() = snap("onboarding.permission.notifications", "default-android13") { NotificationsPermissionScreen(showSkip = true, onContinue = noop, onSkip = noop) }
    @Test fun widgetDefault() = snap("onboarding.widget", "default") {
        WidgetScreen(listOf("Hold down on an empty\nspace on your Home Screen", "Tap the “Widgets” button\nto add a new widget", "Search for {app_name} and\nadd the widget"), noop)
    }
    @Test fun cameraDenied() = snap("onboarding.permission.camera", "denied") { CardOnBlack { PermissionCard("can’t take pics?", "enable camera", "enable", noop) } }
    @Test fun photosDenied() = snap("onboarding.permission.photos", "denied") { CardOnBlack { PermissionCard("can’t save pics?", "enable photos", "enable", noop, onDismiss = noop, dismissLabel = "dismiss") } }

    @Composable
    private fun CardOnBlack(card: @Composable () -> Unit) {
        Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep).padding(horizontal = Tokens.Sizes.onboardingPermissionContactsSizeCardMarginH), contentAlignment = Alignment.Center) { card() }
    }

    // system.permissions ----------------------------------------------------------------------------
    private val rationale = PermissionRationale("can’t see your friends?", "{app_name} uses the contacts you choose to invite people to your groups.", "Not Now", "Continue", "Open Settings")
    @Test fun rationaleDialog() = snap("system.permissions", "rationale-contacts") {
        Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep))
        SystemAlertDialog(rationale.title, rationale.message, rationale.continueLabel, noop, rationale.notNow, noop)
    }
    @Test fun permanentDenialDialog() = snap("system.permissions", "permanentlyDenied") {
        Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackgroundDeep))
        SystemAlertDialog(rationale.title, rationale.message, rationale.openSettings, noop, rationale.notNow, noop)
    }

    // groups.list -----------------------------------------------------------------------------------
    private val rows = listOf(
        GroupRow("g1", "Sunday dinners", null, RowSubtitle.SentPic("Sam", now.minusSeconds(7200)), now),
        GroupRow("g2", "Roomies", null, RowSubtitle.NewPic(now.minusSeconds(18000)), now.minusSeconds(18000)),
        GroupRow("g3", "Lima family", null, RowSubtitle.NoPics, now.minusSeconds(86400)),
    )
    private fun list(state: GroupsListUiState) = @Composable { GroupsListScreen(state, zone, noop, {}, {}, noop, {}) }
    @Test fun listLoading() = snap("groups.list", "loading", list(GroupsListUiState()))
    @Test fun listRows() = snap("groups.list", "default", list(GroupsListUiState(rows = rows, cover = CoverPhoto("g1", "p1", null, "Sam", "Sunday dinners"), refreshing = false)))
    @Test fun listRowsNoPhotos() = snap("groups.list", "default-noCoverPhoto", list(GroupsListUiState(rows = rows.drop(2), refreshing = false)))
    @Test fun listEmpty() = snap("groups.list", "empty", list(GroupsListUiState(rows = emptyList(), refreshing = false)))
    @Test fun listError() = snap("groups.list", "error", list(GroupsListUiState(refreshing = false, error = DataError.Unexpected("x"))))
    @Test fun listOffline() = snap("groups.list", "offline", list(GroupsListUiState(refreshing = false, error = DataError.Network)))
    @Test fun listOfflineCached() = snap("groups.list", "offline-cached", list(GroupsListUiState(rows = rows, refreshing = false, error = DataError.Network)))

    // groups.create ---------------------------------------------------------------------------------
    @Test fun createDefault() = snap("groups.create", "default") { GroupCreateScreen(GroupCreateUiState(), noop, {}, {}, noop, noop) }
    @Test fun createFilled() = snap("groups.create", "filled") { GroupCreateScreen(GroupCreateUiState(name = "Book club", kind = GroupKind.Family), noop, {}, {}, noop, noop, coverImage = ColorPainter(Tokens.Colors.globalAccentSecondary)) }
    @Test fun createCreating() = snap("groups.create", "creating") { GroupCreateScreen(GroupCreateUiState(name = "Book club", working = true), noop, {}, {}, noop, noop) }
    @Test fun createEdit() = snap("groups.create", "edit") { GroupCreateScreen(GroupCreateUiState(editGroupId = "g1", name = "Sunday dinners", kind = GroupKind.Custom), noop, {}, {}, noop, noop) }

    // groups.invite ---------------------------------------------------------------------------------
    private val invite = GroupInviteUiState(groupName = "Sunday dinners", maxMembers = 30)
    private val liveInvite = GroupInvite("i1", "g1", "AbCdEfGhIjKlMnOpQrStUvWx", "u-me", now, now.plusSeconds(14 * 86400L), null)
    private fun inviteScreen(state: GroupInviteUiState) = @Composable { GroupInviteScreen(state, zone, noop, noop, noop, noop, noop, noop, noop, noop, {}) }
    @Test fun inviteDefault() = snap("groups.invite", "default-contactsCard", inviteScreen(invite))
    @Test fun inviteReady() = snap("groups.invite", "linkReady", inviteScreen(invite.copy(invite = liveInvite, canTurnOff = true, cardDismissed = true)))
    @Test fun inviteContacts() = snap("groups.invite", "contacts", inviteScreen(invite.copy(contactsGranted = true, contacts = listOf(DeviceContact("1", "Ana Lima", "+1", null), DeviceContact("2", "Rui Costa", "+2", null)), invited = setOf("2"))))
    @Test fun inviteLoading() = snap("groups.invite", "loading", inviteScreen(invite.copy(loading = true)))
    @Test fun inviteFull() = snap("groups.invite", "full", inviteScreen(invite.copy(full = true)))
    @Test fun inviteError() = snap("groups.invite", "error", inviteScreen(invite.copy(error = true)))
    @Test fun inviteTurnOff() = snap("groups.invite", "turnOffAlert", inviteScreen(invite.copy(invite = liveInvite, canTurnOff = true, confirmTurnOff = true)))
    @Test fun inviteFamily() = snap("groups.invite", "default-family", inviteScreen(invite.copy(kind = GroupKind.Family, cardDismissed = true)))

    // groups.screen ---------------------------------------------------------------------------------
    private val group = Group("g1", "Sunday dinners", GroupKind.Friends, null, "UTC", null, null, false, "u-me", now, now)
    private fun photo(id: String, author: String, mine: Boolean, at: Instant, caption: String? = null) =
        FeedItem.Photo(Post(id, "m$id", "g1", if (mine) "u-me" else "u-x", caption, null, null, null, false, null, at), null, author, null, mine)
    private val feedItems = listOf(
        photo("p1", "Sam", false, now.minusSeconds(3600), "dinner"),
        FeedItem.Joined("u-sam", "Sam", null, now.minusSeconds(7200)),
        photo("p2", "Ana", true, now.minusSeconds(10800)),
    )
    private fun feed(state: GroupFeedUiState) = @Composable { GroupFeedScreen(state, zone, noop, noop, noop, noop, {}, {}, {}, noop, noop, noop, noop, noop) }
    @Test fun feedLoading() = snap("groups.screen", "loading", feed(GroupFeedUiState(group = group)))
    @Test fun feedDefault() = snap("groups.screen", "default", feed(GroupFeedUiState(group = group, items = feedItems, isCreator = true)))
    @Test fun feedCreated() = snap("groups.screen", "created", feed(GroupFeedUiState(group = group, items = emptyList(), isCreator = true)))
    @Test fun feedCreatedNames() = snap("groups.screen", "created-joined", feed(GroupFeedUiState(group = group, items = emptyList(), isCreator = true, otherNames = listOf("Sam", "Rui"))))
    @Test fun feedEmpty() = snap("groups.screen", "empty", feed(GroupFeedUiState(group = group, items = emptyList(), isCreator = false)))
    @Test fun feedError() = snap("groups.screen", "error", feed(GroupFeedUiState(group = group, error = DataError.Unexpected("x"))))
    @Test fun feedOffline() = snap("groups.screen", "offline", feed(GroupFeedUiState(group = group, error = DataError.Network)))
    @Test fun feedRemoved() = snap("groups.screen", "removed", feed(GroupFeedUiState(group = group, removed = true)))
    @Test fun profilePage() = snap("groups.screen", "profile") {
        GroupProfileScreen(GroupFeedUiState(group = group, items = feedItems, memberAvatars = listOf(null, null, null)), noop, noop, {}, noop, noop, noop, noop, noop, noop)
    }

    // groups.settings -------------------------------------------------------------------------------
    private val members = listOf(
        MemberRow("u-me", "Ana Lima", "Ana", null, admin = true, you = true),
        MemberRow("u-sam", "Sam Lee", "Sam", null, admin = false, you = false),
        MemberRow("u-rui", "Rui Costa", "Rui", null, admin = true, you = false),
    )
    private val settings = GroupSettingsUiState(group = group.copy(wakingStart = LocalTime.of(9, 0), wakingEnd = LocalTime.of(21, 0)), members = members, isAdmin = true)
    @Test fun groupSettingsLoading() = snap("groups.settings", "loading") { GroupSettingsScreen(GroupSettingsUiState(), false, GroupSettingsActions()) }
    @Test fun groupSettingsAdmin() = snap("groups.settings", "default-admin") { GroupSettingsScreen(settings, false, GroupSettingsActions()) }
    @Test fun groupSettingsMember() = snap("groups.settings", "nonAdmin") { GroupSettingsScreen(settings.copy(isAdmin = false, group = group, muted = true), false, GroupSettingsActions()) }
    @Test fun groupSettingsError() = snap("groups.settings", "error-save") { GroupSettingsScreen(settings.copy(errorIn = SettingsSection.Notifications), false, GroupSettingsActions()) }
    @Test fun groupSettingsInvalid() = snap("groups.settings", "invalidWindow") { GroupSettingsScreen(settings.copy(invalidWindow = true), false, GroupSettingsActions()) }
    @Test fun groupSettingsOffline() = snap("groups.settings", "offline") { GroupSettingsScreen(settings.copy(online = false), false, GroupSettingsActions()) }
    @Test fun groupSettingsNotificationsOff() = snap("groups.settings", "permissionDenied") { GroupSettingsScreen(settings, true, GroupSettingsActions()) }
    @Test fun groupSettingsLeave() = snap("groups.settings", "leaveAlert") {
        GroupSettingsScreen(settings, false, GroupSettingsActions())
        LeaveGroupDialog("Sunday dinners", last = false, onConfirm = noop, onDismiss = noop)
    }

    // settings.* ------------------------------------------------------------------------------------
    private fun root(premium: Boolean) = @Composable { SettingsRootScreen(premium, legal, noop, noop, noop, noop, noop, noop, {}, {}, noop) }
    @Test fun settingsRoot() = snap("settings.root", "default", root(false))
    @Test fun settingsRootPremium() = snap("settings.root", "premiumActive", root(true))

    private val notif = SettingsNotificationsUiState(groups = listOf(GroupToggle("g1", "Sunday dinners", false), GroupToggle("g2", "Roomies", true)), quietStart = LocalTime.of(22, 0), quietEnd = LocalTime.of(7, 0), quietOn = true, loaded = true)
    private fun notifications(state: SettingsNotificationsUiState, off: Boolean = false) = @Composable { SettingsNotificationsScreen(state, off, noop, noop, { _, _ -> }, {}, {}, {}, noop) }
    @Test fun notificationsLoading() = snap("settings.notifications", "loading", notifications(SettingsNotificationsUiState()))
    @Test fun notificationsDefault() = snap("settings.notifications", "default", notifications(notif))
    @Test fun notificationsSystemOff() = snap("settings.notifications", "permissionDenied", notifications(notif.copy(quietOn = false), off = true))
    @Test fun notificationsError() = snap("settings.notifications", "error", notifications(notif.copy(error = true)))
    @Test fun notificationsOffline() = snap("settings.notifications", "offline", notifications(notif.copy(online = false)))

    private val account = SettingsAccountUiState(name = "Ana Lima", phone = "+14155550100")
    private fun accountScreen(state: SettingsAccountUiState) = @Composable { SettingsAccountScreen(state, noop, {}, noop, noop, noop, noop, noop, noop) }
    @Test fun accountDefault() = snap("settings.account", "default", accountScreen(account))
    @Test fun accountPremium() = snap("settings.account", "premiumActive", accountScreen(account.copy(premium = true)))
    @Test fun accountConfirm() = snap("settings.account", "deleteConfirm", accountScreen(account.copy(confirmDelete = true)))
    @Test fun accountConfirmPremium() = snap("settings.account", "deleteConfirm-premium", accountScreen(account.copy(confirmDelete = true, premium = true)))
    @Test fun accountDeleting() = snap("settings.account", "deleting", accountScreen(account.copy(deleting = true)))
    @Test fun accountDeleteError() = snap("settings.account", "deleteError", accountScreen(account.copy(deleteError = true)))
    @Test fun accountNameError() = snap("settings.account", "nameError", accountScreen(account.copy(nameError = true)))
    @Test fun accountOffline() = snap("settings.account", "offline", accountScreen(account.copy(online = false)))

    private fun blocked(state: SettingsBlockedUiState) = @Composable { SettingsBlockedScreen(state, noop, {}, noop) }
    @Test fun blockedLoading() = snap("settings.blocked", "loading", blocked(SettingsBlockedUiState()))
    @Test fun blockedList() = snap("settings.blocked", "default", blocked(SettingsBlockedUiState(people = listOf(BlockedPerson("u1", "Sam Lee", null), BlockedPerson("u2", null, null)))))
    @Test fun blockedEmpty() = snap("settings.blocked", "empty", blocked(SettingsBlockedUiState(people = emptyList())))
    @Test fun blockedError() = snap("settings.blocked", "error", blocked(SettingsBlockedUiState(error = true)))

    // safety ----------------------------------------------------------------------------------------
    private val postTarget = ReportTarget(ReportTargetKind.Post, "p1", "g1", "u-sam")
    @Composable
    private fun Sheet(content: @Composable () -> Unit) {
        Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackground), contentAlignment = Alignment.BottomCenter) {
            val corner = Tokens.Layouts.GlobalSheet.android.dp
            Box(Modifier.background(Tokens.Colors.globalSystemSurfaceContainerLow, RoundedCornerShape(topStart = corner, topEnd = corner)).padding(top = corner)) { content() }
        }
    }
    private fun report(state: ReportUiState) = @Composable { Sheet { ReportContent(state, {}, noop, noop, noop, {}) } }
    @Test fun reportPost() = snap("safety.report", "default-post", report(ReportUiState(postTarget, firstName = "Sam")))
    @Test fun reportUser() = snap("safety.report", "default-user", report(ReportUiState(ReportTarget(ReportTargetKind.User, "u-sam", "g1", "u-sam"), details = "they keep posting my photos", firstName = "Sam")))
    @Test fun reportGroup() = snap("safety.report", "default-group", report(ReportUiState(ReportTarget(ReportTargetKind.Group, "g1", "g1", null), groupName = "Sunday dinners")))
    @Test fun reportSending() = snap("safety.report", "sending", report(ReportUiState(postTarget, phase = ReportPhase.Sending, firstName = "Sam")))
    @Test fun reportSent() = snap("safety.report", "sent", report(ReportUiState(postTarget, phase = ReportPhase.Sent, firstName = "Sam")))
    @Test fun reportSentGroup() = snap("safety.report", "sent-group", report(ReportUiState(ReportTarget(ReportTargetKind.Group, "g1", "g1", null), phase = ReportPhase.Sent)))
    @Test fun reportError() = snap("safety.report", "error", report(ReportUiState(postTarget, details = "kept", phase = ReportPhase.Error, firstName = "Sam")))
    @Test fun reportGone() = snap("safety.report", "targetGone", report(ReportUiState(postTarget, phase = ReportPhase.NotFound)))

    private fun block(state: BlockUiState) = @Composable {
        Box(Modifier.fillMaxSize().background(Tokens.Colors.globalBackground))
        BlockConfirmation(state, noop, noop)
    }
    @Test fun blockConfirm() = snap("safety.block", "confirm", block(BlockUiState("Sam")))
    @Test fun blockBlocking() = snap("safety.block", "blocking", block(BlockUiState("Sam", blocking = true)))
    @Test fun blockError() = snap("safety.block", "error", block(BlockUiState("Sam", error = true)))

    // paywall ---------------------------------------------------------------------------------------
    private val plans = listOf(PlanOption(PlanPeriod.Yearly, "$35.99", null), PlanOption(PlanPeriod.Monthly, "$3.99", null))
    private fun paywall(state: PaywallUiState) = @Composable { PaywallScreen(state, legal, noop, noop, noop, {}, noop, noop, noop, {}, noop) }
    @Test fun paywallLoading() = snap("paywall", "loading", paywall(PaywallUiState()))
    @Test fun paywallReady() = snap("paywall", "default", paywall(PaywallUiState(plans = plans, status = PlansStatus.Ready)))
    @Test fun paywallHistory() = snap("paywall", "default-historyLimited", paywall(PaywallUiState(plans = plans, status = PlansStatus.Ready, historyLimited = true)))
    @Test fun paywallUnavailable() = snap("paywall", "productsUnavailable", paywall(PaywallUiState(status = PlansStatus.Unavailable)))
    @Test fun paywallOffline() = snap("paywall", "offline", paywall(PaywallUiState(status = PlansStatus.Offline)))
    @Test fun paywallRestored() = snap("paywall", "restoreNone", paywall(PaywallUiState(plans = plans, status = PlansStatus.Ready, message = PaywallMessage.NothingToRestore)))
    private fun planSheet(state: PaywallUiState) = @Composable { Box(Modifier.fillMaxSize().background(Tokens.Colors.paywallColorBackgroundTop), contentAlignment = Alignment.BottomCenter) { PlanSheet(state, {}, noop, noop) } }
    @Test fun planSheetYearly() = snap("paywall", "planSheet-yearly", planSheet(PaywallUiState(plans = plans, status = PlansStatus.Ready)))
    @Test fun planSheetMonthly() = snap("paywall", "planSheet-monthly", planSheet(PaywallUiState(plans = plans, status = PlansStatus.Ready, selected = PlanPeriod.Monthly)))
    @Test fun planSheetPurchasing() = snap("paywall", "planSheet-purchasing", planSheet(PaywallUiState(plans = plans, status = PlansStatus.Ready, purchasing = true)))
    @Test fun planSheetFailed() = snap("paywall", "planSheet-purchaseFailed", planSheet(PaywallUiState(plans = plans, status = PlansStatus.Ready, message = PaywallMessage.PurchaseFailed)))
    @Test fun planSheetPending() = snap("paywall", "planSheet-pending", planSheet(PaywallUiState(plans = plans, status = PlansStatus.Ready, message = PaywallMessage.Pending)))
    @Test fun welcome() = snap("paywall", "welcome") { Box(Modifier.fillMaxSize().background(Tokens.Colors.paywallColorBackgroundTop), contentAlignment = Alignment.BottomCenter) { WelcomeSheet(noop) } }

    // invite.web (Android join path) ----------------------------------------------------------------
    @Test fun inviteJoinLoading() = snap("invite.web", "android-loading") { InviteJoinScreen(InviteJoinState.Loading, noop) }
    @Test fun inviteJoinUnavailable() = snap("invite.web", "android-unavailable") { InviteJoinScreen(InviteJoinState.Unavailable, noop) }
    @Test fun inviteJoinNotFound() = snap("invite.web", "android-notFound") { InviteJoinScreen(InviteJoinState.NotFound, noop) }
    @Test fun inviteJoinFull() = snap("invite.web", "android-full") { InviteJoinScreen(InviteJoinState.Full, noop) }
    @Test fun inviteJoinError() = snap("invite.web", "android-error") { InviteJoinScreen(InviteJoinState.Error, noop) }
    @Test fun inviteJoinOffline() = snap("invite.web", "android-offline") { InviteJoinScreen(InviteJoinState.Offline, noop) }

    private companion object {
        /** One frame after composition (fixed, so the spinner frame is the same on every run). */
        const val FRAME_MS = 16L
    }
}
