# widget.styles — the widget styles (one free, two premium)

**What it is.** Every home-screen photo widget (Group Updates, Friend Updates, Your Memories) has a **Style** setting in
its configuration: **Photo** (free, the widget as it has always been), **Date** and **Frame** (premium — the
"Exclusive Widget Styles" perk the paywall sells, `paywall.perk.widgets.*`). Decision and evidence:
`widget.styles.layout.styles`.

- **Mechanics: Locket Gold** — "Widget frames — Personalize your widgets", a paid decoration around the widget photo
  (https://mobbin.com/explore/flows/775b5243-e2f1-42fa-a2af-cbee353c1dcd, `references/auto/locket/mobbin/locket-mobbin-gold-flow-2.png`).
- **Visual reference: Retro** — its premium recap styles ("Premium recap styles", `recap_select_style_title` "Select
  Style") are frames and headers around one photo: the instant print of the recap preview (ST-04, PLAY-04) and the
  Rewind header (RWA, ST-05). Each premium style is one of them drawn at the widget's size. Retro's white recap card is
  not offered: scaled from its 306-pt card to the 87-pt card a small widget holds, its name line would be 4 pt.
- **Directive Part 6:** "Premium: extra widget styles". The free widget never stops working: a premium style chosen
  without premium draws **Photo**.

## References

| id | image / source | what it verifies |
|---|---|---|
| MB-2 | `references/auto/locket/mobbin/locket-mobbin-gold-flow-2.png` | Locket Gold sells widget frames (premium widget decoration) |
| ST-04 | `references/auto/retro/store/retro-store-04.png` (1284 × 2778) | print x275–1009 y1122–1990, window x324–962 y1194–1833, page x171–1110; backdrop (C-34) |
| PLAY-04 | `references/auto/retro/play/retro-play-04.png` (1563 × 2778) | second capture of the same print: x402–1159 y1144–2035, window x454–1110 y1217–1873, page x298–1264 |
| RWA | `references/auto/retro/press/tc-2025-12-rewind-device-a.png` | Rewind's serif date at the margin over the full-bleed photo, no top scrim |
| ST-05 | `references/auto/retro/store/retro-store-05.png` | the date title 'July 5, 2021' |
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `recap_select_style_title`, `retro_membership_paywall_benefit_title_recap_styles`, `app_widget_config_media_type_*` (option title + subtitle rows) |

## Structure

### Photo (free)

Exactly `widget.home.small` (photo, `layout.global.photoScrim`, the name stack) at every size.

### Date (premium) — `widget.styles.layout.date`

1. Photo and scrim as Photo.
2. **Date title** top-leading: the item's date in `layout.onthisday.dateFormat` ("Jul 22, 2022"), `font.global.display`,
   text role `displaySmall` (25.8, Dynamic Type title2), `color.global.textOnMedia`, one line, tail truncation; leading
   inset `size.global.screenMargin`, cap top `size.global.screenMargin` below the top edge.
3. The name stack (`widget.home.small.layout.overlay`) bottom-trailing, unchanged.

### Frame (premium) — `widget.styles.layout.frame`

1. **Backdrop** (C-34): the same photo aspect-filling the widget, Gaussian σ `size.global.backdropBlur`, under
   `color.global.backdropDim`.
2. **Print**, centred: width ÷ height = 1 ÷ `aspect` (1.18); the largest that fits inside `fit` (0.784) × the widget's
   width by `fit` × its height. Fill `widget.styles.color.frame` (#D5D6CD), square corners.
3. **Window**: square, `sideBorder` (0.066 of the print width) from the left and right edges, `topBorder` (0.097) from
   the top; `bottomBorder` (0.214) of paper below it. The photo aspect-fills the window.
4. No text (Retro's print carries none; the widget's accessibility label says who and where).

Sizes: small 158 × 158 → print 105 × 124 pt; medium 338 × 158 → 105 × 124; large 338 × 354 → 235 × 278 (393 × 852).

### Locked (premium style, no premium)

The widget draws **Photo**. Its tap opens the paywall at the widgets perk, at most once per session (`SessionPromptGate`,
`paywall.layout.promptRule`: the tap on a locked feature); any later tap that session does what the widget's tap always
does (`camera.fromwidget`, the collage, or the memory). The configuration marks each premium style with
`paywall.locked.badge` while the person has no premium.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| style parameter | `widget.styles.layout.styles` | `widget.styles.configuration.style`; names `widget.styles.name.{photo,date,frame}` | iOS: a parameter of each widget's AppIntentConfiguration (an AppEntity: the premium marker `paywall.locked.badge` as the subtitle while not premium); default Photo |
| Android style step | C-29 header (`sheetTitle`), C-16 rows (text roles `listTitle` / `listSubtitle`), C-25 premium pill, C-32 hairlines | title `widget.styles.configuration.title` ("Select Style"); rows name + `widget.styles.description.*`; pill `paywall.locked.badge` | the configure activity's last step (Retro asks one thing per page); a tap binds the widget and finishes; a premium style without premium also opens the paywall (once per session) |
| date title | `widget.styles.layout.date`, `font.global.display`, `fontSize.global.displaySmall` | data (the date) | — |
| print | `widget.styles.layout.frame`, `widget.styles.color.frame`, `size.global.backdropBlur`, `color.global.backdropDim` | — | — |

## States

Loading, empty, not set up, signed out: as the widget kind (`widget.home.small`, `widget.friend`, `widget.memories`) in
every style — the styles dress a photo only. Error / offline: the last photo stays (HIG). Permission-denied: n/a.

## Motion

None (`widget.arrival.duration.transition` 0 — the new image replaces the old).

## Haptics

None on the widget; Android style rows `haptic.global.tap`.

## Accessibility

The widget's one label is the kind's (`widget.home.small.a11y.*`, `widget.memories.a11y.photo`) — the style adds no
element. Dynamic Type: the date scales with title2 and truncates. Contrast: the date (white) over a photo with no top
scrim is photo-dependent like the name stack (reported in `widget.home.small`, not adjusted: Rewind draws it so); the
print paper is non-text.

## Data & actions

- Premium state: the iOS app writes it to the App Group widget store (`premium.json`) whenever it learns it (launch,
  foreground, purchase, restore); Android reads the entitlement through the data layer when the widget renders.
- Locked tap: `app://premium?perk=widgets` with the widget's own link (`then=`), opened by the app.

## Platform notes

- iOS: SwiftUI `.blur(radius: σ)` for the backdrop (as `BlurredBackdrop`); the date's font is bundled in DesignSystem.
- Android (Glance has no blur or custom fonts): the backdrop, print and photo are drawn into one bitmap (Gaussian
  σ × density); the date title is drawn into a bitmap with the bundled display face, as the name stack is.
- Lock Screen kinds and Next Plan have no style (vibrant rendering / its own layout).

## Do-not-copy

Locket's frame art (gold, hearts, streak frames); Retro's paper texture, stickers, tape and its recap card's
'retro.app' line.

## Gaps

| item | status | capture |
|---|---|---|
| Retro's styles applied to a widget | Retro sells no widget styles; its recap styles are drawn at widget size (ratios of the print) | — |
| the print's shadow | not measurable on ST-04 / PLAY-04 (dark backdrop) — none drawn | a light-backdrop capture of the instant-print recap |
