# `year.story` — the group's December year story ("Year in Photos")

Visual reference: **Retro's yearly recap** — "Year in Photos" (`retrospective_page_*` copy) shown the way Retro shows
a recap: one rounded full-width media page on black, a close circle, page dots and a white "Share" pill below
(`references/auto/retro/store/retro-store-04.png` (2026), `press/tc-2023-12-recaps.png` phones 2–3,
`press/tc-2023-12-retro-header.png`; components C-34, C-31, C-22, C-35). Mechanics reference: **Spotify Wrapped** (2024 tap-through pacing: one fact per card, tap halves,
headline / subline reveal) with VidDay's documented 4-s card time. Retro's own retrospective pages use PP Neue
Montreal (commercial) — **not bundled**: every text uses the global type roles. Voice: `retro.voice.retrospective` +
the Retro set. Tokens: `design/tokens/memory.json` (`*.year.story.*`) + `design/tokens/global.json`. Copy:
`design/copy/memory.json` (`year.story.*`). Decisions: `design/MERGE_DECISIONS.md` → "Redesign — Memory (RM-*)".

What it is: from December 1 (group-local, `year_story_release_month_day`) each group that posted that year gets a
story computed by the worker (`year.compute`): the number of photos the group shared (group-level, docs/SPEC_FLAGS.md
T3), the busiest month, the most-reacted photos (ordered, never with numbers or ranks, T2) and the collages of days
everyone answered the daily moment. It ends on Retro's recap preview, from which the year can be shared.

## References

| id | image / source | what it verifies |
|---|---|---|
| ST-04 | `references/auto/retro/store/retro-store-04.png` (2026 render, 2.389 px/pt) | recap preview: media page full width from the safe-area top to 94.8 pt above the bottom (393 × 698 = 9:16), corners 26.5, close #262626 36 pt top-right (centre 37.7 / 38), page dots 16.1 below the page, 'Share' pill 43.5 high (label 17 semibold, padding 23) at the trailing 20-pt margin, row centre 59.2 above the bottom — held by `collage.view.layout.screen` / `collage.share.layout.pill` (capture group) |
| TC-REC p2 | `references/auto/retro/press/tc-2023-12-recaps.png` phone 2 (2023, 1.695 px/pt) | recap card on the blurred backdrop (82.5 % of the frame, padding 2.41 %, 4 columns × 6 rows, cells 1.12:1, corners 5.1 %, footer 21 %); 4 page dots; older chrome (11-pt inset frame, close top-left) superseded by ST-04 |
| TC-REC p3 | same file, phone 3 | full-bleed photo style: '2023' serif (headerTitle size) bottom-left, baseline 24.8 above the frame bottom, 'nathan' / 'retro.app' right-aligned, text 19.5 from the frame edges |
| TC-H | `references/auto/retro/press/tc-2023-12-retro-header.png` | the yearly recap card ('2023 / nathan / retro.app') |
| VID | `references/auto/retro/video/ig-DDbA_F7x-j7-retrospective-contact-2fps.png` | the profile's 'Your 2024 Retrospective' photo card with a chevron (entry pattern) |
| APK | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `retrospective_page_title_*`, `home_feed_card_annual_recap_title` 'Year in Photos', `recap_*` |
| Wrapped (mechanics) | `references/auto/wrapped/frames/wrapped24-rec-emilycraig-reveal-positions.csv`, `…-reveal-fit.csv`; `references/auto/wrapped/frames/wrapped24-rec-emilycraig-sheet-every3s.png` | reveal durations, distances and curves; lists of 5; tap-through model |
| VidDay (mechanics) | `references/auto/vidday/help/vidday-help-display-length-2025-02-07.png` | 4-s card |

## Structure

