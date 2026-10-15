package app.model

import kotlinx.serialization.Serializable

/*
 * Routes added by the memory group (docs/SCREENS_BRIEF.md §6). Same package and module as the
 * sealed [AppRoute], so they join it.
 */

/**
 * `onthisday` — one group's day (design/surfaces/onthisday.md, B). The shared
 * [AppRoute.OnThisDay] carries no group id, so the day is reached through this route from the
 * entry on `groups.screen`. The date is computed on open: the date of (now in `groups.time_zone`
 * − `layout.onthisday.dayBoundary` hours).
 */
@Serializable
data class OnThisDayRoute(val groupId: String) : AppRoute {
    override val surface get() = "onthisday"
}
