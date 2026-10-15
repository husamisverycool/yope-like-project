# daily.dualimage — how the back and front photos of one answer are shown together

Reference: **BeReal** dual image (≥ 2 independent lossless sources agree on every ratio). Used by the daily-capture
preview, by any post that has a front photo (chat thread, photo viewer — those surfaces place this component), and as
the tile of the same-moment collage (composed by the worker, `collage.view`).

## References

| image | what it verifies |
|---|---|
| `references/auto/bereal/help/help-21083730354333_feed-bonus-3x.png` (H3, lossless 3x) | inset size, margin, border, corners |
| `references/auto/bereal/help/help-21083708285725_bts-post-preview-2x.png` (H2) / `help-21083730407325_bts-gif-frame48.png` (HG) | 3:4 main image, inset ratio, border 2 pt |
| `references/auto/bereal/frames/appstore-preview-2026_t6.80s_feed.png`, `…_t7.30s_feed.png` (AP #205, #220) | ratios hold when the image shrinks (2026) |
| `references/auto/bereal/store/bereal-store-03.png`, `references/owner/bereal-02-dualcam-preview.webp` | composition (ratios only) |

## Structure

All values are ratios of the **main image width W** (`daily.dualimage.layout.composition`), so the component scales:

1. **Main image** — the back photo (or the photo taken with the camera that was live), 3:4 portrait, corner radius
   0.0455 × W (≈ 18 pt at 393 pt), aspect-fill.
2. **Inset** — the front photo, outer width 0.31 × W, 3:4, at the top-leading corner with an equal margin of
   0.03 × W on both axes; a solid border of 0.0051 × W (2 pt at 393 pt) drawn outside the photo in
   `color.global.backgroundDeep`; outer corner radius 0.126 × the inset's outer width, inner (photo) radius = outer − border.
3. Background around the component: `color.global.backgroundDeep`.

## Elements

| element | tokens | copy | behavior |
|---|---|---|---|
| main image | `daily.dualimage.layout.composition` (mainAspect, mainRadiusRatio) | — | `media.display_path` (or `original_path` until renditions exist) |
| inset | `daily.dualimage.layout.composition` (inset*), `color.global.backgroundDeep` | — | `media.front_display_path` / `front_original_path`; absent when the answer has no front photo (single camera) |
| whole component | — | a11y `daily.dualimage.a11y.label` ({name} = poster's first name) | no tap-to-swap or drag (not found in any BeReal source) |

## States

| state | design |
|---|---|
| loading | the 3:4 frame filled `color.global.backgroundDeep` until the images load (no placeholder observed) |
| single camera | main image only (no inset) |
| error / offline | frame stays black; the host surface shows its own error state |
| empty / permission-denied | n/a |

## Motion

None (no swap or drag in the reference).

## Haptics

None.

## Accessibility

One element, label `daily.dualimage.a11y.label`; image trait. Contrast: the black border is a separator between two
photos (no text).

## Data & actions

`media` row: `original_path` / `display_path` (main), `front_original_path` / `front_display_path` (inset),
`front_width` / `front_height`. No writes.

## Platform notes

Identical on iOS and Android (ratios). The worker uses the same ratios through the proposal token
`layout.collage.dualTile` (C-21: canonical name here is `daily.dualimage.layout.composition`, same values).

## Do-not-copy

Post-header 'late' labels ('5 min late', '9m late', '27 h late'); '2 retakes' chip; RealMoji / comment counts; the
BeReal watermark inside the image.

## Gaps

| item | status | capture |
|---|---|---|
| tap-to-swap / drag the inset | not found → not built | 2–3-min BeReal recording incl. tapping and dragging the inset |
