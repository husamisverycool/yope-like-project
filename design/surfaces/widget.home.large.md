# widget.home.large — iOS systemLarge home-screen widget

Reference: **Locket** small-widget anatomy + its resizable Android layout (C-20) + **Apple HIG Widgets**. Everything
not listed here is `widget.home.small`.

## References

| image | what it verifies |
|---|---|
| `references/auto/locket/store/locket-store-03.png`, `locket-store-06.png` | the anatomy |
| Locket APK 1.243.0 `res/layout/widget.xml` + `widget_empty_lg.xml` (large empty variant) | one layout at every size; a dedicated large empty state |
| `references/auto/platform/hig-widgets-ios-dimensions.png` | 338 × 354 pt on 393 × 852 |

## Structure

338 × 354 pt on 393 × 852 (`widget.home.large.layout.size`).

1. photo / collage page aspect-filling the widget (`widget.home.small.layout.photo`) — a 3:4 photo or a 9:16 collage
   page is cropped to the near-square frame;
2. avatar (24 pt at 6 pt) + caption pill, same sizes as small.

## Elements

As `widget.home.small`.

## States

- loading: `widget.home.small` placeholder.
- empty / not set up: the Locket **lg** variant of `widget.home.small.layout.empty` — circle 98, ring 110 (3-pt
  stroke), glyph 43 × 36, label 21 pt, label gap 24 (APK `widget_empty_lg.xml`, `dimen/empty_widget_*_lg`; values in
  the notes of `widget.home.small.layout.empty`), same colors; copy `widget.home.small.empty.noPhotos` / `.setUp`;
  label color BLOCKED.
- error / offline: keep the last photo.

## Motion

Instant swap.

## Haptics

None.

## Accessibility

As small. Empty label at 21 pt → Dynamic Type title3 (nearest of Title 3 20 pt).

## Data & actions

As small.

## Platform notes

`.systemLarge` in the same widget kind. Android: a 4×3 / 4×4 placement of `widget.android`.

## Do-not-copy

As small.

## Gaps

| item | status | capture |
|---|---|---|
| Locket's own large layout | not observed; anatomy reused (C-20) | iOS gallery recording of every Locket size |
| rule for choosing Locket's sm / md / lg empty variant | not observed (chosen in Locket's code); large and xl use lg | screenshots of empty Locket Android widgets at 2×2 and 4×4 |
| empty label color | BLOCKED | see `widget.home.small` |
