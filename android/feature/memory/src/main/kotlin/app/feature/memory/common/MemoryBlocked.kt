package app.feature.memory.common

import androidx.compose.animation.core.Easing
import app.designsystem.generated.Tokens

/**
 * The design values the memory screens depended on while they were BLOCKED (design/BLOCKED.md),
 * behind one accessor. All of them are now sourced (gap fill, MERGE G2-17 … G2-21), so each line
 * reads its token; a value that becomes BLOCKED again is set back to `null` here (one line) and the
 * screens fall back to each spec's Gaps rule.
 *
 * Toast dwell (`safety.block.duration.toast`, 2000 ms, G2-7) is shared app-wide:
 * `app.ui.components.ToastDwell`. The tribute video values are sourced too (G2-22 … G2-25:
 * `duration.birthday.tribute.photoHold` 4000 ms, `layout.birthday.tribute.caption`, `.endCard`,
 * copy `birthday.tribute.endCard` "We love you!") but are burned into the video by the worker; the
 * app never reads them, so they have no line here.
 */
object MemoryBlocked {
    /** `duration.onthisday.memoryChange` (ms): years cross-fade. Null: they change without animation. */
    val onThisDayMemoryChangeMs: Int? = Tokens.Durations.onthisdayMemoryChange

    /** `duration.year.story.card` (ms): auto-advance, segment fill, pause control. Null: tap-only, pause hidden. */
    val yearStoryCardMs: Int? = Tokens.Durations.yearStoryCard

    /** `easing.year.story.reveal` (headline). Null: every viewer gets the Reduce Motion cross-fade. */
    val yearStoryRevealEasing: Easing? = Tokens.Easings.yearStoryReveal

    /** `easing.year.story.reveal.subline`. Null: as above. */
    val yearStoryRevealSublineEasing: Easing? = Tokens.Easings.yearStoryRevealSubline

    /** `layout.year.story.summary.dots`: page dots under the summary carousel. False: no dots. */
    const val YEAR_STORY_SUMMARY_DOTS: Boolean = true

    /** `layout.birthday.contribute.lineMax` (characters). Null: the API bound applies. No visible counter either way. */
    val birthdayLineMax: Int? = Tokens.Layouts.BirthdayContributeLineMax.maxCharacters.toInt()
}
