# Verification — `widget.lock.rect` (iOS, Pass 4 — Retro redesign)

Lock Screen rectangular — `ios/Widgets/Sources/WidgetSlots.swift` (`WidgetRectangularSlot`).

Checklist written from the spec (`design/surfaces/widget.lock.rect.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>-<light|dark>.png` (every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/widget.lock.rect.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/apk/widget_preview_journals.webp`, `references/auto/retro/press/tc-2023-07-retro-1b.webp (C-16)`, `references/auto/platform/hig-widgets-ios-dimensions.png`

Snapshots (CI, `ios/build/snapshots/capture/`): `widget.lock.rect-photo-light.png`, `widget.lock.rect-photo-dark.png`, `widget.lock.rect-no-avatar-light.png`, `widget.lock.rect-collage-light.png`, `widget.lock.rect-empty-light.png`, `widget.lock.rect-not-set-up-light.png`, `widget.lock.rect-signed-out-light.png`, `widget.lock.rect-loading-light.png`

**Summary: 8 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Row

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `widget.lock.rect.layout.rendering` | mode: vibrant (monochrome, desaturated); content: opaque grayscale at full opacity; white / light gray for the most prominent content; minText: 11; margins: system (smaller on the Lock Screen) (VERIFIED) | vibrant, white content, no colour photo | entries skip the rendition (`includesPhoto: false`); avatar full opacity |
| matched | `widget.lock.rect.layout.content` | rectangular: C-16 people row in vibrant rendering: the newest poster's avatar size.global.avatarPicker, then name (text role listTitle) over the group name (text role listSubtitle); circular: the newest poster's avatar filling the circle (C-23); inline: one line '{name} · {group}' (copy widget.lock.inline.text); newestIsCollage: rectangular / inline show the group name alone; circular shows icon.global.camera (SOURCED) | rect: C-16 row; circular: avatar; inline: '{name} · {group}'; collage: group name / camera glyph | slot views |
| matched | `size.global.avatarPicker` | 37 pt (SOURCED) | avatar 37; no photo → person glyph | `WidgetLockAvatar` |
| matched | `size.global.cardNameGap` | 11 pt (SOURCED) | 11 after the avatar | HStack spacing |
| matched | `fontSize.global.listTitle` | 15 pt (SOURCED) | name 15 semibold | `WidgetType.listTitle` |
| matched | `fontSize.global.listSubtitle` | 15 pt (SOURCED) | group 15 regular | `WidgetType.listSubtitle` |
| matched | `widget.lock.rect.gallery.name` | “Group Updates” (SOURCED) | "Group Updates" | `.configurationDisplayName` |
| matched | `widget.lock.rect.gallery.description` | “See who shared the newest photo in your group” (SOURCED) | description | `.description` |
