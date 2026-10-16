# Contrast — foundation color pairs (light and dark)

Every text/background and icon/background pair the Retro foundations in `design/tokens/global.json`
imply, checked against W3C WCAG 2.2 (Recommendation 2024-12-12) at level AA **in both appearances**:

| kind | threshold | token | applies to |
|---|---|---|---|
| text | 4.5:1 | `layout.global.contrast.text` | text up to 17 pt (iOS) / below 18 sp (Android), not bold — SC 1.4.3 |
| large | 3:1 | `layout.global.contrast.largeText` | text 18 pt and larger, or bold at any size (HIG Accessibility table) — SC 1.4.3 |
| nontext | 3:1 | `layout.global.contrast.nonText` | UI components and graphical objects against adjacent colors — SC 1.4.11 |

Tool: `tools/contrast.mjs` (WCAG 2.2 relative luminance with the 0.04045 sRGB threshold; translucent
colors are composited source-over onto the color beneath them). A `{light, dark}` colour token resolves
to the appearance being checked; a pair with any such token gets one row per appearance (`light`,
`dark`), a pair of plain colours one row (`both`). The table below is generated:
`node tools/contrast.mjs --write` rewrites it from the current tokens; one pair:
`node tools/contrast.mjs <fg> <bg> [text|large|nontext] [--appearance light|dark]` (token names or
`#RRGGBB(AA)`; without `--appearance` both are printed).

