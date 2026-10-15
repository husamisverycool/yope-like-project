# Verification — `widget.lock.rect` (iOS)

Lock Screen rectangular — `WidgetRectangularSlot`.

Checklist written from the spec (`design/surfaces/widget.lock.rect.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>.png`, then `tools/sidebyside.py` makes `design/verification/widget.lock.rect.png` next to the reference image(s) below.

Reference image(s): `references/auto/locket/store/locket-store-03.png`, `references/auto/platform/hig-widgets-ios-dimensions.png`

Snapshots (CI): `widget.lock.rect-photo-caption.png`, `widget.lock.rect-photo-no-caption.png`, `widget.lock.rect-empty.png`, `widget.lock.rect-not-set-up.png`, `widget.lock.rect-loading.png`

**Summary: 9 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Values

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `widget.lock.rect.layout.size` | w430h932: 172x76; w428h926: 172x76; w414h896: 160x72; w414h736: 170x76; w393h852: 160x72; w390h844: 160x72; w375h812: 157x72; w375h667: 153x68; w360h780: 157x72 (VERIFIED) | 160 × 72 | accessoryRectangular |
| matched | `widget.home.small.size.avatar` | 24 pt (SOURCED) | avatar 24 | WidgetAvatar (no ring) |
| matched | `widget.home.small.size.captionGap` | 5 pt (SOURCED) | caption 5 after avatar | HStack spacing |
| matched | `widget.home.small.fontSize.caption` | 12 pt (SOURCED) | caption 12 | DSTextStyle, lines that fit |
| matched | `widget.home.small.fontWeight.caption` | semibold (SOURCED) | semibold | DSTextStyle |
| matched | `icon.global.gallery` | ios: photo.on.rectangle; android: Rounded.PhotoLibrary (PLATFORM) | empty / loading glyph in the 24-pt slot | Image |
| matched | `widget.lock.rect.layout.rendering` | mode: vibrant (monochrome, desaturated); content: opaque grayscale at full opacity; white / light gray for the most prominent content; minText: 11; margins: system (smaller on the Lock Screen) (VERIFIED) | vibrant: opaque grayscale, white prominent, min text 11 | system vibrant rendering; content drawn in textPrimary at full opacity |
| matched | `widget.lock.rect.layout.content` | noCaptionRectangular: the sender avatar alone, in its 24-pt leading slot (Locket's small widget without a caption shows only the avatar); noCaptionInline: the sentence of widget.home.small.a11y.photo ('{name}’s photo in {group}') as the inline text (the inline widget has no avatar slot); newestIsCollage: keep showing the newest single photo's sender (avatar, and its caption if any): Locket's widget always shows one sender's newest photo and has no collage state (SOURCED) | no caption: avatar alone (rect) / photo sentence (inline); collage newest: newest single photo's sender | GroupWidgetEntryResolver.lockScreenEntry + WidgetRectangularSlot / WidgetInlineSlot |
| matched | `widget.lock.rect.gallery.description` | “See who shared the newest pic in your group” (SOURCED) | Lock Screen kind description | separate widget kind `GroupPhotoLockWidget` |

## Notes

- Snapshots approximate vibrant mode with zero saturation (the system renders the real mode).
- The Lock Screen kind resolves the newest single photo; the Home Screen kind keeps the collage.
