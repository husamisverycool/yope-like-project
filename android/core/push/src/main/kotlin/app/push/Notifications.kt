package app.push

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import app.links.AppLinkConfig
import app.links.DeepLinkIntents
import app.model.CountdownState
import app.model.PushMessage
import app.model.QuietHours
import java.time.Duration
import java.time.Instant
import java.time.ZoneId

/**
 * Notification channels, one per kind of notification so people can tune each separately.
 * Channel names are user-facing copy: [ChannelCopy.registerAll] registers them with
 * `notifications.push.channel.*`. Until then nothing is posted (Android requires a channel).
 */
enum class AppChannel(val id: String, val importance: Int) {
    /** Same-moment invitation (importance per design/surfaces/daily.ongoing.md: heads-up; it does not override Do Not Disturb). */
    DailyInvitation("daily_invitation", NotificationManager.IMPORTANCE_HIGH),
    NewPost("new_post", NotificationManager.IMPORTANCE_DEFAULT),
    ReactionsAndReplies("reactions_replies", NotificationManager.IMPORTANCE_DEFAULT),
    Recap("recap", NotificationManager.IMPORTANCE_DEFAULT),
    BirthdayRequest("birthday_request", NotificationManager.IMPORTANCE_DEFAULT),
    Tribute("tribute", NotificationManager.IMPORTANCE_DEFAULT),
    YearStory("year_story", NotificationManager.IMPORTANCE_DEFAULT),

    /**
     * Overnight photos revealed at 09:00 (`camera.overnight` C, `notifications.push.layout.channels` `developed_photos`,
     * MERGE ON-9): the reveal push is type `new_post` with `revealed_at` (docs/API.md §14.3), parsed as
     * [PushMessage.AlertKind.PhotosDeveloped].
     */
    DevelopedPhotos("developed_photos", NotificationManager.IMPORTANCE_DEFAULT),

    /** A plan was made, changed or cancelled, and the day-before reminder (`plans`, MERGE PL-12). */
    Plans("plans", NotificationManager.IMPORTANCE_DEFAULT);

    companion object {
        fun forAlert(kind: PushMessage.AlertKind): AppChannel = when (kind) {
            PushMessage.AlertKind.NewPost -> NewPost
            PushMessage.AlertKind.Reaction, PushMessage.AlertKind.Reply -> ReactionsAndReplies
            PushMessage.AlertKind.RecapReady -> Recap
            PushMessage.AlertKind.BirthdayRequest -> BirthdayRequest
            PushMessage.AlertKind.TributeForYou -> Tribute
            PushMessage.AlertKind.YearStory -> YearStory
            PushMessage.AlertKind.Plan -> Plans
            PushMessage.AlertKind.PhotosDeveloped -> DevelopedPhotos
        }
    }
}

object NotificationChannels {
    /**
     * Creates or updates every channel. [name] and [description] return the localized copy
     * (`context.getString(R.string.…)`), supplied by the caller so this module references no
     * string that does not exist yet.
     */
    fun register(
        context: Context,
        name: (AppChannel) -> CharSequence,
        description: (AppChannel) -> CharSequence? = { null },
    ) = register(context, AppChannel.entries, name, description)

    /** Creates or updates [channels] only (see [ChannelCopy.registerAll] for the app's set). */
    fun register(
        context: Context,
        channels: Collection<AppChannel>,
        name: (AppChannel) -> CharSequence,
        description: (AppChannel) -> CharSequence? = { null },
    ) {
        val manager = context.getSystemService(NotificationManager::class.java)
        val created = channels.map { channel ->
            NotificationChannel(channel.id, name(channel), channel.importance).apply {
                description(channel)?.let { setDescription(it.toString()) }
            }
        }
        manager.createNotificationChannels(created)
    }

    fun isRegistered(context: Context, channel: AppChannel): Boolean =
        context.getSystemService(NotificationManager::class.java).getNotificationChannel(channel.id) != null
}

