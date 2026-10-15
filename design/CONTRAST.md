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
| 3 | `color.global.textSecondary` #999999 | `color.global.background` #FFFFFF | text | light | 2.85:1 | 4.5:1 | **FAIL** | secondary text 13–15 pt regular on the page: date range, real name, list subtitle, legal 14 pt (iOS) |
| 3 | `color.global.textSecondary` #999999 | `color.global.background` #000000 | text | dark | 7.37:1 | 4.5:1 | pass | secondary text 13–15 pt regular on the page: date range, real name, list subtitle, legal 14 pt (iOS) |
| 4 | `color.global.textSecondary` #999999 | `color.global.background` #FFFFFF | large | light | 2.85:1 | 3:1 | **FAIL** | grey 'Friends Only' 30 pt on the landing (large text) |
| 4 | `color.global.textSecondary` #999999 | `color.global.background` #000000 | large | dark | 7.37:1 | 3:1 | pass | grey 'Friends Only' 30 pt on the landing (large text) |
| 5 | `color.global.textSecondary.android` #7F7F7F | `color.global.background.android` #FFFFFF | text | light | 4.00:1 | 4.5:1 | **FAIL** | Android meta lines (black 50 % / white 60 %) on the page |
| 5 | `color.global.textSecondary.android` #A4A4A5 | `color.global.background.android` #1C1C1E | text | dark | 6.85:1 | 4.5:1 | pass | Android meta lines (black 50 % / white 60 %) on the page |
| 6 | `color.global.textSecondary.android` #7B7B7B | `color.global.surfaceSecondary.android` #F7F7F7 | text | light | 3.95:1 | 4.5:1 | **FAIL** | Android row subtitle on a grouped row |
| 6 | `color.global.textSecondary.android` #A8A8A8 | `color.global.surfaceSecondary.android` #262626 | text | dark | 6.38:1 | 4.5:1 | pass | Android row subtitle on a grouped row |
| 7 | `color.global.textTertiary` #C1C1C1 | `color.global.background` #FFFFFF | text | light | 1.80:1 | 4.5:1 | **FAIL** | tertiary / disabled text (WCAG exempts inactive components) |
| 7 | `color.global.textTertiary` #4D4D4D | `color.global.background` #000000 | text | dark | 2.48:1 | 4.5:1 | **FAIL** | tertiary / disabled text (WCAG exempts inactive components) |
| 8 | `color.global.textTertiary` #C1C1C1 | `color.global.background.android` #FFFFFF | text | light | 1.80:1 | 4.5:1 | **FAIL** | tertiary / disabled text on the Android page |
| 8 | `color.global.textTertiary` #616162 | `color.global.background.android` #1C1C1E | text | dark | 2.73:1 | 4.5:1 | **FAIL** | tertiary / disabled text on the Android page |
| 9 | `color.global.textPrimary` #000000 | `color.global.control` #F1F1F1 | text | light | 18.59:1 | 4.5:1 | pass | typed text in a field; 'Create' fill-pill label 15 semibold; row text on an iOS grouped row |
| 9 | `color.global.textPrimary` #FFFFFF | `color.global.control` #262626 | text | dark | 15.13:1 | 4.5:1 | pass | typed text in a field; 'Create' fill-pill label 15 semibold; row text on an iOS grouped row |
| 10 | `color.global.textPrimary` #000000 | `color.global.control` #F1F1F1 | nontext | light | 18.59:1 | 3:1 | pass | '+' glyph on the add tile / '+' circle; '×' on a light sheet's close circle |
| 10 | `color.global.textPrimary` #FFFFFF | `color.global.control` #262626 | nontext | dark | 15.13:1 | 3:1 | pass | '+' glyph on the add tile / '+' circle; '×' on a light sheet's close circle |
| 11 | `color.global.textSecondary` #999999 | `color.global.control` #F1F1F1 | text | light | 2.52:1 | 4.5:1 | **FAIL** | placeholder 'Search' 17 pt and row subtitles on a fill (iOS) |
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
| 22 | `color.global.tabInactive` #B2B2B2 | `color.global.background` #FFFFFF | nontext | light | 2.12:1 | 3:1 | **FAIL** | unselected tab glyph against the bar (= page) |
| 22 | `color.global.tabInactive` #999999 | `color.global.background` #000000 | nontext | dark | 7.37:1 | 3:1 | pass | unselected tab glyph against the bar (= page) |
| 23 | `color.global.textPrimary` #000000 | `color.global.tabInactive` #B2B2B2 | nontext | light | 9.90:1 | 3:1 | pass | selected vs unselected tab glyph — the state change itself |
| 23 | `color.global.textPrimary` #FFFFFF | `color.global.tabInactive` #999999 | nontext | dark | 2.85:1 | 3:1 | **FAIL** | selected vs unselected tab glyph — the state change itself |
| 24 | `color.global.badge` #EA3337 | `color.global.background` #FFFFFF | nontext | light | 4.18:1 | 3:1 | pass | 4 pt unread dot under a tab glyph |
| 24 | `color.global.badge` #EA3337 | `color.global.background` #000000 | nontext | dark | 5.03:1 | 3:1 | pass | 4 pt unread dot under a tab glyph |
| 25 | `color.global.onBadge` #FFFFFF | `color.global.badge` #EA3337 | text | both | 4.18:1 | 4.5:1 | **FAIL** | 'new' label 11 semibold on the red badge |
| 26 | `color.global.onBadge` #FFFFFF | `color.global.badgeMuted` #999999 | text | both | 2.85:1 | 4.5:1 | **FAIL** | 'Last Week' label (small semibold) on the grey pill |
| 27 | `color.global.pageDotInactive` #DDDDDD | `color.global.background` #FFFFFF | nontext | light | 1.36:1 | 3:1 | **FAIL** | inactive page dot on the page |
| 27 | `color.global.pageDotInactive` #808080 | `color.global.background` #000000 | nontext | dark | 5.32:1 | 3:1 | pass | inactive page dot on the page |
| 28 | `color.global.pageDotInactive` #DDDDDD | `color.global.backgroundDeep` #000000 | nontext | light | 15.46:1 | 3:1 | pass | inactive page dot on a media surface (recap preview) |
| 28 | `color.global.pageDotInactive` #808080 | `color.global.backgroundDeep` #000000 | nontext | dark | 5.32:1 | 3:1 | pass | inactive page dot on a media surface (recap preview) |
| 29 | `color.global.textPrimary` #000000 | `color.global.pageDotInactive` #DDDDDD | nontext | light | 15.46:1 | 3:1 | pass | active vs inactive page dot (state) |
| 29 | `color.global.textPrimary` #FFFFFF | `color.global.pageDotInactive` #808080 | nontext | dark | 3.95:1 | 3:1 | pass | active vs inactive page dot (state) |
| 30 | `color.global.selection` #0088FF | `color.global.background` #FFFFFF | nontext | light | 3.52:1 | 3:1 | pass | system-blue check circle / switch on the page (iOS) |
| 30 | `color.global.selection` #0091FF | `color.global.background` #000000 | nontext | dark | 6.49:1 | 3:1 | pass | system-blue check circle / switch on the page (iOS) |
| 31 | `color.global.destructive` #EA3337 | `color.global.background` #FFFFFF | text | light | 4.18:1 | 4.5:1 | **FAIL** | red destructive row / menu text 15–17 regular on the page |
| 31 | `color.global.destructive` #EA3337 | `color.global.background` #000000 | text | dark | 5.03:1 | 4.5:1 | pass | red destructive row / menu text 15–17 regular on the page |
| 32 | `color.global.destructive` #EA3337 | `color.global.control` #F1F1F1 | text | light | 3.70:1 | 4.5:1 | **FAIL** | red destructive text on an iOS grouped row |
| 32 | `color.global.destructive` #EA3337 | `color.global.control` #262626 | text | dark | 3.62:1 | 4.5:1 | **FAIL** | red destructive text on an iOS grouped row |
| 33 | `color.global.destructive` #EA3337 | `color.global.surfaceSecondary.android` #F7F7F7 | text | light | 3.90:1 | 4.5:1 | **FAIL** | red destructive text on an Android grouped row |
| 33 | `color.global.destructive` #EA3337 | `color.global.surfaceSecondary.android` #262626 | text | dark | 3.62:1 | 4.5:1 | **FAIL** | red destructive text on an Android grouped row |
| 34 | `color.global.separator` #CCCCCC | `color.global.background` #FFFFFF | nontext | light | 1.61:1 | 3:1 | **FAIL** | hairline divider (decorative: not required by SC 1.4.11) |
| 34 | `color.global.separator` #4D4D4D | `color.global.background` #000000 | nontext | dark | 2.48:1 | 3:1 | **FAIL** | hairline divider (decorative: not required by SC 1.4.11) |
| 35 | `color.global.textPrimary` #000000 | `color.global.surfaceElevated` #FFFFFF | text | light | 21.00:1 | 4.5:1 | pass | text on the recap / plan card |
| 35 | `color.global.textPrimary` #FFFFFF | `color.global.surfaceElevated` #181818 | text | dark | 17.76:1 | 4.5:1 | pass | text on the recap / plan card |
| 36 | `color.global.textSecondary` #999999 | `color.global.surfaceElevated` #FFFFFF | text | light | 2.85:1 | 4.5:1 | **FAIL** | secondary text ('retro.app'-style footer, plan footnote) on the card |
| 36 | `color.global.textSecondary` #999999 | `color.global.surfaceElevated` #181818 | text | dark | 6.23:1 | 4.5:1 | pass | secondary text ('retro.app'-style footer, plan footnote) on the card |
| 37 | `color.global.textOnMedia` #FFFFFF | `color.global.backgroundDeep` #000000 | text | both | 21.00:1 | 4.5:1 | pass | viewer header name 15 semibold, comment text on black |
| 38 | `color.global.textSecondary` #999999 | `color.global.backgroundDeep` #000000 | text | both | 7.37:1 | 4.5:1 | pass | viewer 'Week 49' / date 15 regular on black |
| 39 | `color.global.textOnMedia` #FFFFFF | `color.global.controlOnDeep` #262626 | text | both | 15.13:1 | 4.5:1 | pass | position pill / 'Add a message' label on #262626 |
| 40 | `color.global.textOnMedia` #FFFFFF | `color.global.controlOnDeep` #262626 | nontext | both | 15.13:1 | 3:1 | pass | close / edit glyph in a #262626 circle |
| 41 | `color.global.textSecondary` #999999 | `color.global.controlOnDeep` #262626 | text | both | 5.31:1 | 4.5:1 | pass | comment-field placeholder on #262626 |
| 42 | `color.global.controlOnDeep` #262626 | `color.global.backgroundDeep` #000000 | nontext | both | 1.39:1 | 3:1 | **FAIL** | #262626 circle / pill / field against black |
| 43 | `color.global.onSurfaceLight` #000000 | `color.global.surfaceLight` #FFFFFF | text | both | 21.00:1 | 4.5:1 | pass | 'Share' / 'Send Postcard' label on the white pill |
| 44 | `color.global.surfaceLight` #FFFFFF | `color.global.backgroundDeep` #000000 | nontext | both | 21.00:1 | 3:1 | pass | white pill against black |
| 45 | `color.global.textOnMedia` #FFFFFF | `#00000066,#FFFFFF` #999999 | text | both | 2.85:1 | 4.5:1 | **FAIL** | weekday tile label 13 semibold at its baseline (scrim ≈40 % there) over a WHITE photo — worst case |
| 46 | `color.global.textOnMedia` #FFFFFF | `color.global.scrim,#FFFFFF` #666666 | text | both | 5.74:1 | 4.5:1 | pass | white text at the tile's bottom edge (scrim 60 %) over a white photo |
| 47 | `color.global.textOnMedia` #FFFFFF | `color.global.glass,#FFFFFF` #FFFFFF | nontext | both | 1.00:1 | 3:1 | **FAIL** | white glyph in a glass circle over a white photo — worst case |
| 48 | `color.global.textOnMedia` #FFFFFF | `color.global.glass,#7D7263` #8D8376 | nontext | both | 3.72:1 | 3:1 | pass | white glyph in a glass circle over the measured Rewind photo (RWA outside #7D7263) |
| 49 | `color.global.tabInactiveOnMedia` #B1AFAC | `#322C25` #322C25 | nontext | both | 6.29:1 | 3:1 | pass | unselected tab glyph over the measured Rewind photo and scrim (RWA #322C25) |
| 50 | `color.global.system.onSurface` #000000 | `color.global.system.surface` #FFFFFF | text | light | 21.00:1 | 4.5:1 | pass | M3 list item label (bodyLarge) on surface |
| 50 | `color.global.system.onSurface` #FFFFFF | `color.global.system.surface` #1C1C1E | text | dark | 17.01:1 | 4.5:1 | pass | M3 list item label (bodyLarge) on surface |
| 51 | `color.global.system.onSurfaceVariant` #49454F | `color.global.system.surface` #FFFFFF | text | light | 9.34:1 | 4.5:1 | pass | M3 supporting text (bodyMedium 14) on surface |
| 51 | `color.global.system.onSurfaceVariant` #CAC4D0 | `color.global.system.surface` #1C1C1E | text | dark | 9.98:1 | 4.5:1 | pass | M3 supporting text (bodyMedium 14) on surface |
| 52 | `color.global.system.onSurface` #000000 | `color.global.system.surfaceContainerHigh` #ECE6F0 | text | light | 17.14:1 | 4.5:1 | pass | M3 dialog headline / text on the dialog container |
| 52 | `color.global.system.onSurface` #FFFFFF | `color.global.system.surfaceContainerHigh` #2B2930 | text | dark | 14.36:1 | 4.5:1 | pass | M3 dialog headline / text on the dialog container |
| 53 | `color.global.system.onSurfaceVariant` #49454F | `color.global.system.surfaceContainerHigh` #ECE6F0 | text | light | 7.63:1 | 4.5:1 | pass | M3 dialog supporting text |
| 53 | `color.global.system.onSurfaceVariant` #CAC4D0 | `color.global.system.surfaceContainerHigh` #2B2930 | text | dark | 8.42:1 | 4.5:1 | pass | M3 dialog supporting text |
| 54 | `color.global.system.primary` #0A84FF | `color.global.system.surfaceContainerHigh` #ECE6F0 | text | light | 2.98:1 | 4.5:1 | **FAIL** | M3 dialog action label (labelLarge 14/500) in Retro blue |
| 54 | `color.global.system.primary` #0A84FF | `color.global.system.surfaceContainerHigh` #2B2930 | text | dark | 3.94:1 | 4.5:1 | **FAIL** | M3 dialog action label (labelLarge 14/500) in Retro blue |
| 55 | `color.global.system.primary` #0A84FF | `color.global.system.surface` #FFFFFF | text | light | 3.65:1 | 4.5:1 | **FAIL** | M3 text button / link in Retro blue on surface |
| 55 | `color.global.system.primary` #0A84FF | `color.global.system.surface` #1C1C1E | text | dark | 4.66:1 | 4.5:1 | pass | M3 text button / link in Retro blue on surface |
| 56 | `color.global.system.error` #EA3337 | `color.global.system.surface` #FFFFFF | text | light | 4.18:1 | 4.5:1 | **FAIL** | M3 error / destructive text on surface |
| 56 | `color.global.system.error` #EA3337 | `color.global.system.surface` #1C1C1E | text | dark | 4.07:1 | 4.5:1 | **FAIL** | M3 error / destructive text on surface |
| 57 | `color.global.system.error` #EA3337 | `color.global.system.surfaceContainerHigh` #ECE6F0 | text | light | 3.41:1 | 4.5:1 | **FAIL** | M3 destructive action label in a dialog |
| 57 | `color.global.system.error` #EA3337 | `color.global.system.surfaceContainerHigh` #2B2930 | text | dark | 3.44:1 | 4.5:1 | **FAIL** | M3 destructive action label in a dialog |
| 58 | `color.global.system.onSurface` #000000 | `color.global.system.surfaceContainerLow` #F7F2FA | text | light | 19.04:1 | 4.5:1 | pass | M3 bottom-sheet list text |
| 58 | `color.global.system.onSurface` #FFFFFF | `color.global.system.surfaceContainerLow` #1D1B20 | text | dark | 17.07:1 | 4.5:1 | pass | M3 bottom-sheet list text |
| 59 | `color.global.system.outline` #79747E | `color.global.system.surface` #FFFFFF | nontext | light | 4.55:1 | 3:1 | pass | M3 outline (outlined field border) |
| 59 | `color.global.system.outline` #938F99 | `color.global.system.surface` #1C1C1E | nontext | dark | 5.37:1 | 3:1 | pass | M3 outline (outlined field border) |
| 60 | `#CAC4D066` | `color.global.system.surfaceContainerLow` #1D1B20 | nontext | dark | 2.71:1 | 3:1 | **FAIL** | M3 sheet drag handle: on-surface-variant at 0.4 opacity (dark) |
| 61 | `#49454F66` | `color.global.system.surfaceContainerLow` #F7F2FA | nontext | light | 2.00:1 | 3:1 | **FAIL** | M3 sheet drag handle: on-surface-variant at 0.4 opacity (light) |
<!-- contrast:end -->

