# Verification — `widget.home.large` (iOS, Pass 4 — Retro redesign)

Home Screen widget (systemLarge) — the same view as widget.home.small (`ios/Widgets/Sources/WidgetSlots.swift`).

Checklist written from the spec (`design/surfaces/widget.home.large.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>-<light|dark>.png` (every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/widget.home.large.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/apk/widget_preview_journals.webp`, `references/auto/platform/hig-widgets-ios-dimensions.png`

Snapshots (CI, `ios/build/snapshots/capture/`): `widget.home.large-photo-light.png`, `widget.home.large-photo-dark.png`, `widget.home.large-collage-light.png`, `widget.home.large-loading-light.png`, `widget.home.large-empty-light.png`, `widget.home.large-not-set-up-light.png`, `widget.home.large-signed-out-light.png`

**Summary: 12 matched · 1 approximated · 0 not matched (BLOCKED or not buildable).**

## Anatomy (one layout at every size, RC-11)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `widget.home.large.layout.size` | w430h932: 364x382; w428h926: 364x382; w414h896: 360x379; w414h736: 348x357; w393h852: 338x354; w390h844: 338x354; w375h812: 329x345; w375h667: 321x324; w360h780: 329x345; w320h568: 292x311 (VERIFIED) | 338 × 354 | system container; snapshots at the 393 × 852 size |
| matched | `widget.home.small.layout.photo` | fill: aspect-fill, full bleed; ios: containerBackground(for: .widget) with the image; contentMarginsDisabled; android: ImageView centerCrop (SOURCED) | photo / collage page full bleed as the removable container background; content margins disabled | `containerBackground(for: .widget) { WidgetContainerBackground }`, `contentMarginsDisabled()`, `widgetAccentedRenderingMode(.fullColor)` |
| matched | `layout.global.photoScrim` | color: #000000; startAt: 0.55; startOpacity: 0; endOpacity: 0.6; direction: top → bottom (SOURCED) | transparent → black 60 % from 55 % of the height | `WidgetPhotoScrim` |
| matched | `widget.home.small.layout.overlay` | lines: line 1: the poster's first name; line 2: the group name (collage: the group name alone, one line); align: trailing-aligned stack at the bottom-trailing corner; trailingInset: 11; lastBaselineFromBottom: 15; linePitch: 13; colour: color.global.textOnMedia; scrim: layout.global.photoScrim (SOURCED) | trailing stack: first name over group; last baseline 15, pitch 13, trailing 11, truncated at 16 | `WidgetTextStack` (baseline alignment guides; pitch scales with Caption 2) |
| matched | `widget.home.small.fontSize.overlay` | 11 pt (SOURCED) | 11 | `WidgetType.overlay` |
| matched | `widget.home.small.fontWeight.overlay` | regular (SOURCED) | regular | same |
| matched | `color.global.textOnMedia` | #FFFFFF (SOURCED) | white lines | foreground |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| approximated | `widget.home.small.color.stateTint` | #FFFFFFD9 (SOURCED) | camera glyph 24 in a 48 box + line, white 85 %, on backgroundDeep | `WidgetStateColumn`; the 48 box from `size.global.minTouchTarget.android` (the APK's 48-dp Glance box; no capture token holds it) |
| matched | `widget.home.small.empty.noPhotos` | “No photos yet. Tap to add one” (SOURCED) | empty | state line |
| matched | `widget.home.small.empty.setUp` | “Tap to choose a group” (SOURCED) | not set up | state line |
| matched | `widget.home.small.empty.signedOut` | “Log in to see your content” (SOURCED) | signed out (no group list on the device) | state line; detected by the store's group list file |
| matched | `widget.home.small.a11y.photo` | “{name}'s photo in {group}” (SOURCED) | one element, button trait | `WidgetOverlay` label |
| matched | `widget.home.small.a11y.collage` | “Photos from {group}, {date}” (SOURCED) | collage label {group}, {date} | same |
