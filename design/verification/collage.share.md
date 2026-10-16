# Verification — `collage.share` (iOS, Pass 4 — Retro redesign)

Share pill and system share sheet — `ios/App/Sources/Features/Capture/Collage/CollageView.swift` (`sharePill`), `RecapPreviewScreen.swift` (`RecapPillLabel`), `CollageModel.swift` (`CollageSharePage`).

Checklist written from the spec (`design/surfaces/collage.share.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>-<light|dark>.png` (every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/collage.share.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/store/retro-store-04.png (ST-04)`, `references/auto/retro/press/tc-2025-12-rewind-panels.png phone 3`

Snapshots (CI, `ios/build/snapshots/capture/`): `collage.share-pill-light.png`, `collage.share-pill-dark.png`, `collage.share-not-ready-light.png`

**Summary: 8 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Pill

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `collage.share.layout.pill` | height: 43.5; paddingHorizontal: 23; trailingInset: size.global.buttonMarginH; centreFromScreenBottom: 59.2 (SOURCED) | height 43.5, padding 23, trailing 20, centre 59.2 above the bottom | `RecapPillLabel` (minHeight, horizontal padding) in the bottom row's trailing slot |
| matched | `color.global.surfaceLight` | #FFFFFF (SOURCED) | white fill | background Capsule |
| matched | `color.global.onSurfaceLight` | #000000 (SOURCED) | black label | foreground |
| matched | `fontSize.global.button` | 17 pt (SOURCED) | 17 semibold label | `TextRole.button` |
| matched | `collage.share.button` | “Share” (SOURCED) | "Share" | label |

## Share

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `collage.share.layout.sheet` | ios: ShareLink(item:preview: SharePreview(title, image)); android: Intent.createChooser(ACTION_SEND image/jpeg content:// + FLAG_GRANT_READ_URI_PERMISSION, title) (PLATFORM) | ShareLink(item:preview:) with a lazily exported file | `ShareLink(item: CollageSharePage, preview: SharePreview(sheetTitle, image:))` |
| matched | `collage.share.sheetTitle` | “{date}” (SOURCED) | {date} (locale long date) | `CaptureFormat.collageDate` |
| matched | `collage.share.layout.export` | aspect: 9:16; widthPx: 1080; heightPx: 1920; source: collages.share_path page n (worker share-<n>.jpg); watermark: none (VERIFIED) | the worker's 1080 × 1920 page, no watermark | `share-<n>.jpg` of the current page |

## Notes

- Busy and error states: with ShareLink's lazy export (the spec's iOS platform note) the system shows the export progress; no app-drawn busy state or error announcement.
- The pill is hidden until `collages.share_path` exists (`not-ready`).
