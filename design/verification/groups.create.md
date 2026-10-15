# Verification — `groups.create` (iOS)

New / edit group sheet — `Features/Account/Groups/GroupCreateScreen.swift`.

Checklist written from the spec (`design/surfaces/groups.create.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/account/<surface>-<state>.png` (AccountSnapshotTests), then `tools/sidebyside.py` makes `design/verification/groups.create.png` next to the reference image(s) below. The "what the snapshot shows" column states what the code draws for that value; it is to be confirmed on the image.

Reference image(s): `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t45.23-new-group-empty.png`, `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t49.23-new-group-selected-create.png`, `references/auto/yope/frames/a-yrrah-7452976839846382855-t3.73-create-new-group-empty-2024.png`, `references/auto/yope/web/a-bi-2025-create-group-composite.jpg`, `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t51.73-group-profile-add-20-pics.png`, `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t50.60-loading-hud.png`

Snapshots (CI): `groups.create-default.png`, `groups.create-filled.png`, `groups.create-error.png`, `groups.create-edit.png`

**Summary: 71 matched · 1 approximated · 0 not matched (BLOCKED or not buildable) · 1 not applicable on iOS / placed by another pass.**

| status | kind | token / copy | reference value | element | what the snapshot shows (iOS implementation) |
|---|---|---|---|---|---|
| matched | token | `color.global.backgroundDeep` | #000000 (SOURCED) | screen background of the home list, sheets ('new group', 'send to...'), camera, sign-up, profile 'pics' gri… | `Tokens.…globalBackgroundDeep` in GroupCreateScreen.swift |
| matched | token | `size.global.headerButton` | 44 pt (SOURCED) | circle icon buttons in headers (back, close, download, film-strip, search) | `Tokens.…globalHeaderButton` in HeaderCircleButton.swift |
| matched | token | `color.global.controlOnDeep` | #101010 (SOURCED) | header circle icon buttons on black screens and sheets (✕, download) | `Tokens.…globalControlOnDeep` in HeaderCircleButton.swift |
| matched | token | `icon.global.close` | ios: xmark; android: Rounded.Close (PLATFORM) | close / dismiss (✕ in a header circle on sheets) | `Tokens.…globalClose` in GroupCreateScreen.swift, PermissionCard.swift |
| matched | token | `size.global.headerInset` | 11.5 pt (SOURCED) | screen edge to the first / last header circle | `Tokens.…globalHeaderInset` in GroupCreateScreen.swift |
| matched | copy | `groups.create.title` | “new group” (SOURCED) |  | `Copy.…groupsCreateTitle` in GroupCreateScreen.swift |
| matched | token | `groups.create.size.titleToContent` | 34 pt (SOURCED) | title text bottom (descender) to the first content element | `Tokens.…groupsCreateSizeTitleToContent` in GroupCreateScreen.swift |
| matched | token | `groups.create.size.cover.width` | 330 pt (SOURCED) | cover-photo placeholder width (centred) | `Tokens.…groupsCreateSizeCoverWidth` in GroupCreateScreen.swift |
| matched | token | `groups.create.size.cover.height` | 221 pt (SOURCED) | cover-photo placeholder height | `Tokens.…groupsCreateSizeCoverHeight` in GroupCreateScreen.swift |
| matched | token | `groups.create.size.mediaToField` | 23 pt (SOURCED) | cover placeholder bottom to the name field top | `Tokens.…groupsCreateSizeMediaToField` in GroupCreateScreen.swift |
| matched | token | `size.global.buttonMarginH` | 19 pt (SOURCED) | side margin of the form primary button | `Tokens.…globalButtonMarginH` in GroupCreateScreen.swift |
| matched | copy | `groups.create.type.label` | “what kind of group?” (SOURCED) |  | `Copy.…groupsCreateTypeLabel` in GroupCreateScreen.swift |
| matched | copy | `groups.create.cta` | “create group” (SOURCED) |  | `Copy.…groupsCreateCta` in GroupCreateScreen.swift |
| matched | copy | `groups.create.save` | “save” (SOURCED) |  | `Copy.…groupsCreateSave` in GroupCreateScreen.swift |
| matched | token | `groups.create.size.fieldToButton` | 18 pt (SOURCED) | form field bottom to the primary button top | `Tokens.…groupsCreateSizeFieldToButton` in GroupCreateScreen.swift |
| matched | token | `color.global.textPrimary` | #FFFFFF (SOURCED) | primary text and glyphs | `Tokens.…globalTextPrimary` in CheckRow.swift, EmptyStateView.swift, FloatingTabBar.swift |
| matched | copy | `groups.create.close.accessibilityLabel` | “close” (SOURCED) |  | `Copy.…groupsCreateCloseAccessibilityLabel` in GroupCreateScreen.swift |
| matched | token | `groups.create.fontSize.title` | 14.5 pt (SOURCED) | sheet title 'new group' | `Tokens.…groupsCreateFontSizeTitle` in GroupCreateScreen.swift |
| matched | token | `groups.create.fontWeight.title` | medium (SOURCED) | sheet title weight 'new group' | `Tokens.…groupsCreateFontWeightTitle` in GroupCreateScreen.swift |
| matched | copy | `groups.create.titleEdit` | “edit group” (SOURCED) |  | `Copy.…groupsCreateTitleEdit` in GroupCreateScreen.swift |
| matched | token | `groups.create.radius.cover` | 7 pt (SOURCED) | cover-photo placeholder corner radius | `Tokens.…groupsCreateRadiusCover` in GroupCreateScreen.swift |
| matched | token | `groups.create.color.cover` | #494949 (SOURCED) | cover-photo placeholder fill (before a photo is chosen) | `Tokens.…groupsCreateColorCover` in GroupCreateScreen.swift |
| matched | token | `icon.global.camera` | ios: camera.fill; android: Rounded.PhotoCamera (PLATFORM) | camera (composer button, row quick-camera, camera tab) | `Tokens.…globalCamera` in FloatingTabBar.swift, GroupCreateScreen.swift |
| matched | token | `groups.create.size.coverGlyph` | 21 pt (SOURCED) | camera glyph (icon.global.camera, white) centred in the cover placeholder: glyph height | `Tokens.…groupsCreateSizeCoverGlyph` in GroupCreateScreen.swift |
| matched | copy | `groups.create.cover.accessibilityLabel` | “add a cover photo” (SOURCED) |  | `Copy.…groupsCreateCoverAccessibilityLabel` in GroupCreateScreen.swift |
| matched | copy | `groups.create.cover.changeAccessibilityLabel` | “change cover photo” (SOURCED) |  | `Copy.…groupsCreateCoverChangeAccessibilityLabel` in GroupCreateScreen.swift |
| matched | token | `auth.profile.layout.avatarPicker` | ios: PhotosPicker (SwiftUI) / PHPickerViewController, single image, no library permission; android: ActivityResultContracts.PickVisualMedia(ImageOnly), no RE… (PLATFORM) | avatar picker | PhotosPicker (single image, no library permission); empty circle controlRaised + person glyph |
| matched | token | `groups.create.color.field` | #141414 (SOURCED) | single-line text field fill on black ('name group (optional)'); reused by every form field on black (auth.*… | `Tokens.…groupsCreateColorField` in FormField.swift |
| matched | token | `size.global.fieldHeight` | 44 pt (SOURCED) | single-line form text field height | `Tokens.…globalFieldHeight` in FormField.swift |
| matched | token | `radius.global.field` | 12 pt (SOURCED) | single-line form text field corners ('name group (optional)') | `Tokens.…globalField` in FormField.swift |
| matched | token | `groups.create.fontSize.fieldText` | 15 pt (SOURCED) | typed text in the form field (centred) | `Tokens.…groupsCreateFontSizeFieldText` in TextRoles.swift |
| matched | token | `groups.create.fontWeight.fieldText` | bold (SOURCED) | typed text weight in the form field | `Tokens.…groupsCreateFontWeightFieldText` in TextRoles.swift |
| matched | token | `color.global.textSecondary` | #969696 (SOURCED) | secondary text, placeholders ('start typing...'), inactive tab-bar glyphs, chevrons inside capsules | `Tokens.…globalTextSecondary` in CheckRow.swift, EmptyStateView.swift, FloatingTabBar.swift |
| matched | copy | `groups.create.name.placeholder` | “name group” (SOURCED) |  | `Copy.…groupsCreateNamePlaceholder` in GroupCreateScreen.swift |
| matched | copy | `groups.create.name.accessibilityLabel` | “group name” (SOURCED) |  | `Copy.…groupsCreateNameAccessibilityLabel` in GroupCreateScreen.swift |
| matched | token | `fontSize.global.sectionLabel` | 16 pt (SOURCED) | section label ('suggested friends'), secondary color | `Tokens.…globalSectionLabel` in TextRoles.swift |
| matched | token | `fontWeight.global.sectionLabel` | semibold (SOURCED) | section label | `Tokens.…fontWeightGlobalSectionLabel` in TextRoles.swift |
| matched | token | `groups.screen.color.segmentTrack` | #111111 (SOURCED) | segmented control track fill (on black) | `Tokens.…groupsScreenColorSegmentTrack` in SegmentedPills.swift |
| matched | token | `groups.screen.size.segmentHeight` | 41.5 pt (SOURCED) | segmented control track height ('pics / wall / recaps'); also the group-type picker in groups.create | `Tokens.…groupsScreenSizeSegmentHeight` in SegmentedPills.swift |
| matched | token | `color.global.surfaceLight` | #FFFFFF (SOURCED) | light pill fill: secondary buttons ('invite more friends', 'enable', 'new recap'), selected segment pill, '… | `Tokens.…globalSurfaceLight` in LightPill.swift, SegmentedPills.swift |
| matched | token | `groups.screen.size.segmentInset` | 4 pt (SOURCED) | inset of the selected pill inside the track (selected pill height 33.5 pt) | `Tokens.…groupsScreenSizeSegmentInset` in SegmentedPills.swift |
| matched | token | `color.global.onSurfaceLight` | #000000 (SOURCED) | label on the light pill (secondary buttons, selected segment, 'today') | `Tokens.…globalOnSurfaceLight` in LightPill.swift, SegmentedPills.swift |
| matched | token | `groups.screen.fontSize.segmentLabel` | 14.5 pt (SOURCED) | segment labels ('pics', 'wall', 'recaps'): bold, white unselected / black selected | `Tokens.…groupsScreenFontSizeSegmentLabel` in SegmentedPills.swift |
| matched | token | `groups.screen.fontWeight.segmentLabel` | bold (SOURCED) | segment label weight | `Tokens.…groupsScreenFontWeightSegmentLabel` in SegmentedPills.swift |
| matched | copy | `groups.create.type.friends` | “friends” (SOURCED) |  | `Copy.…groupsCreateTypeFriends` in GroupCreateModel.swift |
| matched | copy | `groups.create.type.family` | “family” (SOURCED) |  | `Copy.…groupsCreateTypeFamily` in GroupCreateModel.swift |
| matched | copy | `groups.create.type.roommates` | “roommates” (SOURCED) |  | `Copy.…groupsCreateTypeRoommates` in GroupCreateModel.swift |
| matched | copy | `groups.create.type.custom` | “custom” (SOURCED) |  | `Copy.…groupsCreateTypeCustom` in GroupCreateModel.swift |
| matched | token | `color.global.accent` | #CDFD07 (SOURCED) | brand lime: composer camera button, primary buttons, coach tooltips, toasts, shutter ring, 'today' bar | `Tokens.…globalAccent` in OnboardingTitle.swift, PrimaryButton.swift, Toast.swift |
| matched | token | `color.global.onAccent` | #000000 (SOURCED) | text and glyphs on lime: camera glyph on the composer button, primary button labels, tooltip text | `Tokens.…globalOnAccent` in PrimaryButton.swift, Toast.swift |
| matched | token | `size.global.buttonHeight` | 45 pt (SOURCED) | full-width primary button in a form ('create group') | `Tokens.…globalButtonHeight` in PrimaryButton.swift |
| matched | token | `radius.global.button` | 14 pt (SOURCED) | primary (lime) button corners — not a full pill | `Tokens.…globalButton` in PrimaryButton.swift, TextRoles.swift |
| matched | token | `groups.create.color.buttonDisabledFill` | #201D21 (SOURCED) | primary button while its form is incomplete ('continue' with an empty name) | `Tokens.…groupsCreateColorButtonDisabledFill` in PrimaryButton.swift |
| matched | token | `groups.create.color.buttonDisabledLabel` | #49464A (SOURCED) | label of the disabled primary button | `Tokens.…groupsCreateColorButtonDisabledLabel` in PrimaryButton.swift |
| matched | token | `groups.create.color.hud` | #0C0C0C (SOURCED) | Loading HUD square fill (on black) | `Tokens.…groupsCreateColorHud` in LoadingHUD.swift |
| matched | token | `groups.create.size.hud` | 100 pt (SOURCED) | Loading HUD square side | `Tokens.…groupsCreateSizeHud` in LoadingHUD.swift |
| matched | token | `groups.create.fontSize.hudLabel` | 15 pt (SOURCED) | 'Loading' label under the spinner in the HUD | `Tokens.…groupsCreateFontSizeHudLabel` in TextRoles.swift |
| matched | copy | `groups.create.hud.loading` | “Loading” (SOURCED) |  | `Copy.…groupsCreateHudLoading` in LoadingHUD.swift |
| matched | token | `auth.phone.layout.inlineError` | presentation: system alert: iOS UIAlertController .alert / SwiftUI .alert, Android M3 AlertDialog; not dismissible by tapping outside; title: none: the auth.… (SOURCED) | how a field-level error (wrong number, wrong or expired code, invalid date) is presented on the sign-up scr… | `formErrorAlert` (Components/FormErrorAlert.swift): system alert, no title, the error sentence as its message, one `auth.phone.error.dismiss` button (+ haptic.global.error) |
| matched | copy | `groups.create.error.failed` | “your group wasn’t created. try again in a moment.” (SOURCED) |  | `Copy.…groupsCreateErrorFailed` in GroupCreateModel.swift |
| matched | copy | `groups.create.error.saveFailed` | “your changes didn’t save. try again in a moment.” (SOURCED) |  | `Copy.…groupsCreateErrorSaveFailed` in GroupCreateModel.swift |
| matched | copy | `groups.create.error.cover` | “your cover didn’t upload. try again, or create the group without it.” (SOURCED) |  | `Copy.…groupsCreateErrorCover` in GroupCreateModel.swift |
| matched | copy | `groups.create.offline` | “you’re offline. connect to the internet and try again.” (SOURCED) |  | `Copy.…groupsCreateOffline` in GroupCreateModel.swift |
| matched | token | `easing.global.native` | keyboard: system; alert: system; activityIndicator: system (ProgressView / CircularProgressIndicator); scrollIndicator: system; navigationPush: system (Navig… (PLATFORM) | motion of native components Yope uses; their curves and durations are the platform's | system push / sheet / alert animations |
| matched | token | `spring.global.sheetPresent` | response: 0.3441; dampingFraction: 4.564 (SOURCED) | sheet presentation spring (response, dampingFraction) | native .sheet presentation (the token keeps the system curve for native sheets) |
| matched | token | `duration.global.navigationPush` | 100 ms (SOURCED) | horizontal push to the next screen ('new group' → new group chat after create) | system NavigationStack push |
| matched | token | `spring.global.platformDefault.ios` | response: 0.55; dampingFraction: 1 (PLATFORM) | iOS default animation (SwiftUI Animation.default) for custom motion whose Yope curve was not measurable | `Tokens.…globalPlatformDefaultIos` in SegmentedPills.swift, Toast.swift |
| n/a | token | `spring.global.platformDefault.android` | response: 0.16223; dampingFraction: 1 (PLATFORM) | Android default spring (Compose spring() defaults) for custom motion whose Yope curve was not measurable | Android only |
| matched | token | `layout.global.reduceMotion` | ios: UIAccessibility.isReduceMotionEnabled / @Environment(\.accessibilityReduceMotion); android: Settings.Global.ANIMATOR_DURATION_SCALE == 0 or ValueAnimato… (PLATFORM) | Reduce Motion substitution rule for every token animation (implemented by DSAnimation.reducedMotion / dsMot… | system transitions follow Reduce Motion; custom motion through dsAnimation / dsTransition (cross-fade substitutes) |
| matched | token | `haptic.global.select` | ios: selection; android: SEGMENT_TICK (PLATFORM) | a recipient / group toggled, a segmented choice, picker scrubbing | `Tokens.…globalSelect` in CheckRow.swift, SegmentedPills.swift |
| matched | token | `haptic.global.success` | ios: notification.success; android: CONFIRM (PLATFORM) | any task completed successfully (same generator as send) | `Tokens.…globalSuccess` in GroupCreateScreen.swift |
| matched | token | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | a task failed (send failed) | `Tokens.…globalError` in BlockConfirmation.swift, GroupCreateScreen.swift |

## Approximations

- Loading HUD spinner–label gap: platform stack spacing (not measured).
