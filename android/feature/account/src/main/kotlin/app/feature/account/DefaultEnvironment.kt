package app.feature.account

import android.content.Context
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat
import app.data.DataGraph
import app.feature.account.data.DataGraphAccountBackend
import app.feature.account.data.UnconfiguredAccountBackend
import app.feature.account.invite.HttpInvitePreviewClient
import app.feature.account.paywall.BillingPremiumGateway
import app.feature.account.platform.DeviceAccountStores
import app.feature.account.platform.DeviceContactsSource
import app.feature.account.platform.DeviceImageImporter
import app.feature.account.platform.LegalLinks
import app.links.AppLinkConfig
import app.ui.theme.AppearanceSettings
import android.content.pm.PackageManager
import java.util.Locale

/** The app's real [AccountEnvironment] (one per process; the shell provides it to the screens). */
object AccountEnvironments {
    @Volatile private var instance: AccountEnvironment? = null

    fun get(context: Context): AccountEnvironment = instance ?: synchronized(this) {
        instance ?: create(context.applicationContext).also { instance = it }
    }

    /** Tests: replaces the process-wide environment (null resets). */
    fun override(env: AccountEnvironment?) = synchronized(this) { instance = env }

    private fun create(app: Context): AccountEnvironment {
        val links = InviteLinks(AppLinkConfig.codec, AppLinkConfig.domain)
        return AccountEnvironment(
            backend = DataGraph.get(app)?.let(::DataGraphAccountBackend) ?: UnconfiguredAccountBackend(),
            stores = DeviceAccountStores(app),
            inviteLinks = links,
            invitePreview = HttpInvitePreviewClient(links),
            premium = BillingPremiumGateway,
            contacts = DeviceContactsSource(app),
            images = DeviceImageImporter(app),
            legal = LegalLinks(BuildConfig.LEGAL_TERMS_URL, BuildConfig.LEGAL_PRIVACY_URL, BuildConfig.SUPPORT_EMAIL),
            region = { region(app) },
            isGranted = { ContextCompat.checkSelfPermission(app, it) == PackageManager.PERMISSION_GRANTED },
            appearance = AppearanceSettings.device(app),
        )
    }

    /** The SIM's, then the network's, then the locale's country (auth.phone calling-code prefill). */
    private fun region(context: Context): String? {
        val tm = context.getSystemService(TelephonyManager::class.java)
        return listOfNotNull(tm?.simCountryIso, tm?.networkCountryIso, Locale.getDefault().country)
            .firstOrNull { it.length == 2 }?.uppercase(Locale.ROOT)
    }
}
