// Surface: settings.root — Settings. Spec: design/surfaces/settings.root.md.
// References: https://developer.apple.com/design/human-interface-guidelines/lists-and-tables (HIG-L),
// https://developer.apple.com/design/human-interface-guidelines/settings (HIG-S), https://m3.material.io/components/lists/specs (M3-L),
// references/auto/locket/lazyweb/locket-lazyweb-20260803-autocap-21.png (LZ21, premium row).
package app.feature.account.settings

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironment
import app.feature.account.LocalAccountEnvironment
import app.feature.account.blocked.BlockedCopy
import app.feature.account.common.AccountViewModel
import app.feature.account.common.CollectEvents
import app.feature.account.platform.ExternalActions
import app.feature.account.platform.LegalLinks
import app.model.AppRoute
import app.ui.system.SystemDivider
import app.ui.system.SystemList
import app.ui.system.SystemRow
import app.ui.system.SystemScaffold
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class SettingsRootViewModel(private val env: AccountEnvironment) : AccountViewModel() {
    /** Premium active? (`entitlements`; shown as the not-subscribed row until known). */
    val premium: StateFlow<Boolean> = env.premium.isActive.stateIn(viewModelScope, SharingStarted.Eagerly, false)

    /** Sign out: `unregister_device` (session glue hook) then `auth.signOut()` → auth.phone. Local state clears even offline. */
    fun signOut() {
        viewModelScope.launch {
            runCatching { env.backend.signOut() }
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

@Composable
fun SettingsRootRoute(nav: NavController) {
    val env = LocalAccountEnvironment.current
    val context = LocalContext.current
    val vm = viewModel { SettingsRootViewModel(env) }
    val premium by vm.premium.collectAsStateWithLifecycle()
    CollectEvents(vm.events, nav)
    SettingsRootScreen(
        premium = premium,
        legal = env.legal,
        onBack = { nav.popBackStack() },
        onPremium = { nav.navigate(AppRoute.Paywall) },
        onManage = { ManageSubscription.open(context) },
        onNotifications = { nav.navigate(AppRoute.SettingsNotifications) },
        onAccount = { nav.navigate(AppRoute.SettingsAccount) },
        onBlocked = { nav.navigate(AppRoute.SettingsBlocked) },
        onUrl = { ExternalActions.openInAppBrowser(context, it) },
        onMail = { ExternalActions.mail(context, it) },
        onSignOut = vm::signOut,
    )
}

/**
 * `settings.root.layout.list` (android: Scaffold + LargeTopAppBar + LazyColumn of ListItem).
 * Section 1: the premium row (title / subtitle BLOCKED while they contain `{app_name}`: the row is
 * omitted in release) or, while premium is active, Manage Subscription. Section 2: Notifications,
 * Account, Blocked People. Section 3: Privacy Policy, Terms of Use, Contact Us (each omitted while its
 * `config/app.json` value is BLOCKED). Section 4: Sign Out.
 */
@Composable
fun SettingsRootScreen(
    premium: Boolean,
    legal: LegalLinks,
    onBack: () -> Unit,
    onPremium: () -> Unit,
    onManage: () -> Unit,
    onNotifications: () -> Unit,
    onAccount: () -> Unit,
    onBlocked: () -> Unit,
    onUrl: (String) -> Unit,
    onMail: (String) -> Unit,
    onSignOut: () -> Unit,
) {
    val context = LocalContext.current
    SystemScaffold(
        title = stringResource(R.string.settings_root_title),
        backLabel = stringResource(R.string.groups_screen_back_accessibilitylabel),
        onBack = onBack,
        large = true,
    ) { padding ->
        SystemList(padding) {
            if (premium) {
                item(key = "manage") { SystemRow(stringResource(R.string.settings_root_managesubscription), onClick = onManage) }
                item(key = "d0") { SystemDivider() }
            } else {
                val title = BlockedCopy.premiumRowTitle(context)
                if (title != null) {
                    item(key = "premium") { SystemRow(title, supporting = BlockedCopy.premiumRowSubtitle(context), onClick = onPremium) }
                    item(key = "d0") { SystemDivider() }
                }
            }
            item(key = "notifications") { SystemRow(stringResource(R.string.settings_root_notifications), onClick = onNotifications) }
            item(key = "account") { SystemRow(stringResource(R.string.settings_root_account), onClick = onAccount) }
            item(key = "blocked") { SystemRow(stringResource(R.string.settings_root_blocked), onClick = onBlocked) }
            item(key = "d1") { SystemDivider() }
            legal.privacyUrl?.let { url -> item(key = "privacy") { SystemRow(stringResource(R.string.settings_root_privacy), onClick = { onUrl(url) }) } }
            legal.termsUrl?.let { url -> item(key = "terms") { SystemRow(stringResource(R.string.settings_root_terms), onClick = { onUrl(url) }) } }
            legal.supportEmail?.let { mail -> item(key = "contact") { SystemRow(stringResource(R.string.settings_root_contact), onClick = { onMail(mail) }) } }
            if (legal.privacyUrl != null || legal.termsUrl != null || legal.supportEmail != null) item(key = "d2") { SystemDivider() }
            item(key = "signOut") { SystemRow(stringResource(R.string.settings_root_signout), onClick = onSignOut) }
        }
    }
}
