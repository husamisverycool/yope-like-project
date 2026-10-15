# widget.lock.circular — iOS Lock Screen circular widget (accessoryCircular)

Reference: **Locket** small-widget anatomy (the anatomy's one circular element is the sender avatar) + **Apple HIG
Widgets** (vibrant Lock Screen rendering). Shared kind, copy and rendering: `widget.lock.rect`.

## References

| image / doc | what it verifies |
|---|---|
| `references/auto/locket/store/locket-store-03.png`, `references/auto/locket/help/locket-help-7914857-widget-with-avatar-crop.png` | round sender avatar |
| `references/auto/platform/hig-widgets-ios-dimensions.png`; HIG Widgets §Appearances / §Vibrant | 72 × 72 pt; monochrome |

## Structure

72 × 72 pt on 393 × 852 (`widget.lock.circular.layout.size`), rendering `widget.lock.rect.layout.rendering`.

1. The newest photo's **sender avatar**, filling the circle (the anatomy's circular avatar, scaled to the family),
   full opacity — the system desaturates it.

## Elements

| element | tokens | copy | behavior |
|---|---|---|---|
| avatar | `widget.lock.circular.layout.size` | a11y `widget.home.small.a11y.photo` | newest post's poster; when the newest item is a collage: the newest single photo's poster (`widget.lock.rect.layout.content`) |
| tap | `camera.fromwidget.layout.target` | — | opens the camera, group preselected |

## States

| state | design | copy |
|---|---|---|
| loading / empty / not set up | `icon.global.gallery` centred, white | spoken: `widget.home.small.empty.noPhotos` / `.setUp` |
| error / offline | last content kept | — |

## Motion

Instant swap.

## Haptics

None.

## Accessibility

One element, label `widget.home.small.a11y.photo` ("{name}’s photo in {group}") or the empty text; button trait.

## Data & actions

As `widget.lock.rect` (avatar from the App Group snapshot).

## Platform notes

iOS only (no Android accessory widgets). `widgetAccentedRenderingMode` does not apply on the Lock Screen (vibrant).
Limited-width contexts do not apply to widgets.

## Do-not-copy

As `widget.home.small`.

## Gaps

| item | status | capture |
|---|---|---|
| collage as the newest item | SOURCED by gap fill as a composition (`widget.lock.rect.layout.content`) | see `widget.lock.rect` |
