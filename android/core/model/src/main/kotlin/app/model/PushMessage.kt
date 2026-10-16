package app.model

import java.time.Instant
import java.time.format.DateTimeParseException

/**
 * FCM data messages, parsed from their string map. Notification texts (`title`, `body`) are
 * rendered by the worker from the generated copy table, so the client shows them as sent.
 *
 * The key names live in [PushKeys] and [PushTypes] only; they are the wire contract with the
 * worker's push sender (docs/API.md is the reference once it lands — change them there and here).
 */
sealed interface PushMessage {

    /** A new rendition for one group's widget. Silent; never shown as a notification. */
    data class WidgetUpdate(
        val groupId: String,
        val groupName: String,
        /** Short-lived signed URL of the widget rendition. */
        val renditionUrl: String,
        val kind: WidgetSnapshot.Kind,
        val postedAt: Instant,
        val sourceId: String?,
        val senderName: String?,
        val senderAvatarUrl: String?,
        val caption: String?,
    ) : PushMessage

    /** The daily same-moment invitation: an ongoing notification counting down to [closesAt]. */
    data class DailyInvitation(
        val groupId: String,
        val invitationId: String,
        val closesAt: Instant,
        val title: String,
        val body: String?,
        /** Server send time, used to correct this device's clock for the countdown. */
        val sentAt: Instant?,
    ) : PushMessage {
        val link: DeepLink get() = DeepLink.DailyInvitation(groupId, invitationId)
    }

    /** Daily invitation window ended or was answered on another device: remove the countdown. */
    data class DailyInvitationEnded(val groupId: String, val invitationId: String) : PushMessage

    /** A visible alert. */
    data class Alert(
        val kind: AlertKind,
        val groupId: String?,
        val title: String,
        val body: String?,
        val link: DeepLink?,
        /** Collapses repeated alerts about the same thing (e.g. several reactions to one post). */
        val collapseKey: String?,
    ) : PushMessage

    /**
     * [Plan]: a plan was made, changed or cancelled, or the day-before reminder (`push.plan_*`, docs/API.md §14.2). New
     * kinds go last: the ordinal is part of the notification id.
     */
    enum class AlertKind { NewPost, Reaction, Reply, RecapReady, BirthdayRequest, TributeForYou, YearStory, Plan }

