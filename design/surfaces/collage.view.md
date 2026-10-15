# collage.view — the same-moment collage of one daily invitation

Reference: **BeReal** dual image (each answer) + **Yope** wall composition (how answers sit together) and Yope's
day view (the screen around it). The owner has **not chosen** among options A / B / C
(`design/collage-options/README.md`); the production fallback is **option B "wall pages"**, specified here as the
worker composes it. If the owner picks A or C, only "The image" changes (proposal tokens `layout.collage.optionA/C`).

## References

| image | what it verifies |
|---|---|
| `design/collage-options/option-B.jpg` (rendered by `backend/worker/src/collage/`) | the composed pages for 1–30 people |
| `references/auto/yope/frames/b-presskit-wall.png` (C5) | 9:16 wall canvas, ≈20-pt corners |
| `references/owner/yope-week-recap.jpg` (C1) | 3 columns, tiles touch, paged with dots |
| `references/auto/yope/frames/b-alexaa-7652512140875566349-t5.33-day-view-recap.png` (S6) | screen: back circle, date title, page dots, paged content, bottom pill |
| `references/auto/bereal/help/help-21083730354333_feed-bonus-3x.png` | the answer tile (see `daily.dualimage`) |
| `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t50.60-loading-hud.png` | loading HUD |

## The image (server-side, option B)

`collage.view.layout.page`: pages of **9:16**, 1080 px wide (Stories canvas), **3 columns × 4 rows** of answer tiles
that touch (gap 0) — 3 × (4/9) = 16/9, so 3:4 tiles fill the page exactly; page corners 0.0498 × width (transparent
in the master, matte `color.global.backgroundDeep` in the JPEGs); more than 12 answers continue on further pages; cells
of a part-filled page stay `color.global.backgroundDeep`. Each tile = `daily.dualimage.layout.composition` at the tile
width. Order: capture time, then member id. Only `in_window` posts are composed. Files under
`g/<group_id>/collages/<collage_id>/`: `display-<n>.jpg` per page, `widget.jpg` (page 1), `share-<n>.jpg` (= the pages).

## Structure (screen)

Background `color.global.backgroundDeep`; positions on an 852-pt screen (`collage.view.layout.screen`).

1. **Header** centred 81 pt from the top: back circle (leading, `size.global.headerButton`,
   `color.global.controlOnDeep`, `icon.global.back`, inset `size.global.headerInset`); centred title
   `collage.view.title` (the invitation's date, '26 May'), `collage.view.fontSize.title` / `.fontWeight.title`,
   `color.global.textPrimary`, on the circle's centre line.
2. **Page dots** centred 125 pt from the top — only with 2+ pages: iOS native page control; Android dots
   (`collage.view.layout.pageDots`: 7.6 pt, pitch 15.5, active `collage.view.color.pageDotActive`, inactive
   `color.global.controlRaised`).
3. **Page** from 145 pt: the current page image, 9:16, aspect-fit into the space above the home indicator and centred
   (`collage.view.layout.screen.pageFit`), corners as composed. Horizontal paging between pages.
4. **Share pill** bottom centre over the page — `collage.share`.

## Elements

| element | tokens | copy | behavior |
|---|---|---|---|
| back | `size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.back` | a11y `collage.view.a11y.back` | pops / dismisses |
| title | `collage.view.fontSize.title`, `.fontWeight.title` | `collage.view.title` ({date} = `daily_invitations.local_date`, 'd Month') | — |
| page dots | `collage.view.layout.pageDots`, `collage.view.color.pageDotActive`, `color.global.controlRaised` | Android a11y `collage.view.a11y.page` | tap / swipe changes page |
| page | `collage.view.layout.page`, `daily.dualimage.layout.composition` | a11y `collage.view.a11y.collage` | swipe horizontally; no tile tap (not observed in Yope walls) |
| share | see `collage.share` | `collage.share.button` | shares the current page |

## States

| state | design | copy |
|---|---|---|
| loading (collage `status = pending` or image downloading) | HUD centred in the page area: 100 × 99 pt, corner 8.5, fill `collage.view.color.hud` (`collage.view.layout.hud`), platform activity indicator over the word in text role `body`, `color.global.textPrimary` | `collage.view.loading` |
| empty (window closed, no answer → no collage row) | Yope empty state centred: `emptyTitle`, `emptyDetail` (`color.global.textSecondary`), light pill (`camera.capture.size.permissionButtonHeight`, `color.global.surfaceLight`, `radius.global.capsule`, text role `button`) | `collage.view.empty.title` / `.detail` / `.button` → `camera.capture` with the group preselected |
| error (`status = failed`, or download failed) | same empty-state layout | `collage.view.error.title` / `.error.button` (refetch) |
| offline | cached pages shown if present; else the same layout | `collage.view.offline.title` / `collage.view.error.button` |
| recomposing (a post was deleted) | the previous pages stay until the new paths arrive (`image_path` null while recomposing → keep cache, else loading) | — |
| permission-denied | n/a | — |

## Motion

| motion | tokens | Reduce Motion |
|---|---|---|
| page swipe (finger-driven) | `duration.global.photoSwipe`, `easing.global.photoSwipe` (Yope's horizontal swipe) | swipe still tracks the finger; settle without bounce |
| push in / back | `easing.global.native.navigationPush` | system |

## Haptics

None (page changes are not selections; HIG: avoid overusing).

## Accessibility

- Back `collage.view.a11y.back`; title is a header; each page one image element `collage.view.a11y.collage`;
  Android dots expose `collage.view.a11y.page`; iOS page control speaks its own value.
- Dynamic Type: title → callout (`collage.view.layout.textStyleMap`); HUD word → body.
- Focus order: back → title → page dots → page → share.
- Contrast: white title on black 21:1; active dot #F4F4F4 on black 19.09:1 pass; **inactive dot
  `color.global.controlRaised` on black 2.12:1 FAIL** (no sourced alternative; iOS uses the native control);
  HUD text white on #0C0C0C 19.56:1 pass; HUD vs black 1.07:1 (container edge).

## Data & actions

- `collages` where `invitation_id = <id>` (read: members), show only `status = 'ready'`; page count =
  ceil(`post_ids.count` / 12); page n = `display-<n>.jpg` in `image_path`'s folder (worker pipeline; confirm the
  `image_path` contract with the worker team). Signed URLs (1 h).
- In: `app://daily?…` after `closes_at`, the group screen's daily item, the widget's collage (tap → camera per
  Locket, so not from the widget). Out: back; `collage.share`; `camera.capture` (empty state).

## Platform notes

iOS `TabView(.page)` with the native index display; Android `HorizontalPager` + drawn dots. The worker's token names
differ from these canonical names (C-21).

## Do-not-copy

Yope wordmark watermark; cut-out stickers and decorations of Yope walls; any count of who answered ('{n} answered');
any 'missed' / 'late' marker for members without a tile.

## Gaps

| item | status | capture |
|---|---|---|
| option choice | owner (A / B / C) | owner |
| how Yope fills a part-empty page / short row | not observed | one Yope recording of a weekly recap with 2–5 photos |
| tile tap to open one answer | not built (not observed) | — |
