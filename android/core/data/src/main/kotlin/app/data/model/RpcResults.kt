@file:UseSerializers(InstantSerializer::class, LocalDateSerializer::class)

package app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.intOrNull
import java.time.Instant
import java.time.LocalDate

/** `invite_preview(p_token)` (anon): all a non-member may learn before joining. */
@Serializable
data class InvitePreview(
    @SerialName("group_name") val groupName: String,
    @SerialName("group_kind") val groupKind: GroupKind,
    @SerialName("cover_path") val coverPath: String?,
    @SerialName("inviter_first_name") val inviterFirstName: String?,
    /** In joining order. */
    val members: List<InvitePreviewMember>,
)

@Serializable
data class InvitePreviewMember(
    @SerialName("first_name") val firstName: String?,
    @SerialName("avatar_path") val avatarPath: String?,
)

/** One row of `wall(p_user_id, p_before, p_limit)`. */
@Serializable
data class WallItem(
    @SerialName("item_kind") val itemKind: WallItemKind,
    /** `post`: the first post of that photo in the groups you share. */
    @SerialName("post_id") val postId: String?,
    @SerialName("media_id") val mediaId: String?,
    @SerialName("collage_id") val collageId: String?,
    @SerialName("group_ids") val groupIds: List<String>,
    @SerialName("created_at") val createdAt: Instant,
)

/** One row of `group_history_weeks`: a week (group time zone) with posts, ids in chronological order. */
@Serializable
data class HistoryWeek(
    @SerialName("week_start") val weekStart: LocalDate,
    @SerialName("post_ids") val postIds: List<String>,
    /** The week's same-moment collages, oldest first (migration 0033). Last, so positional calls keep working. */
    val collages: List<GroupCollage> = emptyList(),
)

/**
 * A ready same-moment collage placed on its group-local day (`group_collages`, `group_history_weeks.collages`, migration
 * 0033): the group's photo of the day in its history.
 */
@Serializable
data class GroupCollage(
    @SerialName("collage_id") val collageId: String,
    @SerialName("invitation_id") val invitationId: String,
    /** The invitation's group-local day: the day tile it belongs on. */
    @SerialName("local_date") val localDate: LocalDate,
    /** Page 1 (`display-1.jpg`). */
    @SerialName("image_path") val imagePath: String? = null,
    /** The widget image (smaller; day tiles). */
    @SerialName("widget_path") val widgetPath: String? = null,
    @SerialName("share_path") val sharePath: String? = null,
    @SerialName("composed_at") val composedAt: Instant? = null,
) {
    /** The tile image: the widget rendition, else page 1. */
    val tilePath: String? get() = widgetPath ?: imagePath
}

/** One row of `on_this_day`. */
@Serializable
data class OnThisDayItem(
    @SerialName("post_id") val postId: String,
    @SerialName("media_id") val mediaId: String,
    @SerialName("author_id") val authorId: String,
    @SerialName("created_at") val createdAt: Instant,
    @SerialName("years_ago") val yearsAgo: Int,
)

/** One row of `create_overnight_post` (§14.3): a group the photo develops in, and when. */
@Serializable
data class DevelopingPost(
    @SerialName("group_id") val groupId: String,
    @SerialName("develops_at") val developsAt: Instant,
)

/** `my_developing()` / `group_developing(p_group_id)` (§14.3): whether photos are developing and the next reveal; never a number. */
@Serializable
data class Developing(
    val developing: Boolean,
    @SerialName("reveal_at") val revealAt: Instant?,
)

/** The public tunables (§5.25), typed. Null = not configured (the dependent feature fails closed). */
data class PublicAppConfig(
    val invitationWindowSeconds: Int?,
    val maxGroupMembers: Int?,
    val weekStartIsodow: Int?,
    val freeHistoryDays: Int?,
    val minAgeYears: Int?,
) {
    companion object {
        fun from(rows: List<PublicAppConfigRow>): PublicAppConfig {
            val byKey = rows.associate { it.key to (it.value as? JsonPrimitive)?.intOrNull }
            return PublicAppConfig(
                invitationWindowSeconds = byKey["invitation_window_seconds"],
                maxGroupMembers = byKey["max_group_members"],
                weekStartIsodow = byKey["week_start_isodow"],
                freeHistoryDays = byKey["free_history_days"],
                minAgeYears = byKey["min_age_years"],
            )
        }
    }
}