    companion object {
        fun parse(data: Map<String, String>, codec: DeepLinkCodec): PushMessage? {
            fun s(key: String) = data[key]?.takeIf { it.isNotBlank() }
            fun id(key: String) = s(key)?.takeIf(DeepLinkCodec::isId)
            fun time(key: String) = s(key)?.let(::parseInstant)

            return when (s(PushKeys.TYPE)) {
                PushTypes.WIDGET -> {
                    val groupId = id(PushKeys.GROUP_ID) ?: return null
                    val url = s(PushKeys.RENDITION_URL)?.takeIf { it.startsWith("https://") } ?: return null
                    val kind = when (s(PushKeys.KIND)) {
                        PushTypes.KIND_COLLAGE -> WidgetSnapshot.Kind.Collage
                        PushTypes.KIND_PHOTO, null -> WidgetSnapshot.Kind.Photo
                        else -> return null
                    }
                    WidgetUpdate(
                        groupId = groupId,
                        groupName = s(PushKeys.GROUP_NAME).orEmpty(),
                        renditionUrl = url,
                        kind = kind,
                        postedAt = time(PushKeys.POSTED_AT) ?: return null,
                        sourceId = id(PushKeys.POST_ID) ?: id(PushKeys.COLLAGE_ID),
                        senderName = s(PushKeys.SENDER_NAME),
                        senderAvatarUrl = s(PushKeys.SENDER_AVATAR_URL)?.takeIf { it.startsWith("https://") },
                        caption = s(PushKeys.CAPTION),
                    )
                }
                PushTypes.DAILY_INVITATION -> DailyInvitation(
                    groupId = id(PushKeys.GROUP_ID) ?: return null,
                    invitationId = id(PushKeys.INVITATION_ID) ?: return null,
                    closesAt = time(PushKeys.CLOSES_AT) ?: return null,
                    title = s(PushKeys.TITLE) ?: return null,
                    body = s(PushKeys.BODY),
                    sentAt = time(PushKeys.SENT_AT),
                )
                PushTypes.DAILY_INVITATION_ENDED -> DailyInvitationEnded(
                    groupId = id(PushKeys.GROUP_ID) ?: return null,
                    invitationId = id(PushKeys.INVITATION_ID) ?: return null,
                )
                else -> parseAlert(data, codec)
            }
        }

        private fun parseAlert(data: Map<String, String>, codec: DeepLinkCodec): Alert? {
            fun s(key: String) = data[key]?.takeIf { it.isNotBlank() }
            fun id(key: String) = s(key)?.takeIf(DeepLinkCodec::isId)
            val kind = when (s(PushKeys.TYPE)) {
                PushTypes.NEW_POST -> AlertKind.NewPost
                PushTypes.REACTION -> AlertKind.Reaction
                PushTypes.REPLY -> AlertKind.Reply
                PushTypes.RECAP_READY -> AlertKind.RecapReady
                PushTypes.BIRTHDAY_REQUEST -> AlertKind.BirthdayRequest
                PushTypes.TRIBUTE -> AlertKind.TributeForYou
                PushTypes.YEAR_STORY -> AlertKind.YearStory
                PushTypes.PLAN -> AlertKind.Plan
                else -> return null
            }
            val group = id(PushKeys.GROUP_ID)
            // A plan opens without its group too (the page reads the plan's own group).
            val derived: DeepLink? = if (kind == AlertKind.Plan) id(PushKeys.PLAN_ID)?.let { DeepLink.Plan(it, group) } else group?.let { g ->
                when (kind) {
                    AlertKind.NewPost, AlertKind.Reaction -> id(PushKeys.POST_ID)?.let { DeepLink.Post(g, it) }
                    AlertKind.Reply -> id(PushKeys.MESSAGE_ID)?.let { DeepLink.ChatMessage(g, it) }
                        ?: id(PushKeys.POST_ID)?.let { DeepLink.Post(g, it) }
                    AlertKind.RecapReady -> id(PushKeys.RECAP_ID)?.let { DeepLink.Recap(g, it) }
                    AlertKind.BirthdayRequest -> id(PushKeys.REQUEST_ID)?.let { DeepLink.BirthdayRequest(g, it) }
                    AlertKind.TributeForYou -> id(PushKeys.TRIBUTE_ID)?.let { DeepLink.Tribute(g, it) }
                    AlertKind.YearStory -> s(PushKeys.YEAR)?.toIntOrNull()?.let { DeepLink.YearStory(g, it) }
                    AlertKind.Plan -> null
                }
            }
            return Alert(
                kind = kind,
                groupId = group,
                title = s(PushKeys.TITLE) ?: return null,
                body = s(PushKeys.BODY),
                link = codec.parse(s(PushKeys.LINK)) ?: derived,
                collapseKey = s(PushKeys.COLLAPSE_KEY),
            )
        }

        /** ISO-8601 instant, or epoch milliseconds. */
        fun parseInstant(value: String): Instant? = try {
            if (value.all(Char::isDigit)) Instant.ofEpochMilli(value.toLong()) else Instant.parse(value)
        } catch (_: DateTimeParseException) {
            null
        } catch (_: NumberFormatException) {
            null
        }
    }
}

/** FCM data keys. Wire contract with backend/worker push sender. */
object PushKeys {
    const val TYPE = "type"
    const val GROUP_ID = "group_id"
    const val GROUP_NAME = "group_name"
    const val POST_ID = "post_id"
    const val COLLAGE_ID = "collage_id"
    const val MESSAGE_ID = "message_id"
    const val INVITATION_ID = "invitation_id"
    const val RECAP_ID = "recap_id"
    const val REQUEST_ID = "request_id"
    const val TRIBUTE_ID = "tribute_id"
    const val YEAR = "year"
    const val PLAN_ID = "plan_id"
    const val KIND = "kind"
    const val RENDITION_URL = "rendition_url"
    const val SENDER_NAME = "sender_name"
    const val SENDER_AVATAR_URL = "sender_avatar_url"
    const val CAPTION = "caption"
    const val POSTED_AT = "posted_at"
    const val CLOSES_AT = "closes_at"
    const val SENT_AT = "sent_at"
    const val TITLE = "title"
    const val BODY = "body"
    const val LINK = "link"
    const val COLLAPSE_KEY = "collapse_key"
}

/** Values of [PushKeys.TYPE] (and [PushKeys.KIND]). */
object PushTypes {
    const val WIDGET = "widget"
    const val DAILY_INVITATION = "daily_invitation"
    const val DAILY_INVITATION_ENDED = "daily_invitation_ended"
    const val NEW_POST = "new_post"
    const val REACTION = "reaction"
    const val REPLY = "reply"
    const val RECAP_READY = "recap_ready"
    const val BIRTHDAY_REQUEST = "birthday_request"
    const val TRIBUTE = "tribute"
    const val YEAR_STORY = "year_story"
    const val PLAN = "plan"

    const val KIND_PHOTO = "photo"
    const val KIND_COLLAGE = "collage"
}
