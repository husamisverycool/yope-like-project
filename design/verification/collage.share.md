# Verification — `collage.share` (iOS)

Share pill + system share sheet — `CollageView.sharePill`, `CollageSharePage`.

Checklist written from the spec (`design/surfaces/collage.share.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>.png`, then `tools/sidebyside.py` makes `design/verification/collage.share.png` next to the reference image(s) below.

Reference image(s): `references/auto/yope/store/yope-store-04.png`, `references/auto/yope/frames/b-derot-store-04-rot-3.65.png`

Snapshots (CI): `collage.share-pill.png`

**Summary: 7 matched · 1 approximated · 0 not matched (BLOCKED or not buildable).**

## Values

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `collage.share.layout.pill` | width: 126; height: 58; cornerRadius: 10; bottomFromScreenBottom: 36; glyph: 25.7 (SOURCED) | 126 × 58, r 10, 36 above bottom, glyph 25.7 | frame / padding |
| approximated | `collage.share.color.pill` | #9A9489A8 (SOURCED) | frosted tint #9A9489A8 over a backdrop blur | RoundedRectangle fill; the blur radius was not measured, so the tint is drawn without a blur |
| matched | `collage.share.icon.share` | ios: square.and.arrow.up.fill; android: Rounded.IosShare (PLATFORM) | glyph | Image, hidden from VoiceOver |
| matched | `collage.share.fontSize.label` | 18 pt (SOURCED) | 18 | DSTextStyle (headline) |
| matched | `collage.share.fontWeight.label` | bold (SOURCED) | bold | DSTextStyle |
| matched | `collage.share.button` | “share” (SOURCED) | ‘share’ | label + accessibility label |
| matched | `collage.share.sheetTitle` | “share with friends” (SOURCED) | SharePreview title | ShareLink preview |
| matched | `collage.share.layout.export` | aspect: 9:16; widthPx: 1080; heightPx: 1920; source: collages.share_path page n (worker share-<n>.jpg); watermark: none (VERIFIED) | share-<n>.jpg 1080 × 1920, no watermark | FileRepresentation exported lazily from the current page |

## Notes

- Gap between glyph and label: platform HStack spacing (not measured).
