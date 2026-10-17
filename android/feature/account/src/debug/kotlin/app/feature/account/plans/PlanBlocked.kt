package app.feature.account.plans

/**
 * BLOCKED parts of the plan surfaces (design/BLOCKED.md, MERGE_DECISIONS "New features"): debug builds show them so they
 * can be judged on a device and in the snapshots; the release source set leaves them out.
 */
internal object PlanBlocked {

    /**
     * The `groups.screen` plan row beside an open birthday request row: their order is not evidenced (plans.md §12 item
     * 6), so only debug builds show both (the birthday row first); release builds show the plan row while no birthday row
     * is on screen.
     */
    const val besideBirthdayRow: Boolean = true
}
