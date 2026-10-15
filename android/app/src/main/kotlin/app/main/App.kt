package app.main

import android.app.Application
import android.content.Intent
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.ui.graphics.toArgb
import app.billing.Billing
import app.data.DataGraph
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironments
import app.feature.account.invite.InstallReferrerReader
import app.links.AppLinks
import app.links.DeepLinkIntents
import app.model.DeepLink
import app.push.NotificationAppearance
import app.ui.startup.AppStartupHook
import app.ui.theme.AppTheme
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.receiveAsFlow

/**
 * Process start: data layer, billing, notification channels (names from `R.string`,
 * `notifications.push.channel.*`), `NotificationAppearance` (accent `color.global.accent`, per
 * daily.ongoing; the small icon is an owner asset, BLOCKED), feature start-up hooks (the capture
 * group's `PhotoWidgetSlots` / `WidgetConfigureUi` / notification UI, registered through
 * `META-INF/services/app.ui.startup.AppStartupHook`), and the one-time Play install referrer read
 * (invite.web install path: `invite_token=<token>` becomes the pending invite).
 */
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        DeepLinkIntents.targetActivity = MainActivity::class.java
        Billing.configure(this)
        DataGraph.install(this)
        AppNotificationChannels.register(this)
        NotificationAppearance.current = object : NotificationAppearance {
            override val accentColor: Int = Tokens.Colors.globalAccent.toArgb()
        }
        AppStartupHook.runAll(this)
        readInstallReferrerOnce()
    }

    private fun readInstallReferrerOnce() {
        val stores = AccountEnvironments.get(this).stores
        if (stores.referrerChecked) return
        InstallReferrerReader.read(this) { token ->
            stores.referrerChecked = true
            if (token != null && stores.pendingInviteToken == null) stores.pendingInviteToken = token
        }
    }
}

/**
 * The single activity. Every way in — launcher, invite App Link, widget tap, notification tap —
 * arrives as an intent and is routed into the navigation graph. Dark only
 * (`layout.global.appearance`): light system-bar content over `color.global.backgroundDeep`.
 */
class MainActivity : ComponentActivity() {
    private val deepLinks = Channel<DeepLink>(Channel.BUFFERED)

    override fun onCreate(savedInstanceState: Bundle?) {
        val dark = Tokens.Colors.globalBackgroundDeep.toArgb()
        enableEdgeToEdge(statusBarStyle = SystemBarStyle.dark(dark), navigationBarStyle = SystemBarStyle.dark(dark))
        super.onCreate(savedInstanceState)
        window.setBackgroundDrawable(ColorDrawable(dark))
        // After a configuration change the back stack is restored; route the launch intent once.
        if (savedInstanceState == null) route(intent)
        setContent {
            AppTheme { AppNavHost(deepLinks = deepLinks.receiveAsFlow(), env = AccountEnvironments.get(this)) }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        route(intent)
    }

    private fun route(intent: Intent?) {
        AppLinks.parse(intent)?.let(deepLinks::trySend)
    }
}