/**
 * Notification styling, supplied from tokens by the screens pass. Android requires a small icon;
 * until one is set the app's launcher icon is used if it has one, else nothing is posted.
 */
interface NotificationAppearance {
    /** Monochrome small-icon drawable resource. */
    val smallIcon: Int? get() = null

    /** Accent color (ARGB, from `Tokens.Colors`); null leaves the system default. */
    val accentColor: Int? get() = null

    companion object {
        @Volatile var current: NotificationAppearance = object : NotificationAppearance {}
    }
}

/** The person's quiet hours, provided by the notification settings (settings pass). */
fun interface QuietHoursSource {
    fun current(): Pair<QuietHours, ZoneId>?

    companion object {
        @Volatile var current: QuietHoursSource = QuietHoursSource { null }
    }
}

internal object Posting {
    fun canPost(context: Context, channel: AppChannel): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return false
        return NotificationChannels.isRegistered(context, channel)
    }

    /** The appearance's icon, else the app's status-bar icon (owner decision 32: the monochrome "J"). */
    @Suppress("UNUSED_PARAMETER")
    fun smallIcon(context: Context): Int? = NotificationAppearance.current.smallIcon ?: R.drawable.ic_stat_jolt
}

internal fun NotificationCompat.Builder.applyAppearance(): NotificationCompat.Builder = apply {
    NotificationAppearance.current.accentColor?.let(::setColor)
}

/**
 * The daily invitation's countdown notification (surface `daily.ongoing`,
 * `Tokens.Layouts.DailyOngoingLayoutNotification`): a standard notification whose header
 * chronometer counts down to the server's `closesAt`, removed by the system when the window
 * closes. It is dismissible and never promoted to a Live Update (MERGE_DECISIONS C-11: the
 * invitation is triggered by the server, not by the person; tenet "Invitations, never
 * obligations"). During the person's quiet hours it arrives silently (the push contract carries no
 * quiet-hours flag, so the device applies [QuietHoursSource]).
 */
object DailyInvitationNotifier {
    private const val ID = 1
    /** A device clock this far from the server's is corrected for; below it push latency dominates. */
    private val TRUSTED_SKEW: Duration = Duration.ofSeconds(30)

    fun tag(groupId: String) = "daily:$groupId"

    /** Returns whether the notification was posted. */
    fun show(context: Context, message: PushMessage.DailyInvitation, deviceNow: Instant = Instant.now()): Boolean {
        val channel = AppChannel.DailyInvitation
        if (!Posting.canPost(context, channel)) return false
        val icon = Posting.smallIcon(context) ?: return false

        // closesAt on this device's clock (corrected only for a clock that is clearly wrong).
        val skew = message.sentAt?.let { Duration.between(deviceNow, it) } ?: Duration.ZERO
        val deviceClosesAt = if (skew.abs() > TRUSTED_SKEW) message.closesAt.minus(skew) else message.closesAt
        InvitationClock.record(message.invitationId, if (skew.abs() > TRUSTED_SKEW) skew else Duration.ZERO)
        val state = CountdownState.at(deviceClosesAt, deviceNow)
        if (state !is CountdownState.Open) {
            cancel(context, message.groupId)
            return false
        }
        // Quiet hours are judged on the server's clock, like the window itself.
        val quiet = QuietHoursSource.current.current()?.let { (hours, zone) -> hours.isQuietAt(deviceNow.plus(skew), zone) } ?: false

        val builder = NotificationCompat.Builder(context, channel.id)
            .setSmallIcon(icon)
            .setContentTitle(message.title)
            .setContentText(message.body)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            // Dismissible (not ongoing) and removed on tap: an invitation, not an obligation.
            .setOngoing(false)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(true)
            .setWhen(deviceClosesAt.toEpochMilli())
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setTimeoutAfter(state.remaining.toMillis())
            .setContentIntent(DeepLinkIntents.pendingIntent(context, message.link))
            .setSilent(quiet)
            // No tint (system default, RC-17); never colorized; never a promoted Live Update (C-11).
            .setColorized(false)
        InvitationAppearance.accentColor?.let(builder::setColor)
        NotificationManagerCompat.from(context).notifyChecked(context, tag(message.groupId), ID, builder)
        return true
    }

