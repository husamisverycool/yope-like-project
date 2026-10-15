# `birthday.tribute` — the birthday video and the screen it plays on

Reference: **Tribute / VidDay** (docs/SURFACES.md). The video is rendered server-side by the worker
(`backend/worker/src/tribute/render.ts`, ffmpeg + sharp, Roboto) from the tokens below, read **by name**; the app
plays it. Voice: `P-BT-1`; Title Case labels as the references; states use the app default voice. Tokens:
`design/tokens/memory.json` (`*.birthday.tribute.*`). Copy: `design/copy/memory.json` (`birthday.tribute.*`).

Flow: requests close at 00:00 group-local on the birthday (`due_at`); if anyone contributed, the worker renders the
video and, at or after `due_at`, delivers it (`delivered_at`) and sends the honoree one push. The honoree can read it
only after delivery; other members (not blocked with the honoree) can read it at any time.

## References

| image / video | what it verifies |
|---|---|
| https://website.tribute.co/6KY_IZ1tLME.mp4 (Tess, 640 × 360, 30000/1001 fps) and https://website.tribute.co/QQe5RpbFIyI.mp4 (Doug) | 16:9 frame; hard cuts between clips (28 + 22) and into the end slot (94.201 s / 62.400 s); end slot 10.003 / 10.006 s; portrait content pillarboxed on black |
| `references/auto/tribute/frames/tribute-sample-tess-t007.080-first-clip.png` | pillarbox #000000 beside a portrait clip |
| `references/auto/tribute/frames/tribute-sample-tess-clips-7.2-94.0s-every2s.png`, `tribute-sample-doug-clips-7.2-62.2s-every2s.png` | no automatic name captions in either sample |
| https://static.vidday.com/videos/vidday-group-videos-getting-started-2-minute-tour.mp4 → `references/auto/vidday/frames/vidday-tour-t118.300-phone.png`, `-t119.300-phone.png`, `-t120.000-phone.png` | title card "HAPPY BIRTHDAY, AMELIA!" (layout measured this pass), static 117.767-118.933 s, crossfade ≈0.6 s to the first photo |
| `references/auto/vidday/frames/vidday-tour-t115.000-phone.png`, `-t116.500-phone.png`, `-t117.400-phone.png` | gift-wrap unwrap (not built) |
| `references/auto/vidday/store/vidday-store-08.png`, `-09.png` | recipient page: "Download", standard player controls |
| `references/auto/tribute/mockups/tribute-home-phone-step-3-completed-page.png` | finished page: player, share, "Download" |
| `references/auto/tribute/web/tribute-web-testimonials.computed-styles.json` | secondary buttons 360 × 44, r8, 14/600, #292D34 on white, 10 apart |
| https://help.vidday.com/what-features-do-finalized-video-gifts-get/ | "1080p" |

## A. The video (worker contract)

`layout.birthday.tribute.structure`: **title card → one card per contribution → end card**, no audio.

| # | segment | content | timing |
|---|---|---|---|
| 1 | title card | `layout.birthday.tribute.titleCard`: solid `background`, text `birthday.tribute.titleCard` ("Happy birthday, {name}!") in Roboto `fontWeight`, size `fontSizeRatio` × video height, wrapped inside `maxWidthRatio` × video width, centred horizontally, block centre at `centerYRatio` × height | visible `duration.birthday.tribute.titleHold`, then crossfade `duration.birthday.tribute.titleCrossfade` into card 2 |
| 2…n | contribution | the contributor's photo (display rendition), whole photo fitted inside the 16:9 frame on `color.birthday.tribute.pillarbox`; contributor's first name + their line laid out by `layout.birthday.tribute.caption` (**BLOCKED**) | `duration.birthday.tribute.photoHold` (**BLOCKED**) each; `duration.birthday.tribute.clipTransition` (0 = hard cut) between them |
| n+1 | end card | `layout.birthday.tribute.endCard` (**BLOCKED**) with `birthday.tribute.endCard` (**BLOCKED**) | `duration.birthday.tribute.endTransition` (0 = hard cut) in, then `duration.birthday.tribute.endHold` |

Canvas: `layout.birthday.tribute.video` = 1920 × 1080 at 29.97 fps. Contribution order: worker order (`created_at`).

**Token names the worker reads** (`TRIBUTE_TOKEN_NAMES` in `backend/worker/src/tribute/render.ts`):

