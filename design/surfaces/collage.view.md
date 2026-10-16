# collage.view — the same-moment collage of one daily invitation

**Visual reference: Retro's recap preview** (ST-04 2026, TC-REC 2023 phones 2–3: a rounded media page holding a
blurred, colour-rich version of the photo; the recap card centred on it; a close circle; below the page, page dots and
a white "Share" pill) — C-34 card on a blurred backdrop, C-11, C-31, C-09. **Mechanics:** the collage itself is the
worker's composition of BeReal dual images (`daily.dualimage`) in the owner-pending layout (option B "wall pages",
`design/collage-options/README.md`); its page corners (0.0498 × width) equal Retro's recap-card corners (≈ 4.5–5 %
of the card width, TC-H), so the page is drawn as the card. Decisions: `design/MERGE_DECISIONS.md` RC-14, RC-15, RC-19.

## References

| image | what it verifies |
|---|---|
| `references/auto/retro/store/retro-store-04.png` (ST-04, 2026) | media page geometry and corner, close circle, bottom row (`collage.view.layout.screen`), page dots, Share pill |
| `references/auto/retro/press/tc-2023-12-recaps.png` phones 2–3 (TC-REC) | card centred on the blurred backdrop with ≥ 32-pt side insets; dark page dots; full-bleed variant |
| `references/auto/retro/press/tc-2023-12-retro-header.png` (TC-H) | recap card shape (white card, ≈ 5 % corners, photo grid) |
| `design/collage-options/option-B.jpg` | the composed pages for 1–30 people (worker) |
| `references/auto/bereal/help/help-21083730354333_feed-bonus-3x.png` | the answer tile (`daily.dualimage`) |

## The image (server-side, unchanged)

`collage.view.layout.page`: 9:16 pages, 1080 px wide, 3 columns × 4 rows of answer tiles that touch, page corners
0.0498 × width (transparent in the master, matte `color.global.backgroundDeep` in the JPEGs), more than 12 answers on
further pages, empty cells `color.global.backgroundDeep`; tiles = `daily.dualimage.layout.composition`. Order: capture
time, then member id; only `in_window` posts. Files under `g/<group_id>/collages/<collage_id>/<version>/`:
`display-<n>.jpg`, `widget.jpg`, `share-<n>.jpg`.

## Structure (393 × 852 pt) — `collage.view.layout.screen`

Full-screen modal on `color.global.backgroundDeep` (both appearances).

1. **Media page** — full width, from the safe-area top to 94.8 pt above the screen bottom, corners 26.5
   (`layout.global.cornerStyle`); filled with page 1's image blurred, full bleed (`layout.global.materials.backdrop`;
   blur radius not measurable — Gap).
2. **Close** circle (C-11 on media: `size.global.circleButton`, `color.global.controlOnDeep`, `icon.global.close`
   in `color.global.textOnMedia`), centre 37.7 pt from the trailing edge and 38 pt below the media page top.
3. **Card** — the current page image, aspect-fit and centred in the media page inset 76 pt top and bottom and ≥ 32 pt
   at the sides (307 × 546 on this screen), clipped to `collage.view.layout.page.outerRadiusRatio` × its width
   (continuous on iOS). Pages change by horizontal swipe; the backdrop stays page 1's.
