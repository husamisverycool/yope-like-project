# Retro + Timehop — reference research

Research pass: 2026-10-15. Surfaces: `week.history` (Retro), `onthisday` (Timehop). Also covered: Retro's weekly
recap timing (for `week.recap` / `notifications.push`) and Retro's display serif.

Sources were App Store listings (Retro v124.0, Timehop v5.0.4, plus version history), Google Play listings, retro.app and
its CSS, the Timehop help center (help.timehop.com, 56 articles via sitemap), press (TechCrunch 2023-07, 2023-12,
2024-04, 2025-12; Engadget 2026-08-16), and one user blog post (notes.jeddacp.com, 2024-05-07). Every file cited
here is listed with its URL in `references/auto/retro/INDEX.md` or `references/auto/timehop/INDEX.md`.

Not usable in this pass: TikTok. Its discover, tag and user pages render client-side here, and yt-dlp could not list
`@retrodotapp` because of a JSON parse error, so I found no video URL. Firecrawl returned 402 (out of credits).
Mobbin and Screenlane have no public pages for either app (404 and 403). YouTube was not tried, because the brief says
it is bot-blocked. As a result, **no motion was measured**.

Paths below are relative to `references/auto/`. Two abbreviations are used: **R** = `retro/` and **T** = `timehop/`.

---

## Scale conventions used

| image | screen px width | assumed pt width | px/pt | why |
|---|---|---|---|---|
| R `store/retro-store-01..05.png` (1284×2778 marketing panel) | 939 (x 171–1109, white screen span at y=700/1250) | 393 | 2.389 | The home indicator measures 320 px (y=2587, x 477–796). 320/134 pt = 2.388 px/pt, which matches 939/393 = 2.389. A 430-pt device would give 2.18. |
| R `play/retro-play-02.png` (1563×2778, Android) | 966 (x 297–1262) | unknown dp | — | Only ratios to screen width are used. |
| R `press/tc-2023-07-retro-2b.jpg` (3510×2160, three phones) | 866 (phone 1: x 152–1017 at y=760) | 393 | 2.204 | Tiles measure the same ratio as the 2026 store image, so the scale is consistent. Ratios only for insets, because the frame overlaps the screen edge. |
| R `press/jeddacp-2024-05-home-profile-journals.png` (1350×852) | 364 per phone | unknown | — | Ratios only, because the image is low resolution. |
| R `press/tc-2025-12-rewind-device-a.png` (1320×2868) | raw @3x | 440 | 3 | Raw device screenshot. |
| R `press/tc-2025-12-rewind-device-b.jpg` (1260×2736) | raw @3x | 420 | 3 | Raw device screenshot. |
| T `store/timehop-store-0N.png` (1242×2688 marketing) | 930 (x 156–1085) | 393 (brief default) | 2.366 | The mockup is a stylised notched iPhone, so the device class is unknown. Precision is ±5 %. |
| T `help/th-help-2025-06-share-full-43-years-ago.png` (1170×2532) | raw @3x | 390 | 3 | Raw device screenshot (iPhone 12–14 size). |

Colour sampling method, unless a row says otherwise: the median of a 7×7 box placed away from anti-aliased edges. For text,
the median of the darkest (or brightest) 10–30 % of glyph pixels in the text's bounding box.

---

## Surface `week.history` (Retro) — scroll back week by week

### Reference images (≥ 2 independent)
1. R `store/retro-store-02.png`: iOS App Store, profile with week sections. Listing v124.0, Oct 2026. **Primary measurement image.**
2. R `play/retro-play-02.png`: the same screen rendered on Android (Play listing, Oct 2026). Independent render used for the ratio cross-check.
3. R `press/jeddacp-2024-05-home-profile-journals.png`: **a user's real screenshots**, May 2024. Shows "Week 19" with empty-day tiles, real date-range format, and the "Last Week" pill.
4. R `press/engadget-2026-08-profile.jpg` and `press/engadget-2026-08-home-dark.jpg`: **photos of the live app**, Aug 2026, en-AU locale. Show "Week 33  10–16 Aug", empty placeholders, and dark mode.
5. R `press/tc-2023-07-retro-2b.jpg` and `press/tc-2023-07-retro-1b.webp`: press kit, Jul 2023. Show the empty-day tiles "Jul 10 Mon", the "Key holders only" history gate, and the older labels "Tues"/"Thurs".
6. R `store/retro-store-01.png`, `press/tc-2024-04-journals-1.webp`: home title "Week 27" / "Week 3" (serif display).
7. "On this week" / Rewind entry: R `store/retro-store-05.png`, `press/tc-2025-12-rewind-panels.png`, and the raw device screenshots `press/tc-2025-12-rewind-device-a.png` / `-b.jpg`.

Owner images `references/owner/retro-01..05.webp` (CAPTURED) are the same five App Store panels at 460 px. The 1284-px
store PNGs were used for measuring, and the owner set confirms these are the panels the owner meant.

### Layout (profile = the week-by-week history)
- The screen is a vertical list with the **newest week at the top**. Visible in order: Week 27, 26, 25 (store), and
  Week 19, 18, 17 (jedda 2024). Owner-facing order is reverse-chronological.
