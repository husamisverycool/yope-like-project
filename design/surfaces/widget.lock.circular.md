# widget.lock.circular — iOS Lock Screen circular widget (accessoryCircular)

**Visual reference: Retro** has no Lock Screen widget; the circle shows the newest poster's **avatar** (Retro C-23
circle) in **HIG vibrant rendering** (PLATFORM). **Mechanics: Locket.** Shared kind, copy and rendering:
`widget.lock.rect`. Decisions: `design/MERGE_DECISIONS.md` RC-11.

## References

| image / doc | what it verifies |
|---|---|
| `references/auto/retro/store/retro-store-02.png`, `references/auto/retro/press/tc-2023-07-retro-1b.webp` (C-23) | Retro avatars are plain circles, aspect-fill |
| `references/auto/platform/hig-widgets-ios-dimensions.png`; HIG Widgets §Vibrant | 72 × 72 pt; monochrome |

## Structure

72 × 72 pt on 393 × 852 (`widget.lock.circular.layout.size`), rendering `widget.lock.rect.layout.rendering`.

1. The newest photo's **poster avatar**, aspect-fill, filling the circle (C-23), full opacity — the system desaturates
   it. No avatar photo: `icon.global.person` centred (C-23 fallback).

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| avatar | `widget.lock.circular.layout.size`, `widget.lock.rect.layout.content` (circular) | a11y `widget.home.small.a11y.photo` | newest single photo's poster; newest is a collage → `icon.global.camera` |
| tap | `camera.fromwidget.layout.target` | — | opens the camera, group preselected |

## States

| state | design | copy |
|---|---|---|
| loading / empty / not set up / signed out | `icon.global.camera` centred (`size.global.icon`), white | spoken: `widget.home.small.empty.noPhotos` / `.setUp` / `.signedOut` |
| error / offline | last content kept | — |

## Motion

Instant swap.

## Haptics

None.

## Accessibility

One element, button trait; label `widget.home.small.a11y.photo` or the state line.

## Data & actions

As `widget.lock.rect`.

## Platform notes

iOS only. `widgetAccentedRenderingMode` does not apply on the Lock Screen (vibrant).

## Do-not-copy

As `widget.home.small`.

## Gaps

None BLOCKED.
