# `settings.root` — Settings

Visual reference: Retro **Settings sheet** (inventory #28, VID-SET frames 42–44): centred "Settings" with a close circle,
a profile card in a Fill group, small grey section headers (Subscription, Notifications, Widgets …), grouped Fill rows
with grey subtitles and chevrons; Retro's section list from APK-S (`settings_section_header_*`, `settings_title_*`).
Native switches / alerts: Apple HIG / Material 3 (PLATFORM). Tokens: `settings.root.*` + `global.*`. Copy: `settings.root.*`.

## References

| id | file | used for |
|---|---|---|
| VID-SET | `references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png` (640 × 800 frames, layout only) | sheet header, profile card (name, grey line, avatar right), section headers, rows "Your Subscription / Lifetime · Free", "Notification Settings", Widgets section |
| TC-J5 | `references/auto/retro/press/tc-2024-04-retro-journals-5.png` | grouped row height `settings.root.size.rowHeight` (58.7) |
| ST-02 | `references/auto/retro/store/retro-store-02.png` | profile header pattern (C-19: name, grey real name, 64 avatar right) for the profile card |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | section headers and row titles (`settings_section_header_*`, `settings_title_*`, `settings_description_retro_membership_*`, `settings_page_denied`, `widget_add`) |
| APK-X | `references/auto/retro/apk/retro-android-2026.10.1150-excerpts.txt` 'Retro root theme', 'Retro palette', 'Retro semantic colour accessor' | the Android true-black dark scheme (`colorScheme = isDark ? (trueBlack ? d42.w : d42.v) : d42.u`; only the page `vv3.k` and M3 background / surface change) — owner decision 21 |
| AP-S | https://raw.githubusercontent.com/AntennaPod/AntennaPod/develop/ui/i18n/src/main/res/values/strings.xml, `…/ui/preferences/src/main/res/xml/preferences_user_interface.xml` | the option's mechanics and words (a switch "Full black" / "Use full black for the dark theme" in its theming section): Retro's package names the scheme in no string (MERGE OD21-1) |
| MA-S | https://raw.githubusercontent.com/mastodon/mastodon-android/master/mastodon/src/main/res/values/strings.xml `settings_theme` | section header "Appearance" |

## Structure (page sheet, C-29; `settings.root.layout.list`; scrolls)

Header: centred `settings.root.title` (`sheetTitle`) + trailing close circle (C-11 on the page,
`settings.root.close.accessibilityLabel`).

1. **Profile card** (C-14 single row, C-19 content): display name (`listTitle`), phone number under it (`listSubtitle`,
   `color.global.textSecondary`), avatar `size.global.avatarProfile` (64) at the trailing edge (C-23 fallback when none);
   whole card → `settings.account` (`settings.root.account` as its label).
2. **Subscription** (`settings.root.subscription.header`): non-subscriber — row `settings.root.premium.title` with subtitle
   `settings.root.premium.subtitle` + chevron → `paywall`; subscriber — row `settings.root.manageSubscription` with
   subtitle `settings.root.premium.annual` / `.monthly` + chevron → `settings.account.layout.manageSubscription`.
3. **Notifications** (`settings.root.notifications.header`): row `settings.root.notifications` + chevron → `settings.notifications`.
4. **Widgets** (`settings.root.widgets.header`): row `settings.root.widgets.add` with subtitle `settings.root.widgets.detail`
   + chevron → `onboarding.widget` (which shows the widget preview). Retro shows a carousel of its three widget kinds
   here; this app has one kind, so the section is one row (Gaps).
4a. **Appearance — Android only** (`settings.root.appearance.header`; owner decision 21): one C-14 toggle row
   `settings.root.trueBlack` ("True Black") with subtitle `settings.root.trueBlack.detail` ("Use true black for the dark
   theme.") and the native M3 switch (C-29; the whole row toggles, `haptic.global.select`). On: the **dark** appearance
   draws its page in `color.global.background.android.trueBlack` (#000000) and M3 surface / background in
   `color.global.system.surface.trueBlack` (#000000) — Retro's true-black scheme `d42.w`; every other colour (rows and
   controls #262626, text, separators) and the light appearance stay as they are. Off (default): Retro's default dark page
   #1C1C1E. Kept on the device (app-private SharedPreferences, as the app's other device settings); the window, the bar
   scrims and every open screen follow at once. iOS has no such row (its dark page is already #000000, Retro's iOS).
   The row is always listed (light too): the switch names the dark theme (as AntennaPod's "Full black").
5. **Privacy** (`settings.root.privacy.header`): row `settings.root.blocked` + chevron → `settings.blocked`; row
   `settings.root.hiddenMemories` ("Hidden Memories") + chevron → `settings.hidden` (owner decision 34, research #12).
6. **System Permissions** (`settings.root.permissions.header`): rows `settings.root.permissions.camera`, `.photos` (iOS),
   `.microphone`, `.contacts`, `.notifications`; trailing value `settings.root.permissions.denied` (`listSubtitle`,
   `color.global.textSecondary`) when denied, else none; chevron; each row → the app's page in system Settings.
7. **About** (`settings.root.about.header`): rows `settings.root.contact` (mailto: `config/app.json` `support.email`; iOS
   disabled, Android left out, until the owner sets it),
   `settings.root.privacy`, `settings.root.terms` (in-app browser), `settings.root.version` (trailing value = version,
   no chevron, not tappable).
8. Last group (no header): row `settings.root.signOut` (text `color.global.textPrimary`).

Sections follow `settings.root.layout.list` (C-14; rows ≥ `settings.root.size.rowHeight`; sections `size.global.sectionGap` apart).

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| header | C-29 + C-11 | `settings.root.title`, `settings.root.close.accessibilityLabel` | close the sheet |
| profile card | C-14 + C-19 content (`listTitle`, `listSubtitle`, `size.global.avatarProfile`) | name / phone (data), `settings.root.account` | → `settings.account` |
| section header | C-14 header (`meta`, `color.global.textSecondary`) | `settings.root.*.header` | header trait |
| navigation row | C-14 row (`body` title, `meta` subtitle, `icon.global.chevron` in `color.global.textSecondary`) | row keys above | push inside the sheet |
| permission row | C-14 row + value | `settings.root.permissions.*`, `.denied` | opens system Settings |
| True Black row (Android) | C-14 row + native switch; `color.global.background.android.trueBlack`, `color.global.system.surface.trueBlack` | `settings.root.appearance.header`, `settings.root.trueBlack`, `.trueBlack.detail` | toggles; the theme follows at once (dark appearance only) |
| Sign Out | C-14 row | `settings.root.signOut`; alert `settings.root.signOut.title`, `.signOut.confirm`, `settings.root.alert.cancel` | `unregister_device` → `auth.signOut()` → `auth.phone` landing |

## States

| state | when | design | copy |
|---|---|---|---|
| default | — | as Structure | — |
| subscription loading | entitlements / store not answered yet | Subscription row shows the platform activity indicator as its trailing value (C-28) | — |
| subscriber / not | `entitlements` (docs/API.md §5.22) | row 2 variant | as above |
| permission states | system status | "Denied" value or none | `settings.root.permissions.denied` |
| True Black on / off (Android) | device setting | switch on / off; in dark the page is #000000 / #1C1C1E | — |
| signing out | RPCs in flight | Sign Out row shows the activity indicator | — |
| sign-out failed (offline) | `unregister_device` failed | sign out locally anyway (the token is cleared on the next registration) | — |
| empty / error / permission-denied | — | not applicable at the root | — |

## Motion

Sheet presentation: native, Retro's measured curve (`spring.global.sheetPresent`, settled `duration.global.sheetPresent`
567 ms; the presenting screen scales back on iOS). Pushes inside the sheet: native. Reduce Motion: platform.

## Haptics

Row presses → `haptic.global.tap` (Android). The True Black switch (Android) → `haptic.global.select`. Sign-out confirmed → none (navigation is the feedback).

## Accessibility

- Rows are buttons (title + subtitle + value); the version row is static text; section headers are headers.
- Dynamic Type: rows `subheadline` / `footnote`; rows grow; the avatar keeps 64.
- Focus order: close → title → profile card → sections top to bottom.
- Contrast: as `groups.settings` (rows 9, 11, 12, 13, 14 of `design/CONTRAST.md`); chevron `textSecondary` on group
  **2.52:1 FAIL** light (non-text 3:1 needed; dark 5.31:1); section headers on page **2.85:1 FAIL** light (row 3).

## Data & actions

- `profiles` (own name, avatar), `auth.user.phone`, `entitlements` (own rows), RevenueCat customer info.
- Permission status: `AVCaptureDevice.authorizationStatus`, `PHPhotoLibrary.authorizationStatus(for: .addOnly)`,
  `AVAudioApplication.recordPermission`, `CNContactStore.authorizationStatus`, `UNUserNotificationCenter.notificationSettings`
  / Android `ContextCompat.checkSelfPermission` + `NotificationManagerCompat.areNotificationsEnabled`.
- Sign out: `unregister_device(p_push_token)` then `auth.signOut()` (docs/API.md §2).
- In: `walls.mine` (settings capsule, C-19). Out: `settings.account`, `settings.notifications`, `settings.blocked`, `settings.hidden`,
  `paywall`, `onboarding.widget`, system Settings, legal pages, `auth.phone` (after sign-out).

## Platform notes

- iOS: one `.sheet` with its own `NavigationStack`; legal pages in `SFSafariViewController`.
- Android: `ModalBottomSheet` (expanded) or a full-screen destination with an inner nav host; Custom Tabs for legal pages;
  rows `color.global.surfaceSecondary.android`.

## Do-not-copy

- Retro's referral rows ("Your Referrals", "Refer N friends…"), Postcards, "Follow Retro" socials, "Lock My Friend Requests",
  "Neighborhood Captions", membership expiry countdowns ("Expiring in N days"), "Upgrade" upsell badges.

## Gaps

| item | status | smallest capture |
|---|---|---|
| Settings at full resolution | video frames only | raw screenshots of Retro's Settings (top + scrolled), light and dark (RV §6) |
| Widgets carousel | one widget kind here → one row with a preview | — |
| support e-mail (`support.email`), legal URLs | owner (`config/app.json`; docs/OWNER_SETUP.md §8) | — |
