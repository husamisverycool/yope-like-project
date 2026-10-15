# Verification — `daily.dualimage` (iOS)

Back + front together — `DualImageView`.

Checklist written from the spec (`design/surfaces/daily.dualimage.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>.png`, then `tools/sidebyside.py` makes `design/verification/daily.dualimage.png` next to the reference image(s) below.

Reference image(s): `references/auto/bereal/help/help-21083730354333_feed-bonus-3x.png`, `references/auto/bereal/help/help-21083708285725_bts-post-preview-2x.png`

Snapshots (CI): `daily.dualimage-dual.png`, `daily.dualimage-single-camera.png`, `daily.dualimage-loading.png`

**Summary: 3 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Composition

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `daily.dualimage.layout.composition` | mainAspect: 0.75; mainRadiusRatio: 0.0455; insetWidthRatio: 0.31; insetAspect: 0.75; insetMarginRatio: 0.03; insetBorderRatio: 0.0051; insetOuterRadiusRatio: 0.126 (SOURCED) | main 3:4 r 0.0455W; inset 0.31W 3:4 at 0.03W; border 0.0051W; outer r 0.126 × inset width | GeometryReader ratios; border outside the photo in backgroundDeep |
| matched | `color.global.backgroundDeep` | #000000 (SOURCED) | border / loading frame | fill |
| matched | `daily.dualimage.a11y.label` | “Back and front photos from {name}” (SOURCED) | one label | accessibilityElement + label + image trait |

## Notes

- Images are decoded off the main actor at the frame size before the preview shows.
