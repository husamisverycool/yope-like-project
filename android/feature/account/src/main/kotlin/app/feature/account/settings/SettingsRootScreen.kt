// Surface: settings.root — Settings. Spec: design/surfaces/settings.root.md.
// References: references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png (VID-SET frames 42–44: centred "Settings" +
// close circle, profile card in a Fill group, small grey section headers, grouped Fill rows with grey subtitles and chevrons),
// references/auto/retro/press/tc-2024-04-retro-journals-5.png (TC-J5: row height 58.7), references/auto/retro/store/retro-store-02.png
// (ST-02: name, grey line, 64 avatar right), references/auto/retro/apk/retro-android-2026.10.1150-strings.txt (APK-S: settings_*).
package app.feature.account.settings

import android.Manifest
import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.core.app.NotificationManagerCompat
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.common.SheetPage
import app.feature.account.common.sheetBottomPadding
import app.feature.account.auth.PhoneNumbers
import app.feature.account.paywall.PlanPeriod
import app.feature.account.platform.ExternalActions
import app.feature.account.platform.LegalLinks
import app.model.AppRoute
import app.model.OnboardingWidgetFromSettingsRoute
import app.ui.components.Avatar
import app.ui.components.GroupedPosition
import app.ui.components.GroupedRowSpec
import app.ui.components.GroupedTrailing
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.permissions.PermissionChecks
import app.ui.system.SystemAlertDialog
import app.ui.text.TextRoles
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** The subscription row's state (`entitlements` / the store; unknown until they answer). */
enum class SubscriptionState { Loading, None, Annual, Monthly, Active }

/** A system permission row (`settings.root.permissions.*`): [denied] shows the "Denied" value. */
@Immutable
data class PermissionRow(val titleRes: Int, val denied: Boolean)

@Immutable
data class SettingsRootUiState(
    val name: String = "",
    val phone: String? = null,
    val avatar: Any? = null,
    val subscription: SubscriptionState = SubscriptionState.Loading,
    val signingOut: Boolean = false,
    /** Settings → Appearance → True Black (Android only, owner decision 21). */
    val trueBlack: Boolean = false,
)

class SettingsRootViewModel(private val env: AccountEnvironment) : AccountViewModel() {
    private val mutable = MutableStateFlow(SettingsRootUiState(phone = env.backend.currentPhone()?.let(PhoneNumbers::display)))
    val state: StateFlow<SettingsRootUiState> = mutable.asStateFlow()

    init {
        viewModelScope.launch {
            val me = runCatching { env.backend.me() }.getOrNull() ?: return@launch
            val url = me.avatarPath?.let { path -> runCatching { env.backend.signedUrls(listOf(path))[path] }.getOrNull() }
            mutable.update { it.copy(name = me.displayName, avatar = url) }
        }
        viewModelScope.launch {
            kotlinx.coroutines.flow.combine(env.premium.isActive, env.premium.activePlan) { active, plan ->
                when {
                    !active -> SubscriptionState.None
                    plan == PlanPeriod.Yearly -> SubscriptionState.Annual
                    plan == PlanPeriod.Monthly -> SubscriptionState.Monthly
                    else -> SubscriptionState.Active
                }
            }.collect { sub -> mutable.update { it.copy(subscription = sub) } }
        }
        viewModelScope.launch {
            env.appearance.trueBlack.collect { on -> mutable.update { it.copy(trueBlack = on) } }
        }
    }

    /** True Black on / off: kept on this device; the app theme follows at once (the dark appearance only). */
    fun setTrueBlack(on: Boolean) = env.appearance.setTrueBlack(on)

    /** Sign out: `unregister_device` (session glue hook) then `auth.signOut()` → auth.phone. Local state clears even offline. */
    fun signOut() {
        mutable.update { it.copy(signingOut = true) }
        viewModelScope.launch {
            runCatching { env.backend.signOut() }
            mutable.update { it.copy(signingOut = false) }
            navigate(AppRoute.AuthPhone, clearStack = true)
        }
    }
}

/** The Play Subscription Center link (`settings.account.layout.manageSubscription` android). */
object ManageSubscription {
    fun url(packageName: String, productId: String?): String {
        val template = Tokens.Layouts.SettingsAccountLayoutManageSubscription.android
        val raw = template.substring(template.indexOf("https://")).substringBefore(' ')
        val withPackage = raw.replace("{applicationId}", packageName)
        return if (productId != null) withPackage.replace("{productId}", productId) else withPackage.replace("sku={productId}&", "")
    }

    fun open(context: Context, productId: String? = null) = ExternalActions.view(context, url(context.packageName, productId))
}

/** System permission rows on Android (`settings.root.permissions.*`; Camera Roll is iOS only — pickers need no permission here). */
private fun permissionRows(context: Context): List<PermissionRow> {
    fun denied(permission: String) = PermissionChecks.wasAsked(context, permission) && !PermissionChecks.isGranted(context, permission)
    return listOf(
        PermissionRow(R.string.settings_root_permissions_camera, denied(Manifest.permission.CAMERA)),
        PermissionRow(R.string.settings_root_permissions_microphone, denied(Manifest.permission.RECORD_AUDIO)),
        PermissionRow(R.string.settings_root_permissions_contacts, denied(Manifest.permission.READ_CONTACTS)),
        PermissionRow(R.string.settings_root_permissions_notifications, !NotificationManagerCompat.from(context).areNotificationsEnabled()),
    )
}

