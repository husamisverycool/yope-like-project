# widget.lock.rect — iOS Lock Screen rectangular widget (accessoryRectangular)

Reference: **Locket** small-widget anatomy (Locket has **no** Lock Screen widget — locket.md §3) + **Apple HIG
Widgets** (Lock Screen: vibrant, monochrome). Composed only from those two (MERGE_DECISIONS C-19). This file also
holds the Lock Screen widget kind's shared copy (`widget.lock.rect.gallery.*`) and rendering rule
(`widget.lock.rect.layout.rendering`) used by `widget.lock.circular` and `widget.lock.inline`.

## References

| image / doc | what it verifies |
|---|---|
| `references/auto/locket/store/locket-store-03.png` | the bottom row of the anatomy: avatar + caption side by side |
| `references/auto/platform/hig-widgets-ios-dimensions.png`; https://developer.apple.com/design/human-interface-guidelines/widgets §Appearances, §Vibrant, §iOS, iPadOS | 160 × 72 pt; vibrant rendering; "Provide useful information in your Lock Screen widget, and don't treat it as an additional way for people to launch into your app" |
| docs/PLATFORM_CONSTRAINTS.md summary ("Color photos on widget.lock.* — Impossible") | no color photo on the iPhone Lock Screen |

## Structure

160 × 72 pt on 393 × 852 (`widget.lock.rect.layout.size`); system Lock Screen margins; vibrant rendering
(`widget.lock.rect.layout.rendering`): everything is drawn as opaque grayscale at full opacity, the most prominent
content white.

One row, leading-aligned, vertically centred:
1. **sender avatar** of the newest photo — 24 pt circle (`widget.home.small.size.avatar`), drawn full opacity (the
   system desaturates it);
2. **caption** text 5 pt after it (`widget.home.small.size.captionGap`), `widget.home.small.fontSize.caption` /
   `.fontWeight.caption` (12 pt ≥ the 11-pt minimum), white, up to the lines that fit 72 pt, truncated. No pill (a
   translucent fill has no meaning in vibrant mode — HIG: "use opaque grayscale values, rather than opacities of white").

## Elements

| element | tokens | copy | behavior |
|---|---|---|---|
| avatar | `widget.home.small.size.avatar` | — | newest post's poster |
| caption | `widget.home.small.fontSize.caption`, `.fontWeight.caption`, `.size.captionGap` | post caption (user content) | — |
| no caption / newest item is a collage | `widget.lock.rect.layout.content` | — | no caption: the avatar alone in its slot (Locket's no-caption widget, store-06); newest is a collage: keep the newest single photo's avatar (+ caption) |
| tap | `camera.fromwidget.layout.target` | — | opens the camera with the group preselected (the widget's information is the avatar + caption; the tap is the default widget action) |
| configuration | — | `widget.home.small.configuration.*` | same group parameter as the home widget |
| gallery | — | `widget.lock.rect.gallery.name`, `.gallery.description` | one Lock Screen widget kind (circular, rectangular, inline) |

## States

| state | design | copy |
|---|---|---|
| loading / not set up / empty | `icon.global.gallery` (white, centred in the leading 24-pt slot) + the empty text in the caption style | `widget.home.small.empty.setUp` (not set up) / `.empty.noPhotos` (empty); loading shows the glyph only |
| error / offline | keep the last content (HIG stale-data rule) | — |
| permission-denied | n/a | — |

## Motion

Instant swap on new content (`widget.arrival.duration.transition`); the system adds none on the Lock Screen.

## Haptics

None.

## Accessibility

One element: `widget.home.small.a11y.photoWithCaption` (or the empty text); button trait. Dynamic Type: caption →
caption style. Contrast is system-managed in vibrant mode (Always-On reduced luminance: HIG asks for enough gray
levels — white content only).

## Data & actions

Same App Group snapshot as `widget.home.small` (poster avatar, caption). Refresh as `widget.arrival`.

## Platform notes

iOS only: Android phones have no Lock Screen accessory widgets (docs/PLATFORM_CONSTRAINTS.md §4.2); the Android
lock-screen hub shows `widget.android` instead. iPad Lock Screen: same rendering (monochrome without tint).
Use `AccessoryWidgetBackground` only if a background is needed — none here.

## Do-not-copy

Count badge, streaks (not representable anyway); no color photo.

## Gaps

| item | status | capture |
|---|---|---|
| content when there is no caption, and when the newest item is a collage | SOURCED by gap fill as a composition (`widget.lock.rect.layout.content`, MERGE G2-13): Locket's no-caption anatomy + its one-photo rule; flagged for the owner | one screenshot of the iOS Lock Screen 'Add Widgets' sheet after searching 'Locket', or an owner decision |
| whether Locket offers any Lock Screen widget | not found in 56 help articles, store pages, APK (0 'lock screen' strings) | same screenshot |
| gallery name | BLOCKED until `{app_name}` | owner |
