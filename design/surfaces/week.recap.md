# `week.recap` — Sunday recap of the group's week

Reference app: **Yope** recaps, organised by **week** (Monday–Sunday, per Retro) (`docs/SURFACES.md`). Research:
`design/research/yope-b.md` §6, §8 (C1, C2); `design/research/retro-timehop.md` (week boundaries); docs/API.md §5.14, §11.
Tokens: `design/tokens/social.json` (`week.recap.*`) + `global.*`. Copy: `design/copy/social.json` (`week.recap.*`).
The recap is created by the worker on **Sunday** (`weekly_recap_isodow` = 7) at `weekly_recap_local_time` (owner, NULL
until set — recaps are off until then) for groups that posted that week.

Yope's 2026 builds present recaps as free-form "walls" (v1.214.0 "recaps are now walls"), whose composition is not
observable; the only measured recap screen is the owner's week-recap frame (O3), so O3 is the reference (S-15).

## References

| id | file | used for |
|---|---|---|
| O3 | `references/owner/yope-week-recap.jpg` (CAPTURED, ≈Dec 2025 / Jan 2026, 0.888 pt/px) | **primary**: header title, recap card grid, label, page dots, full-bleed pics grid, floating "recap \| pics" capsule |
| O2 / S2 | `references/owner/yope-03-recaps-collage.webp`, `references/auto/yope/store/yope-store-04.png` | recap scrapbook marketing panel ("today", "share") — context only |
| S6 | `references/auto/yope/frames/b-alexaa-7652512140875566349-t5.33-day-view-recap.png` | "view recap" entry pill (2026-06) |
| S1 | `references/auto/yope/store/yope-store-05.png` | film-strip header circle that opens recaps |
| collage options | `design/collage-options/README.md` Option A | the same recap-card grid rules (and the same open gaps) |

## Structure (top → bottom; one vertical scroll)

