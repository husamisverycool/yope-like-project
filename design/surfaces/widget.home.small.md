# widget.home.small — iOS home-screen widget (systemSmall), and the anatomy every home size shares

Reference: **Locket** (iOS small widget: App Store panels and help drawing; exact Android values for the same
elements where iOS was not measurable) + **Apple HIG Widgets** (sizes, container, rendering). This file also holds
the shared copy (gallery name and description, empty texts, accessibility labels, configuration) used by
`widget.home.medium`, `.large`, `.xl` and `widget.android`.

## References

| image | what it verifies |
|---|---|
| `references/auto/locket/store/locket-store-03.png` | photo fill, avatar 24 pt at 6 pt, caption pill, count badge (do-not-copy) |
| `references/auto/locket/store/locket-store-06.png`, `references/owner/locket-01-widget.webp`, `references/owner/locket-05-receive.webp` | photo fill + avatar, no caption |
| `references/auto/locket/help/locket-help-7914857-widget-with-avatar-crop.png` | Locket's own drawing of the widget |
| `references/auto/locket/frames/locket-tt-7182656074468674859-00.500s-homescreen-widget-and-rewind-2022.jpg` | avatar + caption on a live Home Screen |
| `references/auto/locket/frames/locket-tt-7168613044728155438-15.133s-widget-placeholder-just-added.jpg` → `15.167s-widget-photo-arrived.jpg` | loading placeholder, arrival |
| `references/auto/locket/frames/locket-tt-7168613044728155438-11.900s-widget-gallery-card.jpg`, `references/owner/locket-widget-gallery.jpg`, `…-7532209311150329102-13.750s-gallery-locket-widget-3-friends.jpg` | gallery name / description |
| `references/auto/platform/hig-widgets-ios-dimensions.png` | sizes |

## Structure

158 × 158 pt on a 393 × 852 screen (`widget.home.small.layout.size`); corners from the system (`ContainerRelativeShape`).

1. **Photo** — the group's newest photo, or after a daily invitation the collage's first page, filling the whole
   widget (aspect-fill, `widget.home.small.layout.photo`) as the removable container background; content margins
   disabled.
2. **Bottom row** (photo only, not on the collage), bottom-leading:
   - **sender avatar** 24 pt circle, 6 pt from the leading and bottom edges (`widget.home.small.size.avatar`,
     `.avatarInset`), 1-pt ring `widget.home.small.color.avatarRing`; no avatar → Locket's avatar placeholder: a
     vertical gradient `widget.android.color.avatarPlaceholderTop` → `.avatarPlaceholderBottom`, no glyph;
   - **caption pill** (only when the post has a caption) 5 pt after the avatar, vertically centred on it: height 23,
     horizontal padding 7, shape `radius.global.capsule`, fill `widget.home.small.color.captionPill`; text
     `widget.home.small.fontSize.caption` / `.fontWeight.caption`, `color.global.textPrimary`, one line, truncated
     at the trailing widget edge minus 6 pt.

## Elements

| element | tokens | copy | behavior |
|---|---|---|---|
| photo / collage | `widget.home.small.layout.photo` | a11y `widget.home.small.a11y.photo`, `.photoWithCaption`, `.collage` | newest item of the configured group: the latest post, or the latest collage when it is newer (`collages.composed_at`); muted groups still update |
| avatar | `widget.home.small.size.avatar`, `.avatarInset`, `.size.avatarRing`, `.color.avatarRing` | — | the poster's avatar (`profiles.avatar_path`) |
| caption pill | `widget.home.small.size.captionHeight`, `.captionPadding`, `.captionGap`, `.fontSize.caption`, `.fontWeight.caption`, `.color.captionPill`, `radius.global.capsule` | post caption (user content) | absent without a caption |
| tap | `camera.fromwidget.layout.target` | — | opens `camera.capture` with the group preselected |
| configuration | — | `widget.home.small.configuration.title`, `.group`, `.groupType` | iOS `AppIntentConfiguration` with one group parameter (default: the first group) |
| gallery | — | `widget.home.small.gallery.name`, `.gallery.description` | one widget kind, families small / medium / large (+ extra large on iPad); one description for all sizes (HIG) |

