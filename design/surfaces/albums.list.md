# `albums.list` — a group's saved albums

Reference app: **Yope** (`docs/SURFACES.md`). **No Yope album screen was found**: only the release note "make your own
memory albums" (v1.214.0, yope-b §7). Per the brief the screen is **built from documented Yope components** (the home list
card, header, empty state; S-14); Yope's own album list stays **BLOCKED** (`albums.list.layout.yopeAlbums`) until captured.
Tokens: `design/tokens/social.json` (`albums.list.*`) + `global.*`. Copy: `design/copy/social.json` (`albums.list.*`).

## References

| id | file | used for |
|---|---|---|
| W1 | `references/auto/yope/store/listing.html` (v1.214.0) | "memory albums" |
| V-sav | `references/auto/yope/frames/a-savannahclooney-7683341732695592206-t6.73-home-list.png` | home list card: #181818 on black, ≈100 pt, 64-pt circle at 16 pt, name bold, gray subtitle, 12-pt margins, 17-pt corners |
| V-virgi | `references/auto/yope/frames/a-virgi-7686278541255642390-t40.23-home-list-es.png` | second card-height sample |
| O3 | `references/owner/yope-week-recap.jpg` | centred header title style (‹ + 17 semibold title) |

## Structure (top → bottom)

Background `color.global.backgroundDeep`.

1. **Header**: ‹ circle (`size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.back`,
   `size.global.headerInset`); title `albums.list.title` ("memory albums") centred, `week.recap.fontSize.title` /
   `.fontWeight.title`, `color.global.textPrimary`.
2. **Album cards** (`albums.list.layout.composition`), stacked with `size.global.listGap`, side margins
   `size.global.screenMargin`, newest album first (`albums.created_at`): card `albums.list.dimension.cardHeight`,
   `albums.list.color.card`, `radius.global.card`. Inside, vertically centred: cover circle `size.global.avatarList` (64) at
   `albums.list.dimension.coverInset` (16) — the album's first photo (`thumb_path`), aspect fill; then, after
   `albums.list.dimension.coverToTitle` (15), the album name (text role `listTitle`, `color.global.textPrimary`, one line)
   over the subtitle `albums.list.row.subtitle` ("saved by {name}", text role `listSubtitle`, `color.global.textSecondary`).

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| ‹ circle | `size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.back` | `chat.thread.a11y.back` | pops |
| title | `week.recap.fontSize.title`, `.fontWeight.title` | `albums.list.title` | header trait |
| album card | `albums.list.color.card`, `.dimension.cardHeight`, `radius.global.card`, `size.global.screenMargin`, `size.global.listGap` | album name (data), `albums.list.row.subtitle` | tap → `albums.view` |
| cover | `size.global.avatarList`, `albums.list.dimension.coverInset`, `.coverToTitle` | decorative | — |

## States

| state | what shows | tokens / copy | source |
|---|---|---|---|
| loading | Loading HUD | `groups.create.size.hud`, `.color.hud`, `.fontSize.hudLabel`; `groups.create.hud.loading` | yope-a §1.8 |
| empty | centred bold title, gray detail, white pill | `albums.list.empty.title`, `.empty.detail`, `.empty.action` ("view recap" → `week.recap`); text roles `emptyTitle` / `emptyDetail`; pill `color.global.surfaceLight` / `.onSurfaceLight`, `groups.screen.size.lightPillHeight`, `groups.screen.radius.lightPill` | `yope.voice.empty-state` |
| error | same layout as empty, retry pill | `albums.list.error.title`, `chat.thread.error.detail`, pill `chat.thread.error.retry` | `yope.voice.error` |
| offline | cached cards; nothing cached → `chat.thread.offline.title` / `.offline.detail` | — | `yope.voice.error` |
| permission-denied | not applicable | — | — |

## Motion

Push / pop native; list scroll native. Reduce Motion: system.

## Haptics

None.

## Accessibility

- Card: one button, label "{album name}, {subtitle}" (name data + `albums.list.row.subtitle`); cover decorative.
- Dynamic Type: name → `layout.global.textStyleMap.listTitle`; subtitle → `.listSubtitle`; title →
  `week.recap.layout.textStyleMap.title`. Cards grow in height with the text (100 pt minimum).
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | ratio | result | pair |
|---|---|---|---|---|---|
| `color.global.textPrimary` #FFFFFF | `albums.list.color.card` #181818 | text | 17.76:1 | pass | album name 17.5 bold |
| `color.global.textSecondary` #969696 | `albums.list.color.card` #181818 | text | 6.00:1 | pass | 'saved by {name}' 14 regular |
| `albums.list.color.card` #181818 | `color.global.backgroundDeep` #000000 | nontext | 1.18:1 | **FAIL** | card against black (the card is not the only cue: its text identifies it) |

## Data & actions

- `albums` (docs/API.md §5.15) `eq(group_id).order(created_at desc)`; first `album_items` row (`position = 0`) per album →
  `posts` → `media.thumb_path`; `profiles` for `created_by`.
- Realtime: none for albums (not published): refetch on appear / foreground.
- Navigation in: the group's albums entry on `groups.screen` (account group), after `week.edit`'s album save. Out:
  `albums.view`, `week.recap`.

## Platform notes

iOS `LazyVStack` of cards; Android `LazyColumn`. Dark only.

## Do-not-copy

Streak pills, unread badges, presence dots and the camera glyph of Yope's home cards (not meaningful for albums).

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| `albums.list.layout.yopeAlbums` (Yope's own album list) | BLOCKED; composition from the home card (S-14) | two screenshots: Yope's album list and one open album (yope-b §14 capture 5) |
| album order | approximation: newest first | same |
