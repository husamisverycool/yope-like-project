# widget.home.xl — systemExtraLarge (iPad only)

**Visual reference: Retro's Glance widget** (one layout at every size, RC-11; Retro ships no iPad set — App Store
`ipadScreenshotUrls: []`). **Mechanics: Locket.** Size and availability: **Apple HIG Widgets** ("System extra large |
iPhone: Not supported | iPad: Home Screen and Today View"). Everything not listed here is `widget.home.small`.

## References

| image / doc | what it verifies |
|---|---|
| `references/auto/platform/hig-widgets-ios-dimensions.png`; https://developer.apple.com/design/human-interface-guidelines/widgets | iPad-only, sizes (`widget.home.xl.layout.size`) |
| `references/auto/retro/apk/widget_preview_journals.webp` | the anatomy |

## Structure

iPad sizes (`widget.home.xl.layout.size`): 748 × 356 pt (13" iPad), 628 × 300, 540 × 260 … Photo / collage page
aspect-filling the wide frame, `layout.global.photoScrim`, the text stack (`widget.home.small.layout.overlay`)
bottom-trailing.

## Elements

As `widget.home.small`.

## States

As `widget.home.small`.

## Motion

Instant swap.

## Haptics

None.

## Accessibility

As `widget.home.small`.

## Data & actions

As `widget.home.small`; on a 748-pt-wide widget use the display rendition (`media.display_path`) — the widget
rendition is sized for iPhone widgets (docs/API.md §7 "Which image to show").

## Platform notes

Declare `.systemExtraLarge` in `supportedFamilies`; never offered on iPhone. Android has no extra-large class.

## Do-not-copy

As `widget.home.small`.

## Gaps

| item | status | capture |
|---|---|---|
| any Retro iPad widget | not observed (no iPad app set) | — |
