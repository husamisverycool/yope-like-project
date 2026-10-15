# Contrast — foundation color pairs

Every text/background and icon/background pair the foundations in `design/tokens/global.json` imply,
checked against W3C WCAG 2.2 (Recommendation 2024-12-12) at level AA:

| kind | threshold | token | applies to |
|---|---|---|---|
| text | 4.5:1 | `layout.global.contrast.text` | text up to 17 pt (iOS) / below 18 sp (Android), not bold — SC 1.4.3 |
| large | 3:1 | `layout.global.contrast.largeText` | text 18 pt and larger, or bold at any size (HIG Accessibility table) — SC 1.4.3 |
| nontext | 3:1 | `layout.global.contrast.nonText` | UI components and graphical objects against adjacent colors — SC 1.4.11 |

Tool: `tools/contrast.mjs` (WCAG 2.2 relative luminance with the 0.04045 sRGB threshold; translucent
colors are composited source-over onto the color beneath them). The table below is generated:
`node tools/contrast.mjs --write` rewrites it from the current tokens; one pair:
`node tools/contrast.mjs <fg> <bg> [text|large|nontext]` (token names or `#RRGGBB(AA)`).

Weights decide the threshold: semibold is not bold, so a 15 pt semibold button label needs 4.5:1.

<!-- contrast:begin -->
| # | foreground | background | kind | ratio | needs | result | use |
|---|---|---|---|---|---|---|---|
| 1 | `color.global.textPrimary` #FFFFFF | `color.global.background` #171717 | text | 17.93:1 | 4.5:1 | pass | message / body text 17 regular on group & chat screens |
| 2 | `color.global.textPrimary` #FFFFFF | `color.global.backgroundDeep` #000000 | text | 21.00:1 | 4.5:1 | pass | names, titles, body on black screens (home, sheets, camera) |
| 3 | `color.global.textPrimary` #FFFFFF | `color.global.control` #2E2E2E | text | 13.58:1 | 4.5:1 | pass | typed text in the composer field; header capsule title |
| 4 | `color.global.textPrimary` #FFFFFF | `color.global.controlRaised` #434343 | text | 9.89:1 | 4.5:1 | pass | selected tab glyph / inner header pill text |
| 5 | `color.global.textPrimary` #FFFFFF | `color.global.controlOnDeep` #101010 | nontext | 19.03:1 | 3:1 | pass | ✕ / ↓ glyphs in header circles on black |
| 6 | `color.global.textPrimary` #FFFFFF | `color.global.control` #2E2E2E | nontext | 13.58:1 | 3:1 | pass | ‹ / film-strip glyphs in header circles on #171717 |
| 7 | `color.global.textSecondary` #969696 | `color.global.background` #171717 | text | 6.06:1 | 4.5:1 | pass | secondary text on group & chat screens |
| 8 | `color.global.textSecondary` #969696 | `color.global.backgroundDeep` #000000 | text | 7.10:1 | 4.5:1 | pass | section label 'suggested friends' (16 semibold) on black |
| 9 | `color.global.textSecondary` #969696 | `color.global.control` #2E2E2E | text | 4.59:1 | 4.5:1 | pass | placeholder 'start typing...' (17 regular) in the composer field |
| 10 | `color.global.textSecondary` #969696 | `color.global.control` #2E2E2E | nontext | 4.59:1 | 3:1 | pass | inactive tab-bar glyphs on the tab-bar capsule |
| 11 | `color.global.onAccent` #000000 | `color.global.accent` #CDFD07 | text | 17.65:1 | 4.5:1 | pass | primary button label (15 semibold) and tooltip text on lime |
| 12 | `color.global.onAccent` #000000 | `color.global.accent` #CDFD07 | nontext | 17.65:1 | 3:1 | pass | camera glyph on the lime composer button |
| 13 | `color.global.accent` #CDFD07 | `color.global.background` #171717 | text | 15.07:1 | 4.5:1 | pass | lime text on #171717 (sender name, links) |
| 14 | `color.global.accent` #CDFD07 | `color.global.backgroundDeep` #000000 | text | 17.65:1 | 4.5:1 | pass | lime text on black (sender name on home, 'try other options' link) |
| 15 | `color.global.accent` #CDFD07 | `color.global.background` #171717 | nontext | 15.07:1 | 3:1 | pass | lime button / shutter ring against #171717 |
| 16 | `color.global.accent` #CDFD07 | `color.global.backgroundDeep` #000000 | nontext | 17.65:1 | 3:1 | pass | lime button / shutter ring against black |
| 17 | `color.global.onSurfaceLight` #000000 | `color.global.surfaceLight` #FFFFFF | text | 21.00:1 | 4.5:1 | pass | label on white pill buttons ('invite more friends', 'enable') |
| 18 | `color.global.surfaceLight` #FFFFFF | `color.global.backgroundDeep` #000000 | nontext | 21.00:1 | 3:1 | pass | white pill button against black |
| 19 | `color.global.surfaceLight` #FFFFFF | `color.global.background` #171717 | nontext | 17.93:1 | 3:1 | pass | white pill / selected segment against #171717 |
| 20 | `color.global.control` #2E2E2E | `color.global.background` #171717 | nontext | 1.32:1 | 3:1 | **FAIL** | circle button / capsule fill against #171717 |
| 21 | `color.global.controlOnDeep` #101010 | `color.global.backgroundDeep` #000000 | nontext | 1.10:1 | 3:1 | **FAIL** | header circle fill against black |
| 22 | `color.global.controlRaised` #434343 | `color.global.control` #2E2E2E | nontext | 1.37:1 | 3:1 | **FAIL** | selected tab pill against the tab-bar capsule |
| 23 | `color.global.textPrimary` #FFFFFF | `color.global.textSecondary` #969696 | nontext | 2.96:1 | 3:1 | **FAIL** | selected (white) vs inactive (gray) tab glyph — the state change itself |
| 24 | `color.global.selection` #0091FF | `color.global.backgroundDeep` #000000 | nontext | 6.49:1 | 3:1 | pass | filled check circle on black pickers |
| 25 | `color.global.selection` #0091FF | `color.global.background` #171717 | nontext | 5.54:1 | 3:1 | pass | filled check circle on #171717 |
| 26 | `color.global.textPrimary` #FFFFFF | `color.global.accentSecondary` #FE1F84 | large | 3.66:1 | 3:1 | pass | white name on the pink sticker (heavy display text, large/bold threshold) |
| 27 | `color.global.textPrimary` #FFFFFF | `color.global.accentSecondary` #FE1F84 | text | 3.66:1 | 4.5:1 | **FAIL** | white text under 18 pt, not bold, on the pink (not observed; shows the limit) |
| 28 | `color.global.accentSecondary` #FE1F84 | `color.global.background` #171717 | nontext | 4.90:1 | 3:1 | pass | pink card outline against #171717 |
| 29 | `color.global.destructive` #FF4245 | `color.global.background` #171717 | text | 5.22:1 | 4.5:1 | pass | red destructive menu text (systemRed, dark) on #171717 |
| 30 | `color.global.destructive` #FF4245 | `color.global.backgroundDeep` #000000 | text | 6.12:1 | 4.5:1 | pass | red destructive text (systemRed, dark) on black |
| 31 | `color.global.system.onSurface` #E6E0E9 | `color.global.system.surface` #141218 | text | 14.35:1 | 4.5:1 | pass | M3 list item label (bodyLarge 16) on surface |
| 32 | `color.global.system.onSurfaceVariant` #CAC4D0 | `color.global.system.surface` #141218 | text | 10.91:1 | 4.5:1 | pass | M3 supporting text (bodyMedium 14) on surface |
| 33 | `color.global.system.onSurface` #E6E0E9 | `color.global.system.surfaceContainerHigh` #2B2930 | text | 11.08:1 | 4.5:1 | pass | M3 dialog headline / text on dialog container |
| 34 | `color.global.system.onSurfaceVariant` #CAC4D0 | `color.global.system.surfaceContainerHigh` #2B2930 | text | 8.42:1 | 4.5:1 | pass | M3 dialog supporting text |
| 35 | `color.global.system.primary` #D0BCFF | `color.global.system.surfaceContainerHigh` #2B2930 | text | 8.42:1 | 4.5:1 | pass | M3 dialog action label (labelLarge 14/500) |
| 36 | `color.global.system.error` #F2B8B5 | `color.global.system.surface` #141218 | text | 10.89:1 | 4.5:1 | pass | M3 error / destructive text on surface |
| 37 | `color.global.system.error` #F2B8B5 | `color.global.system.surfaceContainerHigh` #2B2930 | text | 8.41:1 | 4.5:1 | pass | M3 destructive action label in a dialog |
| 38 | `color.global.system.onSurface` #E6E0E9 | `color.global.system.surfaceContainerLow` #1D1B20 | text | 13.17:1 | 4.5:1 | pass | M3 bottom-sheet list text |
| 39 | `color.global.system.outline` #938F99 | `color.global.system.surface` #141218 | nontext | 5.87:1 | 3:1 | pass | M3 list divider (1 dp outline) |
| 40 | `#CAC4D066` | `color.global.system.surfaceContainerLow` #1D1B20 | nontext | 2.71:1 | 3:1 | **FAIL** | M3 sheet drag handle: on-surface-variant at 0.4 opacity |
<!-- contrast:end -->

