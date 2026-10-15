package app.model

import java.net.URI
import java.net.URLDecoder
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

/**
 * Every way into the app from outside it: invite links (App Links), widget taps and
 * notification taps. Parsed by [DeepLinkCodec]; turned into a navigation back stack by
 * [DeepLinkRouting].
 */
sealed interface DeepLink {
    /** `https://<domain>/i/<token>` */
    data class Invite(val token: String) : DeepLink

    /**
     * `app://camera?group=<id>` — widget tap, opens straight into the camera for that group.
     * [groupId] is null for `app://camera` (an unconfigured widget) and for an unreadable id: the
     * camera still opens, with nothing preselected (design/MERGE_DECISIONS.md C-24, iOS
     * `DeepLink.camera(groupID:)`).
     */
    data class Camera(val groupId: String? = null) : DeepLink

    /** `app://post?group=<id>&post=<id>` — new post, reaction to your post. */
    data class Post(val groupId: String, val postId: String) : DeepLink

    /** `app://chat?group=<id>&message=<id>` — reply to you in the group chat. */
    data class ChatMessage(val groupId: String, val messageId: String) : DeepLink

    /** `app://daily?group=<id>&invitation=<id>` — the daily same-moment invitation. */
    data class DailyInvitation(val groupId: String, val invitationId: String) : DeepLink

    /** `app://recap?group=<id>&recap=<id>` — the week's recap is ready. */
    data class Recap(val groupId: String, val recapId: String) : DeepLink

    /** `app://birthday-request?group=<id>&request=<id>` — private request to contribute. */
    data class BirthdayRequest(val groupId: String, val requestId: String) : DeepLink

    /** `app://tribute?group=<id>&tribute=<id>` — the tribute made for you. */
    data class Tribute(val groupId: String, val tributeId: String) : DeepLink

    /** `app://year-story?group=<id>&year=<yyyy>` */
    data class YearStory(val groupId: String, val year: Int) : DeepLink
}

/**
 * Parses and formats [DeepLink]s.
 *
 * @param domain the invite-link host from `config/app.json` (`domain`), or null while the owner
 *   has not set it — invite links are then not recognised.
 */
class DeepLinkCodec(private val domain: String?) {

    fun parse(uri: String?): DeepLink? {
        if (uri.isNullOrBlank()) return null
        val parsed = try {
            URI(uri.trim())
        } catch (_: Exception) {
            return null
        }
        return when (parsed.scheme?.lowercase()) {
            HTTPS -> parseInvite(parsed)
            APP_SCHEME -> parseAppLink(parsed)
            else -> null
        }
    }

    /** The URI for [link]; null for [DeepLink.Invite] while no domain is configured. */
    fun format(link: DeepLink): String? = when (link) {
        is DeepLink.Invite -> domain?.let { "$HTTPS://$it$INVITE_PATH${encode(link.token)}" }
        is DeepLink.Camera -> link.groupId?.let { app(HOST_CAMERA, P_GROUP to it) } ?: "$APP_SCHEME://$HOST_CAMERA"
        is DeepLink.Post -> app(HOST_POST, P_GROUP to link.groupId, P_POST to link.postId)
        is DeepLink.ChatMessage -> app(HOST_CHAT, P_GROUP to link.groupId, P_MESSAGE to link.messageId)
        is DeepLink.DailyInvitation -> app(HOST_DAILY, P_GROUP to link.groupId, P_INVITATION to link.invitationId)
        is DeepLink.Recap -> app(HOST_RECAP, P_GROUP to link.groupId, P_RECAP to link.recapId)
        is DeepLink.BirthdayRequest -> app(HOST_BIRTHDAY_REQUEST, P_GROUP to link.groupId, P_REQUEST to link.requestId)
        is DeepLink.Tribute -> app(HOST_TRIBUTE, P_GROUP to link.groupId, P_TRIBUTE to link.tributeId)
        is DeepLink.YearStory -> app(HOST_YEAR_STORY, P_GROUP to link.groupId, P_YEAR to link.year.toString())
    }

    private fun parseInvite(uri: URI): DeepLink? {
        val host = uri.host ?: return null
        if (domain == null || !host.equals(domain, ignoreCase = true)) return null
        if (uri.port != -1 && uri.port != HTTPS_PORT) return null
        val path = uri.rawPath ?: return null
        if (!path.startsWith(INVITE_PATH)) return null
        val token = decode(path.removePrefix(INVITE_PATH).removeSuffix("/")) ?: return null
        return if (isId(token)) DeepLink.Invite(token) else null
    }

