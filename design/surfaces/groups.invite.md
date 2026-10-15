# `groups.invite` — invite by link or from contacts

Reference: **Yope** (2026 entry pill "invite more friends"; 2024 "Add friends to {group}" sheet). Research:
`design/research/yope-a.md` §2.11; platform: `docs/PLATFORM_CONSTRAINTS.md` Summary (contacts), §6;
`design/research/platform.md` §system.permissions (5.1.2(v)). API: `docs/API.md` §5.5, §6.1 (`create_invite`,
`revoke_invite`), §9.2. Tokens: `groups.invite.*`, `onboarding.permission.contacts.*`. Copy: `groups.invite.*`.

The 2026 sheet behind "invite more friends" was not filmed; the 2024 sheet is the only full reference (older than 12
months; its third-party app row is do-not-copy). The link itself is shared through the system share sheet, which Yope
uses on this surface ("Other app" → iOS share sheet → Copy).

## References

| id | file | used for |
|---|---|---|
| I24 | `references/auto/yope/frames/a-yrrah-7452976839846382855-t10.73-add-friends-share-link-2024.png` | title "Add friends to / {group}" (group name lime), "Share this group link to invite" label with glyph, share row → share sheet |
| E26 | `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t51.23-group-created-empty-state.png` | white pill with link glyph ("invite more friends"), 205 × 45, r 11 |
| M24 | `references/auto/yope/frames/a-yrrah-7434441926000037121-t33.73-group-menu-leave-report-2024.png` | "share invite" label |
| NG2 | `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t49.23-new-group-selected-create.png` | picker rows (avatar 40, bold name, 54.5 pt pitch) for contact rows |
| CC | `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png` | contacts card (Android), section label style ("suggested friends") |
| SF | `references/auto/yope/frames/a-virgi-7686278541255642390-t44.23-suggested-friends-es.png`, `-t52.23-request-pending-es.png` | add pill / pending state on contact rows (es) |

## Structure (sheet on black `color.global.backgroundDeep`, scrolls)

1. Header row: ✕ circle leading (`size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.close`).
2. Title, two lines, centred: line 1 "add {members} to", line 2 the group name in lime (`groups.create.layout.titleAccent`).
3. Gap `groups.create.size.titleToContent`.
4. **Link section**: label `groups.invite.link.label` with leading `icon.global.link` (section-label style), then the white
   pill `groups.invite.link.share` (leading `icon.global.link`), centred; under it `groups.invite.link.expiry` (caption,
   gray); under that, for the link's creator and admins, the lime text link `groups.invite.link.turnOff`.
5. Gap `groups.create.size.titleToContent`.
6. **Contacts section** (`groups.invite.layout.contacts`): label `groups.invite.contacts.label`; then per platform:
   iOS 18 search field + `ContactAccessButton` + granted rows; iOS 17 white pill `onboarding.permission.contacts.choose`;
   Android rows, or the contacts card when `READ_CONTACTS` is not granted.
7. Contact rows (pitch `groups.invite.size.pickerRowPitch`, side margin `size.global.screenMargin`): avatar
   `size.global.avatarPicker` (initials-free gray circle `color.global.controlRaised` + `icon.global.person` when the
   contact has no photo) · name · trailing white pill `groups.invite.contacts.invite` (→ "invited" text after sending).

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| ✕ | `size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.close` | `groups.invite.close.accessibilityLabel` | dismiss |
| title | `fontSize.global.onboardingTitle`, `fontWeight.global.onboardingTitle`, `groups.create.layout.titleAccent` | `groups.invite.title.friends` / `.family` / `.roommates` / `.custom` (by `groups.kind`) | static; long names wrap |
| link label | `fontSize.global.sectionLabel`, `fontWeight.global.sectionLabel`, `color.global.textSecondary`, `icon.global.link` | `groups.invite.link.label` | static |
| share pill | `color.global.surfaceLight`, label `color.global.onSurfaceLight` text role `button`, height `groups.screen.size.lightPillHeight`, corners `groups.screen.radius.lightPill`, `icon.global.link` | `groups.invite.link.share`; shared text `groups.invite.link.message` | first tap: `create_invite` if no live invite of the caller exists; then the system share sheet (`groups.invite.layout.share`) |
| expiry | `fontSize.global.caption`, `color.global.textSecondary` | `groups.invite.link.expiry` ({date} = `expires_at`, "Mmm d yyyy") | shown once an invite exists |
| turn off link | `auth.code.fontSize.textLink`, `auth.code.fontWeight.textLink`, `color.global.accent` | `groups.invite.link.turnOff`; alert `groups.invite.link.turnOff.title`, `.message`, `.confirm`, `.cancel` | alert (`settings.account.layout.alert`) → `revoke_invite`; toast `groups.invite.link.turnedOff` |
| contacts label | section-label style | `groups.invite.contacts.label` | static |
| contact row | pitch `groups.invite.size.pickerRowPitch`; avatar `size.global.avatarPicker`; name `groups.invite.fontSize.pickerName` + `.fontWeight.pickerName` `color.global.textPrimary`; pill = `onboarding.permission.contacts.size.cardButtonWidth` / `.cardButtonHeight`, `color.global.surfaceLight` | `groups.invite.contacts.invite`, then `groups.invite.contacts.invited` (`color.global.textSecondary`) | pill → SMS compose with `groups.invite.link.message` addressed to that number (the person sees and sends it) |
| contacts card (Android) | `onboarding.permission.contacts.*` | `onboarding.permission.contacts.card.*` | see `onboarding.permission.contacts.md` |

