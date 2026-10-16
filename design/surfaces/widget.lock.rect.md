# widget.lock.rect — iOS Lock Screen rectangular widget (accessoryRectangular)

**Visual reference: Retro** has no Lock Screen widget; this widget shows **the Retro home widget's information (who
shared, in which group) drawn with Retro's people-row component** (C-16: avatar + name over a second line) in
**Apple HIG's vibrant Lock Screen rendering** (PLATFORM: monochrome, no colour photo). **Mechanics: Locket** (newest
photo of one group, tap → camera). Composition record: `widget.lock.rect.layout.content`. This file also holds the
Lock Screen kind's shared copy (`widget.lock.rect.gallery.*`) and rendering rule (`widget.lock.rect.layout.rendering`)
used by `widget.lock.circular` and `widget.lock.inline`. Decisions: `design/MERGE_DECISIONS.md` RC-11.

## References

| image / doc | what it verifies |
|---|---|
| `references/auto/retro/apk/widget_preview_journals.webp` | the information: name over the album (group) name |
| `references/auto/retro/press/tc-2023-07-retro-1b.webp` (C-16 people row) | avatar 37 + name (15 semibold) + grey line (15 regular) |
| `references/auto/platform/hig-widgets-ios-dimensions.png`; HIG Widgets §Appearances, §Vibrant | 160 × 72 pt; vibrant rendering; "Provide useful information in your Lock Screen widget" |
| docs/PLATFORM_CONSTRAINTS.md ("Color photos on widget.lock.* — Impossible") | no colour photo |

## Structure

160 × 72 pt on 393 × 852 (`widget.lock.rect.layout.size`); system Lock Screen margins; vibrant rendering
(`widget.lock.rect.layout.rendering`): drawn as opaque grayscale at full opacity, the most prominent content white.

One C-16 row, leading-aligned, vertically centred:
1. the newest poster's **avatar** — `size.global.avatarPicker` (37) circle, full opacity (the system desaturates it);
2. `size.global.cardNameGap` (11) after it, two lines: **name** (text role `listTitle`, 15 semibold) over the **group
   name** (text role `listSubtitle`, 15 regular), white (vibrant), each one line, truncated.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| avatar | `size.global.avatarPicker` | — | newest post's poster; no avatar photo → `icon.global.person` (C-23 fallback) |
| name / group | text roles `listTitle` / `listSubtitle` | data | — |
| newest item is a collage | `widget.lock.rect.layout.content` | — | the group name alone (one line, `listTitle`) with `icon.global.camera` in the avatar slot |
| tap | `camera.fromwidget.layout.target` | — | opens the camera, group preselected |
| configuration | — | `widget.home.small.configuration.*` | same group parameter as the home widget |
| gallery | — | `widget.lock.rect.gallery.name`, `.gallery.description` | one Lock Screen kind (circular, rectangular, inline) |

## States

| state | design | copy |
|---|---|---|
| loading | `icon.global.camera` in the avatar slot, no text | — |
| empty / not set up / signed out | `icon.global.camera` in the avatar slot + the state line in `listSubtitle` | `widget.home.small.empty.noPhotos` / `.empty.setUp` / `.empty.signedOut` |
| error / offline | keep the last content (HIG stale-data rule) | — |
| permission-denied | n/a | — |

## Motion

Instant swap (`widget.arrival.duration.transition`); the system adds none.

## Haptics

None.

## Accessibility

One element, button trait: `widget.home.small.a11y.photo` / `.a11y.collage` / the state line. Dynamic Type:
`listTitle` / `listSubtitle` → subheadline. Contrast is system-managed in vibrant mode (white content only).

## Data & actions

Same App Group snapshot as `widget.home.small` (poster avatar, first name, group name). Refresh as `widget.arrival`.

## Platform notes

iOS only: Android phones have no Lock Screen accessory widgets (PLATFORM_CONSTRAINTS §4.2; the Android lock-screen hub
shows `widget.android`). iPad Lock Screen: same rendering. No `AccessoryWidgetBackground`.

## Do-not-copy

Count badges, streaks, Retro's "Post to see" lock; no colour photo.

## Gaps

| item | status | capture / decision |
|---|---|---|
| any Retro or Locket Lock Screen widget | none exists (composition, RC-11) | — |
| gallery name | closed: "Group Updates" (Retro names widgets by content, no `{app_name}`) | — |