## Failures and what the research offers instead

No value was changed to pass. For each failure the research was searched for a sourced alternative pair.

**1. `color.global.control` #2E2E2E against `color.global.background` #171717 — 1.32:1 (non-text, needs 3:1).**
The fill of Yope's circle buttons, header capsule, composer field and tab-bar capsule barely separates
from the screen. Searched alternatives: Yope draws a 1-2 px lighter rim on these controls. Measured in
this pass on the original lossless PNGs (not the bicubic-rotated derivatives): tab-bar rim #555555
(`references/auto/yope/store/yope-store-02.png` col 900, y 2333-2334) → 2.40:1 against #171717 and 1.82:1
against the fill; composer-field rim peak #4B4B4B (`yope-store-05.png` col 600, y 2397) → 2.06:1;
yope-b's bubble rim #404040 → 1.73:1. **No sourced pair reaches 3:1.** What does pass: the glyph or
text inside each control — white on #2E2E2E 13.58:1, #969696 on #2E2E2E 4.59:1 (pairs 3, 6, 9, 10). SC 1.4.11
asks for 3:1 on "visual information required to identify user interface components"; these controls are
identified by their glyph or text, not by the fill edge. Reported, not resolved here (owner / verification).

**2. `color.global.controlOnDeep` #101010 against `color.global.backgroundDeep` #000000 — 1.10:1 (non-text).**
Same situation on black screens; the ✕ / ↓ glyphs pass at 19.03:1 (pair 5). The #101010 value itself is
video-only (MERGE_DECISIONS F-5). No sourced alternative.

