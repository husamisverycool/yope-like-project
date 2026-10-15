# `settings.notifications` — per-group mute, quiet hours

Reference: **Apple HIG / Material 3** (system surface). Research: `design/research/platform.md` §settings, §daily.liveactivity,
§Haptics; `docs/PLATFORM_CONSTRAINTS.md` §2 (Live Activity off switch), §4.6 (channels); `docs/SPEC_FLAGS.md` T6;
`docs/WIDGET_REFRESH.md` (mute and quiet-hours behaviour). Android channel names and descriptions are owned by the
`notifications.push` pass (`notifications.push.channel.*`, `design/copy/capture.json`) and only referenced here. Tokens: `settings.root.layout.list`, `settings.root.layout.toggleHaptic`. Copy: `settings.notifications.*`.

## References

| id | file / URL | used for |
|---|---|---|
| HIG-L / M3-L | list guidance (as `settings.root`) | container |
| HIG-LA | https://developer.apple.com/design/human-interface-guidelines/live-activities | "offer an in-app control to turn the invitation Live Activity off" |
| WR | `docs/WIDGET_REFRESH.md` | quiet hours = silent delivery; muted groups still update widgets |

## Structure (`settings.root.layout.list`; title `settings.notifications.title`)

1. **System off** (only when the OS authorization is denied/not determined): footer-only section
   `settings.notifications.off.footer` + row `settings.notifications.openSettings`.
2. **Groups** (header `settings.notifications.groups.header`): one Toggle row per group, label = group name, on = not muted;
   footer `settings.notifications.groups.footer`.
3. **Quiet hours**: Toggle `settings.notifications.quietHours`; when on, rows `settings.notifications.quietHours.start`
   and `.end` with native time pickers (iOS compact `DatePicker(.hourAndMinute)`; Android M3 `TimePicker` dialog);
   footer `settings.notifications.quietHours.footer`.
4. **Live Activity** (iOS only): Toggle `settings.notifications.liveActivity`; footer `settings.notifications.liveActivity.footer`.
5. **Android only**: row `settings.notifications.categories` → system channel settings.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| list | `settings.root.layout.list` and its Android sizes; system colours | headers / footers | — |
| group toggles | system Toggle / Switch; `settings.root.layout.toggleHaptic` | group names (data); `settings.notifications.groups.footer` | `set_group_muted(p_group_id, !isOn)`; optimistic |
| quiet hours | Toggle + two time rows | `settings.notifications.quietHours*` | `set_quiet_hours(p_start, p_end, p_time_zone: device zone)`; off → both null |
| Live Activity toggle | Toggle | `settings.notifications.liveActivity`, `.footer` | device-local preference read by the push-to-start registration (when off, the push-to-start token is not registered: `register_device(… p_push_to_start_token: null)`) |
| open settings | system row | `settings.notifications.openSettings` | iOS `UIApplication.openNotificationSettingsURLString`; Android `ACTION_APP_NOTIFICATION_SETTINGS` |
| Android channels | system channel UI | `notifications.push.channel.<id>.name` / `.description` (capture pass) for `dailyInvitation`, `newPost`, `reactionsReplies`, `recap`, `birthdayRequest`, `tribute`; `yearStory` has no string yet (see Gaps) | registered by `NotificationChannels.register` |

## States

| state | design | copy |
|---|---|---|
| loading | native progress until `group_members` and `notification_settings` load | — |
| default | as Structure | — |
| permission-denied (system notifications off) | section 1 shown; toggles stay usable (they apply when notifications return) | `settings.notifications.off.footer`, `.openSettings` |
| error (save) | the toggle reverts; section footer shows | `settings.notifications.error` |
| offline | toggles disabled, cached values shown | — |
| empty (no groups) | Groups section hidden | — |

## Motion · Haptics

Native. Toggles `settings.root.layout.toggleHaptic`.

## Accessibility

System semantics; each toggle is labelled by its row text; time rows read "Start, 10:00 PM". Dynamic Type: system styles.

## Data & actions

- Reads: `group_members.muted` (own rows) + `groups.name`; `notification_settings` (own row; none = no quiet hours).
- Writes: `set_group_muted`, `set_quiet_hours` (errors `invalid_quiet_hours`, `invalid_time_zone`), `register_device`.
- In: `settings.root`; `groups.settings` "quiet hours". Out: system settings.

## Platform notes

- Android channel importance is fixed at creation (daily invitation HIGH, others DEFAULT — `android/core/push` `AppChannel`);
  names ≤ 40 characters, descriptions ≤ 300 (all strings comply).
- No "reminder" channel exists (tenet 5).

## Do-not-copy

Locket's "Daily Reminders" channel ("Reminders to share a Locket with your friends"); badge counts.

## Gaps

| item | status |
|---|---|
| Android channel for year stories (`AppChannel.YearStory`) | no `notifications.push.channel.yearStory.*` string exists; owned by the `notifications.push` pass (MERGE account A-12) |