## States

| state | design | copy | source |
|---|---|---|---|
| loading (just added, no rendition cached yet) | vertical gradient `widget.home.small.color.placeholderTop` → `.placeholderBottom`; up to three member avatars, 25 pt, 2.5 pt apart, bottom-leading at 6 pt (`widget.home.small.layout.placeholderAvatars`); also the gallery preview when no photo exists | — | Locket 2022 placeholder (LP) |
| empty (configured group has no photo yet) | gradient `widget.home.small.color.emptyTop` → `.emptyBottom`; centred stack: 72-pt circle `widget.home.small.color.emptyCircle` holding the 32 × 28 photo glyph (`icon.global.gallery`, `color.global.textPrimary`) inside an 82-pt ring (3 pt, `widget.home.small.color.emptyRing`), then the label 9 pt below, 19 pt (`widget.home.small.layout.empty`), color `widget.home.small.color.emptyLabel` (BLOCKED) | `widget.home.small.empty.noPhotos` | Locket APK `widget_empty` (md) |
| not set up (no group: none chosen, left, deleted, signed out) | same empty layout | `widget.home.small.empty.setUp` | APK `tap_to_set_up` |
| error (rendition download failed) / offline | keep the last photo shown (HIG: "show content quickly without hiding stale data behind placeholder content") | — | HIG Widgets |
| permission-denied | n/a | — | — |

## Motion

New photo: instant swap, `widget.arrival.duration.transition` (0 ms) — see `widget.arrival`. No other motion.

## Haptics

None (system widget).

## Accessibility

- One element per widget: label `widget.home.small.a11y.photoWithCaption` (with caption) / `.a11y.photo` / `.a11y.collage`
  / the visible empty label; trait button (opens the camera). Avatar and pill are combined into it (HIG: group an
  image with its caption).
- Dynamic Type: caption → caption, empty label → title3 (`widget.home.small.layout.textStyleMap`); widgets support
  Large–AX5 — the caption stays one line and truncates.
- Contrast: caption white on `#333333CC` over a white photo → #5C5C5C, 6.71:1 pass; over black 14.59:1 pass;
  empty ring #FFB800 on #2E2E2E 7.83:1, on #1B1B1B 9.93:1 pass; glyph white on the circle (#606060 composite) 6.29:1
  pass; **empty circle vs its background 2.16:1 FAIL** (decorative container, no sourced alternative); **avatar ring
  over white 1.26:1 FAIL** (decorative edge); placeholder avatars white-on-#2D2B2F 14.02:1 pass; empty label: BLOCKED.

## Data & actions

- The app writes per-group snapshots to the App Group (newest post: `media.widget_path` signed URL downloaded, poster
  name / avatar, caption; or `collages.widget_path`); the timeline provider reads the cache first
  (docs/PLATFORM_CONSTRAINTS.md §1.6).
- Refresh: widget push (iOS 26+), notification service extension download, background push, timeline `.after`
  15–60 min with jitter, app foreground reload — see `widget.arrival`.
- Out: `camera.fromwidget`.

## Platform notes

- `containerBackground(for: .widget)` holds the photo (removable, required for StandBy / vibrant contexts);
  `contentMarginsDisabled()`; overlay inside the 6-pt inset (C-6).
- Tinted / clear Home Screen appearances: `widgetAccentedRenderingMode(.fullColor)` on the photo (HIG reserves full
  color for media such as album art).
- StandBy: the system scales the small widget and removes the background; the overlay remains.
- Android: `widget.android` (same anatomy, Locket APK values).

## Do-not-copy

Unseen-photo count badge ('9', yellow); streak pill / 'Streak on widget'; '20 Friends' gallery preview as a score;
Gold 'widget frames'; Locket's icon and heart art.

## Gaps

| item | status | capture |
|---|---|---|
| `widget.home.small.color.emptyLabel` | BLOCKED | one screenshot of a just-added, empty Locket Android widget |
| iOS caption-pill blur radius | approximated by the APK fill | lossless iOS Home Screen screenshot of a captioned Locket widget |
| caption weight (semibold vs bold) | visual | side-by-side verification |
| gallery name | BLOCKED until `{app_name}` | owner names the app |