- Each **week section** has two parts:
  - **Header row.**
    - **Left:** "Week N" in a semibold sans, black. After it, separated by about one space, the date range in
      regular weight, gray `#999999`. Both share one baseline.
    - **Right:** a "•••" more button, vertically centred on the header text.
  - **Day strip.** A horizontal strip of photo tiles, one tile per posted photo, in chronological order left to right
    (Mon → Sun).
    - **Labels.** Each tile is labelled with the 3-letter weekday it was taken: "Mon", "Tue", "Wed", "Thu". The
      label is white semibold, bottom-centred. Two photos from the same day get two tiles with the same label, for
      example "Mon","Mon" (Engadget 2026) and "Tue","Tue" (Engadget home; 2023 press "Tues","Tues").
    - **Corners.** Only the strip's **outer** corners are rounded. The tiles between them are square-cornered and
      separated by a ~2 pt white gap. TechCrunch 2024-07-11 describes it as a "horizontal 'filmstrip'-style format, with
      rounded corners on the outside", which matches what was measured.
    - **Scrolling.** The strip scrolls horizontally when there are more tiles than fit: a 5th tile is clipped at the right
      screen edge, with no trailing inset (Week 26 and Week 25).
- **Current week.**
  - The strip ends with a light-gray **add tile** "+", square-cornered on its left and rounded on its outer right
    corners. In 2026 it comes after the photos; in Jul 2023 (press) it came first, before the empty days.
  - **Empty days** are shown as light-gray placeholder tiles that continue the strip. Each placeholder has three
    centred lines in very light gray: month ("May"/"Jul"), large bold day number ("6"/"10"), and weekday
    ("Mon"/"Tue"). Sources: jedda 2024, press 2023, and Engadget 2026, where the placeholders are blank at that
    resolution.
  - A current week with no photos shows **only "Week 19", with no date range** (jedda 2024). The tiles carry the dates
    instead.
- **Date range format, verbatim:**

  | source | examples | dash |
  |---|---|---|
  | Real app, en-US, 2024 | "Apr 29 – May 5", "Apr 22 – 28" | en dash, spaced |
  | Real app, en-AU, 2026 | "10–16 Aug", "3–9 Aug" | en dash, tight |
  | Store mockups | "Jul 3 - 9", "Jun 26 - Jul 2", "Jun 19 - 25" | spaced hyphen |

  Within a month the range shows the month once; across months it shows both. The real-app outputs match the
  locale's date-interval format. (Inference: this is consistent with iOS `DateIntervalFormatter`. Not confirmed by
  Retro.)
- **Week numbering = ISO-8601 week numbers, with Monday-start weeks.**

  | label | dates | year | source |
  |---|---|---|---|
  | Week 27 | Jul 3–9 (Mon Jul 3) | 2023 | store |
  | Week 24 | Jun 12–18 | 2023 | press |
  | Week 18 | Apr 29 – May 5 | 2024 | jedda |
  | Week 33 | 10–16 Aug | 2026 | Engadget |

  All of these were checked against `date.isocalendar()`. One store panel shows "Jun 18 - 25", which is an 8-day
  mock-up typo. The Android panel and the 2023 press image show "Jun 19 - 25".
- **How far back.**
  - Your own profile scrolls back indefinitely. For example, "Weeks Posted: 32", and the store copy says "backfill the
    weeks on your profile".
  - Friends see **4 weeks** unless they hold a key. Below that point the profile shows a gate (press 2023):
    "Key holders only" / "Only friends you've given a key to can see back more than 4 weeks." / "Manage Key Holders".
  - Engadget 2026 says friends "can head to your profile and view photos you've uploaded in the past four weeks". The
    premium perk is "unlimited profile history" (Threads, per dossier 12).
- **Home title.**
  - The home screen's page title is the current week, "Week 27", in a **heavy condensed display serif**. It sits at the
    left, with the journal and chat glyphs at the right.
  - On the Mondays/Tuesdays after a week ends, the home shows the **previous** week's title with a gray capsule
    **"Last Week"** next to it. Seen twice: "Week 18" + "Last Week" while the profile already showed Week 19 (jedda,
    May 2024), and "Week 32" + "Last Week" while the profile showed Week 33 (Engadget, Aug 2026).
  - Inference, not confirmed: the home keeps last week visible early in the new week.
- **"On this week" entry (Rewind tab, middle of the 5-glyph tab bar).**
  - The screen is a full-bleed photo. At top-left is a large white serif date, in one of two forms:
    - "July 5, 2021" with a small "On this week" under it (store / press kit 2025-12);
    - "May 1, 2019 ⌄" or "Jul 22, 2022" on the real devices, Dec 2025, with no subtitle visible.
  - Top-right is a "•••" button in a translucent circle. Its menu has "Share to my week" / "Add to Album" /
    "Hide photo" / "Delete from Photos" (the last in red).
  - Bottom-centre is a dial ring of radial ticks with a play/pause glyph in the centre. It is flanked by two 64-pt
    translucent circles: share at the left and a dice ("random") at the right.
  - TechCrunch 2025-12-12 lists an extra entry point: "the end of the row of shared photos, just past the 'this week in'
    card".

### Measured values — `week.history`

