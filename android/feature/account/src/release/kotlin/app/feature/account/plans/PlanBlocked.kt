package app.feature.account.plans

/**
 * BLOCKED parts of the plan surfaces (design/BLOCKED.md) do not ship: the past plan's "Went" label is left out (the
 * Going list keeps its avatars and names) and the `groups.screen` plan row is shown only while no birthday request row is
 * on screen, so no order between them is decided (plans.md §12 item 6). The debug source set turns them on.
 */
internal object PlanBlocked {
    /** `plans.page.went` — BLOCKED. */
    val went: Int? = null

    /** The plan row beside a birthday request row — order BLOCKED: release builds show it only without one. */
    const val besideBirthdayRow: Boolean = false
}
