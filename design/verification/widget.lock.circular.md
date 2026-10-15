# Verification — `widget.lock.circular` (iOS)

Lock Screen circular — `WidgetCircularSlot`.

Checklist written from the spec (`design/surfaces/widget.lock.circular.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>.png`, then `tools/sidebyside.py` makes `design/verification/widget.lock.circular.png` next to the reference image(s) below.

Reference image(s): `references/auto/locket/help/locket-help-7914857-widget-with-avatar-crop.png`

Snapshots (CI): `widget.lock.circular-photo.png`, `widget.lock.circular-empty.png`

**Summary: 5 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Values

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `widget.lock.circular.layout.size` | w430h932: 76x76; w428h926: 76x76; w414h896: 76x76; w414h736: 76x76; w393h852: 72x72; w390h844: 72x72; w375h812: 72x72; w375h667: 68x68; w360h780: 72x72 (VERIFIED) | 72 × 72 | avatar fills the circle |
| matched | `icon.global.gallery` | ios: photo.on.rectangle; android: Rounded.PhotoLibrary (PLATFORM) | empty glyph | Image |
| matched | `widget.lock.rect.layout.rendering` | mode: vibrant (monochrome, desaturated); content: opaque grayscale at full opacity; white / light gray for the most prominent content; minText: 11; margins: system (smaller on the Lock Screen) (VERIFIED) | vibrant: opaque grayscale, white prominent, min text 11 | system vibrant rendering; content drawn in textPrimary at full opacity |
| matched | `widget.lock.rect.layout.content` | noCaptionRectangular: the sender avatar alone, in its 24-pt leading slot (Locket's small widget without a caption shows only the avatar); noCaptionInline: the sentence of widget.home.small.a11y.photo ('{name}’s photo in {group}') as the inline text (the inline widget has no avatar slot); newestIsCollage: keep showing the newest single photo's sender (avatar, and its caption if any): Locket's widget always shows one sender's newest photo and has no collage state (SOURCED) | no caption: avatar alone (rect) / photo sentence (inline); collage newest: newest single photo's sender | GroupWidgetEntryResolver.lockScreenEntry + WidgetRectangularSlot / WidgetInlineSlot |
| matched | `widget.lock.rect.gallery.description` | “See who shared the newest pic in your group” (SOURCED) | Lock Screen kind description | separate widget kind `GroupPhotoLockWidget` |