All pt values use the 2.389 px/pt scale of R `store/retro-store-02.png` unless noted.

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| #FFFFFF | screen background | R store/retro-store-02.png | (600–606, 1700–1706) | 7×7 median | ±1/255 | SOURCED |
| #000000 | "Week 27" header text | R store/retro-store-02.png | bbox x221–349, y1289–1313 | darkest 30 % of L<100 glyph px, median | ±3/255 | SOURCED |
| #999999 | date range "Jul 3 - 9" text | R store/retro-store-02.png | bbox x367–490, y1288–1314 | darkest 30 % of L<215 glyph px, median | ±4/255 (anti-aliased text) | SOURCED |
| #F1F1F1 | add tile fill | R store/retro-store-02.png | (860–866,1360–1366); (1000–1006,1580–1586) | 7×7 median ×2 | ±1/255 | SOURCED |
| #000000 | "+" glyph | R store/retro-store-02.png | bbox x912–959, y1452–1499 | median of L<60 px | ±3/255 | SOURCED |
| #000000 | "•••" more glyph | R store/retro-store-02.png | bbox x1012–1056, y1298–1306 | median of L<60 px | ±3/255 | SOURCED |
| #FFFFFF | weekday label on tile | R store/retro-store-02.png | "Tue" bbox x499–550, y1555–1576 | glyph core >235 | ±2/255 | SOURCED |
| #F1F1F1 | empty-day tile fill | R press/tc-2023-07-retro-2b.jpg | (390,420), (540,620), (600,420) | 7×7 median ×3 (JPEG) | ±3/255 | SOURCED (2023). The 2024 user screenshot gives #EDEDED (jedda (520,425)), probably from recompression. |
| ≈#D9D9D9 | empty-day tile text ("Jul"/"10"/"Mon") | R press/tc-2023-07-retro-2b.jpg | tile x378–564, y402–650 | median of darkest 10 % glyph px: 221/216/218 | ±6/255 (light anti-aliased text on JPEG) | SOURCED. jedda 2024 gives 215–218. |
| 84.5 pt | tile width | R store/retro-store-02.png | y=1475 runs: x218–419, 424–625, 630–831 (202 px each) | px/2.389 | ±0.5 pt | SOURCED |
| 112 pt | tile height | R store/retro-store-02.png | x=524: y1341–1608 (268 px) | px/2.389 | ±0.5 pt | SOURCED |
| 3:4 (w:h), 1.32–1.335 | tile aspect | store-02 268/202 = 1.327; play-02 279/209 = 1.335; tc-2023-07-retro-2b 249/187.5 = 1.328; jedda 105.5/80 = 1.32 | as listed | height/width in 4 independent images | ±0.01 | SOURCED |
| 21.5 % of screen width | tile width ratio | store-02 202/939; play-02 209/966 = 21.6 %; 2023 press 187.5/866 = 21.7 % | — | ratio | ±0.3 % | SOURCED |
| 2 pt | gap between tiles | R store/retro-store-02.png | x420–423 white + partial px 419/424 (~50 %) → ≈5 px | px/2.389 | ±0.5 pt | SOURCED |
| 0 pt | inner tile corners | R store/retro-store-02.png | (419–424, 1341–1343) | pixels are full colour at the corner row | — | SOURCED |
| 14 pt | strip outer corner radius | R store/retro-store-02.png | TL (218,1341), BL (218,1608), TR (1036,1341) | least-squares circle fit of per-row edge inset: 34.4 / 34.6 / 35.0 px | ±1 pt. Circular vs continuous corner not distinguishable. | SOURCED. play-02: 34.9 px of 966 = same ratio. |
| 20 pt | leading inset of strip and header | R store/retro-store-02.png | strip x=218, header ink x=221, screen x=171 | (218−171)/2.389 = 19.7; (221−171)/2.389 = 20.9 | ±1 pt | SOURCED. play-02: 49/966 = 5.07 % vs 5.0 %. |
| 15 pt | "Week N" header font size | R store/retro-store-02.png | "W" cap y1289/1290–1313 (24–25 px); x-height ≈18 px | cap 10.2 pt / SF cap ratio 0.705 = 14.5; x-height 7.5 / 0.517 = 14.6 | ±1 pt | SOURCED |
| semibold | "Week N" weight | same | — | visual comparison with the regular-weight range | ±1 weight step | SOURCED (visual) |
| 15 pt regular | date range text | R store/retro-store-02.png | "J" top 1288, baseline 1314 | same cap height as header | ±1 pt | SOURCED |
| 7.5 pt | ink gap "Week 27" → "Jul" | R store/retro-store-02.png | x349 → x367 | 18 px/2.389 | ±0.5 pt | SOURCED |
| 11.7 pt | header baseline → strip top | R store/retro-store-02.png | baseline y1313 → strip y1341 (also 1719→1747, 2126→2154) | 28 px/2.389 | ±0.5 pt | SOURCED |
| 36.4 pt | strip bottom → next header cap top | R store/retro-store-02.png | y1608 → 1695 | 87 px/2.389 | ±0.5 pt | SOURCED. Android is tighter: strip-to-strip 119 px/966 vs iOS 139 px/939. |
| 170 pt | section pitch (strip top → next strip top) | R store/retro-store-02.png | 1341 → 1747 → 2154 | 406.5 px/2.389 | ±0.5 pt | SOURCED |
| 13 pt semibold | weekday label size | R store/retro-store-02.png | "Tue" cap 1555–1576 (22 px); "Wed" 1554–1576 (23 px) | cap 9.2–9.6 pt / 0.705 | ±1 pt | SOURCED |
| 13.4 pt | weekday baseline → tile bottom | R store/retro-store-02.png | baseline 1576 → 1608 | 32 px/2.389 | ±0.5 pt | SOURCED |
| centred | weekday label horizontal | R store/retro-store-02.png | "Tue" centre x524.5 = tile centre x524.5 | — | ±0.5 px | SOURCED |
| 20 pt / 2.9 pt | "+" glyph size / stroke | R store/retro-store-02.png | bbox 48×48 px, centred at (935.5,1475.5) in tile (936,1474.5); bar 7 px | px/2.389 | ±0.5 pt | SOURCED |
| 4.2 pt / 7.1 pt | "•••" dot diameter / centre pitch | R store/retro-store-02.png | dots x1012–1021, 1029–1038, 1047–1056 | px/2.389 | ±0.5 pt | SOURCED |
| 22 pt | "•••" right ink edge → screen edge | R store/retro-store-02.png | x1056 → 1109 | 53 px/2.389 | ±1 pt | SOURCED |
| 30 pt cap height | home title "Week 27" (display serif) | R store/retro-store-01.png | W cap y753–825 (72 px); x-height "e" 774–825 (52 px) | px/2.389 = 30.1 / 21.8 | ±0.5 pt | SOURCED |
| 30.3 pt cap height | Rewind date title | R press/tc-2025-12-rewind-device-a.png "1" y286–376; -b.jpg "2" y304–394 | digits 91 px /3 | raw @3x | ±0.3 pt | SOURCED (raw device) |
| 15–16 pt | serif title left ink inset | store-01 x207 (15.1 pt); device-a x49/3 = 16.3; device-b x47/3 = 15.7 | — | — | ±1 pt | SOURCED |
| 17.6 pt | home title baseline → strip top | R store/retro-store-01.png | 825 → 867 | 42 px/2.389 | ±0.5 pt | SOURCED |
| ≈17 pt regular | "On this week" subtitle | R store/retro-store-05.png | "O" y858–886 (29 px) | cap 12.1 pt / 0.705 | ±1 pt | SOURCED. Colour: white at reduced opacity over the photo (core 219,206,199 is photo-tinted, so opacity is not measurable). |
| 150 pt | Rewind dial outer diameter | R press/tc-2025-12-rewind-device-b.jpg | centre (630,2217.5); tick outer radius p50 = 225 px | radial profile over 720 angles /3 | ±2 pt | SOURCED (raw). Store-05 gives about 133 pt on a 393-pt mockup. |
| ≈45 | dial tick count | same | ring r = 200–210 px | count of bright crossings around the circle (44/45) | ±2 | SOURCED |
| 18 pt / 11 pt | long / short tick length | same | inner radius p50 = 171 px (long), p90 = 193 px (short); outer 225 | (225−171)/3; (225−193)/3 | ±1 pt | SOURCED |
| 64 pt | Rewind share / random circle buttons | R press/tc-2025-12-rewind-device-b.jpg | share x108–300, dice x960–1152 at y≈2217 | 192 px /3 | ±1 pt | SOURCED |

