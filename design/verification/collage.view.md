# Verification — `collage.view` (iOS, Pass 4 — Retro redesign)

Same-moment collage in Retro's recap preview — `ios/App/Sources/Features/Capture/Collage/CollageView.swift`, the shared `ios/App/Sources/Features/Capture/Collage/RecapPreviewScreen.swift`, `CollageModel.swift`.

Checklist written from the spec (`design/surfaces/collage.view.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>-<light|dark>.png` (every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/collage.view.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/store/retro-store-04.png (ST-04)`, `references/auto/retro/press/tc-2023-12-recaps.png phones 2–3 (TC-REC)`, `references/auto/retro/press/tc-2023-12-retro-header.png (TC-H)`, `design/collage-options/option-B.jpg`

Snapshots (CI, `ios/build/snapshots/capture/`): `collage.view-ready-light.png`, `collage.view-ready-dark.png`, `collage.view-loading-light.png`, `collage.view-ready-one-page-light.png`, `collage.view-empty-light.png`, `collage.view-error-light.png`, `collage.view-offline-light.png`

**Summary: 14 matched · 2 approximated · 0 not matched (BLOCKED or not buildable).**

## Screen (`collage.view.layout.screen`)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `color.global.backgroundDeep` | #000000 (SOURCED) | black, both appearances | RecapPreviewScreen page + dark subtree |
| matched | `collage.view.layout.screen` | mediaPage: the page-1 image blurred full-bleed inside a rounded media page (layout.global.materials.backdrop); mediaPageTop: safe-area top; mediaPageSideInset: 0; mediaPageBottomFromScreenBottom: 94.8; mediaPageCornerRadius: 26.5; closeCentreFromTrailing: 37.7; closeCentreBelowPageTop: 38; card: the composed page, aspect-fit and centred in the media page inset by 76 pt top and bottom (close-circle centre 38 + size.global.circleButton ÷ 2 + the 20-pt circle → photo gap of camera.sendto.layout.preview) and at least 32 pt at the sides; clipped to collage.view.layout.page.outerRadiusRatio × its width (393 × 852: 307 × 546 pt); bottomRowCentreFromScreenBottom: 59.2; bottomRow: 'Share' pill (collage.share.layout.pill) at size.global.buttonMarginH from the trailing edge; page dots (C-31) centred, dimension.year.story.dots.offset below the media page (ST-04; MERGE_DECISIONS RC-19) (SOURCED) | media page full width, safe-area top → 94.8 above the bottom, corners 26.5; close centre 37.7 / 38; bottom row centre 59.2 above the bottom | `RecapPreviewGeometry` (frame, closeCentreInFrame, bottomRowCentreY); `DSShape.rounded(26.5)` |
| matched | `layout.global.materials` | glass: only over photos or colour (color.global.glass); backdrop: full-screen blurred, colour-rich version of the photo behind a card (recap preview, paywall); native: menus, share sheet, sheets: system materials (SOURCED) | page 1 blurred full bleed | C-34 `BlurredBackdrop` (σ `size.global.backdropBlur` under `color.global.backdropDim`, L-5) |
| approximated | `collage.view.layout.page` | columns: 3; rowsPerPage: 4; gapRatio: 0; outerRadiusRatio: 0.0498; canvasAspect: 0.5625; canvasWidthPx: 1080 (SOURCED) | card = page aspect-fit inset 76 top/bottom (≥ 32 sides), corners 0.0498 × width | `RecapPreviewMetrics.cardSize` (76 = 38 + 18 + 20 from tokens); clip `outerRadiusRatio × width`; the ≥ 32 side minimum (prose only) never binds on a portrait iPhone |
| approximated | `size.global.circleButton` | 36 pt (SOURCED) | close 36 #262626, glyph ≈ 9.7 (no token) | `RecapPreviewClose` (glyph box `size.global.iconSmall`) |
| matched | `collage.view.a11y.close` | “Close” (SOURCED) | close label | CircleButton label |

## Pages and dots

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `size.global.pageDot` | 5.9 pt (SOURCED) | dots 5.9 / pitch 9.6 (global tokens; ST-04 5.0 / 10.0 — RC-15) | C-31 `PageDots(onMedia: true)` |
| matched | `dimension.year.story.dots.offset` | 16.1 pt (SOURCED) | dots centred 16.1 below the media page (RC-19) | `RecapPreviewDots(placement: .belowPage)` |
| matched | `color.global.pageDotInactive` | light: #DDDDDD; dark: #808080 (SOURCED) | inactive #808080 (dark value) | dark subtree |
| matched | `collage.view.a11y.page` | “{page} of {pages}” (SOURCED) | "2 of 3" value | PageDots accessibilityValue; adjustable + tap halves change the page |
| matched | `collage.view.a11y.collage` | “Photos from {group}, {date}” (SOURCED) | each page one image element | card label |
| matched | `duration.global.fade` | 150 ms (SOURCED) | card appears when loaded | `.dsTransition(.opacity)` |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `collage.view.loading` | “Creating your collage…” (SOURCED) | page #262626; indicator → 26 → emptyTitle line; no dots, no Share | `CaptureMediaProgress` on controlOnDeep |
| matched | `collage.view.empty.title` | “Nothing to see here yet” (SOURCED) | C-27 on media → camera with the group | `EmptyStateView(icon: camera)` + outline capsule |
| matched | `collage.view.error.title` | “Error loading collage. Tap here to try again.” (SOURCED) | one tappable body line, textOnMedia; tap refetches | full-page plain button |
| matched | `collage.view.offline.title` | “No connection. Tap here to try again.” (SOURCED) | cached pages if present, else the error layout | model keeps cached pages; offline line |

## Notes

- Presented as a full-screen cover through `CaptureModal.collageShare` (light status bar); social's walls push `CaptureRoute.collage`, which draws the same screen without the cover's status-bar preference (report: present it modally).
