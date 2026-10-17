// Surface: notifications.push "Actions" — reply, react and mute from an alert. References: Apple Messages reply from the
// Lock Screen (https://support.apple.com/104982), Android direct reply
// (https://developer.android.com/develop/ui/views/notifications/build-notification), Retro's notification actions
// "Reply" / "Mute This Post" (`MessageReplyNotificationReceiver`, design/research/retro-package-copy-motion.md §6.2).
// Spec: design/surfaces/notifications.push.md. The notification and its action row are drawn by the system (PLATFORM).
package app.push

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.RemoteInput
import androidx.core.graphics.drawable.IconCompat
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.links.AppLinkConfig
import app.links.DeepLinkIntents
import app.model.DeepLinkCodec
import app.model.PushMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout

/** One action on an alert. Same rule as iOS (`AppModels` `NotificationAction`). */
enum class AlertAction(val wire: String) {
    /** Direct reply (RemoteInput) → `send_message` as a reply to the alert's message or photo. */
    Reply("reply"),

    /** The first quick reaction (`chat.reactions.layout.quickReactions`) → `react(p_post_id, emoji)`. */
    React("react"),

    /** `set_group_muted(p_group_id, true)` (Retro's "Mute This Post", adapted to groups). */
    MuteGroup("mute_group");

    companion object {
        fun fromWire(value: String?): AlertAction? = entries.firstOrNull { it.wire == value }
    }
}

/** Performs the actions with the signed-in session. Set by the data layer (`DataGraph`); null = no backend. */
interface AlertActionPerformer {
    suspend fun reply(groupId: String, body: String, replyToPostId: String?, replyToMessageId: String?)
    suspend fun react(postId: String, emoji: String)
    suspend fun muteGroup(groupId: String)
}

/** What one tap on an action asks for, read back from the action's broadcast intent. */
data class AlertActionRequest(
    val action: AlertAction,
    val groupId: String,
    val postId: String?,
    val messageId: String?,
    /** The typed reply ([AlertAction.Reply] only). */
    val text: String?,
    /** The alert's notification tag and id (cancelled on success, replaced by the failure notice otherwise). */
    val tag: String,
    val notificationId: Int,
    val channelId: String,
    val title: String,
    /** The alert's destination as a link (the failure notice opens it). */
    val link: String?,
)

/**
 * Actions on alerts (design/surfaces/notifications.push.md "Actions"): a new photo offers Reply, the first quick reaction
 * and "Mute This Group"; a reply or a reaction alert offers Reply and "Mute This Group". The daily invitation, widget
 * messages, recaps, birthdays, plans and memories offer none. An action only answers what the alert already shows (the
 * worker sends no alert from or about a person with a block). Each is a broadcast to [AlertActionReceiver]; every one
 * asks for the unlocked device (`setAuthenticationRequired`, Android 12+): it speaks for the person.
 */
object AlertActions {
    const val KEY_REPLY = "app.push.reply"
    internal const val EXTRA_ACTION = "app.push.action"
    internal const val EXTRA_GROUP = "app.push.action.group"
    internal const val EXTRA_POST = "app.push.action.post"
    internal const val EXTRA_MESSAGE = "app.push.action.message"
    internal const val EXTRA_TAG = "app.push.action.tag"
    internal const val EXTRA_ID = "app.push.action.id"
    internal const val EXTRA_CHANNEL = "app.push.action.channel"
    internal const val EXTRA_TITLE = "app.push.action.title"
    internal const val EXTRA_LINK = "app.push.action.link"
    private const val URI_SCHEME = "app-alert-action"

    /**
     * The receiver's work budget: `goAsync` lets a broadcast finish in the background for about 10 seconds ("Broadcasts
     * overview": "the system … kills the process if the receiver takes too long"); one RPC fits well inside.
     */
    private const val BUDGET_MS = 8_000L

    @Volatile var performer: AlertActionPerformer? = null

    internal val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /** The reaction action's emoji: the first of `chat.reactions.layout.quickReactions` ("🔥 then 💖, …"). */
    val quickReaction: String? by lazy { firstEmoji(Tokens.Layouts.ChatReactionsLayoutQuickReactions.emoji) }

    /** The first word of [text] when it is an emoji (no letter or digit, some non-ASCII character). */
    fun firstEmoji(text: String): String? =
        text.trim().substringBefore(' ').takeIf { word -> word.isNotEmpty() && word.none(Char::isLetterOrDigit) && word.any { it.code > 0x7F } }

