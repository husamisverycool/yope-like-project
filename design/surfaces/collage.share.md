# collage.share — share a collage page as a Stories-sized image

**Visual reference: Retro's recap preview "Share" pill** (ST-04 2026: white capsule, black 17-pt semibold label, at
the bottom-trailing of the recap preview) and Retro's use of the **system share sheet** (TC-RWP phone 3: share sheet
titled with the date). **Mechanics:** the worker's 9:16 share image (Meta Stories spec) handed to the platform share
sheet. Decisions: `design/MERGE_DECISIONS.md` RC-15.

## References

| image | what it verifies |
|---|---|
| `references/auto/retro/store/retro-store-04.png` (ST-04) | Share pill size, padding, label role, position (`collage.share.layout.pill`) |
| `references/auto/retro/press/tc-2023-12-recaps.png` phones 2–3 | the same pill in 2023 (85 × 42) on black |
| `references/auto/retro/press/tc-2025-12-rewind-panels.png` phone 3 | Retro hands sharing to the system share sheet, titled with the date ("Tuesday, December 2") |
| `design/collage-options/option-B.jpg` | the pages that are shared |

## Structure

1. **Share pill** on `collage.view` (bottom row): C-09 light pill — height 43.5, horizontal padding 23, width hugs the
   label (`collage.share.layout.pill`), `radius.global.capsule`, fill `color.global.surfaceLight`, label
   `collage.share.button` text role `button` (17 semibold) `color.global.onSurfaceLight`, no glyph; trailing edge at
   `size.global.buttonMarginH` (20), centre 59.2 pt above the screen bottom.
2. Tap → the **system share sheet** (`collage.share.layout.sheet`) with the current page's `share-<n>.jpg`
   (`collage.share.layout.export`: 9:16, 1080 × 1920 px) and the preview title `collage.share.sheetTitle` ({date}).
3. **Every member can share a page** (owner decision 12): a collage page is a group piece made for sharing — the
   moment as the whole group answered it, as Retro's recap preview shares a recap — so the rule "a photo leaves the app
   only when it is the viewer's own" covers single photos and memories, not the pages.

## Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| pill | C-09 light · `collage.share.layout.pill`, `color.global.surfaceLight` / `.onSurfaceLight`, text role `button` | `collage.share.button` | hidden until `collages.share_path` is set; tap downloads the page (signed URL) and opens the sheet; busy: the label is replaced by the platform indicator in `color.global.onSurfaceLight` (C-05 busy rule) |
| share sheet | native · `collage.share.layout.sheet` | `collage.share.sheetTitle` (iOS `SharePreview` title, Android `Intent.EXTRA_TITLE`) | system UI (includes save to Photos on iOS) |
| export | `collage.share.layout.export` | — | the worker's page JPEG as is: no watermark, no text |

## States

| state | behaviour |
|---|---|
| share image not ready | pill hidden |
| downloading | pill busy; then the sheet opens |
| error / offline | no sheet; Android toast / iOS announcement `camera.sendto.error.offline` (offline) or `camera.sendto.error.generic`; the pill stays and the next tap retries |
| empty / permission-denied | n/a |

## Motion

System sheet presentation (`easing.global.native.sheet`). Pill label ↔ busy: `duration.global.crossfade`.

## Haptics

Pill press: `haptic.global.tap` (Android VIRTUAL_KEY; iOS none). Sheet: system.

## Accessibility

Pill: button, label = its visible text. Dynamic Type: `button` → headline (fixed pill height grows with the text
size; the label never truncates). Contrast: `onSurfaceLight` on `surfaceLight` 21.00:1 pass; pill vs black page 21.00:1
pass (non-text) — both appearances.

## Data & actions

`collages.share_path` / `share-<n>.jpg`. No writes. Out: the system share sheet; back to `collage.view`.

## Platform notes

iOS `ShareLink(item:preview:)` with a lazily exported file; Android `Intent.createChooser(ACTION_SEND, image/jpeg,
content:// + FLAG_GRANT_READ_URI_PERMISSION)`. No third-party share buttons (Retro's share targets row — Instagram,
Snapchat, … — is a third-party list; the system sheet covers them).

## Do-not-copy

Retro: "Check out my … on Retro!" message, share-target brand buttons, "retro.app" footer, wordmark. Yope: frosted
"share" pill with glyph, watermark, orange gradient sheet.

## Gaps

| item | status | capture / decision |
|---|---|---|
| `{app_name}` mark on shared images (Retro's footer carries its domain) | owner decision (none built) | owner |
| options A / C share layout | owner choice | owner |
