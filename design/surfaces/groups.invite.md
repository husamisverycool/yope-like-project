# `groups.invite` — invite by link or from contacts

Visual reference: Retro **album link-sharing flow** (inventory #14, TC-J5 phones 1–2: sheet with the book cover and its
shadow, eye note, black capsule "Turn on link sharing"; then a grouped menu with "Reset link" and a red destructive row,
and a row of circular share targets led by "QR Code") and Retro's Invite rows (#8–9: "Invite" / "Invited"). The **QR card**
(owner decision 17) is Retro's recap card holding the code, shown in Retro's recap preview (TC-REC, ST-04). Mechanics:
system share sheet, SMS compose, contacts, photo library (PLATFORM). Tokens: `groups.invite.*`,
`groups.screen.shadow.cover`, `layout.year.story.recapCard`, `collage.view.layout.screen` + `global.*`. Copy:
`groups.invite.*`, `onboarding.permission.contacts.*`.

## References

| id | file | used for |
|---|---|---|
| TC-J5 | `references/auto/retro/press/tc-2024-04-retro-journals-5.png` (2.0687 px/pt) | cover 281.8 × 393.5, cover → note 29, note colour #767676 + eye glyph, 60 pt capsule, grouped menu (rows 58.7, glyph inset 17.9, text inset 52.7, inset 19.8 ≈ 20, red row #EA3337), 64 pt Fill share circles 90.4 apart, labels 11.6 below |
| TC-J1 | `references/auto/retro/press/tc-2024-04-journals-1.webp` | cover drop shadow (`groups.screen.shadow.cover`) |
| TC-1B | `references/auto/retro/press/tc-2023-07-retro-1b.webp` | people rows with capsule actions (C-16) |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `journal_invite_members_screen_title`, `journal_settings_link_sharing_*` (incl. `_qr_code_cta` "QR Code"), `journal_broadcast_invite_*`, `invite_journal_share_text_short_template`, `friend_tab_contact_*`, `invites_no_contacts_empty_message`; QR card: `qr_card_content_subtitle` ("Retro.app - Photos with Friends"), `qr_card_content_member_since_template`, `journal_qr_code_action_sheet_title` ("Share Link"), `friends_tab_profile_qr` ("Profile QR code") |
| APK-X | `references/auto/retro/apk/retro-android-2026.10.1150-excerpts.txt` "FONT FAMILY USAGE" | QR card tiny print: `osg.g cs1.java:165` 10 sp next to `qr_card_content_subtitle` (`groups.invite.fontSize.qrTagline`) |
| TC-QR | https://techcrunch.com/2024/04/04/retro-an-actually-good-photo-sharing-app-for-bffs-launches-collaborative-journals/ (accessed 2026-10-16) | Retro's journal QR code "that you can either save to your camera roll or print" → Save + Share (print is in the share sheet) |
| TC-REC, ST-04 | `references/auto/retro/press/tc-2023-12-recaps.png`, `references/auto/retro/store/retro-store-04.png` | the recap card shell (`layout.year.story.recapCard`) and the recap preview around it (`collage.view.layout.screen`) |
| WEBD, WEBQ | `references/auto/retro/web/retro.app-u-nathan-desktop.png`; `web/src/render/qr.ts` | QR black on white; this app's web encoding (error correction H, whole-pixel modules) reused |
| DW | https://www.qrcode.com/en/howto/code.html (DENSO WAVE, accessed 2026-10-16) | "QR Code requires a four-module wide margin at all sides of a symbol." |

## Structure (page sheet, C-29; page `color.global.background`; scrolls)

1. Sheet header (C-29): centred title `groups.invite.title` (`sheetTitle`) + trailing close circle (C-11 on the page).
2. **Cover**, centred: `groups.invite.size.coverWidth` × `.coverHeight`, `radius.global.thumbnail`, shadow
   `groups.screen.shadow.cover`; no cover → `color.global.control` fill.
3. `groups.invite.size.coverToNote` (29) below: **note**, centred: `groups.invite.icon.note` (`size.global.iconSmall`)
   + `groups.invite.size.noteGlyphGap` + `groups.invite.link.label` (text role `meta`); colour `groups.invite.color.note`
   (light) / `color.global.textSecondary` (dark). Link on: second line `groups.invite.link.expiry` (same style).
