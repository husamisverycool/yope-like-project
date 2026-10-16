package app.widget

import app.designsystem.R

/**
 * BLOCKED copy of the countdown widget (design/BLOCKED.md): only debug builds have it (core:designsystem `src/debug`
 * resources); the release source set leaves the element out.
 */
internal object CountdownBlocked {
    /** `widget.countdown.empty.noPlans` — no reference widget shows an empty plan state (plans.md §12 item 7). */
    val noPlans: Int? = R.string.widget_countdown_empty_noplans
}
