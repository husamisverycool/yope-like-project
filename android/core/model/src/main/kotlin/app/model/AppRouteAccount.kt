package app.model

import kotlinx.serialization.Serializable

/*
 * Routes added by the account screens pass (same package and module, so they join the sealed
 * [AppRoute]). Surface ids from docs/SURFACES.md.
 */

/** `groups.screen` B: the group profile page (avatar, name, members row, "pics | wall | recaps", ••• menu). */
@Serializable
data class GroupProfileRoute(val groupId: String) : AppRoute {
    override val surface get() = "groups.screen"
}

/** `groups.create` in edit mode (opened from `groups.settings` by an admin). */
@Serializable
data class GroupEditRoute(val groupId: String) : AppRoute {
    override val surface get() = "groups.create"
}

/**
 * `safety.report` for a chat message (target kind `message`), for `chat.thread`'s long-press menu;
 * [AppRoute.SafetyReport] covers posts, people and groups.
 */
@Serializable
data class SafetyReportMessageRoute(val groupId: String, val messageId: String, val authorId: String? = null) : AppRoute {
    override val surface get() = "safety.report"
}
