package app.main

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import app.designsystem.R
import app.push.AppChannel
import app.push.ChannelCopy

/**
 * Registers the notification channels (core:push `AppChannel`, importance fixed there) with the
 * names and descriptions the notifications.push pass wrote (`notifications.push.channel.<id>.name` /
 * `.description`, design/copy/capture.json). A channel whose strings do not exist yet is not
 * registered (Android shows its name in system settings; no name may be invented): today
 * `AppChannel.YearStory` (settings.notifications Gaps, MERGE account A-12), so year-story alerts are
 * not posted until that copy exists.
 */
object AppNotificationChannels {
    fun copy(channel: AppChannel): Pair<Int, Int>? = when (channel) {
        AppChannel.DailyInvitation -> R.string.notifications_push_channel_dailyinvitation_name to R.string.notifications_push_channel_dailyinvitation_description
        AppChannel.NewPost -> R.string.notifications_push_channel_newpost_name to R.string.notifications_push_channel_newpost_description
        AppChannel.ReactionsAndReplies -> R.string.notifications_push_channel_reactionsreplies_name to R.string.notifications_push_channel_reactionsreplies_description
        AppChannel.Recap -> R.string.notifications_push_channel_recap_name to R.string.notifications_push_channel_recap_description
        AppChannel.BirthdayRequest -> R.string.notifications_push_channel_birthdayrequest_name to R.string.notifications_push_channel_birthdayrequest_description
        AppChannel.Tribute -> R.string.notifications_push_channel_tribute_name to R.string.notifications_push_channel_tribute_description
        AppChannel.YearStory -> null
        AppChannel.DevelopedPhotos -> R.string.notifications_push_channel_developedphotos_name to R.string.notifications_push_channel_developedphotos_description
        AppChannel.Plans -> R.string.notifications_push_channel_plans_name to R.string.notifications_push_channel_plans_description
        AppChannel.Memories -> R.string.notifications_push_channel_memories_name to R.string.notifications_push_channel_memories_description
    }

    fun register(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val channels = AppChannel.entries.mapNotNull { channel ->
            val (name, _) = copy(channel) ?: return@mapNotNull null
            // The developed-photos description takes the formatted reveal time (core:push `ChannelCopy.description`).
            NotificationChannel(channel.id, context.getString(name), channel.importance).apply { setDescription(ChannelCopy.description(context, channel)) }
        }
        manager.createNotificationChannels(channels)
    }
}
