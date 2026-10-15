# Verification — `auth.profile` (iOS)

First name and photo — `Features/Account/Auth/ProfileScreen.swift`.

Checklist written from the spec (`design/surfaces/auth.profile.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/auth.profile.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Reference image(s): `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t51.73-group-profile-add-20-pics.png`, `references/auto/yope/frames/a-yrrah-7434441926000037121-t43.23-members-list-2024.png`

Snapshots (CI): `auth.profile-default.png`, `auth.profile-filled.png`, `auth.profile-saving.png`, `auth.profile-offline.png`

**Summary: 34 matched · 2 approximated · 0 not matched (BLOCKED or not buildable) · 0 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | copy | `auth.profile.title` | “what’s your name?” (SOURCED) |  | `Copy.…authProfileTitle` in ProfileScreen.swift |
| matched | copy | `auth.profile.subtitle` | “people in your groups see your name & photo” (SOURCED) |  | `Copy.…authProfileSubtitle` in ProfileScreen.swift |
| matched | token | `groups.create.size.titleToContent` | 34 pt (SOURCED) | title text bottom (descender) to the first content element | `Tokens.…groupsCreateSizeTitleToContent` in ProfileScreen.swift |
| matched | token | `auth.profile.size.avatar` | 92 pt (SOURCED) | large avatar circle (name + avatar step) | `Tokens.…authProfileSizeAvatar` in ProfileScreen.swift |
| matched | copy | `auth.profile.avatar.add` | “add a photo (optional)” (SOURCED) |  | `Copy.…authProfileAvatarAdd` in ProfileScreen.swift |
| matched | token | `groups.create.size.fieldToButton` | 18 pt (SOURCED) | form field bottom to the primary button top | `Tokens.…groupsCreateSizeFieldToButton` in ProfileScreen.swift |
| matched | token | `groups.create.size.mediaToField` | 23 pt (SOURCED) | cover placeholder bottom to the name field top | `Tokens.…groupsCreateSizeMediaToField` in ProfileScreen.swift |
| matched | copy | `auth.profile.field.note` | “your first name shows on the invite links you share” (SOURCED) |  | `Copy.…authProfileFieldNote` in ProfileScreen.swift |
| matched | copy | `auth.profile.continue` | “continue” (SOURCED) |  | `Copy.…authProfileContinue` in ProfileScreen.swift |
| matched | token | `auth.phone.fontSize.subtitle` | 14 pt (SOURCED) | italic subtitle under the sign-up title ('to join or create your friends groups') | `Tokens.…authPhoneFontSizeSubtitle` in TextRoles.swift |
| matched | token | `auth.phone.layout.subtitle` | style: italic; weight: regular; color: color.global.textPrimary; align: center (SOURCED) | subtitle text style under the sign-up title | OnboardingTitleBlock subtitle: italic, regular, textPrimary, centred |
| matched | token | `auth.profile.layout.avatarPicker` | ios: PhotosPicker (SwiftUI) / PHPickerViewController, single image, no library permission; android: ActivityResultContracts.PickVisualMedia(ImageOnly), no RE… (PLATFORM) | avatar picker | PhotosPicker (single image, no library permission); empty circle controlRaised + person glyph |
| matched | token | `color.global.controlRaised` | #434343 (SOURCED) | raised fill: selected tab pill, inner pill inside the header capsule, inactive page dots | `Tokens.…globalControlRaised` in FloatingTabBar.swift, StorageImage.swift |
| matched | token | `icon.global.person` | ios: person.fill; android: Rounded.Person (PLATFORM) | default avatar silhouette | `Tokens.…globalPerson` in FloatingTabBar.swift, StorageImage.swift |
| matched | token | `color.global.textSecondary` | #969696 (SOURCED) | secondary text, placeholders ('start typing...'), inactive tab-bar glyphs, chevrons inside capsules | `Tokens.…globalTextSecondary` in CheckRow.swift, EmptyStateView.swift, FloatingTabBar.swift |
| matched | copy | `auth.profile.avatar.accessibilityLabel` | “add a photo” (SOURCED) |  | `Copy.…authProfileAvatarAccessibilityLabel` in ProfileScreen.swift |
| matched | copy | `auth.profile.avatar.changeAccessibilityLabel` | “change photo” (SOURCED) |  | `Copy.…authProfileAvatarChangeAccessibilityLabel` in ProfileScreen.swift |
| matched | token | `fontSize.global.listSubtitle` | 14 pt (SOURCED) | row subtitle ('new pic added · 9:43 AM'), secondary color | `Tokens.…globalListSubtitle` in TextRoles.swift |
| matched | token | `groups.create.color.field` | #141414 (SOURCED) | single-line text field fill on black ('name group (optional)'); reused by every form field on black (auth.*… | `Tokens.…groupsCreateColorField` in FormField.swift |
| matched | token | `size.global.fieldHeight` | 44 pt (SOURCED) | single-line form text field height | `Tokens.…globalFieldHeight` in FormField.swift |
| matched | token | `radius.global.field` | 12 pt (SOURCED) | single-line form text field corners ('name group (optional)') | `Tokens.…globalField` in FormField.swift |
| matched | token | `groups.create.fontSize.fieldText` | 15 pt (SOURCED) | typed text in the form field (centred) | `Tokens.…groupsCreateFontSizeFieldText` in TextRoles.swift |
| matched | copy | `auth.profile.field.placeholder` | “your name” (SOURCED) |  | `Copy.…authProfileFieldPlaceholder` in ProfileScreen.swift |
| matched | copy | `auth.profile.field.accessibilityLabel` | “your name” (SOURCED) |  | `Copy.…authProfileFieldAccessibilityLabel` in ProfileScreen.swift |
| matched | token | `fontSize.global.caption` | 12 pt (SOURCED) | small meta text: voice-message duration ('00:38'), legal footer under sign-up | `Tokens.…globalCaption` in TextRoles.swift |
| matched | copy | `groups.create.hud.loading` | “Loading” (SOURCED) |  | `Copy.…groupsCreateHudLoading` in LoadingHUD.swift |
| matched | token | `auth.phone.layout.inlineError` | presentation: system alert: iOS UIAlertController .alert / SwiftUI .alert, Android M3 AlertDialog; not dismissible by tapping outside; title: none: the auth.… (SOURCED) | how a field-level error (wrong number, wrong or expired code, invalid date) is presented on the sign-up scr… | `formErrorAlert` (Components/FormErrorAlert.swift): system alert, no title, the error sentence as its message, one `auth.phone.error.dismiss` button (+ haptic.global.error) |
| matched | copy | `auth.profile.error.upload` | “your photo didn’t upload. try again, or keep going without it.” (SOURCED) |  | `Copy.…authProfileErrorUpload` in ProfileModel.swift |
| matched | copy | `auth.profile.error.save` | “your name didn’t save. try again in a moment.” (SOURCED) |  | `Copy.…authProfileErrorSave` in ProfileModel.swift |
| matched | copy | `auth.phone.offline.title` | “you’re offline” (SOURCED) |  | `Copy.…authPhoneOfflineTitle` in ProfileScreen.swift |
| matched | copy | `auth.profile.offline.detail` | “connect to the internet to finish. your next memories are waiting.” (SOURCED) |  | `Copy.…authProfileOfflineDetail` in ProfileScreen.swift |
| matched | copy | `auth.phone.offline.retry` | “try again” (SOURCED) |  | `Copy.…authPhoneOfflineRetry` in ProfileScreen.swift |
| matched | token | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | any task completed successfully (same generator as send) | `Tokens.…globalSuccess` in ProfileScreen.swift |
| matched | token | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | a task failed (send failed) | `Tokens.…globalError` in BlockConfirmation.swift, ProfileScreen.swift |

## Approximations

- Same sign-up layout approximations as auth.phone.
- Empty-avatar glyph at the platform default symbol size (not measured).
