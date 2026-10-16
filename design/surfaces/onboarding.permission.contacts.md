# `onboarding.permission.contacts` — optional contacts

Visual reference: Retro's contacts upsell ("No Contacts Access" / "Connect your phone contacts to find friends to invite
here. We will never spam your contacts." / "Connect Contacts", APK-S `contact_permission_upsell_*`) drawn as the C-27
permission-denied variant inside the invite sheet. Mechanics: Apple HIG / Material 3 (contacts are optional; on iOS
the system's own controls). Composition: `level: SOURCED`, `method: "composition of Retro components C-27, C-12,
C-16, C-06 inside groups.invite, in the platform's contacts flow"`. Tokens: `groups.invite.layout.contacts`. Copy:
`onboarding.permission.contacts.*`, `system.permissions.contacts.purpose`, `system.permissions.rationale.contacts.*`.

Contacts are offered **only inside `groups.invite`** ("Contacts" section); there is no onboarding page (an iOS
pre-alert that can be dismissed is non-compliant — HIG; PLATFORM_CONSTRAINTS Summary). Nothing requires contacts.

## References

| id | file / URL | used for |
|---|---|---|
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `contact_permission_upsell_*`, `search_bar_default_placeholder`, `friend_tab_contact_invite_cta`, `friend_tab_contact_invited_label`, `invites_no_contacts_empty_message` |
| TC-1B | `references/auto/retro/press/tc-2023-07-retro-1b.webp` | people rows with capsule actions (C-16) |
| PC | docs/PLATFORM_CONSTRAINTS.md Summary + §6 | compliant contacts paths per platform |

## Structure (inside `groups.invite` → section "Contacts")

- **iOS 18+**: search field C-12 (placeholder `onboarding.permission.contacts.search.placeholder`) and the system
  `ContactAccessButton(queryString:)` under it; contacts the person grants appear as people rows (C-16).
- **iOS 17.2–17.x**: outline capsule C-06 `onboarding.permission.contacts.choose` → `CNContactPickerViewController`
  (no permission; one contact at a time).
- **Android, `READ_CONTACTS` not granted**: the C-27 block, left-aligned inside the section (glyph `icon.global.group`,
  title `onboarding.permission.contacts.card.title`, explanation `.card.detail`, outline capsule C-06 `.card.button`).
  The block is part of the scrolling sheet, so the person can ignore it (no dismiss control needed).
- **Android, targetSdk ≥ 37 on API 37+**: the system Contact Picker (`Intent.ACTION_PICK_CONTACTS`) replaces the block.

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| permission block (Android) | C-27: `size.global.emptyIcon`, `.emptyIconToTitle`, `.emptyTitleToAction`, text roles `emptyTitle` / `emptyDetail`, `color.global.textPrimary` / `.textSecondary`, C-06 outline capsule | `onboarding.permission.contacts.card.title`, `.card.detail`, `.card.button` | Connect Contacts → runtime request (rationale first when `shouldShowRequestPermissionRationale`) |
| Android rationale | C-29 dialog | `system.permissions.rationale.contacts.title`, `.message`, `system.permissions.rationale.notNow`, `.continue` | — |
| iOS 17 button | C-06 outline capsule | `onboarding.permission.contacts.choose` | contact picker |
| iOS 18 search | C-12 | `onboarding.permission.contacts.search.placeholder` | feeds `ContactAccessButton` |

## States

| state | design | copy |
|---|---|---|
| not asked (Android) | block | block strings |
| granted (Android) / chosen (iOS) | people rows in `groups.invite` | `groups.invite.contacts.*` |
| denied (permission-denied) | Android: the block stays; after two denials Connect Contacts opens Settings; iOS 18: the system button explains itself | block strings / `system.permissions.openSettings` |
| no contacts with a number | `groups.invite.contacts.empty` line | — |
| loading / error / offline | covered by `groups.invite` | — |

## Motion · Haptics

System pickers and dialogs; rows appear with `duration.global.fade`. Capsule press → `haptic.global.tap` (Android).

## Accessibility

- Block: glyph decorative; title header; capsule labelled. Dynamic Type: title `title3`, explanation `subheadline`.
- Contrast (sheet page): title 21:1 (rows 1 / 2); explanation `textSecondary` light **2.85:1 FAIL** (row 3), dark 7.37:1;
  outline capsule border 21:1 (row 20).

## Data & actions

- No contacts API on the backend (no matching RPC yet); inviting sends the link by SMS compose (`groups.invite`).
- `NSContactsUsageDescription` (`system.permissions.contacts.purpose`) for `ContactAccessButton` limited access.

## Platform notes

- App Review 5.1.2(v): no "Select All", nothing pre-selected; the person sees the message before it is sent.
- Play Contact Permissions policy: apps targeting Android 17+ use the picker unless they declare a use (from 2027-01-27).

## Do-not-copy

- Forced invites, invite counts, "N friends joined", referral rewards (Retro's invite counters).

## Gaps

| item | status | smallest capture |
|---|---|---|
| Retro's "No Contacts Access" screen as an image | strings only | screenshot of Retro's contacts upsell (RV §6) |
