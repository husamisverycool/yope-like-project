# widget.home.small — iOS home-screen widget (systemSmall), and the anatomy every home size shares

**Visual reference: Retro's Glance widgets** (Friend Updates / Your Memories / Albums — APK 2026.10.1150 provider and
code constants, mdpi preview art): full-bleed photo, rounded container, white two-line text stack at the
bottom-trailing corner (name over album title / place), states with a white-85 % glyph and one line. Our widget is
Retro's **Albums** variant: name over the **group** name. **Mechanics: Locket** — the group's newest photo (or, after
a daily invitation, the collage), tap opens the camera (`camera.fromwidget`). Size and container: **Apple HIG Widgets**
(PLATFORM). This file holds the shared copy and anatomy used by `widget.home.medium`, `.large`, `.xl`,
`widget.lock.*` and `widget.android`. Decisions: `design/MERGE_DECISIONS.md` RC-9 … RC-11.

## References

| image / source | what it verifies |
|---|---|
| `references/auto/retro/apk/widget_preview_journals.webp` (Albums), `…_friends.webp`, `…_memories.webp` | full-bleed photo; text stack 'cheryl' / 'Seoul 2024' (`widget.home.small.layout.overlay`, `.fontSize.overlay`, `.fontWeight.overlay`) |
| `references/auto/retro/apk/retro-android-2026.10.1150-excerpts.txt` §"Glance widget" (qmh.java), §"WIDGET PROVIDERS" | 22-dp corners, state glyph 48-dp box tinted white 85 % (`.color.stateTint`), 2 × 2 default, hourly refresh |
| `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` `widget_title_*`, `widget_description_*`, `app_widget_*` | gallery names, descriptions, state lines, configuration title |
| `references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png` (VID-SET) | Retro iOS ships the same widgets ("Memories", "Friend Updates" in Settings → Widgets) |
| `references/auto/locket/store/locket-store-03.png`, `locket-store-06.png` | mechanics: newest photo of one circle, tap → camera |
| `references/auto/platform/hig-widgets-ios-dimensions.png` | sizes (`widget.home.small.layout.size`) |

## Structure

158 × 158 pt on 393 × 852 (`widget.home.small.layout.size`); corners from the system (`ContainerRelativeShape`).

1. **Photo** — the group's newest photo, or the newest collage's first page when it is newer, filling the whole
   widget (aspect-fill, `widget.home.small.layout.photo`) as the removable container background; content margins
   disabled.
2. **Scrim** — `layout.global.photoScrim` (black from 55 % of the height to `color.global.scrim` at the bottom).
3. **Text stack** (`widget.home.small.layout.overlay`), bottom-trailing, trailing-aligned: line 1 the poster's first
   name, line 2 the group name; `widget.home.small.fontSize.overlay` (11) / `.fontWeight.overlay` (regular),
   `color.global.textOnMedia`; trailing inset 11, last baseline 15 above the bottom edge, line pitch 13; each line one
   line, truncated at the leading inset `size.global.screenMargin`. Collage: one line, the group name.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| photo / collage | `widget.home.small.layout.photo`, `layout.global.photoScrim` | a11y `widget.home.small.a11y.photo` / `.a11y.collage` | newest item of the configured group (`media.widget_path` / `collages.widget_path`); muted groups still update |
| text stack | `widget.home.small.layout.overlay`, `.fontSize.overlay`, `.fontWeight.overlay`, `color.global.textOnMedia` | data: first name (first word of `display_name`), group name | — |
| tap | `camera.fromwidget.layout.target` | — | opens `camera.capture` with the group preselected |
| configuration | AppIntentConfiguration | `widget.home.small.configuration.title`, `.configuration.group`, `.configuration.groupType` | one group parameter (default: the first group) |
| gallery | — | `widget.home.small.gallery.name`, `.gallery.description` | one widget kind, families small / medium / large (+ extra large on iPad), one description (HIG) |

## States

All non-photo states: background `color.global.backgroundDeep` (composition, RC-10); centred column: `icon.global.camera`
at `size.global.icon` in a 48-pt box (12 padding, APK) tinted `widget.home.small.color.stateTint`, then the line in
`widget.home.small.fontSize.overlay`, same tint, centred, up to 2 lines.

| state | design | copy | source |
|---|---|---|---|
| loading (just added, nothing cached) | `color.global.backgroundDeep`, no content | — | HIG ("show content quickly"); Retro's loading not captured |
| empty (the group has no photo yet) | state column | `widget.home.small.empty.noPhotos` | `app_widget_empty_message` pattern |
| not set up (no group chosen, group left / deleted) | state column | `widget.home.small.empty.setUp` | `retro.voice.widget` |
| signed out | state column | `widget.home.small.empty.signedOut` | `app_widget_not_logged_in_message` |
| error / offline | keep the last photo (HIG: don't hide stale data); nothing cached → loading | — | HIG Widgets |
| permission-denied | n/a | — | — |

## Motion

New photo: instant swap (`widget.arrival.duration.transition` 0 ms). No other motion.

## Haptics

None (system widget).

## Accessibility

- One element per widget, button trait: label `widget.home.small.a11y.photo` ("{name}'s photo in {group}") /
  `.a11y.collage` / the visible state line.
- Dynamic Type: the text stack scales with Caption 2 (`widget.home.small.layout.textStyleMap`); widgets support
  Large–AX5 and the lines truncate.
- Contrast (identical in light and dark — the widget is a media surface):

| pair | ratio | result |
|---|---|---|
| name line (white) over the scrim (≈ 33 % black at that height) on a white photo | 2.32:1 | **FAIL** (photo-dependent) |
| group line (≈ 44 % black) on a white photo | 3.23:1 | **FAIL** (photo-dependent) |
| same lines on a mid-grey photo (#808080) | 7.42:1 | pass |
| state glyph / line `stateTint` (#FFFFFFD9) on `backgroundDeep` | 14.88:1 | pass |

Reported, not adjusted (Retro draws its widget text this way; no sourced alternative).

## Data & actions

- The app writes per-group snapshots to the App Group (newest post: `media.widget_path` downloaded, poster first name,
  group name; or `collages.widget_path`); the timeline provider reads the cache first (PLATFORM_CONSTRAINTS §1.6).
- Refresh: see `widget.arrival` (widget push iOS 26+, notification service extension, background push, timeline
  `.after` 15–60 min, app foreground). Out: `camera.fromwidget`.

## Platform notes

- `containerBackground(for: .widget)` holds the photo (removable for StandBy / vibrant); `contentMarginsDisabled()`.
- Tinted / clear Home Screen: `widgetAccentedRenderingMode(.fullColor)` on the photo (HIG: full colour for media).
- Font: system (`font.global.family` iOS "system"); Android Glance cannot load Inter (system sans) — `widget.android`.
- Android: `widget.android` (same anatomy, Retro Glance constants).

## Do-not-copy

Retro: "Post to see" lock state and its black-70 % overlay, "Keyholders" picker item, the refresh-on-tap behaviour,
wordmark. Locket: count badge, streak pill, avatar + caption pill, yellow empty ring, gold frames, "20 Friends" preview.

## Gaps

| item | status | smallest capture |
|---|---|---|
| widget text on a device (sizes at @3x, weight) | measured on mdpi preview art (±1 dp) | one home-screen screenshot with Retro's Friend Updates widget at 2 × 2 (RP §9) |
| Retro's empty / error widget as rendered (background, text size) | composed (RC-10) | one screenshot of an empty Retro widget |
| Retro iOS widget at full resolution | Settings carousel only (VID-SET, 640 × 800) | one iPhone home-screen screenshot with a Retro widget |
