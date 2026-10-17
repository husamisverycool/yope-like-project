// Surface: camera.quickaccess — the Quick Settings tile that opens the camera (design/surfaces/camera.quickaccess.md →
// Android Quick Settings tile; token camera.quickaccess.layout.entries → androidTile: "TileService, always
// STATE_INACTIVE (a button, no on / off), icon drawable ic_tile_camera, label camera.quickaccess.tile.label, subtitle
// camera.quickaccess.tile.subtitle; a tap collapses the panel and opens camera.capture; on a secure lock screen
// unlockAndRun first"). Mechanics: Snapchat's Lock Screen camera control; platform:
// https://developer.android.com/develop/ui/views/quicksettings-tiles.
package app.feature.capture

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import app.designsystem.R
import app.links.DeepLinkIntents
import app.model.DeepLink

/**
 * "Take a photo" from the Quick Settings panel: the app opens to the camera (`app://camera`, as a widget tap without a
 * group — `camera.fromwidget`). The tile is a button: always inactive, labelled with the app's name and "Camera".
 */
class CameraTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        val tile = qsTile ?: return
        tile.state = Tile.STATE_INACTIVE
        tile.label = getString(R.string.camera_quickaccess_tile_label)
        tile.contentDescription = getString(R.string.camera_quickaccess_tile_label)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) tile.subtitle = getString(R.string.camera_quickaccess_tile_subtitle)
        tile.updateTile()
    }

    override fun onClick() {
        super.onClick()
        // On a secure lock screen the system asks to unlock first (the camera needs the person's groups).
        if (isLocked) unlockAndRun { openCamera() } else openCamera()
    }

    /** Collapses the panel and opens the camera. */
    @SuppressLint("StartActivityAndCollapseDeprecated")
    private fun openCamera() {
        val intent = DeepLinkIntents.intent(this, DeepLink.Camera(null)) ?: packageManager.getLaunchIntentForPackage(packageName) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pending = PendingIntent.getActivity(this, REQUEST_CODE, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            startActivityAndCollapse(pending)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    private companion object {
        /** One PendingIntent of this tile (request codes only tell intents apart). */
        const val REQUEST_CODE = 0
    }
}
