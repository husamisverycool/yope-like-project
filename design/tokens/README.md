# Design tokens — foundations naming map

`design/tokens/global.json` holds the app-wide foundations of the redesign on **Retro** (docs/DESIGN_DIRECTION.md,
docs/REDESIGN_BRIEF.md): pseudo-surfaces `global` (every app screen; Retro is the reference, light and dark) and
`global.system` (native components on system surfaces; Apple HIG / Material 3, with Retro's own Android colour scheme).
Screen builders and the per-surface passes **reference these names instead of copying their values**, and build
screens from the components in `design/components.md`. A surface file (`design/tokens/<group>.json`) adds a token only
when Retro measured something specific for that surface (and says so in `notes`).

Every value traces to evidence (fields `evidence`, `method`, `level`) in `design/research/retro-visual.md`,
`design/research/retro-package-copy-motion.md` and `references/auto/retro/INDEX.md`; conflicts and how they were
resolved are in `design/MERGE_DECISIONS.md` → "Redesign — Foundations (R-*)"; contrast results in `design/CONTRAST.md`.
`node tools/designgen.mjs --check` validates; `node tools/designgen.mjs` generates the code below.

## How to use the names

- **Code identifiers.** `tools/designgen.mjs` drops the leading category word and camel-cases the rest:
  `color.global.textSecondary` → `Tokens.Colors.globalTextSecondary` (Swift and Kotlin),
  `size.global.headerButton` → `Tokens.Sizes.globalHeaderButton`, `icon.global.back` →
  `Tokens.Icons.globalBack` (SF Symbol name on iOS, `ImageVector` on Android). Tokens of type `layout`
  become a nested enum / object of constants: `layout.global.textStyleMap` →
  `Tokens.Layouts.GlobalTextStyleMap.body`. TypeScript reads `tokens["color.global.textSecondary"]`.
  (`fontWeight.*` keeps its prefix: `Tokens.FontWeights.fontWeightGlobalBody`.)
- **BLOCKED** tokens exist only in debug builds (`BlockedTokens`); a release build that uses one fails to
  compile. The foundations have none.
- **A text role** is up to four tokens with the same role name: `fontSize.global.<role>`,
  `fontWeight.global.<role>` (where measured), `lineHeight.global.<role>` (where measured; otherwise the
  platform's default leading for that size), and the Dynamic Type style it scales with in
  `layout.global.textStyleMap.<role>`. Its family is `font.global.family` (UI sans: SF Pro / Inter) unless the
  role is a display role (`headerTitle`, `displayMedium`, `displaySmall` → `font.global.display`). iOS:
  `DSTextStyle(family: Tokens.Fonts.globalFamily, size: Tokens.FontSizes.globalBody, weight:
  Tokens.FontWeights.fontWeightGlobalBody, relativeTo: .subheadline)`. Android: the `fontSize` tokens are sp
  and scale with the system font scale.
- **Platform pairs.** Unless a token has a `.android` (or `.ios`) sibling, its value applies on both platforms
  (Retro ships one identity on iOS and Android). Where Retro itself differs per platform, the Android value is
  a sibling named `….android` — `color.global.background.android` (#1C1C1E dark), `color.global.textSecondary.android`
  (black 50 % / white 60 %), `color.global.surfaceSecondary.android` (#F7F7F7 rows and chips),
  `fontSize.global.body.android` 14 / `lineHeight.global.body.android` 17 / `letterSpacing.global.body.android`
  −0.3 / `layout.global.variableWeight.android.body` 450, `lineHeight.global.listTitle.android`,
  `letterSpacing.global.listTitle.android`, `lineHeight.global.badge.android`, `letterSpacing.global.badge.android`
  — or the token is a `layout` with `ios` / `android` keys (`radius.global.sheet`, `layout.global.cornerStyle`,
  `haptic.global.tap`, `size.global.hairline`). Android `letterSpacing` applies only when the locale's script is
  Latin (Retro's rule), else 0.

## Appearance

The app **follows the system Light / Dark setting** (`layout.global.appearance`), as Retro does. Every colour that
differs between appearances is `{"light": "#…", "dark": "#…"}`:

- **iOS** — `Tokens.Colors.*` are dynamic `Color(light:dark:)` values that follow the trait collection; remove
  the forced dark appearance (`INFOPLIST_KEY_UIUserInterfaceStyle = Dark` in `ios/Config/App.xcconfig`,
  `.preferredColorScheme(.dark)`) so the system setting applies (Pass 3).
- **Android** — themed colours are `@Composable @ReadOnlyComposable` getters that read `LocalDsDarkTheme`, provided
  by `DsTheme(dark = isSystemInDarkTheme())`; wrap the app and every test host in `DsTheme`. Outside composition
  (draw lambdas, enum / top-level initialisers, notifications, Glance `ColorProvider`, `Application`) read
  `Tokens.ColorsLight.*` / `Tokens.ColorsDark.*` (both appearances as plain values).
- **Media stays dark.** The photo / story viewer, camera, postcard-style composer, recap preview and full-bleed
  photos are black in both appearances (`color.global.backgroundDeep`; Retro's viewer is black under a white
  sheet in light mode — TC-R3). Text and glyphs there use `color.global.textOnMedia` (#FFFFFF) and
  `color.global.textSecondary`; controls `color.global.controlOnDeep` (#262626); light pills
  `color.global.surfaceLight` / `color.global.onSurfaceLight`. Sheets presented over media follow the appearance.
- **Android page.** Android screens use `color.global.background.android` (Retro's default dark page #1C1C1E);
  iOS uses `color.global.background` (#000000 in every iOS capture). Retro's Android "true black" option is offered
  in Android Settings → Appearance → True Black (owner decision 21, MERGE OD21-*): while it is on, the dark appearance
  draws the page in `color.global.background.android.trueBlack` and the M3 background / surface in
  `color.global.system.surface.trueBlack` (both #000000; light values equal the defaults). Code reads the page through
  core:ui `PageRoles.page` (it follows `LocalDsTrueBlack`, provided by `DsTheme(trueBlack = …)` / `AppTheme`); outside
  composition pick the `Tokens.ColorsDark.*TrueBlack` value when `AppearanceSettings.trueBlack` is on.
- **Platform-drawn components** (alerts, menus, share sheet, keyboard, pickers, segmented control) take their
  colours from the system in the current appearance (`color.global.system.ios` names; Android M3 roles
  `color.global.system.*` are `{light, dark}` from Retro's own ColorScheme plus the M3 baseline).

## Quick role finder

| need | token(s) |
|---|---|
| page background (iOS / Android; Android True Black) · media surfaces (viewer, camera) | `color.global.background` / `color.global.background.android` (`….trueBlack`) · `color.global.backgroundDeep` |
| tile, field, '+' circle, fill pill, iOS grouped row · Android grouped row, chip, reply bar | `color.global.control` · `color.global.surfaceSecondary.android` |
| card on a blurred backdrop (recap, plan card) | `color.global.surfaceElevated`, `radius.global.cardLarge` / `radius.global.thumbnail`, `layout.global.materials` |
| primary / secondary / tertiary text (iOS · Android secondary) · on media | `color.global.textPrimary` / `.textSecondary` / `.textTertiary` · `color.global.textSecondary.android` · `color.global.textOnMedia` |
| placeholder text | `color.global.textSecondary`, text role `placeholder` (17) |
| primary capsule (60 pt, full width) | fill `color.global.accent`, label `color.global.onAccent`, `size.global.buttonHeight`, `size.global.buttonMarginH`, `radius.global.button`, text role `button` |
| medium capsule (37 pt) — primary / outline / fill | `size.global.pillHeight`, `size.global.pillGap`, `radius.global.capsule`, text role `pill`; primary `color.global.accent`; outline 1 pt `color.global.textPrimary`; fill `color.global.control` |
| outline CTA with icon | `size.global.pillPaddingLeading` / `.pillPaddingTrailing` / `.pillIconGap`, `size.global.iconSmall`, `icon.global.add` |
| disabled primary capsule | `color.global.controlRaised` |
| light pill on media ('Share') | `color.global.surfaceLight` / `color.global.onSurfaceLight` |
| glass circle over a photo | `color.global.glass`, `size.global.circleButtonPhoto` (40) / `.circleButtonLarge` (64) / `.circleButtonSmall` (32) |
| circle button on a fill / on media | `size.global.circleButton` (36), `color.global.control` / `color.global.controlOnDeep` |
| header (root): serif title + trailing glyphs | text role `headerTitle` + `font.global.display`, `size.global.titleTop`, `size.global.titleToContent`, `size.global.headerIconPitch`, `size.global.headerInset`, `size.global.headerButton`, `size.global.icon` |
| header (pushed) | `icon.global.back`, `size.global.backInset`, `size.global.headerGap` |
| sheet / modal title | text role `sheetTitle`, `icon.global.close` in `size.global.circleButton` |
| screen margin · bottom capsule margin | `size.global.screenMargin` (16) · `size.global.buttonMarginH` (20) |
| week strip | `size.global.stripTileWidth` / `.stripTileHeight` / `.stripGap`, `radius.global.card` (outer corners), `radius.global.photo` (inner), `layout.global.photoScrim`, `color.global.scrim`, text roles `tileLabel` / `tileDay` / `tileMonth`, `color.global.emptyTileText`, `size.global.tileLabelBaseline` |
| friend card | `size.global.friendCardWidth` / `.friendCardHeight`, `radius.global.card`, `size.global.cardGap`, `size.global.avatarList`, `size.global.cardNameGap`, `size.global.cardHeaderGap`, text role `listTitle` |
| 'new' badge · unread dot | `color.global.badge` / `color.global.onBadge`, `size.global.badgeHeight`, `size.global.badgeInset`, text role `badge` · `size.global.tabBadgeDot`, `size.global.tabBadgeOffset` |
| section header ('Week 26 · Jun 26 – Jul 2') | text roles `sectionLabel` + `listSubtitle` (`color.global.textSecondary`), `size.global.sectionHeaderToContent`, `size.global.sectionGap`, `icon.global.more` |
| list row with thumbnail · people row | `size.global.rowThumbWidth` / `.rowThumbHeight` / `.rowThumbGap`, `radius.global.thumbnail`, `size.global.listGap` · `size.global.avatarPicker` |
| grouped rows (settings) | `radius.global.groupedRow`, `color.global.control` (iOS) / `color.global.surfaceSecondary.android`, `color.global.separator` + `size.global.hairline`, `icon.global.chevron` |
| avatars | `size.global.avatarSmall` 22.6 (stack, `size.global.avatarStackOverlap`), `.avatarList` 26.5, `.avatarPicker` 37, `.avatarHeader` 39, `.avatarProfile` 64, `.avatarGrid` 81 |
| tab bar | `size.global.tabBarHeight`, `size.global.tabBarInset` (0), `size.global.tabBarIcon`, `color.global.textPrimary` (selected) / `color.global.tabInactive`, `icon.global.home` / `.group` / `.rewind` / `.activity` / `.wall` |
| search / text field | `size.global.fieldHeight`, `radius.global.field`, `color.global.control`, text role `placeholder`, `icon.global.search` |
| empty state | `size.global.emptyIcon`, `.emptyIconToTitle`, `.emptyTitleToAction`, text roles `emptyTitle` / `emptyDetail`, outline CTA |
| page dots | `size.global.pageDot`, `size.global.pageDotPitch`, `color.global.textPrimary` / `color.global.pageDotInactive` |
| shape | `layout.global.cornerStyle` (continuous on iOS), `radius.global.capsule`, no shadows (`layout.global.elevation`) |
| motion | `duration.global.fade` 150 + `easing.global.standard` (house default), `.crossfade` 100, `.fadeShort` 120, `.pageTransition` 500, `.photoOpen` 250, `.stripInsert` 250, `spring.global.playful`, `spring.global.sheetPresent` / `duration.global.sheetPresent`, native `easing.global.native`, Reduce Motion `layout.global.reduceMotion` |
| haptics | `haptic.global.tap` (Android VIRTUAL_KEY), `haptic.global.select` (tick), `.send`, `.success`, `.warning`, `.error`, `.longPressStart`, `.reaction`, `.shutter` (none) |
| icons | `layout.global.iconStyle` (outline, 2 pt stroke, 24 box), `icon.global.variantRule`, `icon.global.*` |
| system surfaces | `color.global.system.ios` (semantic API names), `color.global.system.*` (Android M3 roles), `color.global.destructive`, `radius.global.sheet`, `layout.global.system.typography`, `easing.global.system.standard`, `duration.global.system.scale` |
| accessibility | `size.global.minTouchTarget.*`, `layout.global.contrast.text` / `.largeText` / `.nonText` |

## All global tokens

Generated from `design/tokens/global.json` (values; full evidence in the JSON and `design/SOURCES.md`).

### Colors — app surfaces

| token | light | dark | level | use for | code |
|---|---|---|---|---|---|
| `color.global.background` | #FFFFFF | #000000 | SOURCED | page background of every app screen (home, profile, albums, settings, sheets); iOS — and Android's 'true black' option | `Tokens.Colors.globalBackground` |
| `color.global.background.android` | #FFFFFF | #1C1C1E | SOURCED | page background on Android (Retro's default dark scheme; the iOS / true-black value is color.global.background) | `Tokens.Colors.globalBackgroundAndroid` |
| `color.global.background.android.trueBlack` | #FFFFFF | #000000 | SOURCED | page background on Android while Settings → True Black is on (dark only; Retro d42.w / vv3.k) | `Tokens.Colors.globalBackgroundAndroidTrueBlack` |
| `color.global.backgroundDeep` | #000000 | #000000 | SOURCED | media surfaces that stay black in both appearances: photo / story viewer, camera, postcard-style composer, recap preview, full-bleed media (Rewind) | `Tokens.Colors.globalBackgroundDeep` |
| `color.global.control` | #F1F1F1 | #262626 | SOURCED | fill of tiles (add tile, empty-day tile, strip placeholder), search / text fields, circle buttons ('+'), fill pills ('Create'), grouped rows on iOS | `Tokens.Colors.globalControl` |
| `color.global.surfaceSecondary.android` | #F7F7F7 | #262626 | SOURCED | Android secondary surface: grouped settings rows, chips, reply / comment bar, sheet cards (iOS draws these in color.global.control) | `Tokens.Colors.globalSurfaceSecondaryAndroid` |
| `color.global.surfaceElevated` | #FFFFFF | #181818 | SOURCED | card on a blurred photo backdrop (recap collage card, plan card) and other elevated surfaces | `Tokens.Colors.globalSurfaceElevated` |
| `color.global.controlOnDeep` | #262626 | #262626 | SOURCED | controls on the black media surfaces (both appearances): close circle, 'Add a message' pill, edit circle, position pill ('3 of 4'), comment field on the viewer | `Tokens.Colors.globalControlOnDeep` |
| `color.global.controlRaised` | #CCCCCC | #4D4D4D | SOURCED | stronger fill: disabled primary capsule, container fill | `Tokens.Colors.globalControlRaised` |
| `color.global.textPrimary` | #000000 | #FFFFFF | SOURCED | primary text and glyphs; selected tab glyph; page-dot selected | `Tokens.Colors.globalTextPrimary` |
| `color.global.textOnMedia` | #FFFFFF | #FFFFFF | SOURCED | text and glyphs on media surfaces and over photos in both appearances: viewer header name, close / more glyphs, weekday tile labels, date title on Rewind, controls on color.global.controlOnDeep | `Tokens.Colors.globalTextOnMedia` |
| `color.global.textSecondary` | #999999 | #999999 | SOURCED | secondary text on iOS: date ranges, real names, list subtitles, meta lines, field placeholders (2025), grey links and legal text | `Tokens.Colors.globalTextSecondary` |
| `color.global.textSecondary.android` | #00000080 | #FFFFFF99 | SOURCED | secondary text on Android: meta lines ('A · B'), NUX body, list subtitles | `Tokens.Colors.globalTextSecondaryAndroid` |
| `color.global.textTertiary` | #C1C1C1 | #FFFFFF4D | SOURCED | tertiary / disabled text and glyphs | `Tokens.Colors.globalTextTertiary` |
| `color.global.emptyTileText` | #D9D9D9 | #515151 | SOURCED | month / day number / weekday on an empty-day tile | `Tokens.Colors.globalEmptyTileText` |
| `color.global.tabInactive` | #B2B2B2 | #999999 | SOURCED | unselected tab-bar glyphs (black 30 % on white / white 60 % on black) | `Tokens.Colors.globalTabInactive` |
| `color.global.tabInactiveOnMedia` | #FFFFFF9E | #FFFFFF9E | SOURCED | unselected tab glyphs over a full-bleed photo (selected: color.global.textOnMedia) | `Tokens.Colors.globalTabInactiveOnMedia` |
| `color.global.badge` | #EA3337 | #EA3337 | SOURCED | Retro red: 'new' badge capsule, 4 pt unread dot on a tab, red count-free markers | `Tokens.Colors.globalBadge` |
| `color.global.onBadge` | #FFFFFF | #FFFFFF | SOURCED | label on the red badge; label on the grey 'Last Week' relative-week pill | `Tokens.Colors.globalOnBadge` |
| `color.global.accent` | #000000 | #FFFFFF | SOURCED | primary action fill: full-width primary capsule, primary medium capsule ('Accept'), selected state that is a fill. Retro has no brand colour in chrome — the primary fill is the inverse of the page | `Tokens.Colors.globalAccent` |
| `color.global.onAccent` | #FFFFFF | #000000 | SOURCED | label and glyph on the primary fill | `Tokens.Colors.globalOnAccent` |
| `color.global.surfaceLight` | #FFFFFF | #FFFFFF | SOURCED | light pill / capsule on media and dark surfaces in both appearances: 'Share' on the recap preview, 'Send Postcard' on the black composer | `Tokens.Colors.globalSurfaceLight` |
| `color.global.onSurfaceLight` | #000000 | #000000 | SOURCED | label on the light pill over media ('Share', 'Send Postcard') | `Tokens.Colors.globalOnSurfaceLight` |
| `color.global.glass` | #FFFFFF1F | #FFFFFF1F | SOURCED | glass circle buttons and pills drawn over a photo (Rewind share / random / more circles) | `Tokens.Colors.globalGlass` |
| `color.global.badgeMuted` | #999999 | #999999 | SOURCED | grey relative-week pill next to the title ('Last Week'), label color.global.onBadge | `Tokens.Colors.globalBadgeMuted` |
| `color.global.pageDotInactive` | #DDDDDD | #808080 | SOURCED | inactive page dots (pagers: recap preview, friends grid); the active dot is color.global.textPrimary | `Tokens.Colors.globalPageDotInactive` |
| `color.global.separator` | #CCCCCC | #4D4D4D | SOURCED | hairline divider (1 device pixel), used sparingly: under the profile header, above 'Total', between the viewer footer and comments, between grouped rows | `Tokens.Colors.globalSeparator` |
| `color.global.scrim` | #00000099 | #00000099 | SOURCED | bottom scrim over photos under white text (day tiles, Rewind, widgets): black reaching 60 % at the bottom edge; geometry in layout.global.photoScrim | `Tokens.Colors.globalScrim` |
| `color.global.premium` | #B02EC1 | #B02EC1 | SOURCED | premium-only accent: 'FREE' pill on the paywall plan card (owner decides whether the premium accent is used) | `Tokens.Colors.globalPremium` |
| `layout.global.premiumGradient` | top: #D543DE; bottom: #A327B8; direction: vertical | top: #D543DE; bottom: #A327B8; direction: vertical | SOURCED | vertical gradient of the premium pill | `Tokens.Layouts.GlobalPremiumGradient.<key>` |
| `color.global.selection` | #0088FF | #0091FF | PLATFORM | system tint on iOS: sheet nav text buttons ('Cancel', 'Update'), selected check circle, switches | `Tokens.Colors.globalSelection` |

### Colors — system surfaces (`global.system`)

| token | light | dark | level | use for | code |
|---|---|---|---|---|---|
| `color.global.destructive` | #EA3337 | #EA3337 | SOURCED | destructive actions drawn by the app and destructive menu items: delete, remove, report, leave | `Tokens.Colors.globalDestructive` |
| `color.global.system.ios` | groupedBackground: systemGroupedBackground; cell: secondarySystemGroupedBackground; label: label; secondaryLabel: secondaryLabel; placeholder: placeholderText; separator: separator; tint: systemBlue; destructive: systemRed | groupedBackground: systemGroupedBackground; cell: secondarySystemGroupedBackground; label: label; secondaryLabel: secondaryLabel; placeholder: placeholderText; separator: separator; tint: systemBlue; destructive: systemRed | PLATFORM | semantic colours of native components on iOS (alerts, menus, share sheet, pickers, keyboard, system permission prompts); dynamic — they follow Light / Dark | `Tokens.Layouts.GlobalSystemIos.<key>` |
| `color.global.system.primary` | #0A84FF | #0A84FF | SOURCED | Android M3 primary: dialog action labels, switches, selected controls, text-field cursor | `Tokens.Colors.globalSystemPrimary` |
| `color.global.system.surface` | #FFFFFF | #1C1C1E | SOURCED | Android M3 surface / background (dialogs and sheets inherit from it unless a container role applies) | `Tokens.Colors.globalSystemSurface` |
| `color.global.system.surface.trueBlack` | #FFFFFF | #000000 | SOURCED | Android M3 surface / background while Settings → True Black is on (Retro d42.w) | `Tokens.Colors.globalSystemSurfaceTrueBlack` |
| `color.global.system.onSurface` | #000000 | #FFFFFF | SOURCED | Android M3 on-surface: list item labels, dialog headline | `Tokens.Colors.globalSystemOnSurface` |
| `color.global.system.error` | #EA3337 | #EA3337 | SOURCED | Android M3 error: error / destructive text and icons in M3 components | `Tokens.Colors.globalSystemError` |
| `color.global.system.primaryContainer` | #CCCCCC | #4D4D4D | SOURCED | Android M3 primary container (on-primary-container #000000 / #FFFFFF) | `Tokens.Colors.globalSystemPrimaryContainer` |
| `color.global.system.secondaryContainer` | #F7F7F7 | #262626 | SOURCED | Android M3 secondary container (segmented button selection, tonal containers; on-secondary-container #000000 / #FFFFFF) | `Tokens.Colors.globalSystemSecondaryContainer` |
| `color.global.system.surfaceContainerHigh` | #ECE6F0 | #2B2930 | PLATFORM | Android M3 dialog container (role md.sys.color.surface-container-high) | `Tokens.Colors.globalSystemSurfaceContainerHigh` |
| `color.global.system.surfaceContainerLow` | #F7F2FA | #1D1B20 | PLATFORM | Android M3 modal bottom sheet container (role md.sys.color.surface-container-low) | `Tokens.Colors.globalSystemSurfaceContainerLow` |
| `color.global.system.onSurfaceVariant` | #49454F | #CAC4D0 | PLATFORM | Android M3 supporting text, leading icons, drag handle (role md.sys.color.on-surface-variant) | `Tokens.Colors.globalSystemOnSurfaceVariant` |
| `color.global.system.outline` | #79747E | #938F99 | PLATFORM | Android M3 outline (outlined text field border, M3 divider defaults) | `Tokens.Colors.globalSystemOutline` |

### Appearance

| token | value | level | use for | code |
|---|---|---|---|---|
| `layout.global.appearance` | mode: follows the system Light / Dark setting; ios: no UIUserInterfaceStyle key and no preferredColorScheme override; colour tokens are dynamic (Color(light:dark:)); android: DsTheme(dark = isSystemInDarkTheme()) wraps the app and every test host; colour getters read LocalDsDarkTheme; media: photo / story viewer, camera, postcard-style composer, recap preview and full-bleed media stay dark (color.global.backgroundDeep) in both appearances; sheets over them follow the appearance | SOURCED | appearance of every surface | `Tokens.Layouts.GlobalAppearance.<key>` |

### Typography

| token | value | level | use for | code |
|---|---|---|---|---|
| `font.global.family` | system / Inter | SOURCED | UI typeface of all non-display text: SF Pro on iOS, Inter Variable on Android | `Tokens.Fonts.globalFamily` |
| `font.global.display` | system-serif / serif | PLATFORM | display serif for screen titles ('Week 27', 'Albums', profile name), the date title on Rewind, recap month cards and headlines: New York on iOS, Noto Serif on Android | `Tokens.Fonts.globalDisplay` |
| `fontSize.global.headerTitle` | 40 pt | SOURCED | display serif screen title ('Week 43', 'Albums', 'Friends', 'Messages', profile username); also the date title on full-bleed photos ('May 1, 2019') — family font.global.display | `Tokens.FontSizes.globalHeaderTitle` |
| `fontWeight.global.headerTitle` | regular | SOURCED | display serif screen title ('Week 43', 'Albums', 'Friends', 'Messages', profile username); also the date title on full-bleed photos ('May 1, 2019') — family font.global.display | `Tokens.FontWeights.fontWeightGlobalHeaderTitle` |
| `fontSize.global.displayMedium` | 32 pt | SOURCED | display serif headline on cards, sheets and onboarding ('Share Video' paywall headline, invite page headline, feed-card titles) — family font.global.display | `Tokens.FontSizes.globalDisplayMedium` |
| `fontWeight.global.displayMedium` | regular | SOURCED | display serif headline on cards, sheets and onboarding ('Share Video' paywall headline, invite page headline, feed-card titles) — family font.global.display | `Tokens.FontWeights.fontWeightGlobalDisplayMedium` |
| `fontSize.global.displaySmall` | 24 pt | SOURCED | small display serif: recap month cards ('December'), album titles on covers, recap year ('2023') — family font.global.display | `Tokens.FontSizes.globalDisplaySmall` |
| `fontWeight.global.displaySmall` | regular | SOURCED | small display serif: recap month cards ('December'), album titles on covers, recap year ('2023') — family font.global.display | `Tokens.FontWeights.fontWeightGlobalDisplaySmall` |
| `fontSize.global.onboardingTitle` | 30 pt | SOURCED | large line on the sign-up landing under the mark ('Friends Only'), in color.global.textSecondary | `Tokens.FontSizes.globalOnboardingTitle` |
| `fontWeight.global.onboardingTitle` | regular | SOURCED | large line on the sign-up landing under the mark ('Friends Only'), in color.global.textSecondary | `Tokens.FontWeights.fontWeightGlobalOnboardingTitle` |
| `fontSize.global.sheetTitle` | 17 pt | SOURCED | modal / sheet title, centred ('Postcard', 'Create Recap', 'Settings', 'Add to Your Week') | `Tokens.FontSizes.globalSheetTitle` |
| `fontWeight.global.sheetTitle` | semibold | SOURCED | modal / sheet title, centred ('Postcard', 'Create Recap', 'Settings', 'Add to Your Week') | `Tokens.FontWeights.fontWeightGlobalSheetTitle` |
| `fontSize.global.listTitle` | 15 pt | SOURCED | name / row title ('olson', 'Mexico City', 'Total'), friend-card name, secondary link ('already have an account?') | `Tokens.FontSizes.globalListTitle` |
| `fontWeight.global.listTitle` | semibold | SOURCED | name / row title ('olson', 'Mexico City', 'Total'), friend-card name, secondary link ('already have an account?') | `Tokens.FontWeights.fontWeightGlobalListTitle` |
| `fontSize.global.listSubtitle` | 15 pt | SOURCED | row subtitle and secondary line ('daniel shared 2 posts', date range 'Jul 3 - 9', 'Week 28' in the viewer header) | `Tokens.FontSizes.globalListSubtitle` |
| `fontWeight.global.listSubtitle` | regular | SOURCED | row subtitle and secondary line ('daniel shared 2 posts', date range 'Jul 3 - 9', 'Week 28' in the viewer header) | `Tokens.FontWeights.fontWeightGlobalListSubtitle` |
| `fontSize.global.body` | 15 pt | SOURCED | body / list row text on iOS ('Weeks Posted: 32'-style info rows, comment text, address lines, sheet rows) | `Tokens.FontSizes.globalBody` |
| `fontWeight.global.body` | regular | SOURCED | body / list row text on iOS ('Weeks Posted: 32'-style info rows, comment text, address lines, sheet rows) | `Tokens.FontWeights.fontWeightGlobalBody` |
| `fontSize.global.button` | 17 pt | SOURCED | label of the 60 pt full-width capsule ('Claim', 'Send Postcard', 'Get started') | `Tokens.FontSizes.globalButton` |
| `fontWeight.global.button` | semibold | SOURCED | label of the 60 pt full-width capsule ('Claim', 'Send Postcard', 'Get started') | `Tokens.FontWeights.fontWeightGlobalButton` |
| `fontSize.global.pill` | 15 pt | SOURCED | label of the 36–37 pt capsules ('Get this week started', 'Recaps', 'Share Profile', 'Accept', 'Create') | `Tokens.FontSizes.globalPill` |
| `fontWeight.global.pill` | semibold | SOURCED | label of the 36–37 pt capsules ('Get this week started', 'Recaps', 'Share Profile', 'Accept', 'Create') | `Tokens.FontWeights.fontWeightGlobalPill` |
| `fontSize.global.textButton` | 17 pt | SOURCED | app-drawn text buttons in a header ('Invite', 'Keys'); native sheet nav buttons ('Cancel', 'Update') are the system's own at the same size | `Tokens.FontSizes.globalTextButton` |
| `fontWeight.global.textButton` | regular | SOURCED | app-drawn text buttons in a header ('Invite', 'Keys'); native sheet nav buttons ('Cancel', 'Update') are the system's own at the same size | `Tokens.FontWeights.fontWeightGlobalTextButton` |
| `fontSize.global.caption` | 14 pt | SOURCED | fine print and timestamps: legal footer under the sign-up button ('By continuing, I confirm…'), timestamps ('1d', '2h') | `Tokens.FontSizes.globalCaption` |
| `fontWeight.global.caption` | regular | SOURCED | fine print and timestamps: legal footer under the sign-up button ('By continuing, I confirm…'), timestamps ('1d', '2h') | `Tokens.FontWeights.fontWeightGlobalCaption` |
| `lineHeight.global.caption` | 21.7 pt | SOURCED | line pitch of the multi-line legal footer (14 pt) | `Tokens.LineHeights.globalCaption` |
| `fontSize.global.meta` | 13 pt | SOURCED | small secondary line: real name under the profile name ('Isabel Reyes'), field labels ('Mailing Address') | `Tokens.FontSizes.globalMeta` |
| `fontWeight.global.meta` | regular | SOURCED | small secondary line: real name under the profile name ('Isabel Reyes'), field labels ('Mailing Address') | `Tokens.FontWeights.fontWeightGlobalMeta` |
| `fontSize.global.placeholder` | 17 pt | SOURCED | placeholder and typed text in the search / text field ('Search'), colour color.global.textSecondary | `Tokens.FontSizes.globalPlaceholder` |
| `fontSize.global.sectionLabel` | 15 pt | SOURCED | section header ('Week 27' before its date range; dated album group 'January 25, 2024') | `Tokens.FontSizes.globalSectionLabel` |
| `fontWeight.global.sectionLabel` | semibold | SOURCED | section header ('Week 27' before its date range; dated album group 'January 25, 2024') | `Tokens.FontWeights.fontWeightGlobalSectionLabel` |
| `fontSize.global.emptyTitle` | 20 pt | SOURCED | empty-state title ('Welcome to Week 43!') | `Tokens.FontSizes.globalEmptyTitle` |
| `fontWeight.global.emptyTitle` | semibold | SOURCED | empty-state title ('Welcome to Week 43!') | `Tokens.FontWeights.fontWeightGlobalEmptyTitle` |
| `fontSize.global.emptyDetail` | 14 pt | SOURCED | empty-state explanation (two lines, grey) under the title | `Tokens.FontSizes.globalEmptyDetail` |
| `fontWeight.global.emptyDetail` | regular | SOURCED | empty-state explanation (two lines, grey) under the title | `Tokens.FontWeights.fontWeightGlobalEmptyDetail` |
| `fontSize.global.tileLabel` | 13 pt | SOURCED | weekday label on a photo tile ('Mon'), white over the bottom scrim, centred, baseline 13.4 above the tile bottom | `Tokens.FontSizes.globalTileLabel` |
| `fontWeight.global.tileLabel` | semibold | SOURCED | weekday label on a photo tile ('Mon'), white over the bottom scrim, centred, baseline 13.4 above the tile bottom | `Tokens.FontWeights.fontWeightGlobalTileLabel` |
| `fontSize.global.tileDay` | 28 pt | SOURCED | day number on an empty-day tile ('20'), tabular digits | `Tokens.FontSizes.globalTileDay` |
| `fontWeight.global.tileDay` | semibold | SOURCED | day number on an empty-day tile ('20'), tabular digits | `Tokens.FontWeights.fontWeightGlobalTileDay` |
| `fontSize.global.tileMonth` | 14 pt | SOURCED | month and weekday lines on an empty-day tile ('Oct' / 'Mon') | `Tokens.FontSizes.globalTileMonth` |
| `fontSize.global.badge` | 11 pt | SOURCED | label of the red 'new' badge, the grey relative-week pill and the viewer position pill | `Tokens.FontSizes.globalBadge` |
| `fontWeight.global.badge` | semibold | SOURCED | label of the red 'new' badge, the grey relative-week pill and the viewer position pill | `Tokens.FontWeights.fontWeightGlobalBadge` |
| `fontSize.global.pillSmall` | 13 pt | SOURCED | label of small pills on media / the paywall ('FREE', video duration '1:00' with monospaced digits) | `Tokens.FontSizes.globalPillSmall` |
| `fontWeight.global.pillSmall` | bold | SOURCED | label of small pills on media / the paywall ('FREE', video duration '1:00' with monospaced digits) | `Tokens.FontWeights.fontWeightGlobalPillSmall` |
| `fontSize.global.body.android` | 14 sp | SOURCED | Android body text (Retro's most-used style, 33 call sites) | `Tokens.FontSizes.globalBodyAndroid` |
| `lineHeight.global.body.android` | 17 sp | SOURCED | Android body line height | `Tokens.LineHeights.globalBodyAndroid` |
| `letterSpacing.global.body.android` | -0.3 sp | SOURCED | Android body tracking — only when the locale's script is Latin (hh3.p0), else 0 | `Tokens.Tracking.globalBodyAndroid` |
| `layout.global.variableWeight.android` | body: 450 | SOURCED | Android weights on Inter's wght axis that the named weights cannot express (FontWeight(450)) | `Tokens.Layouts.GlobalVariableWeightAndroid.<key>` |
| `lineHeight.global.listTitle.android` | 18 sp | SOURCED | Android name / row title line height (Inter 15/18 W600) | `Tokens.LineHeights.globalListTitleAndroid` |
| `letterSpacing.global.listTitle.android` | -0.35 sp | SOURCED | Android name / row title tracking — Latin script only | `Tokens.Tracking.globalListTitleAndroid` |
| `lineHeight.global.badge.android` | 11 sp | SOURCED | Android badge line height (Inter 11/11 W600) | `Tokens.LineHeights.globalBadgeAndroid` |
| `letterSpacing.global.badge.android` | -0.2 sp | SOURCED | Android badge tracking — Latin script only | `Tokens.Tracking.globalBadgeAndroid` |
| `lineHeight.global.headerTitle` | 48 pt | SOURCED | line height of the display serif title (multi-line titles) | `Tokens.LineHeights.globalHeaderTitle` |
| `layout.global.textStyleMap` | headerTitle: largeTitle; displayMedium: largeTitle; displaySmall: title2; onboardingTitle: title; sheetTitle: headline; listTitle: subheadline; listSubtitle: subheadline; body: subheadline; button: headline; pill: subheadline; textButton: body; caption: subheadline; meta: footnote; placeholder: body; sectionLabel: subheadline; emptyTitle: title3; emptyDetail: subheadline; tileLabel: footnote; tileDay: title; tileMonth: subheadline; badge: caption2; pillSmall: footnote | PLATFORM | iOS Dynamic Type text style each fontSize.global.<role> scales with (SwiftUI Font.TextStyle case; DSTextStyle.relativeTo); Android sp sizes follow the font scale | `Tokens.Layouts.GlobalTextStyleMap.<key>` |
| `layout.global.system.typography` | ios: built-in text styles (Font.TextStyle) inside native alerts, menus, share sheet, pickers; android: MaterialTheme.typography with Retro's overrides: headlineLarge = display 40/48, bodyLarge = Inter 15/18 W600, bodyMedium = Inter 14/17 W600, bodySmall = Inter 11/11 W600; other M3 styles stay baseline | PLATFORM | text styles of components the system draws | `Tokens.Layouts.GlobalSystemTypography.<key>` |

### Spacing and sizes

| token | value | level | use for | code |
|---|---|---|---|---|
| `size.global.screenMargin` | 16 pt | SOURCED | side margin of all content: titles, strips, friend cards, list rows, header glyph ink, search field | `Tokens.Sizes.globalScreenMargin` |
| `size.global.buttonMarginH` | 20 pt | SOURCED | side margin of the full-width bottom capsule (and of the plan card) | `Tokens.Sizes.globalButtonMarginH` |
| `size.global.buttonMarginHSheet` | 20 pt | SOURCED | side margin of a full-width capsule at the bottom of a sheet / modal (same as buttonMarginH in Retro) | `Tokens.Sizes.globalButtonMarginHSheet` |
| `size.global.buttonHeight` | 60 pt | SOURCED | height of the full-width primary / secondary capsule | `Tokens.Sizes.globalButtonHeight` |
| `size.global.buttonHeightSheet` | 60 pt | SOURCED | height of the full-width capsule at the bottom of a sheet / modal (same as buttonHeight in Retro) | `Tokens.Sizes.globalButtonHeightSheet` |
| `size.global.pillHeight` | 37 pt | SOURCED | height of the medium capsules (outline CTA, action pairs, profile action row) | `Tokens.Sizes.globalPillHeight` |
| `size.global.iconPillWidth` | 49 pt | SOURCED | icon-only capsule in an action row (the gear capsule after 'Recaps' / 'Share Profile') | `Tokens.Sizes.globalIconPillWidth` |
| `size.global.pillGap` | 8.8 pt | SOURCED | gap between side-by-side capsules (Recaps / Share Profile / gear) | `Tokens.Sizes.globalPillGap` |
| `size.global.pillPaddingLeading` | 18 pt | SOURCED | outline CTA with icon: leading edge → icon | `Tokens.Sizes.globalPillPaddingLeading` |
| `size.global.pillPaddingTrailing` | 17 pt | SOURCED | outline CTA with icon: label → trailing edge | `Tokens.Sizes.globalPillPaddingTrailing` |
| `size.global.pillIconGap` | 9.7 pt | SOURCED | outline CTA with icon: icon → label | `Tokens.Sizes.globalPillIconGap` |
| `size.global.iconSmall` | 14.7 pt | SOURCED | inline glyph inside a pill ('+' in 'Get this week started'); info-row icons measure 14 | `Tokens.Sizes.globalIconSmall` |
| `size.global.icon` | 24 pt | SOURCED | glyph box of outline icons: tab bar, header, list accessories | `Tokens.Sizes.globalIcon` |
| `size.global.headerButton` | 44 pt | PLATFORM | hit area of a header icon button (Retro draws the glyph bare, no circle); glyph centred | `Tokens.Sizes.globalHeaderButton` |
| `size.global.headerIconPitch` | 48 pt | SOURCED | centre-to-centre distance of trailing header glyphs (book, chat) | `Tokens.Sizes.globalHeaderIconPitch` |
| `size.global.headerInset` | 16 pt | SOURCED | screen edge → ink of the last trailing header glyph (the glyph, not its hit area, sits on the margin) | `Tokens.Sizes.globalHeaderInset` |
| `size.global.headerGap` | 14.6 pt | SOURCED | pushed screen: back chevron ink → serif title ink | `Tokens.Sizes.globalHeaderGap` |
| `size.global.backInset` | 21.1 pt | SOURCED | pushed screen: screen edge → back chevron ink (chevron ink 11.1 × 18.3 pt, centred on the title's cap middle) | `Tokens.Sizes.globalBackInset` |
| `size.global.titleTop` | 64 pt | SOURCED | safe-area top → baseline of the display title on a root screen | `Tokens.Sizes.globalTitleTop` |
| `size.global.titleToContent` | 30 pt | SOURCED | display title baseline → first content (strip top) | `Tokens.Sizes.globalTitleToContent` |
| `size.global.listGap` | 22.5 pt | SOURCED | vertical gap between list rows with a thumbnail (albums list: row pitch 119.5 − thumbnail 97) | `Tokens.Sizes.globalListGap` |
| `size.global.cardGap` | 16 pt | SOURCED | gap between friend cards in the horizontal pager (the next card peeks) | `Tokens.Sizes.globalCardGap` |
| `size.global.stripTileWidth` | 84 pt | SOURCED | week-strip tile width (3:4) | `Tokens.Sizes.globalStripTileWidth` |
| `size.global.stripTileHeight` | 112 pt | SOURCED | week-strip tile height (3:4) | `Tokens.Sizes.globalStripTileHeight` |
| `size.global.stripGap` | 2 pt | SOURCED | gap between strip tiles (page colour shows through) | `Tokens.Sizes.globalStripGap` |
| `size.global.tileLabelBaseline` | 13.4 pt | SOURCED | photo tile: weekday label baseline → tile bottom | `Tokens.Sizes.globalTileLabelBaseline` |
| `size.global.friendCardWidth` | 240 pt | SOURCED | friend card (photo) width, 2:3 | `Tokens.Sizes.globalFriendCardWidth` |
| `size.global.friendCardHeight` | 361 pt | SOURCED | friend card (photo) height, 2:3 | `Tokens.Sizes.globalFriendCardHeight` |
| `size.global.cardNameGap` | 11 pt | SOURCED | friend card header: avatar → name ink | `Tokens.Sizes.globalCardNameGap` |
| `size.global.cardHeaderGap` | 10 pt | SOURCED | friend card header: avatar bottom → card top | `Tokens.Sizes.globalCardHeaderGap` |
| `size.global.badgeInset` | 12 pt | SOURCED | 'new' badge: distance from the card's top and right edges | `Tokens.Sizes.globalBadgeInset` |
| `size.global.badgeHeight` | 24 pt | SOURCED | height of the red badge capsule | `Tokens.Sizes.globalBadgeHeight` |
| `size.global.tabBarHeight` | 49 pt | SOURCED | tab bar height above the home indicator (standard bar; background = page, no hairline, no labels) | `Tokens.Sizes.globalTabBarHeight` |
| `size.global.tabBarInset` | 0 pt | SOURCED | tab bar inset from the screen edges: none — Retro's bar is not floating; it spans the width with 5 items evenly distributed (centres at width ÷ 10, 3 ÷ 10 …) and sits on the home indicator | `Tokens.Sizes.globalTabBarInset` |
| `size.global.tabBarIcon` | 24 pt | SOURCED | tab glyph box (ink 18.7–24 × 19.7–22 pt) | `Tokens.Sizes.globalTabBarIcon` |
| `size.global.tabBadgeDot` | 4 pt | SOURCED | red unread dot under a tab glyph | `Tokens.Sizes.globalTabBadgeDot` |
| `size.global.tabBadgeOffset` | 5 pt | SOURCED | tab glyph bottom → dot top (dot centred) | `Tokens.Sizes.globalTabBadgeOffset` |
| `size.global.avatarList` | 26.5 pt | SOURCED | avatar beside a name above a friend card (home feed) | `Tokens.Sizes.globalAvatarList` |
| `size.global.avatarPicker` | 37 pt | SOURCED | avatar in a people row (friend request, member rows) | `Tokens.Sizes.globalAvatarPicker` |
| `size.global.avatarComment` | 30 pt | SOURCED | avatar in a comment row and inside the reply / comment field | `Tokens.Sizes.globalAvatarComment` |
| `size.global.avatarSmall` | 22.6 pt | SOURCED | avatar in an avatar stack (≈3 pt overlap, white ring) | `Tokens.Sizes.globalAvatarSmall` |
| `size.global.avatarHeader` | 39 pt | SOURCED | viewer / story header avatar including its white ring with a gap | `Tokens.Sizes.globalAvatarHeader` |
| `size.global.avatarProfile` | 64 pt | SOURCED | avatar in the profile header (right margin, aligned to the title) | `Tokens.Sizes.globalAvatarProfile` |
| `size.global.avatarGrid` | 81 pt | SOURCED | avatar in a 3-column people grid (name centred below) | `Tokens.Sizes.globalAvatarGrid` |
| `size.global.avatarStackOverlap` | 3 pt | SOURCED | overlap between avatars in a stack | `Tokens.Sizes.globalAvatarStackOverlap` |
| `size.global.circleButton` | 36 pt | SOURCED | circle button with a glyph on a fill ('+' on album rows, close on the postcard modal) | `Tokens.Sizes.globalCircleButton` |
| `size.global.circleButtonSmall` | 32 pt | SOURCED | small close circle (glass over colour on the paywall) | `Tokens.Sizes.globalCircleButtonSmall` |
| `size.global.circleButtonPhoto` | 40 pt | SOURCED | '•••' glass circle over a full-bleed photo | `Tokens.Sizes.globalCircleButtonPhoto` |
| `size.global.circleButtonLarge` | 64 pt | SOURCED | large glass circle beside a central control (Rewind share / random) | `Tokens.Sizes.globalCircleButtonLarge` |
| `size.global.fieldHeight` | 52 pt | SOURCED | search / text field height (full width inside the margins) | `Tokens.Sizes.globalFieldHeight` |
| `size.global.commentFieldHeight` | 48 pt | SOURCED | reply / comment field at the bottom of the viewer (own avatar leading, trailing glyph) | `Tokens.Sizes.globalCommentFieldHeight` |
| `size.global.positionPillHeight` | 22 pt | SOURCED | position pill in the viewer header ('3 of 4') | `Tokens.Sizes.globalPositionPillHeight` |
| `size.global.rowThumbWidth` | 72 pt | SOURCED | list row thumbnail width (3:4 cover) | `Tokens.Sizes.globalRowThumbWidth` |
| `size.global.rowThumbHeight` | 97 pt | SOURCED | list row thumbnail height (3:4 cover) | `Tokens.Sizes.globalRowThumbHeight` |
| `size.global.rowThumbGap` | 17 pt | SOURCED | list row thumbnail → text | `Tokens.Sizes.globalRowThumbGap` |
| `size.global.infoRowPitch` | 29 pt | SOURCED | profile info rows (14 pt icon + 15 pt text) baseline pitch | `Tokens.Sizes.globalInfoRowPitch` |
| `size.global.sectionHeaderToContent` | 11.7 pt | SOURCED | section header baseline → strip / grid top | `Tokens.Sizes.globalSectionHeaderToContent` |
| `size.global.sectionGap` | 36.4 pt | SOURCED | strip bottom → next section header cap top | `Tokens.Sizes.globalSectionGap` |
| `size.global.emptyIcon` | 22 pt | SOURCED | empty-state outline glyph | `Tokens.Sizes.globalEmptyIcon` |
| `size.global.emptyIconToTitle` | 26 pt | SOURCED | empty state: glyph bottom → title cap top | `Tokens.Sizes.globalEmptyIconToTitle` |
| `size.global.emptyTitleToAction` | 25 pt | SOURCED | empty state: title baseline → capsule top | `Tokens.Sizes.globalEmptyTitleToAction` |
| `size.global.checkCircle` | 24 pt | SOURCED | selection circle (empty ring / filled check) — drawn in the 24 pt glyph box | `Tokens.Sizes.globalCheckCircle` |
| `size.global.pageDot` | 5.9 pt | SOURCED | page-dot diameter | `Tokens.Sizes.globalPageDot` |
| `size.global.pageDotPitch` | 9.6 pt | SOURCED | page-dot centre-to-centre | `Tokens.Sizes.globalPageDotPitch` |
| `size.global.planCardPadding` | 27 pt | SOURCED | padding inside the large card on a blurred backdrop (paywall plan card); its capsule sits 16 from the card sides and bottom | `Tokens.Sizes.globalPlanCardPadding` |
| `size.global.planCardGap` | 8 pt | SOURCED | gap before the next card that peeks in a horizontal card pager | `Tokens.Sizes.globalPlanCardGap` |
| `size.global.featureSheetInset` | 12 pt | SOURCED | feature-intro sheet floating in from the screen edges | `Tokens.Sizes.globalFeatureSheetInset` |
| `size.global.hairline` | ios: 1 device pixel (1 / displayScale pt); android: 1 device pixel | SOURCED | thickness of color.global.separator | `Tokens.Layouts.GlobalHairline.<key>` |
| `size.global.minTouchTarget.ios` | 44 pt | VERIFIED | minimum hit area of any control, iOS (default control size) | `Tokens.Sizes.globalMinTouchTargetIos` |
| `size.global.minTouchTarget.iosMinimum` | 28 pt | VERIFIED | absolute minimum control size, iOS | `Tokens.Sizes.globalMinTouchTargetIosMinimum` |
| `size.global.minTouchTarget.android` | 48 dp | VERIFIED | minimum touch target, Android | `Tokens.Sizes.globalMinTouchTargetAndroid` |
| `size.global.minTouchTarget.androidSpacing` | 8 dp | VERIFIED | spacing between touch targets, Android | `Tokens.Sizes.globalMinTouchTargetAndroidSpacing` |

### Radii and shape

| token | value | level | use for | code |
|---|---|---|---|---|
| `radius.global.card` | 18 pt | SOURCED | photo containers: week-strip outer corners, friend card — continuous corner (layout.global.cornerStyle) | `Tokens.Radii.globalCard` |
| `radius.global.photo` | 0 pt | SOURCED | photo cells inside strips and grids (inner corners square; only the container's outer corners round) | `Tokens.Radii.globalPhoto` |
| `radius.global.thumbnail` | 4 pt | SOURCED | list row cover thumbnail (albums), recap collage cells | `Tokens.Radii.globalThumbnail` |
| `radius.global.button` | 30 pt | SOURCED | full-width 60 pt capsule (radius = height ÷ 2) | `Tokens.Radii.globalButton` |
| `radius.global.capsule` | shape: capsule; radius: height / 2 | SOURCED | buttons (60 / 37 / 36), pills, badges, position pill; circles for avatars and circle buttons | `Tokens.Layouts.GlobalCapsule.<key>` |
| `radius.global.field` | 19 pt | SOURCED | search / text field corners (52 pt field) | `Tokens.Radii.globalField` |
| `radius.global.commentField` | 12 pt | SOURCED | reply / comment field at the bottom of the viewer (48 pt high, rounded rectangle — not a capsule) | `Tokens.Radii.globalCommentField` |
| `radius.global.groupedRow` | 12 pt | SOURCED | grouped list (settings) — first row top corners, last row bottom corners, a single row all corners; middle rows square | `Tokens.Radii.globalGroupedRow` |
| `radius.global.cardLarge` | 36 pt | SOURCED | large card on a blurred backdrop (paywall plan card) | `Tokens.Radii.globalCardLarge` |
| `radius.global.viewfinder` | 18 pt | SOURCED | camera viewfinder corners — composition: the viewfinder is drawn as Retro's photo container (radius.global.card) | `Tokens.Radii.globalViewfinder` |
| `radius.global.sheet` | ios: system; android: 28 | PLATFORM | top corners of native sheets (iOS draws its own; Android ModalBottomSheet default) | `Tokens.Layouts.GlobalSheet.<key>` |
| `layout.global.cornerStyle` | ios: continuous (RoundedRectangle(cornerRadius:style: .continuous)); android: circular (RoundedCornerShape) | SOURCED | corner curve of every rounded rectangle | `Tokens.Layouts.GlobalCornerStyle.<key>` |

### Elevation, materials, photo treatment

| token | value | level | use for | code |
|---|---|---|---|---|
| `layout.global.elevation` | cards: none; tiles: none; lists: none; buttons: none; darkMode: no elevation tint: #262626 fills on the page colour; exceptions: album cover drop shadow (book cover); premium pill coloured shadow (paywall) — both unmeasured | SOURCED | shadows and elevation | `Tokens.Layouts.GlobalElevation.<key>` |
| `layout.global.materials` | glass: only over photos or colour (color.global.glass); backdrop: full-screen blurred, colour-rich version of the photo behind a card (recap preview, paywall); native: menus, share sheet, sheets: system materials | SOURCED | where translucency is used | `Tokens.Layouts.GlobalMaterials.<key>` |
| `layout.global.photoScrim` | color: #000000; startAt: 0.55; startOpacity: 0; endOpacity: 0.6; direction: top → bottom | SOURCED | bottom gradient on photo tiles and full-bleed photos under white text (end colour color.global.scrim) | `Tokens.Layouts.GlobalPhotoScrim.<key>` |

### Motion

| token | value | level | use for | code |
|---|---|---|---|---|
| `easing.global.standard` | cubic-bezier(0.4, 0, 0.2, 1) | SOURCED | Retro's house easing (FastOutSlowIn) for fades, slides, photo open, strip insert | `Tokens.Easings.globalStandard` |
| `duration.global.fade` | 150 ms | SOURCED | house default: fade in / out (paired with a slide) for composers, caption box, picker, media preview | `Tokens.Durations.globalFade` |
| `duration.global.crossfade` | 100 ms | SOURCED | crossfade between two states of one element | `Tokens.Durations.globalCrossfade` |
| `duration.global.fadeShort` | 120 ms | SOURCED | small fades | `Tokens.Durations.globalFadeShort` |
| `duration.global.pageTransition` | 500 ms | SOURCED | onboarding page enter (fade + expand) / exit (fade + shrink); onboarding header height | `Tokens.Durations.globalPageTransition` |
| `duration.global.photoOpen` | 250 ms | SOURCED | opening a photo from a list / comment into the viewer (easing.global.standard) | `Tokens.Durations.globalPhotoOpen` |
| `duration.global.stripInsert` | 250 ms | SOURCED | a tile shifts one slot when a photo is added to the strip (easing.global.standard) | `Tokens.Durations.globalStripInsert` |
| `duration.global.sheetPresent` | 567 ms | SOURCED | native sheet presentation, first movement to rest (curve spring.global.sheetPresent) | `Tokens.Durations.globalSheetPresent` |
| `spring.global.sheetPresent` | response 0.347, dampingFraction 1 | SOURCED | native sheet presentation curve (critically damped, no overshoot); for custom presentations that must match it | `Tokens.Springs.globalSheetPresent` |
| `spring.global.playful` | response 0.4443, dampingFraction 0.75 | SOURCED | playful reveals (fan-outs, blur reveal, avatar entries) | `Tokens.Springs.globalPlayful` |
| `spring.global.platformDefault.ios` | response 0.55, dampingFraction 1 | PLATFORM | iOS default animation (SwiftUI Animation.default) for motion Retro shows no value for | `Tokens.Springs.globalPlatformDefaultIos` |
| `spring.global.platformDefault.android` | response 0.16223, dampingFraction 1 | PLATFORM | Android default spring (Compose spring() defaults: stiffness 1500, damping 1) | `Tokens.Springs.globalPlatformDefaultAndroid` |
| `easing.global.native` | sheet: system (.sheet / ModalBottomSheet) — measured on Retro: spring.global.sheetPresent; navigationPush: system (NavigationStack / Compose Navigation default) — Retro's push not captured; keyboard: system; alert: system; menu: system; activityIndicator: system (ProgressView / CircularProgressIndicator); scrollIndicator: system; segmentedControl: system; toast: Android Toast LENGTH_SHORT | PLATFORM | motion of native components; their curves and durations are the platform's | `Tokens.Layouts.GlobalNative.<key>` |
| `easing.global.system.standard` | cubic-bezier(0.2, 0, 0, 1) | PLATFORM | M3 standard easing for custom transitions on Android system surfaces | `Tokens.Easings.globalSystemStandard` |
| `duration.global.system.scale` | short1: 50; short2: 100; short3: 150; short4: 200; medium1: 250; medium2: 300; medium3: 350; medium4: 400; long1: 450; long2: 500; long3: 550; long4: 600; extraLong1: 700; extraLong2: 800; extraLong3: 900; extraLong4: 1000 | PLATFORM | M3 duration scale (ms) for custom transitions on Android system surfaces | `Tokens.Layouts.GlobalSystemScale.<key>` |
| `layout.global.reduceMotion` | ios: UIAccessibility.isReduceMotionEnabled / @Environment(\.accessibilityReduceMotion); android: Settings.Global.ANIMATOR_DURATION_SCALE == 0 or ValueAnimator.areAnimatorsEnabled() == false (Accessibility > Remove animations); substitute: replace x/y/z movement with a cross-fade of the same token duration; springs lose their bounce (dampingFraction 1); drop zoom, scale, peripheral and automatic repeating animation; never animate into or out of blur; motion that tracks the finger stays | PLATFORM | Reduce Motion substitution rule for every token animation (DSAnimation.reducedMotion / dsMotion / dsTransition; Motion.kt dsMotionSpec) | `Tokens.Layouts.GlobalReduceMotion.<key>` |

### Haptics

| token | value | level | use for | code |
|---|---|---|---|---|
| `haptic.global.select` | selection / SEGMENT_FREQUENT_TICK | PLATFORM | tick: one per step on a dial / scrubber (Rewind dial, friend picker, video trim), a segmented choice, a toggled selection | `Tokens.Haptics.globalSelect` |
| `haptic.global.tap` | ios: none; android: VIRTUAL_KEY | PLATFORM | tap on a button, tile or card (played just before the action) | `Tokens.Layouts.GlobalTap.<key>` |
| `haptic.global.send` | notification.success / CONFIRM | PLATFORM | confirm / send: a photo or message was sent | `Tokens.Haptics.globalSend` |
| `haptic.global.success` | notification.success / CONFIRM | PLATFORM | a task completed successfully | `Tokens.Haptics.globalSuccess` |
| `haptic.global.warning` | notification.warning / CONFIRM | PLATFORM | a destructive action was confirmed | `Tokens.Haptics.globalWarning` |
| `haptic.global.error` | notification.error / REJECT | PLATFORM | a task failed | `Tokens.Haptics.globalError` |
| `haptic.global.longPressStart` | ios: system (context menu plays its own haptic; no custom generator); android: LONG_PRESS | PLATFORM | a long press starts (context menu) | `Tokens.Layouts.GlobalLongPressStart.<key>` |
| `haptic.global.reaction` | ios: system (context menu plays its own haptic; no custom generator); android: LONG_PRESS | PLATFORM | the long press that opens the reaction picker on a photo | `Tokens.Layouts.GlobalReaction.<key>` |
| `haptic.global.shutter` | ios: none; android: none | PLATFORM | shutter press (photo / video capture) | `Tokens.Layouts.GlobalShutter.<key>` |

### Icons

| token | value | level | use for | code |
|---|---|---|---|---|
| `layout.global.iconStyle` | style: outline, uniform stroke, rounded caps and joins; stroke: 2; glyphBox: 24; filled: only as a state (selected check, play / pause, lock); ios: SF Symbols, outline variant (also in the tab bar), weight regular; android: Material Icons Outlined / Rounded (outline shapes), 24 dp | SOURCED | icon style of every glyph | `Tokens.Layouts.GlobalIconStyle.<key>` |
| `icon.global.back` | chevron.left / AutoMirrored.Rounded.ArrowBackIos | PLATFORM | back (chevron before the serif title on pushed screens) | `Tokens.Icons.globalBack` |
| `icon.global.close` | xmark / Rounded.Close | PLATFORM | close / dismiss (in a circle on modals and over photos) | `Tokens.Icons.globalClose` |
| `icon.global.more` | ellipsis / Rounded.MoreHoriz | PLATFORM | more '•••' (week section, viewer, over photos) | `Tokens.Icons.globalMore` |
| `icon.global.share` | square.and.arrow.up / Rounded.IosShare | PLATFORM | share | `Tokens.Icons.globalShare` |
| `icon.global.add` | plus / Rounded.Add | PLATFORM | add ('+' on the add tile, '+' circle, CTA icon) | `Tokens.Icons.globalAdd` |
| `icon.global.check` | checkmark.circle.fill / Rounded.CheckCircle | PLATFORM | selected (filled check circle — a state, so filled) | `Tokens.Icons.globalCheck` |
| `icon.global.uncheck` | circle / Rounded.RadioButtonUnchecked | PLATFORM | not selected (empty ring) | `Tokens.Icons.globalUncheck` |
| `icon.global.checkmark` | checkmark / Rounded.Check | PLATFORM | done (bare check in a toast or row) | `Tokens.Icons.globalCheckmark` |
| `icon.global.chevron` | chevron.right / AutoMirrored.Rounded.KeyboardArrowRight | PLATFORM | disclosure on grouped rows and recap month cards | `Tokens.Icons.globalChevron` |
| `icon.global.chevronDown` | chevron.down / Rounded.ExpandMore | PLATFORM | expand (after the date title on Rewind; 'Camera Roll ⌄') | `Tokens.Icons.globalChevronDown` |
| `icon.global.settings` | gearshape / Outlined.Settings | PLATFORM | settings (gear capsule on the profile) | `Tokens.Icons.globalSettings` |
| `icon.global.group` | person.2 / Outlined.Group | PLATFORM | friends / people (Friends tab) | `Tokens.Icons.globalGroup` |
| `icon.global.wall` | person.crop.circle / Outlined.AccountCircle | PLATFORM | profile tab — your weeks (= walls) | `Tokens.Icons.globalWall` |
| `icon.global.recap` | film.stack / Outlined.VideoLibrary | PLATFORM | recap entry where a glyph is needed (Retro's profile shows a text pill 'Recaps' — no Retro glyph) | `Tokens.Icons.globalRecap` |
| `icon.global.lock` | lock.fill / Rounded.Lock | PLATFORM | private (lock on a private week header; filled as in the capture) | `Tokens.Icons.globalLock` |
| `icon.global.search` | magnifyingglass / Rounded.Search | PLATFORM | search (leading glyph in the search field) | `Tokens.Icons.globalSearch` |
| `icon.global.edit` | pencil / Outlined.Edit | PLATFORM | edit ('Add a message' pill, address edit circle) | `Tokens.Icons.globalEdit` |
| `icon.global.link` | link / Rounded.Link | PLATFORM | invite link / copy link | `Tokens.Icons.globalLink` |
| `icon.global.report` | flag / Outlined.Flag | PLATFORM | report (menu item; outline per the icon style) | `Tokens.Icons.globalReport` |
| `icon.global.person` | person.fill / Rounded.Person | PLATFORM | silhouette where no name exists (Retro's no-photo avatar shows initials on a colour circle — ED-W3 'SF') | `Tokens.Icons.globalPerson` |
| `icon.global.play` | play.fill / Rounded.PlayArrow | PLATFORM | play (dial centre) | `Tokens.Icons.globalPlay` |
| `icon.global.pause` | pause.fill / Rounded.Pause | PLATFORM | pause (dial centre while playing) | `Tokens.Icons.globalPause` |
| `icon.global.gallery` | photo.on.rectangle / Outlined.PhotoLibrary | PLATFORM | photo library | `Tokens.Icons.globalGallery` |
| `icon.global.chats` | bubble.left / Outlined.ChatBubbleOutline | PLATFORM | messages (chat glyph in the home header) | `Tokens.Icons.globalChats` |
| `icon.global.calendar` | calendar / Outlined.CalendarMonth | PLATFORM | week / calendar (empty-week glyph, 'Weeks' info row) | `Tokens.Icons.globalCalendar` |
| `icon.global.leave` | rectangle.portrait.and.arrow.right / AutoMirrored.Outlined.Logout | PLATFORM | leave (menu item) | `Tokens.Icons.globalLeave` |
| `icon.global.camera` | camera / Outlined.PhotoCamera | PLATFORM | camera (composer header, capture entry) — outline per the icon style | `Tokens.Icons.globalCamera` |
| `icon.global.flip` | arrow.triangle.2.circlepath / Rounded.Sync | PLATFORM | flip camera (mechanics: Locket / Yope; outline style) | `Tokens.Icons.globalFlip` |
| `icon.global.flashOff` | bolt.slash / Outlined.FlashOff | PLATFORM | flash off (mechanics: camera; outline style) | `Tokens.Icons.globalFlashOff` |
| `icon.global.flashOn` | bolt / Outlined.FlashOn | PLATFORM | flash on (mechanics: camera; outline style) | `Tokens.Icons.globalFlashOn` |
| `icon.global.mic` | mic / Outlined.Mic | PLATFORM | microphone (voice note; outline style) | `Tokens.Icons.globalMic` |
| `icon.global.send` | paperplane / AutoMirrored.Outlined.Send | PLATFORM | send (outline paper plane) | `Tokens.Icons.globalSend` |
| `icon.global.download` | arrow.down.to.line / Rounded.Download | PLATFORM | save to device | `Tokens.Icons.globalDownload` |
| `icon.global.home` | house / Outlined.Home | PLATFORM | Home tab | `Tokens.Icons.globalHome` |
| `icon.global.albums` | book / AutoMirrored.Outlined.MenuBook | PLATFORM | albums / groups (book glyph: home header 2026, tab ≤2025) | `Tokens.Icons.globalAlbums` |
| `icon.global.rewind` | clock.arrow.circlepath / Outlined.History | PLATFORM | Rewind / on-this-day tab | `Tokens.Icons.globalRewind` |
| `icon.global.activity` | bell / Outlined.Notifications | PLATFORM | activity tab | `Tokens.Icons.globalActivity` |
| `icon.global.trash` | trash / Outlined.Delete | PLATFORM | delete (menu item, red) | `Tokens.Icons.globalTrash` |
| `icon.global.hide` | eye.slash / Outlined.VisibilityOff | PLATFORM | hide (menu item) | `Tokens.Icons.globalHide` |
| `icon.global.location` | location / Outlined.NearMe | PLATFORM | location (info row, widget place line) | `Tokens.Icons.globalLocation` |
| `icon.global.random` | dice / Outlined.Casino | PLATFORM | random memory (glass circle on Rewind) | `Tokens.Icons.globalRandom` |
| `icon.global.video` | video.fill / Rounded.Videocam | PLATFORM | video duration pill | `Tokens.Icons.globalVideo` |
| `icon.global.newAlbum` | plus.rectangle.on.rectangle / Outlined.LibraryAdd | PLATFORM | new album / group in the header (book + plus badge; no exact SF Symbol — closest) | `Tokens.Icons.globalNewAlbum` |
| `icon.global.variantRule` | tabBar: outline variant; selection shown by colour only (color.global.textPrimary vs color.global.tabInactive); header: outline variant; states: fill variant only for a state (selected check, play / pause, lock) | PLATFORM | which SF Symbol / Material variant a context uses | `Tokens.Layouts.GlobalVariantRule.<key>` |

### Accessibility (contrast thresholds; touch targets are under Spacing and sizes)

| token | value | level | use for | code |
|---|---|---|---|---|
| `layout.global.contrast.text` | ratio: 4.5; rule: text up to 17 pt (iOS) / below 18 sp (Android), not bold | VERIFIED | minimum contrast ratio: text up to 17 pt (iOS) / below 18 sp (Android), not bold | `Tokens.Layouts.GlobalContrastText.<key>` |
| `layout.global.contrast.largeText` | ratio: 3; rule: text 18 pt and larger, or bold at any size | VERIFIED | minimum contrast ratio: text 18 pt and larger, or bold at any size | `Tokens.Layouts.GlobalContrastLargeText.<key>` |
| `layout.global.contrast.nonText` | ratio: 3; rule: UI components and graphical objects against adjacent colors | VERIFIED | minimum contrast ratio: UI components and graphical objects against adjacent colors | `Tokens.Layouts.GlobalContrastNonText.<key>` |

## Redesign renames

Pass 1 (Foundations, 2026-10-15) rebuilt every global token on Retro. **No token was renamed**: every name whose
role exists in Retro was kept so code keeps compiling, and its value (and where needed its role wording) changed.
Pass 2 / 3 / 4 must re-read each kept token's `element` before using it. Group files (`design/tokens/{account,
capture,social,memory,invite}.json`) still describe the Yope values in their `notes` / `element` text — Pass 2
rewrites them.

### Removed (Yope-only roles; nothing in Retro corresponds)

| removed token | why | replacement | code that references it (stops compiling) |
|---|---|---|---|
| `color.global.accentSecondary` | Yope's pink sticker / card outline; Retro has no second accent in chrome | none (`color.global.premium` is paywall-only) | `ios/App/Sources/Features/Capture/Support/CaptureFakes.swift:127`, `ios/App/Sources/Features/Social/UI/SocialServices.swift:290` |
| `fontSize.global.overlayTime`, `fontWeight.global.overlayTime`, `layout.global.textStyleMap.overlayTime` | Yope's time overlay on chat photos; Retro's on-photo text is the weekday tile label | text role `tileLabel` (13 semibold) or the display date role `headerTitle` | `ios/App/Sources/Components/TextRoles.swift:53`; `android/core/ui/src/main/kotlin/app/ui/text/TextRoles.kt:82`; `android/feature/social/src/main/kotlin/app/feature/social/common/SocialUi.kt:103` |
| `fontSize.global.overlayTimeCamera`, `fontWeight.global.overlayTimeCamera`, `layout.global.textStyleMap.overlayTimeCamera` | Yope's hour overlay on the viewfinder | as above (camera mechanics compose Retro roles — Pass 2 capture) | `ios/App/Sources/Features/Capture/Support/CaptureStyle.swift:46`; `android/feature/capture/src/main/kotlin/app/feature/capture/ui/CaptureText.kt:30` |
| `size.global.tabBarWidth` | Yope's floating capsule width; Retro's bar spans the screen | full width | `ios/App/Sources/Components/FloatingTabBar.swift:62`; `android/core/ui/src/main/kotlin/app/ui/components/FloatingTabBar.kt:53` |
| `size.global.tabBarSelectedWidth`, `size.global.tabBarSelectedHeight` | Yope's selected-tab pill; Retro selects by glyph colour only | `color.global.textPrimary` vs `color.global.tabInactive` | `ios/App/Sources/Components/FloatingTabBar.swift:75`; `android/core/ui/src/main/kotlin/app/ui/components/FloatingTabBar.kt:71` |
| `size.global.tabBarAvatar` | Yope's 'me' tab avatar; Retro's profile tab is a glyph | `icon.global.wall` (`person.crop.circle`) at `size.global.tabBarIcon` | `ios/App/Sources/Components/FloatingTabBar.swift:78`, `ios/AppTests/Account/AccountTestSupport.swift:127`; `android/core/ui/src/main/kotlin/app/ui/components/FloatingTabBar.kt:82` |
| `spring.global.sheetPresentObserved` | Yope's sheet overshoot; Retro's sheet has none | `spring.global.sheetPresent` | none |
| `duration.global.photoSwipe`, `easing.global.photoSwipe` | Yope's viewer swipe; Retro's viewer advances by tap (no swipe measured) | — (viewer mechanics: Pass 2) | none |
| `duration.global.navigationPush` | Yope's 100 ms push (video, low confidence); Retro's push not captured | `easing.global.native.navigationPush` (system) | none |
| `icon.global.grid` | no Retro glyph | — | none |

### Kept names whose role or value changed (no code change needed to compile; check usage)

| token | Yope value → Retro value | role note |
|---|---|---|
| `color.global.background` | #171717 → #FFFFFF / #000000 | page background (iOS); Android screens should move to `color.global.background.android` |
| `color.global.backgroundDeep` | #000000 → #000000 | **role changed**: was home / sheets / camera; now media surfaces only (black in both appearances). Home and sheets move to `color.global.background` |
| `color.global.control` | #2E2E2E → #F1F1F1 / #262626 | fills (tiles, fields, circles, pills, iOS grouped rows) |
| `color.global.controlOnDeep` | #101010 → #262626 | controls on media surfaces |
| `color.global.controlRaised` | #434343 → #CCCCCC / #4D4D4D | **role changed**: was selected tab / inner pill; now disabled capsule / container fill |
| `color.global.textPrimary` | #FFFFFF → #000000 / #FFFFFF | on media use `color.global.textOnMedia` |
| `color.global.textSecondary` | #969696 → #999999 | iOS secondary; Android `color.global.textSecondary.android` |
| `color.global.accent` / `onAccent` | lime #CDFD07 / #000 → #000 / #FFF and #FFF / #000 | **role kept** (primary action fill and its label); Retro has no brand colour — the red is `color.global.badge` / `color.global.destructive` |
| `color.global.surfaceLight` / `onSurfaceLight` | #FFFFFF / #000000 (unchanged) | **role narrowed**: white pill on media / dark surfaces |
| `color.global.selection` | #0091FF → #0088FF / #0091FF | iOS system tint (both appearances) |
| `color.global.separator` | #FFFFFF33 → #CCCCCC / #4D4D4D | 1 device px hairline |
| `color.global.scrim` | #00000080 → #00000099 | bottom photo scrim end colour (geometry `layout.global.photoScrim`); sheet dimming is the platform's |
| `color.global.destructive` | #FF4245 (systemRed dark) → #EA3337 | Retro red |
| `color.global.system.*` | M3 baseline dark → Retro ColorScheme (primary #0A84FF, surface #FFFFFF / #1C1C1E, onSurface, error #EA3337) + M3 baseline light / dark for the rest | `{light, dark}` |
| `layout.global.appearance` | dark only → follows the system | see "Appearance" |
| `font.global.family` | system / system → system / Inter | Inter Variable bundled on Android |
| text roles `onboardingTitle` 40 heavy → 30 regular; `sheetTitle` 19.5 bold → 17 semibold; `headerTitle` 15 bold → **40 regular serif** (`font.global.display`); `listTitle` 17.5 bold → 15 semibold; `listSubtitle` 14 → 15; `body` 17 → 15; `button` 15 → 17; `caption` 12 semibold → 14 regular (line 15.2 → 21.7); `sectionLabel` 16 → 15; `emptyTitle` 16 bold → 20 semibold; `emptyDetail` 14 (italic) → 14 regular | | `headerTitle` is now the display serif screen title (role kept: the screen's title) |
| `radius.global.card` 17 → 18 (continuous); `radius.global.button` 14 → 30 (capsule); `radius.global.field` 12 → 19; `radius.global.photo` 15 → **0** (grid / strip cells are square); `radius.global.viewfinder` 18.5 → 18 | | |
| `size.global.screenMargin` 12 → 16; `headerInset` 11.5 → 16 (ink of the last glyph); `headerGap` 7.3 → 14.6 (back chevron → title); `listGap` 7.5 → 22.5; `buttonHeight` / `buttonHeightSheet` 45 / 47 → 60; `buttonMarginH` / `buttonMarginHSheet` 19 / 27 → 20; `fieldHeight` 44 → 52; `headerButton` 44 (now PLATFORM hit area; no circle) | | |
| avatars `avatarList` 64 → 26.5 (friend-card header); `avatarPicker` 40 → 37 (people row); `avatarSmall` 32.6 → 22.6 (stack); `avatarHeader` 28 → 39 (viewer header, with ring) | | new: `avatarProfile` 64, `avatarGrid` 81 |
| tab bar `tabBarHeight` 58 → 49; `tabBarInset` 22 → 0 (bar not floating); `tabBarIcon` 21 → 24 | | |
| motion `duration.global.sheetPresent` 215 → 567 (first frame at rest); `spring.global.sheetPresent` response 0.3441 → 0.347 (Retro fit) | | |
| `haptic.global.select` android SEGMENT_TICK → SEGMENT_FREQUENT_TICK (Retro's tick) | | |
| icons → outline variants (`camera`, `bolt.slash`, `mic`, `person.2`, `flag`, Outlined.* on Android); `icon.global.wall` film.stack.fill → `person.crop.circle` (profile tab); `icon.global.chats` → `bubble.left`; `icon.global.back` android → `AutoMirrored.Rounded.ArrowBackIos` | | `icon.global.variantRule`: Retro's tab bar stays outline |

### Compile impact of `{light, dark}` colours (not renames)

A colour that became `{light, dark}` is a `@Composable` getter on Android; reading it outside composition no longer
compiles. Static scan + `./gradlew compileDebugKotlin` (2026-10-15) found:
`android/core/ui/src/main/kotlin/app/ui/components/HeaderCircleButton.kt:23,29` (enum arguments),
`android/core/ui/src/main/kotlin/app/ui/theme/AppTheme.kt:21-29` (top-level `darkColorScheme` — becomes the
light / dark M3 scheme, Pass 3), `android/app/src/main/kotlin/app/main/App.kt:44` and
`android/core/push/src/main/kotlin/app/push/NotificationUi.kt:62` (notification accent `toArgb()` outside
composition), `android/feature/capture/src/main/kotlin/app/feature/capture/ui/Components.kt:273` (inside a
`DrawCanvas` lambda). Fix: `Tokens.ColorsLight.*` / `Tokens.ColorsDark.*`, or read the colour in composition
before the lambda. Swift is unaffected (`Color(light:dark:)` is still a `Color`).

## Not available yet (gaps)

| need | status | smallest capture that closes it |
|---|---|---|
| light-mode RAW captures (fills #F1F1F1 vs Android #F7F7F7 rows, strip margin, tab spacing) | renders only (2.389 / 3.89 px/pt) | 3 raw iPhone screenshots in light mode: Home (populated), Profile (2 week sections), Albums list |
| dark Settings / profile / albums | not captured (dark values of rows assumed = the fill #262626, APK agrees) | the 3 screenshots above in dark mode |
| tertiary text on iOS | 2023 WebP only (#B0B0B0–#B4B4B4); APK #C1C1C1 used | one raw screenshot with a timestamp ('2h') |
| disabled capsule label colour | not isolated (TC-R3 phone 2) | one raw screenshot of a disabled primary button |
| weights of `placeholder`, `tileMonth` | not measured | lossless crop of the search field and an empty-day tile |
| glass blur radius, paywall card alpha, backdrop blur | not derivable | none from stills; Retro's iOS app internals |
| push / pop, tab switch, photo open (iOS), story advance, pull-to-refresh motion | not captured (Apple editorial video is a montage of stills — R-14) | 60 s 60 fps screen recording: open a friend's week → tap through 3 photos → back → switch tabs → pull to refresh |
| iOS tap haptic | Retro iOS not inspected | — (iOS buttons play none by default) |
| Android tab-bar height, Android header metrics | Play renders not measured | 2 raw Android screenshots (Home light + dark) |
| initials-avatar colours | chromatic colours unusable from the Apple editorial images | one raw screenshot of a friend without a photo |
| page-dot sizes light | TC-1B 2023 (5 / 12) vs TC-REC 2023-12 (5.9 / 9.6) | one raw screenshot of a pager |
| display face | platform serif (PLATFORM) until the owner licenses Roslindale | owner decision (docs/OWNER_SETUP.md §0) |
