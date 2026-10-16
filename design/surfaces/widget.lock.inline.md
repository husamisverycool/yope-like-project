# widget.lock.inline — iOS Lock Screen inline widget (accessoryInline, above the clock)

**Visual reference: Retro** has no Lock Screen widget; the line carries the Retro home widget's two lines (name,
group) joined with Retro's meta separator " · " (`retro.voice.formats`), in **HIG's inline style** (PLATFORM: system
font and size, one line, one tap target). **Mechanics: Locket.** Shared kind, copy and rendering: `widget.lock.rect`.

## References

| image / doc | what it verifies |
|---|---|
| `references/auto/retro/apk/widget_preview_journals.webp` | the information (name, group) |
| `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` `home_feed_card_muted_with_seen` "Muted · Seen" (`retro.voice.formats`) | the " · " meta separator |
| `references/auto/platform/hig-widgets-ios-dimensions.png`; HIG Widgets §iOS, iPadOS | 234 × 26 pt; one line of text |

## Structure

234 × 26 pt on 393 × 852 (`widget.lock.inline.layout.size`). One line, styled by the system:

1. `widget.lock.inline.text` ("{name} · {group}"), truncated by the system. Newest item is a collage: the group name.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| line | `widget.lock.inline.layout.size`, `widget.lock.rect.layout.content` (inline) | `widget.lock.inline.text` | — |
| tap (one target) | `camera.fromwidget.layout.target` | — | opens the camera, group preselected |

## States

| state | design | copy |
|---|---|---|
| empty / not set up / signed out | the state line | `widget.home.small.empty.noPhotos` / `.setUp` / `.signedOut` |
| loading | empty line (system placeholder) | — |
| error / offline | last content kept | — |

## Motion

None (system).

## Haptics

None.

## Accessibility

VoiceOver reads the line; label `widget.home.small.a11y.photo` gives who and where.

## Data & actions

As `widget.lock.rect`.

## Platform notes

iOS only; only `Text` (+ an optional `Image`) is honoured; custom fonts are ignored.

## Do-not-copy

As `widget.home.small`.

## Gaps

None BLOCKED.
