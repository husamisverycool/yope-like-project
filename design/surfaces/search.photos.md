# `search.photos` — find a photo by what was said about it, who is in it, or when

Owner decision 34 (research #6). Visual reference: Retro's **pushed Albums page with its search field** (screen 11,
ED-W3: back chevron + serif title, 52-pt search field) over Retro's **album photo grid** (C-21, TC-J1). Mechanics: Retro's
albums search (App Store story https://apps.apple.com/us/story/id1854931006), **Yope's search on the group list**
(https://www.tiktok.com/@savannahclooney/video/7683341732695592206; design/research/yope-a.md §2.9 — the search circle
in Yope's home header) and Apple Shared Albums' people and date filters (https://support.apple.com/en-us/108314).
Server: `search_photos` (migration 0040, docs/API.md). Tokens: `search.photos.*` + `global.*`
(`design/tokens/social.json`). Copy: `search.photos.*` (`design/copy/social.json`).

What it searches: the words of a caption or of the chat about a photo (its comments in the viewer and replies in the
chat), a member (who posted it, or who tagged themselves "I'm in this"), and the day it was taken. **No face search,
no AI image search** (directive). **No count of results** anywhere ("12 results" is forbidden — tenet 2).

## References

| id | file | used for |
|---|---|---|
| ED-W3 | `references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png` | **primary**: pushed header (C-02), search field (C-12) |
| TC-J1 | `references/auto/retro/press/tc-2024-04-journals-1.webp` phone 3 | 3-column photo grid with 2 pt gaps (C-21) |
| YP-A | design/research/yope-a.md §2.9, §1.7 | search glyph in the group list's header (`magnifyingglass` / `search`) |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | "Search", "No matching users", "Error loading friends. Tap here to try again.", "Cancel", "Done" |
| ASA | https://support.apple.com/en-us/108314 | people / date filters on shared photos |

## Entry

- `groups.list`: the header glyph `icon.global.search` (only while you have a group) → all your groups.
- `groups.screen`: the header glyph `icon.global.search` (first of the row's glyphs) → this group (`p_group_id`).
- Both labelled `search.photos.open`.

## Structure (pushed; page `color.global.background` / `.background.android`; one vertical scroll)

`search.photos.layout.composition`:

1. **Header** (C-02): back chevron + `search.photos.title` ("Search") in the display serif.
2. **Search field** (C-12) `size.global.titleToContent` below the title baseline, inside `size.global.screenMargin`:
   `icon.global.search` + placeholder `search.photos.field`; accessibility label `search.photos.field.a11y`; the keyboard's
   search key runs the search.
3. **Filter chips**, one row `size.global.sectionHeaderToContent` below the field, from `size.global.screenMargin`,
   scrolling sideways, chips `size.global.pillGap` apart — the C-06 toggle ("I'm in this": outline off, primary on):
   - **date**: `search.photos.date` ("Date"); with a range chosen, the range in the locale's interval format ("Oct 3 – 9",
     "Sep 28 – Oct 4, 2025") in the on state. Off → the native picker: iOS a sheet with two date pickers
     (`search.photos.date.start` / `.end`) and the toolbar `search.photos.date.cancel` / `search.photos.date.done`; Android
     the Material 3 date range picker dialog with `search.photos.date.done` / `search.photos.date.cancel`. On → tapping clears it.
   - **members**: you first (`search.photos.member.you`), then the members by joining order (first names; from all your
     groups each person once). One member at a time: choosing another moves the selection; tapping the chosen one clears it.
4. **Results** (C-21 album grid): `search.photos.count.gridColumns` (3) square cells, `size.global.stripGap` apart, full
   width inside `size.global.screenMargin`, `size.global.titleToContent` below the chips; newest first in `search_photos`
   order; the next page (60) loads when the end is reached (`p_before` = the last `created_at`). A video carries the
   video marker (`layout.global.videoMarker`). A cell → `photo.viewer` with the results in this order (from all groups: the
   header's second line names the group, as from a wall).

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| back + title | C-02; text role `headerTitle` | `chat.thread.a11y.back`; `search.photos.title` | pops |
| search field | C-12; `size.global.fieldHeight`, `radius.global.field`, `color.global.control` | `search.photos.field`, `search.photos.field.a11y` | search key → search |
| date chip | C-06 toggle; `size.global.pillHeight`, `size.global.pillGap` | `search.photos.date` / the range (data) | off → picker; on → clears |
| date sheet (iOS) | C-29 page sheet, native `DatePicker` rows (C-14) | `search.photos.date`, `.start`, `.end`, `.cancel`, `.done` | Done → search |
| date dialog (Android) | C-29 M3 `DateRangePicker` | `search.photos.date.done`, `.cancel` (the picker's own labels are the platform's) | Done → search |
| member chip | C-06 toggle | `search.photos.member.you`; first names (data) | one at a time → search |
| result cell | C-21 square cell, `radius.global.photo` | `photo.viewer.a11y.photo` ({name}'s photo, {date}) + `chat.thread.a11y.video` for a video | → `photo.viewer` |

## States

| state | what shows | components · tokens · copy | source |
|---|---|---|---|
| idle (nothing typed, no chip on) | C-27 block `size.global.sectionGap` below the chips: `icon.global.search` → title → explanation | `search.photos.idle.title`, `search.photos.idle.detail` | `retro.voice.empty-state` |
| loading | two rows of C-17 placeholder cells (`color.global.control`) in the grid's place | C-28; `week.history.a11y.loading` | C-28 |
| loading more | C-28 activity indicator under the grid | `easing.global.native.activityIndicator` | C-28 |
| empty (nothing matches) | C-27 title only, `size.global.sectionGap` below the chips | `search.photos.empty.title` ("No matching photos") | APK-S (adapted) |
| error | one tappable line (text role `body`, `color.global.textSecondary`) under the chips; tap searches again | `search.photos.error` | `retro.voice.error` |
| offline | the same line with the offline copy; tap searches again | `search.photos.offline` | `retro.voice.error` |
| permission-denied | not applicable | — | — |

Light and dark: page, field, chips and text follow the global colours in both appearances; nothing on this page is a media
surface.

## Motion

Push / pop native; results appear with `duration.global.fade`; chip toggles crossfade (`duration.global.crossfade`, C-06);
the date sheet / dialog is native. Reduce Motion: system.

## Haptics

| interaction | token |
|---|---|
| a chip toggles | `haptic.global.select` (C-06 toggle) |
| tap a cell (Android) | `haptic.global.tap` (iOS none) |

## Accessibility

- Field: search-field trait, label `search.photos.field.a11y` (the placeholder is not the label, C-12).
- Chips: buttons with the selected trait / checkbox role when on (C-06 toggle); the date chip's label is "Date" or the
  spoken range.
- Cells: one button each, `photo.viewer.a11y.photo` (who, the day it was taken).
- No result count is announced; the busy state is (`week.history.a11y.loading`).
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | light | dark | pair |
|---|---|---|---|---|---|
| `color.global.textPrimary` | `color.global.background` | text | 21.00:1 pass | 21.00:1 pass | title, outline chips |
| `color.global.textSecondary` | `color.global.control` | text | **2.52:1 FAIL** | 5.31:1 pass | search placeholder (C-12 failure 1) |
| `color.global.onAccent` | `color.global.accent` | text | 21.00:1 pass | 21.00:1 pass | chosen chip |
| `color.global.textSecondary` | `color.global.background` | text | **2.85:1 FAIL** | 7.37:1 pass | idle explanation, error / offline line |

## Data & actions

- `search_photos(p_text, p_group_id, p_member_id, p_from, p_to, p_before, p_limit: 60)` (docs/API.md, migration 0040):
  `p_text` = the field's text trimmed (null when empty); `p_group_id` = the group when opened from `groups.screen`;
  `p_member_id` = the chosen member; `p_from` / `p_to` = the chosen days (the group's time zone applies server-side).
  At least one criterion, else idle (no call). Rows: `post_id`, `media_id`, `group_id`, `author_id`, `created_at`,
  `matched` (not shown).
- Then `posts` + `media` (thumbnails) for the rows, `profiles` for the cells' labels; members from `group_members`
  (+ `profiles`) of the group, or of every group you are in.
- A new search replaces the results; an answer to an older search is dropped.
- Realtime: none (a search is a moment's answer); searching again refreshes.
- Navigation in: `groups.list`, `groups.screen`. Out: `photo.viewer`.

## Platform notes

- iOS: `ScrollView` with a `LazyVGrid` (C-21 `PhotoGrid`), `SearchField` (C-12), `CapsuleToggle` chips; `DatePicker(.date)`
  rows in a `.sheet` with `sheetToolbar`.
- Android: `LazyVerticalGrid` with the header, field and chips as full-span items; `SearchField`; `CapsuleToggle`; M3
  `DatePickerDialog` + `DateRangePicker`.

## Do-not-copy

- Result counts ("12 results", "N photos"), "Top results" / relevance ranking, face or people-recognition filters, AI
  "things" search (Google Photos), location filters (no location is kept), search history and suggestions.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| Retro's own search results page | not captured — composed from ED-W3's field and TC-J1's grid | one screenshot of a Retro album search with results |
| field → chips spacing | `size.global.sectionHeaderToContent` (composition; no reference shows filter chips under Retro's field) | — |