    private fun parseAppLink(uri: URI): DeepLink? {
        // app://camera?group=x  → host "camera", no path.
        if (uri.isOpaque) return null
        val host = (uri.host ?: uri.authority)?.lowercase() ?: return null
        val path = uri.rawPath.orEmpty()
        if (path.isNotEmpty() && path != "/") return null
        // The camera opens even when its group id is missing or unreadable (C-24).
        if (host == HOST_CAMERA) return DeepLink.Camera(query(uri.rawQuery)?.get(P_GROUP)?.takeIf(::isId))
        val q = query(uri.rawQuery) ?: return null
        fun id(key: String) = q[key]?.takeIf(::isId)
        return when (host) {
            HOST_POST -> both(id(P_GROUP), id(P_POST), DeepLink::Post)
            HOST_CHAT -> both(id(P_GROUP), id(P_MESSAGE), DeepLink::ChatMessage)
            HOST_DAILY -> both(id(P_GROUP), id(P_INVITATION), DeepLink::DailyInvitation)
            HOST_RECAP -> both(id(P_GROUP), id(P_RECAP), DeepLink::Recap)
            HOST_BIRTHDAY_REQUEST -> both(id(P_GROUP), id(P_REQUEST), DeepLink::BirthdayRequest)
            HOST_TRIBUTE -> both(id(P_GROUP), id(P_TRIBUTE), DeepLink::Tribute)
            HOST_YEAR_STORY -> {
                val year = q[P_YEAR]?.takeIf { it.length == YEAR_DIGITS && it.all(Char::isDigit) }?.toInt()
                both(id(P_GROUP), year, DeepLink::YearStory)
            }
            else -> null
        }
    }

    private inline fun <A : Any, B : Any> both(a: A?, b: B?, make: (A, B) -> DeepLink): DeepLink? =
        if (a != null && b != null) make(a, b) else null

    /** Query parameters; null when any parameter is malformed. The first value of a key wins. */
    private fun query(raw: String?): Map<String, String>? {
        if (raw.isNullOrEmpty()) return emptyMap()
        val out = LinkedHashMap<String, String>()
        for (pair in raw.split('&')) {
            if (pair.isEmpty()) continue
            val key = decode(pair.substringBefore('=')) ?: return null
            val value = decode(pair.substringAfter('=', "")) ?: return null
            out.putIfAbsent(key, value)
        }
        return out
    }

    private fun app(host: String, vararg params: Pair<String, String>): String =
        "$APP_SCHEME://$host?" + params.joinToString("&") { (k, v) -> "$k=${encode(v)}" }

    companion object {
        /** Scheme for links the app builds for itself (widgets, notifications). */
        const val APP_SCHEME = "app"
        /** Path prefix of invite links: `https://<domain>/i/<token>`. */
        const val INVITE_PATH = "/i/"

        const val HOST_CAMERA = "camera"
        const val HOST_POST = "post"
        const val HOST_CHAT = "chat"
        const val HOST_DAILY = "daily"
        const val HOST_RECAP = "recap"
        const val HOST_BIRTHDAY_REQUEST = "birthday-request"
        const val HOST_TRIBUTE = "tribute"
        const val HOST_YEAR_STORY = "year-story"

        const val P_GROUP = "group"
        const val P_POST = "post"
        const val P_MESSAGE = "message"
        const val P_INVITATION = "invitation"
        const val P_RECAP = "recap"
        const val P_REQUEST = "request"
        const val P_TRIBUTE = "tribute"
        const val P_YEAR = "year"

        private const val HTTPS = "https"
        private const val HTTPS_PORT = 443
        private const val YEAR_DIGITS = 4
        private const val MAX_ID_LENGTH = 256
        private val ID = Regex("[A-Za-z0-9_-]+")

        /** Server identifiers (UUIDs) and invite tokens (URL-safe random strings). */
        fun isId(value: String): Boolean = value.length in 1..MAX_ID_LENGTH && ID.matches(value)

        private fun decode(s: String): String? = try {
            URLDecoder.decode(s, StandardCharsets.UTF_8)
        } catch (_: IllegalArgumentException) {
            null
        }

        private fun encode(s: String): String = URLEncoder.encode(s, StandardCharsets.UTF_8)
    }
}
