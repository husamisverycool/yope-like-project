package app.main

import android.app.Application
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import app.billing.Billing
import app.data.DataGraph
import app.links.AppLinks
import app.links.DeepLinkIntents
import app.model.DeepLink
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.receiveAsFlow

/**
 * Process start. Firebase is not touched here (it initialises lazily, and only when configured).
 * The screens pass registers what needs copy and tokens: notification channel names
 * (`NotificationChannels.register`), `NotificationAppearance`, `PhotoWidgetSlots`,
 * `WidgetConfigureUi`. The data layer's session glue sets `PushTokens.sink` and
 * `QuietHoursSource` (core:data `SessionGlue`); it stays off while config/app.json has no
 * Supabase URL / key.
 */
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        DeepLinkIntents.targetActivity = MainActivity::class.java
        Billing.configure(this)
        DataGraph.install(this)
    }
}

/**
 * The single activity. Every way in — launcher, invite App Link, widget tap, notification tap —
 * arrives as an intent and is routed into the navigation graph.
 */
class MainActivity : ComponentActivity() {
    private val deepLinks = Channel<DeepLink>(Channel.BUFFERED)

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        // After a configuration change the back stack is restored; route the launch intent once.
        if (savedInstanceState == null) route(intent)
        setContent { AppNavHost(deepLinks = deepLinks.receiveAsFlow()) }
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