| name | value | level |
|---|---|---|
| `layout.birthday.tribute.video` | `{ width: 1920, height: 1080, fps: 29.97 }` | SOURCED |
| `duration.birthday.tribute.titleHold` | 1167 ms | SOURCED |
| `duration.birthday.tribute.titleCrossfade` | 600 ms | SOURCED |
| `duration.birthday.tribute.photoHold` | — | **BLOCKED** |
| `duration.birthday.tribute.clipTransition` | 0 ms | SOURCED |
| `duration.birthday.tribute.endTransition` | 0 ms | SOURCED |
| `duration.birthday.tribute.endHold` | 10003 ms | SOURCED |
| `color.birthday.tribute.pillarbox` | `#000000` | SOURCED |
| `layout.birthday.tribute.titleCard` | `{ background: "#EFEEF3", textColor: "#444347", fontWeight: 500, fontSizeRatio: 0.084, maxWidthRatio: 0.405, centerYRatio: 0.5 }` | SOURCED |
| `layout.birthday.tribute.endCard` | — | **BLOCKED** |
| `layout.birthday.tribute.caption` | — | **BLOCKED** |

Copy keys the worker reads: `birthday.tribute.titleCard` (`{name}`, SOURCED) and `birthday.tribute.endCard`
(`{group}`, **BLOCKED**). Because three tokens and one string are BLOCKED, `tributeTokens()` throws
`MissingTokenError` and `tribute.render` jobs retry with backoff until the owner capture lands — no tribute is
rendered with invented values.

## B. The tribute screen (in the app)

Full screen on `color.global.backgroundDeep`, side margin `dimension.birthday.request.margin`:
1. Header: close circle top-left (`size.global.headerButton`, `size.global.headerInset`, `color.global.controlOnDeep`,
   `icon.global.close`).
2. Title `birthday.tribute.title` ("Birthday Video") — `fontSize/fontWeight/lineHeight.birthday.request.title`
   (Tribute page title role), `color.global.textPrimary`; under it the group name (data) in
   `fontSize.birthday.request.message`, `color.global.textSecondary`.
3. `dimension.birthday.request.message.gap` below: the **player** (`layout.birthday.tribute.player`), full content
   width, 16:9, native controls, poster = `poster_path` (the title card). The video has no audio; it starts playing
   once when the screen opens (see Motion for the autoplay setting).
4. `dimension.birthday.request.cta.gap` below: **Download** and **Share**, stacked
   `dimension.birthday.tribute.button.gap` apart, each full width, `dimension.birthday.tribute.button.height`,
   `radius.birthday.tribute.button`, fill `color.global.surfaceLight`, label `fontSize/fontWeight.birthday.tribute.button`
   in `color.birthday.tribute.button.label` with a leading glyph (`icon.global.download`, `icon.global.share`) in the
   same colour.

## Elements

| element | tokens | copy keys | behaviour |
|---|---|---|---|
| close | `size.global.headerButton`, `size.global.headerInset`, `color.global.controlOnDeep`, `icon.global.close` | `birthday.tribute.a11y.close` | dismiss |
| title / group | `fontSize/fontWeight/lineHeight.birthday.request.title`, `fontSize.birthday.request.message`, `color.global.textPrimary`, `color.global.textSecondary`, `font.birthday` | `birthday.tribute.title` | — |
| player | `layout.birthday.tribute.player`, `layout.birthday.tribute.video` (aspect) | — | signed URL of `video_path` (1 h) |
| Download | `dimension.birthday.tribute.button.*`, `radius.birthday.tribute.button`, `fontSize/fontWeight.birthday.tribute.button`, `color.birthday.tribute.button.label`, `color.global.surfaceLight`, `icon.global.download` | `birthday.tribute.download`, toast `birthday.tribute.saved` | saves the MP4 to the photo library (add-only access; purpose string owned by `system.permissions`) |
| Share | same + `icon.global.share` | `birthday.tribute.share` | system share sheet with the MP4 file |
| push (honoree) | — | `birthday.tribute.push.title`, `birthday.tribute.push.body` (`{group}`) | once, at delivery; tap → this screen |

## States

| state | design | copy | source |
|---|---|---|---|
| loading | player area shows the platform activity indicator; buttons disabled | `birthday.tribute.loading` | Yope HUD word |
| re-rendering (`status = 'pending'` after a photo was deleted) | same as loading; refetch when `status = 'ready'` | `birthday.tribute.loading` | docs/API.md 6.2 `delete_media` |
| not found (tribute deleted) | text roles `emptyTitle` / `emptyDetail` centred | `birthday.tribute.notFound.title`, `.detail` | app voice |
| error | same + light pill retry | `birthday.tribute.error.title`, `.detail`, `.retry` | app voice |
| offline | inline under the title, `fontSize.global.listSubtitle`, `color.global.textSecondary` | `birthday.tribute.offline` | app voice |
| save failed / photo access denied | toast | `birthday.tribute.saveFailed` | app voice; settings link per `system.permissions` |
| empty | n/a: no tribute exists without a contribution (`due_tributes`) | — | docs/API.md 10 |

