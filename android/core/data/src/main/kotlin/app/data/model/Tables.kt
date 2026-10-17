@file:UseSerializers(InstantSerializer::class, LocalDateSerializer::class, LocalTimeSerializer::class)

package app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import kotlinx.serialization.json.JsonElement
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime

/*
 * One class per client-readable table / view of docs/API.md §5, with exactly the table's columns in
 * table order (`?` columns are nullable). An RPC that returns a table row returns the same shape.
 * Ids are lowercase UUID strings. `SchemaConformanceIntegrationTest` compares every class here with
 * the live database (columns, nullability, enum values).
 */

/** §5.1 `profiles` */
@Serializable
data class Profile(
    val id: String,
    @SerialName("display_name") val displayName: String,
    @SerialName("avatar_path") val avatarPath: String?,
    @SerialName("created_at") val createdAt: Instant,
    @SerialName("updated_at") val updatedAt: Instant,
) {
    /** The first word of the display name (what the invite preview shows); null when unset. */
    val firstName: String? get() = displayName.trim().split(Regex("\\s+")).firstOrNull()?.takeIf { it.isNotEmpty() }
}

/** §5.2 `profile_private` (own row only). */
@Serializable
data class ProfilePrivate(
    @SerialName("user_id") val userId: String,
    val birthday: LocalDate?,
    @SerialName("birthday_opt_in") val birthdayOptIn: Boolean,
    @SerialName("age_confirmed_at") val ageConfirmedAt: Instant?,
    @SerialName("updated_at") val updatedAt: Instant,
)

/** §5.3 `groups` */
@Serializable
data class Group(
    val id: String,
    val name: String,
    val kind: GroupKind,
    @SerialName("cover_path") val coverPath: String?,
    @SerialName("time_zone") val timeZone: String,
    @SerialName("waking_start") val wakingStart: LocalTime?,
    @SerialName("waking_end") val wakingEnd: LocalTime?,
    @SerialName("invitation_paused") val invitationPaused: Boolean,
    @SerialName("created_by") val createdBy: String?,
    @SerialName("created_at") val createdAt: Instant,
    @SerialName("updated_at") val updatedAt: Instant,
    /** §14.4 the weekly question is on for the group (`set_group_weekly_question`, admins; default off). Last, so positional calls keep working. */
    @SerialName("weekly_question") val weeklyQuestion: Boolean = false,
    /** Migration 0039: the photo `set_group_cover_from_post` made the cover (its rendition is `cover_path`); null for an uploaded cover. */
    @SerialName("cover_post_id") val coverPostId: String? = null,
)

/** §5.4 `group_members` */
@Serializable
data class GroupMember(
    @SerialName("group_id") val groupId: String,
    @SerialName("user_id") val userId: String,
    val role: MemberRole,
    val muted: Boolean,
    @SerialName("joined_at") val joinedAt: Instant,
)

/** §5.5 `group_invites` */
@Serializable
data class GroupInvite(
    val id: String,
    @SerialName("group_id") val groupId: String,
    val token: String,
    @SerialName("created_by") val createdBy: String,
    @SerialName("created_at") val createdAt: Instant,
    /** Null = the link never expires (owner decision 27: `invite_ttl_seconds` is NULL); it works until revoked. */
    @SerialName("expires_at") val expiresAt: Instant?,
    @SerialName("revoked_at") val revokedAt: Instant?,
) {
    fun isUsable(now: Instant): Boolean = revokedAt == null && (expiresAt == null || expiresAt.isAfter(now))
}

/** §5.6 `blocks` (rows where you are the blocker). */
@Serializable
data class Block(
    @SerialName("blocker_id") val blockerId: String,
    @SerialName("blocked_id") val blockedId: String,
    @SerialName("created_at") val createdAt: Instant,
)

