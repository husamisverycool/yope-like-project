# `widget.countdown` — the next plan, in days (draft)

> **Draft, 2026-10-16.** Research: `design/research/plans.md` §9; data: `design/research/plans-data.md` (`next_plans`).
> Copy keys are proposals; tokens are existing names only.

**Visual reference: Retro's Glance widget anatomy, exactly as `widget.home.small`** (full-bleed photo, `layout.global.photoScrim`,
white text at the bottom-trailing corner, system corner, white-85 % state column) — so the countdown widget reads as the
same app as the photo widget. **Mechanics: Apple Invites' widget** ("count down the days until your next event"; "Edit
Widget" to change the featured event; photo + event title + "In 9 Days") with the day-only wording also used by
**Widgetsmith** ("SPRING BREAK / 4 DAYS") and the countdown apps. Sizes and refresh: **Apple HIG Widgets / WidgetKit**,
Android Glance (PLATFORM). Never hours, minutes or seconds (SPEC_FLAGS T4).

## References

| image / source | what it verifies |
|---|---|
| `references/auto/apple-invites/store/apple-invites-store-08.png` (3.000 px/pt) | medium widget 382.3 × 180.3 pt on a 440-pt phone; square photo 139.5 pt inset 20; title ≈ 19–20 pt white ≈ 62 %; countdown "In 9 Days" ≈ 24 pt bold white; baseline pitch 27; block centred; a guest-count pill (do-not-copy) |
| https://support.apple.com/guide/apple-invites/view-your-events-dev18a008ffb/ios | "count down the days until your next event"; "To change the featured event, touch and hold the widget, then tap Edit Widget." |
| `references/auto/countdown-widgets/store/widgetsmith-store-05.png` | full-bleed photo, title over "{n} DAYS" — days only (775,771-rating app) |
| `references/auto/countdown-widgets/store/cwdu-store-02.png` | photo widgets "{title}" / "{n}" / "days left" in small and medium sizes |
| `references/auto/countdown-widgets/store/cwdu-store-04.png`, `cwdc-store-01.png` | seconds / minutes countdowns — do-not-copy |
| `design/surfaces/widget.home.small.md` (+ its Retro APK and preview-art references) | anatomy, scrim, insets, state column, configuration pattern |
| Apple `RelativeDateTimeFormatter`, Android ICU `RelativeDateTimeFormatter` / `DateUtils` (docs, `plans.md` §1.3) | the relative-day wording ("in 2 weeks", "tomorrow", "In 42 minutes") — PLATFORM |
| `references/auto/platform/hig-widgets-ios-dimensions.png` | sizes (`widget.home.small.layout.size`, `widget.home.medium.layout.size`) |

## Structure