**Dark mode.** Engadget 2026 (`press/engadget-2026-08-home-dark.jpg`) shows a black home background, dark-gray empty
tiles and a white serif title. It is a low-resolution photo of a phone, so no colour was sampled. See Not found.

### Typeface (Retro)
- **Display serif = "Roslindale Retro".** Source: Retro's own site CSS,
  `https://retro.app/_next/static/css/c857ab11667cdfc8.css` (saved as R `web/retro.app-c857ab11667cdfc8.css`), which
  declares `@font-face{font-family:Roslindale Retro Web;src:url(/RoslindaleRetrov0.2-Regular.woff2)…}`.
  - `048ddcd8a10813ca.css` applies it to `.page_heroTitle` ("Your friends, week to week") and
    `.page_largeRetroWordmark`. The same CSS also loads `Roslindale-DisplayNarrowRegular.ttf`.
  - Roslindale is a commercial typeface by David Jonathan Ross (DJR; https://djr.com/roslindale, private licensing).
    "Roslindale Retro v0.2" looks like a custom cut. The in-app "Week 27" / "isareyes" / "July 5, 2021" glyphs are
    visually consistent with Roslindale's condensed display styles: high x-height (x/cap 0.72), sharp serifs, round
    bowls. The app binary was not inspected.
  - **Proprietary or licensed, so the build uses the PLATFORM font.** No font file was saved.
- **UI sans:** the site CSS lists `SF Pro Display,-apple-system,…` for UI text, and in-app text renders as SF. → PLATFORM.

### Copy — `week.history` (verbatim, with sources)
| string | where | source |
|---|---|---|
| "Week 27", "Week 26", "Week 3", "Week 18", "Week 19", "Week 33" | week header / home title | store-01/02; tc-2024-04-journals-1; jedda 2024; Engadget 2026 |
| "Jul 3 - 9", "Jun 26 - Jul 2" | range (store mockup) | R store/retro-store-02.png |
| "Apr 29 – May 5", "Apr 22 – 28" | range (real app, en-US) | R press/jeddacp-2024-05-…png |
| "10–16 Aug", "3–9 Aug" | range (real app, en-AU) | R press/engadget-2026-08-profile.jpg |
| "Mon", "Tue", "Wed", "Thu" | tile weekday (2024–2026) | store-02, jedda, Engadget |
| "Tues", "Thurs", "Fri" | tile weekday (2023, superseded) | R press/tc-2023-07-retro-1b.webp / -2b.jpg |
| "May" / "6" / "Mon" | empty-day tile (month / day / weekday) | jedda 2024; "Jul / 10 / Mon" in press 2023 |
| "Last Week" | capsule next to the home title after rollover | jedda 2024; Engadget 2026 |
| "On this week" | Rewind subtitle | store-05; tc-2025-12-rewind-panels |
| "July 5, 2021" / "May 1, 2019" / "Jul 22, 2022" | Rewind date title | store-05 / device-a / device-b |
| "Share to my week", "Add to Album", "Hide photo", "Delete from Photos" | Rewind "•••" menu | R press/tc-2025-12-rewind-panels.png |
| "Tuesday, December 2" / "Memory" | Rewind share-sheet header | same |
| "Key holders only" / "Only friends you've given a key to can see back more than 4 weeks." / "Manage Key Holders" | history gate below 4 weeks | R press/tc-2023-07-retro-2b.jpg |
| "Getting Started:" / "Retro is a weekly photo album. Try adding photos to 3 different weeks below." | profile onboarding card | R press/engadget-2026-08-profile.jpg |
| "Weeks Posted: 32" / "Weeks posted: 2" | profile stat (see do-not-copy) | store-02; Engadget 2026 |
| "tim" / "Week 28" / "3 of 4"; "nathan" / "Week 49" / "2 of 9" | story viewer header | press 2023-07, 2023-12 |
| "Your friends, week to week" | website hero | https://retro.app |
| "Retro is a weekly photo journal that (1) brings you closer…" | store description | App Store listing v124.0 |

**Voice pattern (Retro):**
1. Title Case for navigation, buttons and capsules: "Share Profile", "Manage Key Holders", "Create Recap", "Add to
   Album", "Last Week", "Send Postcard".
2. Sentence case for short contextual labels and menu verbs: "On this week", "Hide photo", "Share to my week", "Delete
   from Photos".
3. Sentence case with a final period for one-line explanations: "Only friends you've given a key to can see back more
   than 4 weeks."
4. Numbers as digits ("4 weeks", "3 different weeks"). Terse labels ("Week 27"). First-person possessive in actions
   ("my week"). **No emoji, no exclamation marks** in UI strings.

### Motion — `week.history`
Not measured, because no video source was obtainable (see the top of this file). Fast Company's description of the
Rewind dial ("clicks", "subtle vibration as each new memory loads", photos "flip by", dossier 02) is text only. No
duration or curve can be derived from it, and haptics are PLATFORM per the brief.

### Do-not-copy — `week.history`
- **"Post to see" lock** on friends' weeks (press 2023-07, Retro-2b). It obliges you to post before you can see, which
  breaks tenet 5 (invitations, never obligations).
- **"Weeks Posted: N"** profile stat. It is a streak-like count of the user's own posting.
- **"N new" red count pill / "Seen" pill** on friend cards (home). It is a count and read-state pressure. It is outside
  this surface anyway.
- **"Getting Started … 3 different weeks" progress ring "2"**. It is a gamified progress count. The sentence can be
  adapted without the ring.
- **"Key holders only" gate.** In our product every group member sees the group's full history (tenet: nothing gets
  lost). Record the 4-week gate as Retro behaviour only.
