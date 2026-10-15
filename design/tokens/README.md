# Design tokens — foundations naming map

`design/tokens/global.json` holds the app-wide foundations: pseudo-surfaces `global` (every app screen;
Yope is the reference) and `global.system` (native components on system surfaces; Apple HIG / Material 3),
see `docs/SURFACES.md`. Screen builders and the per-surface consolidation passes **reference these names
instead of copying their values**. A surface file (`design/tokens/<group>.json`) adds a token only when its
own reference measured something different for that surface (and says so in `notes`).

Every value traces to evidence (fields `evidence`, `method`, `level`); conflicts and how they were resolved
are in `design/MERGE_DECISIONS.md` → "Foundations"; contrast results in `design/CONTRAST.md`.
`node tools/designgen.mjs --check` validates; `node tools/designgen.mjs` generates the code below.

## How to use the names

- **Code identifiers.** `tools/designgen.mjs` drops the leading category word and camel-cases the rest:
  `color.global.textSecondary` → `Tokens.Colors.globalTextSecondary` (Swift and Kotlin),
  `size.global.headerButton` → `Tokens.Sizes.globalHeaderButton`, `icon.global.back` →
  `Tokens.Icons.globalBack` (SF Symbol name on iOS, `ImageVector` on Android). Tokens of type `layout`
  become a nested enum / object of constants: `layout.global.textStyleMap` →
  `Tokens.Layouts.GlobalTextStyleMap.body`. TypeScript reads `tokens["color.global.textSecondary"]`.
- **BLOCKED** tokens exist only in debug builds (`BlockedTokens`); a release build that uses one fails to
  compile. They mark a gap and name the smallest capture that closes it.
