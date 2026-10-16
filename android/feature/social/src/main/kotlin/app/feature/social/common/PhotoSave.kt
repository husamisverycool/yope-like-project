package app.feature.social.common

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import app.data.media.StoragePaths
import app.designsystem.R
import app.ui.system.SystemAlertDialog
import kotlinx.coroutines.launch

/** The save-to-library permission alert's state (hoisted so a test can show it). */
class PhotoSaveUi(denied: Boolean = false) {
    var denied by mutableStateOf(denied)
}

/**
 * "Save to Camera Roll" (`photo.viewer.menu.save`, also the thread's photo "Save"): the original
 * ([originalPath]) into the photo library through the platform gallery saver (MediaStore; API 26–28 ask
 * WRITE_EXTERNAL_STORAGE first). A denial shows the C-29 alert `photo.viewer.permission.*` whose button opens the
 * app's Settings page. [onResult] gets true when saved (the caller plays `haptic.global.success` and the toast).
 */
@Composable
fun rememberPhotoSaver(ui: PhotoSaveUi, onResult: (Boolean) -> Unit): (originalPath: String) -> Unit {
    val data = LocalSocialData.current
    val context = LocalContext.current
    val gallery = LocalSocialServices.current.gallery
    val scope = rememberCoroutineScope()
    val result by rememberUpdatedState(onResult)
    var pending by remember { mutableStateOf<String?>(null) }
    val save: (String) -> Unit = { path ->
        scope.launch {
            val bytes = runCatching { data.download(path) }.getOrNull()
            if (bytes == null) {
                result(false)
            } else {
                val ext = path.substringAfterLast('.', "jpg").lowercase()
                val mime = runCatching { StoragePaths.contentTypeFor(ext) }.getOrDefault("image/jpeg")
                result(gallery.save(context, bytes, mime, ext))
            }
        }
    }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        val path = pending
        pending = null
        if (granted && path != null) save(path) else if (!granted) ui.denied = true
    }
    if (ui.denied) {
        SystemAppearance {
            SystemAlertDialog(
                title = stringRes(R.string.photo_viewer_permission_title),
                text = stringRes(R.string.photo_viewer_permission_detail),
                confirmLabel = stringRes(R.string.photo_viewer_permission_button),
                onConfirm = {
                    ui.denied = false
                    context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)))
                },
                dismissLabel = stringRes(R.string.photo_viewer_delete_cancel),
                onDismiss = { ui.denied = false },
            )
        }
    }
    return { path ->
        if (gallery.needsPermission(context)) {
            pending = path
            launcher.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        } else {
            save(path)
        }
    }
}