Families: **systemSmall** (158 × 158 pt on 393 × 852) and **systemMedium** (338 × 158) — the existing size tokens; one
layout at both sizes (Retro's resizable widget, MERGE RC-11). Corners from the system (`ContainerRelativeShape`).

1. **Photo** — the plan's cover; else the group's newest photo (the `widget.home.small` snapshot); full-bleed,
   aspect-fill, as the removable container background (`containerBackground(for: .widget)`), content margins disabled
   (`widget.home.small.layout.photo`). No photo at all → `color.global.backgroundDeep`.
2. **Scrim** — `layout.global.photoScrim` (black from 55 % of the height to `color.global.scrim`).
3. **Text stack**, bottom-trailing, trailing-aligned, insets from `widget.home.small.layout.overlay` (trailing 11, last
   baseline 15 above the bottom edge), `color.global.textOnMedia`:
   - line 1 — the plan's **title**, text role `listTitle` (15 semibold), one line, truncated at the leading inset
     `size.global.screenMargin`;
   - line 2 — **how far away**, text role `displaySmall` (24) in `font.global.display`, one line. Size: Apple's
     countdown line is ≈ 24 pt (cap 16.7 pt, AI-S 08) and Retro sets its photo-card headlines in displaySmall 24
     (`groups.screen` feed cards); the serif is Retro's display face (no second visual language). Title above the
     countdown, as Apple Invites and Widgetsmith.
   - medium only: line 0 above the title — the **group name** (`widget.home.small.fontSize.overlay` 11, regular), so a
     widget showing plans from all groups says whose plan it is (small: the group name is in the accessibility label
     only; HIG 11-pt minimum respected).
4. Nothing else: no guest avatars, no count pill, no date line (Apple's widget has none; Countdown Widget's date line is
   not needed when the plan page has it).

### The countdown line

Day granularity, from the platform formatter, never typed by us:

| days until `local_date` (viewer's calendar) | text | source |
|---|---|---|
| ≥ 2 | "In {n} days" | iOS `RelativeDateTimeFormatter` (`unitsStyle .full`, `localizedString(from: DateComponents(day: n))`, `formattingContext .beginningOfSentence`); Android ICU `format(n, Direction.NEXT, RelativeUnit.DAYS)` with `DisplayContext.CAPITALIZATION_FOR_BEGINNING_OF_SENTENCE` — mechanic Apple "In 9 Days" (AI-S 08) |
| 1 | "Tomorrow" | iOS `dateTimeStyle .named` (doc: "tomorrow"); ICU `AbsoluteUnit.DAY, Direction.NEXT` |
| 0 | the formatter's same-day word | iOS `.named` day 0; ICU `AbsoluteUnit.DAY, Direction.THIS` — exact output not printed in the docs: **BLOCKED** until a snapshot test pins it (`plans.md` §12 item 2) |

Days are counted between calendar dates (the plan's `local_date` in the group's time zone vs. today in the device's time
zone), not 24-hour spans, so "Tomorrow" never shows for a plan 30 hours away on the day after tomorrow.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| photo | `widget.home.small.layout.photo`, `layout.global.photoScrim`, `widgetAccentedRenderingMode(.fullColor)` | a11y via the widget label | plan cover → group newest photo → none |
| group line (medium) | `widget.home.small.fontSize.overlay`, `widget.home.small.fontWeight.overlay`, `color.global.textOnMedia` | data | — |
| title | text role `listTitle`, `color.global.textOnMedia` | data | — |
| countdown | `font.global.display`, text role `displaySmall`, `color.global.textOnMedia` | platform formatter output | changes at local midnight only |
| tap | `widgetURL` (`DeepLink.plan(planID:)`) | — | opens `plans.page`; empty state opens `plans.create` for the configured group (or `groups.list` when "All groups") |
| configuration | AppIntentConfiguration, one parameter | `widget.countdown.configuration.title`, `.configuration.group`, `.configuration.allGroups` | "All groups" (default — Apple's "your next event") or one group (Apple "Edit Widget") |
| gallery | — | `widget.countdown.gallery.name`, `.gallery.description` | families small + medium (HIG: one description for all sizes) |

## States

Non-photo states use `widget.home.small`'s state column: `color.global.backgroundDeep`, centred `icon.global.calendar` at
`size.global.icon` in a 48-pt box, tinted `widget.home.small.color.stateTint`, then the line in
`widget.home.small.fontSize.overlay`, same tint, up to 2 lines.

| state | design | copy | source |
|---|---|---|---|
| upcoming plan | photo + text stack | — | Apple Invites widget |
| plan today | same; countdown = same-day word | BLOCKED word | formatter |
| no upcoming plan | state column | `widget.countdown.empty.noPlans` | retro.voice.widget ("No media. Tap to reload" pattern) — **wording BLOCKED for reference evidence** (`plans.md` §12 item 7); pattern-only until then |
| next plan canceled | skipped; the following plan shows (or the empty state) | — | Apple: a canceled event is inactive |
| not set up (configured group left / deleted) | state column | `widget.home.small.empty.setUp` (shared) | `widget.home.small` |
| signed out | state column | `widget.home.small.empty.signedOut` (shared) | `widget.home.small` |
| loading / error / offline | keep the last entry (HIG: don't hide stale data); nothing cached → `color.global.backgroundDeep` | — | HIG Widgets |

## Motion

None. The day count changes by a new timeline entry at local midnight with the instant swap of
`widget.arrival.duration.transition` (0 ms). No `Text(date, style: .timer)` / `.relative`, no Live Activity, no
seconds — T4.

## Haptics

None (system widget).

## Accessibility

- One element, button trait. Label `widget.countdown.a11y.plan`: "{plan_title} with {group_name}, {countdown}" (the
  countdown in the formatter's words); empty: the visible line.
- Dynamic Type: title scales with Subheadline, countdown with Title 2 (the text-style map of `listTitle` /
  `displaySmall`); both truncate to one line (widgets support Large–AX5, HIG).
- Contrast: identical to `widget.home.small` (white over the scrim is photo-dependent, **FAIL** on white photos —
  reported, not adjusted); state column 14.88:1.

## Data & actions

- The app writes a snapshot of `next_plans()` (title, `local_date`, `starts_at`, group name, cover downloaded) to the App
  Group / Glance state on every `plan_*` realtime event and on foreground (`widget.arrival` channels).
- Timeline: entries for today and each following midnight up to the plan's day (+1 entry for the day after, which falls
  through to the next plan); policy `.atEnd`. Android: Glance `updateAll` from a midnight `AlarmManager` /
  `WorkManager` job plus the snapshot write; `widget.android.duration.updatePeriod` as the backstop.

## Platform notes

- iOS: `AppIntentConfiguration` (as `widget.home.small`) with one `GroupEntity` parameter that includes "All groups".
- Android: `GlanceAppWidget` with the `widget.android` provider rules (system corner radius, edge-to-edge container),
  `SizeMode.Responsive` for 2 × 2 and 4 × 2; lock-screen hub opt-in as `widget.android` (owner decision 18).
- Lock Screen (accessory families): not in this draft (a monochrome text line "{title} · {countdown}" would follow
  `widget.lock.inline`; no reference captured).

## Copy (proposed, English)

| key | text | origin | pattern / source | level |
|---|---|---|---|---|
| `widget.countdown.gallery.name` | Next Plan | new | retro.voice.widget (gallery name Title Case: "Friend Updates", "Your Memories") | SOURCED |
| `widget.countdown.gallery.description` | See how many days until your group's next plan. | new | platform.widgetDescription (action verb first: "Keep track of your upcoming events and meetings.", HIG) + content of Apple "count down the days until your next event" | SOURCED |
| `widget.countdown.configuration.title` | Show plans from… | adapted | Retro "See photos from…" (`app_widget_config_screen_title_friend_picker`, retro.voice.widget: "…" leads to a choice) | SOURCED |
| `widget.countdown.configuration.group` | Group | verbatim | `widget.home.small.configuration.group` | SOURCED |
| `widget.countdown.configuration.allGroups` | All Groups | new | retro.voice.title-case (picker item naming a set) | SOURCED |
| `widget.countdown.empty.noPlans` | No plans yet. Tap to make one | new | retro.voice.widget ("No media. Tap to reload") | BLOCKED (no reference widget shows an empty plan state; pattern-only) |
| `widget.countdown.a11y.plan` | {plan_title} with {group_name}, {countdown} | new | platform.a11yLabel | SOURCED |

## Do-not-copy

Apple Invites' guest-count pill ("👤 15"); countdown apps' hours / minutes / seconds, "days left" (deadline framing),
count-ups ("DAYS OF SOBRIETY", "TOGETHER 135 days"), emoji titles, gradient number art; Locket's count badge and streak
pill; any `Text(_, style: .timer)` live countdown.

## Gaps

| item | status | smallest capture |
|---|---|---|
| Apple Invites small widget | not in the store images (only medium) | one home-screen screenshot of the Apple Invites small widget |
| Apple Invites widget for an event tomorrow / today | not captured | the same widget on the day before and the day of an event |
| Apple Invites widget with no upcoming event | not captured | one screenshot |
| HIG size row for 440 / 402-pt iPhones | not in the HIG table (`platform.md`) | the HIG table update, or a device screenshot measured like AI-S 08 |
