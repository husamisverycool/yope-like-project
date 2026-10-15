# collage.share — share a collage page as a Stories-sized image

Reference: **Yope** share (the frosted "share" pill on a recap collage; the "share with friends" sheet) + the platform
share sheet (third-party buttons are not copied) + Meta's Stories image spec.

## References

| image | what it verifies |
|---|---|
| `references/auto/yope/store/yope-store-04.png` (S2) / `references/auto/yope/frames/b-derot-store-04-rot-3.65.png`, `references/owner/yope-03-recaps-collage.webp` | 'share' pill on a collage |
| `references/auto/yope/frames/b-yopeapp-7591560669967682847-t66.00-share-with-friends.png` | 'share with friends' sheet, 9:16 export preview |
| `references/auto/yope/frames/b-itsaubrey-7521021527354068255-t9.50-exported-wall.png` | exported 9:16 wall (watermark = do-not-copy) |
| `design/collage-options/option-B.jpg` | the pages that are shared |

## Structure

1. **Share pill** on `collage.view`, bottom centre, bottom edge 36 pt above the screen bottom
   (`collage.share.layout.pill`): 126 × 58 pt, corner 10, fill `collage.share.color.pill` (BLOCKED, frosted), glyph
   `collage.share.icon.share` 25.7 pt + label `collage.share.button` (`collage.share.fontSize.label` /
   `.fontWeight.label`), both `color.global.textPrimary`, centred together.
2. Tap → the **system share sheet** (`collage.share.layout.sheet`) with the current page's `share-<n>.jpg`
   (`collage.share.layout.export`: 9:16, 1080 × 1920 px) and the preview title `collage.share.sheetTitle`.

## Elements

| element | tokens | copy | behavior |
|---|---|---|---|
| pill | `collage.share.layout.pill`, `collage.share.color.pill`, `collage.share.icon.share`, `.fontSize.label`, `.fontWeight.label` | `collage.share.button` | hidden until `collages.share_path` is set; tap downloads the page (signed URL) and opens the sheet |
| share sheet | `collage.share.layout.sheet` | `collage.share.sheetTitle` (iOS `SharePreview` title, Android `Intent.EXTRA_TITLE`) | system UI; includes save to library on iOS |
| export | `collage.share.layout.export` | — | the worker's page JPEG as is: no watermark, no text |

## States

| state | behavior |
|---|---|
| share image not ready | pill hidden |
| downloading | the system sheet's own preview loading (iOS `ShareLink` with a lazily exported file); Android: the chooser opens after the download |
| error / offline | the download fails → no sheet opens; the pill stays and the next tap retries (no reference shows a share error; when the page itself cannot load, `collage.view` shows its offline / error state) |
| empty / permission-denied | n/a |

## Motion

System sheet presentation (`easing.global.native.sheet`).

## Haptics

None (system sheet).

## Accessibility

Pill: button, label = its visible text `collage.share.button`; glyph hidden. Dynamic Type: label → headline
(`collage.share.layout.textStyleMap`). Contrast: white on the BLOCKED frosted fill — not computable (backdrop-dependent).

## Data & actions

`collages.share_path` / `share-<n>.jpg` (worker, option B pages are 9:16 at 1080 px). No writes. Out: the system share
sheet; back to `collage.view`.

## Platform notes

iOS `ShareLink(item:preview:)`; Android `Intent.createChooser(ACTION_SEND, image/jpeg, content:// +
FLAG_GRANT_READ_URI_PERMISSION)`. Instagram Stories direct sharing (Meta SDK, App ID) is not built — the system sheet
covers it.

## Do-not-copy

Yope's wordmark watermark; Instagram / Snapchat / WhatsApp brand buttons; the orange gradient sheet.

## Gaps

| item | status | capture |
|---|---|---|
| `collage.share.color.pill` | BLOCKED | one lossless screenshot of Yope's share pill over flat white and flat black |
| `{app_name}` watermark on shared images | owner decision (none built) | owner |
| options A / C share layout | needs a 9:16 layout no reference shows (README) | owner choice |
