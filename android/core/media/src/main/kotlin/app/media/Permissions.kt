package app.media

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import androidx.core.content.edit

/** A runtime permission the capture flows need. */
enum class MediaPermission(val manifestName: String) {
    Camera(Manifest.permission.CAMERA),
    Microphone(Manifest.permission.RECORD_AUDIO),
}

/** Where a permission stands, for the in-context permission surfaces (`onboarding.permission.*`). */
sealed interface PermissionState {
    data object Granted : PermissionState

    /** Never asked: show the in-context explanation, then the system prompt. */
    data object NotRequested : PermissionState

    /** Declined once; the system prompt can still be shown. */
    data object Denied : PermissionState

    /** Declined with "don't ask again" (or blocked by policy): only Settings can change it. */
    data object PermanentlyDenied : PermissionState
}

object MediaPermissions {
    private const val PREFS = "media_permissions"

    fun state(activity: Activity, permission: MediaPermission): PermissionState = resolve(
        granted = isGranted(activity, permission),
        showRationale = activity.shouldShowRequestPermissionRationale(permission.manifestName),
        requestedBefore = wasRequested(activity, permission),
    )

    fun isGranted(context: Context, permission: MediaPermission): Boolean =
        ContextCompat.checkSelfPermission(context, permission.manifestName) == PackageManager.PERMISSION_GRANTED

    /** Call when the system prompt is launched, so a later "no rationale" reads as permanent. */
    fun markRequested(context: Context, permission: MediaPermission) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit { putBoolean(permission.name, true) }
    }

    fun wasRequested(context: Context, permission: MediaPermission): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(permission.name, false)

    /**
     * Android reports "no rationale" both before the first request and after "don't ask again";
     * whether we asked before tells them apart.
     */
    fun resolve(granted: Boolean, showRationale: Boolean, requestedBefore: Boolean): PermissionState = when {
        granted -> PermissionState.Granted
        showRationale -> PermissionState.Denied
        requestedBefore -> PermissionState.PermanentlyDenied
        else -> PermissionState.NotRequested
    }
}

/**
 * Photo-library access. The app imports through the system Photo Picker, which needs no
 * permission, and declares no media permission — so this is [PickerOnly] unless a future build
 * adds one. Android 14+ partial access ("selected photos") is reported as [Partial].
 */
sealed interface PhotoLibraryAccess {
    data object PickerOnly : PhotoLibraryAccess
    data object Partial : PhotoLibraryAccess
    data object Full : PhotoLibraryAccess

    companion object {
        private const val READ_MEDIA_VISUAL_USER_SELECTED = "android.permission.READ_MEDIA_VISUAL_USER_SELECTED"

        fun current(context: Context): PhotoLibraryAccess {
            fun granted(p: String) = ContextCompat.checkSelfPermission(context, p) == PackageManager.PERMISSION_GRANTED
            val full = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                granted(Manifest.permission.READ_MEDIA_IMAGES)
            } else {
                @Suppress("DEPRECATION") granted(Manifest.permission.READ_EXTERNAL_STORAGE)
            }
            val partial = Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE && granted(READ_MEDIA_VISUAL_USER_SELECTED)
            return resolve(full, partial)
        }

        fun resolve(fullGranted: Boolean, userSelectedGranted: Boolean): PhotoLibraryAccess = when {
            fullGranted -> Full
            userSelectedGranted -> Partial
            else -> PickerOnly
        }
    }
}
