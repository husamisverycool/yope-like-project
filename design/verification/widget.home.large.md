# Verification — `widget.home.large` (iOS)

Home Screen widget — `ios/Widgets/Sources/WidgetSlots.swift`, `GroupPhotoWidget.swift`, `GroupWidgetEntry.swift`.

Checklist written from the spec (`design/surfaces/widget.home.large.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>.png`, then `tools/sidebyside.py` makes `design/verification/widget.home.large.png` next to the reference image(s) below.

Reference image(s): `references/auto/locket/store/locket-store-03.png`, `references/auto/locket/store/locket-store-06.png`, `references/auto/locket/frames/locket-tt-7168613044728155438-15.133s-widget-placeholder-just-added.jpg`

Snapshots (CI): `widget.home.large-photo.png`, `widget.home.large-photo-caption.png`, `widget.home.large-collage.png`, `widget.home.large-loading.png`, `widget.home.large-empty.png`, `widget.home.large-not-set-up.png`

**Summary: 28 matched · 0 approximated · 1 not matched (BLOCKED or not buildable).**

## Values

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `widget.home.large.layout.size` | w430h932: 364x382; w428h926: 364x382; w414h896: 360x379; w414h736: 348x357; w393h852: 338x354; w390h844: 338x354; w375h812: 329x345; w375h667: 321x324; w360h780: 329x345; w320h568: 292x311 (VERIFIED) | family size | supportedFamilies; snapshots at the 393 × 852 (xl: 13" iPad) size |
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
| matched | `widget.home.small.color.emptyLabel` | #969696 (SOURCED) | label #969696 | label 9 pt under the stack at 19 pt (weight not measured: platform regular) |
| matched | `widget.home.small.empty.noPhotos` | “No pics yet” (SOURCED) | empty text | visible label + accessibility label |
| matched | `widget.home.small.empty.setUp` | “Tap to set up” (SOURCED) | not-set-up text | same |
| matched | `widget.home.small.a11y.photoWithCaption` | “{name}’s photo in {group}, {caption}” (SOURCED) | label | one element, button trait |
| matched | `widget.home.small.a11y.photo` | “{name}’s photo in {group}” (SOURCED) | label | same |
| matched | `widget.home.small.a11y.collage` | “Photos from {group}, {date}” (SOURCED) | label ({date} medium date) | postedAt .abbreviated |
| matched | `widget.arrival.duration.transition` | 0 ms (SOURCED) | 0 ms swap | .transition(.identity), .contentTransition(.identity) |

## Notes

- Same widget kind for small / medium / large / extra large (one gallery description); Locket's anatomy at every size (C-20).
- Error / offline: the last rendition stays (the provider reads the App Group store only; never the network).
- The lg empty variant (circle 98, ring 110, glyph 43 × 36, label 21, gap 24) exists only in the notes of `widget.home.small.layout.empty`; no token → the md variant is drawn (not matched to the lg reference).
