# `week.recap` — the group's weekly recaps

Redesign on **Retro**: visual reference Retro's **recaps** — screen 19 "Create Recap" (close circle, title, month cards:
cover photo, serif month, grey year, chevron), screen 20 the **recap preview** (blurred photo page, close circle, the
recap card / full-bleed styles in a pager, page dots, a circle and a white "Share" pill) and screen 21 the **recap card**
(white card, photo grid, serif "2023" + name / domain footer). Our recaps are weekly only (created by the worker on Sunday,
`weekly_recap_isodow` = 7, at `weekly_recap_local_time`; off until the owner sets it). Two levels: the **recap list**
(`week.recap.layout.list`) and one **recap preview** (`week.recap.layout.preview`). Tokens: `design/tokens/social.json`
(`week.recap.*`) + `global.*`. Copy: `design/copy/social.json` (`week.recap.*`). Decisions: `design/MERGE_DECISIONS.md` →
Redesign — Social (RS-17 … RS-19).

## References

| id | file | used for |
|---|---|---|
| TC-REC | `references/auto/retro/press/tc-2023-12-recaps.png` (render, 1.695 px/pt) | **primary** for the list: phone 1 month cards (`week.recap.aspectRatio.weekCard`, `.radius.card`, text insets); phones 2–3 the card and full-bleed styles (as measured by the memory group, `layout.year.story.recapCard`) |
| TC-H | `references/auto/retro/press/tc-2023-12-retro-header.png` | card footer ("2023 / nathan / retro.app") |
| ST-04 | `references/auto/retro/store/retro-store-04.png` (render, 2.389 px/pt) | **primary** for the preview chrome (2026): full-width media page, close top-right, leading photo thumbnail (`week.recap.dimension.selectThumb`), page dots, "Share" pill — via the capture group's `collage.view.layout.screen` / `collage.share.layout.pill` |
| ST-02 | `references/auto/retro/store/retro-store-02.png` | "Recaps" (feature name) |
| WEB | `references/auto/retro/web/retro.app-42b38811bebcd07d.css` | note box (`.mediaGrid_noteContainer`) used for the recap text |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | "Select photos", "Creating your collage…", "When you fill in your weeks on Retro, you'll see recaps here.", "Add a memory" |

## Structure A — recap list (`week.recap.layout.list`)

Page sheet (C-29) over the group, content on `color.global.background`.
1. **Sheet header**: C-11 close circle (`size.global.circleButton`, `color.global.control`, `icon.global.close`) at the leading
   margin; centred `week.recap.list.title` ("Recaps", text role `sheetTitle`).
2. **Week cards**, newest first, full width inside `size.global.screenMargin`, `size.global.cardGap` apart, starting
   `size.global.titleToContent` below the header: shape `week.recap.aspectRatio.weekCard`, corners `week.recap.radius.card`
   (continuous), cover = the recap's first item (aspect fill). On the cover, `week.recap.dimension.weekCardTextInset` from the
   leading edge and `week.recap.dimension.weekCardTextTop` from the top (cap top): "Week {n}" (`photo.viewer.header.week`
   text; `font.global.display`, text role `displayMedium`, `color.global.textOnMedia`) and, `week.recap.dimension.weekCardLinePitch`
   below its baseline, the date range ("Jul 3 - 9", text role `listSubtitle`, `color.global.textOnMedia`); `icon.global.chevron`
   (`color.global.textOnMedia`) at the trailing top, aligned to the serif line's cap middle.
3. A recap still being made (`status = pending`) shows as a card filled with `color.global.control` (C-17 placeholder fill)
   with `week.recap.pending` in text role `body`, `color.global.textSecondary`, centred.
No segmented control: only weekly recaps exist (Retro's Yearly / Monthly / Weekly / All Posts has nothing to switch, RS-17).

## Structure B — recap preview (`week.recap.layout.preview`)

Full-screen, **dark in both appearances** (as `photo.viewer.layout.appearance`): page `color.global.backgroundDeep`. The
chrome is the **same screen the capture group measured on Retro's 2026 recap preview** (ST-04, `collage.view.layout.screen`,
`collage.share.layout.pill` — RC-15) and the pages are the **same recap styles the memory group defined for the year story**
(`layout.year.story.recapCard`, `dimension.year.story.*` — RM-8): one definition of Retro's recap preview in the product.
1. **Frame**: the media page of `collage.view.layout.screen` — full width, from the top safe area to
   `mediaPageBottomFromScreenBottom`, corners `mediaPageCornerRadius` (`layout.global.cornerStyle`), filled with the cover photo
   blurred (`layout.global.materials.backdrop`); its close circle (C-11 on media: `size.global.circleButton`,
   `color.global.controlOnDeep`, `icon.global.close` in `color.global.textOnMedia`) centred `closeCentreFromTrailing` /
   `closeCentreBelowPageTop`.
