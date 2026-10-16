# daily.dualimage — how the back and front photos of one answer are shown together

**Mechanics: BeReal** dual image (≥ 2 independent lossless sources agree on every ratio) — kept unchanged because the
worker composes collage tiles with it (`backend/worker/COPY_KEYS.md` "Collage and media"). **Visual reference:
Retro** photo treatment (`design/research/retro-visual.md` §3.8): the component takes its **outer shape from the Retro
container that hosts it** (daily-capture viewfinder, viewer, card, recap-preview card), and its only colour is Retro's
media black. Used by `daily.capture` (preview), by any post with a front photo (`photo.viewer`, `chat.thread` place the
component) and inside each collage tile (`collage.view`). Decisions: `design/MERGE_DECISIONS.md` RC-13.

## References

| image | what it verifies |
|---|---|
| `references/auto/bereal/help/help-21083730354333_feed-bonus-3x.png` (H3, lossless 3x) | inset size, margin, border, corners |
| `references/auto/bereal/help/help-21083708285725_bts-post-preview-2x.png` (H2) / `help-21083730407325_bts-gif-frame48.png` | 3:4 main image, inset ratio, 2-pt border |
| `references/auto/bereal/frames/appstore-preview-2026_t6.80s_feed.png`, `…_t7.30s_feed.png` | ratios hold at other sizes (2026) |
| `references/auto/retro/store/retro-store-01.png`, `references/auto/retro/press/tc-2023-07-retro-2b.jpg` phone 2 | Retro hosts: friend card corners 18; viewer photo full width, corners 0 |

## Structure

All values are ratios of the **main image width W** (`daily.dualimage.layout.composition`):

1. **Main image** — the back photo (or the photo from the camera that was live), 3:4 portrait, aspect-fill. Outer
   corners = the host's: `radius.global.viewfinder` (18) in `daily.capture`, `radius.global.photo` (0) in the viewer
   (full width, Retro C-22), `radius.global.card` (18) on cards; the token's `mainRadiusRatio` (0.0455 × W, ≈ 18 pt at
   393) applies only where the host draws no shape of its own (the worker ignores it — tiles touch).
2. **Inset** — the front photo, outer width 0.31 × W, 3:4, top-leading with an equal margin of 0.03 × W on both axes;
   a solid border of 0.0051 × W drawn outside the photo in `color.global.backgroundDeep`; outer corner radius 0.126 ×
   the inset's outer width, inner = outer − border.
3. Background around the component: the host's (`color.global.backgroundDeep` on media surfaces).

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| main image | `daily.dualimage.layout.composition` (mainAspect), host corner token | — | `media.display_path` (or `original_path` until renditions exist) |
| inset | `daily.dualimage.layout.composition` (inset*), `color.global.backgroundDeep` | — | `media.front_display_path` / `front_original_path`; absent without a front photo |
| whole component | — | a11y `daily.dualimage.a11y.label` ({name} = poster's first name) | no tap-to-swap or drag (not found in any BeReal source) |

## States

| state | design |
|---|---|
| loading | the 3:4 frame filled `color.global.control` (Retro placeholder tile, C-17 / C-28) on page hosts; `color.global.backgroundDeep` on media hosts; images fade in with `duration.global.fade` |
| single camera | main image only |
| error / offline | frame stays as loading; the host shows its own error state |
| empty / permission-denied | n/a |

## Motion

Image appearance: `duration.global.fade` (150) with `easing.global.standard` (Retro's house fade). No swap or drag.
Reduce Motion: unchanged (fade).

## Haptics

None.

## Accessibility

One element, label `daily.dualimage.a11y.label`; image trait. Contrast: the black border separates two photos (no
text, decorative). Placeholder `color.global.control` vs page 1.07–1.39:1 (decorative placeholder, CONTRAST failure 2).

## Data & actions

`media` row: `original_path` / `display_path` (main), `front_original_path` / `front_display_path` (inset),
`front_width` / `front_height`. No writes.

## Platform notes

Identical on iOS and Android (ratios). The worker reads `daily.dualimage.layout.composition` by name (unchanged).

## Do-not-copy

BeReal post-header 'late' labels ('5 min late'), '2 retakes', RealMoji / comment counts, the watermark inside the image.

## Gaps

| item | status | capture |
|---|---|---|
| tap-to-swap / drag the inset | not found → not built | 2–3-min BeReal recording incl. tapping and dragging the inset |