4. **Link off** (no live invite of yours): primary capsule C-05 `groups.invite.link.turnOn` at `size.global.buttonMarginH`,
   `size.global.titleToContent` below the note.
   **Link on**: `size.global.titleToContent` below the note —
   - grouped menu (C-14 group, fill `color.global.control` / `.surfaceSecondary.android`, `radius.global.groupedRow`,
     inset `size.global.buttonMarginH`, rows `groups.invite.size.menuRowHeight`, hairline between them): row 1
     `groups.invite.link.reset` (glyph `groups.invite.icon.reset` at `groups.invite.size.menuGlyphInset`,
     label at `groups.invite.size.menuTextInset`, text role `textButton`, `color.global.textPrimary`); row 2
     `groups.invite.link.turnOff` (glyph `icon.global.lock`, label and glyph `color.global.destructive`, C-10);
   - `size.global.titleToContent` below: **share targets**, centred row of four 64 pt circles (C-11:
     `size.global.circleButtonLarge`, `color.global.control`, glyph `size.global.icon` in `color.global.textPrimary`),
     centres `groups.invite.size.targetPitch` apart (a quarter of the width each where four pitches do not fit), in
     TC-J5's order: QR Code (`groups.invite.icon.qr`), Copy Link (`icon.global.link`), Message (`icon.global.chats`, in
     the place of Retro's Instagram target), Share to… (`icon.global.share`); labels `groups.invite.size.targetLabelGap`
     below each (text role `meta`, `color.global.textPrimary`, centred).
5. `size.global.sectionGap` below: **Contacts** section — header `groups.invite.contacts.label` (text role `sectionLabel`)
   at the margin, then per `groups.invite.layout.contacts` (iOS 18 search + system button; iOS 17 capsule; Android rows or
   the permission block, `onboarding.permission.contacts.md`); people rows C-16 (avatar `size.global.avatarPicker`,
   name `listTitle`, trailing outline capsule C-06 `groups.invite.contacts.invite` → after sending, the value
   `groups.invite.contacts.invited` in `listSubtitle` `color.global.textSecondary`).

## QR card (owner decision 17; `groups.invite.layout.qrCard`)

"QR Code" opens Retro's recap preview (`RecapPreviewScreen`, ST-04; iOS full-screen cover, Android a full-screen layer
over the sheet that Back closes), a media surface, dark in both appearances:

1. **Media page** (`collage.view.layout.screen`): the group's cover blurred (`BlurredBackdrop`, σ `size.global.backdropBlur`
   under `color.global.backdropDim`); no cover → `color.global.controlOnDeep`. Close circle (C-11 on media) at
   `closeCentreFromTrailing` / `closeCentreBelowPageTop`.
2. **Card**, centred, `layout.year.story.recapCard` shell: width `widthRatio` × the page width, fill
   `color.global.surfaceLight` in both appearances (L-4), corners `cornerRadiusRatio` × width, padding `paddingRatio` ×
   width.
   - **Code** in the square grid area (width − 2 × padding): the link the sheet shares (`https://<domain>/i/<token>`),
     error correction H, byte mode — the web page's encoding (`web/src/render/qr.ts`) — modules
     `color.global.onSurfaceLight`, square, a whole number of device pixels each (nearest-neighbour), centred, with a
     white quiet zone of `quietZoneModules` (4, DW) inside the card. Light card in dark appearance too: some readers do
     not decode reversed codes.
   - **Footer** `footerHeightRatio` × width, two lines centred in it at the card padding: the group's name (text role
     `displayTitle`, `color.global.onSurfaceLight`, one line, tail truncation) over `groups.invite.qr.tagline`
     (`groups.invite.fontSize.qrTagline` 10 in `font.global.family`, `groups.invite.color.note`). The card is a picture
     (also the exported image): its text keeps the default size.
3. **Bottom row** (`collage.view.layout.screen.bottomRowCentreFromScreenBottom`): Save circle (C-11 on media,
   `icon.global.download`, label `groups.invite.qr.save`) leading, light Share pill (C-09, `collage.share.layout.pill`,
   `groups.invite.qr.share`) trailing, both at `size.global.buttonMarginH`.