Weights decide the threshold: semibold is not bold, so a 15 pt semibold label needs 4.5:1. Android
pairs use `color.global.background.android` (#1C1C1E dark) where Retro's Android page differs.

<!-- contrast:begin -->
| # | foreground | background | kind | appearance | ratio | needs | result | use |
|---|---|---|---|---|---|---|---|---|
| 1 | `color.global.textPrimary` #000000 | `color.global.background` #FFFFFF | text | light | 21.00:1 | 4.5:1 | pass | body / names 15 pt on the page (iOS) |
| 1 | `color.global.textPrimary` #FFFFFF | `color.global.background` #000000 | text | dark | 21.00:1 | 4.5:1 | pass | body / names 15 pt on the page (iOS) |
| 2 | `color.global.textPrimary` #000000 | `color.global.background.android` #FFFFFF | text | light | 21.00:1 | 4.5:1 | pass | body / names on the Android page |
| 2 | `color.global.textPrimary` #FFFFFF | `color.global.background.android` #1C1C1E | text | dark | 17.01:1 | 4.5:1 | pass | body / names on the Android page |
| 3 | `color.global.textSecondary` #6E6E6E | `color.global.background` #FFFFFF | text | light | 5.10:1 | 4.5:1 | pass | secondary text 13–15 pt regular on the page: date range, real name, list subtitle, legal 14 pt (iOS) |
| 3 | `color.global.textSecondary` #999999 | `color.global.background` #000000 | text | dark | 7.37:1 | 4.5:1 | pass | secondary text 13–15 pt regular on the page: date range, real name, list subtitle, legal 14 pt (iOS) |
| 4 | `color.global.textSecondary` #6E6E6E | `color.global.background` #FFFFFF | large | light | 5.10:1 | 3:1 | pass | grey 'Friends Only' 30 pt on the landing (large text) |
| 4 | `color.global.textSecondary` #999999 | `color.global.background` #000000 | large | dark | 7.37:1 | 3:1 | pass | grey 'Friends Only' 30 pt on the landing (large text) |
| 5 | `color.global.textSecondary.android` #6E6E6E | `color.global.background.android` #FFFFFF | text | light | 5.10:1 | 4.5:1 | pass | Android meta lines (black 50 % / white 60 %) on the page |
| 5 | `color.global.textSecondary.android` #A4A4A5 | `color.global.background.android` #1C1C1E | text | dark | 6.85:1 | 4.5:1 | pass | Android meta lines (black 50 % / white 60 %) on the page |
| 6 | `color.global.textSecondary.android` #6B6B6B | `color.global.surfaceSecondary.android` #F7F7F7 | text | light | 5.01:1 | 4.5:1 | pass | Android row subtitle on a grouped row |
| 6 | `color.global.textSecondary.android` #A8A8A8 | `color.global.surfaceSecondary.android` #262626 | text | dark | 6.38:1 | 4.5:1 | pass | Android row subtitle on a grouped row |
| 7 | `color.global.textTertiary` #C1C1C1 | `color.global.background` #FFFFFF | text | light | 1.80:1 | 4.5:1 | **FAIL** | tertiary / disabled text (WCAG exempts inactive components) |
| 7 | `color.global.textTertiary` #4D4D4D | `color.global.background` #000000 | text | dark | 2.48:1 | 4.5:1 | **FAIL** | tertiary / disabled text (WCAG exempts inactive components) |
| 8 | `color.global.textTertiary` #C1C1C1 | `color.global.background.android` #FFFFFF | text | light | 1.80:1 | 4.5:1 | **FAIL** | tertiary / disabled text on the Android page |
| 8 | `color.global.textTertiary` #616162 | `color.global.background.android` #1C1C1E | text | dark | 2.73:1 | 4.5:1 | **FAIL** | tertiary / disabled text on the Android page |
| 9 | `color.global.textPrimary` #000000 | `color.global.control` #F1F1F1 | text | light | 18.59:1 | 4.5:1 | pass | typed text in a field; 'Create' fill-pill label 15 semibold; row text on an iOS grouped row |
| 9 | `color.global.textPrimary` #FFFFFF | `color.global.control` #262626 | text | dark | 15.13:1 | 4.5:1 | pass | typed text in a field; 'Create' fill-pill label 15 semibold; row text on an iOS grouped row |
| 10 | `color.global.textPrimary` #000000 | `color.global.control` #F1F1F1 | nontext | light | 18.59:1 | 3:1 | pass | '+' glyph on the add tile / '+' circle; '×' on a light sheet's close circle |
| 10 | `color.global.textPrimary` #FFFFFF | `color.global.control` #262626 | nontext | dark | 15.13:1 | 3:1 | pass | '+' glyph on the add tile / '+' circle; '×' on a light sheet's close circle |
| 11 | `color.global.textSecondary` #6E6E6E | `color.global.control` #F1F1F1 | text | light | 4.51:1 | 4.5:1 | pass | placeholder 'Search' 17 pt and row subtitles on a fill (iOS) |
| 11 | `color.global.textSecondary` #999999 | `color.global.control` #262626 | text | dark | 5.31:1 | 4.5:1 | pass | placeholder 'Search' 17 pt and row subtitles on a fill (iOS) |
| 12 | `color.global.textPrimary` #000000 | `color.global.surfaceSecondary.android` #F7F7F7 | text | light | 19.60:1 | 4.5:1 | pass | Android grouped-row title / chip label |
| 12 | `color.global.textPrimary` #FFFFFF | `color.global.surfaceSecondary.android` #262626 | text | dark | 15.13:1 | 4.5:1 | pass | Android grouped-row title / chip label |
| 13 | `color.global.control` #F1F1F1 | `color.global.background` #FFFFFF | nontext | light | 1.13:1 | 3:1 | **FAIL** | tile / field / circle / grouped-row fill against the page |
| 13 | `color.global.control` #262626 | `color.global.background` #000000 | nontext | dark | 1.39:1 | 3:1 | **FAIL** | tile / field / circle / grouped-row fill against the page |
| 14 | `color.global.surfaceSecondary.android` #F7F7F7 | `color.global.background.android` #FFFFFF | nontext | light | 1.07:1 | 3:1 | **FAIL** | Android grouped-row / chip fill against the page |
| 14 | `color.global.surfaceSecondary.android` #262626 | `color.global.background.android` #1C1C1E | nontext | dark | 1.12:1 | 3:1 | **FAIL** | Android grouped-row / chip fill against the page |
| 15 | `color.global.emptyTileText` #D9D9D9 | `color.global.control` #F1F1F1 | text | light | 1.25:1 | 4.5:1 | **FAIL** | empty-day tile month / weekday 14 pt |
| 15 | `color.global.emptyTileText` #515151 | `color.global.control` #262626 | text | dark | 1.91:1 | 4.5:1 | **FAIL** | empty-day tile month / weekday 14 pt |
| 16 | `color.global.emptyTileText` #D9D9D9 | `color.global.control` #F1F1F1 | large | light | 1.25:1 | 3:1 | **FAIL** | empty-day tile day number 28 pt semibold (large text) |
| 16 | `color.global.emptyTileText` #515151 | `color.global.control` #262626 | large | dark | 1.91:1 | 3:1 | **FAIL** | empty-day tile day number 28 pt semibold (large text) |
| 17 | `color.global.onAccent` #FFFFFF | `color.global.accent` #000000 | text | light | 21.00:1 | 4.5:1 | pass | primary capsule label 17 semibold; medium capsule label 15 semibold |
| 17 | `color.global.onAccent` #000000 | `color.global.accent` #FFFFFF | text | dark | 21.00:1 | 4.5:1 | pass | primary capsule label 17 semibold; medium capsule label 15 semibold |
| 18 | `color.global.accent` #000000 | `color.global.background` #FFFFFF | nontext | light | 21.00:1 | 3:1 | pass | primary capsule against the page |
| 18 | `color.global.accent` #FFFFFF | `color.global.background` #000000 | nontext | dark | 21.00:1 | 3:1 | pass | primary capsule against the page |
| 19 | `color.global.accent` #000000 | `color.global.background.android` #FFFFFF | nontext | light | 21.00:1 | 3:1 | pass | primary capsule against the Android page |
| 19 | `color.global.accent` #FFFFFF | `color.global.background.android` #1C1C1E | nontext | dark | 17.01:1 | 3:1 | pass | primary capsule against the Android page |
| 20 | `color.global.textPrimary` #000000 | `color.global.background` #FFFFFF | nontext | light | 21.00:1 | 3:1 | pass | outline capsule 1 pt border against the page |
| 20 | `color.global.textPrimary` #FFFFFF | `color.global.background` #000000 | nontext | dark | 21.00:1 | 3:1 | pass | outline capsule 1 pt border against the page |
| 21 | `color.global.controlRaised` #CCCCCC | `color.global.background` #FFFFFF | nontext | light | 1.61:1 | 3:1 | **FAIL** | disabled primary capsule fill (inactive component: exempt) |
| 21 | `color.global.controlRaised` #4D4D4D | `color.global.background` #000000 | nontext | dark | 2.48:1 | 3:1 | **FAIL** | disabled primary capsule fill (inactive component: exempt) |
| 22 | `color.global.tabInactive` #949494 | `color.global.background` #FFFFFF | nontext | light | 3.03:1 | 3:1 | pass | unselected tab glyph against the bar (= page) |
| 22 | `color.global.tabInactive` #999999 | `color.global.background` #000000 | nontext | dark | 7.37:1 | 3:1 | pass | unselected tab glyph against the bar (= page) |
| 23 | `color.global.textPrimary` #000000 | `color.global.tabInactive` #949494 | nontext | light | 6.92:1 | 3:1 | pass | selected vs unselected tab glyph — the state change itself |
| 23 | `color.global.textPrimary` #FFFFFF | `color.global.tabInactive` #999999 | nontext | dark | 2.85:1 | 3:1 | **FAIL** | selected vs unselected tab glyph — the state change itself |
| 24 | `color.global.badge` #D0151A | `color.global.background` #FFFFFF | nontext | light | 5.52:1 | 3:1 | pass | 4 pt unread dot under a tab glyph |
| 24 | `color.global.badge` #D0151A | `color.global.background` #000000 | nontext | dark | 3.80:1 | 3:1 | pass | 4 pt unread dot under a tab glyph |
| 25 | `color.global.onBadge` #FFFFFF | `color.global.badge` #D0151A | text | both | 5.52:1 | 4.5:1 | pass | 'new' label 11 semibold on the red badge |
| 26 | `color.global.onBadge` #FFFFFF | `color.global.badgeMuted` #767676 | text | both | 4.54:1 | 4.5:1 | pass | 'Last Week' label (small semibold) on the grey pill |
| 27 | `color.global.pageDotInactive` #DDDDDD | `color.global.background` #FFFFFF | nontext | light | 1.36:1 | 3:1 | **FAIL** | inactive page dot on the page |
| 27 | `color.global.pageDotInactive` #808080 | `color.global.background` #000000 | nontext | dark | 5.32:1 | 3:1 | pass | inactive page dot on the page |
| 28 | `color.global.pageDotInactive` #DDDDDD | `color.global.backgroundDeep` #000000 | nontext | light | 15.46:1 | 3:1 | pass | inactive page dot on a media surface (recap preview) |
| 28 | `color.global.pageDotInactive` #808080 | `color.global.backgroundDeep` #000000 | nontext | dark | 5.32:1 | 3:1 | pass | inactive page dot on a media surface (recap preview) |
| 29 | `color.global.textPrimary` #000000 | `color.global.pageDotInactive` #DDDDDD | nontext | light | 15.46:1 | 3:1 | pass | active vs inactive page dot (state) |
| 29 | `color.global.textPrimary` #FFFFFF | `color.global.pageDotInactive` #808080 | nontext | dark | 3.95:1 | 3:1 | pass | active vs inactive page dot (state) |
| 30 | `color.global.selection` #0088FF | `color.global.background` #FFFFFF | nontext | light | 3.52:1 | 3:1 | pass | system-blue check circle / switch on the page (iOS) |
| 30 | `color.global.selection` #0091FF | `color.global.background` #000000 | nontext | dark | 6.49:1 | 3:1 | pass | system-blue check circle / switch on the page (iOS) |
| 31 | `color.global.destructive` #D0151A | `color.global.background` #FFFFFF | text | light | 5.52:1 | 4.5:1 | pass | red destructive row / menu text 15–17 regular on the page |
| 31 | `color.global.destructive` #EF6265 | `color.global.background` #000000 | text | dark | 6.61:1 | 4.5:1 | pass | red destructive row / menu text 15–17 regular on the page |
| 32 | `color.global.destructive` #D0151A | `color.global.control` #F1F1F1 | text | light | 4.89:1 | 4.5:1 | pass | red destructive text on an iOS grouped row |
| 32 | `color.global.destructive` #EF6265 | `color.global.control` #262626 | text | dark | 4.76:1 | 4.5:1 | pass | red destructive text on an iOS grouped row |
| 33 | `color.global.destructive` #D0151A | `color.global.surfaceSecondary.android` #F7F7F7 | text | light | 5.15:1 | 4.5:1 | pass | red destructive text on an Android grouped row |
| 33 | `color.global.destructive` #EF6265 | `color.global.surfaceSecondary.android` #262626 | text | dark | 4.76:1 | 4.5:1 | pass | red destructive text on an Android grouped row |
| 34 | `color.global.destructive` #EF6265 | `color.global.controlOnDeep` #262626 | nontext | dark | 4.76:1 | 3:1 | pass | red mic / trash glyph in the voice capsule on media (#262626; dark value in both appearances) |
| 35 | `color.global.separator` #CCCCCC | `color.global.background` #FFFFFF | nontext | light | 1.61:1 | 3:1 | **FAIL** | hairline divider (decorative: not required by SC 1.4.11) |
| 35 | `color.global.separator` #4D4D4D | `color.global.background` #000000 | nontext | dark | 2.48:1 | 3:1 | **FAIL** | hairline divider (decorative: not required by SC 1.4.11) |
| 36 | `color.global.textPrimary` #000000 | `color.global.surfaceElevated` #FFFFFF | text | light | 21.00:1 | 4.5:1 | pass | text on the recap / plan card |
| 36 | `color.global.textPrimary` #FFFFFF | `color.global.surfaceElevated` #181818 | text | dark | 17.76:1 | 4.5:1 | pass | text on the recap / plan card |
| 37 | `color.global.textSecondary` #6E6E6E | `color.global.surfaceElevated` #FFFFFF | text | light | 5.10:1 | 4.5:1 | pass | secondary text ('retro.app'-style footer, plan footnote) on the card |
| 37 | `color.global.textSecondary` #999999 | `color.global.surfaceElevated` #181818 | text | dark | 6.23:1 | 4.5:1 | pass | secondary text ('retro.app'-style footer, plan footnote) on the card |
| 38 | `color.global.textOnMedia` #FFFFFF | `color.global.backgroundDeep` #000000 | text | both | 21.00:1 | 4.5:1 | pass | viewer header name 15 semibold, comment text on black |
| 39 | `color.global.textSecondary` #999999 | `color.global.backgroundDeep` #000000 | text | dark | 7.37:1 | 4.5:1 | pass | viewer 'Week 49' / date 15 regular on black (media surfaces take the dark appearance's value in both appearances: iOS forces .dark, Android reads Tokens.ColorsDark) |
| 40 | `color.global.textOnMedia` #FFFFFF | `color.global.controlOnDeep` #262626 | text | both | 15.13:1 | 4.5:1 | pass | position pill / 'Add a message' label on #262626 |
| 41 | `color.global.textOnMedia` #FFFFFF | `color.global.controlOnDeep` #262626 | nontext | both | 15.13:1 | 3:1 | pass | close / edit glyph in a #262626 circle |
| 42 | `color.global.textSecondary` #999999 | `color.global.controlOnDeep` #262626 | text | dark | 5.31:1 | 4.5:1 | pass | comment-field placeholder on #262626 (media: dark value in both appearances) |
| 43 | `color.global.controlOnDeep` #262626 | `color.global.backgroundDeep` #000000 | nontext | both | 1.39:1 | 3:1 | **FAIL** | #262626 circle / pill / field against black |
| 44 | `color.global.onSurfaceLight` #000000 | `color.global.surfaceLight` #FFFFFF | text | both | 21.00:1 | 4.5:1 | pass | 'Share' / 'Send Postcard' label on the white pill |
| 45 | `color.global.textSecondary` #6E6E6E | `color.global.surfaceLight` #FFFFFF | text | light | 5.10:1 | 4.5:1 | pass | recap card detail line on the white card (white in both appearances: it takes the light value) |
| 46 | `color.global.surfaceLight` #FFFFFF | `color.global.backgroundDeep` #000000 | nontext | both | 21.00:1 | 3:1 | pass | white pill against black |
| 47 | `color.global.textOnMedia` #FFFFFF | `#00000066,#FFFFFF` #999999 | text | both | 2.85:1 | 4.5:1 | **FAIL** | weekday tile label 13 semibold at its baseline (scrim ≈40 % there) over a WHITE photo — worst case |
| 48 | `color.global.textOnMedia` #FFFFFF | `color.global.scrim,#FFFFFF` #666666 | text | both | 5.74:1 | 4.5:1 | pass | white text at the tile's bottom edge (scrim 60 %) over a white photo |
| 49 | `color.global.textOnMedia` #FFFFFF | `color.global.glass,#FFFFFF` #FFFFFF | nontext | both | 1.00:1 | 3:1 | **FAIL** | white glyph in a glass circle over a white photo — worst case |
| 50 | `color.global.textOnMedia` #FFFFFF | `color.global.glass,#7D7263` #8D8376 | nontext | both | 3.72:1 | 3:1 | pass | white glyph in a glass circle over the measured Rewind photo (RWA outside #7D7263) |
| 51 | `color.global.tabInactiveOnMedia` #B1AFAC | `#322C25` #322C25 | nontext | both | 6.29:1 | 3:1 | pass | unselected tab glyph over the measured Rewind photo and scrim (RWA #322C25) |
| 52 | `color.global.system.onSurface` #000000 | `color.global.system.surface` #FFFFFF | text | light | 21.00:1 | 4.5:1 | pass | M3 list item label (bodyLarge) on surface |
| 52 | `color.global.system.onSurface` #FFFFFF | `color.global.system.surface` #1C1C1E | text | dark | 17.01:1 | 4.5:1 | pass | M3 list item label (bodyLarge) on surface |
| 53 | `color.global.system.onSurfaceVariant` #49454F | `color.global.system.surface` #FFFFFF | text | light | 9.34:1 | 4.5:1 | pass | M3 supporting text (bodyMedium 14) on surface |
| 53 | `color.global.system.onSurfaceVariant` #CAC4D0 | `color.global.system.surface` #1C1C1E | text | dark | 9.98:1 | 4.5:1 | pass | M3 supporting text (bodyMedium 14) on surface |
| 54 | `color.global.system.onSurface` #000000 | `color.global.system.surfaceContainerHigh` #ECE6F0 | text | light | 17.14:1 | 4.5:1 | pass | M3 dialog headline / text on the dialog container |
| 54 | `color.global.system.onSurface` #FFFFFF | `color.global.system.surfaceContainerHigh` #2B2930 | text | dark | 14.36:1 | 4.5:1 | pass | M3 dialog headline / text on the dialog container |
| 55 | `color.global.system.onSurfaceVariant` #49454F | `color.global.system.surfaceContainerHigh` #ECE6F0 | text | light | 7.63:1 | 4.5:1 | pass | M3 dialog supporting text |
| 55 | `color.global.system.onSurfaceVariant` #CAC4D0 | `color.global.system.surfaceContainerHigh` #2B2930 | text | dark | 8.42:1 | 4.5:1 | pass | M3 dialog supporting text |
| 56 | `color.global.system.primary` #0066CE | `color.global.system.surfaceContainerHigh` #ECE6F0 | text | light | 4.52:1 | 4.5:1 | pass | M3 dialog action label (labelLarge 14/500) in Retro blue |
| 56 | `color.global.system.primary` #2592FF | `color.global.system.surfaceContainerHigh` #2B2930 | text | dark | 4.54:1 | 4.5:1 | pass | M3 dialog action label (labelLarge 14/500) in Retro blue |
| 57 | `color.global.system.primary` #0066CE | `color.global.system.surface` #FFFFFF | text | light | 5.54:1 | 4.5:1 | pass | M3 text button / link in Retro blue on surface |
| 57 | `color.global.system.primary` #2592FF | `color.global.system.surface` #1C1C1E | text | dark | 5.38:1 | 4.5:1 | pass | M3 text button / link in Retro blue on surface |
| 58 | `color.global.system.error` #D0151A | `color.global.system.surface` #FFFFFF | text | light | 5.52:1 | 4.5:1 | pass | M3 error / destructive text on surface |
| 58 | `color.global.system.error` #EF6265 | `color.global.system.surface` #1C1C1E | text | dark | 5.35:1 | 4.5:1 | pass | M3 error / destructive text on surface |
| 59 | `color.global.system.error` #D0151A | `color.global.system.surfaceContainerHigh` #ECE6F0 | text | light | 4.51:1 | 4.5:1 | pass | M3 destructive action label in a dialog |
| 59 | `color.global.system.error` #EF6265 | `color.global.system.surfaceContainerHigh` #2B2930 | text | dark | 4.52:1 | 4.5:1 | pass | M3 destructive action label in a dialog |
| 60 | `color.global.system.onSurface` #000000 | `color.global.system.surfaceContainerLow` #F7F2FA | text | light | 19.04:1 | 4.5:1 | pass | M3 bottom-sheet list text |
| 60 | `color.global.system.onSurface` #FFFFFF | `color.global.system.surfaceContainerLow` #1D1B20 | text | dark | 17.07:1 | 4.5:1 | pass | M3 bottom-sheet list text |
| 61 | `color.global.system.outline` #79747E | `color.global.system.surface` #FFFFFF | nontext | light | 4.55:1 | 3:1 | pass | M3 outline (outlined field border) |
| 61 | `color.global.system.outline` #938F99 | `color.global.system.surface` #1C1C1E | nontext | dark | 5.37:1 | 3:1 | pass | M3 outline (outlined field border) |
| 62 | `#CAC4D066` | `color.global.system.surfaceContainerLow` #1D1B20 | nontext | dark | 2.71:1 | 3:1 | **FAIL** | M3 sheet drag handle: on-surface-variant at 0.4 opacity (dark) |
| 63 | `#49454F66` | `color.global.system.surfaceContainerLow` #F7F2FA | nontext | light | 2.00:1 | 3:1 | **FAIL** | M3 sheet drag handle: on-surface-variant at 0.4 opacity (light) |
<!-- contrast:end -->

## Owner decision 20 — what was raised and what stays

Owner decision 20 (docs/OWNER_DECISIONS.md, 2026-10-16): **text under WCAG AA (4.5:1; 3:1 for large text)
is raised to the nearest passing value of the same hue; non-text fills keep Retro's values.** "Nearest" is
computed: HLS lightness stepped by 0.001 from Retro's value with hue and saturation held, until every
surface the colour sits on passes. Each raised token is level PLATFORM and keeps Retro's value and evidence
in its own `evidence` field (design/SOURCES.md).

| token | Retro | now (light / dark) | why it moved | result |
|---|---|---|---|---|
| `color.global.textSecondary` | #999999 | **#6E6E6E** / #999999 | 2.85:1 on white, 2.52:1 on the #F1F1F1 fill | 5.10 white · 4.51 #F1F1F1 · 4.76 #F7F7F7 |
| `color.global.textSecondary.android` | black 50 % / white 60 % | **black 57 %** / white 60 % | 4.00:1 on white, 3.95:1 on #F7F7F7 | 5.10 white · 5.01 #F7F7F7 |
| `invite.web.color.bodyDesktop` | black 50 % | **black 57 %** | 4.00:1 on white | 5.10 |
| `color.global.badgeMuted` | #999999 | **#767676** | white label 2.85:1 | 4.54 |
| `color.global.tabInactive` | #B2B2B2 / #999999 | **#949494** / #999999 | glyph 2.12:1 on white (non-text, but the glyph is the control) | 3.03 |
| `color.global.destructive`, `color.global.system.error` | #EA3337 | **#D0151A** / **#EF6265** | 3.41–4.18:1 as text on the light fills / dialog; 3.44–4.07:1 on the dark fills | ≥ 4.51 on every surface in both |
| `color.global.badge` | #EA3337 | **#D0151A** (both) | white 'new' label 4.18:1 | 5.52; unread dot on black 3.80 |
| `color.global.system.primary` | #0A84FF | **#0066CE** / **#2592FF** | dialog action labels 2.98:1 (light) / 3.94:1 (dark) | 4.52 / 4.54 in the dialog |

One red per appearance, as Retro uses one red constant for badge, destructive and M3 error. Apple's
current increased-contrast system colours (HIG Color, read 2026-10-16) move the same way — red light
233,21,45, blue light 30,110,244, systemGray light 108,108,112 — but the red and blue do not pass on
Retro's fills, so the computed values are used and Apple's are cited as corroboration.

**Media surfaces** (viewer, capture, send-to, memories, year story) are black in both appearances: they
take the **dark** appearance's value. iOS already forces `.dark` on those screens; Android media code reads
`Tokens.ColorsDark.globalTextSecondary` / `PageRoles.secondaryText(onMedia = true)` and
`Tokens.ColorsDark.globalDestructive` / `PageRoles.destructive(onMedia = true)`. The media pairs in the
table are therefore checked in the dark appearance only.

## What still fails, and why it stays

**1. Fills against the page — `color.global.control` 1.13:1 (light) / 1.39:1 (dark); Android
`color.global.surfaceSecondary.android` 1.07:1 / 1.12:1; `color.global.controlOnDeep` on black 1.39:1
(non-text).** Decision 20 keeps Retro's fills. Retro's tiles, fields, circle buttons, pills and grouped
rows are flat fills a few levels off the page, with no outline (retro-visual §3.7); they are identified by
their glyph or text, which pass (e.g. black on #F1F1F1 18.6:1, white on #262626 15.1:1).

**2. Empty-day tile text — `color.global.emptyTileText` on the fill: 1.25:1 (light) / 1.91:1 (dark).**
Retro draws the date of an empty day as a faint watermark on a tile that has nothing to open (retro-visual
§4 #2); the tile's accessibility label carries the date (design/components.md "Week-strip tile"). It is
text, so decision 20 would raise it — but raised to 4.5:1 it reads like secondary text and the strip no
longer shows which days are empty. **Kept and listed for the owner** (docs/OWNER_SETUP.md) as the one
open exception.

**3. Tab bar state change in dark — white vs `color.global.tabInactive` #999999 2.85:1.** Both glyphs
pass against the bar (21:1 and 7.37:1); this row compares the two states with each other, which SC 1.4.11
does not require. The selected tab is exposed to VoiceOver / TalkBack as selected.

**4. Inactive page dot on white — `color.global.pageDotInactive` #DDDDDD 1.36:1 (light, non-text).**
A fill (decision 20 keeps it); pagers also announce the page to assistive technology.

**5. Over photos (content-dependent; worst case = a white photo).** The weekday label at its baseline
over a white photo 2.85:1 (passes once the photo is darker than ≈#C0C0C0; 5.74:1 at the tile's bottom
edge); a white glyph in a glass circle 1.00:1 over a white photo, 3.72:1 over the measured Rewind photo.
Retro's scrim values (±15 %); side-by-side checks with real photos (`fixtures/photos/`) decide.

**6. Exempt or decorative:** `color.global.textTertiary` (disabled / inactive text, SC 1.4.3 exempts);
`color.global.controlRaised` (disabled capsule, SC 1.4.11 exempts); `color.global.separator` (decorative
hairline); the M3 sheet drag handle (drawn by Compose; SC 1.4.11 exempts user-agent appearance).

## Pairs not computed

- **iOS system surfaces** (`color.global.system.ios`: native alerts, menus, share sheet, keyboard): Apple
  publishes these dynamic colours by name only. Apple: "Prefer system-defined colors. These colors have
  their own accessible variants that automatically adapt…" (HIG Accessibility).
- **Photos**: every over-photo pair depends on the photo; the over-photo rows give the worst case and one measured
  photo.
- **Surface-specific pairs** (paywall card text over the blurred backdrop, recap cards, widget overlays,
  chat bubbles) belong to the per-surface passes (Pass 2); they reuse `tools/contrast.mjs`.

## Precision note

Colours from RAW iOS captures and the APK are exact; light-mode greys from renders carry ±1–4/255
(retro-visual §3.1). Within those ranges no result above crosses a threshold except the empty-tile text
(±6/255 light), which fails either way.
