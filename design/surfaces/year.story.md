# `year.story` — the group's December year story

Reference: **Spotify Wrapped**, 2024 tap-through model (docs/SURFACES.md; MERGE_DECISIONS "Memory" M-11). Voice:
`P-YS-1` … `P-YS-5`; states use the app default voice (`yope.voice.error`). Tokens: `design/tokens/memory.json`
(`*.year.story.*`) + `design/tokens/global.json`. Copy: `design/copy/memory.json` (`year.story.*`).

What it is: from December 1 (group-local, `year_story_release_month_day`) each group that posted that year gets a
story computed by the worker (`year.compute`). One fact per card, tapped through like Wrapped 2024: moments shared
(a group-level number, docs/SPEC_FLAGS.md T3), the busiest month, the most-reacted photos (ordered, **never** with
numbers or ranks, T2), and collages from days when everyone answered the daily invitation. Every card that states a
fact can be shared as a 9:16 image. No Spotify branding, art, colours or fonts; no ranks, percentiles, leaderboards or
streaks.

## References

| image | what it verifies |
|---|---|
| `references/auto/wrapped/frames/wrapped24-rec-emilycraig-t020.png` | device recording (Android 2024): 9:16 canvas letterboxed in #111111, progress bar (inset 11, top 8, 1.8 thick, gap 3.6), chrome circles (29.6 pt, centre 48.3 pt), headline 31.6 / subline 15.4, "Share this story" row 29 pt above the bottom |
| `references/auto/wrapped/frames/wrapped24-rec-emilycraig-t020-bars-zoom2x.png` | filled / current / upcoming segments |
| `references/auto/wrapped/frames/wrapped24-rec-emilycraig-t15.533-reveal-start.png`, `-t16.400-reveal-end.png` | headline moves up 18.2 pt, subline rises 25 pt |
| `references/auto/wrapped/frames/wrapped24-rec-emilycraig-sheet-every3s.png` | card sequence; "Your top song" card (square art 66 % wide, centre 41.2 % down, text below); top-5 lists; month cards; "February 25" date form |
| `references/auto/wrapped/press/wrapped24-press-minutes.jpg` | per-card share row with the iOS share glyph; chrome (pause, sound, close) |
| `references/auto/wrapped/press/wrapped24-press-summary-sharecard.jpg` | summary: share card at ~60 % width, page dots, white "Share" pill 148 × 50, "Replay from beginning"; chrome glyph 14.9 pt |
| `references/auto/wrapped/press/wrapped25-press-minutes.png` | "Share this story" pill label size (17.7 pt) |
| `references/auto/wrapped/press/wrapped25-press-sharecards.png` | share cards are 9:16 |
| `references/auto/wrapped/press/wrapped25-press-entrypoints.png` | entry card copy ("It's time for your 2025 Wrapped", "We can't wait to show it to you.", "Let's go") |
| `references/auto/wrapped/frames/wrapped25-rec-cdragon2010-t004.800.png`, `-t258.000.png` | "We're ready for you." / "Come on down."; "One more thing..." |
| `references/auto/wrapped/frames/wrapped24-rec-xenarxoxo-sheet-every3s.png` | "Luckily, we took notes."; outro "Thanks for coming along for the ride" / "Until we meet again..." |

## Structure

**A. Entry (placed by `groups.screen`).** While `year_stories` has a row for the group with `status = 'ready'` for
the current year (from December 1): title `year.story.entry.title` (`{year}`), subtitle `year.story.entry.subtitle`,
button `year.story.entry.button`. Row component and position belong to the `groups.screen` pass.

**B. Player (full screen).**
1. **Letterbox**: the screen background is `color.year.story.letterbox`; the **canvas** (`layout.year.story.canvas`)
   is 9:16, screen width, centred vertically in the safe area, filled with `color.global.backgroundDeep`.