- Retro wordmark, app icon, Roslindale font: legal. Not saved, not proposed.

### Not found — `week.history`
- **Dark-mode colours.** The only dark-mode image is a low-res Engadget photo. Tried: App Store and Play (both
  light-only), press kits.
- **Scroll / paging motion** of the week list and the strip, and the transition into a week. No video: TikTok
  unreachable, YouTube blocked.
- **Contents of the per-week "•••" menu.** Not shown in any image.
- **Exact text sizes of empty-day tiles at raw resolution.** Only ratios are available: the day number cap ≈ 24 % of
  tile width (2023 press 45/187 px; jedda 19/80 px), and month/weekday caps ≈ 12.5 % of tile width. That gives about
  20 pt cap (≈29 pt SF) for the number and about 10.6 pt cap (≈15 pt SF) for the labels, but both images are
  re-encoded and stylised.
- **Whether a tile shows a scrim/gradient behind the weekday label.** Not measurable on photo content.
- **How the strip handles more than about 4 photos per day.** Not shown.

---

## Retro weekly recap: when the week closes and when recaps arrive

- **Week boundaries: SOURCED.** Retro weeks are ISO weeks running **Monday → Sunday**. Evidence is the week numbers and
  ranges in four images from 2023, 2024 and 2026 (see Layout). So a week closes at the end of Sunday, in local time
  (inference).
- **Rollover behaviour: SOURCED observation, interpretation not confirmed.** Early in a new week, the home still shows
  the previous week with a **"Last Week"** capsule. Seen in jedda 2024 (profile already on Week 19) and Engadget
  2026-08 (profile already on Week 33).
- **Weekly recaps exist.** Sources:
  - App Store listing, v124.0, "MONTHLY RECAPS": "Create a beautiful photo collage or video slideshow from the photos
    you've shared from the week, month, or year".
  - Recap creator segments "Yearly / Monthly / Weekly / All Posts" (press 2023-12).
  - User review (App Store, 08/08/2024, "fotomojodojo"): "The recaps at the end of each week and month are soooo
    gorgeous". This is user wording, so it is weak evidence.
- **Day and time a weekly recap is delivered or announced: NOT FOUND.** Searches tried:
  - retro.app: home, /ethos and /terms; /faq and help.retro.app do not exist.
  - App Store v124.0 description, full version history 100.0–124.0 (all boilerplate), and Editors' Choice text.
  - Apple editorial stories id1840659619 (AU) and id1858405528 (404).
  - mwm.ai reviews; Engadget 2026, TechCrunch ×5, Apptisan #013, and the jedda blog.
  - Web searches for "Sunday"/"Monday"/"weekly recap ready"/"new week"/"notification".