/** §5.7 `media` */
@Serializable
data class Media(
    val id: String,
    @SerialName("owner_id") val ownerId: String,
    val kind: MediaKind,
    @SerialName("original_path") val originalPath: String,
    @SerialName("front_original_path") val frontOriginalPath: String?,
    @SerialName("motion_path") val motionPath: String?,
    @SerialName("display_path") val displayPath: String?,
    @SerialName("thumb_path") val thumbPath: String?,
    @SerialName("widget_path") val widgetPath: String?,
    @SerialName("front_display_path") val frontDisplayPath: String?,
    @SerialName("front_thumb_path") val frontThumbPath: String?,
    val width: Int?,
    val height: Int?,
    @SerialName("front_width") val frontWidth: Int?,
    @SerialName("front_height") val frontHeight: Int?,
    @SerialName("duration_ms") val durationMs: Int?,
    @SerialName("renditions_ready_at") val renditionsReadyAt: Instant?,
    @SerialName("created_at") val createdAt: Instant,
    /** Migration 0050: the day a library photo was taken (date only, from the library); null for camera photos. */
    @SerialName("taken_on") val takenOn: LocalDate? = null,
    /** Migration 0051: the photos of one selection share it (one post of several photos); null for a single photo. */
    @SerialName("batch_id") val batchId: String? = null,
) {
    /**
     * §7 "Which image to show": the rendition once ready, the original until then. A video's original is the movie: its
     * poster renditions are used as soon as the worker wrote them (before the transcode finishes).
     */
    fun imagePath(use: Rendition): String = if (renditionsReadyAt == null && kind != MediaKind.Video) originalPath else when (use) {
        Rendition.Display -> displayPath
        Rendition.Thumb -> thumbPath
        Rendition.Widget -> widgetPath
    } ?: originalPath

    /** The front image of a dual capture, rendition first; null when there is none. */
    fun frontImagePath(use: Rendition): String? {
        val original = frontOriginalPath ?: return null
        if (renditionsReadyAt == null) return original
        return when (use) {
            Rendition.Display -> frontDisplayPath
            Rendition.Thumb, Rendition.Widget -> frontThumbPath
        } ?: original
    }

    enum class Rendition { Display, Thumb, Widget }
}

/** §5.8 `posts` (one row per group a photo was sent to). */
@Serializable
data class Post(
    val id: String,
    @SerialName("media_id") val mediaId: String,
    @SerialName("group_id") val groupId: String,
    @SerialName("author_id") val authorId: String,
    val caption: String?,
    @SerialName("voice_path") val voicePath: String?,
    @SerialName("voice_duration_ms") val voiceDurationMs: Int?,
    @SerialName("invitation_id") val invitationId: String?,
    @SerialName("in_window") val inWindow: Boolean,
    @SerialName("reply_to_post_id") val replyToPostId: String?,
    @SerialName("created_at") val createdAt: Instant,
    /** The voice note's waveform: 100 levels of 0…31 (§5.8 `voice_levels`); null when it has none. Last, so positional calls keep working. */
    @SerialName("voice_levels") val voiceLevels: List<Int>? = null,
    /** §14.3: the reveal time an overnight photo joined the group at (`created_at` stays when it was taken); null for every other post. */
    @SerialName("revealed_at") val revealedAt: Instant? = null,
    /** §14.4: the group week's question this post answers (`answer_question`); null for every other post. */
    @SerialName("question_id") val questionId: String? = null,
    /** The stored `posts.visible_at` (migration 0027); null in rows made on the device. Read [visibleAt]. Last, so positional calls keep working. */
    @SerialName("visible_at") val visibleAtColumn: Instant? = null,
    /** Migration 0047: when the author last changed the caption (`edit_caption`); null when never edited. */
    @SerialName("caption_edited_at") val captionEditedAt: Instant? = null,
    /** Migration 0050: the day the photo was taken, copied from its media; it places the post's week (visible_at). */
    @SerialName("taken_on") val takenOn: LocalDate? = null,
    /** Migration 0051: the batch (several photos posted together) this photo belongs to; show the batch together. */
    @SerialName("batch_id") val batchId: String? = null,
) {
    /**
     * When the group could first see the photo (`posts.visible_at` = `revealed_at ?: created_at`, migration 0027): the week
     * and the week-strip day a photo belongs to. An overnight photo taken on Sunday night is in Monday's week.
     */
    val visibleAt: Instant get() = revealedAt ?: createdAt
}