4. **Page dots** (C-31, only with 2+ pages) centred horizontally, their centre `dimension.year.story.dots.offset`
   (16.1) below the media page (ST-04: 16.3; MERGE_DECISIONS RC-19) — `size.global.pageDot`, `size.global.pageDotPitch`,
   active `color.global.textOnMedia`, inactive `color.global.pageDotInactive` dark value (#808080; media surface).
5. **Bottom row** (on black, below the media page), centred 59.2 pt above the screen bottom: **Share** pill
   (`collage.share`) at `size.global.buttonMarginH` from the trailing edge.

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| media page | C-34 backdrop · `collage.view.layout.screen` (mediaPage*), `layout.global.materials` | — (decorative) | page 1 blurred |
| close | C-11 on media | a11y `collage.view.a11y.close` | dismisses |
| card / page | C-34 card · `collage.view.layout.page`, `daily.dualimage.layout.composition` | a11y `collage.view.a11y.collage` ({group}, {date} = `daily_invitations.local_date`, `retro.voice.formats`) | horizontal paging; no tile tap |
| page dots | C-31 · `size.global.pageDot`, `.pageDotPitch`, `dimension.year.story.dots.offset` (below the page), `color.global.textOnMedia`, `color.global.pageDotInactive` (dark) | Android a11y value `collage.view.a11y.page` | tap / swipe changes the page |
| share | C-09 light (`collage.share.layout.pill`) | `collage.share.button` | shares the current page (`collage.share`) |

## States

| state | design | copy |
|---|---|---|
| loading (`status = pending` or pages downloading) | media page filled `color.global.controlOnDeep`; centred in it: platform activity indicator (`color.global.textOnMedia`, C-28) → `size.global.emptyIconToTitle` → line text role `emptyTitle` `color.global.textOnMedia`; no dots, no Share | `collage.view.loading` |
| empty (window closed, nobody shared → no collage row) | media page `color.global.controlOnDeep`; C-27 on media: `icon.global.camera` (`size.global.emptyIcon`) → title `emptyTitle` → explanation `emptyDetail` `color.global.textSecondary` → C-07 outline capsule (border / label `color.global.textOnMedia`) | `collage.view.empty.title` / `.detail` / `.button` → `camera.capture`, group preselected |
| error (`status = failed`, download failed) | media page `color.global.controlOnDeep`; one tappable line centred, text role `body`, `color.global.textOnMedia` (Retro's list-error line) | `collage.view.error.title` (tap refetches) |
| offline | cached pages shown if present; else the error layout | `collage.view.offline.title` |
| recomposing (a post was deleted) | previous pages stay until the new paths arrive | — |
| permission-denied | n/a | — |

## Motion

| motion | tokens | Reduce Motion |
|---|---|---|
| modal in / out | native full-screen cover (`easing.global.native.sheet`); custom presentations match `spring.global.sheetPresent` | cross-fade |
| card and backdrop appear when loaded | `duration.global.fade` (150) + `easing.global.standard` | same |
| page swipe | finger-tracked, platform pager settle (`easing.global.native`) | tracks the finger, no bounce |
| dot change | `duration.global.crossfade` (100) | same |

## Haptics

Close and Share presses: `haptic.global.tap` (Android VIRTUAL_KEY; iOS none). Page changes: none (not a selection).

## Accessibility

- Close `collage.view.a11y.close`; each page one image element `collage.view.a11y.collage`; Android dots expose
  `collage.view.a11y.page` ("2 of 3"); iOS page control speaks its own value. Backdrop hidden.
- Dynamic Type: `emptyTitle` → title3, `emptyDetail` → subheadline, `body` → subheadline.
- Focus order: close → page → page dots → Share.
- Contrast (both appearances identical — media surface): glyph `textOnMedia` on `controlOnDeep` 15.13:1 pass;
  close fill vs blurred backdrop: photo-dependent; active dot `textOnMedia` on black 21.00:1, inactive #808080 on black
  5.32:1 pass (non-text); state text `textOnMedia` / `textSecondary` on `controlOnDeep` 15.13:1 / 5.31:1 pass.

## Data & actions

- `collages` where `invitation_id = <id>` (members), shown when `status = 'ready'`; pages from `page_count`
  (`display-<n>.jpg` in `image_path`'s folder); signed URLs (1 h).
- In: `app://daily?…` after `closes_at`, the group screen's daily item. Out: close; `collage.share`; `camera.capture`
  (empty).

## Platform notes

iOS `TabView(.page)` (index display hidden; dots drawn per C-31 on black) or a native page control styled with the
same tokens; Android `HorizontalPager` + C-31 dots. Blurred backdrop: iOS `.blur(radius:)` on the image, Android
`Modifier.blur` (API 31+; below 31 the backdrop is `color.global.controlOnDeep`). The worker's token names are the
canonical ones (C-21 resolved).

## Do-not-copy

Retro: the bottom-left selected-photos thumbnail with its count badge ("9"), "2023 / nathan / retro.app" footer,
wordmark, Rive collage loader. Yope: day view (back circle, '26 May' title), loading HUD, watermark, stickers. Any count
of who answered; any 'missed' / 'late' marker for members without a tile.

## Gaps

| item | status | capture / decision |
|---|---|---|
| collage option (A / B / C, or a Retro recap-card composition — RC-14) | owner | owner |
| backdrop blur radius | not measurable (C-34 Gap) | none from stills |
| exact media-page corner | ±1.5 pt (fit limited by page content) | one raw iOS screenshot of a Retro recap preview |
| part-filled page in Yope | not observed | (only if option B stays) |
