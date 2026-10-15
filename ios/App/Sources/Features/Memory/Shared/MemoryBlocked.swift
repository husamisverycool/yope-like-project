// Every BLOCKED value the memory screens wait for (design/BLOCKED.md), each behind one accessor.
// While a value is BLOCKED its accessor returns nil and the screen does what its spec's "Gaps"
// section says. When research unblocks a value (it moves from the DEBUG-only `BlockedTokens` into
// `Tokens`, same name), replace the `nil` below with the `Tokens.*` constant — one line — and the
// behaviour wired to it switches on. (The tribute video's BLOCKED values are read by the worker only.)
import DesignSystem
import Foundation

enum MemoryBlocked {
    /// `duration.year.story.card` → `Tokens.Durations.yearStoryCard`. With it the story advances on its
    /// own (the current segment fills over it, `easing.year.story.progress.fill`) and the pause / play
    /// circle shows; nil: tap-only, pause hidden (M-16).
    static var yearStoryCardDuration: TimeInterval? { nil }

    /// `easing.year.story.reveal` → `Tokens.Easings.yearStoryReveal`. With it the headline moves up and
    /// the subline rises in (`dimension.year.story.reveal.*`, `duration.year.story.reveal.*`), with the
    /// Reduce Motion cross-fade substitute; nil: everyone gets the substitute (M-17).
    static var yearStoryRevealEasing: DSEasing? { nil }

    /// `layout.year.story.summary.dots` → `Tokens.Layouts.YearStorySummaryDots`. Its fields are not
    /// known until it is sourced, so the dots are drawn only once that token is wired here; nil: none.
    static var yearStorySummaryDots: Bool { false }

    /// `duration.onthisday.memoryChange` → `Tokens.Durations.onthisdayMemoryChange`. With it the year
    /// content cross-fades over that duration (curve: `easing.global.native` until a curve is sourced);
    /// nil: the year changes without animation.
    static var onThisDayMemoryChange: TimeInterval? { nil }

    /// `layout.birthday.contribute.lineMax` → its character limit. With it the line stops growing at
    /// the limit (still no visible counter); nil: the API bound applies (280, `invalid_line`).
    static var contributeLineMax: Int? { nil }

    /// The toast dwell (`safety.block.duration.toast`, `camera.sendto.duration.toastVisible`) →
    /// `Tokens.Durations.safetyBlockToast`. With it release builds show the toast for that long; nil:
    /// release builds announce the text only, DEBUG builds draw it until tapped.
    static var toastDwell: TimeInterval? { nil }
}
