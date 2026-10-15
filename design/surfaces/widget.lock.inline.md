# widget.lock.inline — iOS Lock Screen inline widget (accessoryInline, above the clock)

Reference: **Locket** small-widget anatomy (its only text element is the caption) + **Apple HIG Widgets** ("inline
text that appears above the clock"; "inline accessory widgets offer only one tap target"). Shared kind, copy and
rendering: `widget.lock.rect`.

## References

| image / doc | what it verifies |
|---|---|
| `references/auto/locket/store/locket-store-03.png` | the caption ('Sundays ☀️') |
| `references/auto/platform/hig-widgets-ios-dimensions.png`; HIG Widgets §iOS, iPadOS | 234 × 26 pt; one line of text (+ optional symbol) |

## Structure

234 × 26 pt on 393 × 852 (`widget.lock.inline.layout.size`). One line, system font and size (the system styles inline
widgets; custom fonts are ignored):

1. the newest photo's **caption**, truncated by the system.

## Elements

| element | tokens | copy | behavior |
|---|---|---|---|
| caption | `widget.lock.inline.layout.size` | post caption (user content) | no caption → the `widget.home.small.a11y.photo` sentence; newest item is a collage → the newest single photo's caption (`widget.lock.rect.layout.content`) |
| tap (one target) | `camera.fromwidget.layout.target` | — | opens the camera, group preselected |

## States

| state | design | copy |
|---|---|---|
| not set up / empty | the text line | `widget.home.small.empty.setUp` / `.empty.noPhotos` |
| loading | empty line (system placeholder) | — |
| error / offline | last content kept | — |

## Motion

None (system).

## Haptics

None.

## Accessibility

VoiceOver reads the line; label `widget.home.small.a11y.photoWithCaption` gives who and where.

## Data & actions

As `widget.lock.rect`.

## Platform notes

iOS only. The system renders inline text in its own style next to the date; only `Text` (+ an optional `Image`) is honoured.

## Do-not-copy

As `widget.home.small`.

## Gaps

| item | status | capture |
|---|---|---|
| no caption / collage newest | SOURCED by gap fill as a composition (`widget.lock.rect.layout.content`) | see `widget.lock.rect` |
