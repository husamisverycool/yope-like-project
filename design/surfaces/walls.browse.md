# `walls.browse` — the people in your groups

Redesign on **Retro**: visual reference Retro's **Friends tab** (screen 8 — TC-1B 2023: serif "Friends", search field,
3-column grid of 81-pt avatars with names under them). Tapping a person opens their wall (`walls.member`), as Retro opens a
profile. Tokens: `design/tokens/social.json` (`walls.browse.*`) + `global.*`. Copy: `design/copy/social.json`
(`walls.browse.*`). Decisions: `design/MERGE_DECISIONS.md` → Redesign — Social (RS-16). Tab root: the Friends item of the tab
bar (C-04, `icon.global.group`; tab items owned by `groups.list`, account group).

## References

| id | file | used for |
|---|---|---|
| TC-1B | `references/auto/retro/press/tc-2023-07-retro-1b.webp` phone 2 (2.204 px/pt) | **primary**: title, search field, grid (avatar 81, `walls.browse.dimension.columnPitch`, `.rowPitch`, `.nameBaseline`) |
| H43 | `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png` | root header metrics (C-01) |
| ED-W3 | `references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png` | 2025 search field (52 pt, r 19 — C-12) |
| AP-P | `references/auto/apple-photos/apple-support/page-find-and-name-people-and-pets.txt`, `references/auto/apple-photos/store/photos-store-03.png` | people grid sorted by name ("Sort alphabetically: Tap Sort by Name") — `walls.browse.layout.rowOrder` |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | "Members" (`journal_edit_members_screen_title`), "Search", "Error loading friends. Tap here to try again." (noun → members), "Nothing to see here yet" |

## Structure (top → bottom; page `color.global.background` / `.background.android`)

1. **Header** (C-01 root): `walls.browse.title` ("Members" — owner decision 10: the people of your groups are members) in the display serif, baseline `size.global.titleTop` below the
   top safe area. No trailing text buttons (Retro's "Invite" is group-scoped here and lives in `groups.invite`; "Keys" is
   do-not-copy).
2. **Search field** (C-12): `size.global.titleToContent` below the title baseline, full width inside
   `size.global.screenMargin`, `size.global.fieldHeight`, `radius.global.field`, `color.global.control`, `icon.global.search`
   + placeholder `walls.browse.search` (`color.global.textSecondary`). Filters the grid by display name as you type.
3. **People grid** (`walls.browse.layout.grid`, C-21), `size.global.sectionGap` below the field: everyone who shares at least
   one group with you (not you), three columns centred on the screen, `walls.browse.dimension.columnPitch` apart (C-21); each cell: avatar
   `size.global.avatarGrid` (C-23), the display name centred under it (text role `listTitle`, `color.global.textPrimary`,
   baseline `walls.browse.dimension.nameBaseline` below the avatar, one line, tail truncation within the column pitch);
   rows `walls.browse.dimension.rowPitch` apart. Order `walls.browse.layout.rowOrder`: display name A to Z in the device
   locale's collation, ignoring case and accents (Apple Photos' people grid "Sort by Name", AP-P). The grid scrolls
   vertically (RS-16).
4. The tab bar (C-04) at the bottom.

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| title | C-01; text role `headerTitle`, `font.global.display`, `size.global.titleTop` | `walls.browse.title` | header trait |
| search | C-12; `size.global.fieldHeight`, `radius.global.field`, `color.global.control`, `icon.global.search`, text role `placeholder` | `walls.browse.search` | filters; clear button native |
| person cell | C-21 people grid + C-23; `size.global.avatarGrid`, `walls.browse.dimension.columnPitch`, `.rowPitch`, `.nameBaseline`, text role `listTitle` | name (data); label `walls.member.a11y.wall` | tap → `walls.member` |

## States

| state | what shows | components · tokens · copy | source |
|---|---|---|---|
| loading | C-28 activity indicator centred under the search field | `easing.global.native.activityIndicator`; `week.history.a11y.loading` | C-28 |
| empty (no groups / nobody else) | no search field; C-27 block centred between the title and the tab bar: `icon.global.group`, title, detail, C-06 outline capsule | `walls.browse.empty.title`, `.empty.detail`, `.empty.action` (→ `groups.create`) | C-27; APK-S |
| no search results | C-27 title only, under the field | `walls.browse.search.empty` | `retro.voice.empty-state` |
| error | one tappable line under the title at `size.global.screenMargin`, text role `body`, `color.global.textSecondary` | `walls.browse.error.title` (tap reloads) | APK-S `friends_tab_loading_error` (verbatim) |
| offline | cached grid; nothing cached → the error line | — | — |
| permission-denied | not applicable | — | — |

## Motion

Grid appears with `duration.global.fade`; search filtering re-lays the grid without animation (Retro's not captured); tab
switch and push native. Reduce Motion: system.

## Haptics

| interaction | token |
|---|---|
| tap a person (Android) | `haptic.global.tap` (iOS none) |

## Accessibility

- The grid is a list; each cell is one button labelled `walls.member.a11y.wall` ("Maya's profile"); avatars decorative.
- Dynamic Type: title largeTitle; names `listTitle` → subheadline (one line, truncation; the label carries the full name).
- Focus order: title → search → cells row by row.
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | light | dark | pair |
|---|---|---|---|---|---|
| `color.global.textPrimary` | `color.global.background` | text | 21.00:1 pass | 21.00:1 pass | title, names |
| `color.global.textPrimary` | `color.global.background.android` | text | 21.00:1 pass | 17.01:1 pass | the same on Android |
| `color.global.textSecondary` | `color.global.control` | text | **2.52:1 FAIL** | 5.31:1 pass | search placeholder (C-12 failure 1) |
| `color.global.textPrimary` | `color.global.control` | text | 18.59:1 pass | 15.13:1 pass | typed search text |
| `color.global.textSecondary` | `color.global.background` | text | **2.85:1 FAIL** | 7.37:1 pass | error line (iOS) |

## Data & actions

- People: `group_members` of my groups → `profiles` (§5.1), distinct, minus me. No RPC.
- Realtime: none (memberships change through group screens); refetch on appear / foreground.
- Navigation in: Friends tab. Out: `walls.member`, `groups.create`. No deep link.

## Platform notes

- iOS: `LazyVGrid` with three fixed columns at `walls.browse.dimension.columnPitch` inside a `ScrollView`; `.searchable` is not used (Retro's field is
  in the content, C-12).
- Android: `LazyVerticalGrid(GridCells.Fixed(3))`; the field as the first full-span item.

## Do-not-copy

- Key badges on avatars, "Keys", "Friend Requests" with "Expires in …" urgency, "Hidden (%1$d)" counts, "Getting Started"
  invite goals, "Find Your Friends" contact suggestions.
- Yope's "me & friends" circle row and combined wall.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| `walls.browse.layout.rowOrder` (old BLOCKED) | closed 2026-10-16: by name (Apple Photos' People & Pets "Sort by Name"; this product has no hand-made order); Retro's own rule stays uncaptured | one raw screenshot of Retro's current Friends tab with 7 or more people would show Retro's rule |
| `walls.browse.layout.selection` (old BLOCKED) | closed: no selected state — a tap opens the person's wall (Retro grid behaviour) | — |
| current Friends tab (2023 render only) | 2023 values (±0.6 pt) | same screenshot |
| title noun for family / roommates groups | closed by owner decision 10 (2026-10-16): "Members" (Retro's journal word, `journal_edit_members_screen_title`; retro.app /j/ "7 members • 24 photos") | — |