2. **Progress bar** at `dimension.year.story.progress.top` from the canvas top, `dimension.year.story.progress.inset`
   from both sides, segments `dimension.year.story.progress.height` thick with `dimension.year.story.progress.gap`
   between them, one segment per card (`layout.year.story.progress`): completed and current segments
   `color.year.story.progress.fill`; upcoming segments white at `opacity.year.story.progress.track`. While
   `duration.year.story.card` (4000 ms, VidDay) the current segment fills linearly; the story then advances on its own.
3. **Chrome row**, centre `dimension.year.story.chrome.centerY` below the canvas top, right-aligned:
   close circle `dimension.year.story.chrome.button` at `dimension.year.story.chrome.insetRight` from the canvas
   right, fill `color.year.story.chrome.fill`, glyph `icon.global.close` `dimension.year.story.chrome.glyph` high in
   `color.global.textPrimary`. The pause circle (`icon.year.story.pause` / `icon.global.play`) sits
   `dimension.year.story.chrome.pitch` to the left of close (auto-advance over `duration.year.story.card`, sourced by gap fill;
   M-16). Wrapped's sound toggle is not built (no audio, M-18); its logo is do-not-copy. Hit areas
   `size.global.minTouchTarget.ios` / `.android` around each circle.
4. **Card content** (below), centred; text blocks are at most `dimension.year.story.text.maxWidth` wide
   (`layout.year.story.text`): headline `fontSize.year.story.headline` / `fontWeight.year.story.headline` /
   `lineHeight.year.story.headline`, then subline `fontSize.year.story.body` / `fontWeight.year.story.body` /
   `lineHeight.year.story.body`, both `color.global.textPrimary`, `font.year.story`.
5. **Share row** on fact cards (`layout.year.story.share`): bottom `dimension.year.story.share.bottomInset` above the
   canvas bottom, centred, height `dimension.year.story.share.rowHeight`: `icon.year.story.share` (height = row
   height), `dimension.year.story.share.glyphGap`, label `year.story.share` in `fontSize.year.story.share` /
   `fontWeight.year.story.share`, `color.global.textPrimary`.
6. **Tap zones** over the canvas (`layout.year.story.navigation`): right half next, left half previous (first card:
   nothing). Chrome and share row take their own taps.

**Cards, in order** (skip a card whose data is missing; `data` is `YearStoryData` from the worker):

| # | card | content | share row |
|---|---|---|---|
| 1 | intro | headline `year.story.intro.title`, subline `year.story.intro.subtitle` | no |
| 2 | moments, setup | headline `year.story.moments.title` | no |
| 3 | moments, fact | headline `year.story.moments.count` (`{group}`, `{count}` = `data.moments_shared`), subline `year.story.moments.aside` | yes |
| 4 | busiest month | headline `year.story.busiestMonth.title` (`{month}` = `data.busiest_month.month` as `layout.year.story.monthFormat`), subline `year.story.busiestMonth.aside` | yes |
| 5 | most-reacted, setup | headline `year.story.mostReacted.title`, subline `year.story.mostReacted.aside` | no |
| 6…10 | most-reacted photo | photo card (below) for each of the first `count.year.story.listLength` ids of `data.most_reacted`, in that order; headline `year.story.mostReacted.photo` (`{name}` poster's first name, `{date}` post date as `layout.year.story.dateFormat`). No number, rank or reaction glyph anywhere | yes |
| 11 | together, setup | headline `year.story.together.title`, subline `year.story.together.aside` | no |
| 12…16 | together day | collage card for each of the first `count.year.story.listLength` entries of `data.everyone_days` (worker order, chronological): the collage image (`collages.image_path` by `collage_id`) fitted in the square, headline = the date (`layout.year.story.dateFormat`) | yes |
| 17 | teaser | headline `year.story.outro.teaser` | no |
| 18 | outro | headline `year.story.outro.title`, subline `year.story.outro.subtitle` | no |
| 19 | summary | see C | — |

**Photo / collage card** (`layout.year.story.photoCard`): a square box `boxWidthRatio` × canvas width, centred
horizontally, its centre at `boxCenterYRatio` × canvas height; photo fills the square (crop), collage is fitted
inside it on the canvas colour (M-19); square corners (`cornerRadius` 0, as the album art); headline centred `textGap` below the box.

**C. Summary** (`layout.year.story.summary`): a horizontal pager of this story's share cards (each the share image of
a fact card) at `previewWidthRatio` × canvas width; below it the **Share** pill (`dimension.year.story.summary.shareWidth`
× `dimension.year.story.summary.shareHeight`, `radius.global.capsule`, fill `color.global.surfaceLight`, label
`year.story.summary.share` in `fontSize.year.story.sharePill` / `fontWeight.year.story.sharePill`,
`color.global.onSurfaceLight`) sharing the card in view; then the text button `icon.year.story.replay` +
`year.story.summary.replay` (`fontSize.year.story.body`, `color.global.textPrimary`) going back to card 1. Page dots:
`layout.year.story.summary.dots` (Wrapped: one per share card, 8.4 pt, pitch 16.8 pt, current #FFFFFF, others #666666;
centre 20.4 pt below the carousel card, 29.3 pt above the Share pill).