## Failures and what the research offers instead

No value was changed to pass (CONVENTIONS: never adjust a sourced value). For each failure the Retro
research and the platform references were searched for a sourced alternative pair.

**1. Retro's secondary grey in light appearance — `color.global.textSecondary` #999999 on white 2.85:1,
on the fill #F1F1F1 2.52:1, on the white card 2.85:1 (text, needs 4.5:1); the 30 pt grey landing line
fails even the large-text 3:1.** This is the date range, real name, list subtitle, placeholder and legal
text in light mode. Dark passes (7.37:1 on black). Searched: Retro Android's own secondary (black 50 %,
`color.global.textSecondary.android`) gives 4.00:1 on white / 3.95:1 on #F7F7F7 — closer, still fails;
the paywall card's secondary #757A7D on its tinted card 3.92:1; iOS `secondaryLabel` (#3C3C43 at 60 %)
3.44:1; the empty-state grey #A4A4A4 (TC-2B) 2.49:1. **No sourced grey reaches 4.5:1 on white**; only
`color.global.textPrimary` does. Reported for the owner / verification (MERGE_DECISIONS R-13); the
landing line is only captured in dark (LAND), where it passes.

**2. Fills against the page — `color.global.control` 1.13:1 (light) / 1.39:1 (dark); Android
`color.global.surfaceSecondary.android` 1.07:1 / 1.12:1; `color.global.controlOnDeep` on black 1.39:1
(non-text).** Retro's tiles, fields, circle buttons, pills and grouped rows are flat fills a few levels
off the page, with no outline (retro-visual §3.7). SC 1.4.11 asks for 3:1 on "visual information required
to identify user interface components": these components are identified by their glyph or text, which
pass (pairs 9–12, 39–40, 41 in the dark — e.g. black on #F1F1F1 18.8:1, white on #262626 15.1:1). No
sourced outline exists to add. Reported.

**3. Empty-day tile text — `color.global.emptyTileText` on the fill: 1.25:1 (light) / 1.91:1 (dark), for
both the 14 pt month / weekday and the 28 pt semibold day number.** Retro draws the date of an empty
day as a faint watermark (retro-visual §4 #2). No sourced alternative (the only other tile text is the
white weekday label on photos). The tile's accessibility label must carry the date (design/components.md
"Week-strip tile"). Reported.

