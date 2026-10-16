# `chat.reactions` — any-emoji reactions on photos (never a number)

Redesign on **Retro**: Retro's only reaction on posts is a heart like (do-not-copy); its message threads have a
"Reactions" sheet (APK). The reaction surfaces are therefore **composed of Retro components** — a fill capsule (C-06)
summarising the emoji, a native context menu (C-29) with a quick-reaction row, a native sheet with a search field (C-12)
for the full picker, and people rows (C-16) for who reacted — following **WhatsApp / Apple Messages** mechanics (long press
to react, a summary under the message, tap the summary to see who, tap your own to remove) with **Locket**'s quick emoji
and ordering. Tenet 2: no count anywhere — not on the chip, in the sheet, in pushes or in labels. Tokens:
`design/tokens/social.json` (`chat.reactions.*`) + `global.*`. Copy: `design/copy/social.json` (`chat.reactions.*`).
Decisions: `design/MERGE_DECISIONS.md` → Redesign — Social (RS-8, RS-9). Composition record: `level: SOURCED`, `method:
"composition of Retro components C-06, C-29, C-12, C-16, C-11 in WhatsApp / Apple Messages' order"`.

## References

| id | file | used for |
|---|---|---|
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | "Reactions" (`message_reactions_sheet_title`), "Search", "All", "Nothing to see here yet", "Couldn't send comment" |
| APK-X | `references/auto/retro/apk/retro-android-2026.10.1150-excerpts.txt` | PaddingValues(12, 8, 12, 8) of Retro's small pills (chip padding) |
| WEB | `references/auto/retro/web/retro.app-42b38811bebcd07d.css` | 12-pt gap from a photo to the row under it (`.immersiveViewer_mediaFooter`) |
| WA | `references/auto/whatsapp/store/whatsapp-store-04.png`, `references/auto/whatsapp/help/faq-424198503229937-react-iphone.png` | summary pill under the message showing three distinct emoji (its count is do-not-copy); "tap your reaction to remove it" |
| IM | `references/auto/imessage/apple-support/messages-tapbacks-ios27.png`, `…/page-react-with-tapbacks.png` | reaction row above the long-pressed message; your reaction highlighted; tap it again to remove |
| ST-R | `references/auto/stream/docs-react-reactions-excerpt.txt` | the "who reacted" list sorts people in reverse chronological order of their reactions (`chat.reactions.layout.listOrder`) |
| LK | `references/auto/locket/store/locket-store-08.png`; `references/auto/locket/frames/locket-tt-7460656081153445163-15.000s-emoji-picker-sheet-search-popular.jpg`, `…-16.734s-reaction-cluster-landed.jpg` | quick emoji 🔥 💖 + add; picker search / Frequently Used / 6 columns; newest emoji first |

## Structure

### 1. Reaction chip (thread photo messages, viewer footer) — `chat.reactions.layout.chip`

A C-06 fill capsule holding the **distinct** emoji used on the photo — at most `chat.reactions.count.clusterMaxVisible` (3),
newest first (`chat.reactions.layout.clusterOrder`) — at `fontSize.global.pill`, padding 12 horizontal / 8 vertical (Retro's
small-pill padding), height hugging the line, corners `radius.global.capsule`. Fill: `color.global.control` (iOS) /
`color.global.surfaceSecondary.android` on a page; `color.global.controlOnDeep` in the viewer. No number, no avatars.
- Thread: under the photo card, leading-aligned with the text column, `chat.reactions.dimension.chipTop` below the photo.
- Viewer: in the footer's trailing slot (where Retro shows its heart), before the add-reaction glyph.
Hidden when nobody reacted. Tap → Reactions sheet (4).

### 2. Quick reactions — `chat.reactions.layout.quickReactions`

Long press on a photo message (thread) or on the viewer photo opens the photo's native context menu (C-29); its first row
is a palette of 🔥, 💖 and the add-reaction glyph `chat.reactions.icon.add`. An emoji reacts at once (an emoji you already
used shows selected and unreacts); the glyph opens the picker (3). The menu's other items are the surface's own
(`chat.thread.md`, `photo.viewer.md`).

### 3. Picker — `chat.reactions.layout.picker`

