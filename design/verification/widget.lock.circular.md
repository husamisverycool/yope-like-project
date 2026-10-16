# Verification — `widget.lock.circular` (iOS, Pass 4 — Retro redesign)

Lock Screen circular — `ios/Widgets/Sources/WidgetSlots.swift` (`WidgetCircularSlot`).

Checklist written from the spec (`design/surfaces/widget.lock.circular.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>-<light|dark>.png` (every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/widget.lock.circular.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/store/retro-store-02.png (C-23)`, `references/auto/platform/hig-widgets-ios-dimensions.png`

Snapshots (CI, `ios/build/snapshots/capture/`): `widget.lock.circular-photo-light.png`, `widget.lock.circular-photo-dark.png`, `widget.lock.circular-no-avatar-light.png`, `widget.lock.circular-collage-light.png`, `widget.lock.circular-empty-light.png`

**Summary: 5 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Circle

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `widget.lock.rect.layout.rendering` | mode: vibrant (monochrome, desaturated); content: opaque grayscale at full opacity; white / light gray for the most prominent content; minText: 11; margins: system (smaller on the Lock Screen) (VERIFIED) | vibrant, white content, no colour photo | entries skip the rendition (`includesPhoto: false`); avatar full opacity |
| matched | `widget.lock.rect.layout.content` | rectangular: C-16 people row in vibrant rendering: the newest poster's avatar size.global.avatarPicker, then name (text role listTitle) over the group name (text role listSubtitle); circular: the newest poster's avatar filling the circle (C-23); inline: one line '{name} · {group}' (copy widget.lock.inline.text); newestIsCollage: rectangular / inline show the group name alone; circular shows icon.global.camera (SOURCED) | rect: C-16 row; circular: avatar; inline: '{name} · {group}'; collage: group name / camera glyph | slot views |
| matched | `widget.lock.circular.layout.size` | w430h932: 76x76; w428h926: 76x76; w414h896: 76x76; w414h736: 76x76; w393h852: 72x72; w390h844: 72x72; w375h812: 72x72; w375h667: 68x68; w360h780: 72x72 (VERIFIED) | 72 × 72 | fills the family's size |
| matched | `icon.global.person` | ios: person.fill; android: Rounded.Person (PLATFORM) | no avatar photo | glyph 24 |
| matched | `icon.global.camera` | ios: camera; android: Outlined.PhotoCamera (PLATFORM) | collage / states | glyph 24, white |
