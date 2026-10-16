package app.feature.account.plans

import android.app.Activity
import android.app.Application
import android.os.Build
import android.os.Bundle
import androidx.glance.appwidget.GlanceAppWidgetManager
import app.data.DataGraph
import app.ui.startup.AppStartupHook
import app.widget.CountdownClock
import app.widget.CountdownWidgetReceiver
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Process start for the plan surfaces (registered in `META-INF/services/app.ui.startup.AppStartupHook`): the countdown
 * widget's snapshot (`widget.countdown` → Data & actions: written "on every plan_* realtime event and on foreground")
 * follows the session and this device's plan writes, and is refreshed each time the app comes to the foreground.
 */
class PlansStartup : AppStartupHook {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun install(application: Application) {
        val graph = DataGraph.get(application) ?: return
        graph.countdown.start(graph.auth)
        CountdownClock.onFirstPlaced = { graph.countdown.request() }
        // The widget picker's generated preview (Android 15+), as the photo widget's (CaptureStartup).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            scope.launch { runCatching { GlanceAppWidgetManager(application).setWidgetPreviews(CountdownWidgetReceiver::class) } }
        }
        application.registerActivityLifecycleCallbacks(ForegroundCallbacks { graph.countdown.request() })
    }

    /** Calls [onForeground] when the first activity starts (the app comes to the foreground). */
    private class ForegroundCallbacks(private val onForeground: () -> Unit) : Application.ActivityLifecycleCallbacks {
        private var started = 0

        override fun onActivityStarted(activity: Activity) {
            if (started++ == 0) onForeground()
        }

        override fun onActivityStopped(activity: Activity) {
            started = (started - 1).coerceAtLeast(0)
        }

        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
        override fun onActivityResumed(activity: Activity) = Unit
        override fun onActivityPaused(activity: Activity) = Unit
        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
        override fun onActivityDestroyed(activity: Activity) = Unit
    }
}