Native sheet with a grabber (C-29, `radius.global.sheet`), content on `color.global.background`:
1. C-12 search field, placeholder `chat.reactions.picker.search`, inside `size.global.screenMargin`; filters by the emoji's
   system name.
2. Section header `chat.reactions.picker.frequent` (text role `sectionLabel`, C-20 form without "•••"), then the emoji you
   used recently on this device.
3. Section header `chat.reactions.picker.all`, then every emoji in Unicode order.
Grid: `chat.reactions.count.pickerColumns` equal columns across the content width, emoji at `fontSize.global.headerTitle`.
Emoji you already reacted with on this photo sit on a `size.global.circleButton` circle in `color.global.control` (selected
trait). Tap → `react` and the sheet closes; tap a highlighted one → `unreact`. Section spacing: `size.global.sectionGap`
above a header, `size.global.sectionHeaderToContent` below its baseline.

### 4. Reactions sheet — `chat.reactions.layout.list`

Native sheet (C-29) titled `chat.reactions.activity.title`, a plain list (no grouped rows) on `color.global.background`: one
C-16 row per person and emoji — avatar `size.global.avatarPicker` at the margin, name (text role `listTitle`)
`chat.thread.dimension.rowAvatarToText` after it, the emoji at the trailing margin in the `size.global.icon` box. Your own rows add
`chat.reactions.list.removeHint` as a second line (`listSubtitle`, `color.global.textSecondary`); tapping one unreacts
(`chat.reactions.layout.unreact`). Rows `size.global.listGap` apart; order `chat.reactions.layout.listOrder`: newest first by
`reactions.created_at`, your own rows in their place by time (the "who reacted" list of the Stream Chat SDK, ST-R).
Empty (all reactions taken back while open): `chat.reactions.empty`.

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| chip | C-06 fill; `chat.reactions.layout.chip`, `chat.reactions.dimension.chipTop`, `chat.reactions.count.clusterMaxVisible`, `chat.reactions.layout.clusterOrder`, `fontSize.global.pill`, `radius.global.capsule` | `chat.reactions.a11y.cluster` | tap → Reactions sheet |
| quick row | C-29 menu palette; `chat.reactions.layout.quickReactions` | `chat.reactions.a11y.quick`, `chat.reactions.a11y.add` | react / unreact / open picker |
| add-reaction glyph (viewer footer) | `chat.reactions.icon.add`, `size.global.icon`, `color.global.textSecondary`; hit area `size.global.headerButton` | `chat.reactions.a11y.add` | opens the picker |
| picker | C-29 sheet, C-12, C-20 headers, C-11 highlight; `chat.reactions.layout.picker`, `chat.reactions.count.pickerColumns`, `fontSize.global.headerTitle` | `chat.reactions.picker.search`, `.picker.frequent`, `.picker.all` | react / unreact |
| Reactions sheet | C-29 sheet, C-16 rows; `chat.reactions.layout.list`, `size.global.avatarPicker`, `size.global.icon`; order `chat.reactions.layout.listOrder` (newest first) | `chat.reactions.activity.title`, `.activity.row`, `.activity.rowMine`, `chat.reactions.list.removeHint`, `chat.reactions.empty` | your row → unreact |

## States

| state | what shows | tokens · copy | source |
|---|---|---|---|
| no reactions | no chip | — | WA |
| reacting | the chip updates at once (optimistic) | — | — |
| loading (sheet) | C-28 platform activity indicator centred in the sheet | `easing.global.native.activityIndicator` | C-28 |
| empty (sheet) | C-27 title only | `chat.reactions.empty` | APK-S |
| error / offline (react fails) | the optimistic change is undone; Android Toast / iOS announcement | `chat.reactions.error`; `haptic.global.error` | `retro.voice.error` |
| permission-denied | not applicable | — | — |

## Motion

