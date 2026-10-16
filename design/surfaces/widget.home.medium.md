# widget.home.medium — iOS systemMedium home-screen widget

**Visual reference: Retro's Glance widget**, which is resizable from its 2 × 2 default (min resize 100 dp) and keeps
one layout at every size: full-bleed photo + bottom-trailing text stack. **Mechanics: Locket** (newest photo of the
group, tap → camera). Size: **Apple HIG Widgets**. Everything not listed here is exactly `widget.home.small` (same
kind, copy, states). Decisions: `design/MERGE_DECISIONS.md` RC-11.

## References

| image / source | what it verifies |
|---|---|
| `references/auto/retro/apk/widget_preview_journals.webp` | the anatomy |
| `references/auto/retro/apk/retro-android-2026.10.1150-excerpts.txt` "WIDGET PROVIDERS" (minResize 100 dp, target 2 × 2) | one layout across sizes |
| `references/auto/platform/hig-widgets-ios-dimensions.png` | 338 × 158 pt on 393 × 852 (`widget.home.medium.layout.size`) |

## Structure

338 × 158 pt (`widget.home.medium.layout.size`). The layers of `widget.home.small`: the photo / collage page
aspect-filling the wide frame (centre crop), `layout.global.photoScrim`, the text stack
(`widget.home.small.layout.overlay`, same 11-pt lines, insets 11 / 15) at the bottom-trailing corner.

## Elements

As `widget.home.small`. No element is added for the larger area (Retro's resizable widget adds none).

## States

As `widget.home.small` (state column centred in the wider frame).

## Motion

Instant swap (`widget.arrival.duration.transition`).

## Haptics

None.

## Accessibility

Labels and contrast as `widget.home.small` (`widget.home.small.a11y.*`); one element, button trait.

## Data & actions

As `widget.home.small`; rendition `media.widget_path` (sized by the worker for the largest widget).

## Platform notes

Same widget kind (`supportedFamilies` includes `.systemMedium`); Android equivalent: a 4 × 2 placement of
`widget.android`.

## Do-not-copy

As `widget.home.small`.

## Gaps

| item | status | capture |
|---|---|---|
| Retro's widget at a non-square size | not captured; one layout per the provider's resize rule (RC-11) | one home-screen screenshot of a resized Retro widget |
