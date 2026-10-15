# widget.home.xl — systemExtraLarge (iPad only)

Reference: **Apple HIG Widgets** ("System extra large | iPhone: Not supported | iPad: Home Screen and Today View") +
**Locket** anatomy (C-20). On iPhone this surface does not exist (docs/PLATFORM_CONSTRAINTS.md summary).

## References

| image | what it verifies |
|---|---|
| `references/auto/platform/hig-widgets-ios-dimensions.png`; https://developer.apple.com/design/human-interface-guidelines/widgets (system-family support table) | iPad-only, sizes |
| `references/auto/locket/store/locket-store-03.png`; Locket APK `widget_empty_lg.xml` | anatomy, large empty state |

## Structure

iPad sizes (`widget.home.xl.layout.size`): 748 × 356 pt (13" iPad), 628 × 300, 540 × 260 …

1. photo / collage page aspect-filling the widget (`widget.home.small.layout.photo`), centre-cropped to the wide frame;
2. avatar (24 pt at 6 pt) + caption pill, unchanged (`widget.home.small.size.*`).

## Elements

As `widget.home.small`.

## States

As `widget.home.large` (lg empty variant; loading placeholder; stale on error / offline).

## Motion

Instant swap.

## Haptics

None.

## Accessibility

As small.

## Data & actions

As small. The widget rendition is sized for iPhone widgets; on a 748-pt-wide iPad widget it is upscaled — use the
display rendition (`media.display_path`) for `.systemExtraLarge` (docs/API.md §7 'Which image to show').

## Platform notes

Declare `.systemExtraLarge` in `supportedFamilies`; the iPhone widget gallery never offers it (HIG table). Android has no extra-large class; `widget.android` resizes.

## Do-not-copy

As small.

## Gaps

| item | status | capture |
|---|---|---|
| any Locket iPad widget | not observed | one iPad Home Screen screenshot with Locket widgets |
| empty label color | BLOCKED | see `widget.home.small` |
