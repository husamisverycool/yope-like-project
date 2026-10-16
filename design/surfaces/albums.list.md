# `albums.list` — a group's saved albums

Redesign on **Retro**: visual reference Retro's **Albums list** (screen 10 / 11 — ED-W3 pushed variant: back chevron +
serif "Albums", 52-pt search field, rows with a 3:4 cover thumbnail, semibold title, grey context line with the actor's name
in semibold). Our albums are named selections of a group's photos saved from a recap (`week.edit`). Tokens:
`design/tokens/social.json` (`albums.list.*`) + `global.*`. Copy: `design/copy/social.json` (`albums.list.*`). Decisions:
`design/MERGE_DECISIONS.md` → Redesign — Social (RS-21).

## References

| id | file | used for |
|---|---|---|
| ED-W3 | `references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png` (render, 3.89 px/pt; geometry only) | **primary**: pushed header, search field, rows (C-15: thumbnail 72 × 97, gap 17, pitch 119.5) |
| ED-A | `references/auto/retro/store/editorial/retro-appstore-story-1840659619-albums.png` | root Albums list (rows, avatar stack, "+" circle) |
| TC-J1 | `references/auto/retro/press/tc-2024-04-journals-1.webp` phone 2 | rows "**daniel** shared 2 posts" (count is do-not-copy) |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | "Albums", "%1$s created the album", "you created the album", "Error retrieving your albums. Tap here to try again" |

## Structure (top → bottom; page `color.global.background` / `.background.android`)

`albums.list.layout.composition`:
1. **Header** (C-02 pushed): back chevron + `albums.list.title` ("Albums") in the display serif.
2. **Search field** (C-12) `size.global.titleToContent` below the title baseline, inside `size.global.screenMargin`:
   `icon.global.search` + `albums.list.search`; filters by album name. Shown when the group has albums.
3. **Rows** (C-15), newest album first, the first `size.global.titleToContent` below the field, rows `size.global.listGap`
   apart: cover thumbnail (`size.global.rowThumbWidth` × `.rowThumbHeight`, `radius.global.thumbnail`, the album's first item,
   aspect fill) at the margin; text block `size.global.rowThumbGap` after it, top-aligned with the thumbnail: album name (text
   role `listTitle`, `color.global.textPrimary`, up to two lines) over the context line `albums.list.row.subtitle`
   ("{name} created the album", the name in `fontWeight.global.listTitle`; yours `albums.list.row.subtitleMine`), text role
   `listSubtitle`, `color.global.textSecondary`. No avatar stack and no "+" circle (RS-21).

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| back + title | C-02; text role `headerTitle` | `chat.thread.a11y.back`; `albums.list.title` | pops to `groups.screen` |
| search | C-12 | `albums.list.search` | filters |
| row | C-15; `size.global.rowThumbWidth`, `.rowThumbHeight`, `.rowThumbGap`, `.listGap`, `radius.global.thumbnail`; text roles `listTitle` / `listSubtitle` | album name (data), `albums.list.row.subtitle` / `.row.subtitleMine` | tap → `albums.view` (sheet) |

## States

| state | what shows | components · tokens · copy | source |
|---|---|---|---|
| loading | three C-15 rows with `color.global.control` thumbnails and no text | C-28; `week.history.a11y.loading` | C-28 |
| empty | no search field; C-27 centred below the header: `icon.global.albums` → title → detail → C-06 outline capsule | `albums.list.empty.title`, `.empty.detail`, `.empty.action` (→ `week.recap` list) | APK-S |
| no search results | C-27 title only under the field | `albums.list.search.empty` | `retro.voice.empty-state` |
| error | one tappable line under the header (text role `body`, `color.global.textSecondary`) | `albums.list.error.title` (verbatim Retro) | APK-S |
| offline | cached rows; nothing cached → the error line | — | — |
| permission-denied | not applicable | — | — |

## Motion

Push / pop native; rows appear with `duration.global.fade`; opening an album: native sheet. Reduce Motion: system.

## Haptics

| interaction | token |
|---|---|
| tap a row (Android) | `haptic.global.tap` (iOS none) |

## Accessibility

- Each row is one button: "{album name}, {name} created the album" (title + subtitle combined; C-15); thumbnail decorative.
- Dynamic Type: `listTitle` / `listSubtitle` → subheadline; the thumbnail keeps its size, text wraps.
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | light | dark | pair |
|---|---|---|---|---|---|
| `color.global.textPrimary` | `color.global.background` | text | 21.00:1 pass | 21.00:1 pass | title, album names |
| `color.global.textSecondary` | `color.global.background` | text | **2.85:1 FAIL** | 7.37:1 pass | context line, error line (iOS) |
| `color.global.textSecondary.android` | `color.global.background.android` | text | **4.00:1 FAIL** | 6.85:1 pass | the same on Android |
| `color.global.textSecondary` | `color.global.control` | text | **2.52:1 FAIL** | 5.31:1 pass | search placeholder |

## Data & actions

- `albums` (docs/API.md §5.15) `eq(group_id).order(created_at desc)`; first `album_items` row (`position = 0`) per album →
  `posts` → `media.thumb_path`; `profiles` for `created_by`.
- Realtime: none (albums are not published) — refetch on appear / foreground.
- Navigation in: the group's albums entry on `groups.screen` (account group); after a `week.edit` album save. Out:
  `albums.view`, `week.recap` (empty action).

## Platform notes

iOS `LazyVStack` in a `ScrollView` (search field in the content, C-12); Android `LazyColumn`.

## Do-not-copy

- Post counts in the context line ("shared 2 posts"), "N new" badges, the "+" post-to-album circle, member avatar stacks
  (albums have no members of their own), "Ideas to Get Started" templates (group creation lives in `groups.create`).
- Apple Photos' 2-column cover grid (old gap fill G-17, superseded by Retro's own list).

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| rows without the stack and "+" | composition (RS-21) | — |
| current Albums list in light / dark (renders only) | ED-W3 is an editorial render (geometry only) | one raw screenshot of Retro's Albums list, light + dark |