**A. Entry (placed by `groups.screen`).** One Retro feed card per `year_stories` row of the group with
`status = 'ready'`, newest year first, side by side in the feed pager (`size.global.cardGap`): title
`year.story.entry.title` ("Year in Photos"), line `year.story.entry.subtitle` ("{year} Recap"), action
`year.story.entry.button` ("View memories"). A story appears once ready (from 1 December) and **stays for good** (owner
decision 31: kept in the group's memories; nothing removes it on 1 January). Card component and position belong to the
`groups.screen` pass. Tap → B (full-screen) for that year.

**When.** The story is computed on 1 December (`year_story_release_month_day`) and **refreshed on 31 December** at the
end of the group's waking window (the weekly recap's "last waking moment"), so December counts; deleting a photo or
adding / removing a self-tag recomputes it too. The group hears **once**, the first time it is ready
(`notifications.push.yearStory.*`, type `year_story`, Android channel "Year in Photos"); refreshes never notify
(owner decision 31).

**B. Player** (full-screen cover; media — dark in both appearances: render the subtree in the dark appearance,
`layout.global.appearance.media`). Page `color.global.backgroundDeep`. Top to bottom:

1. **Frame** (`layout.year.story.frame` → the recap-preview media page `collage.view.layout.screen`): full screen
   width, from the safe-area top to `mediaPageBottomFromScreenBottom` (94.8 pt) above the screen bottom, corners
   `mediaPageCornerRadius` (26.5, `layout.global.cornerStyle`), content clipped. Each card is laid out in a 9:16 box as
   wide as the frame, centred vertically; backdrops and full-bleed photos fill the whole frame. The share image renders
   the 9:16 box at 1080 px wide.
2. Inside the frame, on top of the card:
   - **Close** circle top-right (C-11 on media): `size.global.circleButton`, `color.global.controlOnDeep`,
     `icon.global.close` (glyph ≈ 9.7 pt) in `color.global.textOnMedia`, centre `closeCentreFromTrailing` /
     `closeCentreBelowPageTop` of `collage.view.layout.screen` (37.7 / 38 pt).
   - **Position pill** top-left (components C-22): `size.global.positionPillHeight` capsule,
     `color.global.controlOnDeep`, label `year.story.position` ("3 of 12") in text role `badge`,
     `color.global.textOnMedia`; leading edge at `dimension.year.story.frame.padding`, centred on the close circle's
     centre line. Hidden on the summary (the page dots take over).
3. **Bottom row**, centre `bottomRowCentreFromScreenBottom` (59.2 pt) of `collage.view.layout.screen` above the
   screen bottom:
   - leading **circle** (C-11 on media): `size.global.circleButton`, `color.global.controlOnDeep`, at
     `size.global.buttonMarginH` from the leading edge: `icon.global.pause` / `icon.global.play` (cards) or
     `icon.year.story.replay` (summary), glyph in a `size.global.icon` box, `color.global.textOnMedia`;
   - trailing **Share** pill (`collage.share.layout.pill`: height 43.5, horizontal padding 23, trailing inset
     `size.global.buttonMarginH`), `radius.global.capsule`, fill `color.global.surfaceLight`, label `year.story.share`
     text role `button` in `color.global.onSurfaceLight`. Shown on fact cards and the summary only (table below);
     elsewhere its place stays empty.
   - **Page dots** (C-31, summary only): centred, centre `dimension.year.story.dots.offset` below the frame;
     `size.global.pageDot`, `size.global.pageDotPitch`; active `color.global.textOnMedia`, inactive
     `color.global.pageDotInactive` (dark value).
4. **Tap zones** over the frame (`layout.year.story.navigation`): right half → next card, left half → previous (first
   card: nothing). Close, pill and the bar take their own taps. Auto-advance after `duration.year.story.card` while
   playing; the leading circle pauses / plays. The story starts playing.

**Card kinds** (inside the frame):

- **Text card** — backdrop: the story's cover photo blurred over the whole frame (`layout.global.materials.backdrop`;
  cover = first id of `data.most_reacted`, else the first of `year_stories.post_ids`), then `layout.global.photoScrim`.
  A centred text block, width = frame width − 2 × `dimension.year.story.frame.padding`: headline in
  `font.global.display`, text role `displayMedium`, `color.global.textOnMedia`, centred; subline (when present) text
  role `textButton`, `color.global.textOnMedia`, centred, its cap top `dimension.birthday.request.headlineToMessage`
  below the headline's baseline (Retro's serif headline → line gap). Reveal (below).
