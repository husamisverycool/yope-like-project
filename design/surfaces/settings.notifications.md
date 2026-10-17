# `settings.notifications` — per-group mute, quiet hours

Visual reference: Retro **Notification Settings** (inventory #28 row → page; APK-S `notification_settings_page_title`,
section headers `notification_settings_section_header_*`, Title-Case rows, the off-permission upsell
`notification_settings_enable_permission_*`, "Pause All — Turn off all notifications for the day"). Switches and time
pickers native (PLATFORM). Tokens: `settings.root.size.rowHeight`, `settings.root.layout.*` + `global.*`.
Copy: `settings.notifications.*`.

## References

| id | file | used for |
|---|---|---|
| VID-SET | `references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png` | grouped rows, section headers |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `notification_settings_*`, `notification_setting_title_pause_all` / `_description_pause_all` |
| H43 | `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png` | C-27 / outline capsule in dark |

## Structure (pushed inside the Settings sheet; native back + centred `settings.notifications.title`; scrolls)

1. **Permission off** (only when the system permission is off): C-27 block at the top, left-aligned inside the margins,
   no glyph: title `settings.notifications.off.title` (`emptyTitle`), explanation `settings.notifications.off.footer`
   (`emptyDetail`, `color.global.textSecondary`), outline capsule C-06 `settings.notifications.openSettings` → system Settings.
   The rows below stay visible and editable (they apply once notifications are on).
2. **Groups** (`settings.notifications.groups.header`): one row per group: group cover in a 30 pt circle
   (`size.global.avatarComment`; no cover → C-23 fallback with `icon.global.group`), group name (`body`), trailing native
   switch (on = notifications on). Footer `settings.notifications.groups.footer`.
3. **Quiet Hours**: row `settings.notifications.quietHours` with a switch; when on, two rows `settings.notifications.quietHours.start`
   / `.end` with trailing time values (`listSubtitle`, `color.global.textSecondary`) → native time pickers. Footer
   `settings.notifications.quietHours.footer`.
4. iOS only: row `settings.notifications.liveActivity` with a switch; footer `settings.notifications.liveActivity.footer`.
5. Android only: row `settings.notifications.categories` + chevron → the app's notification channel settings.

All groups follow `settings.root.layout.list` (C-14, rows ≥ `settings.root.size.rowHeight`, sections `size.global.sectionGap` apart).

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| off block | C-27 (no glyph) + C-06 | `settings.notifications.off.title`, `.off.footer`, `.openSettings` | `UIApplication.openNotificationSettingsURLString` / `Settings.ACTION_APP_NOTIFICATION_SETTINGS`; iOS when the app has never asked (`.notDetermined`: Settings has no switch for the app yet) — the system alert (`requestAuthorization`) instead; the block follows the answer and the return from Settings |
| group row | C-14 + C-23 30 pt + native switch (`color.global.selection` / `color.global.system.primary`) | group name (data); section `settings.notifications.groups.header`, footer | `set_group_muted(group, !on)`; optimistic, reverts on error |
| quiet hours | C-14 rows + switch + native time pickers | `settings.notifications.quietHours`, `.start`, `.end`, `.footer` | `set_quiet_hours(p_start, p_end, p_time_zone)`; off = both null |
| Live Activity (iOS) | C-14 + switch | `settings.notifications.liveActivity`, `.footer` | local preference read by `daily.liveactivity` |
| categories (Android) | C-14 + chevron | `settings.notifications.categories` | `Settings.ACTION_APP_NOTIFICATION_SETTINGS` |

## States

| state | design | copy |
|---|---|---|
| loading | each group shows one row with the platform activity indicator (C-28) | — |
| permission off (permission-denied) | off block at the top | `settings.notifications.off.*` |
| no groups | Groups section hidden | — |
| change failed / offline | the control returns; message-only alert | `settings.notifications.error` + `auth.phone.error.dismiss` |
| empty / error (read) | the read uses cached `group_members.muted`; on failure the section shows the error alert on load | `settings.notifications.error` |

## Motion

Native push; quiet-hours rows expand / collapse with the platform list animation (iOS) / `AnimatedVisibility` default
(`spring.global.platformDefault.android`); off block fades `duration.global.fade`. Reduce Motion: cross-fade.

## Haptics

Switches: `settings.root.layout.toggleHaptic`. Presses → `haptic.global.tap` (Android). Failure → `haptic.global.error`.

## Accessibility

- Each switch row is one toggle (name + state); the off block's title is a header.
- Dynamic Type: rows `subheadline`; footers `footnote`; block title `title3`.
- Contrast: as `groups.settings` (rows 9, 11–14); switch tint on the group: system (iOS) / Retro blue raised to #0066CE / #2592FF (Android,
  owner decision 20: 4.52 / 4.54:1 as dialog text — design/CONTRAST.md).

## Data & actions

- `group_members.muted` (own rows) per group; `notification_settings` (own row, docs/API.md §5.21).
- Writes: `set_group_muted`, `set_quiet_hours` (§6.3).
- In: `settings.root`; `groups.settings` ("Quiet Hours" row). Out: system notification settings.

## Platform notes

- iOS: switches `Toggle`, times `DatePicker(.hourAndMinute)` (compact style in the row).
- Android: `Switch`, M3 `TimePicker` in a dialog; channels for categories (owned by `notifications.push.channel.*`).

## Do-not-copy

- Retro's per-type toggles for likes / comment likes / keys / friend requests (no such notifications here); "Pause All"
  for the day (no API); reminder cadence rows (the daily invitation is per group, in `groups.settings`).

## Gaps

| item | status | smallest capture |
|---|---|---|
| Retro's Notification Settings page as an image | strings only | screenshot of Retro's Notification Settings (light + dark) |
