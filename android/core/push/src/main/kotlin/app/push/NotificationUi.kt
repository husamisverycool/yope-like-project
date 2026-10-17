// Surfaces: notifications.push (Android channels, layouts, small-icon / accent hooks),
// daily.notification and daily.ongoing (the invitation's presentation on Android).
// References: design/surfaces/notifications.push.md, daily.notification.md, daily.ongoing.md
// (system-drawn; Retro's copy voice and channel naming, APK 2026.10.1150 notification_channel_display_*;
// BeReal's MM:SS countdown as the system chronometer). Decisions: MERGE_DECISIONS RC-16 … RC-18.
package app.push

import android.content.Context
import android.text.format.DateFormat
import app.designsystem.R
import app.designsystem.generated.Tokens
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.util.Date

/**
 * The user-visible copy of each notification channel (`notifications.push.channel.*`) and the set
 * of channels the app registers. Importance per `Tokens.Layouts.NotificationsPushLayoutChannels`
 * is fixed in [AppChannel].
 */
object ChannelCopy {
    /**
     * Channels with an event the worker actually sends (every channel since the worker sends the
     * year story's one push, `push.year_story`, owner decision 31).
     */
    val registered: List<AppChannel> = AppChannel.entries.filter { nameRes(it) != null }

    fun nameRes(channel: AppChannel): Int? = when (channel) {
        AppChannel.DailyInvitation -> R.string.notifications_push_channel_dailyinvitation_name
        AppChannel.NewPost -> R.string.notifications_push_channel_newpost_name
        AppChannel.ReactionsAndReplies -> R.string.notifications_push_channel_reactionsreplies_name
        AppChannel.Recap -> R.string.notifications_push_channel_recap_name
        AppChannel.BirthdayRequest -> R.string.notifications_push_channel_birthdayrequest_name
        AppChannel.Tribute -> R.string.notifications_push_channel_tribute_name
        AppChannel.YearStory -> R.string.notifications_push_channel_yearstory_name
        AppChannel.DevelopedPhotos -> R.string.notifications_push_channel_developedphotos_name
        AppChannel.Plans -> R.string.notifications_push_channel_plans_name
    }

    fun descriptionRes(channel: AppChannel): Int? = when (channel) {
        AppChannel.DailyInvitation -> R.string.notifications_push_channel_dailyinvitation_description
        AppChannel.NewPost -> R.string.notifications_push_channel_newpost_description
        AppChannel.ReactionsAndReplies -> R.string.notifications_push_channel_reactionsreplies_description
        AppChannel.Recap -> R.string.notifications_push_channel_recap_description
        AppChannel.BirthdayRequest -> R.string.notifications_push_channel_birthdayrequest_description
        AppChannel.Tribute -> R.string.notifications_push_channel_tribute_description
        AppChannel.YearStory -> R.string.notifications_push_channel_yearstory_description
        AppChannel.DevelopedPhotos -> R.string.notifications_push_channel_developedphotos_description
        AppChannel.Plans -> R.string.notifications_push_channel_plans_description
    }

    /**
     * The channel's description as shown in system settings. `developedPhotos` takes `{time}`: the reveal time
     * (`camera.overnight.layout.reveal` time, 09:00) in the locale's short time format (`DateFormat.getTimeFormat`,
     * MERGE ON-10).
     */
    fun description(context: Context, channel: AppChannel): String? {
        val res = descriptionRes(channel) ?: return null
        return if (channel == AppChannel.DevelopedPhotos) context.getString(res, revealTime(context)) else context.getString(res)
    }

    /** `{time}` of the overnight copy: 09:00 today in the device's zone, as the locale writes a short time ("9:00 AM"). */
    fun revealTime(context: Context): String {
        val time = LocalTime.parse(Tokens.Layouts.CameraOvernightLayoutReveal.time)
        val zone = ZoneId.systemDefault()
        return DateFormat.getTimeFormat(context).format(Date.from(LocalDate.now(zone).atTime(time).atZone(zone).toInstant()))
    }

    /** Creates or updates every channel that has copy. Safe to call on every process start. */
    fun registerAll(context: Context) {
        NotificationChannels.register(
            context,
            registered,
            name = { context.getString(requireNotNull(nameRes(it))) },
            description = { channel -> description(context, channel) },
        )
    }
}

/**
 * The daily invitation's accent: none. Retro's notification tint is not captured, so the system
 * default applies (`daily.ongoing` → "No `setColor`", MERGE_DECISIONS RC-17), as for every alert
 * ([NotificationAppearance.accentColor]).
 */
object InvitationAppearance {
    val accentColor: Int? get() = null
}

/**
 * The capture group's [NotificationAppearance]: the monochrome status-bar "J" of the app icon
 * (owner decision 32, tools/appicon.py; Material 3: white on transparent).
 */
object CaptureNotificationAppearance : NotificationAppearance {
    override val smallIcon: Int get() = app.push.R.drawable.ic_stat_jolt
    override val accentColor: Int? get() = null
}
