# Verification — `widget.lock.inline` (iOS, Pass 4 — Retro redesign)

Lock Screen inline — `ios/Widgets/Sources/WidgetSlots.swift` (`WidgetInlineSlot`).

Checklist written from the spec (`design/surfaces/widget.lock.inline.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>-<light|dark>.png` (every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/widget.lock.inline.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/apk/widget_preview_journals.webp`, `references/auto/platform/hig-widgets-ios-dimensions.png`

Snapshots (CI, `ios/build/snapshots/capture/`): `widget.lock.inline-photo-light.png`, `widget.lock.inline-photo-dark.png`, `widget.lock.inline-collage-light.png`, `widget.lock.inline-not-set-up-light.png`

**Summary: 4 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Line

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `widget.lock.rect.layout.rendering` | mode: vibrant (monochrome, desaturated); content: opaque grayscale at full opacity; white / light gray for the most prominent content; minText: 11; margins: system (smaller on the Lock Screen) (VERIFIED) | vibrant, white content, no colour photo | entries skip the rendition (`includesPhoto: false`); avatar full opacity |
| matched | `widget.lock.rect.layout.content` | rectangular: C-16 people row in vibrant rendering: the newest poster's avatar size.global.avatarPicker, then name (text role listTitle) over the group name (text role listSubtitle); circular: the newest poster's avatar filling the circle (C-23); inline: one line '{name} · {group}' (copy widget.lock.inline.text); newestIsCollage: rectangular / inline show the group name alone; circular shows icon.global.camera (SOURCED) | rect: C-16 row; circular: avatar; inline: '{name} · {group}'; collage: group name / camera glyph | slot views |
| matched | `widget.lock.inline.text` | “{name} · {group}” (SOURCED) | "{name} · {group}" | `Copy.widgetLockInlineText` with the first name |
| matched | `widget.home.small.empty.setUp` | “Tap to choose a group” (SOURCED) | state lines; loading: empty line | same keys as the home widget |
