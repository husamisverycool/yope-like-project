package app.data.media

/**
 * Object paths in the private `media` bucket (docs/API.md §7). Clients write only under
 * `u/<own uid>/` and `avatars/<own uid>/`, never overwrite, and read through signed URLs.
 */
object StoragePaths {
    const val BUCKET = "media"

    /** `u/<uid>/<media_id>/original.<ext>` — back camera / only image, or the video file. */
    fun original(uid: String, mediaId: String, ext: String): String = "u/${seg(uid)}/${seg(mediaId)}/original.${ext(ext)}"

    /** `u/<uid>/<media_id>/front.jpg` — front image of a dual capture. */
    fun front(uid: String, mediaId: String): String = "u/${seg(uid)}/${seg(mediaId)}/front.jpg"

    /**
     * `u/<uid>/<media_id>/motion.<ext>` — the motion clip. API.md names it `motion.mov` (an iOS Live
     * Photo); an Android motion clip is MP4, stored as `motion.mp4` with `video/mp4` so the name,
     * content type and bytes agree (the database only requires the `u/<uid>/<media_id>/` prefix).
     */
    fun motion(uid: String, mediaId: String, ext: String = "mov"): String = "u/${seg(uid)}/${seg(mediaId)}/motion.${ext(ext)}"

    /** `u/<uid>/<media_id>/voice.m4a` — the voice note of a post. */
    fun postVoice(uid: String, mediaId: String): String = "u/${seg(uid)}/${seg(mediaId)}/voice.m4a"

    /** `u/<uid>/voice/<uuid>.m4a` — a chat voice message. */
    fun chatVoice(uid: String, id: String): String = "u/${seg(uid)}/voice/${seg(id)}.m4a"

    /** `u/<uid>/covers/<uuid>.jpg` — a group cover (the group id does not exist yet at upload). */
    fun cover(uid: String, id: String): String = "u/${seg(uid)}/covers/${seg(id)}.jpg"

    /** `avatars/<uid>/<uuid>.jpg` */
    fun avatar(uid: String, id: String): String = "avatars/${seg(uid)}/${seg(id)}.jpg"

    /** The server's rule: letters, digits, `_ . / -`; no `..`, no empty segments. */
    fun isSafe(path: String): Boolean =
        path.isNotEmpty() && SAFE.matches(path) && !path.contains("..") && path.split('/').none { it.isEmpty() }

    /** The bucket's allowed content types (docs/API.md §7). */
    val ALLOWED_CONTENT_TYPES = setOf(
        "image/jpeg", "image/heic", "image/heif", "image/png", "image/webp",
        "video/mp4", "video/quicktime",
        "audio/mp4", "audio/m4a", "audio/x-m4a", "audio/aac", "audio/mpeg",
    )

    /** Max object size: 100 MiB. */
    const val MAX_OBJECT_BYTES = 100L * 1024 * 1024

    fun contentTypeFor(ext: String): String = when (ext.lowercase()) {
        "jpg", "jpeg" -> "image/jpeg"
        "heic" -> "image/heic"
        "heif" -> "image/heif"
        "png" -> "image/png"
        "webp" -> "image/webp"
        "mp4" -> "video/mp4"
        "mov" -> "video/quicktime"
        "m4a" -> "audio/mp4"
        "aac" -> "audio/aac"
        "mp3" -> "audio/mpeg"
        else -> throw IllegalArgumentException("unsupported extension $ext")
    }

    private val SAFE = Regex("[A-Za-z0-9_./-]+")
    private val SEGMENT = Regex("[A-Za-z0-9_-]+")
    private val EXT = Regex("[a-z0-9]{1,5}")

    private fun seg(s: String): String = s.also { require(SEGMENT.matches(it)) { "invalid path segment" } }
    private fun ext(s: String): String = s.lowercase().also { require(EXT.matches(it)) { "invalid extension" } }
}