@Composable
fun SettingsRootRoute(nav: NavController) {
    val env = LocalAccountEnvironment.current
    val context = LocalContext.current
    val vm = viewModel { SettingsRootViewModel(env) }
    val state by vm.state.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    var permissions by remember { mutableStateOf(permissionRows(context)) }
    // Back from system Settings: the "Denied" values follow.
    LifecycleResumeEffect(Unit) {
        permissions = permissionRows(context)
        onPauseOrDispose { }
    }
    val version = remember { runCatching { context.packageManager.getPackageInfo(context.packageName, 0).versionName }.getOrNull() }
    SettingsRootScreen(
        state = state,
        legal = env.legal,
        permissions = permissions,
        version = version,
        actions = SettingsRootActions(
            onClose = { nav.popBackStack() },
            onAccount = { nav.navigate(AppRoute.SettingsAccount) },
            onPremium = { nav.navigate(AppRoute.Paywall) },
            onManage = { ManageSubscription.open(context) },
            onNotifications = { nav.navigate(AppRoute.SettingsNotifications) },
            onWidgets = { nav.navigate(OnboardingWidgetFromSettingsRoute) },
            onBlocked = { nav.navigate(AppRoute.SettingsBlocked) },
            onHidden = { nav.navigate(AppRoute.SettingsHidden) },
            onPermission = { PermissionChecks.openSafely(context, PermissionChecks.appSettingsIntent(context)) },
            onUrl = { ExternalActions.openInAppBrowser(context, it) },
            onMail = { ExternalActions.mail(context, it) },
            onSignOut = vm::signOut,
            onTrueBlack = vm::setTrueBlack,
        ),
    )
}

/** What the Settings sheet does on each row. */
@Immutable
data class SettingsRootActions(
    val onClose: () -> Unit = {},
    val onAccount: () -> Unit = {},
    val onPremium: () -> Unit = {},
    val onManage: () -> Unit = {},
    val onNotifications: () -> Unit = {},
    val onWidgets: () -> Unit = {},
    val onBlocked: () -> Unit = {},
    /** Privacy → Hidden Memories (settings.hidden). */
    val onHidden: () -> Unit = {},
    val onPermission: () -> Unit = {},
    val onUrl: (String) -> Unit = {},
    val onMail: (String) -> Unit = {},
    val onSignOut: () -> Unit = {},
    val onTrueBlack: (Boolean) -> Unit = {},
)

/**
 * The Settings sheet (C-29 page sheet: centred "Settings" + close; `settings.root.layout.list`): the profile card (one C-14
 * row: name `listTitle`, phone `listSubtitle` secondary, the 64 avatar at the trailing edge — C-19 content) → settings.account;
 * Subscription (Premium → paywall; subscribers "Your Subscription" with Annual / Monthly → the Play subscription page; the
 * platform indicator while the store answers); Notifications; Widgets ("Add Widget" → onboarding.widget); Appearance
 * (Android only: the "True Black" switch row, owner decision 21 — Retro's true-black dark scheme); Privacy
 * (Blocked People, Hidden Memories); System Permissions (Camera, Microphone, Contacts, Push Notifications — "Denied" when denied → the
 * app's page in system Settings); About (Contact Us, Privacy Policy, Terms of Use — each omitted while its
 * `config/app.json` value is BLOCKED — and Version); Sign Out (confirmed; the row shows the indicator while it runs).
 */
