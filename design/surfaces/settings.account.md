# `settings.account` — profile fields, delete account

Visual reference: Retro **Account** section and **Edit Profile** page (inventory #28; APK-S `settings_section_header_account`,
`edit_profile_row_title_fullname`, `edit_full_name_screen_title`, `edit_profile_picture_*`, `settings_title_delete_account`,
`delete_account_page_*`). Alerts, pickers and the subscription sheet are native (PLATFORM). Tokens:
`settings.account.layout.*`, `settings.root.size.rowHeight`, `settings.root.layout.list` + `global.*`. Copy: `settings.account.*`.

## References

| id | file | used for |
|---|---|---|
| VID-SET | `references/auto/retro/video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png` | grouped rows |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | row titles, photo choice sheet, "Name too long", delete copy, "Yes, delete" |
| TC-J5 | `references/auto/retro/press/tc-2024-04-retro-journals-5.png` | red destructive row (C-10), row height |

## Structure (pushed inside the Settings sheet; native back + centred `settings.account.title`)

1. Group 1 (no header): avatar row — `size.global.avatarProfile` circle leading (C-23), title `settings.account.photo`
   + chevron → native action sheet `settings.account.photo.sheetTitle` with `settings.account.photo.library`,
   `.photo.camera`, `.photo.remove` (destructive, only with a photo), Cancel; row `settings.account.name` with the name as
   trailing value + chevron → **Edit Full Name** page; row `settings.account.phone` with the number as value (read-only,
   no chevron); row `settings.account.birthday` with the date or nothing + chevron → `birthday.add`.
2. Group 2 (no header): row `settings.account.delete` in `color.global.destructive` (C-10); footer
   `settings.account.delete.footer`.

**Edit Full Name** (pushed): native back + centred `settings.account.name.title`; C-12 field (prefilled) at
`size.global.titleToContent` under the bar; inline `settings.account.name.tooLong` when needed; C-05
`settings.account.name.save` pinned above the keyboard.

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| photo row | C-14 + C-23 64 | `settings.account.photo`; sheet `settings.account.photo.*` | library → `PhotosPicker` / `PickVisualMedia`; camera → system camera (`UIImagePickerController(.camera)` / `ActivityResultContracts.TakePicture`), asks camera permission; remove → clears `avatar_path` |
| name row / page | C-14; C-12 + C-05 | `settings.account.name`, `.name.title`, `.name.save`, `.name.tooLong`, `.name.error` | `update profiles set display_name` |
| phone row | C-14 value | `settings.account.phone` | none (no change-number flow) |
| birthday row | C-14 value | `settings.account.birthday` | → `birthday.add` (memory group) |
| Delete Account | C-14 row, C-10 | `settings.account.delete`, `.delete.footer`; alert `.delete.title`, `.delete.message` (+ `.delete.subscriptionNote` when subscribed), `.delete.confirm`, `settings.account.alert.cancel` | `delete_account()` → sign out → `auth.phone` landing; Android Toast `settings.account.deleted.toast` |
| Your Subscription | — | — | `settings.account.layout.manageSubscription` (opened from `settings.root`) |

## States

| state | design | copy |
|---|---|---|
| default | as Structure | — |
| saving (name / photo) | capsule busy (C-05) / avatar shows the platform indicator over it | — |
| save failed / offline | message-only alert | `settings.account.name.error` + `auth.phone.error.dismiss` |
| deleting | the alert closes; the Delete row shows the activity indicator; the sheet is not dismissible | — |
| delete failed | message-only alert | `settings.account.delete.error` |
| empty / permission-denied | camera denied from the photo sheet → `onboarding.permission.camera` denied copy in an alert | `onboarding.permission.camera.denied.*` |

## Motion

Native pushes, action sheet and alerts (system). Photo change: cross-fade `duration.global.crossfade`. Reduce Motion: platform.

## Haptics

Presses → `haptic.global.tap` (Android). Delete confirmed → `haptic.global.warning`. Saved → `haptic.global.success`;
failed → `haptic.global.error`.

## Accessibility

- Rows: buttons with title + value; the phone row is static text. Destructive alert button role `.destructive`.
- Dynamic Type: rows `subheadline`; footer `footnote`; field `body`.
- Contrast: as `groups.settings` (rows 9, 11–14); red row **3.70:1 / 3.62:1 FAIL** (row 32); footer on page **2.85:1 FAIL** light.

## Data & actions

- `profiles` (name, avatar), `auth.user.phone`, `profile_private` (birthday, docs/API.md §5.2).
- `update profiles` (§5.0); avatar upload `avatars/<uid>/<uuid>.jpg` (§7); `delete_account()` then `auth.signOut()` (§6.3).
- In: `settings.root` (profile card). Out: `birthday.add`, `auth.phone` (after deletion).

## Platform notes

- iOS: action sheet = `confirmationDialog`; alert = `settings.account.layout.alert`.
- Android: M3 `ModalBottomSheet` list for the photo choices; `AlertDialog`.

## Do-not-copy

- Retro's delete page that makes the person type their username, and its "WARNING:" capitals; username / homebase rows.

## Gaps

| item | status | smallest capture |
|---|---|---|
| Retro's Edit Profile page as an image | strings only | screenshot of Retro's Edit Profile (light + dark) |
| account deletion completion statement | owner (legal) | — |
