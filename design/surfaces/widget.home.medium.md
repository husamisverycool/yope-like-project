# widget.home.medium — iOS systemMedium home-screen widget

Reference: **Locket** small-widget anatomy (Locket shows no medium layout on iOS; its resizable Android widget keeps
the same layout at every size) + **Apple HIG Widgets** (size, container). Everything not listed here is exactly
`widget.home.small` (same widget kind, same copy, same states).

## References

| image | what it verifies |
|---|---|
| `references/auto/locket/store/locket-store-03.png`, `locket-store-06.png` | the anatomy (small) |
| Locket APK 1.243.0 `res/layout/widget.xml`, `res/xml/widget_info.xml` (resizeMode horizontal\|vertical; fixed 32-dp avatar, 8-dp margins at every size) | one layout for every size (C-20) |
| `references/auto/locket/frames/locket-tt-7168613044728155438-11.900s-widget-gallery-card.jpg` (4 page dots, 2022) | Locket offered more than one gallery page (sizes or kinds — unconfirmed) |
| `references/auto/platform/hig-widgets-ios-dimensions.png` | 338 × 158 pt on 393 × 852 |

## Structure

338 × 158 pt on 393 × 852 (`widget.home.medium.layout.size`). Identical layers to `widget.home.small`:

1. photo / collage page aspect-filling the whole widget (`widget.home.small.layout.photo`) — the 3:4 or 9:16 image is
   cropped to the centre of the wide frame (Android centerCrop behaviour);
2. bottom-leading avatar (24 pt at 6 pt) and caption pill, unchanged in size (`widget.home.small.size.*`,
   `.fontSize.caption`, `.color.captionPill`). The pill may run wider (truncates at the trailing edge minus 6 pt).

## Elements

As `widget.home.small` (photo, avatar, caption pill, tap → `camera.fromwidget`). No element is added for the larger
area (no multiple photos, no names — nothing in the reference shows them).

## States

As `widget.home.small`: loading placeholder (`widget.home.small.color.placeholder*`, avatars bottom-leading),
empty (`widget.home.small.layout.empty` md variant, centred), not set up, stale-on-error / offline.

## Motion

Instant swap (`widget.arrival.duration.transition`).

## Haptics

None.

## Accessibility

Same labels as `widget.home.small` (`widget.home.small.a11y.*`); one element; button trait. Contrast as small.

## Data & actions

As `widget.home.small`; the cached rendition is `media.widget_path` (the worker sizes it for the largest widget, see
`backend/worker/src/media/renditions.ts`).

## Platform notes

Same widget kind as small (`supportedFamilies` includes `.systemMedium`); one gallery description for all sizes.
Android equivalent: a 4×2 placement of `widget.android` (same layout).

## Do-not-copy

As `widget.home.small`.

## Gaps

| item | status | capture |
|---|---|---|
| Locket's own medium layout | not observed; anatomy reused (C-20 — HIG warns against "simply filling" a larger area) | one iOS widget-gallery recording swiping through every Locket size + a Home Screen with a Locket medium widget |
| `widget.home.small.color.emptyLabel` | BLOCKED (shared) | see `widget.home.small` |
