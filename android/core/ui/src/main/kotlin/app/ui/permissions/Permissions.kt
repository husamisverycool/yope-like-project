package app.ui.permissions

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import app.ui.system.SystemAlertDialog

/**
 * Android runtime permissions as `design/surfaces/system.permissions.md` specifies them:
 * asked in context; the rationale dialog (M3 basic dialog, `settings.account.layout.alert`) only
 * when `shouldShowRequestPermissionRationale()` is true; always cancellable ("Not Now"); after a
 * permanent denial (two denials) the confirming action becomes "Open Settings" (app details).
 */
enum class PermissionStatus {
    Granted,

    /** Never asked, or asked and denied once: the system dialog can still appear. */
    Askable,

    /** Denied with "don't ask again" / twice: only Settings can change it. */
    PermanentlyDenied,
}

/** Copy of the rationale dialog (`system.permissions.rationale.<resource>.*`, `.notNow`, `.continue`, `system.permissions.openSettings`). */
data class PermissionRationale(
    val title: String,
    /** BLOCKED while it contains `{app_name}`: release builds pass null and the dialog shows the title only. */
    val message: String?,
    val notNow: String,
    val continueLabel: String,
    val openSettings: String,
)

object PermissionChecks {
    private const val PREFS = "permission_requests"

    fun isGranted(context: Context, permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED

    /** POST_NOTIFICATIONS is a runtime permission only from API 33. */
    fun notificationsNeedRuntimeRequest(sdkInt: Int = Build.VERSION.SDK_INT): Boolean = sdkInt >= Build.VERSION_CODES.TIRAMISU

    fun status(context: Context, permission: String): PermissionStatus {
        if (isGranted(context, permission)) return PermissionStatus.Granted
        val activity = context.findActivity() ?: return PermissionStatus.Askable
        val asked = wasAsked(context, permission)
        val rationale = ActivityCompat.shouldShowRequestPermissionRationale(activity, permission)
        return if (asked && !rationale) PermissionStatus.PermanentlyDenied else PermissionStatus.Askable
    }

    fun wasAsked(context: Context, permission: String): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(permission, false)

    internal fun markAsked(context: Context, permission: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(permission, true).apply()
    }

    /** The app's page in system Settings (`Settings.ACTION_APPLICATION_DETAILS_SETTINGS`, `package:` URI). */
    fun appSettingsIntent(context: Context): Intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    /** The app's notification settings (`ACTION_APP_NOTIFICATION_SETTINGS`). */
    fun notificationSettingsIntent(context: Context): Intent =
        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    fun openSafely(context: Context, intent: Intent) {
        try {
            context.startActivity(intent)
        } catch (_: android.content.ActivityNotFoundException) {
        }
    }
}

/** A permission request in progress; call [launch] from the in-context action. */
@Stable
class PermissionRequest internal constructor(private val onLaunch: () -> Unit) {
    fun launch() = onLaunch()
}

/**
 * Remembers a request for [permission] and draws its rationale dialog when needed.
 *
 * [launch] → granted: [onResult] (true) at once · askable without rationale: the system dialog ·
 * askable with rationale: [rationale] dialog → Continue → system dialog, Not Now → [onResult] (false) ·
 * permanently denied: the dialog with "Open Settings" → app details settings.
 */
@Composable
fun rememberPermissionRequest(
    permission: String,
    rationale: PermissionRationale,
    onResult: (granted: Boolean) -> Unit,
): PermissionRequest {
    val context = LocalContext.current
    val result by rememberUpdatedState(onResult)
    var dialog by remember { mutableStateOf<PermissionStatus?>(null) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        PermissionChecks.markAsked(context, permission)
        result(granted)
    }
    val request = remember(permission) {
        PermissionRequest {
            when (PermissionChecks.status(context, permission)) {
                PermissionStatus.Granted -> result(true)
                PermissionStatus.PermanentlyDenied -> dialog = PermissionStatus.PermanentlyDenied
                PermissionStatus.Askable -> {
                    val activity = context.findActivity()
                    if (activity != null && ActivityCompat.shouldShowRequestPermissionRationale(activity, permission)) {
                        dialog = PermissionStatus.Askable
                    } else {
                        launcher.launch(permission)
                    }
                }
            }
        }
    }
    when (dialog) {
        PermissionStatus.Askable -> SystemAlertDialog(
            title = rationale.title,
            text = rationale.message,
            confirmLabel = rationale.continueLabel,
            onConfirm = { dialog = null; launcher.launch(permission) },
            dismissLabel = rationale.notNow,
            onDismiss = { dialog = null; result(false) },
        )
        PermissionStatus.PermanentlyDenied -> SystemAlertDialog(
            title = rationale.title,
            text = rationale.message,
            confirmLabel = rationale.openSettings,
            onConfirm = { dialog = null; PermissionChecks.openSafely(context, PermissionChecks.appSettingsIntent(context)) },
            dismissLabel = rationale.notNow,
            onDismiss = { dialog = null; result(false) },
        )
        else -> Unit
    }
    return request
}

/** The Activity hosting [this] context, if any. */
fun Context.findActivity(): Activity? {
    var c: Context? = this
    while (c is ContextWrapper) {
        if (c is Activity) return c
        c = c.baseContext
    }
    return null
}