/** §5.9 `messages` (group chat). */
@Serializable
data class Message(
    val id: String,
    @SerialName("group_id") val groupId: String,
    @SerialName("author_id") val authorId: String,
    val kind: MessageKind,
    val body: String?,
    @SerialName("post_id") val postId: String?,
    @SerialName("voice_path") val voicePath: String?,
    @SerialName("voice_duration_ms") val voiceDurationMs: Int?,
    @SerialName("reply_to_post_id") val replyToPostId: String?,
    @SerialName("reply_to_message_id") val replyToMessageId: String?,
    @SerialName("created_at") val createdAt: Instant,
    /** A voice message's waveform: 100 levels of 0…31 (§5.9 `voice_levels`); null when it has none. Last, so positional calls keep working. */
    @SerialName("voice_levels") val voiceLevels: List<Int>? = null,
    /** Migration 0047: when the author last edited the text (`edit_message`); null when never edited ("Edited" under it). */
    @SerialName("edited_at") val editedAt: Instant? = null,
    /** Migration 0053: the preview the sender's device built for a link in the text (`set_link_preview`); null when none. */
    @SerialName("link_preview") val linkPreview: LinkPreview? = null,
)

/** `messages.link_preview` (migration 0053): built on the sender's device; recipients never contact the site. */
@Serializable
data class LinkPreview(
    val url: String,
    val title: String? = null,
    val site: String? = null,
    @SerialName("image_path") val imagePath: String? = null,
)

/** §5.10a `message_reactions` (migration 0047): one reaction per person per message, rows only, never a number. */
@Serializable
data class MessageReaction(
    @SerialName("message_id") val messageId: String,
    @SerialName("user_id") val userId: String,
    val emoji: String,
    @SerialName("group_id") val groupId: String,
    @SerialName("created_at") val createdAt: Instant,
)

/** §5.10b `chat_typing` (migration 0048): typing while [until] is in the future; never a number of people. */
@Serializable
data class ChatTyping(
    @SerialName("group_id") val groupId: String,
    @SerialName("user_id") val userId: String,
    val until: Instant,
)

/** §5.10 `reactions`: rows `(user, emoji)`, never a number. */
@Serializable
data class Reaction(
    @SerialName("post_id") val postId: String,
    @SerialName("user_id") val userId: String,
    val emoji: String,
    @SerialName("group_id") val groupId: String,
    @SerialName("created_at") val createdAt: Instant,
)

/**
 * §14.1 `selfie_reactions`: one live front-camera selfie per person per post (a new one replaces yours); the image is the
 * reacting member's own upload. Rows, never a number.
 */
@Serializable
data class SelfieReaction(
    /** The report target (`report('selfie', id, …)`); the row's key is `(post_id, user_id)`. */
    val id: String,
    @SerialName("post_id") val postId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("group_id") val groupId: String,
    @SerialName("image_path") val imagePath: String,
    @SerialName("created_at") val createdAt: Instant,
)

/** §5.11 `post_tags` ("I'm in this" self-tags). */
@Serializable
data class PostTag(
    @SerialName("post_id") val postId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("group_id") val groupId: String,
    @SerialName("created_at") val createdAt: Instant,
)

/** §5.12 `daily_invitations` (visible only after `fires_at`). */
@Serializable
data class DailyInvitation(
    val id: String,
    @SerialName("group_id") val groupId: String,
    @SerialName("local_date") val localDate: LocalDate,
    @SerialName("fires_at") val firesAt: Instant,
    @SerialName("closes_at") val closesAt: Instant,
    val status: InvitationStatus,
    @SerialName("created_at") val createdAt: Instant,
) {
    /** Open at [now]: `[fires_at, closes_at]` (use the timestamps for UI state, not [status]). */
    fun isOpen(now: Instant): Boolean = !now.isBefore(firesAt) && !now.isAfter(closesAt)
}

