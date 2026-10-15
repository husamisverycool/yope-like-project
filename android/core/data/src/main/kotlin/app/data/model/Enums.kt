package app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Postgres enums (docs/API.md §4). Serial names are the wire values. */

@Serializable
enum class GroupKind(val wire: String) {
    @SerialName("friends") Friends("friends"),
    @SerialName("family") Family("family"),
    @SerialName("roommates") Roommates("roommates"),
    @SerialName("custom") Custom("custom"),
}

@Serializable
enum class MemberRole(val wire: String) {
    @SerialName("admin") Admin("admin"),
    @SerialName("member") Member("member"),
}

@Serializable
enum class MediaKind(val wire: String) {
    @SerialName("photo") Photo("photo"),
    @SerialName("live_photo") LivePhoto("live_photo"),
    @SerialName("video") Video("video"),
}

@Serializable
enum class MessageKind(val wire: String) {
    @SerialName("text") Text("text"),
    @SerialName("photo") Photo("photo"),
    @SerialName("voice") Voice("voice"),
}

@Serializable
enum class DevicePlatform(val wire: String) {
    @SerialName("ios") Ios("ios"),
    @SerialName("android") Android("android"),
}

@Serializable
enum class InvitationStatus(val wire: String) {
    @SerialName("scheduled") Scheduled("scheduled"),
    @SerialName("fired") Fired("fired"),
    @SerialName("closed") Closed("closed"),
    @SerialName("cancelled") Cancelled("cancelled"),
}

@Serializable
enum class RenderStatus(val wire: String) {
    @SerialName("pending") Pending("pending"),
    @SerialName("ready") Ready("ready"),
    @SerialName("failed") Failed("failed"),
}

@Serializable
enum class ReportTargetKind(val wire: String) {
    @SerialName("post") Post("post"),
    @SerialName("message") Message("message"),
    @SerialName("user") User("user"),
    @SerialName("group") Group("group"),
}

/** `wall.item_kind` (text, not a Postgres enum). */
@Serializable
enum class WallItemKind(val wire: String) {
    @SerialName("post") Post("post"),
    @SerialName("collage") Collage("collage"),
}
