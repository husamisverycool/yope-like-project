# Verification — `settings.root` (iOS)

Settings list — `Features/Account/Settings/SettingsRootScreen.swift`.

Checklist written from the spec (`design/surfaces/settings.root.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/settings.root.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Reference image(s): `references/auto/locket/lazyweb/locket-lazyweb-20260803-autocap-21.png`

Snapshots (CI): `settings.root-default.png`, `settings.root-premium.png`

**Summary: 16 matched · 0 approximated · 2 not matched (BLOCKED or not buildable) · 11 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | token | `settings.account.layout.manageSubscription` | ios: AppStore.showManageSubscriptions(in:) (manageSubscriptionsSheet); android: open https://play.google.com/store/account/subscriptions?sku={productId}&pack… (VERIFIED) | 'Manage Subscription' destination | .manageSubscriptionsSheet(isPresented:) |
| matched | token | `settings.root.layout.list` | ios: List with .listStyle(.insetGrouped); Section(header:footer:); NavigationLink rows show the system disclosure indicator; colours color.global.system.ios;… (PLATFORM) | settings list container (also settings.notifications, settings.account, settings.blocked, groups.settings) | List with .insetGrouped style, system rows |
| matched | copy | `settings.root.title` | “Settings” (VERIFIED) |  | `Copy.…settingsRootTitle` in SettingsRootScreen.swift |
| not matched | copy | `settings.root.premium.title` | “{app_name} Premium” (SOURCED) |  | uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (AccountBlockedCopy.swift); omitted in release |
| not matched | copy | `settings.root.premium.subtitle` | “Unlock the best of {app_name}” (SOURCED) |  | uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (AccountBlockedCopy.swift); omitted in release |
| matched | token | `paywall.layout.promptRule` | settingsEntry: always opens (navigation the person chose; not counted); lockedFeature: the first tap on a locked perk per session opens the paywall (SessionP… (SOURCED) | when the paywall may appear | settings entry always opens; `AppRouter.presentPaywallForLockedFeature` uses `SessionPromptGate` (once per session, never during capture / onboarding) and leaves the camera tab first |
| matched | copy | `settings.root.manageSubscription` | “Manage Subscription” (VERIFIED) |  | `Copy.…settingsRootManageSubscription` in SettingsRootScreen.swift |
| matched | copy | `settings.root.notifications` | “Notifications” (VERIFIED) |  | `Copy.…settingsRootNotifications` in SettingsRootScreen.swift |
| matched | copy | `settings.root.account` | “Account” (VERIFIED) |  | `Copy.…settingsRootAccount` in SettingsRootScreen.swift |
| matched | copy | `settings.root.blocked` | “Blocked People” (VERIFIED) |  | `Copy.…settingsRootBlocked` in SettingsRootScreen.swift |
| matched | copy | `settings.root.privacy` | “Privacy Policy” (VERIFIED) |  | `Copy.…settingsRootPrivacy` in SettingsRootScreen.swift |
| matched | copy | `settings.root.terms` | “Terms of Use” (VERIFIED) |  | `Copy.…settingsRootTerms` in SettingsRootScreen.swift |
| matched | copy | `settings.root.contact` | “Contact Us” (VERIFIED) |  | `Copy.…settingsRootContact` in SettingsRootScreen.swift |
| matched | copy | `settings.root.signOut` | “Sign Out” (VERIFIED) |  | `Copy.…settingsRootSignOut` in SettingsRootScreen.swift |
| matched | token | `color.global.system.ios` | groupedBackground: systemGroupedBackground; cell: secondarySystemGroupedBackground; label: label; secondaryLabel: secondaryLabel; placeholder: placeholderTex… (PLATFORM) | semantic colors of native inset-grouped lists, alerts and sheets on system surfaces (settings.*, safety.*, … | system list colours, no overrides |
| n/a | token | `color.global.system.surface` | #141218 (PLATFORM) | page / list container on Android system surfaces (role md.sys.color.surface, baseline dark scheme) | Android only |
| n/a | token | `color.global.system.onSurface` | #E6E0E9 (PLATFORM) | list item label, dialog headline (role md.sys.color.on-surface, baseline dark scheme) | Android only |
| n/a | token | `color.global.system.onSurfaceVariant` | #CAC4D0 (PLATFORM) | supporting text, leading icons, drag handle (role md.sys.color.on-surface-variant, baseline dark scheme) | Android only |
| n/a | token | `color.global.system.outline` | #938F99 (PLATFORM) | list divider (1 dp) (role md.sys.color.outline, baseline dark scheme) | Android only |
| n/a | token | `settings.root.size.listItemOneLine.android` | 56 dp (VERIFIED) | M3 one-line list item height | Android only |
| n/a | token | `settings.root.size.listItemTwoLine.android` | 72 dp (VERIFIED) | M3 two-line list item height | Android only |
| n/a | token | `settings.root.size.listItemPaddingH.android` | 16 dp (VERIFIED) | M3 list item leading and trailing space | Android only |
| n/a | token | `settings.root.size.listItemPaddingV.android` | 10 dp (VERIFIED) | M3 list item top and bottom space | Android only |
| n/a | token | `settings.root.size.divider.android` | 1 dp (VERIFIED) | M3 list divider thickness | Android only |
| matched | token | `layout.global.system.typography` | ios: built-in text styles (Font.TextStyle) on native lists, alerts and sheets; android: MaterialTheme.typography (M3 baseline type scale: list label bodyLarg… (PLATFORM) | text styles on system surfaces | system text styles (no custom font on system surfaces) |
| matched | token | `size.global.headerButton` | 44 pt (SOURCED) | circle icon buttons in headers (back, close, download, film-strip, search) | `Tokens.…globalHeaderButton` in HeaderCircleButton.swift |
| matched | token | `color.global.controlOnDeep` | #101010 (SOURCED) | header circle icon buttons on black screens and sheets (✕, download) | `Tokens.…globalControlOnDeep` in HeaderCircleButton.swift |
| n/a | token | `icon.global.settings` | ios: gearshape; android: Rounded.Settings (PLATFORM) | settings entry | the settings circle lives on walls.mine (social pass) |
| n/a | copy | `walls.mine.a11y.settings` | “settings” (SOURCED) |  | the settings circle lives on walls.mine (social pass) |

## Not matched

- `settings.root.premium.title` — uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (AccountBlockedCopy.swift); omitted in release
- `settings.root.premium.subtitle` — uses {app_name}: DEBUG builds only via `AccountBlockedCopy` (AccountBlockedCopy.swift); omitted in release
