# widget.android — Glance home-screen widget (all sizes)

**Visual reference: Retro's own Android widgets** (androidx.glance, APK 2026.10.1150): provider 200 × 200 dp, resizable
to 100 dp, default 2 × 2, hourly update, 22-dp corners, full-bleed photo with the white bottom-trailing text stack,
state glyph in a 48-dp box tinted white 85 %. **Mechanics: Locket (Android)** — newest photo per group, tap → camera,
push-driven refresh. Same anatomy and copy as `widget.home.small`. Decisions: `design/MERGE_DECISIONS.md` RC-9 … RC-11.

## References

| source | what it verifies |
|---|---|
| `references/auto/retro/apk/retro-android-2026.10.1150-excerpts.txt` §"WIDGET PROVIDERS", §"Glance widget" (qmh.java), §"TOASTS" (`app_widget_refreshing_toast`) | `widget.android.layout.provider`, `.radius.widget`, `.duration.updatePeriod`, `widget.home.small.color.stateTint` |
| `references/auto/retro/apk/widget_preview_friends.webp`, `…_journals.webp`, `…_memories.webp` | anatomy; picker previews (Retro ships static preview art) |
| `references/auto/platform/android-widget-default-sizes.png`; https://developer.android.com/develop/ui/compose/glance/create-app-widget | size classes (`widget.android.layout.sizes`) |

## Structure

Root container edge to edge at every size, no outer padding, `cornerRadius(widget.android.radius.widget)` (22 dp).

1. **Photo / collage page**, `ContentScale.Crop` over the whole widget (`widget.home.small.layout.photo`);
2. **scrim** `layout.global.photoScrim` (a drawable gradient: Glance has no runtime gradient brush);
3. **text stack** (`widget.home.small.layout.overlay`) bottom-end: name over group name,
   `widget.home.small.fontSize.overlay` (11 sp), regular, `Tokens.ColorsLight.globalTextOnMedia` (#FFFFFF; Glance
   `ColorProvider` outside composition), end inset 11 dp, last baseline 15 dp above the bottom, line pitch 13 dp,
   `maxLines = 1` each.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| widget provider | `widget.android.layout.provider`, `widget.android.duration.updatePeriod`, `widget.android.layout.lockScreen` | label `widget.android.label`, description `widget.android.description` | default 2 × 2; resizable down to 100 dp; reconfigurable; home screen and lock-screen hub (`home_screen\|keyguard`); generated preview (Android 15+); static `previewImage` BLOCKED (owner asset) |
| photo, scrim, text stack | as Structure | root `contentDescription` `widget.home.small.a11y.photo` / `.a11y.collage` | — |
| tap | `camera.fromwidget.layout.target` (PendingIntent) | — | opens `camera.capture`, group preselected; on the collage, opens that collage (`collage.view`) |
| configure activity | page `color.global.background.android`; centred title (text role `sheetTitle`); C-16 rows: group cover (`size.global.avatarPicker`), name text role `listTitle` (`lineHeight.global.listTitle.android`, `letterSpacing.global.listTitle.android`) `color.global.textPrimary`, C-32 hairlines | title `widget.home.small.configuration.title`; empty `widget.android.configure.empty` | tapping a group finishes with RESULT_OK (single choice — no "Done") |

## States

| state | design | copy |
|---|---|---|
| loading | `color.global.backgroundDeep`, no content | — |
| empty | state column (`widget.home.small`): `icon.global.camera` 24 dp in a 48-dp box (12 padding), tint `widget.home.small.color.stateTint`, line 11 sp same tint | `widget.home.small.empty.noPhotos` |
| not set up / group gone | same | `widget.home.small.empty.setUp` (tap → configure activity) |
| signed out | same | `widget.home.small.empty.signedOut` (tap → app sign-in) |
| error / offline | keep the last image | — |
| refresh running (foreground job) | `widget.arrival` notification | `widget.arrival.android.*` |
| configure: loading / empty / error | C-28 indicator; C-27 block with `widget.android.configure.empty`; error line `camera.sendto.error.generic` | as listed |

## Motion

None — Glance replaces its content (`widget.arrival.duration.transition`).

## Haptics

None on the widget. Configure activity rows: `haptic.global.tap` (VIRTUAL_KEY).

## Accessibility

Root `contentDescription` as listed; the whole widget is the touch target (≥ 48 dp). Text in sp follows the font
scale. Contrast as `widget.home.small` (photo-dependent text stack: 2.32–3.23:1 over a white photo **FAIL**, 7.42:1
over mid grey; state tint 14.88:1). Configure activity: `color.global.textPrimary` on `color.global.background.android` 21.00:1 / 17.01:1 pass.

## Data & actions

`WidgetUpdateWorker` downloads `media.widget_path` / `collages.widget_path` into app storage and calls
`GlanceAppWidget.updateAll`; triggered by FCM (`widget` data message) or the hourly safety net. Out: `camera.fromwidget`.

## Platform notes

- **Lock screen (owner decision 18: opt in)** — `widget.android.layout.lockScreen`: the provider declares
  `widgetCategory="home_screen|keyguard"` (`WIDGET_CATEGORY_KEYGUARD`, API 17: "Indicates that the widget can be displayed
  on the keyguard"), so the widget is offered on the lock-screen widget hub wherever the OS has one — AOSP from "the
  release after Android 16 (QPR1)" (Pixel phones from Android 16 QPR2), Pixel Tablet since 2024; older releases ignore
  the flag and keep it on the home screen. The hub slot is "approximately 4 cells wide by 3 cells tall" → the responsive
  **Medium** layout (`PlatformWidgetGrid.minSize(4, 3)` = 276 × 183 dp): photo / collage with the text stack, and the state
  column, unchanged (snapshots `widget.android_keyguard_{photo,collage,empty,signedout}`, feature/capture
  `WidgetSnapshotTest.keyguardHubSlot`). The person adds it to the hub themselves; a tap opens the camera only after
  unlock (`MainActivity` declares no `showWhenLocked`; "users must authenticate to launch the activity"). The generated
  preview (Android 15+) covers the keyguard category too (Glance `setWidgetPreviews` default). Sources:
  https://android-developers.googleblog.com/2025/03/widgets-on-lock-screen-faq.html,
  https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo; docs/PLATFORM_CONSTRAINTS.md §4.2.
- No accessory widgets on Android phones; `widget.lock.*` is iOS only.
- Font: Glance text uses the system sans (Glance cannot load the bundled Inter) — PLATFORM limitation.
- Corners: `cornerRadius` works on Android 12+; below 12 the root uses a 22-dp rounded shape drawable.

## Do-not-copy

Retro: "Post to see" locked state (black 70 % overlay + lock glyph), "Keyholders" picker item, refresh-on-tap,
`widget_preview_*` art. Locket: missed-moments count badge, streak frame, Gold frames, weather / music captions.

## Gaps

| item | status | capture |
|---|---|---|
| static `previewImage` asset | BLOCKED (owner-approved image; Retro's art is do-not-copy) | owner asset |
| Retro widget text on a device | mdpi preview art (±1 dp) | one Android home-screen screenshot of a Retro widget at 2 × 2 |
| Retro empty / error widget as rendered | composed (RC-10) | one screenshot of an empty Retro widget |