    /** The actions [alert] offers, in order. */
    fun forAlert(alert: PushMessage.Alert): List<AlertAction> {
        if (alert.groupId == null) return emptyList()
        val canReply = alert.postId != null || alert.messageId != null
        return when (alert.kind) {
            // A new photo (and the overnight reveal, also `new_post`).
            PushMessage.AlertKind.NewPost, PushMessage.AlertKind.PhotosDeveloped -> listOfNotNull(
                AlertAction.Reply.takeIf { canReply },
                AlertAction.React.takeIf { alert.postId != null && quickReaction != null },
                AlertAction.MuteGroup,
            )
            // A reply names a chat message or a photo; a reaction names your own photo.
            PushMessage.AlertKind.Reply, PushMessage.AlertKind.Reaction -> listOfNotNull(AlertAction.Reply.takeIf { canReply }, AlertAction.MuteGroup)
            PushMessage.AlertKind.RecapReady, PushMessage.AlertKind.BirthdayRequest, PushMessage.AlertKind.TributeForYou,
            PushMessage.AlertKind.YearStory, PushMessage.AlertKind.Plan, PushMessage.AlertKind.Memory,
            -> emptyList()
        }
    }

    /** Adds [alert]'s actions to the notification posted as [tag] / [id] on [channelId]. */
    internal fun addTo(context: Context, builder: NotificationCompat.Builder, alert: PushMessage.Alert, tag: String, id: Int, channelId: String) {
        val groupId = alert.groupId ?: return
        for (action in forAlert(alert)) {
            val intent = Intent(context, AlertActionReceiver::class.java)
                .setAction("app.push.action.${action.wire}")
                // A distinct data URI per notification and action, so each keeps its own PendingIntent and extras.
                .setData(Uri.Builder().scheme(URI_SCHEME).authority(action.wire).appendQueryParameter("tag", tag).appendQueryParameter("id", id.toString()).build())
                .putExtra(EXTRA_ACTION, action.wire)
                .putExtra(EXTRA_GROUP, groupId)
                .putExtra(EXTRA_POST, alert.postId)
                .putExtra(EXTRA_MESSAGE, alert.messageId)
                .putExtra(EXTRA_TAG, tag)
                .putExtra(EXTRA_ID, id)
                .putExtra(EXTRA_CHANNEL, channelId)
                .putExtra(EXTRA_TITLE, alert.title)
                .putExtra(EXTRA_LINK, alert.link?.let(AppLinkConfig.codec::format))
            // RemoteInput fills the intent in, so the reply's PendingIntent must be mutable (explicit intent: allowed on 14+).
            val mutability = if (action == AlertAction.Reply && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else if (action == AlertAction.Reply) {
                0
            } else {
                PendingIntent.FLAG_IMMUTABLE
            }
            val pending = PendingIntent.getBroadcast(context, "$tag:$id:${action.wire}".hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or mutability)
            builder.addAction(build(context, action, pending))
        }
    }

    private fun build(context: Context, action: AlertAction, pending: PendingIntent): NotificationCompat.Action = when (action) {
        AlertAction.Reply -> NotificationCompat.Action.Builder(null as IconCompat?, context.getString(R.string.notifications_push_action_reply), pending)
            .addRemoteInput(RemoteInput.Builder(KEY_REPLY).setLabel(context.getString(R.string.chat_composer_placeholderreply)).build())
            .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_REPLY)
            .setAllowGeneratedReplies(false)
            .setShowsUserInterface(false)
            .setAuthenticationRequired(true)
            .build()
        AlertAction.React -> NotificationCompat.Action.Builder(null as IconCompat?, quickReaction, pending)
            .setShowsUserInterface(false)
            .setAuthenticationRequired(true)
            .build()
        AlertAction.MuteGroup -> NotificationCompat.Action.Builder(null as IconCompat?, context.getString(R.string.notifications_push_action_mute), pending)
            .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_MUTE)
            .setShowsUserInterface(false)
            .setAuthenticationRequired(true)
            .build()
    }

    /** The request an action's broadcast carries; null when it is not one of ours or lacks its group. */
    fun request(intent: Intent): AlertActionRequest? {
        val action = AlertAction.fromWire(intent.getStringExtra(EXTRA_ACTION)) ?: return null
        val groupId = intent.getStringExtra(EXTRA_GROUP)?.takeIf(DeepLinkCodec::isId) ?: return null
        val text = if (action == AlertAction.Reply) RemoteInput.getResultsFromIntent(intent)?.getCharSequence(KEY_REPLY)?.toString() else null
        return AlertActionRequest(
            action = action,
            groupId = groupId,
            postId = intent.getStringExtra(EXTRA_POST)?.takeIf(DeepLinkCodec::isId),
            messageId = intent.getStringExtra(EXTRA_MESSAGE)?.takeIf(DeepLinkCodec::isId),
            text = text,
            tag = intent.getStringExtra(EXTRA_TAG) ?: return null,
            notificationId = intent.getIntExtra(EXTRA_ID, 0),
            channelId = intent.getStringExtra(EXTRA_CHANNEL) ?: return null,
            title = intent.getStringExtra(EXTRA_TITLE).orEmpty(),
            link = intent.getStringExtra(EXTRA_LINK),
        )
    }

    /**
     * Runs [request] with the [performer] inside the receiver's budget. Success removes the alert (the reply is sent, the
     * reaction or mute is done); a failure — no session, offline, refused, a blank reply — replaces it with the failure
     * notice, which keeps the alert's destination. Returns whether it succeeded.
     */
    suspend fun perform(context: Context, request: AlertActionRequest): Boolean {
        val performer = performer
        val body = request.text?.trim()
        val ok = performer != null && runCatching {
            withTimeout(BUDGET_MS) {
                when (request.action) {
                    AlertAction.Reply -> {
                        val reply = requireNotNull(body?.takeIf { it.isNotEmpty() })
                        // A text reply alert names the message; otherwise the photo.
                        val toMessage = request.messageId
                        val toPost = if (toMessage == null) requireNotNull(request.postId) else null
                        performer.reply(request.groupId, reply, toPost, toMessage)
                    }
                    AlertAction.React -> performer.react(requireNotNull(request.postId), requireNotNull(quickReaction))
                    AlertAction.MuteGroup -> performer.muteGroup(request.groupId)
                }
            }
        }.isSuccess
        if (ok) NotificationManagerCompat.from(context).cancel(request.tag, request.notificationId) else showFailure(context, request)
        return ok
    }

    /**
     * The platform's "couldn't send" in the alert's place (same tag and id, so the reply field's progress ends): the
     * alert's title, the failure line — reply `chat.thread.sendFailed` ("Couldn't send. Tap to retry"), reaction
     * `chat.reactions.error`, mute `settings.notifications.error` — and a tap that opens what the alert opened. No
     * actions; it does not alert again.
     */
    internal fun showFailure(context: Context, request: AlertActionRequest) {
        val icon = Posting.smallIcon(context) ?: return
        val text = context.getString(
            when (request.action) {
                AlertAction.Reply -> R.string.chat_thread_sendfailed
                AlertAction.React -> R.string.chat_reactions_error
                AlertAction.MuteGroup -> R.string.settings_notifications_error
            },
        )
        val link = AppLinkConfig.codec.parse(request.link)
        val builder = NotificationCompat.Builder(context, request.channelId)
            .setSmallIcon(icon)
            .setContentTitle(request.title)
            .setContentText(text)
            .setCategory(NotificationCompat.CATEGORY_ERROR)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .addExtras(Bundle().apply {
                request.postId?.let { putString(DeliveredAlerts.EXTRA_POST_ID, it) }
                request.messageId?.let { putString(DeliveredAlerts.EXTRA_MESSAGE_ID, it) }
            })
            .applyAppearance()
        link?.let { DeepLinkIntents.pendingIntent(context, it) }?.let(builder::setContentIntent)
        builder.setGroup("group:${request.groupId}")
        NotificationManagerCompat.from(context).notifyChecked(context, request.tag, request.notificationId, builder)
    }
}

/** Receives the alert actions' broadcasts and runs them off the main thread (`goAsync`, [AlertActions.perform]). */
class AlertActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val request = AlertActions.request(intent) ?: return
        val app = context.applicationContext
        val pending = goAsync()
        AlertActions.scope.launch {
            try {
                AlertActions.perform(app, request)
            } finally {
                pending.finish()
            }
        }
    }
}
