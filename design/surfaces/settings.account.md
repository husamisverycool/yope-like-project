# `settings.account` — account, delete account

Reference: **Apple HIG / Material 3** (system surface). Research: `design/research/platform.md` §settings (delete account);
`docs/PLATFORM_CONSTRAINTS.md` §8, §9 (5.1.1(v), Apple deletion FAQ, Google Play in-app + web deletion).
Directive: deleting the account is **permanent** and deletes **all** the person's data. API: `docs/API.md` §2,
§6.3 `delete_account`. Tokens: `settings.account.*`, `settings.root.layout.list`. Copy: `settings.account.*`.

## References

| id | URL | used for |
|---|---|---|
| ADF | https://developer.apple.com/support/offering-account-deletion-in-your-app/ | easy to find; deletion (not deactivation); includes shared photos; re-auth allowed; say when it completes; subscription note |
| HIG-MA | https://developer.apple.com/design/human-interface-guidelines/managing-accounts#Deleting-accounts | alert, timing, billing continues until cancelled |
| HIG-A | https://developer.apple.com/design/human-interface-guidelines/alerts | destructive + Cancel, Cancel not default |
| M3-D | https://m3.material.io/components/dialogs/specs | dialog values |
| GP | https://support.google.com/googleplay/android-developer/answer/13327111 | in-app deletion + web link (store listing) |

## Structure (`settings.root.layout.list`; title `settings.account.title`)

1. Section: `settings.account.name` (value = display name; tap → inline `TextField` row, saved on submit),
   `settings.account.photo` (value = avatar thumbnail; tap → system photo picker, `auth.profile.layout.avatarPicker`),
   `settings.account.phone` (value = phone number, read-only), `settings.account.birthday` (→ `birthday.add`).
2. Section (only while premium is active): `settings.root.manageSubscription` → `settings.account.layout.manageSubscription`.
3. Section: `settings.account.delete` (destructive role, centred text on iOS); footer `settings.account.delete.footer`.

## Delete flow

1. Tap → alert / dialog (`settings.account.layout.alert`): title `settings.account.delete.title`; message
   `settings.account.delete.message` (+ `settings.account.delete.subscriptionNote` while premium is active); buttons
   `settings.account.alert.cancel` and `settings.account.delete.confirm` (destructive). While premium is active a third
   button `settings.root.manageSubscription` is offered on iOS (≤ 3 buttons); Android keeps 2 actions and shows the
   Manage Subscription row in section 2.
2. Confirm → HUD-free native progress on the row → `rpc("delete_account")` → `unregister_device` → `auth.signOut()` →
   `auth.phone` with the toast `settings.account.deleted.toast`.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| list | `settings.root.layout.list` + Android sizes | — | — |
| delete row | iOS `color.global.destructive` (role .destructive); Android `color.global.system.error` | `settings.account.delete`, `settings.account.delete.footer` | opens the alert |
| alert | `settings.account.layout.alert` (Android 28 dp corner, surfaceContainerHigh, headlineSmall/bodyMedium/labelLarge) | `settings.account.delete.*`, `settings.account.alert.cancel` | Cancel is never the default |

## States

| state | design | copy |
|---|---|---|
| default | as Structure | — |
| deleting | native progress indicator in the delete row; list disabled | — |
| error | alert with the error message + Cancel | `settings.account.delete.error` |
| name save error | section footer | `settings.account.name.error` |
| offline | delete row disabled with the footer kept; name/photo edits disabled | — |
| loading / empty / permission-denied | values load with the list; photo picker needs no permission | — |

## Motion · Haptics

Native alert/dialog motion. Confirmed deletion → `haptic.global.warning`; failure → `haptic.global.error`.

## Accessibility

System semantics; the delete row is announced by its text (destructive colour is not the only cue). Dynamic Type: system.

## Data & actions

- Reads: `profiles` (own), the session's phone, `entitlements` (own).
- Writes: `update profiles` (name, avatar path), avatar upload (§7), `delete_account()` (deletes media with full cascade,
  messages, reactions, tags, tribute data, memberships with admin hand-off, invites, devices, quiet hours, blocks,
  reports, entitlements, profile; files and the auth user by the worker).
- In: `settings.root`. Out: `birthday.add`, Manage Subscription, `auth.phone`.

## Platform notes

- Google Play also needs a **web** deletion link in the store listing / Data safety form (owner, not in-app).
- No deactivation option (Apple: insufficient).

## Report and block

Not applicable (own account).

## Gaps

| item | status |
|---|---|
| when deletion completes | the database part is immediate; file removal and the auth user are worker jobs (`storage.delete`, `auth.delete_user`) with retries up to ~1 h backoff — if the owner wants a stated time, add it to the message (Apple: "tell people when account deletion will complete") |
| tenet "Nothing gets lost" vs deleting shared photos | owner decision (PLATFORM_CONSTRAINTS §9); the copy states that shared photos are deleted |
| pre-deletion export / save prompt | allowed by Apple; not specified (owner) |