**4. Tab bar — inactive glyph `color.global.tabInactive` #B2B2B2 on white 2.12:1 (light, non-text); the
state change white vs #999999 2.85:1 (dark, non-text).** Retro's tab bar has no labels and no selected
pill; selection is the glyph colour alone (H43, ST-01). Selected / unselected pass in the other
appearance (10.0:1 light state change; 7.37:1 dark inactive glyph). No sourced alternative state
indicator. The selected tab is exposed to VoiceOver / TalkBack as selected (components.md "Tab bar").
Reported.

**5. Retro red #EA3337 — white on red 4.18:1 (the 11 pt semibold "new" badge); red text on white 4.18:1,
on the fills 3.62–3.90:1; Android M3 error on surface 4.07–4.18:1 and on the dialog container
3.41–3.44:1 (all text).** Passes the large / bold 3:1 everywhere. Searched: iOS `systemRed` light
#FF383C is lower (3.57:1 on white). No sourced alternative. Reported (red is used only for the badge,
the unread dot — which passes as non-text, 4.18:1 / 5.03:1 — and destructive labels).

**6. Retro blue #0A84FF (Android M3 primary) — on the M3 baseline dialog container 2.98:1 (light) /
3.94:1 (dark), on white 3.65:1 (text: dialog action labels, text buttons).** Retro sets only primary and
leaves the dialog container at the M3 baseline (`color.global.system.surfaceContainerHigh`). The M3
baseline primary (#6750A4, 5.26:1 on #ECE6F0) passes but is not Retro's; iOS systemBlue light also fails
(≈3.6:1). Reported (MERGE_DECISIONS R-13).

**7. Grey relative-week pill — white on `color.global.badgeMuted` #999999 2.85:1.** Small semibold label
(JED, ENG-D). No alternative. Reported.

**8. Over photos (content-dependent; worst case = a white photo).** The weekday label (13 pt semibold) at
its baseline sits where the bottom scrim is ≈40 % black: 2.85:1 over a white photo (passes 4.5:1 once the
photo underneath is darker than ≈#C0C0C0); at the tile's bottom edge (60 %) it reaches 5.74:1. A white
glyph in a glass circle is 1.00:1 over a white photo and 3.72:1 over the measured Rewind photo (RWA).
The scrim values are Retro's (±15 %). Reported; side-by-side verification with real photos
(`fixtures/photos/`) decides whether the label reads.

**9. Inactive page dot on white — `color.global.pageDotInactive` #DDDDDD 1.36:1 (light, non-text).**
Dark passes (5.32:1). Pagers also announce the page to assistive technology. Reported.

**10. Exempt or decorative (listed for completeness, not failures of the rule):**
`color.global.textTertiary` (1.80–2.73:1) is used for disabled / inactive text, which SC 1.4.3 exempts;
the disabled capsule fill `color.global.controlRaised` (1.61 / 2.48:1) is an inactive component (SC
1.4.11 exempts); the hairline `color.global.separator` (1.61 / 2.48:1) is decorative; the M3 sheet drag
handle (2.00 / 2.71:1) is drawn by Compose (SC 1.4.11 exempts components "where the appearance of the
component is determined by the user agent and not modified by the author").

## Pairs not computed

- **iOS system surfaces** (`color.global.system.ios`: native alerts, menus, share sheet, keyboard): Apple
  publishes these dynamic colours by name only. Apple: "Prefer system-defined colors. These colors have
  their own accessible variants that automatically adapt…" (HIG Accessibility).
- **Photos**: every over-photo pair depends on the photo; rows 45–48 give the worst case and one measured
  photo.
- **Surface-specific pairs** (paywall card text over the blurred backdrop, recap cards, widget overlays,
  chat bubbles) belong to the per-surface passes (Pass 2); they reuse `tools/contrast.mjs`.

## Precision note

Colours from RAW iOS captures and the APK are exact; light-mode greys from renders carry ±1–4/255
(retro-visual §3.1). Within those ranges no result above crosses a threshold except the empty-tile text
(±6/255 light), which fails either way.