- **Photo card** (Rewind / full-bleed recap style) — the photo full-bleed in the frame (aspect-fill, display
  rendition), `layout.global.photoScrim`; footer at `dimension.year.story.frame.padding` from the sides, baselines
  `dimension.year.story.footer.baseline` above the frame bottom: leading the date (`layout.year.story.dateFormat`,
  `font.global.display`, text role `displaySmall`, `color.global.textOnMedia`); trailing `year.story.mostReacted.photo`
  ("Post by {name}") text role `listTitle`, `color.global.textOnMedia`, right-aligned. No number, rank or reaction glyph.
- **Collage card** — the collage image (`collages.image_path`) fitted whole inside the frame (never cropped — tenet
  "Nothing gets lost") on its own blurred backdrop (`layout.global.materials.backdrop`), scrim as above; footer: the
  date (`layout.year.story.dateFormat`, as the photo card), no trailing text.

**Cards, in order** (skip a card whose data is missing; `data` = worker `YearStoryData` v1):

| # | card | kind | content | Share pill |
|---|---|---|---|---|
| 1 | intro | text | headline `year.story.intro.title` ("Year in Photos"), subline `year.story.intro.subtitle` ("{group} · {year}") | no |
| 2 | look back | text | headline `year.story.lookBack.title` ("Let’s look back at your 52 weeks") | no |
| 3 | photos shared (T3) | text | headline `year.story.moments.count` (`{group}`, `{count}` = `data.moments_shared`) | yes |
| 4 | busiest month | text | headline `year.story.busiestMonth.title` (`{month}` = `data.busiest_month.month` as `layout.year.story.monthFormat`) | yes |
| 5 | most-reacted, setup | text | headline `year.story.mostReacted.title` | no |
| 6…10 | most-reacted photos | photo | the first `count.year.story.listLength` ids of `data.most_reacted`, in that order (T2) | your own photo only |
| — | self-tagged, setup | text | headline `year.story.tagged.title` ("The moments you were in") | no |
| — | self-tagged photos | photo | up to `count.year.story.listLength` of `data.self_tagged` (photos a member tagged themselves in, "I'm in this") not already shown above, spread evenly over the year, in time order; footer trailing `tagging.with` ("with Ana and Rui": who tagged themselves in it) — no count, no ranking (directive: self-tagging powers year stories; Retro's "most tagged friend" ranking is do-not-copy) | your own photo only |
| 11 | together, setup | text | headline `year.story.together.title`, subline `year.story.together.aside` | no |
| 12…16 | everyone-was-there days | collage | the first `count.year.story.listLength` entries of `data.everyone_days` (chronological) | yes |
| 17 | outro | text | headline `year.story.outro.title` ("Here’s to another year in the books") | yes |
| 18 | summary | C | — | yes |

**Who can share what (owner decision 12).** A photo leaves the app only when it is the viewer's own: a most-reacted
photo card shows the Share pill only on the viewer's own photo; on another member's photo the pill is not shown (its
place stays empty, nothing moves). The pieces made for sharing as the group's — the text cards, the everyone-was-there
collage cards and the summary's recap card and full-bleed cover — keep their Share, as do the other group pieces (the
same-moment collage pages, `collage.share`; the week recap, `week.recap`). Evidence: Retro's Rewind and Timehop resurface
only your own photos; BeReal offers no way to share another person's post; Retro's recap preview and Spotify Wrapped
share the recap as a whole.

**C. Summary** (`layout.year.story.summary`) — a horizontal pager of two share styles inside the frame, page dots
below it, the leading circle = replay (`year.story.summary.replay` as its label; → card 1), Share = the style in view:
1. **Recap card** (`layout.year.story.recapCard`; C-34): the cover blurred over the frame; a card
   `color.global.surfaceElevated` 82.5 % of the frame width, centred, corners 5.1 % of its width; a grid of 4 columns
   × up to 6 rows of the year's photos (cells 1.12:1, `size.global.stripGap` gaps, padding 2.41 % of the card width;
   photos = `data.most_reacted` first, then `year_stories.post_ids` in order, deduplicated; only full rows; offered
   only when there are at least 4 photos); footer 21 % of the card width: the year (`font.global.display`, text role
   `headerTitle`, `color.global.textPrimary`) bottom-left at the card padding; the group name (text role `listTitle`,
   `color.global.textPrimary`) right-aligned; under it the app line `year.story.card.app` (text role `meta`,
   `color.global.textSecondary`): the owner's app name ("Jolt", `config/app.json` displayName) where Retro prints its
   own ('retro.app').