- No public source states a recap push or its time. Retro does not appear to publish a help center.

---

## Surface `onthisday` (Timehop) — photos from this date in past years

### Reference images (≥ 2 independent)
1. T `store/timehop-store-01.png` "3 YEARS AGO", `-02` "8 YEARS AGO", `-03` "8 YEARS AGO | AND NOW", `-04` share into
   chat, `-05` "2 YEARS AGO" grid. iOS listing v5.0.4, Oct 2026, marketing renders.
2. T `play/timehop-play-01..05.png`: the same set on Android (Play listing updated Jun 15, 2026).
3. T `help/th-help-2025-06-share-full-43-years-ago.png`: **raw device screenshot**, Jun 2025, share screen.
4. T `help/th-help-2023-04-memory-view-hide.png`: in-app memory view (2023). Shows the progress bar, the banner with
   gear, the meta row, and the hide/open actions.
5. T `help/th-help-2024-03-intro-day-in-history.jpg`: the day's intro card.
6. T `help/th-help-2025-06-timeskip-header.png`: day navigation (Timeskip) header.
7. Older UI for comparison: T `help/th-help-2024-02-panel-*.png`. Header "SATURDAY  3 YEARS AGO  MAY 30" and share
   tabs "SQUARE / FULL / THEN & NOW".

### Layout
- **Day structure** (help 754, "How to Move Through Your Timehop Day"):
  - The day is a sequence of memory screens ordered "from most recent to oldest": 1 year ago first, then 2, 3, … years.
  - "tap or swipe the right side of your screen to move towards older memories", and "tap or swipe the left side" to go
    back. This is a stories-style tap-through.
  - In the 2016–2023 images a thin **segmented progress bar** runs along the very top: yellow progress over a darker
    track.
- **Day opener:** an intro card on a solid yellow background. It shows a gear with "SETTINGS" at top-left, then, centred,
  the wordmark, "VERONICA'S DAY IN HISTORY" (small caps-style uppercase, darker yellow) and a large serif date "Sep 2" in
  white (help 2024-03). While loading, the app shows **"Collecting Memories"** (help 812, 774).
- **Each memory:**
  - **Banner.** A full-width **solid colour banner** at the top. It holds the centred, uppercase, bold sans label
    "N YEARS AGO" in white, with a gear at its left (2023). Banner colours vary between memories: orange-red, yellow,
    blue and pink were seen.
  - **Content.** The memory sits full-width below the banner. A single photo fills the width (store-01/02). Several
    photos from that date show as a **2-column masonry grid** on a warm off-white background (store-05).
  - **Meta row.** Overlaid at the top-left of the photo: the source icon, the weekday in caps, the time ("TUE 10:34 PM"),
    and a "•••" capsule. Tapping it shows two full-width capsules, "OPEN IN INSTAGRAM" and "HIDE FROM TIMEHOP" (2023).
  - **Older UI (≤2018).** The header showed weekday · years ago · date: "SATURDAY  3 YEARS AGO  MAY 30".
- **Then & Now** (help 752, store-03): the screen splits into two equal halves. The left is the old photo with the
  banner "8 YEARS AGO" (orange). The right is a new photo, from the live camera or the camera roll, with "AND NOW"
  (blue). They are separated by a 1-px seam.
- **Share** (help 746, 1086, raw 2025):
  - Tabs "SQUARE" | "FULL" at the top, with a white underline under the selected tab. The 2018 UI also had a third tab,
    "THEN & NOW".
  - Preview card: the banner ("43 YEARS AGO") on top of the memory, with a "timehop" watermark at the bottom.
  - A row of round share targets: Save, SMS, Facebook, Instagram, Instagram Stories, Snapchat, and ⋯ for more.
  - Timehop+ adds "Change Color" (cycles the banner colour) and "Remove Watermark".
  - Store-04 shows the shared image arriving in a messaging thread ("Look how big!").
- **Moving between days:** with Timehop+ "Timeskip" (help 774), a calendar icon opens Yesterday / Refresh / Tomorrow. The
  year banner then reads "Yesterday" or "Tomorrow", and the loader reads "Collecting Yesterday's Memories".
- **Day boundary:** "Your Timehop Day spans 24 hours from 5 am to 5 am"; "Timehop updates occur promptly at 5 am each day"
  (help 775).

