package app.main

import android.app.Application
import android.content.Intent
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.toArgb
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import app.billing.Billing
import app.data.DataGraph
import app.designsystem.DsAppearance
import app.designsystem.generated.Tokens
import app.feature.account.AccountEnvironments
import app.feature.account.invite.InstallReferrerReader
import app.feature.capture.data.CaptureDataProvider
import app.feature.capture.share.ShareIn
import app.feature.capture.widget.CameraShortcuts
import app.feature.capture.widget.WidgetPrefetch
import app.links.AppLinks
import app.links.DeepLinkIntents
import app.model.DeepLink
import app.push.DeliveredAlerts
import app.push.NotificationAppearance
import app.ui.startup.AppStartupHook
import app.ui.theme.AppTheme
import app.ui.theme.AppearanceSettings
import app.ui.theme.LocalAppearanceSettings
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch

/**
 * Process start: data layer, billing, notification channels (names from `R.string`,
 * `notifications.push.channel.*`), `NotificationAppearance` (accent `color.global.accent` in the system
 * appearance, per daily.ongoing; the small icon is an owner asset, BLOCKED), feature start-up hooks (the capture
 * group's `PhotoWidgetSlots` / `WidgetConfigureUi` / notification UI, registered through
 * `META-INF/services/app.ui.startup.AppStartupHook`), and the one-time Play install referrer read
 * (invite.web install path: `invite_token=<token>` becomes the pending invite).
 */
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        DeepLinkIntents.targetActivity = MainActivity::class.java
        // camera.quickaccess: the per-group launcher shortcuts use the static shortcut's adaptive icon.
        CameraShortcuts.iconRes = R.drawable.ic_shortcut_camera
        Billing.configure(this)
        DataGraph.install(this)?.let { graph -> SessionEndCleanup.start(this, graph.auth.authState, graph.scope) }
        AppNotificationChannels.register(this)
        NotificationAppearance.current = object : NotificationAppearance {
            // Read when a notification is posted, outside composition: the accent of the system appearance.
            override val accentColor: Int
                get() = DsAppearance.pickSystem(Tokens.ColorsLight.globalAccent, Tokens.ColorsDark.globalAccent).toArgb()
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
 * The single activity. Every way in — launcher, invite App Link, widget tap, notification tap, a share from another app
 * (share.in) — arrives as an intent and is routed into the navigation graph. The appearance follows the system
 * (`layout.global.appearance`): edge-to-edge with system-bar icons that contrast with the page
 * (`SystemBarStyle.auto`, scrims in the page colour `color.global.background.android` of each appearance),
 * the window background in the page colour of the current appearance, and the Compose content in
 * [AppTheme] (which provides `DsTheme` with the system setting).
 */
class MainActivity : ComponentActivity() {
    private val deepLinks = Channel<DeepLink>(Channel.BUFFERED)

    /** The navigation controller of the current content (routing tests read the destination). */
    internal var navController: NavHostController? = null
        private set

    override fun onCreate(savedInstanceState: Bundle?) {
        val appearance = AppearanceSettings.device(this)
        applyWindowColours(appearance.trueBlack.value)
        super.onCreate(savedInstanceState)
        // After a configuration change the back stack is restored; route the launch intent once.
        if (savedInstanceState == null) route(intent)
        setContent {
            val nav = rememberNavController()
            navController = nav
            val trueBlack by appearance.trueBlack.collectAsState()
            // Settings → True Black (Android, owner decision 21) repaints the window and the bar scrims at once.
            LaunchedEffect(trueBlack) { applyWindowColours(trueBlack) }
            CompositionLocalProvider(LocalAppearanceSettings provides appearance) {
                AppTheme { AppNavHost(deepLinks = deepLinks.receiveAsFlow(), navController = nav, env = AccountEnvironments.get(this)) }
            }
        }
    }

    /**
     * Edge-to-edge with bar scrims and the window background in the page colour of each appearance
     * (`color.global.background.android`, or `….trueBlack` while Settings → True Black is on — dark only).
     */
    private fun applyWindowColours(trueBlack: Boolean) {
        val light = Tokens.ColorsLight.globalBackgroundAndroid.toArgb()
        val dark = (if (trueBlack) Tokens.ColorsDark.globalBackgroundAndroidTrueBlack else Tokens.ColorsDark.globalBackgroundAndroid).toArgb()
        enableEdgeToEdge(statusBarStyle = SystemBarStyle.auto(light, dark), navigationBarStyle = SystemBarStyle.auto(light, dark))
        window.setBackgroundDrawable(ColorDrawable(DsAppearance.pick(this, light, dark)))
    }

    /**
     * Alerts of photos deleted while the app was in the background leave the shade (core:push `DeliveredAlerts`), and each
     * placed widget's group shows its newest photo or collage (`WidgetPrefetch.refreshPlaced`).
     */
    override fun onStart() {
        super.onStart()
        DataGraph.get(this)?.let { graph ->
            graph.scope.launch { DeliveredAlerts.reconcile(applicationContext) }
            if (graph.auth.currentUserId != null) {
                graph.scope.launch { WidgetPrefetch.refreshPlaced(applicationContext, CaptureDataProvider.get(applicationContext)) }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        route(intent)
    }

    /**
     * Parsed with the account environment's link codec: the one its invite sheet formats links with. A share (share.in)
     * is copied at once, while its read grant holds; the shell opens the camera with it once the person is home.
     */
    private fun route(intent: Intent?) {
        if (intent != null && ShareIn.isShare(intent)) {
            ShareIn.receive(this, intent)
            return
        }
        AppLinks.parse(intent, AccountEnvironments.get(this).inviteLinks.codec)?.let(deepLinks::trySend)
    }
}
