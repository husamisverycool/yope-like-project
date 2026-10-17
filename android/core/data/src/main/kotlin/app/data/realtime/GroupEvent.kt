package app.data.realtime

import app.data.model.ChatTyping
import app.data.model.Message
import app.data.model.MessageReaction
import app.data.model.Post
import app.data.model.Reaction
import app.data.model.SelfieReaction

/**
 * What happens in one group, live (docs/API.md §8). Inserts and updates come from Postgres changes
 * (RLS-filtered); deletions come from the private `group:<id>` broadcast topic.
 */
sealed interface GroupEvent {
    val groupId: String

    /**
     * The subscription is live. [resumed] = it was live before and dropped (socket reconnect):
     * refetch the visible page, events may have been missed (§8.3).
     */
    data class Subscribed(override val groupId: String, val stream: Stream, val resumed: Boolean) : GroupEvent

    /** The subscription could not be established (e.g. no longer a member); retried with backoff. */
    data class Unavailable(override val groupId: String, val stream: Stream) : GroupEvent

    data class MessageInserted(override val groupId: String, val message: Message) : GroupEvent
    /** A message was edited (`edit_message`, migration 0047) or a reply lost its target (`reply_to_*` set to null after a deletion). */
    data class MessageUpdated(override val groupId: String, val message: Message) : GroupEvent
    data class PostInserted(override val groupId: String, val post: Post) : GroupEvent
    data class PostUpdated(override val groupId: String, val post: Post) : GroupEvent
    data class ReactionAdded(override val groupId: String, val reaction: Reaction) : GroupEvent
    /** A selfie reaction was added or replaced (§14.1; removals arrive as [ReactionsChanged]). */
    data class SelfieReactionChanged(override val groupId: String, val selfie: SelfieReaction) : GroupEvent

    /**
     * Someone set or replaced their reaction on a text / voice message (`message_reactions` inserts and updates, migration
     * 0047); removals arrive as [MessageReactionsChanged].
     */
    data class MessageReactionChanged(override val groupId: String, val reaction: MessageReaction) : GroupEvent
    /** Refetch that message's reactions (`message_reactions_changed`: a reaction was removed; the payload names no one). */
    data class MessageReactionsChanged(override val groupId: String, val messageId: String) : GroupEvent
    /** Someone started or stopped typing (`chat_typing` inserts and updates, migration 0048): typing while `until` is ahead. */
    data class TypingChanged(override val groupId: String, val typing: ChatTyping) : GroupEvent

    /** Remove the post and its chat photo message; drop it from walls, recaps, albums. */
    data class PostDeleted(override val groupId: String, val postId: String, val mediaId: String?) : GroupEvent
    data class MessageDeleted(override val groupId: String, val messageId: String) : GroupEvent
    /** Refetch that post's reactions and selfie reactions (no user or emoji in the payload, so a block is never revealed). */
    data class ReactionsChanged(override val groupId: String, val postId: String) : GroupEvent

    /**
     * A 9 AM photo started or stopped developing in the group (`create_overnight_post`, a reveal): refetch
     * `group_developing` (§14.3; no user, no photo and no number in the payload).
     */
    data class DevelopingChanged(override val groupId: String) : GroupEvent

    /** The two subscriptions per group. */
    enum class Stream {
        /** Postgres changes on `messages`, `posts`, `reactions`, `selfie_reactions`, `message_reactions`, `chat_typing` filtered by `group_id`. */
        Changes,
        /** The private broadcast topic `group:<id>` (deletions, reaction and developing changes). */
        Deletions,
    }
}