2. **Full-bleed cover**: the cover photo filling the frame, `layout.global.photoScrim`; footer as the photo card but
   with the year (text role `headerTitle`) leading and the group name (`listTitle`) + app line (`meta`,
   `color.global.textOnMedia`) trailing (TC-REC p3).

**D. Share image** (`layout.year.story.shareCard`): the card in view without close, position pill or bar, rendered at
1080 × 1920 px (scale = 1080 ÷ frame width), PNG, handed to the share sheet (`layout.year.story.shareSheet`) with
`year.story.entry.subtitle` ("2025 Recap") as the preview title.

## Elements

| element | component · tokens | copy keys | behaviour |
|---|---|---|---|
| entry card | `groups.screen` feed card | `year.story.entry.title`, `.entry.subtitle`, `.entry.button` | opens B |
| page / frame | `color.global.backgroundDeep`, `layout.year.story.frame`, `collage.view.layout.screen` (media page) | — | content in a 9:16 box |
| close | C-11 on media: `size.global.circleButton`, `color.global.controlOnDeep`, `icon.global.close`, `color.global.textOnMedia`, `collage.view.layout.screen` (close centre) | `year.story.a11y.close` | dismisses |
| position pill | C-22: `size.global.positionPillHeight`, `color.global.controlOnDeep`, text role `badge`, `color.global.textOnMedia`, `dimension.year.story.frame.padding` | `year.story.position` | position only |
| pause / play / replay | C-11 on media: `size.global.circleButton`, `color.global.controlOnDeep`, `size.global.buttonMarginH`, `icon.global.pause` / `.play`, `icon.year.story.replay`, `size.global.icon`; row centre `collage.view.layout.screen` | `year.story.a11y.pause`, `.a11y.play`, `year.story.summary.replay` | auto-advance on / off; replay → card 1 |
| Share pill | C-09 recap size: `collage.share.layout.pill`, `radius.global.capsule`, `color.global.surfaceLight`, `color.global.onSurfaceLight`, text role `button` | `year.story.share` | renders D, opens the share sheet; not shown on another member's photo card (owner decision 12) |
| text card | `layout.global.materials.backdrop`, `layout.global.photoScrim`, `font.global.display` + text role `displayMedium`, text role `textButton`, `color.global.textOnMedia`, `dimension.year.story.frame.padding`, `dimension.birthday.request.headlineToMessage` | card keys above | reveal |
| photo card | `layout.global.photoScrim`, text roles `displaySmall` / `listTitle`, `dimension.year.story.footer.baseline`, `layout.year.story.dateFormat` | `year.story.mostReacted.photo`, `year.story.a11y.photo` | display rendition |
| collage card | `layout.global.materials.backdrop`, text role `displaySmall`, `layout.year.story.dateFormat` | `year.story.a11y.collage` | fitted, never cropped |
| summary | `layout.year.story.summary`, `layout.year.story.recapCard`, C-31 dots (`size.global.pageDot`, `.pageDotPitch`, `color.global.pageDotInactive`), `dimension.year.story.dots.offset` | `year.story.card.app` | pager |
| tap zones | `layout.year.story.navigation` | `year.story.a11y.next`, `.a11y.previous` | halves |

## States

