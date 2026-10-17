package app.model

import kotlinx.serialization.Serializable

/*
 * Routes added by the account screens passes (same package and module, so they join the sealed [AppRoute]).
 * Surface ids from docs/SURFACES.md.
 */

/**
 * `groups.screen` opened as "the group's page" (social's chat header). The redesign has one group screen (Retro's album
 * detail, MERGE RA-9): this route hosts the same screen as [AppRoute.Group]; new callers use [AppRoute.Group].
 */
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
 * `groups.create` at its name step with the group kind already chosen (a "Create" template row on `groups.list`);
 * [kind] is the `group_kind` wire value (friends · family · roommates · custom).
 */
@Serializable
data class GroupCreateKindRoute(val kind: String) : AppRoute {
    override val surface get() = "groups.create"
}

/** `onboarding.widget` opened from `settings.root` (Widgets → Add Widget): back chevron, returns to Settings. */
@Serializable
data object OnboardingWidgetFromSettingsRoute : AppRoute {
    override val surface get() = "onboarding.widget"
}

/**
 * `safety.report` for a chat message (target kind `message`), for `chat.thread`'s long-press menu;
 * [AppRoute.SafetyReport] covers posts, people and groups.
 */
@Serializable
data class SafetyReportMessageRoute(val groupId: String, val messageId: String, val authorId: String? = null) : AppRoute {
    override val surface get() = "safety.report"
}

/**
 * `safety.report` for a selfie reaction (target kind `selfie`, by its `selfie_reactions.id`), from the Reactions sheet's
 * row menu in `photo.viewer` (viewer.selfiereaction §4); [authorId] is who took the selfie (Next Steps → Block).
 */
@Serializable
data class SafetyReportSelfieRoute(val groupId: String, val selfieId: String, val authorId: String) : AppRoute {
    override val surface get() = "safety.report"
}

/**
 * `safety.report` for the other content kinds (MERGE FV-4): [kind] is the server's `report_target_kind` — `plan`
 * (plans.page), `tribute` (birthday.tribute), `year_story` (year.story), `collage` (collage.view) or `recap`
 * (week.recap) — and [targetId] its row's id; [authorId] is the person behind it (a plan's maker: Next Steps → Block),
 * null for group-made content (Next Steps → Leave the group only).
 */
@Serializable
data class SafetyReportContentRoute(val kind: String, val targetId: String, val groupId: String, val authorId: String? = null) : AppRoute {
    override val surface get() = "safety.report"
}