## Motion

Screen: native presentation (`easing.global.native`). Video motion is rendered (title crossfade 600 ms; hard cuts).
VidDay's gift-wrap unwrap (`UNWRAP VIDEO`, ribbons clear in ≈470 ms) is not built (wrap art is VidDay's asset).
Reduce Motion: the video has no camera moves (VidDay's slow zoom is not used); the app does not autoplay when
"Auto-play video previews" is off on iOS (`UIAccessibility.isVideoAutoplayEnabled`) — the poster shows with the play
control.

## Haptics

Download saved → `haptic.global.success`; failed → `haptic.global.error`.

## Accessibility

- Close `birthday.tribute.a11y.close`; player: native controls carry their own labels; buttons: visible text.
- The names and lines are burned into the video and cannot be read by VoiceOver / TalkBack, and the honoree cannot
  read `tribute_contributions` (RLS: own rows only) — reported in Gaps.
- Dynamic Type: title `title2` and group name `callout` (`layout.birthday.request.textStyleMap`); button label 14 pt
  → `subheadline` (nearest Large size, tie with footnote → larger, MERGE F-13).
- Focus order: close → title → group → player → Download → Share.
- Contrast: title white on black 21.00 pass; group `textSecondary` on black 7.10 pass;
  `color.birthday.tribute.button.label` on `color.global.surfaceLight` 13.82 pass; video title card
  `#444347` on `#EFEEF3` 8.50 pass (large text).

## Data & actions

- **Read:** `from("tributes").select().eq("id", tributeId).single()` → `video_path`, `poster_path`, `status`,
  `delivered_at`, `group_id`; group name from `groups`. Signed URLs from `g/<group_id>/tributes/<id>/…`.
- **Writes:** none. **Worker:** `tribute.render` / `tribute.rerender`, then `push.tribute` (payload `type = tribute`,
  `tribute_id`, `group_id`).
- **Navigation in:** push → `DeepLink.tribute(tributeID:groupID:)` / `app://tribute?tribute=<id>&group=<id>`
  (`ios/Packages/AppCore/Sources/AppModels/DeepLink.swift`, `android/core/model/src/main/kotlin/app/model/DeepLink.kt`).
  **Out:** close; share sheet.

## Platform notes

- iOS: `VideoPlayer` / `AVPlayerViewController`; save with `PHPhotoLibrary.shared().performChanges` +
  `PHAssetCreationRequest` (add-only authorization `NSPhotoLibraryAddUsageDescription`). Android: Media3 `PlayerView`;
  save with `MediaStore.Video` insert (no permission on API 29+; `WRITE_EXTERNAL_STORAGE` maxSdk 28).
- Share: `ShareLink(item: URL)` with the downloaded file / Android `ACTION_SEND` `video/mp4` via `FileProvider`.
- The worker's push keys today are `notifications.push.tribute.*`; this surface's texts are `birthday.tribute.push.*`
  (MERGE memory M-22).

## Do-not-copy

Tribute and VidDay intro / outro brand stings, watermarks, logos and theme art; "From Russell and 36 others" (count);
gift money ("Funds were collected…", "Redeem"); paid upsells (custom intro, Video Book, DVD / USB); "Present Now"
(creator-side); "Send a special link" / public links; background music (timings not found); contributor counts.

## Gaps

| item | status | owner capture |
|---|---|---|
| `layout.birthday.tribute.caption` (first name + line over each photo) | BLOCKED | one finished Tribute in which the creator added "text on a clip" (name at the bottom of the frame), or a VidDay with contributor names on photos: its share link or a 10 s screen recording |
| `duration.birthday.tribute.photoHold` | BLOCKED | one finished Tribute or VidDay containing photos: share link, or a 20 s recording playing three photo contributions (research capture 5) |
| `layout.birthday.tribute.endCard`, copy `birthday.tribute.endCard` | BLOCKED | the last 15 s of a finished (non-marketing) VidDay or Tribute (research capture 5) |
| title card `maxWidthRatio` | measured assuming VidDay's 16:9 frame is cropped to fill the square gift-page player | the same finished video at full frame |
| title-card hold | 1167 ms static span; up to 1667 ms if playback starts at the unwrap tap | the same finished video from its first frame |
| burned-in text not accessible | no transcript (honoree cannot read contributions) | owner / API decision: expose names + lines to the honoree after delivery |
| tribute video aspect | 16:9 landscape as both references; portrait photos are pillarboxed | owner decision if a 9:16 video is wanted |