**3. `color.global.controlRaised` #434343 against `color.global.control` #2E2E2E — 1.37:1 (non-text), and the
state change white vs #969696 glyph — 2.96:1 (non-text).** The selected tab is shown by the raised pill
plus a white glyph; neither cue reaches 3:1 on its own. Both values are lossless measurements of
`yope-store-02.png`. No sourced alternative state indicator was found in the research (yope-a §1.5). A
selected-state check (SC 1.4.11 "states") should be part of the tab-bar surface review.

**4. `color.global.textPrimary` #FFFFFF on `color.global.accentSecondary` #FE1F84 — 3.66:1.** Passes as
large / bold text (the observed name sticker is heavy display text, pair "large"); **fails for text under
18 pt that is not bold** (pair "text"). Use on the pink only bold or ≥ 18 pt text, or none: the pink itself
is unresolved (MERGE_DECISIONS F-7).

**5. Material 3 drag handle — `on-surface-variant` at 0.4 opacity over `surface-container-low`: 2.71:1 (non-text).**
This is the M3 default (`design/proposals/platform.tokens.json` `opacity.safety.sheetHandle.android`
0.4, `dimension.safety.sheetHandle.android` 32×4 dp). It is a platform component drawn by Compose; SC
1.4.11 exempts components "where the appearance of the component is determined by the user agent and not
modified by the author". Recorded for the Android sheet review; not changed.

## Pairs not computed

- **iOS system surfaces** (`color.global.system.ios`: systemGroupedBackground, secondarySystemGroupedBackground,
  label, secondaryLabel, separator): Apple's HIG publishes no hex values for these dynamic colors, so no
  ratio can be computed from documentation. Apple: "Prefer system-defined colors. These colors have their
  own accessible variants that automatically adapt…" (HIG Accessibility).
- **`color.global.separator`, `color.global.scrim`**: BLOCKED (not measured in Yope).
- **Surface-specific pairs** (chat bubbles, reaction capsule, home cards, Locket / BeReal / Timehop colors)
  belong to the per-surface consolidation passes; they can reuse `tools/contrast.mjs`.

## Precision note

Video-sourced colors carry ±8/255 (yope-a §0.3); within that range `controlOnDeep` vs black spans
1.0-1.3:1 (fails either way). All other Yope colors above come from lossless PNGs (±1-2/255), which moves
no result across a threshold.
