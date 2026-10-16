// Surface: widget.arrival (Android refresh notification).
// References: Retro APK 2026.10.1150 strings notification_channel_display_name_foreground_work
// "Background Work" (design/surfaces/widget.arrival.md → References).
package app.widget

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import app.designsystem.R

/**
 * The notification shown only while a widget refresh runs as a foreground job: expedited work on
 * Android 11 and lower runs as a foreground service and needs one (`widget.arrival` → Android
 * refresh notification). Channel `widget_refresh`, IMPORTANCE_MIN (no sound, no status-bar icon).
 */
object WidgetRefreshNotification {
    const val CHANNEL_ID = "widget_refresh"
    const val NOTIFICATION_ID = 2

    /**
     * Monochrome small-icon drawable. The owner's icon is BLOCKED (design/surfaces/daily.ongoing.md
     * → Gaps); until it is set the app's launcher icon is used, and without either the refresh
     * runs as regular (non-expedited) work so no notification is needed.
     */
    @Volatile var smallIcon: Int? = null

    fun icon(context: Context): Int? = smallIcon ?: context.applicationInfo.icon.takeIf { it != 0 }

    /** Whether a foreground notification can be shown (an icon exists). */
    fun isAvailable(context: Context): Boolean = icon(context) != null

    /** Creates or updates the channel with its copy (`widget.arrival.android.refreshChannel*`). */
    fun registerChannel(context: Context) {
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.widget_arrival_android_refreshchannelname),
            NotificationManager.IMPORTANCE_MIN,
        ).apply { description = context.getString(R.string.widget_arrival_android_refreshchanneldescription) }
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    /** The "Updating widgets…" notification (`widget.arrival.android.refreshTitle`), or null without an icon. */
    fun build(context: Context): Notification? {
        val icon = icon(context) ?: return null
        registerChannel(context)
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(icon)
            .setContentTitle(context.getString(R.string.widget_arrival_android_refreshtitle))
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_DEFAULT)
            .build()
    }

    /** Expedited work needs this notification only before Android 12. */
    fun neededFor(sdkInt: Int = Build.VERSION.SDK_INT): Boolean = sdkInt < Build.VERSION_CODES.S
}