### Measured values — `onthisday`
| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| #FC5F33 | banner, orange-red | T store/timehop-store-01.png; also store-03 left half | (300–306, 680–686); (230–236, 635–641) | 7×7 median | ±2/255 | SOURCED |
| #FFC700 | banner, yellow | T store/timehop-store-02.png | (400–406, 995–1001) | 7×7 median | ±2/255 | SOURCED |
| #14B6EF | banner, blue (and "AND NOW" half) | T store/timehop-store-05.png; store-03 right half | (330–336, 657–663); (1000–1006, 635–641) | 7×7 median | ±2/255 | SOURCED |
| #DB6FA3 | banner, pink (share card) | T help/th-help-2025-06-share-full-43-years-ago.png | (200–206, 360–366) | 7×7 median | ±2/255 | SOURCED (raw device) |
| #FFFFFF | banner label | store-01/02/05; help raw | label bboxes below | glyph core >235 | ±2/255 | SOURCED |
| full width, label centred | banner geometry | store-01 banner x156–1085 = screen; label centre x620 = banner centre 620.5 | — | — | ±1 px | SOURCED |
| 18.2 pt cap height | "3 YEARS AGO" label (in-app marketing render) | T store/timehop-store-01.png / -02 / -05 | bbox y718–760, y978–1020, y640–682 (43 px) | px/2.366 | ±5 % (mockup scale) | SOURCED |
| 25.4 pt | label baseline → banner bottom | store-02: 1020 → 1080; store-05: 682 → 743 | — | 60–61 px/2.366 | ±5 % | SOURCED |
| 96.8 pt | banner height from the screen top (includes the status-bar area) | store-02 y852–1080 | — | 229 px/2.366 | ±5 % | SOURCED (mockup) |
| 40 pt / 10.7 pt cap | share-card banner height / label cap | T help/…43-years-ago.png | banner y330–449; label y372–403 | px/3 (raw) | ±0.3 pt | SOURCED |
| 282 pt | share preview card width (FULL) | same | x162–1007 | 846 px/3 | ±0.3 pt | SOURCED |
| 11.5 pt cap / 3 pt | share tab label cap / selected underline | same | "FULL" y213–246; underline y279–287 | px/3 | ±0.3 pt | SOURCED |
| #F5F0ED | multi-photo grid background | T store/timehop-store-05.png | (gap px x616–625, y1000) | exact run colour (245,240,237) | ±2/255 | SOURCED |
| 3.8 pt | grid outer margin | store-05 | x156–164 | 9 px/2.366 | ±0.5 pt (mockup) | SOURCED |
| 4.2 pt | grid gutter (column and row) | store-05 | x616–625; y1209–1218 | 10 px/2.366 | ±0.5 pt | SOURCED |
| 5.5 pt | gap banner → first photo | store-05 | y745–757 | 13 px/2.366 | ±0.5 pt | SOURCED |
| 2 columns, masonry | grid structure | store-05 | col 1 x165–615, col 2 x626–1076 | — | — | SOURCED |
| 50 / 50 split, 1 px seam | Then & Now | T store/timehop-store-03.png | left x121–620, right x622–1120 | — | ±1 px | SOURCED |

**Typeface (Timehop):** timehop.com's CSS uses `proxima-nova` (Adobe Fonts, 78 + 45 declarations), with
`adobe-garamond-pro` for some site text. The in-app uppercase labels are a geometric sans that looks consistent with
Proxima Nova, but the app binary was not checked. The font is commercial, so the build uses PLATFORM. The intro date
"Sep 2" is a slab-ish serif, identity unknown, so PLATFORM again.

### Copy — `onthisday` (verbatim)
| string | where | source |
|---|---|---|
| "3 YEARS AGO", "8 YEARS AGO", "2 YEARS AGO" | memory banner | T store/timehop-store-01/02/05 (v5.0.4 listing) and play-01/02/05 |
| "43 YEARS AGO", "7 YEARS AGO" | share banner | T help/…43-years-ago.png; help/…share-banner-colors.png |
| "1 YEAR AGO" | singular banner | T help/th-help-2024-02-panel-share-1-year-ago.png and panel-best-photos ("TUESDAY  1 YEAR AGO  AUG 30") |
| "1 Year Ago" | Title Case in prose | help 795 ("a picture labeled "1 Year Ago"") |
| "AND NOW" | Then & Now right banner | store-03, play-03 |
| "Then & Now" | feature name | listing; help 752 |
| "VERONICA'S DAY IN HISTORY" / "Sep 2" | intro card | T help/th-help-2024-03-intro-day-in-history.jpg |
| "[Your Name]'s Yesterday in History" / "[Your Name]'s Tomorrow in History" | intro card during Timeskip | help 774 |
| "Collecting Memories" / "Collecting Yesterday's Memories" / "Collecting Tomorrow's Memories" | loading | help 812, 774 |
| "Yesterday" / "Tomorrow" | year banner during Timeskip | help 774 |
| "TUE" "10:34 PM" | memory meta row | T help/th-help-2023-04-memory-view-hide.png |
| "OPEN IN INSTAGRAM" / "HIDE FROM TIMEHOP" | memory actions | same |
| "SQUARE" / "FULL" / ("THEN & NOW", older) | share tabs | raw 2025; older panel |
| "Save" "SMS" "Facebook" "Instagram" "Instagram Stories" "Snapchat" | share targets | raw 2025 |
| "Change Color" / "Remove Watermark" | Timehop+ share actions | raw 2025; help 1086 |
| "You posted 12:37 pm" | share card footer (older) | older share panel |
| "1 Hidden Memory Today" / "UNHIDE" / "Your private content remains private." | settings | T help/th-help-2024-02-settings-hidden-memory.jpg |
| "Daily Reminder" / "Email Notifications" | settings toggles | T help/th-help-2024-03-settings-daily-reminder.jpg |
| "Time Travel Failed" | error | help 767 (title "Time Travel Failed Error") |
| "Missing Memories? Fix It!" | reconnect alert | help 723 |
| "See this exact day in history, every time you open" / "Go back 1 year ago, to 20 years ago, and beyond!" / "Relive the Best, Hide the Rest!" | store description | App Store v5.0.4 |
| "Every morning you get a new day of Timehop memories, and it only lasts for 24 hours!" | store description | App Store (see do-not-copy) |

