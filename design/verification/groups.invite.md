# Verification — `groups.invite` (iOS, Pass 4 — Retro redesign)

Invite sheet — `Features/Account/Groups/GroupInviteScreen.swift`, `GroupInviteModel.swift`, `InviteSystemControllers.swift`;
QR card (owner decision 17) — `GroupInviteQR.swift`.

Checklist written from the spec (`design/surfaces/groups.invite.md`) against the iOS code: every token and copy key the spec names, its reference value, and where the iOS code uses it. The snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>-<light|dark>.png` (AccountSnapshotTests: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/groups.invite.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/press/tc-2024-04-retro-journals-5.png`, `references/auto/retro/press/tc-2024-04-journals-1.webp`, `references/auto/retro/press/tc-2023-07-retro-1b.webp`, `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt`

Snapshots (CI, `ios/build/snapshots/account/`): `groups.invite-loading-light.png`, `groups.invite-link-off-light.png`, `groups.invite-link-on-light.png`, `groups.invite-link-on-dark.png`, `groups.invite-error-light.png`, `groups.invite-full-light.png`, `groups.invite-qr-light.png`, `groups.invite-qr-dark.png`, `groups.invite-qr-noCover-light.png`

**Summary: 74 matched · 0 approximated · 0 not matched · 1 not applicable on iOS / owner / another pass.** (QR card rows
added 2026-10-16; the QR snapshots come from the next macOS CI round. Unit tests: `AccountInviteQRTests` — the symbol,
its four-module quiet zone, whole-pixel modules, the rendered card read back by `CIDetector` as the link at error
correction H, Save's outcomes.)


## Structure

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `groups.screen.shadow.cover` | color: #000000; blur: 8.5; x: 3; y: 10; opacity: 0.25 (SOURCED) | `Tokens.Shadows.groupsScreenShadowCover` in GroupCreateScreen.swift |
| matched | `color.global.background` | light: #FFFFFF; dark: #000000 (SOURCED) | `Tokens.Colors.globalBackground` in AccountGroupedRows.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, GroupScreen.swift … |
| matched | `groups.invite.title` | “Invite to {group_name}” (SOURCED) | `Copy.groupsInviteTitle` in GroupInviteScreen.swift |
| matched | `groups.invite.size.coverWidth` | 281.8 pt (SOURCED) | `Tokens.Sizes.groupsInviteSizeCoverWidth` in GroupInviteScreen.swift |
| matched | `radius.global.thumbnail` | 4 pt (SOURCED) | `Tokens.Radii.globalThumbnail` in GroupCreateScreen.swift, GroupsHomeScreen.swift, ThumbnailRow.swift |
| matched | `color.global.control` | light: #F1F1F1; dark: #262626 (SOURCED) | `Tokens.Colors.globalControl` in AccountGroupedRows.swift, Avatar.swift, CapsuleButton.swift, CircleButton.swift … |
| matched | `groups.invite.size.coverToNote` | 29 pt (SOURCED) | `Tokens.Sizes.groupsInviteSizeCoverToNote` in GroupInviteScreen.swift |
| matched | `groups.invite.icon.note` | ios: eye; android: Outlined.Visibility (PLATFORM) | `Tokens.Icons.groupsInviteIconNote` in GroupInviteScreen.swift |
| matched | `size.global.iconSmall` | 14.7 pt (SOURCED) | `Tokens.Sizes.globalIconSmall` in CapsuleButton.swift, GroupInviteScreen.swift, LightPill.swift, MediaPills.swift … |
| matched | `groups.invite.size.noteGlyphGap` | 6.3 pt (SOURCED) | `Tokens.Sizes.groupsInviteSizeNoteGlyphGap` in GroupInviteScreen.swift |
| matched | `groups.invite.link.label` | “Anyone with this link can join {group_name}” (SOURCED) | `Copy.groupsInviteLinkLabel` in GroupInviteScreen.swift |
| matched | `groups.invite.color.note` | #767676 (SOURCED) | `Tokens.Colors.groupsInviteColorNote` in GroupInviteScreen.swift |
| matched | `color.global.textSecondary` | #999999 (SOURCED) | `Tokens.Colors.globalTextSecondary` in AccountGroupedRows.swift, Avatar.swift, CheckRow.swift, CodeScreen.swift … |
| removed 2026-10-17 | `groups.invite.link.expiry` | — | links never expire (owner decision 27); the line and its key are gone |
| matched | `groups.invite.link.turnOn` | “Turn on link sharing” (SOURCED) | `Copy.groupsInviteLinkTurnOn` in GroupInviteScreen.swift |
| matched | `size.global.buttonMarginH` | 20 pt (SOURCED) | `Tokens.Sizes.globalButtonMarginH` in BackdropCard.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, OnboardingTitle.swift … |
| matched | `size.global.titleToContent` | 30 pt (SOURCED) | `Tokens.Sizes.globalTitleToContent` in AccountGroupedRows.swift, AgeGateForm.swift, GroupCreateScreen.swift, GroupInviteScreen.swift … |
| matched | `radius.global.groupedRow` | 12 pt (SOURCED) | `Tokens.Radii.globalGroupedRow` in AccountGroupedRows.swift, GroupInviteScreen.swift, GroupedSection.swift |
| matched | `groups.invite.size.menuRowHeight` | 58.7 pt (SOURCED) | `Tokens.Sizes.groupsInviteSizeMenuRowHeight` in GroupInviteScreen.swift |
| matched | `groups.invite.link.reset` | “Reset link” (SOURCED) | `Copy.groupsInviteLinkReset` in GroupInviteScreen.swift |
| matched | `groups.invite.icon.reset` | ios: arrow.clockwise; android: Rounded.Refresh (PLATFORM) | `Tokens.Icons.groupsInviteIconReset` in GroupInviteScreen.swift |
| matched | `groups.invite.size.menuGlyphInset` | 17.9 pt (SOURCED) | `Tokens.Sizes.groupsInviteSizeMenuGlyphInset` in GroupInviteScreen.swift |
| matched | `groups.invite.size.menuTextInset` | 52.7 pt (SOURCED) | `Tokens.Sizes.groupsInviteSizeMenuTextInset` in GroupInviteScreen.swift |
| matched | `color.global.textPrimary` | light: #000000; dark: #FFFFFF (SOURCED) | `Tokens.Colors.globalTextPrimary` in AccountGroupedRows.swift, CapsuleButton.swift, CheckRow.swift, CircleButton.swift … |
| matched | `groups.invite.link.turnOff` | “Turn off link sharing” (SOURCED) | `Copy.groupsInviteLinkTurnOff` in GroupInviteScreen.swift |
| matched | `icon.global.lock` | ios: lock.fill; android: Rounded.Lock (PLATFORM) | `Tokens.Icons.globalLock` in GroupInviteScreen.swift |
| matched | `color.global.destructive` | #EA3337 (SOURCED) | `Tokens.Colors.globalDestructive` in AccountGroupedRows.swift, DestructiveButton.swift, FormField.swift, GroupInviteScreen.swift … |
| matched | `size.global.circleButtonLarge` | 64 pt (SOURCED) | `Tokens.Sizes.globalCircleButtonLarge` in CircleButton.swift, GroupInviteScreen.swift |
| matched | `size.global.icon` | 24 pt (SOURCED) | `Tokens.Sizes.globalIcon` in CircleButton.swift, ComponentSupport.swift, GroupScreen.swift, GroupSettingsScreen.swift … |
| matched | `groups.invite.size.targetPitch` | 90.4 pt (SOURCED) | `Tokens.Sizes.groupsInviteSizeTargetPitch` in GroupInviteScreen.swift |
| matched | `icon.global.chats` | ios: bubble.left; android: Outlined.ChatBubbleOutline (PLATFORM) | `Tokens.Icons.globalChats` in GroupInviteScreen.swift, GroupScreen.swift |
| matched | `icon.global.link` | ios: link; android: Rounded.Link (PLATFORM) | `Tokens.Icons.globalLink` in GroupInviteScreen.swift |
| matched | `icon.global.share` | ios: square.and.arrow.up; android: Rounded.IosShare (PLATFORM) | `Tokens.Icons.globalShare` in GroupInviteScreen.swift |
| matched | `groups.invite.size.targetLabelGap` | 11.6 pt (SOURCED) | `Tokens.Sizes.groupsInviteSizeTargetLabelGap` in GroupInviteScreen.swift |
| matched | `size.global.sectionGap` | 36.4 pt (SOURCED) | `Tokens.Sizes.globalSectionGap` in AccountGroupedRows.swift, GroupInviteScreen.swift, GroupScreen.swift, GroupsHomeScreen.swift … |
| matched | `groups.invite.contacts.label` | “Contacts” (SOURCED) | `Copy.groupsInviteContactsLabel` in GroupInviteScreen.swift |
| matched | `groups.invite.layout.contacts` | ios18: ContactAccessButton(queryString:) under the search field (C-12): the person grants access per contact (limited access); granted contacts listed as peo… (PLATFORM) | Contacts section in groups.invite: iOS 18 search field + `ContactAccessButton`, iOS 17 "Choose Contacts" → `CNContactPickerViewController` (InviteSystemControllers.swift) |
| matched | `size.global.avatarPicker` | 37 pt (SOURCED) | `Tokens.Sizes.globalAvatarPicker` in GroupScreen.swift, GroupSettingsScreen.swift, PeopleRow.swift, SettingsBlockedScreen.swift |
| matched | `groups.invite.contacts.invite` | “Invite” (SOURCED) | `Copy.groupsInviteContactsInvite` in GroupInviteScreen.swift |
| matched | `groups.invite.contacts.invited` | “Invited” (SOURCED) | `Copy.groupsInviteContactsInvited` in GroupInviteScreen.swift |

## Elements

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `groups.invite.close.accessibilityLabel` | “Close” (VERIFIED) | `Copy.groupsInviteCloseAccessibilityLabel` in GroupInviteScreen.swift |
| matched | `groups.invite.cover.accessibilityLabel` | “{group_name} cover” (VERIFIED) | `Copy.groupsInviteCoverAccessibilityLabel` in GroupInviteScreen.swift |
| matched | `settings.account.layout.alert` | ios: alert(_:isPresented:actions:message:): destructive-role button + Cancel; at most 3 buttons; Cancel is never the default; android: M3 AlertDialog: contai… (VERIFIED) | native `.alert` / `.confirmationDialog` (C-29) |
| matched | `groups.invite.link.turnedOff` | “Link off” (SOURCED) | `Copy.groupsInviteLinkTurnedOff` in GroupInviteScreen.swift |
| matched | `groups.invite.link.messageTarget` | “Message” (SOURCED) | `Copy.groupsInviteLinkMessageTarget` in GroupInviteScreen.swift |
| matched | `groups.invite.link.message` | “Check out {group_name} on {app_name}: {link}” (SOURCED) | `AccountBlockedCopy.inviteLinkMessage` (BLOCKED {app_name}: DEBUG shows the placeholder; release shares the link alone) |
| matched | `groups.invite.link.copy` | “Copy Link” (SOURCED) | `Copy.groupsInviteLinkCopy` in GroupInviteScreen.swift |
| matched | `groups.invite.link.copied` | “Invite link copied to clipboard” (SOURCED) | `Copy.groupsInviteLinkCopied` in GroupInviteScreen.swift |
| matched | `groups.invite.link.share` | “Share to…” (SOURCED) | `Copy.groupsInviteLinkShare` in GroupInviteScreen.swift |
| matched | `groups.invite.link.qr` | “QR Code” (SOURCED) | `Copy.groupsInviteLinkQr` in GroupInviteScreen.swift (first target, TC-J5 order) |
| matched | `groups.invite.icon.qr` | ios: qrcode; android: Rounded.QrCode2 (PLATFORM) | `Tokens.Icons.groupsInviteIconQr` in GroupInviteScreen.swift |

## QR card (owner decision 17)

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `groups.invite.layout.qrCard` | recap preview + recap card shell, EC H, quiet zone 4, whole-pixel modules, card PNG at exportScale 3 (SOURCED) | `GroupInviteQRScreen` (`RecapPreviewScreen`), `InviteQRCard`, `InviteQRCode` (CIQRCodeGenerator `correctionLevel` = `errorCorrection`, `quietZoneModules`, `exportScale`) in GroupInviteQR.swift |
| matched | `layout.year.story.recapCard` | widthRatio 0.825, paddingRatio 0.0241, cornerRadiusRatio 0.051, footerHeightRatio 0.21 (SOURCED) | `Tokens.Layouts.YearStoryRecapCard` in GroupInviteQR.swift |
| matched | `collage.view.layout.screen` | media page, close, bottom row (SOURCED) | `RecapPreviewScreen` / `RecapPreviewClose` (capture's shared screen) |
| matched | `color.global.surfaceLight` | #FFFFFF (SOURCED) | card fill in both appearances (`Tokens.Colors.globalSurfaceLight`) |
| matched | `color.global.onSurfaceLight` | #000000 (SOURCED) | modules (template image tinted) and the group name |
| matched | `color.global.controlOnDeep` | #262626 (SOURCED) | media page without a cover |
| matched | `size.global.backdropBlur` | 1.8 pt (SOURCED) | `BlurredBackdrop` of the group's cover |
| matched | `groups.invite.fontSize.qrTagline` | 10 pt (SOURCED) | `Tokens.FontSizes.groupsInviteFontSizeQrTagline` in GroupInviteQR.swift |
| matched | `groups.invite.color.note` | #767676 (SOURCED) | tagline colour on the white card |
| matched | `icon.global.download` | ios: arrow.down.to.line (PLATFORM) | Save circle (`CircleButton` `.media`) |
| matched | `collage.share.layout.pill` | 43.5 high, padding 23 (SOURCED) | `RecapPill` "Share" |
| matched | `groups.invite.qr.accessibilityLabel` | “QR code for joining {group_name}” (SOURCED) | `Copy.groupsInviteQrAccessibilityLabel` — the card is one image element |
| matched | `groups.invite.qr.tagline` | “Photos with friends and family” (SOURCED) | `Copy.groupsInviteQrTagline` |
| matched | `groups.invite.qr.save` / `.share` | “Save” / “Share” (SOURCED) | `Copy.groupsInviteQrSave`, `Copy.groupsInviteQrShare` |
| matched | `groups.invite.qr.saved` / `.saveFailed` | “Saved” / “Couldn't save photo” (SOURCED) | `GroupInviteQRModel.save` → `ToastCenter` (announcement, C-26 iOS) |
| matched | `groups.invite.qr.saveDenied.*` | “Camera Roll Access” … “Allow Photo Access” / “Cancel” (SOURCED / VERIFIED) | native `.alert`, button opens Settings |
| matched | `haptic.global.success` / `haptic.global.error` | notification success / error (PLATFORM) | `.dsHaptic` on Save's outcome |

## States

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `groups.invite.full.title` | “{group_name} is full” (SOURCED) | `Copy.groupsInviteFullTitle` in GroupInviteScreen.swift |
| matched | `groups.invite.error.title` | “Something went wrong” (SOURCED) | `Copy.groupsInviteErrorTitle` in GroupInviteScreen.swift |
| matched | `groups.invite.contacts.empty` | “No Contacts” (SOURCED) | `Copy.groupsInviteContactsEmpty` in GroupInviteScreen.swift |

## Motion

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| matched | `spring.global.sheetPresent` | response: 0.347; dampingFraction: 1 (SOURCED) | system sheet presentation (`.sheet`) |
| matched | `duration.global.fade` | 150 ms (SOURCED) | `Tokens.Durations.globalFade` in ComponentSupport.swift, GroupCreateScreen.swift, GroupInviteScreen.swift, PaywallScreen.swift … |
| matched | `easing.global.standard` | x1: 0.4; y1: 0; x2: 0.2; y2: 1 (SOURCED) | `Tokens.Easings.globalStandard` in AgeGateForm.swift, ComponentSupport.swift, GroupCreateScreen.swift, GroupInviteScreen.swift … |

## Haptics

| status | token / copy | reference value | iOS implementation |
|---|---|---|---|
| n/a | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | Android only — iOS presses play no haptic |
| matched | `haptic.global.warning` | ios: notification.warning; android: CONFIRM (PLATFORM) | `Tokens.Haptics.globalWarning` in BlockConfirmation.swift, GroupInviteScreen.swift, GroupSettingsScreen.swift, ReportFlow.swift … |
| matched | `haptic.global.send` | ios: notification.success; android: CONFIRM (PLATFORM) | `Tokens.Haptics.globalSend` in GroupInviteScreen.swift, ReplyBar.swift |