## States

| state | when | design | copy |
|---|---|---|---|
| loading | `create_invite` in flight | Loading HUD | `groups.create.hud.loading` |
| default | invite ready | as Structure | — |
| group full | members = `max_group_members` | link and contacts sections replaced by the Yope empty-state layout (title `fontSize.global.emptyTitle` bold, detail `fontSize.global.emptyDetail` italic gray) | `groups.invite.full.title`, `groups.invite.full.detail` |
| error | `create_invite` failed | same layout + white retry pill | `groups.invite.error.title`, `.detail`, `.retry` |
| offline | no connection | same as error (the link cannot be created offline) | `groups.invite.error.*` |
| empty contacts | permission granted, no contacts with a phone number | section shows only the label | — |
| permission-denied | contacts denied | Android card stays / iOS system button | `onboarding.permission.contacts.*` |
| link turned off | after revoke | expiry and "turn off link" hidden; the next share creates a new invite | toast `groups.invite.link.turnedOff` |

## Motion

Native sheet presentation; share sheet and SMS compose are system. Toast as `auth.phone` (dwell BLOCKED). Reduce Motion:
platform behaviour.

## Haptics

Link turned off → `haptic.global.warning`. SMS sent (compose result `.sent`) → `haptic.global.send`. Share sheet: system.

## Accessibility

- Title read as one sentence. Share pill: button "share invite". Contact rows: name + "invite" button; after sending the
  row's value becomes "invited".
- Dynamic Type: title `largeTitle`; labels `callout`; pills `subheadline`; expiry `caption`; row names 13.5 → `footnote`.
- Focus order: ✕ → title → link label → share → expiry → turn off → contacts label → rows.
- Contrast: pill label 21:1; lime link on black 17.65:1; row name white on black 21:1 pass.

## Data & actions

- `group_invites` (members can read, docs/API.md §5.5): reuse a live invite created by the caller (not revoked, not
  expired); else `create_invite(p_group_id)` → `{token, expires_at}`; link `https://<domain>/i/<token>` (domain = owner).
- `revoke_invite(p_token)` (creator or admin; `not_group_admin` otherwise).
- `group_members` count is read only to show the full state (never displayed as a number).
- In: `groups.screen` created empty state ("invite more …"), `groups.screen` ••• "share invite", `groups.settings`
  (invite row, "share invite"). Out: back to the caller.

## Platform notes

- iOS: `ShareLink(item: url, message: Text(…))` / `UIActivityViewController`; contacts per `groups.invite.layout.contacts`
  (`ContactAccessButton` needs iOS 18; the deployment target is 17.2, so the iOS 17 picker path is required too).
  SMS: `MFMessageComposeViewController` (unavailable → the share sheet).
- Android: Sharesheet `Intent.createChooser(ACTION_SEND)`; SMS `ACTION_SENDTO smsto:<number>` with `sms_body`.

## Do-not-copy

- The 2024 third-party app row (WhatsApp, Instagram, Snapchat, Messages logos), the blue 2024 card, forced invites before
  using the app, "Select All" contacts, any count of invited people.

## Gaps

| item | status | smallest capture |
|---|---|---|
| 2026 invite sheet | not filmed → 2024 structure with 2026 components | one 15-s English recording of Yope's "invite more friends" tap in a 2026 group |
| section spacing inside the sheet | `groups.create.size.titleToContent` reused (approximation) | same recording |
| `{domain}` for the link | owner (config/app.json `domain`) | — |
| contact matching ("on {app_name}" rows) | no backend RPC yet (ContactMatching.swift) | backend decision |
