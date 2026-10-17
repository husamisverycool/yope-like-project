# `groups.list` — group list (home)

Visual reference: **Retro Albums list** (inventory #10 root, #11 pushed with search; ED-W3, ED-A, TC-J1 phone 2) with the
"Ideas to Get Started" templates (#12, JED phone 3) and Retro's tab bar (H43 / H22). Tokens: `groups.list.layout.tabBar`
+ `global.*`. Copy: `groups.list.*` (+ `groups.create.type.*` for the template rows). Components: C-01, C-15, C-23, C-11,
C-06, C-04, C-27, C-28.

## References

| id | file | used for |
|---|---|---|
| ED-W3 | `references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png` (3.89 px/pt, geometry only) | row pitch 119.5, 72 × 97 cover r ≈ 4, text at thumbnail + 17, subtitle with the actor in semibold, avatar stack, 36 pt "+" Fill circle, header glyph `icon.global.newAlbum` |
| TC-J1 | `references/auto/retro/press/tc-2024-04-journals-1.webp` phone 2 | serif "Journals" title with the new-album glyph; rows "you shared a post" / "nathan shared a post" |
| JED | `references/auto/retro/press/jeddacp-2024-05-home-profile-journals.png` phone 3 | "Ideas to Get Started" header + "•••"; template rows (cover, title, 2-line grey description, Fill "Create" pill) |
| H43, H22 | `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png`, `…-20260528-week22-dark-a.png` | title metrics (C-01), tab bar (C-04), dark values |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `journals_tab_screen_title`, `journal_tab_context_line_*`, `journal_tab_suggestion*`, `journal_tab_empty_state_*`, `journal_tab_loading_error` |

## Structure (page `color.global.background` / `.background.android`; vertical scroll; tab bar fixed)

1. **Header (C-01)**: serif title `groups.list.title` (`font.global.display`, text role `headerTitle` 40,
   `color.global.textPrimary`) at `size.global.screenMargin`, baseline `size.global.titleTop`; trailing glyphs
   (C-01, `size.global.headerIconPitch` apart): while you have a group, `icon.global.search` → `search.photos` over all
   your groups (Yope puts search on its group list — design/research/yope-a.md §2.9; owner decision 34, research #6),
   then `icon.global.newAlbum` (ink at `size.global.headerInset`, hit `size.global.headerButton`) → `groups.create`.
2. `size.global.titleToContent` below the title baseline: **group rows (C-15)**, newest activity first, thumbnails
   `size.global.listGap` (22.5) apart (row pitch 119.5), inside `size.global.screenMargin`:
   - cover thumbnail `size.global.rowThumbWidth` × `.rowThumbHeight` (72 × 97, 3:4), `radius.global.thumbnail` (4),
     aspect-fill; no cover → `color.global.control` fill with `icon.global.group` centred in `color.global.textSecondary`;
   - text block `size.global.rowThumbGap` (17) after it, vertically centred on the thumbnail: group name (text role
     `listTitle`, `color.global.textPrimary`, one line, tail truncation); subtitle (text role `listSubtitle`,
     `color.global.textSecondary`, the actor — `{first_name}` or "you" — in semibold); member avatar stack (C-23,
     `size.global.avatarSmall`, overlap `size.global.avatarStackOverlap`, joining order) below the subtitle;
   - trailing "+" circle (C-11 on the page: `size.global.circleButton`, `color.global.control`, `icon.global.add`
     `color.global.textPrimary`), ink at the right margin, centred on the thumbnail.
3. `size.global.sectionGap` (36.4) below the last row: **"Ideas to Get Started"** section — header
   `groups.list.ideas.title` (text role `sectionLabel`, `color.global.textPrimary`) at the margin; then one template row
   per group kind in `group_kind` order (friends · family · roommates · custom), same C-15 geometry:
   thumbnail = the kind's **cover photo** (`groups.list.layout.templateCovers`, owner decision 9: people-free sample
   photos bundled with the app — friends a road-trip window, family a birthday cake, roommates dinner on the table,
   custom a lake at sunset; aspect-fill, `radius.global.thumbnail`, `color.global.control` behind it), title `groups.create.type.<kind>`
   (`listTitle`), description `groups.create.type.<kind>.detail` (`listSubtitle`, `color.global.textSecondary`, ≤ 2 lines),
   trailing **fill capsule** C-06 (`color.global.control`, label `groups.create.type.create` text role `pill`, height
   `size.global.pillHeight`, hugging its label with 12 / 8 padding) at the right margin.
4. Tab bar (C-04, `groups.list.layout.tabBar`) over the bottom safe area; the list scrolls under it with its last row
   clear of the bar.

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| title | C-01 | `groups.list.title` | header trait |
| search glyph | C-01 trailing glyph `icon.global.search` (only with at least one group) | `search.photos.open` | → `search.photos` (all groups) |
| new group glyph | C-01 trailing glyph `icon.global.newAlbum` | `groups.list.header.add.accessibilityLabel` | → `groups.create` (type step) |
| group row | C-15 + C-23 | `groups.list.row.accessibilityLabel` ({group_name}, {subtitle}) | tap → `groups.screen` (push) |
| subtitle | `listSubtitle`, actor semibold | newest post by someone else: `groups.list.row.sentPic` ({first_name}); by you: `groups.list.row.newPic`; no posts: `groups.list.row.createdByYou` / `.createdBy` ({first_name}) / `.noPics` (creator unknown) | updates live (realtime `posts` inserts) |
| avatar stack | C-23 stack; members in joining order, as many as fit the text column (no "+N", no count) | — | part of the row element |
| "+" circle | C-11 | `groups.list.row.camera.accessibilityLabel` ("Add to {group_name}") | → `camera.capture` with the group preselected (`DeepLink.camera(groupID:)`) |
| ideas header | `sectionLabel` | `groups.list.ideas.title` | static (Retro's "•••" after the header is not built — its menu was not captured) |
| template row | C-15 geometry with the kind's cover (`groups.list.layout.templateCovers`); C-06 fill capsule | `groups.create.type.*`, `.detail`, `groups.create.type.create` | Create → `groups.create` at its name step with that kind preselected |
| tab bar | C-04 + `groups.list.layout.tabBar` (`icon.global.camera`, `.home`, `.group`, `.wall`; selected `color.global.textPrimary`, unselected `color.global.tabInactive`) | `groups.list.tab.camera.accessibilityLabel`, `.groups`, `.walls`, `.me` | camera → `camera.capture`; groups = this screen; walls → `walls.browse`; me → `walls.mine` |

## States

| state | when | design | copy |
|---|---|---|---|
| loading | first fetch, nothing cached | C-28: three C-15 rows whose thumbnails are `color.global.control` placeholders (no text) — Retro's placeholder-tile loading form; ideas section hidden | — |
| default | ≥ 1 group | as Structure | as above |
| empty | no groups | C-27 block centred between the header and the ideas section: glyph `icon.global.albums` → title `groups.list.empty.title` → explanation `groups.list.empty.detail` → outline CTA C-07 (`icon.global.add` + `groups.list.empty.button`) → `groups.create`; the ideas section follows | `groups.list.empty.*` |
| error | fetch failed, nothing cached | one tappable line centred under the header (Retro list error): text role `body`, `color.global.textSecondary` | `groups.list.error.title` (tap = retry) |
| offline, nothing cached | no connection | C-27 block without glyph or action | `groups.list.offline.title`, `.detail` |
| offline with cache | cached rows; nothing else changes | — | — |
| permission-denied | — | not applicable | — |

Light and dark: same layout; colours follow the appearance (ED-W3 / TC-J1 / JED light; H43 / H22 dark tab bar and title).

## Motion

- Push to `groups.screen`: native (`easing.global.native` navigationPush; Retro's push not captured, R-14).
- Pull-to-refresh: system refresh control (Retro's not captured).
- Rows reorder when activity changes: cross-fade `duration.global.crossfade` (100 ms); a new row fades in
  `duration.global.fade` (150 ms) with `easing.global.standard`. Reduce Motion: cross-fades only (`layout.global.reduceMotion`).

## Haptics

Row, "+", template "Create", tab presses → `haptic.global.tap` (Android VIRTUAL_KEY; iOS none). Pull-to-refresh: system.

## Accessibility

- Each row is one button (name + subtitle; the avatar stack is hidden from assistive technology); the "+" circle is a
  separate button. Template rows: one element (title + description) plus the Create button.
- Tabs: buttons with labels, selected trait on the current tab, no count values.
- Dynamic Type: title `largeTitle`; name, subtitle `subheadline`; section header `subheadline`; capsule `subheadline`.
  Rows grow with their text (minimum = the thumbnail height); the thumbnail keeps 72 × 97.
- Focus order: title → search → new group → rows (row, +) → ideas header → template rows (row, Create) → tab bar.
- Contrast (`design/CONTRAST.md`):

| pair | light | dark |
|---|---|---|
| title / name `textPrimary` on page | 21:1 pass (row 1) | 21:1 / 17.01:1 Android (rows 1–2) |
| subtitle / description `textSecondary` 15 on page | **2.85:1 FAIL** (row 3) | 7.37:1 pass |
| "+" glyph on #F1F1F1 / #262626 circle | 18.59:1 pass (row 10) | 15.13:1 pass |
| "Create" label on fill capsule | 18.59:1 pass (row 9) | 15.13:1 pass |
| circle / fill capsule / placeholder vs page (non-text) | **1.13:1 FAIL** (row 13) | **1.39:1 FAIL** |
| tab unselected vs page; selected vs unselected | **2.12:1 FAIL** / 9.90:1 (rows 22–23) | 7.37:1 / **2.85:1 FAIL** |

  All failures are Retro's own palette (R-13): reported, not adjusted.

## Data & actions

- `groups` (member rows; RLS) + `group_members` (avatars, joining order) + `profiles` (first names, avatars) + the newest
  `posts` row per group (docs/API.md §5.8) + `groups.created_by` for the no-post subtitle + signed URLs for covers and
  avatars (§7).
- Realtime: `posts` inserts per group (§8.1) update subtitles and order; refetch on foreground / reconnect (§8.3).
- In: launch with a session when the person is in **no group** (owner decision 13: Retro's empty home leads with its
  templates; a camera with nobody to send to is a dead end — with ≥ 1 group the app opens to `camera.capture`, the cached
  list deciding, else the first fetch; offline with nothing cached counts as none), end of onboarding, back from a
  group, the tab bar. iOS `AccountSession.start` (window on `LaunchingView` until the check answers), Android `RootGate`.
- Out: `groups.screen`, `groups.create` (type step or a preselected kind), `camera.capture` (`DeepLink.camera`),
  `walls.browse`, `walls.mine`.

## Platform notes

- iOS: custom `ScrollView` + `LazyVStack`, custom tab bar (C-04: the system `TabView` bar draws labels and a material).
- Android: `LazyColumn`, custom bottom bar (Retro's Compose bar has no M3 indicator); page `color.global.background.android`.
- `DeepLink.camera` carries an optional group id on iOS and `DeepLink.Camera(groupId)` on Android; rows always pass one.

## Do-not-copy

- Counts in subtitles ("shared 2 posts") and Retro's "N new" badges; the user-styled title on Retro's cover thumbnails
  (this app has no cover-title editor); Retro's sample template photos (Retro assets — ours are Unsplash photos with no
  person in them, `fixtures/photos/LICENSE.md`).

## Gaps

| item | status | smallest capture |
|---|---|---|
| light Albums list as a RAW capture | renders only (ED-W3 / TC-J1) | raw light screenshot of the Albums list (RV §6) |
| "Ideas to Get Started" "•••" menu | not built (menu contents not captured) | one screenshot with that menu open |
| template thumbnails | closed (owner decision 9): four people-free Unsplash photos, 216 × 291 px JPEG (3 × 72 × 97) in the iOS asset catalog and Android `drawable-nodpi` | — |
| tab destinations Rewind / Activity | not in this app's IA | lead / owner (MERGE RA-7) |