/** §5.13 `collages` */
@Serializable
data class Collage(
    val id: String,
    @SerialName("group_id") val groupId: String,
    @SerialName("invitation_id") val invitationId: String?,
    val option: String,
    @SerialName("post_ids") val postIds: List<String>,
    @SerialName("image_path") val imagePath: String?,
    @SerialName("widget_path") val widgetPath: String?,
    @SerialName("share_path") val sharePath: String?,
    val status: RenderStatus,
    @SerialName("composed_at") val composedAt: Instant?,
    @SerialName("created_at") val createdAt: Instant,
    /**
     * Pages of the composed collage (migration 0015; not yet in docs/API.md §5.13). Page 1 is
     * [imagePath]; page n is `display-<n>.jpg` in the same folder.
     */
    @SerialName("page_count") val pageCount: Int = 1,
) {
    /** Storage paths of every page, in order; empty while (re)composing. */
    fun pagePaths(): List<String> {
        val first = imagePath ?: return emptyList()
        val folder = first.substringBeforeLast('/', missingDelimiterValue = "")
        return listOf(first) + (2..pageCount).map { n -> if (folder.isEmpty()) "display-$n.jpg" else "$folder/display-$n.jpg" }
    }
}

/** §5.14 `weekly_recaps` */
@Serializable
data class WeeklyRecap(
    val id: String,
    @SerialName("group_id") val groupId: String,
    @SerialName("week_start") val weekStart: LocalDate,
    val items: List<String>,
    val text: String?,
    val status: RenderStatus,
    @SerialName("generated_at") val generatedAt: Instant?,
    @SerialName("edited_by") val editedBy: String?,
    @SerialName("created_at") val createdAt: Instant,
    @SerialName("updated_at") val updatedAt: Instant,
    /** The week's same-moment collages, in order (migration 0033); empty for recaps made before. */
    @SerialName("collage_ids") val collageIds: List<String> = emptyList(),
)

/** §5.15 `albums` */
@Serializable
data class Album(
    val id: String,
    @SerialName("group_id") val groupId: String,
    val name: String,
    @SerialName("created_by") val createdBy: String?,
    @SerialName("created_at") val createdAt: Instant,
    @SerialName("updated_at") val updatedAt: Instant,
)

/** §5.15 `album_items` */
@Serializable
data class AlbumItem(
    @SerialName("album_id") val albumId: String,
    @SerialName("post_id") val postId: String,
    val position: Int,
    /** Migration 0039: who added the photo (`add_to_album`; they may remove it); null once their account is gone. */
    @SerialName("added_by") val addedBy: String? = null,
    @SerialName("added_at") val addedAt: Instant = Instant.EPOCH,
)

/** §5.16 `tribute_requests` (never visible to the honoree). */
@Serializable
data class TributeRequest(
    val id: String,
    @SerialName("group_id") val groupId: String,
    @SerialName("honoree_id") val honoreeId: String,
    @SerialName("birthday_date") val birthdayDate: LocalDate,
    @SerialName("due_at") val dueAt: Instant,
    @SerialName("closed_at") val closedAt: Instant?,
    @SerialName("created_at") val createdAt: Instant,
) {
    fun isOpen(now: Instant): Boolean = closedAt == null && dueAt.isAfter(now)
}

/** §5.17 `tribute_contributions` (your own only). */
@Serializable
data class TributeContribution(
    val id: String,
    @SerialName("request_id") val requestId: String,
    @SerialName("contributor_id") val contributorId: String,
    @SerialName("post_id") val postId: String,
    val line: String,
    @SerialName("created_at") val createdAt: Instant,
    @SerialName("updated_at") val updatedAt: Instant,
)