Save writes the card alone (no backdrop) as a PNG (`exportScale` 3 on iOS; the drawn layer at the device density on
Android) to the photo library — add-only access on iOS, MediaStore on Android (API 26–28 ask WRITE_EXTERNAL_STORAGE):
`groups.invite.qr.saved` + `haptic.global.success`; denied → native alert `groups.invite.qr.saveDenied.*` (button opens
Settings); failed → `groups.invite.qr.saveFailed` + `haptic.global.error`. Share hands the same PNG to the system share
sheet (Save Image, Print, Messages… are the platform's).

Not copied: Retro's QR card art (never captured), its "Retro.app" domain line and "Member since %1$d" (a person's join
year; this card is a group's), any logo or avatar over the code.

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| header | C-29, C-11 | `groups.invite.title` ({group_name}), `groups.invite.close.accessibilityLabel` | close |
| cover | `groups.invite.size.coverWidth` / `.coverHeight`, `groups.screen.shadow.cover` | `groups.invite.cover.accessibilityLabel` | decorative image |
| note | `groups.invite.icon.note`, `groups.invite.size.noteGlyphGap`, `meta`, `groups.invite.color.note` / `color.global.textSecondary` | `groups.invite.link.label`, `groups.invite.link.expiry` ({date} long date, `retro.voice.formats`) | static |
| Turn on link sharing | C-05 | `groups.invite.link.turnOn` | `create_invite(p_group_id)` → link on |
| Reset link | C-14 row | `groups.invite.link.reset` | `revoke_invite(old)` then `create_invite` (a new link; the old stops working) |
| Turn off link sharing | C-14 row, C-10 red | `groups.invite.link.turnOff`; alert `.turnOff.title`, `.turnOff.message`, `.turnOff.confirm`, `.turnOff.cancel` | native alert (`settings.account.layout.alert`) → `revoke_invite` → link off; confirmation `groups.invite.link.turnedOff` (C-26) |
| QR Code | C-11 64 circle + label, `groups.invite.icon.qr` | `groups.invite.link.qr` | link live (or created) → the QR card |
| Message | C-11 64 circle + label | `groups.invite.link.messageTarget` | SMS compose with `groups.invite.link.message` (`groups.invite.layout.share.message`) |
| Copy Link | C-11 + label | `groups.invite.link.copy`; confirmation `groups.invite.link.copied` (C-26) | pasteboard |
| Share to… | C-11 + label | `groups.invite.link.share` | system share sheet with `groups.invite.link.message` |
| contact row | C-16 + C-06 | `groups.invite.contacts.invite` / `.invited` | Invite → SMS compose addressed to that number (the person sees the message first) |
| QR card | `groups.invite.layout.qrCard`, `layout.year.story.recapCard`, `groups.invite.fontSize.qrTagline`, `groups.invite.color.note` | `groups.invite.qr.accessibilityLabel` ({group_name}), `groups.invite.qr.tagline` | one image element |
| QR close | C-11 on media | `groups.invite.close.accessibilityLabel` | back to the sheet |
| Save | C-11 on media, `icon.global.download` | `groups.invite.qr.save`; `.saved`, `.saveFailed`, `.saveDenied.title` / `.message` / `.button` / `.cancel` | card PNG → photo library |
| Share | C-09 recap pill | `groups.invite.qr.share` | card PNG → system share sheet |

## States

| state | when | design | copy |
|---|---|---|---|
| loading | reading `group_invites` | C-28 platform indicator under the note in place of 4 | — |
| link off | no live invite created by you | capsule | `groups.invite.link.turnOn` |
| link on | live invite (not revoked, not expired) | menu + targets | as above |
| creating | `create_invite` in flight | capsule busy (C-05) | — |
| group full | members = `max_group_members` | 4 and 5 replaced by the C-27 block (no glyph, no action) | `groups.invite.full.title`, `.full.detail` |
| error | invite read / create failed | C-27 block with outline capsule C-06 | `groups.invite.error.title`, `.detail`, `.retry` |
| offline | no connection | same as error | same |
| no contacts | permission granted, nothing with a number | one line under the header (`body`, `textSecondary`) | `groups.invite.contacts.empty` |
| permission-denied | contacts denied | `onboarding.permission.contacts.md` | `onboarding.permission.contacts.*` |
| QR card | "QR Code" tapped, link live | the QR card screen (above) | `groups.invite.qr.*` |
| QR card, no cover | the group has no cover | media page `color.global.controlOnDeep` | — |
| photo access denied | Save, access denied | native alert, button → Settings | `groups.invite.qr.saveDenied.*` |

## Motion

Sheet: native (`spring.global.sheetPresent`). Link off ↔ on: cross-fade `duration.global.fade` (150 ms,
`easing.global.standard`) between the capsule and the menu + targets. QR card: iOS full-screen cover (system); Android
fades in and out over the sheet (`duration.global.fade`). Share sheet, SMS compose, alerts: system.
Reduce Motion: cross-fade only.

## Haptics

Presses (capsule, rows, targets, Invite) → `haptic.global.tap` (Android). Link turned off → `haptic.global.warning`;
SMS sent (compose result `.sent`) → `haptic.global.send` (PLATFORM outcomes, R-12).

## Accessibility

- Cover hidden behind its label; note read as one sentence (+ expiry). Menu rows: buttons ("Turn off link sharing" is
  announced as destructive by its alert, not by colour). Targets: one button each, label = visible text.
- QR card: one image, "QR code for joining {group_name}" (`groups.invite.qr.accessibilityLabel`); the name and tagline are
  not read separately. Save (circle) and Share (pill) are buttons with their copy; close "Close". Focus order: card →
  Save → Share → close. The card's text keeps its size at every Dynamic Type / font scale (a picture of a card; the
  label carries it); Save and Share follow the text size like every recap preview control.
