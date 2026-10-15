# Verification — `widget.lock.inline` (iOS)

Lock Screen inline — `WidgetInlineSlot`.

Checklist written from the spec (`design/surfaces/widget.lock.inline.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>.png`, then `tools/sidebyside.py` makes `design/verification/widget.lock.inline.png` next to the reference image(s) below.

Reference image(s): `references/auto/locket/store/locket-store-03.png`

Snapshots (CI): `widget.lock.inline-photo-caption.png`, `widget.lock.inline-not-set-up.png`

**Summary: 6 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Values

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `widget.lock.inline.layout.size` | w430h932: 257x26; w428h926: 257x26; w414h896: 248x26; w414h736: 248x26; w393h852: 234x26; w390h844: 234x26; w375h812: 225x26; w375h667: 225x26; w360h780: 225x26 (VERIFIED) | 234 × 26, system text style | Text only (system styles it) |
| matched | `widget.home.small.empty.setUp` | “Tap to set up” (SOURCED) | not set up | Text |
| matched | `widget.home.small.empty.noPhotos` | “No pics yet” (SOURCED) | empty | Text |
| matched | `widget.lock.rect.layout.rendering` | mode: vibrant (monochrome, desaturated); content: opaque grayscale at full opacity; white / light gray for the most prominent content; minText: 11; margins: system (smaller on the Lock Screen) (VERIFIED) | vibrant: opaque grayscale, white prominent, min text 11 | system vibrant rendering; content drawn in textPrimary at full opacity |
| matched | `widget.lock.rect.layout.content` | noCaptionRectangular: the sender avatar alone, in its 24-pt leading slot (Locket's small widget without a caption shows only the avatar); noCaptionInline: the sentence of widget.home.small.a11y.photo ('{name}’s photo in {group}') as the inline text (the inline widget has no avatar slot); newestIsCollage: keep showing the newest single photo's sender (avatar, and its caption if any): Locket's widget always shows one sender's newest photo and has no collage state (SOURCED) | no caption: avatar alone (rect) / photo sentence (inline); collage newest: newest single photo's sender | GroupWidgetEntryResolver.lockScreenEntry + WidgetRectangularSlot / WidgetInlineSlot |
| matched | `widget.lock.rect.gallery.description` | “See who shared the newest pic in your group” (SOURCED) | Lock Screen kind description | separate widget kind `GroupPhotoLockWidget` |
