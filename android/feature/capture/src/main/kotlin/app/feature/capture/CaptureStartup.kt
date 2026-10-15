package app.feature.capture

import android.app.Application
import android.os.Build
import androidx.camera.lifecycle.ProcessCameraProvider
import app.feature.capture.widget.CaptureWidgetConfigureUi
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

/**
 * Process start for the capture group's UI plugged into foundation modules (registered in
 * `META-INF/services/app.ui.startup.AppStartupHook`; the app shell runs it):
 * - the widget's token styling and group picker (core:widget, `widget.android`);
 * - notification channels with their copy and the notification appearance (core:push,
 *   `notifications.push`, `daily.ongoing`), plus the widget-refresh channel (`widget.arrival`);
 * - the widget picker's generated preview (Android 15+; the system rate-limits it);
 * - CameraX pre-warm: the app opens to the camera, so its provider initialises in the background
 *   now and the first preview frame is not held up by it.
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
    runCatching { ChannelCopy.registerAll(application) }
    runCatching { WidgetRefreshNotification.registerChannel(application) }
    runCatching { ProcessCameraProvider.getInstance(application) }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
        startupScope.launch { runCatching { GlanceAppWidgetManager(application).setWidgetPreviews(GroupPhotoWidgetReceiver::class) } }
    }
}
