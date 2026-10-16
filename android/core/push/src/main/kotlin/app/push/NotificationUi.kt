// Surfaces: notifications.push (Android channels, layouts, small-icon / accent hooks),
// daily.notification and daily.ongoing (the invitation's presentation on Android).
// References: design/surfaces/notifications.push.md, daily.notification.md, daily.ongoing.md
// (system-drawn; Retro's copy voice and channel naming, APK 2026.10.1150 notification_channel_display_*;
// BeReal's MM:SS countdown as the system chronometer). Decisions: MERGE_DECISIONS RC-16 … RC-18.
package app.push

import android.content.Context
import app.designsystem.R

/**
 * The user-visible copy of each notification channel (`notifications.push.channel.*`) and the set
 * of channels the app registers. Importance per `Tokens.Layouts.NotificationsPushLayoutChannels`
 * is fixed in [AppChannel].
 */
object ChannelCopy {
    /**
     * Channels with an event the worker actually sends. `AppChannel.YearStory` has no sent event
     * and no copy: registering it would advertise a notification that never comes (owner
     * decision, design/surfaces/notifications.push.md → Platform notes).
     */
    val registered: List<AppChannel> = AppChannel.entries.filter { nameRes(it) != null }

    fun nameRes(channel: AppChannel): Int? = when (channel) {
        AppChannel.DailyInvitation -> R.string.notifications_push_channel_dailyinvitation_name
        AppChannel.NewPost -> R.string.notifications_push_channel_newpost_name
        AppChannel.ReactionsAndReplies -> R.string.notifications_push_channel_reactionsreplies_name
        AppChannel.Recap -> R.string.notifications_push_channel_recap_name
        AppChannel.BirthdayRequest -> R.string.notifications_push_channel_birthdayrequest_name
        AppChannel.Tribute -> R.string.notifications_push_channel_tribute_name
        AppChannel.YearStory -> null
    }

    fun descriptionRes(channel: AppChannel): Int? = when (channel) {
        AppChannel.DailyInvitation -> R.string.notifications_push_channel_dailyinvitation_description
        AppChannel.NewPost -> R.string.notifications_push_channel_newpost_description
        AppChannel.ReactionsAndReplies -> R.string.notifications_push_channel_reactionsreplies_description
        AppChannel.Recap -> R.string.notifications_push_channel_recap_description
        AppChannel.BirthdayRequest -> R.string.notifications_push_channel_birthdayrequest_description
        AppChannel.Tribute -> R.string.notifications_push_channel_tribute_description
        AppChannel.YearStory -> null
    }

    /** Creates or updates every channel that has copy. Safe to call on every process start. */
    fun registerAll(context: Context) {
        NotificationChannels.register(
            context,
            registered,
            name = { context.getString(requireNotNull(nameRes(it))) },
            description = { channel -> descriptionRes(channel)?.let(context::getString) },
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
 * The capture group's [NotificationAppearance]. The monochrome small icon is an owner asset
 * (BLOCKED, design/surfaces/daily.ongoing.md → Gaps): until it exists [smallIcon] is null, so
 * [Posting.smallIcon] falls back to the app's launcher icon, and nothing is posted while the app
 * has none either.
 */
object CaptureNotificationAppearance : NotificationAppearance {
    override val smallIcon: Int? get() = null
    override val accentColor: Int? get() = null
}
