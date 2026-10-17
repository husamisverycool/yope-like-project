# `birthday.tribute` — the birthday video and the screen it plays on

Visual reference: **Retro screens 22 / 23 and 20** (docs/SURFACES.md): a media page (black in both appearances) with
the display serif title at the margin (Rewind, C-35) and Retro's recap-preview bottom bar (circle + white "Share"
pill, `references/auto/retro/store/retro-store-04.png`, `press/tc-2023-12-recaps.png`). Mechanics reference: **Tribute / VidDay** (the video's
structure and timings; the worker renders it). The video's own colours and weights are restyled on Retro's media look;
its geometry stays the references'. Voice: Retro set + `P-BT-1`. Tokens: `design/tokens/memory.json`
(`*.birthday.tribute.*`; the bottom row is the recap preview's, `collage.view.layout.screen` / `collage.share.layout.pill`) + global. Copy: `design/copy/memory.json`
(`birthday.tribute.*`). Decisions: `design/MERGE_DECISIONS.md` → "Redesign — Memory (RM-*)".

Flow: requests close at 00:00 group-local on the birthday (`due_at`); if anyone contributed, the worker renders the
video and, at or after `due_at`, delivers it (`delivered_at`) and sends the honoree one push. **Nobody can read it
before delivery; then the honoree and the members who contributed to it (not blocked with the honoree)** — VidDay:
"The final video is private right from the start!", then "Share with Friends" sends it to the contributors
(`references/auto/vidday/INDEX.md`; migration 0034, MERGE_DECISIONS FV-3). Members who did not contribute never see it:
it carries the contributors' photos and lines, made for one person.

## References

| image / video | what it verifies |
|---|---|
| `references/auto/retro/press/tc-2025-12-rewind-device-a.png` (RAW) | serif title on a black / media page at the margin, `size.global.titleTop` |
| `references/auto/retro/store/retro-store-04.png` (recap preview, 2026) | bottom row: leading control + white "Share" pill (43.5 high, label 17 semibold, padding 23) at the 20-pt margin, row centre 59.2 pt above the bottom (`collage.view.layout.screen`, `collage.share.layout.pill`) |
| `references/auto/retro/press/tc-2023-07-retro-2b.jpg` phone 2 | media shown at full width, native aspect, letterboxed on black (C-22) |
| Tribute samples https://website.tribute.co/6KY_IZ1tLME.mp4, https://website.tribute.co/QQe5RpbFIyI.mp4; VidDay tour + theme render (`references/auto/vidday/frames/…`) | video structure, 16:9, hard cuts, title hold / crossfade, 4-s photo slots, end slot (mechanics) |
| `references/auto/tribute/web/tribute-web-video-editor-name-badge*` | caption position / sizes (name badge + caption text) |

## A. The video (worker contract)

`layout.birthday.tribute.structure`: **title card → one card per contribution → end card**, no audio.

| # | segment | content | timing |
|---|---|---|---|
| 1 | title card | `layout.birthday.tribute.titleCard`: `background` #000000, `textColor` #FFFFFF (Retro media), weight 400 (Retro display role); text `birthday.tribute.titleCard` ("Happy birthday, {name}!") sized `fontSizeRatio` × video height, wrapped inside `maxWidthRatio` × width, centred, block centre at `centerYRatio` × height (VidDay geometry) | visible `duration.birthday.tribute.titleHold`, then crossfade `duration.birthday.tribute.titleCrossfade` into card 2 |
| 2…n | contribution | the contributor's photo (display rendition), whole photo fitted inside the 16:9 frame on `color.birthday.tribute.pillarbox`; contributor's first name + their line laid out by `layout.birthday.tribute.caption` (Tribute geometry; band `scrim` #00000099 = `color.global.scrim`, name weight 600, line weight 400, white) | `duration.birthday.tribute.photoHold` each; `duration.birthday.tribute.clipTransition` (0 = hard cut) between them |
| n+1 | end card | `layout.birthday.tribute.endCard` (as the title card) with `birthday.tribute.endCard` ("We love you!") | `duration.birthday.tribute.endTransition` (0 = hard cut) in, then `duration.birthday.tribute.endHold` |

Canvas `layout.birthday.tribute.video` = 1920 × 1080 at 29.97 fps. Contribution order: worker order (`created_at`).

**Token names and copy keys the worker reads** (`TRIBUTE_TOKEN_NAMES` in `backend/worker/src/tribute/render.ts`;
`WORKER_COPY_KEYS` in `backend/worker/src/copy.ts`) — **all kept with the same names and shapes**:

| name | value | level |
|---|---|---|
| `layout.birthday.tribute.video` | `{ width: 1920, height: 1080, fps: 29.97 }` | SOURCED |
| `duration.birthday.tribute.titleHold` / `.titleCrossfade` / `.photoHold` / `.clipTransition` / `.endTransition` / `.endHold` | 1167 / 600 / 4000 / 0 / 0 / 10003 ms | SOURCED |
| `color.birthday.tribute.pillarbox` | `#000000` | SOURCED |
| `layout.birthday.tribute.titleCard`, `.endCard` | `{ background: "#000000", textColor: "#FFFFFF", fontWeight: 400, fontSizeRatio: 0.084, maxWidthRatio: 0.405, centerYRatio: 0.5 }` | SOURCED (Retro + VidDay) |
| `layout.birthday.tribute.caption` | `{ textColor: "#FFFFFF", nameFontWeight: 600, nameFontSizeRatio: 0.0463, lineFontWeight: 400, lineFontSizeRatio: 0.0795, leftRatio: 0.0577, bottomRatio: 0.0861, maxWidthRatio: 0.8845, gapRatio: 0.0099, scrim: "#00000099" }` | SOURCED (Retro + Tribute) |
| copy `birthday.tribute.titleCard`, `birthday.tribute.endCard` | "Happy birthday, {name}!", "We love you!" | SOURCED |

Worker hand-offs (MERGE RM-12): render the card text in the display serif (Noto Serif, OFL — `font.global.display`
Android) and the caption in Inter (OFL — `font.global.family` Android) instead of Roboto; weight 600 maps to Roboto
Medium until then. `backend/worker/COPY_KEYS.md` still describes the previous values (paper / navy band) in its status
column.

## B. The tribute screen (in the app)

Full-screen cover; media page `color.global.backgroundDeep`, dark in both appearances (render the subtree dark):
1. **Header (C-35 / C-01 placement on media):** title `birthday.tribute.title` ("Your birthday video") for the
   honoree, `birthday.tribute.title.member` ("{name}'s birthday video") for anyone else — `font.global.display`, text
   role `headerTitle`, `color.global.textOnMedia`, leading `size.global.screenMargin`, baseline
   `size.global.titleTop` below the safe-area top, up to two lines; under it the group name (data) in text role
   `textButton`, `color.global.textSecondary`, baseline `dimension.onthisday.subtitleBaseline` below the title's.
   Close circle on media (C-11: `size.global.circleButton`, `color.global.controlOnDeep`, `icon.global.close`,
   `color.global.textOnMedia`) at the trailing margin (`size.global.headerInset`), centred on the title's first-line
   cap middle.
2. **Player** (`layout.birthday.tribute.player`): full screen width, 16:9, centred vertically in the space between the
   header and the bar (C-22 photo placement), native controls, poster = `poster_path` (the title card). No audio.
3. **Bottom row** (Retro recap preview, as `year.story`): centre `bottomRowCentreFromScreenBottom` of
   `collage.view.layout.screen` (59.2 pt) above the screen bottom; leading circle (C-11 on media:
   `size.global.circleButton`, `color.global.controlOnDeep`, `icon.global.download` in a `size.global.icon` box,
   `color.global.textOnMedia`) at `size.global.buttonMarginH` — label `birthday.tribute.download` ("Save to Camera
   Roll"); trailing Share pill (`collage.share.layout.pill`, `radius.global.capsule`, `color.global.surfaceLight` /
   `color.global.onSurfaceLight`, text role `button`) `birthday.tribute.share` ("Share").
   **The bottom row is the honoree's only** (owner decision 12: a photo leaves the app only when it is the viewer's
   own; the tribute is the honoree's gift, as Tribute / VidDay hand the finished video to the recipient). Contributors
   see the title, group, close and player, and no bottom row; the app downloads no local copy for them.

## C. Entry on the group screen (MERGE FV-3)

Where the honoree finds the video on the day and afterwards, and where a contributor finds it once it is given: one
**feed card** per video in the members' pager of `groups.screen` (item 8), the same composition as the year story's
card (C-18 geometry, `layout.global.photoScrim`, text role `displaySmall`, C-09 light pill), after the week's question
card and before the on-this-day and year-story cards — the pager runs newest first, and a birthday video is newer than
the memories of earlier years. Cards come from `group_tributes` (docs/API.md §6.4): delivered, `ready`, the caller's own
or one they contributed to, newest delivery first. **Kept for good**, as the year story's cards (owner decision 31) —
the group's memories. A muted group still shows it (mute silences pushes; the card sends nothing and asks for nothing).

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| header glyph | `icon.global.video` (Retro's video glyph) in the `size.global.avatarList` box | — | — |
| card image | the video's poster (`poster_path`, the title card), aspect-fill; none → `color.global.backgroundDeep` | — | — |
| title | `font.global.display`, text role `displaySmall`, `color.global.textOnMedia` | `birthday.tribute.title` (honoree) / `birthday.tribute.title.member` (contributor) | — |
| line | text role `listSubtitle`, `color.global.textOnMedia` | the birthday (group-local) in `layout.onthisday.dateFormat` (the memory date, year shown: the card stays) | — |
| pill | C-09 light pill | `birthday.tribute.entry.button` ("Play", Retro `video_editor_play`) | the whole card is one button → this screen, full screen |

States: loading, error, offline and "no video" show no card (an invitation, never a placeholder); the last cards are
cached per viewer so they do not pop in on each visit. VoiceOver / TalkBack: one button, "title, line, Play".
Reduce Motion: the card fades in with the pager's `ComponentMotion.fade` (iOS) / appears without animation (Android).

## Elements

| element | component · tokens | copy keys | behaviour |
|---|---|---|---|
| page | `color.global.backgroundDeep`, `layout.global.appearance` (media) | — | — |
| title / group | `font.global.display`, text role `headerTitle`, `size.global.titleTop`, `size.global.screenMargin`, `color.global.textOnMedia`; text role `textButton`, `color.global.textSecondary`, `dimension.onthisday.subtitleBaseline` | `birthday.tribute.title`, `.title.member` | — |
| close | C-11 on media | `birthday.tribute.a11y.close` | dismiss |
| player | `layout.birthday.tribute.player`, `layout.birthday.tribute.video` | — | signed URL of `video_path` (1 h); plays once on open (Motion) |
| save circle | C-11 on media: `size.global.circleButton`, `color.global.controlOnDeep`, `size.global.buttonMarginH`, `icon.global.download` | `birthday.tribute.download`, `.saved`, `.saveFailed`, `.saveDenied.*` | honoree only; saves the MP4 (add-only photo access) |
| Share pill | `collage.share.layout.pill`, `color.global.surfaceLight`, `color.global.onSurfaceLight`, text role `button` | `birthday.tribute.share` | honoree only; share sheet with the MP4 |
| push (honoree) | — | `notifications.push.tribute.title` / `.body` (owned by `notifications.push`, MERGE L-1) | once at delivery; tap → this screen |
| group-screen card | C. above | `birthday.tribute.title`, `.title.member`, `.entry.button` | honoree and contributors, after delivery; tap → this screen |

## States

| state | design (components) | copy | source |
|---|---|---|---|
| loading | player area: the platform activity indicator (C-28); bar disabled | `birthday.tribute.loading` (announcement) | C-28 |
| re-rendering (`status = 'pending'` after a photo was deleted) | as loading; refetch when `status = 'ready'` | `birthday.tribute.loading` | docs/API.md 6.2 |
| not found (deleted) | C-27 title centred on the black page | `birthday.tribute.notFound.title` | `retro.voice.error` |
| error | C-27 error variant + light pill (C-09) retry | `birthday.tribute.error.title`, `.error.detail`, `.error.retry` | `retro.voice.error` |
| offline | same block | `birthday.tribute.offline.title`, `birthday.tribute.offline`, `.error.retry` | `retro.voice.error` |
| save failed / photo access denied | toast (C-26) / native alert with a Settings button | `birthday.tribute.saveFailed`; `birthday.tribute.saveDenied.*` | `retro.voice.error`, `retro.voice.permission` |
| empty | n/a: no tribute exists without a contribution (`due_tributes`) | — | docs/API.md 10 |

## Motion

Screen: native full-screen presentation (`easing.global.native`). Video motion is rendered (title crossfade 600 ms;
hard cuts). The app does not autoplay when "Auto-play video previews" is off on iOS
(`UIAccessibility.isVideoAutoplayEnabled`) or animations are removed on Android (`layout.global.reduceMotion`): the
poster shows with the play control. VidDay's gift-wrap unwrap is not built.

## Haptics

Close, save, Share → `haptic.global.tap` (Android). Saved → `haptic.global.success`; failed → `haptic.global.error`.

## Accessibility

- Close `birthday.tribute.a11y.close`; save circle `birthday.tribute.download`; player: native controls; Share: visible
  text. Title: header.
- The names and lines are burned into the video; the honoree cannot read `tribute_contributions` (RLS: own rows only)
  — no transcript (Gaps).
- Dynamic Type: title `headerTitle` → largeTitle (wraps to two lines), group `textButton` → body.
- Focus order: title → group → close → player → save → Share (save and Share: honoree only).
- Contrast (`node tools/contrast.mjs`; dark in both appearances):

  | pair | ratio | needs | result |
  |---|---|---|---|
  | title `color.global.textOnMedia` on `color.global.backgroundDeep` | 21.00 | 3 | pass |
  | group `color.global.textSecondary` on `color.global.backgroundDeep` | 7.37 | 4.5 | pass |
  | Share label on `color.global.surfaceLight` | 21.00 | 4.5 | pass |
  | save glyph `color.global.textOnMedia` on `color.global.controlOnDeep` | 15.13 | 3 | pass |
  | `color.global.controlOnDeep` circle vs the page | 1.39 | 3 | **FAIL** (non-text; glyph identifies it — C-11, reported) |
  | video title / end card #FFFFFF on #000000 | 21.00 | 3 | pass |
  | caption white on the band (#00000099) over a white photo (#666666) | 5.74 | 3 / 4.5 | pass |

## Data & actions

- **Read:** `from("tributes").select().eq("id", tributeId).single()` → `video_path`, `poster_path`, `status`,
  `delivered_at`, `group_id`, `honoree_id`; group name from `groups`; honoree first name from `profiles` (contributor
  view). Signed URLs from `g/<group_id>/tributes/<id>/…`. The group screen's cards: `rpc("group_tributes", {p_group_id})`
  (+ the honorees' first names, the posters' signed URLs).
- **Writes:** none. **Worker:** `tribute.render` / `tribute.rerender`, then `push.tribute` (payload `type = tribute`,
  `tribute_id`, `group_id`).
- **Navigation in:** push → `DeepLink.tribute(tributeID:groupID:)` / `app://tribute?tribute=<id>&group=<id>`
  (`ios/Packages/AppCore/Sources/AppModels/DeepLink.swift`, `android/core/model/src/main/kotlin/app/model/DeepLink.kt`);
  the group screen's card (C.). **Out:** close; share sheet.

## Platform notes

- iOS: `VideoPlayer` / `AVPlayerViewController` (system controls); save with `PHPhotoLibrary` +
  `PHAssetCreationRequest` (add-only, `NSPhotoLibraryAddUsageDescription` owned by `system.permissions`); share with
  `ShareLink(item: URL)` of the downloaded file.
- Android: Media3 `PlayerView`; save via `MediaStore.Video` (no permission on API 29+); share `ACTION_SEND`
  `video/mp4` via `FileProvider`.

## Do-not-copy

Tribute / VidDay intro / outro stings, watermarks, logos, theme art (VidDay paper card and hand-lettering, Tribute's
navy badge), music; "From Russell and 36 others" (count); gift money; paid upsells; "Present Now"; public links;
contributor counts.

## Gaps

| item | status | smallest capture that closes it |
|---|---|---|
| title / caption type in the video | Roboto (worker) until the hand-off; Retro's faces are the display serif / Inter | worker change (RM-12) |
| photo hold, end card, caption | SOURCED (VidDay / Tribute gap fill, G2-22…G2-24) | one finished Tribute or VidDay with photos and names (research capture 5) |
| burned-in text not accessible | no transcript | owner / API decision: expose names + lines to the honoree after delivery |
| tribute video aspect | 16:9 landscape, portrait photos pillarboxed | owner decision if a 9:16 video is wanted |