| state | design (components) | copy | source |
|---|---|---|---|
| loading (row, photos, collages) | frame on the black page with the platform activity indicator centred (C-28, `color.global.textSecondary`); close available | `year.story.loading` (announcement) | C-28 |
| not ready (`status = 'pending'`, `data` null) | not a screen: the entry is hidden | — | docs/API.md 5.19 |
| empty | none: a story exists only for groups that posted that year; cards without data are skipped | — | docs/API.md 10 |
| error | C-27 error variant centred in the frame on black: title `emptyTitle` `color.global.textOnMedia`, detail `emptyDetail` `color.global.textSecondary`, light pill C-09 (`size.global.pillHeight`, text role `pill`) | `year.story.error.title`, `.error.detail`, `.error.retry` | `retro.voice.error` |
| offline | same block | `year.story.offline.title`, `.offline.detail`, `.error.retry` | `retro.voice.error` |
| photo deleted while open | the worker recomputes (`year.recompute`); drop the card on `post_deleted`; re-fetch on foreground | — | docs/API.md 6.2 |
| permission-denied | n/a; the share sheet's "save image" asks for photo-library add access itself (string owned by `system.permissions`) | — | — |

## Motion

| transition | tokens | Reduce Motion |
|---|---|---|
| open / close player | native full-screen presentation (`easing.global.native`) | system |
| card → card | cut (Wrapped's chapter animations are brand art, not reproduced); the position pill updates with it | same |
| text reveal (cards with a subline): headline moves up `dimension.year.story.reveal.headlineShift` over `duration.year.story.reveal.headline` (`easing.year.story.reveal`); the subline starts `duration.year.story.reveal.sublineDelay` later from `dimension.year.story.reveal.sublineOffset` below over `duration.year.story.reveal.subline` (`easing.year.story.reveal.subline`); both fade in over `duration.global.fade` | Wrapped (mechanics) | cross-fade of the same durations (`layout.global.reduceMotion`) |
| auto-advance | every `duration.year.story.card` while playing | stays (user-pausable, WCAG 2.2.2) |
| Share pill show / hide | fade `duration.global.fade`, `easing.global.standard` | fade |
| summary pager | native paging | system |

## Haptics

Close, pause / play / replay, Share → `haptic.global.tap` (Android VIRTUAL_KEY; iOS none). Card change and pager page
change: none (Retro plays a tick only on dial / scrubber steps). The share sheet plays its own.

## Accessibility

- **Labels / traits:** close `year.story.a11y.close`; pause / play `year.story.a11y.pause` / `.play`; replay
  `year.story.summary.replay`; Share: visible text, button. Headline: header trait. Photo card: the photo is labelled
  `year.story.a11y.photo` ("Photo by {name}, {date}"); collage `year.story.a11y.collage`. Position pill: read as part of
  the frame's value ("3 of 12"). Backdrop, scrim and dots: hidden (the pager announces "page N of M").
- **Navigation:** custom accessibility actions `year.story.a11y.next` / `.previous` on the frame; after each change
  post a screen-changed / `announceForAccessibility` so the new headline is read. VoiceOver / TalkBack running →
  start paused (auto-advance would cut speech; WCAG 2.2.2).
- **Focus order:** close → position → headline → subline (or photo → footer) → pause / play → Share.
- **Dynamic Type:** `displayMedium` → largeTitle, `displaySmall` → title2, `textButton` → body, `listTitle` →
  subheadline (`layout.global.textStyleMap`); text wraps inside the frame padding; the share image always renders at
  the default size.
- **Contrast** (`node tools/contrast.mjs`; dark in both appearances unless noted):

  | pair | ratio | needs | result |
  |---|---|---|---|
  | `color.global.textOnMedia` on the blurred backdrop / photo under `layout.global.photoScrim` | photo-dependent; on the scrim end over white (#666666) 5.74 | 3 (≥ 24 pt) / 4.5 | pass at the bottom; text cards centre the text where the scrim is weaker — **not guaranteed** over light photos (reported) |
  | close / bar glyph `color.global.textOnMedia` on `color.global.controlOnDeep` | 15.13 | 3 | pass |
  | `color.global.controlOnDeep` circle vs the black page | 1.39 | 3 | **FAIL** (non-text; the glyph identifies it — C-11 failure 2, reported) |
  | position pill text on `color.global.controlOnDeep` | 15.13 | 4.5 | pass |
  | Share pill label on `color.global.surfaceLight`; pill vs page | 21.00; 21.00 | 4.5; 3 | pass |
  | page dots: active vs page 21.00; inactive (dark value #808080) vs page 5.32; active vs inactive 3.95 | — | 3 | pass |
  | recap card: `color.global.textPrimary` on `color.global.surfaceElevated` | light 21.00 · dark 17.76 | 4.5 | pass |
  | recap card app line `color.global.textSecondary` on `color.global.surfaceElevated` | light 2.85 · dark 6.23 | 4.5 | **FAIL in light** (Retro's grey; reported, no sourced alternative) |
  | error block: `color.global.textOnMedia` / `color.global.textSecondary` on black | 21.00 / 7.37 | 4.5 | pass |

## Data & actions

- **Read:** `from("year_stories").select().eq("group_id", g).eq("year", y).single()` → `status`, `data`
  (`YearStoryData` v1: `moments_shared`, `busiest_month.month`, `most_reacted` post ids, `everyone_days`
  `{local_date, collage_id, post_ids}`), `post_ids`. Then `posts` + `media` (display renditions; thumbs for the recap
  grid) and `profiles` for most-reacted ids (RLS drops posts hidden by a block — skip those), `collages` by id
  (`image_path`, `status = 'ready'` only). Signed URLs, 1 h. Dates in `data.time_zone`.
- **Writes:** none; share images are rendered on the device.
- **Realtime:** `group:<group_id>` `post_deleted` → drop that card (and from the recap grid).
- **Navigation in:** the entry on `groups.screen`; deep link `DeepLink.yearStory(groupID:year:)` /
  `app://year-story?group=<id>&year=<yyyy>` (`ios/Packages/AppCore/Sources/AppModels/DeepLink.swift`,
  `android/core/model/src/main/kotlin/app/model/DeepLink.kt`). Push type `year_story` exists but is not sent (owner
  decision). **Out:** close → group screen; share sheet.

## Platform notes

- iOS: `.fullScreenCover`, `.environment(\.colorScheme, .dark)` on the subtree, status bar light; frame = a
  `GeometryReader`-sized view clipped with `RoundedRectangle(cornerRadius:style: .continuous)`; share via `ShareLink`
  with an `ImageRenderer` PNG at 1080 × 1920 px (`renderer.scale = 1080 / frameWidth`). Backdrop blur: `.blur` on the
  aspect-fill image (radius not sourced — components C-34 gap).
- Android: full-screen destination, `DsTheme(dark = true)` around the content, edge-to-edge; frame `Box` with
  `RoundedCornerShape`; share image drawn into a `GraphicsLayer` at 1080 × 1920 px, `Intent.createChooser(ACTION_SEND)`
  via `FileProvider`; blur `Modifier.blur` (API 31+; below 31 the backdrop is the photo under `color.global.scrim`).
- Share glyph is not shown (the pill carries the word, as Retro's recap preview).

## Do-not-copy

Retro's per-person retrospective pages ("You took %1$s photos this year", "%1$s was your biggest fan", "these were
your closest friends", "the ones your friends loved the most", likes and comments counts, distance travelled, places,
"Days Captured / Moments Captured" summary); PP Neue Montreal / ED Lavonia / Fraktion Mono type and recap stickers;
the Retro wordmark and 'retro.app' line (ours is the owner's app name); Spotify's logo, colours, card art, percentiles,
numbered top-5 lists, sound toggle and progress-bar segments; any per-person count.

## Gaps

| item | status | smallest capture that closes it |
|---|---|---|
| Retro's "Year in Photos" pages themselves | not captured (strings only); composed from the recap preview + C-35 | one RAW screen recording of Retro's Year in Photos (December) |
| backdrop blur radius | not measurable (C-34) | — (Retro's iOS app internals) |
| app line on the recap card | closed 2026-10-17: the owner named the app (`config/app.json` displayName) | — |
| recap-preview values are from App Store / press renders (±3 %) | SOURCED, render; shared with `collage.*` (RM-8) | one RAW screenshot of Retro's recap preview (Profile → Recaps → a year) |
| auto-advance 4 s, tap halves, reveal curves | mechanics (VidDay / Wrapped) | Wrapped 30 s recording with touches (research capture 1) |
| moments-shared number (T3), most-reacted order (T2), which five everyone-days | built as specified | owner decision (docs/SPEC_FLAGS.md) |