Background `color.global.background` (O3 JPEG #121011, within ±6).

1. **Header** (floats): ‹ circle top-left (`size.global.headerButton`, `color.global.controlOnDeep` — O3 #0A0809 —
   `icon.global.back`, `size.global.headerInset`); title centred: the week label in `week.recap.layout.weekFormat` title
   form ("18 aug-24 aug"), `week.recap.fontSize.title` / `.fontWeight.title`, `color.global.textPrimary`; pencil circle
   top-right (same circle, `icon.global.edit`) → `week.edit` (composition flagged, S-13: Yope's edit control was not
   observed; the pencil circle is Yope's send-to header button).
2. **Recap card** (page 1 of a horizontally paged card), width `week.recap.dimension.cardWidth` (334) centred, corners
   `week.recap.radius.card` (12) outside, square inside:
   - grid of the recap's items in `weekly_recaps.items` order: the row holding the leftover 1–2 photos first, spanning the
     full card width (`week.recap.layout.shortRow`; its split **BLOCKED** `week.recap.layout.shortRowSplit`, its height
     **BLOCKED** `week.recap.dimension.shortRowHeight`), then full rows of `week.recap.count.gridColumns` (3) tiles shaped
     `week.recap.aspectRatio.gridTile` (111 : 167), gaps `week.recap.dimension.gridGap` (0), aspect fill;
   - bottom scrim (**BLOCKED** `week.recap.layout.scrim`) and the week label in uppercase (`week.recap.layout.weekFormat`
     label form, "18 AUG-24 AUG"), `week.recap.fontSize.label` / `.fontWeight.label`, `color.global.textPrimary`, at
     `week.recap.dimension.labelInsetLeading` from the left, baseline `week.recap.dimension.labelBaselineBottom` above the
     card bottom. No wordmark / @handle.
   - Page 2 (two page dots in O3): **BLOCKED** (`week.recap.layout.page2`); the recap text (`weekly_recaps.text`) is shown
     there once captured. Until then the card has one page and the dots are hidden.
3. **Page dots** `week.recap.dimension.cardToDots` below the card, centred: `week.recap.dimension.pageDot` circles at
   `week.recap.dimension.pageDotPitch`; current `color.global.textPrimary`, others `color.global.controlRaised`.
4. **Week pics grid**, `week.recap.dimension.dotsToPics` below the dots, full screen width (no side inset):
   `week.recap.count.picsColumns` (3) columns, gaps `week.recap.dimension.picsGap` (1), tiles
   `week.recap.aspectRatio.picsTile` (131 : 175, 3:4), square corners; every visible post of that week in chronological
   order (`group_history_weeks.post_ids`), not only the recap's items.
5. **Floating segmented capsule** "recap | pics", centred, bottom `week.recap.dimension.segmentedBottom` above the screen
   bottom: track `week.recap.dimension.segmentedWidth` × `.segmentedHeight`, `radius.global.capsule`, fill
   `color.global.control` (O3 #292526–#2B292A, within ±6); selected pill `week.recap.dimension.segmentedPillWidth` ×
   `.segmentedPillHeight`, inset `week.recap.dimension.segmentedInset`, `color.global.surfaceLight`, capsule; labels
   `week.recap.segment.recap` / `week.recap.segment.pics`, `week.recap.fontSize.segmented` / `.fontWeight.segmented`,
   selected `color.global.onSurfaceLight`, unselected `color.global.textPrimary`. "recap" = scroll to the card; "pics" =
   scroll to the pics grid; scrolling updates the selection (approximation, Gaps).

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| ‹ circle | `size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.back` | `chat.thread.a11y.back` | pops |
| title | `week.recap.fontSize.title`, `.fontWeight.title`, `color.global.textPrimary`, `week.recap.layout.weekFormat` | week label (data) | header trait |
| pencil circle | `size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.edit` | `week.recap.a11y.edit` | opens `week.edit` (status `ready` only) |
| recap card | card tokens above | `week.recap.a11y.card` | tile tap → `photo.viewer` (context = recap items in order) |
| week label | `week.recap.fontSize.label`, `.fontWeight.label`, `.dimension.labelInsetLeading`, `.labelBaselineBottom` | week label uppercase (data) | — |
| page dots | `week.recap.dimension.pageDot`, `.pageDotPitch`, `.cardToDots`; `color.global.textPrimary` / `color.global.controlRaised` | — | hidden while one page |
| pics grid | `week.recap.count.picsColumns`, `.dimension.picsGap`, `.aspectRatio.picsTile`, `.dimension.dotsToPics` | `photo.viewer.a11y.photo` | tap → `photo.viewer` (context = the week's posts) |
| segmented capsule | segmented tokens above | `week.recap.segment.recap`, `week.recap.segment.pics` | see Structure 5 |

## States

| state | what shows | tokens / copy | source |
|---|---|---|---|
| loading | Yope loading HUD centred | `groups.create.size.hud`, `groups.create.color.hud`, `groups.create.fontSize.hudLabel`, `chat.thread.radius.loadingHud` (10.5); `groups.create.hud.loading` | yope-a §1.8 |
| pending (`status = pending`) | centred bold line, no pill | text role `emptyTitle`; `week.recap.pending` | `yope.voice.confirmation` |
| empty (no ready recap yet) | centred bold title, gray detail, white pill | `week.recap.empty.title`, `.empty.detail`, `.empty.action` ("share a pic" → `camera.capture`); text roles `emptyTitle` / `emptyDetail`; pill `color.global.surfaceLight` / `.onSurfaceLight`, `groups.screen.size.lightPillHeight`, `groups.screen.radius.lightPill` | `yope.voice.empty-state` (Yope's "Add 20 pics more to get a recap" is a progress count: do-not-copy) |
| error | same layout as empty, retry pill | `week.recap.error.title`, `chat.thread.error.detail`, pill `chat.thread.error.retry` | `yope.voice.error` |
| offline | cached recap; nothing cached → `chat.thread.offline.title` / `.offline.detail` | — | `yope.voice.error` |
| permission-denied | not applicable | — | — |

## Motion

| transition | tokens | Reduce Motion |
|---|---|---|
| push / pop | native (`easing.global.native.navigationPush`) | system |
| card paging (when page 2 exists) | native paging (`easing.global.photoSwipe` rule: system paging physics) | finger-tracking stays |
| segment change | not observed: the pill moves with the platform default spring (`spring.global.platformDefault.ios` / `.android`), scroll uses the system scroll animation | pill jumps; scroll without animation |

## Haptics

| interaction | token |
|---|---|
| segment selected | `haptic.global.select` |

## Accessibility

- Card: one element labelled `week.recap.a11y.card` with a "photos" rotor / custom action to step tiles; each tile
  `photo.viewer.a11y.photo`. Segmented capsule exposed as a segmented control (2 items, selected trait). Page dots as a
  page control (adjustable) once there are two pages.
- Dynamic Type: title → `week.recap.layout.textStyleMap.title` (headline); label → `.label` (title3); segments → `.segmented`
  (headline). The card label stays one line (shrinks to fit within the card width).
- Focus order: back → title → pencil → card → dots → pics grid → segmented capsule.
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | ratio | result | pair |
|---|---|---|---|---|---|
| `color.global.textPrimary` #FFFFFF | `color.global.background` #171717 | text | 17.93:1 | pass | title 17 semibold |
| `color.global.textPrimary` #FFFFFF | `color.global.controlOnDeep` #101010 | nontext | 19.03:1 | pass | ‹ / pencil glyphs |
| `color.global.controlOnDeep` #101010 | `color.global.background` #171717 | nontext | 1.06:1 | **FAIL** | header circle against the background |
| `color.global.controlRaised` #434343 | `color.global.background` #171717 | nontext | 1.81:1 | **FAIL** | inactive page dot |
| `color.global.textPrimary` #FFFFFF | `color.global.background` #171717 | nontext | 17.93:1 | pass | active page dot |
| `color.global.onSurfaceLight` #000000 | `color.global.surfaceLight` #FFFFFF | text | 21.00:1 | pass | selected segment label |
| `color.global.textPrimary` #FFFFFF | `color.global.control` #2E2E2E | text | 13.58:1 | pass | unselected segment label |
| `color.global.surfaceLight` #FFFFFF | `color.global.control` #2E2E2E | nontext | 13.58:1 | pass | selected pill against the track |

  The inactive dot fails 3:1; the current page is also conveyed by the page control's accessibility value. Card label on
  the BLOCKED scrim: not computable.

## Data & actions

- **Reads**: `weekly_recaps` (§5.14: `items` ordered post ids — fetch from `posts`, RLS drops hidden ones; `text`; `status`;
  `week_start`); `group_history_weeks(p_group_id, …)` (§6.4) for the week's `post_ids` (pics grid); `posts` / `media`
  (`thumb_path`).
- **Realtime**: `post_deleted` → drop the item from card and grid (§8.2); the recap row itself is not published — refetch
  on foreground.
- **Push**: `notifications.push.recapReady.title` / `.body` ("new recap added"; design/copy/capture.json), push type
  `recap_ready`.
- **Navigation in**: chat header film-strip circle (`chat.thread`), "view recap" pill (`groups.screen`), `week.history` week
  menu, `albums.list` empty action, deep link `DeepLink.recap(groupID:recapID:)` (`app://recap?group=…&recap=…`).
- **Navigation out**: `week.edit`, `photo.viewer`.

## Platform notes

- iOS: one `ScrollView` with the card (`TabView(.page)` once page 2 exists) and a `LazyVGrid`; floating capsule in
  `.safeAreaInset(edge: .bottom)`. Android: `LazyVerticalGrid` with the card as a full-span item; capsule in a `Box` overlay.
- Week label from the group's time zone (`groups.time_zone`), Monday start (`week_start_isodow` = 1).

## Do-not-copy

- Wordmark + "@handle" watermark on the card.
- "Add {n} pics more to get a recap" progress bar / count; "skip the queue and create one now" (on-demand recaps do not exist).
- Streaks; Wrapped-style counts.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| `week.recap.layout.shortRowSplit`, `week.recap.dimension.shortRowHeight` | BLOCKED (gap fill: Yope-specific card; no other app shows it) | one screen recording of a Yope weekly recap card for a week with only 2–5 photos (also closes collage Option A) |
| `week.recap.layout.page2` (+ where the recap text shows) | BLOCKED (Yope-specific content) | 20-s recording: open a weekly recap, swipe pages, toggle recap/pics, tap edit/remix, save (yope-b §14 capture 4) |
| `week.recap.layout.scrim` | BLOCKED (gap fill: Apple Photos / Google Photos title gradients sit on photo content and cannot be separated) | one lossless export of a Yope recap card |
| segmented behaviour (scroll vs filter) and its motion | approximation | same 20-s recording |
| pencil entry to edit | composition from the send-to header (S-13) | same recording |
| 2026 wall-style recaps | not built (free-form; S-15) | same recording |
