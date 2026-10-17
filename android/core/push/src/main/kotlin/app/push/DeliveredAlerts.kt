package app.push

import android.app.NotificationManager
import android.content.Context
import android.os.Bundle
import android.service.notification.StatusBarNotification
import app.model.DeepLink
import app.model.DeepLinkCodec
import app.model.PushKeys
import app.model.PushMessage
import app.model.WidgetSnapshot
import app.widget.WidgetBinding
import app.widget.WidgetFileStore

/**
 * The alerts of deleted photos and messages leave the notification shade (directive Part 6, "Deleting a photo removes it
 * everywhere"; iOS `NotificationWithdrawal`). Each alert carries the post / chat message it shows in its extras
 * ([AlertNotifier]); it is cancelled when the app learns of the deletion: the group's Realtime deletion broadcast while
 * the app runs (SessionGlue), the check of every shown alert against the server when the app starts or comes to the
 * front (MainActivity), and the FCM widget message the worker sends when a deletion changes the widget
 * ([AppMessagingService]). Only alerts this app posted are read (`NotificationManager.getActiveNotifications`).
 */
object DeliveredAlerts {
    const val EXTRA_POST_ID = "app.push.post_id"
    const val EXTRA_MESSAGE_ID = "app.push.message_id"

    /**
     * Which of these post ids the signed-in person can still see; null when that cannot be told (signed out, offline).
     * Set by the data layer (`DataGraph`).
     */
    @Volatile var existingPosts: (suspend (Set<String>) -> Set<String>?)? = null

    /** The ids [alert] shows: its link's, else the payload's `post_id` / `message_id`. */
    fun extras(alert: PushMessage.Alert, payload: Map<String, String> = emptyMap()): Bundle {
        val post = (alert.link as? DeepLink.Post)?.postId ?: payload[PushKeys.POST_ID]?.takeIf(DeepLinkCodec::isId)
        val message = (alert.link as? DeepLink.ChatMessage)?.messageId ?: payload[PushKeys.MESSAGE_ID]?.takeIf(DeepLinkCodec::isId)
        return Bundle().apply {
            post?.let { putString(EXTRA_POST_ID, it) }
            message?.let { putString(EXTRA_MESSAGE_ID, it) }
        }
    }

    /** The posts the shown alerts name. */
    fun shownPostIds(context: Context): Set<String> =
        active(context).mapNotNull { it.notification.extras.getString(EXTRA_POST_ID) }.toSet()

    /** Cancels every shown alert that names one of [posts] or [messages]; returns how many. */
    fun withdraw(context: Context, posts: Set<String>, messages: Set<String>): Int {
        if (posts.isEmpty() && messages.isEmpty()) return 0
        val manager = context.getSystemService(NotificationManager::class.java) ?: return 0
        var withdrawn = 0
        for (shown in active(context)) {
            val extras = shown.notification.extras
            val named = extras.getString(EXTRA_POST_ID)?.let(posts::contains) == true ||
                extras.getString(EXTRA_MESSAGE_ID)?.let(messages::contains) == true
            if (named) {
                manager.cancel(shown.tag, shown.id)
                withdrawn++
            }
        }
        return withdrawn
    }

    /** Checks the shown alerts' posts against the server ([existingPosts]) and cancels the ones that are gone. */
    suspend fun reconcile(context: Context): Int {
        val lookup = existingPosts ?: return 0
        val shown = shownPostIds(context)
        if (shown.isEmpty()) return 0
        val existing = lookup(shown) ?: return 0
        return withdraw(context, shown - existing, emptySet())
    }

    private fun active(context: Context): List<StatusBarNotification> =
        runCatching { context.getSystemService(NotificationManager::class.java)?.activeNotifications?.toList() }.getOrNull().orEmpty()
}

/**
 * A widget showing a deleted photo. The widget store keeps the newest item ([WidgetSnapshot.supersedes]), so the older
 * photo the worker sends after a deletion would be refused while the deleted one stays: when a widget message arrives
 * (and when the app starts, `WidgetPrefetch.refreshPlaced`), a shown photo the server no longer returns is dropped
 * first ([DeliveredAlerts.existingPosts]). Collages are not looked up here (their deletion recomposes them).
 */
object ShownWidgetPhoto {
    /** Returns whether [groupId]'s photo was dropped. */
    suspend fun dropIfDeleted(context: Context, groupId: String, store: WidgetFileStore = WidgetFileStore.default(context)): Boolean {
        val shown = store.read(groupId) ?: return false
        if (shown.kind != WidgetSnapshot.Kind.Photo) return false
        val postId = shown.sourceId ?: return false
        val lookup = DeliveredAlerts.existingPosts ?: return false
        val existing = lookup(setOf(postId)) ?: return false
        if (postId in existing) return false
        store.remove(groupId)
        runCatching { WidgetBinding.refresh(context, groupId) }
        return true
    }
}