**D. Share image** (`layout.year.story.shareCard`): 1080 × 1920 px render of the card's canvas without the progress
bar, chrome or share row; handed to the share sheet (`layout.year.story.shareSheet`) as a PNG.

## Elements

| element | tokens | copy keys | behaviour |
|---|---|---|---|
| letterbox / canvas | `color.year.story.letterbox`, `layout.year.story.canvas`, `color.global.backgroundDeep` | — | canvas keeps 9:16 on every phone |
| progress bar | `dimension.year.story.progress.height` / `.top` / `.gap` / `.inset`, `color.year.story.progress.fill`, `opacity.year.story.progress.track`, `easing.year.story.progress.fill`, `layout.year.story.progress`, `duration.year.story.card` (4000 ms) | — | current segment fills over the card duration |
| close | `dimension.year.story.chrome.button` / `.centerY` / `.insetRight` / `.glyph`, `color.year.story.chrome.fill`, `icon.global.close`, `color.global.textPrimary` | `year.story.a11y.close` | dismisses the player |
| pause / play | same + `dimension.year.story.chrome.pitch`, `icon.year.story.pause`, `icon.global.play` | `year.story.a11y.pause`, `year.story.a11y.play` | shown (auto-advance is on) |
| headline / subline | `fontSize/fontWeight/lineHeight.year.story.headline`, `…body`, `dimension.year.story.text.maxWidth`, `layout.year.story.text`, `font.year.story` | card keys above | reveal motion below |
| photo / collage card | `layout.year.story.photoCard`, `count.year.story.listLength`, `layout.year.story.dateFormat` | `year.story.mostReacted.photo`, `year.story.a11y.collage` | photos use `display_path` |
| share row | `layout.year.story.share`, `dimension.year.story.share.*`, `fontSize/fontWeight.year.story.share`, `icon.year.story.share` | `year.story.share` | renders D and opens the share sheet |
| summary | `layout.year.story.summary`, `dimension.year.story.summary.shareWidth/Height`, `fontSize/fontWeight.year.story.sharePill`, `radius.global.capsule`, `color.global.surfaceLight`, `color.global.onSurfaceLight`, `icon.year.story.replay` | `year.story.summary.share`, `year.story.summary.replay` | — |
| tap zones | `layout.year.story.navigation` | `year.story.a11y.next`, `year.story.a11y.previous` | halves (M-24) |

## States

