# Verification — `widget.home.xl` (iOS)

Home Screen widget — `ios/Widgets/Sources/WidgetSlots.swift`, `GroupPhotoWidget.swift`, `GroupWidgetEntry.swift`.

Checklist written from the spec (`design/surfaces/widget.home.xl.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>.png`, then `tools/sidebyside.py` makes `design/verification/widget.home.xl.png` next to the reference image(s) below.

Reference image(s): `references/auto/locket/store/locket-store-03.png`, `references/auto/locket/store/locket-store-06.png`, `references/auto/locket/frames/locket-tt-7168613044728155438-15.133s-widget-placeholder-just-added.jpg`

Snapshots (CI): `widget.home.xl-photo.png`, `widget.home.xl-photo-caption.png`, `widget.home.xl-collage.png`, `widget.home.xl-loading.png`, `widget.home.xl-empty.png`, `widget.home.xl-not-set-up.png`

**Summary: 27 matched · 0 approximated · 2 not matched (BLOCKED or not buildable).**

## Values

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `widget.home.xl.layout.size` | ipad1024x1366: 748x356; ipad834x1194: 628x300; ipad820x1180: 628x300; ipad768x1024: 540x260; ipad744x1133: 540x260 (VERIFIED) | family size | supportedFamilies; snapshots at the 393 × 852 (xl: 13" iPad) size |
| matched | `widget.home.small.layout.photo` | fill: aspect-fill, full bleed; ios: containerBackground(for: .widget) with the image; contentMarginsDisabled; android: ImageView centerCrop (SOURCED) | photo aspect-fill as removable container background | containerBackground(for: .widget) { WidgetPhotoImage }, contentMarginsDisabled |
| matched | `widget.home.small.size.avatar` | 24 pt (SOURCED) | avatar 24 | WidgetAvatar |
| matched | `widget.home.small.size.avatarInset` | 6 pt (SOURCED) | 6 pt from edges | padding |
| matched | `widget.home.small.size.avatarRing` | 1 pt (SOURCED) | 1-pt ring | strokeBorder |
| matched | `widget.home.small.color.avatarRing` | #0000001A (SOURCED) | ring colour | strokeBorder colour |
| matched | `widget.android.color.avatarPlaceholderTop` | #A0A0A0F5 (SOURCED) | no-avatar gradient top | LinearGradient |
| matched | `widget.android.color.avatarPlaceholderBottom` | #828282F5 (SOURCED) | no-avatar gradient bottom | LinearGradient |
| matched | `widget.home.small.size.captionGap` | 5 pt (SOURCED) | pill 5 after avatar | HStack spacing |
| matched | `widget.home.small.size.captionHeight` | 23 pt (SOURCED) | pill height 23 | minHeight (grows with Dynamic Type) |
| matched | `widget.home.small.size.captionPadding` | 7 pt (SOURCED) | padding 7 | padding(.horizontal) |
| matched | `widget.home.small.color.captionPill` | #333333CC (SOURCED) | #333333CC | Capsule fill |
| matched | `widget.home.small.fontSize.caption` | 12 pt (SOURCED) | 12 pt | DSTextStyle (caption) |
| matched | `widget.home.small.fontWeight.caption` | semibold (SOURCED) | semibold | DSTextStyle |
| matched | `widget.home.small.color.placeholderTop` | #2D2B2F (SOURCED) | loading gradient | LinearGradient |
| matched | `widget.home.small.color.placeholderBottom` | #201E21 (SOURCED) | loading gradient | LinearGradient |
| not matched | `widget.home.small.layout.placeholderAvatars` | diameter: 25; gap: 2.5; max: 3; inset: 6 (SOURCED) | up to 3 member avatars on the placeholder | not drawn: the App Group store holds no member avatars before the first rendition |
| matched | `widget.home.small.color.emptyTop` | #2E2E2E (SOURCED) | empty gradient | LinearGradient |
| matched | `widget.home.small.color.emptyBottom` | #1B1B1B (SOURCED) | empty gradient | LinearGradient |
| matched | `widget.home.small.layout.empty` | circle: 72; ring: 82; ringStroke: 3; glyphWidth: 32; glyphHeight: 28; label: 19; labelGap: 9 (SOURCED) | md: circle 72, ring 82 / 3, glyph 32 × 28, label 19, gap 9 | WidgetEmptyStack |
| matched | `widget.home.small.color.emptyCircle` | #FFFFFF3D (SOURCED) | circle fill | Circle fill |
| matched | `widget.home.small.color.emptyRing` | #FFB800 (SOURCED) | #FFB800 ring | strokeBorder |
| not matched | `widget.home.small.color.emptyLabel` | None (BLOCKED) | label colour (BLOCKED) | label not drawn until unblocked (WidgetBlocked.emptyLabelColor); text is the accessibility label |
| matched | `widget.home.small.empty.noPhotos` | “No pics yet” (SOURCED) | empty text | accessibility label (visible once the colour is unblocked) |
| matched | `widget.home.small.empty.setUp` | “Tap to set up” (SOURCED) | not-set-up text | same |
| matched | `widget.home.small.a11y.photoWithCaption` | “{name}’s photo in {group}, {caption}” (SOURCED) | label | one element, button trait |
| matched | `widget.home.small.a11y.photo` | “{name}’s photo in {group}” (SOURCED) | label | same |
| matched | `widget.home.small.a11y.collage` | “Photos from {group}, {date}” (SOURCED) | label ({date} medium date) | postedAt .abbreviated |
| matched | `widget.arrival.duration.transition` | 0 ms (SOURCED) | 0 ms swap | .transition(.identity), .contentTransition(.identity) |

## Notes

- Same widget kind for small / medium / large / extra large (one gallery description); Locket's anatomy at every size (C-20).
- Error / offline: the last rendition stays (the provider reads the App Group store only; never the network).
- The lg empty variant (circle 98, ring 110, glyph 43 × 36, label 21, gap 24) exists only in the notes of `widget.home.small.layout.empty`; no token → the md variant is drawn (not matched to the lg reference).
- Spec asks for `media.display_path` at extra large; the App Group store keeps one rendition per snapshot (the widget rendition), so it is upscaled (foundation `WidgetStore` / NSE delivery would need a second file).
