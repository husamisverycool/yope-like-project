# `onboarding.permission.contacts` — optional contacts

Reference: **Yope** (skippable), under the platform rules. Research: `design/research/yope-a.md` §2.8;
`design/research/platform.md` §system.permissions; `docs/PLATFORM_CONSTRAINTS.md` Summary + §6. Tokens:
`onboarding.permission.contacts.*`, `groups.invite.layout.contacts`. Copy: `onboarding.permission.contacts.*`,
`system.permissions.contacts.purpose`, `system.permissions.rationale.contacts.*`.

Yope asks for contacts with a **dismissible inline card** on the home list ("can’t see your friends?" / "enable contacts" /
"enable" / ✕). On iOS a dismissible pre-alert view is non-compliant (HIG: one button, no way to leave without the system
alert) — so **on iOS there is no onboarding screen and no card**: contacts are offered inside `groups.invite` with the
system's own controls. **On Android the Yope card is kept** (Android requires a way to cancel), inside `groups.invite`.
Contacts stay optional everywhere; nothing requires them (Yope's forced invites are do-not-copy).

## References

| id | file | used for |
|---|---|---|
| CC | `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png` | card: #131313, 101 pt tall, 18 pt margins, card radius, title 17 bold (2 lines), detail 14 gray, white "enable" 91 × 37, ✕ |
| SF | `references/auto/yope/frames/a-virgi-7686278541255642390-t44.23-suggested-friends-es.png` | contact-derived suggestions "de tus contactos" (es) |
| PC | `docs/PLATFORM_CONSTRAINTS.md` Summary row "Skippable iOS pre-permission screens" | compliant alternative |

## Structure

**iOS** (`groups.invite.layout.contacts`), inside `groups.invite` → "from your contacts":
- iOS 18+: a search field (Yope form field, placeholder `onboarding.permission.contacts.search.placeholder`) and the
  system `ContactAccessButton(queryString:)` under it; contacts the person grants appear as rows (limited access).
- iOS 17.2–17.x: a white pill `onboarding.permission.contacts.choose` opens `CNContactPickerViewController` (no
  permission, one contact at a time).

**Android**, inside `groups.invite` → "from your contacts", when `READ_CONTACTS` is not granted — the inline card
(`onboarding.permission.contacts.layout.card`), left to right: text block (title, detail), white "enable" pill; ✕ at the
top-trailing corner. "enable" → runtime request (rationale first when `shouldShowRequestPermissionRationale`); ✕ hides the
card for this group screen session. When targeting API 37+, the Contact Picker (`Intent.ACTION_PICK_CONTACTS`) replaces
the card and the permission.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| card container | `onboarding.permission.contacts.color.card`, `.size.cardHeight`, `.size.cardMarginH`, `radius.global.card`, `.layout.card` | — | Android only |
| card title | `.fontSize.cardTitle`, `.fontWeight.cardTitle`, `color.global.textPrimary`, max 2 lines | `onboarding.permission.contacts.card.title.friends` / `.family` / `.roommates` / `.custom` (by `groups.kind`) | — |
| card detail | `.fontSize.cardDetail`, `color.global.textSecondary` | `onboarding.permission.contacts.card.detail` | — |
| enable pill | `.size.cardButtonWidth`, `.size.cardButtonHeight`, `color.global.surfaceLight`, `color.global.onSurfaceLight`, `radius.global.capsule`, text role `button` | `onboarding.permission.contacts.card.button` | runtime permission |
| dismiss ✕ | `icon.global.close`, `color.global.textPrimary`, hit area `size.global.minTouchTarget.android` | `onboarding.permission.contacts.card.dismissAccessibilityLabel` | hides the card |
| iOS 17 button | white pill: `color.global.surfaceLight`, `groups.screen.size.lightPillHeight`, `groups.screen.radius.lightPill` | `onboarding.permission.contacts.choose` | contact picker |
| iOS 18 search | Yope form field tokens | `onboarding.permission.contacts.search.placeholder` | feeds `ContactAccessButton` |
| Android rationale | `settings.account.layout.alert` (M3 dialog) | `system.permissions.rationale.contacts.title`, `.message`, `system.permissions.rationale.notNow`, `.continue` | — |

## States

| state | design | copy |
|---|---|---|
| not asked (Android) | card | card strings |
| granted (Android) / chosen (iOS) | contact rows in `groups.invite` | `groups.invite.contacts.*` |
| denied (permission-denied) | Android: card stays (after two denials "enable" opens Settings); iOS 18: the system button explains itself | card strings / `system.permissions.openSettings` |
| loading / empty / error / offline | covered by `groups.invite` | — |

## Motion · Haptics

None of our own (system pickers and dialogs). Card dismiss: removed without animation (no measured Yope motion).

## Accessibility

- Card: title + detail one element; pill a button; ✕ a button with its label (touch target ≥ 44 pt / 48 dp).
- Dynamic Type: title `headline`, detail `subheadline`, pill `subheadline`.
- Contrast: white on #131313 18.58:1, #969696 on #131313 6.28:1, pill 18.58:1 pass; card vs black 1.13:1 **FAIL** (non-text).

## Data & actions

- No API for contacts themselves. `ContactMatching.swift` (hash matching) has no backend RPC yet; until it exists, rows
  are local contacts only and inviting sends the link by SMS (`groups.invite`).
- Purpose string `system.permissions.contacts.purpose` (`NSContactsUsageDescription`) — needed for `ContactAccessButton`
  limited access; must mention matching if matching ships.

## Platform notes

- App Review 5.1.2(v): no "Select All", no contact pre-selected; the person sees the invite message before it is sent.
- Play Contact Permissions policy: apps targeting Android 17+ must use the picker unless they declare a use (from 2027-01-27).

## Do-not-copy

- The card's contacts-app-like illustration with a red "!" (resembles Apple's Contacts icon).
- Forcing a number of invites before using the app; "suggested friends" from public discovery.

## Gaps

| item | status | smallest capture |
|---|---|---|
| card inner insets | approximation (16 pt home-card inset) | one lossless screenshot of the Yope contacts card |
| Yope's contacts purpose string | not found (system purpose follows `platform.purposeString`) | one screenshot of Yope's iOS contacts alert |