    fun cancel(context: Context, groupId: String) {
        NotificationManagerCompat.from(context).cancel(tag(groupId), ID)
    }
}

/**
 * The server-clock offset seen when an invitation's push arrived (its `sent_at` vs this device),
 * so `daily.capture` counts down to the same moment as the notification's chronometer. Process
 * memory only; without an entry the device clock is used.
 */
object InvitationClock {
    private val offsets = java.util.concurrent.ConcurrentHashMap<String, Duration>()

    fun record(invitationId: String, offset: Duration) {
        offsets[invitationId] = offset
    }

    /** Server time − device time for [invitationId], or null when unknown. */
    fun offset(invitationId: String): Duration? = offsets[invitationId]
}

/** Android 16+ promoted ongoing notifications (Live Updates), which the person can turn off per app. */
object PromotedNotifications {
    fun isAllowed(context: Context): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.BAKLAVA &&
            context.getSystemService(NotificationManager::class.java).canPostPromotedNotifications()

    /** Opens the system screen where the person can allow them; null before Android 16. */
    fun settingsIntent(context: Context): android.content.Intent? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.BAKLAVA) {
            android.content.Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_PROMOTION_SETTINGS)
                .putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, context.packageName)
        } else {
            null
        }
}

/** Alerts (surface `notifications.push`): text comes rendered from the server. */
object AlertNotifier {
    private const val ID_BASE = 100

    fun show(context: Context, alert: PushMessage.Alert, now: Instant = Instant.now()): Boolean {
        val channel = AppChannel.forAlert(alert.kind)
        if (!Posting.canPost(context, channel)) return false
        val icon = Posting.smallIcon(context) ?: return false
        val quiet = QuietHoursSource.current.current()?.let { (hours, zone) -> hours.isQuietAt(now, zone) } ?: false
        val intent = alert.link?.let { DeepLinkIntents.pendingIntent(context, it) } ?: launchIntent(context)
        val builder = NotificationCompat.Builder(context, channel.id)
            .setSmallIcon(icon)
            .setContentTitle(alert.title)
            .setContentText(alert.body)
            .setCategory(category(alert.kind))
            .setAutoCancel(true)
            .setContentIntent(intent)
            // During quiet hours the alert still arrives (nothing gets lost), just silently.
            .setSilent(quiet)
            .applyAppearance()
        alert.groupId?.let { builder.setGroup("group:$it") }
        val tag = alert.collapseKey ?: alert.link?.let(AppLinkConfig.codec::format) ?: "alert:${alert.kind}:${now.toEpochMilli()}"
        NotificationManagerCompat.from(context).notifyChecked(context, tag, ID_BASE + alert.kind.ordinal, builder)
        return true
    }

    private fun category(kind: PushMessage.AlertKind) = when (kind) {
        PushMessage.AlertKind.NewPost, PushMessage.AlertKind.Reaction, PushMessage.AlertKind.Reply -> NotificationCompat.CATEGORY_SOCIAL
        else -> NotificationCompat.CATEGORY_RECOMMENDATION
    }

    private fun launchIntent(context: Context) = context.packageManager.getLaunchIntentForPackage(context.packageName)?.let {
        android.app.PendingIntent.getActivity(context, 0, it, android.app.PendingIntent.FLAG_IMMUTABLE)
    }
}

private fun NotificationManagerCompat.notifyChecked(context: Context, tag: String, id: Int, builder: NotificationCompat.Builder) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
        ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
    ) return
    notify(tag, id, builder.build())
}