/** §5.18 `tributes` */
@Serializable
data class Tribute(
    val id: String,
    @SerialName("request_id") val requestId: String,
    @SerialName("group_id") val groupId: String,
    @SerialName("honoree_id") val honoreeId: String,
    @SerialName("video_path") val videoPath: String?,
    @SerialName("poster_path") val posterPath: String?,
    val status: RenderStatus,
    @SerialName("rendered_at") val renderedAt: Instant?,
    @SerialName("delivered_at") val deliveredAt: Instant?,
    @SerialName("created_at") val createdAt: Instant,
)

/** §5.19 `year_stories`; [data] is owned by the worker (format not part of the contract). */
@Serializable
data class YearStory(
    val id: String,
    @SerialName("group_id") val groupId: String,
    val year: Int,
    val status: RenderStatus,
    val data: JsonElement?,
    @SerialName("post_ids") val postIds: List<String>,
    @SerialName("asset_paths") val assetPaths: List<String>,
    @SerialName("generated_at") val generatedAt: Instant?,
    @SerialName("created_at") val createdAt: Instant,
    /** When the 31 December refresh ran (migration 0031); null before. */
    @SerialName("refreshed_at") val refreshedAt: Instant? = null,
    /** When the ready push went (once; migration 0031); null before. */
    @SerialName("announced_at") val announcedAt: Instant? = null,
)

/** §5.20 `devices` */
@Serializable
data class Device(
    val id: String,
    @SerialName("user_id") val userId: String,
    val platform: DevicePlatform,
    @SerialName("push_token") val pushToken: String,
    @SerialName("push_to_start_token") val pushToStartToken: String?,
    @SerialName("created_at") val createdAt: Instant,
    @SerialName("updated_at") val updatedAt: Instant,
    /** iOS only (whether the iPhone shows Live Activities, migration 0030); null on Android. */
    @SerialName("live_activities_enabled") val liveActivitiesEnabled: Boolean? = null,
)

/** §5.21 `notification_settings` (no row = no quiet hours). */
@Serializable
data class NotificationSettings(
    @SerialName("user_id") val userId: String,
    @SerialName("quiet_start") val quietStart: LocalTime?,
    @SerialName("quiet_end") val quietEnd: LocalTime?,
    @SerialName("time_zone") val timeZone: String?,
    @SerialName("updated_at") val updatedAt: Instant,
    /** §14.3 the reveal push of overnight photos (`set_overnight_alerts`, default on). Last, so positional calls keep working. */
    val overnight: Boolean = true,
    /** Pause All (`set_notifications_paused`, migration 0037): no notification before this instant; null or past = not paused. */
    @SerialName("paused_until") val pausedUntil: Instant? = null,
    /** The opt-in memory notification (`set_memory_alerts`, migration 0049; default off) and the zone its day is counted in. */
    val memories: Boolean = false,
    @SerialName("memory_time_zone") val memoryTimeZone: String? = null,
)

/** §5.22 `entitlements` */
@Serializable
data class Entitlement(
    @SerialName("user_id") val userId: String,
    val entitlement: String,
    @SerialName("expires_at") val expiresAt: Instant?,
    val source: String,
    @SerialName("updated_at") val updatedAt: Instant,
) {
    /** Active when `expires_at` is null or in the future (§5.22). */
    fun isActive(now: Instant): Boolean = expiresAt == null || expiresAt.isAfter(now)
}

/** §5.25 view `public_app_config`: `value` is a JSON number, or null when not set. */
@Serializable
data class PublicAppConfigRow(
    val key: String,
    val value: JsonElement?,
)

/** §5.0 direct insert into `media` (the columns a client may send; `owner_id` defaults to you). */
@Serializable
data class NewMedia(
    val id: String,
    val kind: MediaKind,
    @SerialName("original_path") val originalPath: String,
    @SerialName("front_original_path") val frontOriginalPath: String? = null,
    @SerialName("motion_path") val motionPath: String? = null,
    val width: Int? = null,
    val height: Int? = null,
    @SerialName("front_width") val frontWidth: Int? = null,
    @SerialName("front_height") val frontHeight: Int? = null,
    @SerialName("duration_ms") val durationMs: Int? = null,
)