**Daily notification (verbatim wording NOT FOUND).** What the help center says (help 751, "How to Manage Timehop
Notifications"):
- The reminder: "If you opt into notifications, we'll send you a gentle reminder every morning at 8 am to check your
  Timehop and take a stroll down memory lane before your day kicks off."
- The time is fixed: "you can't customize the 8 am notification time".
- Two more pushes exist: "A friendly push if you haven't opened the app by the afternoon" and "A little nudge to finish
  your day if you didn't quite make it to the end (you're so close!)". Both are do-not-copy.
- The settings label for the toggle is "Daily Reminder".

**Empty state "no memories today" (wording NOT FOUND).** See the Not found list.

**Voice pattern (Timehop):**
1. Uppercase for short in-image labels and buttons: "3 YEARS AGO", "AND NOW", "OPEN IN INSTAGRAM", "HIDE FROM
   TIMEHOP", "SQUARE", "FULL".
2. Title Case for screen and feature names: "Collecting Memories", "Daily Reminder", "Time Travel Failed", "Then & Now",
   "Change Color".
3. Numbers as digits followed by a unit: "43 YEARS AGO".
4. Playful second person with exclamation marks in marketing and help: "Celebrate your best memories, every day!",
   "We got you.", "Good riddance.", "Happy Timehopping!".
5. No emoji in in-app labels.
6. Release notes are jokey non-information: "Kept you waiting, huh?" (5.0.4). Do not follow pattern 6 or the nag-style
   lines from pattern 4.

### Motion — `onthisday`
Not measured, because no video was obtainable. The navigation model is documented as tap or swipe, right = older and
left = back (help 754). Help 755 describes the hide animation: "You should now see that memory float away and fade to
black". It is text only, so no duration is given.

### Do-not-copy — `onthisday`
- **Streak.**
  - The end-of-day streak screen: mascots, the "2200" count badge, the "6 YEAR CLUB" ribbon
    (T help/th-help-2024-02-streak-screen.jpg).
  - The store panel "ONE YEAR DOWN 365" (store-06), "Your Timehop streak tracks how many days in a row…", and "Unlock
    badges and rewards the bigger your streak gets!".
  - Streak Pause (help 1080).
- **Mascot "Abe"** (dinosaur): the news cards, the sticker pack (store-07), the Timehop+ list art and the theme "Abe".
- **Habit and expiry framing:** "It's your new daily habit" (store-06), "it only lasts for 24 hours!", "Set alerts so you
  never miss a day". This breaks tenet 3, nothing gets lost: our memories never expire.
- **Nag pushes:** the afternoon push "if you haven't opened the app" and the "nudge to finish your day … (you're so
  close!)" (help 751). This breaks tenet 5.
- **Ads**, "Remove Ads" (help 739, 1082), and the watermark-removal upsell.
- The Timehop wordmark, the "timehop" watermark on shares, and the mascot sticker art. Legal.

### Not found — `onthisday`
- **Verbatim daily notification text.** Tried:
  - help center: all 56 articles via the sitemap;
  - App Store and Play descriptions, and version history 4.18.1–5.0.4;
  - App Store reviews and mwm.ai reviews;
  - web searches for "Your Timehop is ready" / "memories are ready" / "time travel" notification;
  - press 2012–2014, where one 2014 review quotes a past-day content line, "four years ago today, Queen Elizabeth II
    joined Facebook", which is a news item, not the reminder text.

  Only the 8 am timing and the "Daily Reminder" toggle label are sourced.
- **Empty-state wording when a day has no memories.** Tried: the help center (article 711 covers missing content but
  quotes no on-screen copy), web and Reddit searches for "no memories"/"nothing today"/"come back tomorrow"/"that's all
  for today", and App Store reviews. A user report mentions an "Oh Fiddlesticks" error after "collecting memories"
  (issitedownrightnow.com, page not opened). It is not an empty state and is unverified.
- **Raw in-app memory-view geometry in v5.x.** Store and Play images are marketing renders in a stylised notched-phone
  frame. The banner height *excluding* the status bar cannot be separated reliably. The 2023 help image is a composite.
- **Motion** for tap-through, banner and progress-bar changes, and the hide animation.
- **Whether v5.0 (Jul 1, 2026) changed the memory layout.** Its release notes are jokes ("Pay no attention to that new
  feature behind the curtain!"), and the help center has no post-July-2026 screenshots.

---

## Smallest owner captures that would close the gaps
1. **Retro, `week.history` scroll and dark mode.** One 20–30 s screen recording on the current Retro iOS, in light mode
   and then dark mode.
   - It should start at the profile, scroll from the current week (with at least one empty day) back about 6 weeks,
     and open one week's "•••" menu.
   - This settles: dark colours, the menu contents, raw empty-tile text sizes, and the scroll/strip motion.
2. **Retro recap timing.** One screenshot of Retro's Notifications (bell) tab taken on a Monday. Alternatively, a
   lock-screen screenshot of any Retro weekly recap or "new week" push showing its timestamp. This settles the day and
   time.
3. **Timehop daily push.** One lock-screen screenshot of Timehop's 8 am notification. This gives the verbatim wording.
4. **Timehop empty state.** One 10 s screen recording of opening Timehop on an account with Photos access set to "None"
   and no connected services, or on a day with no memories. This gives the empty-state wording and layout.
5. **Timehop v5 memory view.** One 15–20 s screen recording tapping through three years of one day, on the current
   version. This gives the raw banner height and label size, and the tap-through and progress-bar motion.
