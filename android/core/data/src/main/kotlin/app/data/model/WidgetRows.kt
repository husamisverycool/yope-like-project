@file:UseSerializers(InstantSerializer::class, LocalDateSerializer::class)

package app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.UseSerializers
import java.time.Instant
import java.time.LocalDate

/** One row of `widget_people()` (migration 0036): a person the friend widget's picker lists (shares a group, no block). */
@Serializable
data class WidgetPerson(
    @SerialName("user_id") val userId: String,
    @SerialName("display_name") val displayName: String,
    @SerialName("avatar_path") val avatarPath: String? = null,
)

/**
 * One row of `newest_photos_of(p_user_id, p_limit)` (migration 0036): a photo of that person the caller can see, newest
 * first — posted by them ([via] `author`) or one they tagged themselves in ([via] `tag`), never found by face.
 * [widgetPath] is null while the widget rendition is not made yet.
 */
@Serializable
data class PersonPhoto(
    @SerialName("post_id") val postId: String,
    @SerialName("media_id") val mediaId: String,
    @SerialName("group_id") val groupId: String,
    @SerialName("group_name") val groupName: String,
    @SerialName("author_id") val authorId: String,
    @SerialName("author_name") val authorName: String,
    @SerialName("author_avatar_path") val authorAvatarPath: String? = null,
    @SerialName("widget_path") val widgetPath: String? = null,
    val caption: String? = null,
    @SerialName("visible_at") val visibleAt: Instant,
    val via: String,
) {
    companion object {
        const val VIA_AUTHOR = "author"
        const val VIA_TAG = "tag"
    }
}

/**
 * One row of `my_memories(p_from, p_days, p_time_zone)` (migrations 0036, 0038): the caller's own memory for [day] — the
 * newest photo they posted or tagged themselves in, taken on that month and day in an earlier year. Hidden memories are
 * left out by the server (0038); a day without a memory has no row.
 */
@Serializable
data class DayMemory(
    val day: LocalDate,
    @SerialName("post_id") val postId: String,
    @SerialName("media_id") val mediaId: String,
    @SerialName("group_id") val groupId: String,
    @SerialName("group_name") val groupName: String,
    @SerialName("author_id") val authorId: String,
    @SerialName("author_name") val authorName: String,
    @SerialName("widget_path") val widgetPath: String? = null,
    @SerialName("taken_at") val takenAt: Instant,
    @SerialName("years_ago") val yearsAgo: Int,
)
