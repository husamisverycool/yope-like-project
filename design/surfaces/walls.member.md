# `walls.member` — a member's wall (only photos from shared groups)

Redesign on **Retro**: visual reference Retro's profile of **another person** (screen 4: same header and week sections as
your own; the action row carries "More Options" — APK `user_profile_more_options` with "Report Profile" / "Block Profile").
Same structure and tokens as `walls.mine.md` (read it first); this file lists only the differences. Tokens:
`design/tokens/social.json` (`walls.mine.*`, `week.history.*`) + `global.*`. Copy: `design/copy/social.json`
(`walls.member.*`). Decisions: `design/MERGE_DECISIONS.md` → Redesign — Social (RS-14).

**Scope rule (data, not design):** `wall(p_user_id)` returns only the person's photos posted in groups **you both belong
to** (and collages of those groups containing one of their photos); nothing for a person you share no group with or have a
block with (docs/API.md §6.4). The screen never says which groups a photo came from.

## References

| id | file | used for |
|---|---|---|
| ST-02 | `references/auto/retro/store/retro-store-02.png` | header, week sections (as `walls.mine`) |
| TC-1B | `references/auto/retro/press/tc-2023-07-retro-1b.webp` phone 3 | outline "•••" capsule ending the profile action row |
| APK-X / APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-excerpts.txt` (xw1.java: profile action row with `user_profile_more_options`), `…-strings.txt` | "More Options", "Report Profile", "Block Profile", "Nothing to see here", "%1$s hasn't posted anything…" |
| ED-W3 | `references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png` | C-02 pushed header (back chevron + serif title) |

## Differences from `walls.mine`

1. **Pushed header** (C-02): back chevron (`icon.global.back`, `size.global.backInset`) then the person's display name in the
   display serif on the same line, `size.global.headerGap` after the chevron; the avatar (`size.global.avatarProfile`) at the
   trailing margin, centred on the name's cap middle (`walls.mine.layout.header`).
2. **Action row**: one C-06 outline icon capsule (`size.global.iconPillWidth` × `size.global.pillHeight`, `icon.global.more`)
   at the trailing margin, `walls.mine.dimension.nameToActions` below the name baseline → native menu (C-29):
   `walls.member.menu.report` (destructive red, → `safety.report`, kind `user`) and `walls.member.menu.block` (destructive red,
   → `safety.block`).
3. **No add tile** in the current week (you cannot post to their wall): photo tiles, then placeholder tiles for the remaining
   days; an empty current week shows seven dated empty-day tiles (`week.history.layout.currentWeek` `readOnly`).
4. **Empty** (no shared photos, a block, or no shared group): C-27 block without action — `icon.global.calendar`, title
   `walls.member.empty.title`, detail `walls.member.empty.detail`.

## Elements (differences)

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| back | C-02; `icon.global.back`, `size.global.backInset`, `size.global.headerGap` | `chat.thread.a11y.back` | pops |
| name | C-02 title; text role `headerTitle`, `font.global.display` | display name (data); screen label `walls.member.a11y.wall` | header trait |
| more capsule | C-06 outline icon capsule; `size.global.iconPillWidth`, `size.global.pillHeight`, `icon.global.more`, `size.global.iconSmall` | `walls.member.a11y.more` | menu: `walls.member.menu.report`, `walls.member.menu.block` |
| photo tile | C-17 | `week.history.a11y.tile` ("{weekday}, {date}, {name}'s photo") | → `photo.viewer` (context = this wall) |
| batch tile (photos posted together, `layout.global.photoBatch`) | C-17 + `layout.global.batchMarker` (`icon.global.batch`), as `walls.mine` | `week.history.a11y.tile` + `chat.thread.a11y.batch` | → `photo.viewer` at the batch's first photo (`photo.viewer.layout.batchDots`) |
| collage tile | C-17 | `walls.browse.a11y.collage` | → `collage.view` |

## States

| state | what shows | components · tokens · copy | source |
|---|---|---|---|
| loading | header from `profiles`; one placeholder section | C-28; `week.history.a11y.loading` | C-28 |
| empty | header; C-27 (glyph, title, detail; no action) | `walls.member.empty.title`, `walls.member.empty.detail` | APK-S `user_profile_empty_media_title` |
| error | tappable line (as `walls.mine`) | `walls.mine.error.title` | `retro.voice.error` |
| offline | cached sections, else the error line | — | — |
| blocked (after Block from the menu) | the wall empties (API returns nothing); empty state | as empty | docs/API.md §6.4 |
| permission-denied | not applicable | — | — |

## Motion · Haptics · Accessibility

As `walls.mine.md`. Push / pop native (`easing.global.native.navigationPush`). Focus order: back → name → more → sections.
Contrast pairs as `walls.mine.md` (destructive menu items are platform-drawn: iOS systemRed / Android
`color.global.system.error` on `color.global.system.surfaceContainerHigh`).

## Data & actions

- `wall(p_user_id: member id, p_before, p_limit: 50)` (docs/API.md §6.4); `profiles` (§5.1) for name / avatar.
- `report` (kind `user`) via `safety.report`; `block_user` via `safety.block` (account group).
- Realtime: `post_deleted` on shared groups → drop the tile.
- Navigation in: avatar / name in `chat.thread`, `photo.viewer`, the people grid of `walls.browse`, member rows in
  `groups.settings`. Out: `photo.viewer`, `collage.view`, `safety.report`, `safety.block`. No deep link.

## Platform notes

As `walls.mine.md`; menu: iOS `Menu` on the capsule (`Button(role: .destructive)`), Android `DropdownMenu`.

## Do-not-copy

- Retro's "Add Friend" / "Accept" / "Unfriend" / "Give Key" / "Say Hey!" / "Message" / "Send Postcard" actions (no friend
  graph, keys, DMs or postcards here); "Friends Only" / "Requests Locked" states; "Weeks Posted: N".
- Discovery profiles, mutual-friend counts ("You share %1$d mutual friends").

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| Retro's pushed profile (where the back chevron sits relative to the serif name and avatar) | composition C-02 + C-19 (RS-14) | one raw screenshot of a friend's profile opened from the Friends tab |
| a row holding only the "More Options" capsule | composition | same screenshot |