| motion | tokens | Reduce Motion |
|---|---|---|
| chip appears / changes | cross-fade `duration.global.crossfade` (Retro's state cross-fade) | same |
| context menu, sheets | native (`easing.global.native.menu`, `.sheet`; sheet `spring.global.sheetPresent`) | system |

No emoji rain and no fly-to-cluster: both were Locket's visual effects (RS-8).

## Haptics

| interaction | token |
|---|---|
| long press opens the menu with the quick row | `haptic.global.reaction` (system context-menu haptic on iOS; LONG_PRESS on Android) |
| tap an emoji (Android) | `haptic.global.tap` (iOS none) |
| reaction failed | `haptic.global.error` |

## Accessibility

- Chip: one button, label `chat.reactions.a11y.cluster` with the emoji's system names ("Reactions: fire, sparkling heart") —
  never a count; hint opens the sheet. Picker cells and quick-row emoji are labelled with system names
  (`chat.reactions.a11y.quick` for the quick row; `chat.reactions.a11y.add`); highlighted cells carry the selected trait.
- Sheet rows: `chat.reactions.activity.row` / `.activity.rowMine`; your rows are buttons (remove).
- Dynamic Type: section headers `sectionLabel`, names `listTitle`, hint `listSubtitle`; emoji keep their size.
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | light | dark | pair |
|---|---|---|---|---|---|
| `color.global.control` | `color.global.background` | nontext | **1.13:1 FAIL** | **1.39:1 FAIL** | chip boundary on a page (identified by its emoji) |
| `color.global.controlOnDeep` | `color.global.backgroundDeep` | nontext | **1.39:1 FAIL** | **1.39:1 FAIL** | chip boundary in the viewer |
| `color.global.textSecondary` | `color.global.background` | text | **2.85:1 FAIL** | 7.37:1 pass | "Tap to remove" (iOS) |
| `color.global.textPrimary` | `color.global.background` | text | 21.00:1 pass | 21.00:1 pass | names, section headers |
| `color.global.textSecondary` | `color.global.backgroundDeep` | nontext | 7.37:1 pass | 7.37:1 pass | add-reaction glyph in the viewer |

  Emoji are colour glyphs (no fixed foreground). Failures are Retro's palette (design/CONTRAST.md); reported.

## Data & actions

- **Reads**: `reactions` (docs/API.md §5.10) for the post — rows `(user_id, emoji, created_at)`; distinct emoji for the chip;
  `profiles` for names. Never request `Prefer: count=…` (§13).
- **RPCs**: `react(p_post_id, p_emoji)` (idempotent; several emoji per person allowed); `unreact(p_post_id, p_emoji)`. Errors
  `post_not_found`, `invalid_emoji`. Job `push.reaction` → `notifications.push.reaction.*` (capture group).
- **Realtime**: `reactions` INSERT on the group channel; `reactions_changed` broadcast → refetch that post's reactions (§8).
- **Navigation**: lives inside `chat.thread` and `photo.viewer`; a reaction push opens `DeepLink.post(groupID:postID:)` →
  `photo.viewer`.

## Platform notes

- iOS: quick row = `ControlGroup { … }.controlGroupStyle(.palette)` inside the `contextMenu` (iOS 17+); picker = custom
  grid in `.sheet` with `.presentationDragIndicator(.visible)`; emoji names via `CFStringTransform(…ToUnicodeName)`;
  "Frequently Used" stored per device.
- Android: first `DropdownMenu` item is a `Row` of emoji buttons; picker in `ModalBottomSheet`; `androidx.emoji2` for emoji
  support and names (the system `EmojiPickerView` is not used, to keep the sections).

## Do-not-copy

- Counts in any form (WhatsApp's "7", "N reactions", "Seen by"); Retro's heart like, "Likers", "❤️ your post".
- Locket's outlined sticker cluster, emoji rain and fly-to-cluster animation; Locket's curated "Popular" list.
- Messages' Tapback glyph set (thumbs down, "!!", "?").

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| `chat.reactions.layout.listOrder` (old BLOCKED) | closed 2026-10-16: newest first (Stream Chat's reaction list, `references/auto/stream/docs-react-reactions-excerpt.txt`; WhatsApp / Messages help pages state no order) | a WhatsApp or Retro list with three reactors would confirm |
| `chat.reactions.count.clusterMaxVisible` (old BLOCKED) | closed: 3 (WhatsApp panel) | — |
| `chat.reactions.layout.activitySheet` (old BLOCKED) | closed: C-16 rows in Retro's "Reactions" sheet (`chat.reactions.layout.list`) | — |
| Retro's own reaction UI in messages | not captured | one raw screenshot of a reacted message in a Retro DM |
| picker metrics | columns from a filmed Locket frame; emoji size = `fontSize.global.headerTitle` (composition) | one screenshot of a picker in a reference app |
