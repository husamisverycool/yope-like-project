# widget.android — Glance home-screen widget (all sizes)

Reference: **Locket (Android)** — exact values from the Locket Android APK 1.243.0 resources — + **Material 3 /
Android widget guidelines** (sizes, corner radius, fill rules). Same anatomy and copy as `widget.home.small`.

## References

| image / source | what it verifies |
|---|---|
| `references/auto/locket/play/locket-play-01.png`, `-02.png`, `-04.png` | Android widget on a Home Screen |
| `references/auto/locket/frames/locket-tt-7498394022428331295-04.000s-android-widget-streak-DONOTCOPY.jpg` | live Android widget (streak pill = do-not-copy) |
| Locket APK `res/layout/widget.xml`, `widget_empty*.xml`, `res/xml/widget_info.xml`, drawables (decoded; locket.md §2 and this pass) | every dp value below |
| `references/auto/platform/android-widget-default-sizes.png`; https://developer.android.com/develop/ui/compose/glance/create-app-widget | sizes, `system_app_widget_background_radius` |

## Structure

Root container stretches edge to edge at every size (`widget.android.layout.sizes`), no outer padding; corner radius
`@android:dimen/system_app_widget_background_radius` (Android 12+) or `widget.android.radius.fallback` (8 dp).

1. **photo / collage page**, centerCrop over the whole widget (`widget.home.small.layout.photo`);
2. **avatar** 32 dp circle (`widget.android.size.avatar`), margin start and bottom 8 dp (`widget.android.size.overlayMargin`),
   ring 1 dp `widget.home.small.color.avatarRing`; no avatar → gradient `widget.android.color.avatarPlaceholderTop` →
   `.avatarPlaceholderBottom`;
3. **caption pill** 6 dp after the avatar (`widget.android.size.captionGap`), bottom and end margins 8 dp, vertically
   centred on the avatar: capsule, `widget.home.small.color.captionPill`, height `widget.home.small.size.captionHeight`,
   padding `widget.home.small.size.captionPadding`; text `widget.home.small.fontSize.caption` (sp) /
   `.fontWeight.caption`, `color.global.textPrimary`, one line, ellipsized (C-8: Locket's own Android text-caption
   style fails contrast; the same APK's capsule style is used).

## Elements

| element | tokens | copy | behavior |
|---|---|---|---|
| widget provider | `widget.android.size.minSize` (110 × 110 dp), `widget.android.duration.updatePeriod`, `widget.android.layout.sizes` | label `widget.android.label`, description `widget.android.description` | `resizeMode` horizontal \| vertical; `targetCellWidth/Height` 2 × 2; generated preview (Android 15+) from the current content; `previewImage` fallback BLOCKED (asset) |
| photo, avatar, caption | as Structure | a11y `widget.home.small.a11y.*` as the root `contentDescription` | — |
| tap | `camera.fromwidget.layout.target` (PendingIntent) | — | opens `camera.capture`, group preselected |
| configure activity | Material 3 list (`color.global.system.*`, `layout.global.system.typography`) — a system surface | title `widget.home.small.configuration.title`; empty `widget.android.configure.empty` | lists the member's groups; choosing one finishes with RESULT_OK |

## States

| state | design | copy |
|---|---|---|
| loading | `widget.home.small` placeholder (gradient + up to 3 avatars, values in dp) | — |
| empty | `widget.home.small.layout.empty` (md; sm / lg variants per size — rule not observed), gradient `widget.home.small.color.emptyTop/Bottom`, circle, ring, `icon.global.gallery` glyph 32 × 28 dp, label 19 sp | `widget.home.small.empty.noPhotos`; label color BLOCKED |
| not set up / signed out / group gone | same layout | `widget.home.small.empty.setUp` (tap → configure activity) |
| error / offline | keep the last image | — |
| refresh in progress (foreground job) | `widget.arrival` notification | `widget.arrival.android.*` |

## Motion

None — Glance replaces the RemoteViews (`widget.arrival.duration.transition`).

## Haptics

None.

## Accessibility

Root `contentDescription` = `widget.home.small.a11y.photoWithCaption` / `.photo` / `.collage` / the empty text;
touch target is the whole widget (≥ 48 × 48 dp). Text in sp follows the font scale. Contrast as `widget.home.small`.

## Data & actions

`WidgetUpdateWorker` downloads `media.widget_path` / `collages.widget_path` (signed URL) into app storage and calls
`GlanceAppWidget.updateAll`; triggered by FCM (`widget` data message) or the periodic safety net. Out: `camera.fromwidget`.

## Platform notes

- **Lock-screen hub** (Android 16 QPR2 on Pixel phones, tablets, OEMs): every widget is eligible by default and shown
  at about 4×3 cells — the group photo would then show on the lock screen. Opting out (`widgetCategory not_keyguard`,
  API 36, `res/xml-v36`) is an **owner decision**; activities launched from it require unlock (default).
- No accessory (circular / rectangular / inline) widgets exist on Android phones; `widget.lock.*` is iOS only.
- Glance: capsule via `cornerRadius(height/2)` on Android 12+, a 9-patch / shape drawable before; no blur available.
- Font: system (Roboto); Locket's Proxima Soft is proprietary (do not ship).

## Do-not-copy

`locket_missed_moments_badge` (count), `locket_streak_frame` / 'Streak on widget', Gold widget frames
(`locket_frame_view`), weather / music / location caption variants (not features), `ic_widget_preview_static` art.

## Gaps

| item | status | capture |
|---|---|---|
| empty label color | BLOCKED (`widget.home.small.color.emptyLabel`) | screenshot of an empty Locket Android widget |
| static `previewImage` asset | BLOCKED (needs an owner-approved image; Locket's is do-not-copy) | owner asset |
| sm / md / lg empty-variant thresholds | not observed | empty Locket widget at 2×2 and 4×4 |
| Locket's Android caption text size (bitmap) | iOS 12 pt measurement used | one Android screenshot of a captioned Locket widget |