- **A text role** is four tokens with the same role name: `fontSize.global.<role>`,
  `fontWeight.global.<role>` (where measured), `lineHeight.global.<role>` (where measured; otherwise the
  platform's default leading for that size), and the Dynamic Type style it scales with in
  `layout.global.textStyleMap.<role>`. iOS: `DSTextStyle(family: Tokens.Fonts.globalFamily, size:
  Tokens.FontSizes.globalBody, weight: Tokens.FontWeights.globalBody, relativeTo: .body)`. Android: the
  `fontSize` tokens are emitted in sp and scale with the system font scale.
- **Platform pairs.** Where iOS and Android values differ, the name ends in `.ios` / `.android`
  (`size.global.minTouchTarget.ios` 44 pt, `.android` 48 dp) or the token is a `layout` with `ios` /
  `android` keys (`radius.global.sheet`, `haptic.global.longPressStart`).
- **Dark only.** Every surface renders in the dark appearance (`layout.global.appearance`); system
  colors are recorded with their dark values.

## Quick role finder

| need | token(s) |
|---|---|
| screen background (group, chat, profile grid) / (home, sheets, camera, sign-up) | `color.global.background` / `color.global.backgroundDeep` |
| circle button, capsule, text-field fill on #171717 / on black | `color.global.control` / `color.global.controlOnDeep` |
| selected pill (tab, inner header pill) | `color.global.controlRaised` |
| primary / secondary text, placeholder, inactive glyph | `color.global.textPrimary` / `color.global.textSecondary` |
| primary button: fill, label, height, margin, corners | `color.global.accent`, `color.global.onAccent`, `size.global.buttonHeight` (form) or `.buttonHeightSheet` (sheet bottom), `size.global.buttonMarginH` / `.buttonMarginHSheet`, `radius.global.button`, text role `button` |
| white secondary pill: fill, label, shape | `color.global.surfaceLight`, `color.global.onSurfaceLight`, `radius.global.capsule` |
| selected check | `icon.global.check` in `color.global.selection`, `size.global.checkCircle`; unselected `icon.global.uncheck` |
| header | `size.global.headerButton`, `.headerInset`, `.headerGap`, `icon.global.back` / `.close` / `.more`, text role `headerTitle` (capsule) or `sheetTitle` (sheet) |
| list cards | `radius.global.card`, `size.global.screenMargin`, `size.global.listGap`, `size.global.avatarList`, text roles `listTitle` / `listSubtitle` |
| photos, viewfinder | `radius.global.photo`, `radius.global.viewfinder`, text roles `overlayTime` / `overlayTimeCamera` |
| tab bar | `size.global.tabBar*`, `radius.global.capsule`, `color.global.control` / `.controlRaised`, `icon.global.chats` / `.camera` / `.wall` |
| empty state | text roles `emptyTitle` / `emptyDetail`, `color.global.surfaceLight` pill |
| motion | `duration.global.sheetPresent`, `duration.global.photoSwipe`, `duration.global.navigationPush`, native components `easing.global.native`, defaults `spring.global.platformDefault.ios` / `.android`, Reduce Motion `layout.global.reduceMotion` |
| haptics | `haptic.global.select`, `.send` (confirm / send), `.success`, `.warning`, `.error`, `.longPressStart`, `.reaction`, `.shutter` (none) |
| system surfaces (settings, safety, permissions) | `color.global.system.ios` (semantic API names), `color.global.system.*` (M3 roles), `color.global.destructive`, `radius.global.sheet`, `layout.global.system.typography`, `easing.global.system.standard`, `duration.global.system.scale` |
| accessibility | `size.global.minTouchTarget.*`, `layout.global.contrast.text` / `.largeText` / `.nonText` |

## All global tokens

### Colors — app surfaces

| token | value | level | use for | code |
|---|---|---|---|---|
| `color.global.background` | #171717 | SOURCED | screen background of group, chat and profile-grid screens (dark gray, not black) | `Tokens.Colors.globalBackground` |
| `color.global.backgroundDeep` | #000000 | SOURCED | screen background of the home list, sheets ('new group', 'send to...'), camera, sign-up, profile 'pics' grid, group photo cards (2026) | `Tokens.Colors.globalBackgroundDeep` |
| `color.global.control` | #2E2E2E | SOURCED | control fill on #171717: header circle buttons, header title capsule, floating tab-bar capsule, composer text field | `Tokens.Colors.globalControl` |
| `color.global.controlRaised` | #434343 | SOURCED | raised fill: selected tab pill, inner pill inside the header capsule, inactive page dots | `Tokens.Colors.globalControlRaised` |
| `color.global.controlOnDeep` | #101010 | SOURCED | header circle icon buttons on black screens and sheets (✕, download) | `Tokens.Colors.globalControlOnDeep` |
| `color.global.textPrimary` | #FFFFFF | SOURCED | primary text and glyphs | `Tokens.Colors.globalTextPrimary` |
| `color.global.textSecondary` | #969696 | SOURCED | secondary text, placeholders ('start typing...'), inactive tab-bar glyphs, chevrons inside capsules | `Tokens.Colors.globalTextSecondary` |
| `color.global.accent` | #CDFD07 | SOURCED | brand lime: composer camera button, primary buttons, coach tooltips, toasts, shutter ring, 'today' bar | `Tokens.Colors.globalAccent` |
| `color.global.onAccent` | #000000 | SOURCED | text and glyphs on lime: camera glyph on the composer button, primary button labels, tooltip text | `Tokens.Colors.globalOnAccent` |
| `color.global.accentSecondary` | #FE1F84 | SOURCED | pink: profile card outline and name sticker | `Tokens.Colors.globalAccentSecondary` |
| `color.global.surfaceLight` | #FFFFFF | SOURCED | light pill fill: secondary buttons ('invite more friends', 'enable', 'new recap'), selected segment pill, 'today' pill | `Tokens.Colors.globalSurfaceLight` |
| `color.global.onSurfaceLight` | #000000 | SOURCED | label on the light pill (secondary buttons, selected segment, 'today') | `Tokens.Colors.globalOnSurfaceLight` |
| `color.global.selection` | #0091FF | PLATFORM | filled check circle on selected people / groups (Yope draws it in iOS system blue) | `Tokens.Colors.globalSelection` |
| `color.global.separator` | `#FFFFFF33` (1 px) | `#FFFFFF33` (1 px) | hairline between rows on app (Yope-referenced) surfaces | `Tokens.Colors.globalSeparator` |
| `color.global.scrim` | `#00000080` | `#00000080` | dimming layer behind sheets / over photos under text on app surfaces | `Tokens.Colors.globalScrim` |

### Colors — system surfaces (`global.system`)

| token | value | level | use for | code |
|---|---|---|---|---|
| `color.global.destructive` | #FF4245 | PLATFORM | destructive actions on system surfaces (delete account, block, leave, report) — iOS systemRed via Button(role: .destructive) | `Tokens.Colors.globalDestructive` |
| `color.global.system.ios` | groupedBackground: systemGroupedBackground; cell: secondarySystemGroupedBackground; label: label; secondaryLabel: secondaryLabel; placeholder: placeholderText; separator: separator; tint: systemBlue; destructive: systemRed | PLATFORM | semantic colors of native inset-grouped lists, alerts and sheets on system surfaces (settings.*, safety.*, system.permissions), iOS | `Tokens.Layouts.GlobalSystemIos.<key>` |
| `color.global.system.surface` | #141218 | PLATFORM | page / list container on Android system surfaces (role md.sys.color.surface, baseline dark scheme) | `Tokens.Colors.globalSystemSurface` |
| `color.global.system.surfaceContainerHigh` | #2B2930 | PLATFORM | M3 dialog container (role md.sys.color.surface-container-high, baseline dark scheme) | `Tokens.Colors.globalSystemSurfaceContainerHigh` |
| `color.global.system.surfaceContainerLow` | #1D1B20 | PLATFORM | M3 modal bottom sheet container (role md.sys.color.surface-container-low, baseline dark scheme) | `Tokens.Colors.globalSystemSurfaceContainerLow` |
| `color.global.system.onSurface` | #E6E0E9 | PLATFORM | list item label, dialog headline (role md.sys.color.on-surface, baseline dark scheme) | `Tokens.Colors.globalSystemOnSurface` |
| `color.global.system.onSurfaceVariant` | #CAC4D0 | PLATFORM | supporting text, leading icons, drag handle (role md.sys.color.on-surface-variant, baseline dark scheme) | `Tokens.Colors.globalSystemOnSurfaceVariant` |
| `color.global.system.outline` | #938F99 | PLATFORM | list divider (1 dp) (role md.sys.color.outline, baseline dark scheme) | `Tokens.Colors.globalSystemOutline` |
| `color.global.system.error` | #F2B8B5 | PLATFORM | error / destructive text and icons (role md.sys.color.error, baseline dark scheme) | `Tokens.Colors.globalSystemError` |
| `color.global.system.primary` | #D0BCFF | PLATFORM | dialog action labels, switches, selected controls (role md.sys.color.primary, baseline dark scheme) | `Tokens.Colors.globalSystemPrimary` |

### Appearance

| token | value | level | use for | code |
|---|---|---|---|---|
| `layout.global.appearance` | mode: dark only; ios: Info.plist UIUserInterfaceStyle = Dark; android: dark color scheme only | PLATFORM | appearance of every surface (app and system) | `Tokens.Layouts.GlobalAppearance.<key>` |

### Typography

| token | value | level | use for | code |
|---|---|---|---|---|
| `font.global.family` | system / system | PLATFORM | typeface of all text (SF Pro on iOS, Roboto on Android) | `Tokens.Fonts.globalFamily` |
| `fontSize.global.onboardingTitle` | 40 pt | SOURCED | onboarding / sign-up big title ('registrarse') | `Tokens.FontSizes.globalOnboardingTitle` |
| `fontWeight.global.onboardingTitle` | heavy | SOURCED | onboarding / sign-up big title | `Tokens.FontWeights.fontWeightGlobalOnboardingTitle` |
| `fontSize.global.sheetTitle` | 19.5 pt | SOURCED | sheet title centred between header circles ('send to...') | `Tokens.FontSizes.globalSheetTitle` |
| `fontWeight.global.sheetTitle` | bold | SOURCED | sheet title ('send to...') | `Tokens.FontWeights.fontWeightGlobalSheetTitle` |
| `fontSize.global.headerTitle` | 15 pt | SOURCED | group name in the header capsule | `Tokens.FontSizes.globalHeaderTitle` |
| `fontWeight.global.headerTitle` | bold | SOURCED | group name in the header capsule | `Tokens.FontWeights.fontWeightGlobalHeaderTitle` |
| `fontSize.global.listTitle` | 17.5 pt | SOURCED | row / card name on the home list ('kylee') | `Tokens.FontSizes.globalListTitle` |
| `fontWeight.global.listTitle` | bold | SOURCED | row / card name on the home list | `Tokens.FontWeights.fontWeightGlobalListTitle` |
| `fontSize.global.listSubtitle` | 14 pt | SOURCED | row subtitle ('new pic added · 9:43 AM'), secondary color | `Tokens.FontSizes.globalListSubtitle` |
| `fontWeight.global.listSubtitle` | regular | SOURCED | row subtitle | `Tokens.FontWeights.fontWeightGlobalListSubtitle` |
| `fontSize.global.body` | 17 pt | SOURCED | chat message text in bubbles (body text) | `Tokens.FontSizes.globalBody` |
| `fontWeight.global.body` | regular | SOURCED | chat message text | `Tokens.FontWeights.fontWeightGlobalBody` |
| `fontSize.global.button` | 15 pt | SOURCED | primary button label ('create group', 'send') | `Tokens.FontSizes.globalButton` |
| `fontWeight.global.button` | semibold | SOURCED | primary button label | `Tokens.FontWeights.fontWeightGlobalButton` |
| `fontSize.global.caption` | 12 pt | SOURCED | small meta text: voice-message duration ('00:38'), legal footer under sign-up | `Tokens.FontSizes.globalCaption` |
| `fontWeight.global.caption` | semibold | SOURCED | voice-message duration ('00:38') | `Tokens.FontWeights.fontWeightGlobalCaption` |
| `lineHeight.global.caption` | 15.2 pt | SOURCED | line pitch of the 3-line legal footer under sign-up (12 pt text) | `Tokens.LineHeights.globalCaption` |
| `fontSize.global.overlayTime` | 21 pt | SOURCED | hour / time overlay centred on a photo in the chat ('10:00 PM') | `Tokens.FontSizes.globalOverlayTime` |
| `fontWeight.global.overlayTime` | heavy | SOURCED | time overlay on a photo | `Tokens.FontWeights.fontWeightGlobalOverlayTime` |
| `fontSize.global.overlayTimeCamera` | 26 pt | SOURCED | hour overlay on the camera viewfinder and the send-to preview ('5:00 PM') | `Tokens.FontSizes.globalOverlayTimeCamera` |
| `fontWeight.global.overlayTimeCamera` | heavy | SOURCED | hour overlay on the viewfinder | `Tokens.FontWeights.fontWeightGlobalOverlayTimeCamera` |
| `fontSize.global.placeholder` | 17 pt | SOURCED | text-field placeholder ('start typing...') | `Tokens.FontSizes.globalPlaceholder` |
| `fontSize.global.sectionLabel` | 16 pt | SOURCED | section label ('suggested friends'), secondary color | `Tokens.FontSizes.globalSectionLabel` |
| `fontWeight.global.sectionLabel` | semibold | SOURCED | section label | `Tokens.FontWeights.fontWeightGlobalSectionLabel` |
| `fontSize.global.emptyTitle` | 16 pt | SOURCED | empty-state title ('you created group') | `Tokens.FontSizes.globalEmptyTitle` |
| `fontWeight.global.emptyTitle` | bold | SOURCED | empty-state title | `Tokens.FontWeights.fontWeightGlobalEmptyTitle` |
| `fontSize.global.emptyDetail` | 14 pt | SOURCED | empty-state detail line ('and added mẹ, Anh'), italic | `Tokens.FontSizes.globalEmptyDetail` |
| `layout.global.textStyleMap` | onboardingTitle: largeTitle; sheetTitle: title3; headerTitle: subheadline; listTitle: headline; listSubtitle: subheadline; body: body; button: subheadline; caption: caption; overlayTime: title2; overlayTimeCamera: title; placeholder: body; sectionLabel: callout; emptyTitle: callout; emptyDetail: subheadline | PLATFORM | iOS Dynamic Type text style each fontSize.global.<role> scales with (SwiftUI Font.TextStyle case; DSTextStyle.relativeTo) | `Tokens.Layouts.GlobalTextStyleMap.<key>` |
| `layout.global.system.typography` | ios: built-in text styles (Font.TextStyle) on native lists, alerts and sheets; android: MaterialTheme.typography (M3 baseline type scale: list label bodyLarge, supporting bodyMedium, dialog headline headlineSmall, actions labelLarge) | PLATFORM | text styles on system surfaces | `Tokens.Layouts.GlobalSystemTypography.<key>` |

### Radii

| token | value | level | use for | code |
|---|---|---|---|---|
| `radius.global.capsule` | shape: capsule; radius: height / 2 | SOURCED | full pill: header title capsule, composer text field, chat bubbles, tab-bar capsule, tooltip ends, white secondary pills | `Tokens.Layouts.GlobalCapsule.<key>` |
| `radius.global.card` | 17 pt | SOURCED | list card corners (home conversation / group cards, inline permission card) | `Tokens.Radii.globalCard` |
| `radius.global.button` | 14 pt | SOURCED | primary (lime) button corners — not a full pill | `Tokens.Radii.globalButton` |
| `radius.global.field` | 12 pt | SOURCED | single-line form text field corners ('name group (optional)') | `Tokens.Radii.globalField` |
| `radius.global.photo` | 15 pt | SOURCED | photo corners in the thread and in grids of walls | `Tokens.Radii.globalPhoto` |
| `radius.global.viewfinder` | 18.5 pt | SOURCED | camera viewfinder corners (full-width viewfinder) | `Tokens.Radii.globalViewfinder` |
| `radius.global.sheet` | ios: system; android: 28 | PLATFORM | sheet top corners (Yope's sheet radius was not measured) | `Tokens.Layouts.GlobalSheet.<key>` |

### Sizes

| token | value | level | use for | code |
|---|---|---|---|---|
| `size.global.headerButton` | 44 pt | SOURCED | circle icon buttons in headers (back, close, download, film-strip, search) | `Tokens.Sizes.globalHeaderButton` |
| `size.global.headerInset` | 11.5 pt | SOURCED | screen edge to the first / last header circle | `Tokens.Sizes.globalHeaderInset` |
| `size.global.headerGap` | 7.3 pt | SOURCED | gap between the back circle and the header title capsule | `Tokens.Sizes.globalHeaderGap` |
| `size.global.screenMargin` | 12 pt | SOURCED | side margin of full-width content (home list cards); edge elements sit at the same inset | `Tokens.Sizes.globalScreenMargin` |
| `size.global.listGap` | 7.5 pt | SOURCED | vertical gap between stacked list cards | `Tokens.Sizes.globalListGap` |
| `size.global.buttonHeight` | 45 pt | SOURCED | full-width primary button in a form ('create group') | `Tokens.Sizes.globalButtonHeight` |
| `size.global.buttonHeightSheet` | 47 pt | SOURCED | primary action button at the bottom of a sheet ('send ⓝ') | `Tokens.Sizes.globalButtonHeightSheet` |
| `size.global.buttonMarginH` | 19 pt | SOURCED | side margin of the form primary button | `Tokens.Sizes.globalButtonMarginH` |
| `size.global.buttonMarginHSheet` | 27 pt | SOURCED | side margin of the sheet-bottom primary button | `Tokens.Sizes.globalButtonMarginHSheet` |
| `size.global.fieldHeight` | 44 pt | SOURCED | single-line form text field height | `Tokens.Sizes.globalFieldHeight` |
| `size.global.avatarList` | 64 pt | SOURCED | avatar in a home list card | `Tokens.Sizes.globalAvatarList` |
| `size.global.avatarPicker` | 40 pt | SOURCED | avatar in a people-picker row | `Tokens.Sizes.globalAvatarPicker` |
| `size.global.avatarSmall` | 32.6 pt | SOURCED | small avatar: chat sender, send-to recipient row | `Tokens.Sizes.globalAvatarSmall` |
| `size.global.avatarHeader` | 28 pt | SOURCED | group avatar inside the header capsule | `Tokens.Sizes.globalAvatarHeader` |
| `size.global.checkCircle` | 24 pt | SOURCED | selection circle (empty ring / filled check) in pickers and recipient rows | `Tokens.Sizes.globalCheckCircle` |
| `size.global.tabBarWidth` | 344 pt | SOURCED | floating tab-bar capsule width | `Tokens.Sizes.globalTabBarWidth` |
| `size.global.tabBarHeight` | 58 pt | SOURCED | floating tab-bar capsule height | `Tokens.Sizes.globalTabBarHeight` |
| `size.global.tabBarInset` | 22 pt | SOURCED | tab-bar side inset from the screen edges | `Tokens.Sizes.globalTabBarInset` |
| `size.global.tabBarSelectedWidth` | 74 pt | SOURCED | selected-tab pill width (fill color.global.controlRaised) | `Tokens.Sizes.globalTabBarSelectedWidth` |
| `size.global.tabBarSelectedHeight` | 48 pt | SOURCED | selected-tab pill height | `Tokens.Sizes.globalTabBarSelectedHeight` |
| `size.global.tabBarIcon` | 21 pt | SOURCED | tab glyph size (20-23 pt measured) | `Tokens.Sizes.globalTabBarIcon` |
| `size.global.tabBarAvatar` | 34 pt | SOURCED | 'me' tab avatar | `Tokens.Sizes.globalTabBarAvatar` |
| `size.global.minTouchTarget.ios` | 44 pt | VERIFIED | minimum hit area of any control, iOS (default control size) | `Tokens.Sizes.globalMinTouchTargetIos` |
| `size.global.minTouchTarget.iosMinimum` | 28 pt | VERIFIED | absolute minimum control size, iOS | `Tokens.Sizes.globalMinTouchTargetIosMinimum` |
| `size.global.minTouchTarget.android` | 48 dp | VERIFIED | minimum touch target, Android | `Tokens.Sizes.globalMinTouchTargetAndroid` |
| `size.global.minTouchTarget.androidSpacing` | 8 dp | VERIFIED | spacing between touch targets, Android | `Tokens.Sizes.globalMinTouchTargetAndroidSpacing` |

### Motion

| token | value | level | use for | code |
|---|---|---|---|---|
| `duration.global.sheetPresent` | 215 ms | SOURCED | bottom-sheet presentation, first movement to rest (rise ≈ 100 ms to an overshoot ≈ 16 pt past rest, settle ≈ 100 ms) | `Tokens.Durations.globalSheetPresent` |
| `spring.global.sheetPresentObserved` | overshootPt: 16; timeToPeakMs: 100; settleMs: 100 | SOURCED | observed shape of the sheet presentation: overshoot past rest, time to the peak, time from the peak to rest | `Tokens.Layouts.GlobalSheetPresentObserved.<key>` |
| `spring.global.sheetPresent` | response 0.3441, dampingFraction 1.0 | same | sheet presentation spring (response, dampingFraction) | `Tokens.Springs.globalSheetPresent` |
| `duration.global.photoSwipe` | 167 ms | SOURCED | horizontal swipe to the adjacent photo in the viewer, first movement to settled (gesture-driven) | `Tokens.Durations.globalPhotoSwipe` |
| `easing.global.photoSwipe` | ios: system paging scroll physics; android: Compose HorizontalPager default fling | PLATFORM | settle curve of the photo swipe after the finger lifts | `Tokens.Layouts.GlobalPhotoSwipe.<key>` |
| `duration.global.navigationPush` | 100 ms | SOURCED | horizontal push to the next screen ('new group' → new group chat after create) | `Tokens.Durations.globalNavigationPush` |
| `easing.global.native` | keyboard: system; alert: system; activityIndicator: system (ProgressView / CircularProgressIndicator); scrollIndicator: system; navigationPush: system (NavigationStack / Compose Navigation default); sheet: system (.sheet / ModalBottomSheet) | PLATFORM | motion of native components Yope uses; their curves and durations are the platform's | `Tokens.Layouts.GlobalNative.<key>` |
| `spring.global.platformDefault.ios` | response 0.55, damping 1 | PLATFORM | iOS default animation (SwiftUI Animation.default) for custom motion whose Yope curve was not measurable | `Tokens.Springs.globalPlatformDefaultIos` |
| `spring.global.platformDefault.android` | response 0.16223, damping 1 | PLATFORM | Android default spring (Compose spring() defaults) for custom motion whose Yope curve was not measurable | `Tokens.Springs.globalPlatformDefaultAndroid` |
| `easing.global.system.standard` | cubic-bezier(0.2, 0, 0, 1) | PLATFORM | M3 standard easing for custom transitions on Android system surfaces | `Tokens.Easings.globalSystemStandard` |
| `duration.global.system.scale` | short1: 50; short2: 100; short3: 150; short4: 200; medium1: 250; medium2: 300; medium3: 350; medium4: 400; long1: 450; long2: 500; long3: 550; long4: 600; extraLong1: 700; extraLong2: 800; extraLong3: 900; extraLong4: 1000 | PLATFORM | M3 duration scale (ms) for custom transitions on Android system surfaces | `Tokens.Layouts.GlobalSystemScale.<key>` |
| `layout.global.reduceMotion` | ios: UIAccessibility.isReduceMotionEnabled / @Environment(\.accessibilityReduceMotion); android: Settings.Global.ANIMATOR_DURATION_SCALE == 0 or ValueAnimator.areAnimatorsEnabled() == false (Accessibility > Remove animations); substitute: replace x/y/z movement with a cross-fade of the same token duration; springs lose their bounce (dampingFraction 1); drop zoom, scale, peripheral and automatic repeating animation; never animate into or out of blur; motion that tracks the finger stays | PLATFORM | Reduce Motion substitution rule for every token animation (implemented by DSAnimation.reducedMotion / dsMotion / dsTransition and Motion.kt dsMotionSpec) | `Tokens.Layouts.GlobalReduceMotion.<key>` |

### Haptics

| token | value | level | use for | code |
|---|---|---|---|---|
| `haptic.global.select` | selection / SEGMENT_TICK | PLATFORM | a recipient / group toggled, a segmented choice, picker scrubbing | `Tokens.Haptics.globalSelect` |
| `haptic.global.send` | notification.success / CONFIRM | PLATFORM | confirm / send: a photo or message was sent | `Tokens.Haptics.globalSend` |
| `haptic.global.success` | notification.success / CONFIRM | PLATFORM | any task completed successfully (same generator as send) | `Tokens.Haptics.globalSuccess` |
| `haptic.global.warning` | notification.warning / CONFIRM | PLATFORM | a destructive action was confirmed (delete account, block, leave) | `Tokens.Haptics.globalWarning` |
| `haptic.global.error` | notification.error / REJECT | PLATFORM | a task failed (send failed) | `Tokens.Haptics.globalError` |
| `haptic.global.longPressStart` | ios: system (context menu plays its own haptic; no custom generator); android: LONG_PRESS | PLATFORM | a long press starts (context menu) | `Tokens.Layouts.GlobalLongPressStart.<key>` |
| `haptic.global.reaction` | ios: system (context menu plays its own haptic; no custom generator); android: LONG_PRESS | PLATFORM | the long press that opens the reaction picker on a photo | `Tokens.Layouts.GlobalReaction.<key>` |
| `haptic.global.shutter` | ios: none; android: none | PLATFORM | shutter press (photo / video capture) | `Tokens.Layouts.GlobalShutter.<key>` |

### Icons

| token | value | level | use for | code |
|---|---|---|---|---|
| `icon.global.back` | chevron.left / AutoMirrored.Rounded.KeyboardArrowLeft | PLATFORM | back (‹ in a header circle) | `Tokens.Icons.globalBack` |
| `icon.global.close` | xmark / Rounded.Close | PLATFORM | close / dismiss (✕ in a header circle on sheets) | `Tokens.Icons.globalClose` |
| `icon.global.more` | ellipsis / Rounded.MoreHoriz | PLATFORM | more (•••) | `Tokens.Icons.globalMore` |
| `icon.global.share` | square.and.arrow.up / Rounded.IosShare | PLATFORM | share (square + up arrow) | `Tokens.Icons.globalShare` |
| `icon.global.camera` | camera.fill / Rounded.PhotoCamera | PLATFORM | camera (composer button, row quick-camera, camera tab) | `Tokens.Icons.globalCamera` |
| `icon.global.flip` | arrow.triangle.2.circlepath / Rounded.Sync | PLATFORM | flip camera (two circular arrows in a circle) | `Tokens.Icons.globalFlip` |
| `icon.global.flashOff` | bolt.slash.fill / Rounded.FlashOff | PLATFORM | flash off (slashed bolt on the viewfinder) | `Tokens.Icons.globalFlashOff` |
| `icon.global.flashOn` | bolt / Rounded.FlashOn | PLATFORM | flash on (bolt) | `Tokens.Icons.globalFlashOn` |
| `icon.global.mic` | mic.fill / Rounded.Mic | PLATFORM | microphone (voice memo, voice message) | `Tokens.Icons.globalMic` |
| `icon.global.send` | paperplane / AutoMirrored.Rounded.Send | PLATFORM | send (paper plane in a circle) | `Tokens.Icons.globalSend` |
| `icon.global.download` | arrow.down.to.line / Rounded.Download | PLATFORM | download / save (arrow down to a line in a header circle) | `Tokens.Icons.globalDownload` |
| `icon.global.add` | plus / Rounded.Add | PLATFORM | add (+ in a header circle) | `Tokens.Icons.globalAdd` |
| `icon.global.check` | checkmark.circle.fill / Rounded.CheckCircle | PLATFORM | selected (filled check circle, color.global.selection) | `Tokens.Icons.globalCheck` |
| `icon.global.uncheck` | circle / Rounded.RadioButtonUnchecked | PLATFORM | not selected (empty ring) | `Tokens.Icons.globalUncheck` |
| `icon.global.checkmark` | checkmark / Rounded.Check | PLATFORM | done / posted (bare check, e.g. in the 'posted in the wall' toast) | `Tokens.Icons.globalCheckmark` |
| `icon.global.chevron` | chevron.right / AutoMirrored.Rounded.KeyboardArrowRight | PLATFORM | disclosure / forward (› at the end of the header capsule) | `Tokens.Icons.globalChevron` |
| `icon.global.chevronDown` | chevron.down / Rounded.ExpandMore | PLATFORM | expand / dismiss down (⌄) | `Tokens.Icons.globalChevronDown` |
| `icon.global.settings` | gearshape / Rounded.Settings | PLATFORM | settings entry | `Tokens.Icons.globalSettings` |
| `icon.global.group` | person.2.fill / Rounded.Group | PLATFORM | group / people | `Tokens.Icons.globalGroup` |
| `icon.global.wall` | film.stack.fill / Rounded.VideoLibrary | PLATFORM | walls / recaps tab (film frame with stacked lines, filled) | `Tokens.Icons.globalWall` |
| `icon.global.grid` | square.grid.2x2 / Rounded.GridView | PLATFORM | grid view (2×2 rounded squares) | `Tokens.Icons.globalGrid` |
| `icon.global.recap` | film.stack / Rounded.VideoLibrary | PLATFORM | recap entry in a header circle (film frame with stacked lines, outline) | `Tokens.Icons.globalRecap` |
| `icon.global.lock` | lock.fill / Rounded.Lock | PLATFORM | private / restricted | `Tokens.Icons.globalLock` |
| `icon.global.search` | magnifyingglass / Rounded.Search | PLATFORM | search (home header circle) | `Tokens.Icons.globalSearch` |
| `icon.global.edit` | pencil / Rounded.Edit | PLATFORM | edit (pencil in a header circle) | `Tokens.Icons.globalEdit` |
| `icon.global.link` | link / Rounded.Link | PLATFORM | invite link | `Tokens.Icons.globalLink` |
| `icon.global.report` | flag.fill / Rounded.Flag | PLATFORM | report (menu item, destructive color) | `Tokens.Icons.globalReport` |
| `icon.global.person` | person.fill / Rounded.Person | PLATFORM | default avatar silhouette | `Tokens.Icons.globalPerson` |
| `icon.global.play` | play.fill / Rounded.PlayArrow | PLATFORM | play (voice message) | `Tokens.Icons.globalPlay` |
| `icon.global.gallery` | photo.on.rectangle / Rounded.PhotoLibrary | PLATFORM | photo library (camera, when no thumbnail) | `Tokens.Icons.globalGallery` |
| `icon.global.chats` | bubble.left.and.bubble.right.fill / Rounded.Forum | PLATFORM | chats tab (two overlapping bubbles) | `Tokens.Icons.globalChats` |
| `icon.global.calendar` | calendar / Rounded.CalendarMonth | PLATFORM | calendar circle in the group header | `Tokens.Icons.globalCalendar` |
| `icon.global.leave` | rectangle.portrait.and.arrow.right / AutoMirrored.Rounded.Logout | PLATFORM | leave group (menu item, destructive color) | `Tokens.Icons.globalLeave` |
| `icon.global.variantRule` | tabBar: fill variant; header: outline variant unless the reference glyph is filled | PLATFORM | which SF Symbol variant a context uses | `Tokens.Layouts.GlobalVariantRule.<key>` |

### Accessibility (contrast thresholds; touch targets are under Sizes)

| token | value | level | use for | code |
|---|---|---|---|---|
| `layout.global.contrast.text` | ratio: 4.5; rule: text up to 17 pt (iOS) / below 18 sp (Android), not bold | VERIFIED | minimum contrast ratio: text up to 17 pt (iOS) / below 18 sp (Android), not bold | `Tokens.Layouts.GlobalContrastText.<key>` |
| `layout.global.contrast.largeText` | ratio: 3; rule: text 18 pt and larger, or bold at any size | VERIFIED | minimum contrast ratio: text 18 pt and larger, or bold at any size | `Tokens.Layouts.GlobalContrastLargeText.<key>` |
| `layout.global.contrast.nonText` | ratio: 3; rule: UI components and graphical objects against adjacent colors | VERIFIED | minimum contrast ratio: UI components and graphical objects against adjacent colors | `Tokens.Layouts.GlobalContrastNonText.<key>` |

## Not available yet (BLOCKED or not measured)

(separator, scrim and the sheet spring were sourced in the gap fill — MERGE_DECISIONS G2: Locket's list divider and sheet scrim, the iOS modal spring Locket ships.)

| need | status | smallest capture |
|---|---|---|
| placeholder / emptyDetail weight, legal-footer weight | not measured — no token | one lossless screenshot of the sign-up screen and of a text field |
| line heights other than `caption` | not measured — the platform default leading applies | one lossless screenshot of a multi-line Yope message bubble |
| sheet corner radius on iOS | system-drawn (`radius.global.sheet.ios = system`) | — |
| flash-on glyph from Yope | taken from Locket (`icon.global.flashOn`) | one Yope camera frame with flash on |