2. **Pages** (`week.recap.layout.pages`, swiped sideways inside the frame):
   - **page 1 — card**: `layout.year.story.recapCard` centred in the frame — width ratio, padding, `size.global.stripGap` gaps,
     4 columns up to 6 rows, cell aspect, corner ratio, footer; footer text: "Week {n}" (`font.global.display`, text role
     `headerTitle`) bottom-leading; trailing, right-aligned, the group name over the date range (text role `meta`,
     `color.global.textSecondary`). Fill rule for other photo counts: `week.recap.layout.gridFill` (**BLOCKED**).
     **Note** (only when the recap has text — `week.recap.layout.note`): a box the card's width, `week.recap.dimension.noteGap`
     under the card, corners `week.recap.radius.note`, padding `week.recap.dimension.notePaddingV` / `.notePaddingH`, fill
     `color.global.controlOnDeep`; the last editor's avatar (`size.global.avatarComment`) and name (`listTitle`) lead the first
     line, then the text (text role `body`, `color.global.textOnMedia`); card + note centred together in the frame.
   - **page 2 — cover**: the cover photo fills the frame (aspect fill, frame corners) under `layout.global.photoScrim`; "Week {n}"
     (`headerTitle` serif, `color.global.textOnMedia`) and the name / range stack at `dimension.year.story.frame.padding`,
     baseline `dimension.year.story.footer.baseline` above the frame bottom.
3. **Page dots** (C-31 on media: active `color.global.textOnMedia`, inactive `color.global.pageDotInactive` dark) centred,
   `dimension.year.story.dots.offset` below the frame.
4. **Bottom row** (centre `bottomRowCentreFromScreenBottom` of `collage.view.layout.screen`):
   - leading at `size.global.buttonMarginH`: the select-photos thumbnail — `week.recap.dimension.selectThumb` square, corners
     `week.recap.radius.selectThumb`, `week.recap.dimension.selectThumbBorder` border in `color.global.surfaceLight`, the recap's
     first item (aspect fill), no count badge → `week.edit`;
   - trailing: C-09 light pill `week.recap.saveAsAlbum` (`color.global.surfaceLight` / `color.global.onSurfaceLight`, text role
     `pill`) laid out as `collage.share.layout.pill` (height, `paddingHorizontal`, `trailingInset`) → the album sheet of
     `week.edit` with the recap's photos selected.

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| list close | C-11; `size.global.circleButton`, `color.global.control` | `week.recap.a11y.close` | dismisses the sheet |
| list title | C-29 sheet header; text role `sheetTitle` | `week.recap.list.title` | header trait |
| week card | `week.recap.aspectRatio.weekCard`, `.radius.card`, `.dimension.weekCardTextInset`, `.weekCardTextTop`, `.weekCardLinePitch`; text roles `displayMedium` / `listSubtitle`; `icon.global.chevron` | `photo.viewer.header.week` ("Week {n}"), range (data); label `week.recap.a11y.card` | → preview |
| preview close | C-11 on media; `collage.view.layout.screen` (`closeCentreFromTrailing`, `closeCentreBelowPageTop`) | `week.recap.a11y.close` | back to the list / opener |
| card grid cell | `layout.year.story.recapCard` | `photo.viewer.a11y.photo` | → `photo.viewer` (context = recap items in order) |
| card footer | `layout.year.story.recapCard` footer; text roles `headerTitle` / `meta` | "Week {n}", group name, range (data) | — |
| note | `week.recap.layout.note`, `.radius.note`, `.dimension.notePaddingV` / `.notePaddingH` / `.noteGap` | recap text (data) | — |
| page dots | C-31 (on media); `dimension.year.story.dots.offset` | page position (platform) | swipe pages |
| select-photos thumbnail | `week.recap.dimension.selectThumb`, `week.recap.radius.selectThumb`, `week.recap.dimension.selectThumbBorder`, `size.global.buttonMarginH` | `week.recap.a11y.edit` | → `week.edit` |
| Save as Album pill | C-09; `collage.share.layout.pill`, text role `pill` | `week.recap.saveAsAlbum` | → album sheet (`week.edit.md`) |

## States

| state | what shows | components · tokens · copy | source |
|---|---|---|---|
| loading (list) | two C-17-fill placeholder cards | C-28; `week.history.a11y.loading` | C-28 |
| loading (preview) | frame with the blurred cover; card cells as `color.global.control` placeholders until images load (`duration.global.fade` in) | C-28 | C-28 |
| pending (`status = pending`) | list: placeholder card with `week.recap.pending`; preview opened by link: the frame with the line centred | `week.recap.pending` | `retro.voice.progress` |
| empty (no recaps yet) | C-27 in the sheet: `icon.global.recap` → title → detail → C-07 outline CTA with `icon.global.add` | `week.recap.empty.title`, `.empty.detail`, `.empty.action` (→ `camera.capture` for this group) | APK-S |
| error | list: one tappable line under the header (text role `body`, `color.global.textSecondary`); preview: the same line centred in the frame | `week.recap.error.title` (tap reloads) | `retro.voice.error` |
| offline | cached recaps; nothing cached → error line + `chat.thread.offline.detail` | — | — |
| permission-denied | not applicable | — | — |

## Motion

