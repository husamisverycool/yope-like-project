package app.feature.memory.common

import androidx.compose.animation.core.Easing

/**
 * Every BLOCKED design value the memory screens depend on (design/BLOCKED.md), behind one accessor.
 * Null = still BLOCKED: each screen follows its spec's Gaps rule. When `tools/designgen.mjs` moves a
 * value into `Tokens`, replace its `null` with the token (one line); the screens already implement the
 * sourced behaviour behind each value.
 *
 * Toast dwell (`safety.block.duration.toast`) is shared app-wide: `app.ui.components.ToastDwell`.
 * The tribute video values (`duration.birthday.tribute.photoHold`, `layout.birthday.tribute.caption`,
 * `.endCard`, copy `birthday.tribute.endCard`) are read by the worker only, never by the app.
 */
object MemoryBlocked {
    /** `duration.onthisday.memoryChange` (ms). Null: years change without animation. */
    val onThisDayMemoryChangeMs: Int? = null

    /** `duration.year.story.card` (ms). Null: no auto-advance, the current segment shows full, pause hidden. */
    val yearStoryCardMs: Int? = null

    /** `easing.year.story.reveal`. Null: every viewer gets the Reduce Motion cross-fade with the same timings. */
    val yearStoryRevealEasing: Easing? = null

    /**
     * `layout.year.story.summary.dots`. False: the summary carousel shows no page dots. The token's
     * shape (a layout object) is not known yet, so drawing the dots is added with it.
     */
    const val YEAR_STORY_SUMMARY_DOTS: Boolean = false

    /** `layout.birthday.contribute.lineMax` (characters). Null: the API bound applies, no visible counter. */
    val birthdayLineMax: Int? = null
}
