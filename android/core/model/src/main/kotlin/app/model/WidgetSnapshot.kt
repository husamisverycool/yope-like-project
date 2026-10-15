package app.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.time.Instant

/**
 * What one group's home-screen widget shows: the newest photo, or the day's collage after a
 * daily invitation. File names are relative to that group's directory in the widget store.
 */
@Serializable
data class WidgetSnapshot(
    val groupId: String,
    val groupName: String,
    /** The widget rendition, a file in the group's widget directory. */
    val photoFile: String,
    /** Null for a collage (it has no single sender). */
    val senderName: String? = null,
    val senderAvatarFile: String? = null,
    val caption: String? = null,
    val kind: Kind,
    @SerialName("postedAt") val postedAtEpochMillis: Long,
    /** The post (or collage) this rendition belongs to; used to skip duplicate deliveries. */
    val sourceId: String? = null,
) {
    @Serializable
    enum class Kind {
        @SerialName("photo") Photo,
        @SerialName("collage") Collage,
    }

    val postedAt: Instant get() = Instant.ofEpochMilli(postedAtEpochMillis)

    /** Whether this snapshot should replace [current] on the widget (newest wins). */
    fun supersedes(current: WidgetSnapshot?): Boolean =
        current == null || postedAtEpochMillis > current.postedAtEpochMillis ||
            (postedAtEpochMillis == current.postedAtEpochMillis && sourceId != current.sourceId)

    fun toJson(): String = json.encodeToString(serializer(), this)

    companion object {
        private val json = Json { ignoreUnknownKeys = true; encodeDefaults = false }

        fun fromJson(text: String): WidgetSnapshot? = try {
            json.decodeFromString(serializer(), text)
        } catch (_: Exception) {
            null
        }
    }
}