| transition | tokens | Reduce Motion |
|---|---|---|
| list sheet in / out | native sheet (`spring.global.sheetPresent`, `duration.global.sheetPresent`) | system |
| list → preview | `duration.global.photoOpen` + `easing.global.standard` (cover opens like a photo) | cross-fade |
| page swipe | native pager (finger-tracked) | allowed |
| images appear | `duration.global.fade` | same |

## Haptics

| interaction | token |
|---|---|
| tap card / circle / pill (Android) | `haptic.global.tap` (iOS none) |
| page swipe | none (Retro's recap pager haptic not captured; the tick is reserved for dials and segmented choices) |

## Accessibility

- List: each card one button, label `week.recap.a11y.card` ("Recap of Week 27, July 3 to 9").
- Preview: the card is a group labelled `week.recap.a11y.card`; cells are buttons (`photo.viewer.a11y.photo`); the pager
  announces "page 1 of 2" (platform page control); close `week.recap.a11y.close`; circle `week.recap.a11y.edit`.
- Dynamic Type: `sheetTitle`, `displayMedium`, `listSubtitle`, `body` scale; the card footer keeps the card's proportions
  (its text scales inside the fixed card up to the footer height, then truncates — labels carry the full text).
- Contrast (`node tools/contrast.mjs`):

| foreground | background | kind | light | dark | pair |
|---|---|---|---|---|---|
| `color.global.onSurfaceLight` | `color.global.surfaceLight` | text | 21.00:1 pass | 21.00:1 pass | "Week 27", group name on the white card |
| `color.global.textSecondary` | `color.global.surfaceLight` | text | **2.85:1 FAIL** | **2.85:1 FAIL** | date range on the card (meta 13) |
| `color.global.textOnMedia` | `color.global.controlOnDeep` | text | 15.13:1 pass | 15.13:1 pass | note text, close glyph |
| `color.global.onSurfaceLight` | `color.global.surfaceLight` | text | 21.00:1 pass | 21.00:1 pass | "Save as Album" pill |
| `color.global.textPrimary` | `color.global.background` | text | 21.00:1 pass | 21.00:1 pass | list title |
| #808080 (`color.global.pageDotInactive` dark) | `color.global.backgroundDeep` | nontext | 5.32:1 pass | 5.32:1 pass | inactive page dot (preview is dark) |

  Text on cover photos (list cards, page 2) has no fixed backdrop (photo-dependent; Retro draws none on month cards).

## Data & actions

- **Reads**: `weekly_recaps` (§5.14) of the group: `id`, `week_start`, `items` (ordered post ids; fetch from `posts` — RLS
  drops hidden ones), `text`, `status`, `edited_by`; `posts` / `media` (`thumb_path`, `display_path`); `profiles`
  (`edited_by`); `groups.name`, `groups.time_zone` (week number and range).
- **Realtime**: `post_deleted` → drop the item (§8.2); recap rows are not published — refetch on appear / foreground.
- **Push**: `notifications.push.recapReady.*` (capture group), push type `recap_ready`.
- **Navigation in**: `groups.screen` (recaps entry → list; its label may use `week.recap.open`), `week.history` week menu
  (→ preview), `albums.list` empty action (→ list), `DeepLink.recap(groupID:recapID:)` (`app://recap?group=…&recap=…` → preview).
- **Navigation out**: `photo.viewer`, `week.edit` (editor; album sheet).

## Platform notes

- iOS: list `.sheet`; preview `.fullScreenCover` with `.environment(\.colorScheme, .dark)`; pager `TabView(.page)` with its
  own dots hidden (C-31 drawn by the app); backdrop blur = a blurred copy of the cover image (`.blur`, radius not measurable —
  C-34 Gap) clipped to the frame shape.
- Android: `ModalBottomSheet(skipPartiallyExpanded = true)` for the list; preview route in `DsTheme(dark = true)`;
  `HorizontalPager`; blur via `Modifier.blur` (API 31+) or a pre-blurred bitmap below.
- Week label: group time zone, Monday start.

## Do-not-copy

- Retro's "Share" export targets (Stories, Reels, TikTok, Postcard), recap styles behind a paywall ("Recaps Pro"), sticker
  collage tools, the "retro.app" domain line, Retro's year / month / all-posts recaps.
- Yope's grid card with uppercase label, "recap | pics" capsule, "Add {n} pics more to get a recap" progress.

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| `week.recap.layout.gridFill` | **BLOCKED** (development approximation: fill row by row, empty cells blank, beyond 24 not drawn) | one Retro recap preview (Week style) for a week with 5 photos |
| old BLOCKED `shortRowSplit`, `shortRowHeight`, `scrim`, `page2` | closed: Yope's card replaced by Retro's card and full-bleed page (RS-17) | — |
| preview chrome | 2026 render values via the capture group (RC-15); this pass's TC-REC 2023 readings (inset panel, top-left glass close, 41.9-pt circle) superseded (RS-17) | one raw screenshot of Retro's recap preview |
| backdrop blur radius | not measurable (C-34 Gap) | Retro's iOS internals |
| recap text placement | composition: Retro's journal note under the card (RS-19) | — (Retro recaps carry no text) |
| list card values are a 2023 render (±1 %) | — | one raw screenshot of "Create Recap" |