- Dynamic Type: sheet title `headline`; note `footnote`; menu labels `body`; target labels `footnote`; section header
  `subheadline`; capsule `headline`. Targets wrap to a second row before their labels truncate.
- Focus order: close → title → cover → note → capsule | (menu rows → targets) → Contacts header → rows.
- Contrast:

| pair | light | dark |
|---|---|---|
| note `#767676` / `textSecondary` on page | 4.54:1 pass (`node tools/contrast.mjs '#767676' '#FFFFFF' text`) | 7.37:1 pass (row 3) |
| menu label on fill | 18.59:1 pass (row 9) | 15.13:1 pass |
| red row on fill | **3.70:1 FAIL** (row 32) | **3.62:1 FAIL** |
| target glyph on 64 circle | 18.59:1 pass (row 10) | 15.13:1 pass |
| target label `textPrimary` on page | 21:1 (row 1) | 21:1 |
| QR modules `onSurfaceLight` on card `surfaceLight` | 21:1 | 21:1 (the card stays white) |
| QR card name `onSurfaceLight` on white | 21:1 | 21:1 |
| QR card tagline `#767676` on white | 4.54:1 pass | 4.54:1 pass |
| menu / circle fill vs page (non-text) | **1.13:1 FAIL** (row 13) | **1.39:1 FAIL** |

## Data & actions

- `group_invites` (members read, docs/API.md §5.5): reuse a live invite created by the caller; else nothing is live
  (link off). `create_invite(p_group_id)` → `{token, expires_at}`; link `https://<domain>/i/<token>` (domain = owner).
- `revoke_invite(p_token)` (creator or admin; `not_group_admin` otherwise) for Reset / Turn off.
- `group_members` count only to decide the full state (never shown as a number).
- In: `groups.screen` ("Invite" capsule, created state), `groups.settings` (Invite row). Out: back.

## Platform notes

- iOS: `ShareLink` / `UIActivityViewController`; `MFMessageComposeViewController` (unavailable → the share sheet); contacts
  per `groups.invite.layout.contacts` (iOS 18 `ContactAccessButton`, iOS 17 picker).
- Android: Sharesheet `Intent.createChooser(ACTION_SEND)`; SMS `ACTION_SENDTO smsto:` with `sms_body`.
- QR encoding: iOS CoreImage `CIQRCodeGenerator` (`correctionLevel` "H"); Android ZXing core 3.5.3 `Encoder` (Apache-2.0,
  `android/feature/account/licenses/ZXing-LICENSE.txt`, `ZXing-NOTICE.txt`). Save: iOS `PhotoLibraryService.saveImage`
  (add-only); Android MediaStore Pictures (WRITE_EXTERNAL_STORAGE ≤ API 28 in the account manifest). Share: iOS
  `UIActivityViewController` with the image; Android `ACTION_SEND image/png` through the account FileProvider
  (`cache/invite/`).

## Do-not-copy

- Retro's Instagram target and story sticker (third-party brand), its "Make journal private" / view-only link
  (this app's links only join), referral counters, "Select All" contacts, any count of invited people.

## Gaps

| item | status | smallest capture |
|---|---|---|
| reset glyph | `groups.invite.icon.reset` (PLATFORM match of Retro's circular arrow) | — |
| QR card art | Retro's own card was never captured: the card is a composition (recap card shell + the web encoding); its tiny print size is Retro's (APK-X) | one screenshot of Retro's journal "QR Code" sheet |
| `{domain}` | owner (`config/app.json` domain) | — |
| dark appearance of the sheet | light renders only (TC-J5) | one dark screenshot of Retro's link-sharing sheet |
