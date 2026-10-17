package app.feature.capture

import android.app.Application
import android.os.Build
import androidx.camera.lifecycle.ProcessCameraProvider
import app.feature.capture.data.CaptureDataProvider
import app.feature.capture.widget.CameraShortcuts
import app.feature.capture.widget.CaptureWidgetConfigureUi
import app.feature.capture.widget.WidgetPrefetch
import app.widget.PersonalWidgetStores
import app.widget.PersonalWidgets
import app.push.CaptureNotificationAppearance
import app.push.ChannelCopy
import app.push.NotificationAppearance
import app.ui.startup.AppStartupHook
import app.widget.GroupPhotoWidgetReceiver
import app.widget.PhotoWidgetSlots
import app.widget.TokenPhotoWidgetSlots
import app.widget.WidgetConfigureUi
import app.widget.WidgetRefreshNotification
import androidx.glance.appwidget.GlanceAppWidgetManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import app.data.DataGraph
import app.data.repo.AuthState
import app.widget.WidgetBinding
import app.widget.WidgetFileStore
import app.widget.WidgetGroupMeta
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.map

/**
 * Process start for the capture group's UI plugged into foundation modules (registered in
 * `META-INF/services/app.ui.startup.AppStartupHook`; the app shell runs it):
 * - the widget's token styling and group picker (core:widget, `widget.android`);
 * - notification channels with their copy and the notification appearance (core:push,
 *   `notifications.push`, `daily.ongoing`), plus the widget-refresh channel (`widget.arrival`);
 * - the widget picker's generated preview (Android 15+; the system rate-limits it);
 * - the widget's signed-out state (`widget.home.small.empty.signedOut`): the session is mirrored into the
 *   widget store so every placed widget says so, and a tap opens the app's sign-in;
 * - CameraX pre-warm: the app opens to the camera, so its provider initialises in the background
 *   now and the first preview frame is not held up by it;
 * - the friend and memories widgets' first look-up when one is placed (`PersonalWidgets.onPlaced`), and the launcher's
 *   per-group camera shortcuts kept to the person's groups (`camera.quickaccess`).
 */
class CaptureStartup : AppStartupHook {
    override fun install(application: Application) = installCapture(application)
}

private val startupScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

@Volatile private var installed = false

/** Idempotent; also callable directly (tests, or an app shell without the hook runner). */
fun installCapture(application: Application) {
    if (installed) return
    installed = true
    PhotoWidgetSlots.current = TokenPhotoWidgetSlots
    WidgetConfigureUi.current = CaptureWidgetConfigureUi
    NotificationAppearance.current = CaptureNotificationAppearance
    WidgetRefreshNotification.smallIcon = app.push.R.drawable.ic_stat_jolt
    runCatching { ChannelCopy.registerAll(application) }
    runCatching { WidgetRefreshNotification.registerChannel(application) }
    runCatching { ProcessCameraProvider.getInstance(application) }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
        startupScope.launch { runCatching { GlanceAppWidgetManager(application).setWidgetPreviews(GroupPhotoWidgetReceiver::class) } }
    }
    PersonalWidgets.onPlaced = { WidgetPrefetch.refreshPersonal(application, CaptureDataProvider.get(application)) }
    DataGraph.get(application)?.let { graph ->
        mirrorSessionIntoWidgets(application, graph.auth.authState)
        // A group left or deleted loses its camera shortcut when the group list loads.
        startupScope.launch {
            graph.groups.myGroupIds.filterNotNull().distinctUntilChanged().collect { ids ->
                runCatching { CameraShortcuts.sync(application, ids) }
            }
        }
    }
}

/** Keeps the widget store's signed-out marker in step with the session and re-renders the widgets when it flips. */
internal fun mirrorSessionIntoWidgets(application: Application, states: Flow<AuthState>) {
    val meta = WidgetGroupMeta.of(WidgetFileStore.default(application))
    startupScope.launch {
        states
            .map { state -> if (state is AuthState.Initializing) null else state is AuthState.SignedOut }
            .filterNotNull()
            .distinctUntilChanged()
            .collect { signedOut ->
                if (meta.isSignedOut() != signedOut) {
                    runCatching { meta.setSignedOut(signedOut) }
                    if (signedOut) {
                        // Nothing of the last person stays: friend and memories photos, premium styles, group shortcuts.
                        runCatching { PersonalWidgetStores.clear(application) }
                        runCatching { meta.setPremium(false) }
                        runCatching { CameraShortcuts.clear(application) }
                    }
                    runCatching { WidgetBinding.refreshAll(application) }
                }
            }
    }
}