@Composable
fun SettingsRootScreen(
    state: SettingsRootUiState,
    legal: LegalLinks,
    permissions: List<PermissionRow>,
    version: String?,
    actions: SettingsRootActions,
) {
    val context = LocalContext.current
    var confirmSignOut by remember { mutableStateOf(false) }
    SheetPage(
        title = stringResource(R.string.settings_root_title),
        close = app.ui.components.HeaderAction(Tokens.Icons.globalClose, stringResource(R.string.settings_root_close_accessibilitylabel), actions.onClose),
    ) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(bottom = sheetBottomPadding())) {
            ProfileCard(state, actions.onAccount)
            // Subscription
            val premiumTitle = context.getString(R.string.settings_root_premium_title)
            val subscriptionRow: GroupedRowSpec? = when (state.subscription) {
                SubscriptionState.Loading -> null
                SubscriptionState.None -> navRow(premiumTitle, stringResource(R.string.settings_root_premium_subtitle), onClick = actions.onPremium)
                SubscriptionState.Annual -> navRow(stringResource(R.string.settings_root_managesubscription), stringResource(R.string.settings_root_premium_annual), onClick = actions.onManage)
                SubscriptionState.Monthly -> navRow(stringResource(R.string.settings_root_managesubscription), stringResource(R.string.settings_root_premium_monthly), onClick = actions.onManage)
                SubscriptionState.Active -> navRow(stringResource(R.string.settings_root_managesubscription), onClick = actions.onManage)
            }
            if (state.subscription == SubscriptionState.Loading) {
                SettingsHeader(stringResource(R.string.settings_root_subscription_header))
                LoadingGroup()
            } else if (subscriptionRow != null) {
                SettingsHeader(stringResource(R.string.settings_root_subscription_header))
                SettingsGroup(listOf(subscriptionRow))
            }
            // Notifications
            SettingsHeader(stringResource(R.string.settings_root_notifications_header))
            SettingsGroup(listOf(navRow(stringResource(R.string.settings_root_notifications), onClick = actions.onNotifications)))
            // Widgets
            SettingsHeader(stringResource(R.string.settings_root_widgets_header))
            SettingsGroup(listOf(navRow(stringResource(R.string.settings_root_widgets_add), stringResource(R.string.settings_root_widgets_detail), onClick = actions.onWidgets)))
            // Appearance (Android only): one C-14 row with the native switch; the dark appearance only.
            SettingsHeader(stringResource(R.string.settings_root_appearance_header))
            SettingsGroup(
                listOf(
                    GroupedRowSpec(
                        title = stringResource(R.string.settings_root_trueblack),
                        subtitle = stringResource(R.string.settings_root_trueblack_detail),
                        trailing = GroupedTrailing.Toggle(state.trueBlack, actions.onTrueBlack),
                    ),
                ),
            )
            // Privacy
            SettingsHeader(stringResource(R.string.settings_root_privacy_header))
            SettingsGroup(
                listOf(
                    navRow(stringResource(R.string.settings_root_blocked), onClick = actions.onBlocked),
                    navRow(stringResource(R.string.settings_root_hiddenmemories), onClick = actions.onHidden),
                ),
            )
            // System Permissions
            SettingsHeader(stringResource(R.string.settings_root_permissions_header))
            val denied = stringResource(R.string.settings_root_permissions_denied)
            SettingsGroup(
                permissions.map { row ->
                    GroupedRowSpec(
                        title = stringResource(row.titleRes),
                        trailing = if (row.denied) GroupedTrailing.ValueChevron(denied) else GroupedTrailing.Chevron,
                        onClick = actions.onPermission,
                    )
                },
            )
            // About
            SettingsHeader(stringResource(R.string.settings_root_about_header))
            SettingsGroup(
                listOfNotNull(
                    legal.supportEmail?.let { mail -> navRow(stringResource(R.string.settings_root_contact)) { actions.onMail(mail) } },
                    legal.privacyUrl?.let { url -> navRow(stringResource(R.string.settings_root_privacy)) { actions.onUrl(url) } },
                    legal.termsUrl?.let { url -> navRow(stringResource(R.string.settings_root_terms)) { actions.onUrl(url) } },
                    GroupedRowSpec(stringResource(R.string.settings_root_version), trailing = version?.let { GroupedTrailing.Value(it) } ?: GroupedTrailing.None),
                ),
            )
            // Sign Out
            SettingsGap()
            if (state.signingOut) {
                LoadingGroup()
            } else {
                SettingsGroup(listOf(GroupedRowSpec(stringResource(R.string.settings_root_signout), trailing = GroupedTrailing.None, onClick = { confirmSignOut = true })))
            }
        }
    }
    if (confirmSignOut) {
        SystemAlertDialog(
            title = stringResource(R.string.settings_root_signout_title),
            text = null,
            confirmLabel = stringResource(R.string.settings_root_signout_confirm),
            onConfirm = { confirmSignOut = false; actions.onSignOut() },
            dismissLabel = stringResource(R.string.settings_root_alert_cancel),
            onDismiss = { confirmSignOut = false },
        )
    }
}

/**
 * The profile card: one C-14 row (fill `color.global.surfaceSecondary.android`, `radius.global.groupedRow`, padding 16) with
 * the C-19 content — the display name (`listTitle`), the phone number under it (`listSubtitle`, secondary) and the avatar
 * `size.global.avatarProfile` at the trailing edge (C-23 fallback). One button labelled "Edit Profile".
 */
@Composable
private fun ProfileCard(state: SettingsRootUiState, onClick: () -> Unit) {
    val shape = GroupedPosition.Single.shape()
    val label = stringResource(R.string.settings_root_account)
    Row(
        Modifier
            .padding(horizontal = Tokens.Sizes.globalScreenMargin)
            .fillMaxWidth()
            .heightIn(min = Tokens.Sizes.settingsRootSizeRowHeight)
            .clip(shape)
            .background(PageRoles.secondarySurface, shape)
            .tapClickable(onClickLabel = label, onClick = onClick)
            .semantics(mergeDescendants = true) { contentDescription = label }
            .padding(Tokens.Sizes.globalScreenMargin),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(state.name, style = TextRoles.listTitle, color = Tokens.Colors.globalTextPrimary)
            state.phone?.let { Text(it, style = TextRoles.listSubtitle, color = PageRoles.secondaryText()) }
        }
        Spacer(Modifier.width(Tokens.Sizes.globalScreenMargin))
        Avatar(state.avatar, Tokens.Sizes.globalAvatarProfile)
    }
}