| state | design | copy | source |
|---|---|---|---|
| loading (fetching the row, photos, collages) | canvas with the platform activity indicator centred (`easing.global.native` activityIndicator); text `fontSize.global.listSubtitle`, `color.global.textSecondary` | `year.story.loading` | Yope HUD word; indicator PLATFORM |
| not ready (`status = 'pending'`, `data` null) | not a screen: the entry is not shown | — | docs/API.md 5.19 |
| empty | none: a story exists only for groups that posted that year; cards with no data are skipped | — | docs/API.md 10 `due_year_stories` |
| error | centred on the canvas: text roles `emptyTitle` / `emptyDetail`, light pill `color.global.surfaceLight` + `color.global.onSurfaceLight` + `radius.global.capsule` | `year.story.error.title`, `year.story.error.detail`, `year.story.error.retry` | app default voice |
| offline | same layout | `year.story.offline.title`, `year.story.offline.detail`, `year.story.error.retry` | app default voice |
| photo deleted while open | the worker recomputes (`year.recompute`); drop the card on `post_deleted`, re-fetch on foreground | — | docs/API.md 6.2 `delete_media` |
| permission-denied | n/a; the share sheet's "save image" asks for photo-library add access itself (string owned by `system.permissions`) | — | — |

## Motion

| transition | tokens | Reduce Motion substitute |
|---|---|---|
| open / close player | native full-screen presentation (`easing.global.native`) | system |
| card → card | cut (Wrapped's chapter transitions are bespoke brand animation, not reproduced) | same |
| text reveal on a card with a subline: headline moves up `dimension.year.story.reveal.headlineShift` over `duration.year.story.reveal.headline`; subline starts `duration.year.story.reveal.sublineDelay` later from `dimension.year.story.reveal.sublineOffset` below and settles over `duration.year.story.reveal.subline` | curves `easing.year.story.reveal` (headline, cubic-bezier(0.56, 0.08, 0.14, 0.87)) and `easing.year.story.reveal.subline` (0.05, 0.36, 0.26, 0.94), fitted to all 25 / 19 samples (0.5-px residual) | cross-fade of the same durations (`layout.global.reduceMotion`) |
| progress fill | `easing.year.story.progress.fill` (linear) over `duration.year.story.card` (4000 ms) | the fill tracks time, so it stays (it is not decorative motion) |

## Haptics

None observed in Wrapped; none added. The share sheet plays its own.

## Accessibility

- **Labels / traits:** close `year.story.a11y.close`; pause / play `year.story.a11y.pause` / `year.story.a11y.play`
  (when shown); share row: its visible text, button; summary pill and replay: visible text, button. Headline:
  header trait. Photo cards: the image is decorative, the headline carries who and when; collage image
  `year.story.a11y.collage`. Progress bar: hidden (position is read on change, below).
- **Navigation:** custom accessibility actions `year.story.a11y.next` / `year.story.a11y.previous` on the canvas;
  after each change post a screen-changed / `announceForAccessibility` so the new headline is read. Auto-advance
  can be paused with the pause control (WCAG 2.2.2 Pause, Stop, Hide).
- **Dynamic Type** (`layout.year.story.textStyleMap`): headline `largeTitle`, subline `subheadline`, share label
  `callout`, Share pill `headline`. Text wraps inside `dimension.year.story.text.maxWidth`; at accessibility sizes
  the block may grow past the photo box — keep the box and push the text down. The share image always renders at the
  default size.
- **Focus order:** close (and pause) → headline → subline → photo → share row.
- **Contrast:**

  | pair | ratio | needs | result |
  |---|---|---|---|
  | `color.global.textPrimary` on `color.global.backgroundDeep` (all card text) | 21.00 | 4.5 | pass |
  | `color.year.story.progress.fill` vs upcoming track (white 0.43 on black = #6E6E6E) | 5.10 | 3 | pass |
  | upcoming track #6E6E6E vs canvas #000000 | 4.12 | 3 | pass |
  | close / pause glyph white on `color.year.story.chrome.fill` over the canvas | 21.00 | 3 | pass |
  | `color.year.story.chrome.fill` circle vs canvas | 1.00 | 3 | **FAIL** (circle invisible on black; the glyph carries the control — reported) |
  | `color.year.story.letterbox` vs canvas | 1.11 | — | decorative boundary, not a component |
  | `color.global.onSurfaceLight` on `color.global.surfaceLight` (Share pill) | 21.00 | 4.5 | pass |

## Data & actions

- **Read:** `from("year_stories").select().eq("group_id", g).eq("year", y).single()` → `status`, `data`
  (`YearStoryData` v1: `moments_shared`, `busiest_month.month`, `most_reacted` post ids, `everyone_days`
  `{local_date, collage_id, post_ids}`). Then `posts` + `media` (renditions) and `profiles` for most-reacted ids
  (RLS drops posts hidden by a block — skip those), `collages` by id (`image_path`, show only `status = 'ready'`).
  Signed URLs, 1 h. Dates in the group time zone (`data.time_zone`).
- **Writes:** none. Share images are rendered on the device.
- **Realtime:** `group:<group_id>` `post_deleted` → drop that card.
- **Navigation in:** the entry on `groups.screen`; deep link `DeepLink.yearStory(groupID:year:)` /
  `app://year-story?group=<id>&year=<yyyy>` (`ios/Packages/AppCore/Sources/AppModels/DeepLink.swift`,
  `android/core/model/src/main/kotlin/app/model/DeepLink.kt`). Push type `year_story` exists in the contract but is
  not sent (not in the directive's notification list; owner decision). **Out:** close → group screen; share sheet.

## Platform notes

- iOS: `.fullScreenCover`, status bar hidden over the letterbox; share via `ShareLink` / `UIActivityViewController`
  with the PNG. Android: full-screen destination, edge-to-edge, system bars hidden with transient reveal; share via
  `Intent.createChooser(ACTION_SEND)` with a `content://` URI from a `FileProvider`.
- Rendering the share image: iOS `ImageRenderer` of the card view at 1080 × 1920 px; Android draw the composable into
  a `GraphicsLayer` / `Picture` at that size.
- Android's share glyph is `Rounded.Share` (Wrapped Android), not the app's `Rounded.IosShare`.

## Do-not-copy

Spotify logo, colours, card art, Spotify Mix / Circular, logo animations and stings; percentile / rank comparisons
("top 8% of listeners", "top 0.5% fan"); numbered top-5 lists (the order is kept, the numbers are not); Fan
Leaderboard, Wrapped Party awards, streak chips; consumption counts as achievements ("You overachiever.", "Where do
you find the time?", "Commitment never sounded so good."); per-person counts of any kind; the sound toggle; the 2025
vertical-swipe coach mark (other navigation model); AI-written report pages.

## Gaps

| item | status | owner capture that closes it |
|---|---|---|
| `duration.year.story.card` (auto-advance) and the pause control | SOURCED by gap fill: 4000 ms (VidDay's documented card time, confirmed in its render; MERGE G2-18); Wrapped's own per-fact time unknown | 30 s iPhone recording of Wrapped "Your Stories" replay with show-touches on: taps left / right and a press-and-hold (research capture 1) |
| tap-zone widths, hold-to-pause | halves; no hold | same recording |
| `easing.year.story.reveal`, `.reveal.subline` | SOURCED by gap fill: fitted to the existing 30 fps samples (MERGE G2-19) | one 60 fps recording of any Wrapped card whose subline appears |
| `layout.year.story.summary.dots` | SOURCED by gap fill: measured on the Wrapped 2024 press render (JPEG, ±0.9 pt; MERGE G2-20) | one full-resolution screenshot of the Wrapped summary screen |
| text block width | lower bound 274 pt (`dimension.year.story.text.maxWidth`) | same recording at full resolution |
| iOS placement of the chrome | from an Android recording | one iOS screenshot of a Wrapped card |
| "Share" pill label size (2024) | 2025 pill label used | summary screenshot above |
| everyone-days selection | first five in worker order (chronological) | owner decision (spread across the year?) |
| moments-shared number (T3), most-reacted ordering (T2) | built as specified | owner decision (docs/SPEC_FLAGS.md) |
