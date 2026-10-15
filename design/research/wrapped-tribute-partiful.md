# Research: Spotify Wrapped · Tribute · VidDay · Partiful

Pass date: 2026-10-15. Surfaces: `year.story` (Spotify Wrapped), `birthday.request`, `birthday.contribute`,
`birthday.tribute` (Tribute, VidDay), `invite.web`, `invite.appclip` (Partiful). Proposals:
`design/proposals/wrapped-tribute-partiful.tokens.json`, `design/proposals/wrapped-tribute-partiful.copy.json`.
Image indexes: `references/auto/{wrapped,tribute,vidday,partiful}/INDEX.md`.

Leads re-checked: `/home/user/newproject/research/04-wrapped-duolingo-partiful.md`, `15-wrapped-partiful-exact.md`,
`21-events-plans.md`, `22-recaps-memories.md`. Lead claims are used only where re-verified below; lead [B]
(background) rows were not used.

## How values were obtained

- **VERIFIED**: live web pages opened in Playwright Chromium 141 (`/opt/pw-browsers`), iPhone UA, viewport 390×844 CSS px,
  deviceScaleFactor 3. Values are `getComputedStyle` / `getBoundingClientRect` in CSS px, which equal iOS pt at this
  viewport. Dumps are saved next to the screenshots (`*.computed-styles.json`). Partiful's design tokens were also read
  from its production CSS (`references/auto/partiful/css/partiful-web-css-excerpt-2026-10-15.css`).
- **SOURCED**: pixel measurements on official press renders, App Store panels and screen recordings.
  `pt = px / screen_px_width × 393` (393 assumed for every phone render; the Wrapped 2025 renders are 726×1567 px, ratio
  2.158, which matches both 393×852 and 430×932, so 393 is an assumption: multiply by 1.094 if 430 is right).
  Android recordings are converted the same way relative to the phone screen width.
- **Video**: frames decoded with ffmpeg at native rate. TikTok recordings were downloaded with yt-dlp to `/tmp/claude-0/wtp/`
  (not the repo). Only cited frames and per-frame measurement CSVs are saved. Precision is stated per value
  (±1 frame = ±33 ms at 30 fps, ±17 ms at 59.94 fps).
- **Fonts**: Spotify Mix / Spotify Circular (Spotify), PartifulGrotesk + TWK Lausanne (Partiful) are proprietary.
  Every font token is `{ios: system, android: system}` / PLATFORM. Type sizes for proprietary faces are converted
  by matching cap height to SF Pro (cap height 0.705 em). This is an approximation and is labelled as such.
- **Privacy/legal**: person avatars on Partiful pages are blurred in the saved screenshots (computed styles read
  first). No logo, wordmark or font file was saved on its own. Frames whose main content was a logo were removed.

---

## 1. `year.story` — Spotify Wrapped (2024 and 2025)

### 1.1 Reference images

| # | file | what | date |
|---|---|---|---|
| A | `references/auto/wrapped/press/wrapped24-press-minutes.jpg` | official 2024 render, 4 cards, 422 px wide each | 2024-12-04 |
| B | `references/auto/wrapped/press/wrapped24-press-summary-sharecard.jpg` | official 2024 render, summary screen 448×795 px | 2024-12-04 |
| C | `references/auto/wrapped/frames/wrapped24-rec-emilycraig-t005.png`, `-t010.png`, `-t020.png`, `-t020-bars-zoom2x.png` | real Android screen recording of 2024 Wrapped (TikTok @emilycraig1996_author 7444590686135160110), phone screen 864 px wide | 2024-12 |
| D | `references/auto/wrapped/press/wrapped25-press-minutes.png`, `-genres.png`, `-podcasts.png`, `-audiobooks.png` | official 2025 renders, screens 725–726 px wide (3840×2160 originals) | 2025-12-03 |
| E | `references/auto/wrapped/frames/wrapped25-rec-cdragon2010-*.png` | real Android screen recording of 2025 Wrapped (TikTok @cdragon2010 7579703263306485022), 1080×2340, 59.94 fps | 2025-12 |
| F | `references/auto/wrapped/press/wrapped25-press-sharecards.png`, `wrapped24-press-summary-sharecard.jpg` | share cards | 2024/2025 |
| G | `references/auto/wrapped/frames/wrapped25-press-gif-f181-story-open.png` | Spotify's own 2025 recording GIF (story opened) | 2025-12-03 |

### 1.2 Layout

Two different navigation models exist; both are evidenced.

**2024: tap-through stories (images A, B, C).**
- Story canvas is a **9:16 card** (A: 422×751 px = 1.780; B: 448×795 = 1.775; C: 864×1537 = 1.779). On a taller
  phone (C, 20:9) the card is letterboxed: a dark band above (behind the status bar) and below (behind the
  navigation bar), measured `#111111` (C t020, luma 17 at x 540, y 180–212).
- Top edge: **segmented progress bar**, one segment per chapter (6 in A/B, 13 in C), full card width minus side
  insets. The current segment fills left→right over time; completed segments are solid white; future segments are
  translucent white.
- Below the bar, one row of chrome: brand logo at left (do-not-copy); at right three icon buttons: **pause**,
  **sound on/off**, **close (×)**, each on a translucent dark circle (A zoom).
- Content is centred: a bold multi-line **headline** with an inline number, then a smaller **one- or two-line
  subline**. Art fills the background around the text.
- Bottom centre: **"Share this story"** (share glyph in a white circle + label), on shareable cards only (C t020; A
  cards 2–3; not on the intro card).
- Summary/outro (B): the share card itself shown at ~60% width, page dots under it (4 dots), a white **"Share"** pill,
  then a text link **"Replay from beginning"** with a replay glyph.
- Chapters contain several beats: e.g. chapter 1 in C = logo animation → "Hi {name}" → "Life moves fast" →
  subline "Luckily, we took notes." (C sheet).

**2025: vertical swipe pages (images D, E, G).**
- Each card is a full-screen page; **swipe up** for the next one. The first card shows a coach mark: the page dims and
  an animated hand demonstrates the gesture with the label **"Swipe up for more"** (E t007.500).
- **No progress bar** (D, E, G). Top chrome: back arrow at left, brand logo centred (do-not-copy), sound toggle at
  right. On Android a platform scrollbar thumb flashes at the right edge after each scroll (E t054) — platform
  behaviour, not designed.
- Content: same headline + subline structure; "big number" cards set the number edge-to-edge (D minutes: "78,432"
  spans x 1–720 of 725 px). A light pill **"Share this story"** sits under the text (D: 187.6×49.9 pt).
- Outro (E t252/t258): share-card carousel with page dots and a dark "Share" pill, then "One more thing..." with
  down-arrows inviting a further swipe.
- Newsroom (2025-12-03, https://newsroom.spotify.com/2025-12-03/2025-wrapped-user-experience/): "we've added new
  controls that let you adjust the speed of your experience and revisit specific moments without starting from
  the beginning." The control UI itself was not visible in E (Not found: its layout).

**Tap zones.** Not observable in recordings (no touch indicators). Only press support: "Users can tap the left or
right of the screen to go to the previous or next screen." (Uproxx, 2022-12-01,
https://uproxx.com/music/how-to-watch-your-spotify-wrapped-2022-again/). Zone widths not found. Hold-to-pause: not
found in any source; 2024 shows an explicit pause button instead (A, B, C).

### 1.3 Measured values

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| 9:16 (1.775–1.780) | story canvas aspect | A, B, C | A card 558–979 × 187–937; B 107–554 × 178–972; C 108–971 × 214–1750 | extent of non-background pixels | ±0.003 | SOURCED |
| `#111111` | letterbox bands above/below the 9:16 card on a 20:9 phone | C t020 | x 540, y 180–212 and y 1752–1868 | luma 17 (full range) | ±2/255 | SOURCED |
| 1.8 pt | progress bar thickness | B / A / C | B y 9–10 of card (2 px of 448); A y 196–197 (2 px of 422); C y 231–234 (≈4 px of 864) | rows with luma > 90 | 1.75 / 1.86 / 1.82 pt → ±0.3 pt | SOURCED |
| 8 pt | bar top offset from card top | B / A / C | 9 px/448; 9 px/422; 17 px/864 | first bar row − card top | 7.9 / 8.4 / 7.7 pt → ±0.5 pt | SOURCED |
| 3.6 pt | gap between segments | B / A / C | 4 px/448; 4 px/422; 8 px/864 | run analysis along bar row | 3.5 / 3.7 / 3.6 pt → ±0.4 pt | SOURCED |
| 11 pt (device) / 16.7 pt (renders) | bar side inset | C / B, A | C 24 px left, 25 px right of 864; B 19 px of 448; A 19 px left 16 px right of 422 | first/last bar pixel to card edge | ±0.5 pt each; **conflict** between real device and press renders | SOURCED |
| `#FFFFFF` | filled segment | B, C | B luma 254 at bar centre; C RGB (255,249,255) | median of 40×3 px | ±3/255 | SOURCED |
| white @ 0.43 | unfilled segment | B | B segs 5–6 luma 109–113 over black (luma 1) | α = (L−bg)/(255−bg) | ±0.05; C over pink art gives 0.27–0.31 (compressed video) | SOURCED |
| linear | fill easing | C | segment 1 fill 2.23→13.53 s; segment 11 110.88→137.16 s | per-frame fill fraction (`wrapped24-rec-emilycraig-progress-fill.csv`), linear fit R² 0.997 both, quadratic term ≈0 | — | SOURCED |
| 11.3 s and 26.3 s | segment (chapter) duration — varies per chapter | C | as above | 1/slope of linear fit | ±0.1 s | SOURCED |
| 18.2 pt, 0.80 s, S-curve | headline moves up when subline arrives ("Life moves fast") | C | top y 956→916 px, 15.533→16.333 s | per-frame top row of white text (`…-reveal-positions.csv`) | ±1 frame (33 ms), ±0.5 pt | SOURCED |
| 25.0 pt, 0.60 s | subline enters from below and settles ("Luckily, we took notes.") | C | top y 1083→1028 px, 15.800→16.400 s | same | ±1 frame | SOURCED |
| 0.267 s | delay from headline start to subline appearance | C | 15.533 → 15.800 s | same | ±1 frame | SOURCED |
| 22.3 pt cap height (≈32 pt SF) | 2024 headline | C t020 | "Y" of "You listened for", 49 px of 864 | cap height × 393/864; ÷0.705 for SF size | ±0.5 pt cap | SOURCED |
| 36.4 pt | 2024 headline line pitch | C t020 | line tops 813 → 893 px | difference × 393/864 | ±0.5 pt | SOURCED |
| 11.4 pt ascender (≈15–16 pt) | 2024 subline | C t020 | "worldwide." 1132–1156 px | ascender height | ±0.5 pt | SOURCED |
| 21.4 pt | 2024 subline line pitch | C t020 | 1085 → 1132 px | difference | ±0.5 pt | SOURCED |
| 29 pt | 2024 "Share this story" row bottom inset from card bottom | C t020 | row 1646–1686, card bottom 1750 | (1750−1686)×393/864 | ±0.5 pt | SOURCED |
| 18.6 pt | 2024 "Share this story" row height (glyph circle + label) | C t020 | 1646–1686 | height | ±0.5 pt | SOURCED |
| 148 × 50 pt, full radius, white fill, dark label | 2024 summary "Share" pill | B | x 140–308, y 620–676 of card | extent × 393/448 | ±1 pt | SOURCED |
| 14.9 pt | 2024 chrome icon glyph height (pause/sound/close) | B | y 40–56 of card | extent | ±1 pt | SOURCED |
| 42 pt | 2024 chrome row centre from card top | B | y 48 | ×393/448 | ±1 pt | SOURCED |
| 17.9 pt cap (≈25 pt SF) | 2025 headline ("You listened. We counted.") | D minutes, screen 1 | "Y" 33 px of 726 | cap height | ±0.5 pt | SOURCED |
| 30.9 pt | 2025 headline line pitch | D minutes, screen 1 | 783 → 840 px | difference | ±0.5 pt | SOURCED |
| 11.9 pt cap (≈17 pt SF) | 2025 subline | D minutes, screen 2 | "Y" 22 px of 725 | cap height | ±0.5 pt | SOURCED |
| 23.3 pt | 2025 subline line pitch | D minutes, screen 2 | 835 → 878 px | difference | ±0.5 pt | SOURCED |
| edge-to-edge | 2025 big number width | D minutes, screen 2 | x 1–720 of 725 | extent | — | SOURCED |
| 187.6 × 49.9 pt, full radius | 2025 "Share this story" pill | D minutes, screen 2 | x 189–534, y 956–1047 | extent × 393/725 | ±0.6 pt | SOURCED |
| 12.5 pt cap (≈17.7 pt SF), padding ≈34.5 pt | 2025 pill label | D minutes, screen 2 | "S" 23 px; label x 252–470 | cap height; (pill w − label w)/2 | ±0.6 pt | SOURCED |
| 27.6 pt | 2025 gap subline → pill | D minutes, screen 2 | 905 → 956 px | difference | ±0.6 pt | SOURCED |
| 11.4 × 19.5 pt glyph, centre x 28.7 pt | 2025 back chevron | D minutes, screen 1 | x 43–63, y 45–80 | extent | ±0.6 pt | SOURCED |
| centre x 362.4 pt | 2025 sound toggle glyph | D minutes, screen 1 | x 648–691 | extent | ±0.6 pt | SOURCED |
| 0.70 black | 2025 coach-mark scrim | E | bg luma 238 → 71, x 100–300 y 700–850, 5.0–8.9 s | α = 1 − 71/238 | ±0.02 | SOURCED |
| 0.35–0.39 s | 2025 coach-mark scrim fade-in | E | 6.291 s (first change) → 6.628–6.684 s (settled) | per-frame mean luma | ±1 frame (17 ms) | SOURCED |
| ≈1.8 s | 2025 delay from first card to coach mark | E | first card visible ≈4.5 s; scrim starts 6.29 s | frame inspection | ±0.1 s | SOURCED |
| 1 page, 243–262 ms, ease-out | 2025 swipe: release (peak velocity) → rest | E | events at 9.77, 17.70, 25.93, 34.52 s | vertical row-profile matching per frame (`wrapped25-rec-cdragon2010-swipe-shift.csv`); total shift 98–107% of screen; velocity decays 200→20 px/frame over 14–15 frames | ±17 ms | SOURCED |
| 430–505 ms | 2025 whole swipe gesture incl. finger drag | E | same | same | ±17 ms | SOURCED |
| 9:16 (1.775) | share card aspect, 2025 | F (2025) | 4 cards 808–810 × 1436–1437 px | extent | ±0.003 | SOURCED |
| 7.7% of width | share card text margin, 2025 | F (2025) | card 1: text x 62 of 809 | ratio | ±0.2% | SOURCED |
| 7.8% of width | share card corner radius in press render (may be presentation only) | F (2025) | first non-bg x at dy 0/16/32/44 = 61/20/7/3 px → r ≈ 62–64 px of 809 | circle fit | ±0.3% | SOURCED |

Colours of the story canvases (2025 `#272727` dark, `#EFEFEA` light, pill `#EFEFEA`; 2024 per-chapter art colours)
are Spotify's brand palette and are **not proposed** (brief: no brand colours). Only the neutral white-on-dark bar
values are proposed.

### 1.4 Motion summary

- Progress fill: linear, duration = chapter length (11.3 s and 26.3 s measured; chapters hold several beats).
- Beat change inside a chapter: the existing headline eases up 18.2 pt over 0.80 s (S-curve; samples at 25/50/75% time
  = 12.5/72.5/92.5% distance) while the subline enters 25 pt lower 0.267 s later and settles in 0.60 s. Curve: duration
  plus sampled points only; no named curve fitted.
- 2024 chapter-to-chapter: art transitions are bespoke animation (not reproducible, not proposed).
- 2025 page change: platform vertical paging; release→rest 243–262 ms with decelerating velocity (PLATFORM scroll physics).
- 2025 coach mark: 0.70 black scrim fades in over ≈0.35–0.39 s, ≈1.8 s after the first card appears.
- Intro/outro: bespoke brand animation (not proposed).
- Not measurable: open-from-entry transition (Spotify's GIF is edited at the cut: clock 5:11→5:12 between frames 180–181).

### 1.5 Copy (verbatim) and voice

| string | where | source |
|---|---|---|
| "It's time for your 2025 Wrapped" / "We can't wait to show it to you." / "Let's go" | 2025 home entry card | `wrapped25-press-entrypoints.png` |
| "Your 2025 Wrapped" / "Dive into your year in listening." | 2025 entry card | same |
| "Your Stories" / "Replay your Wrapped." | 2025 entry tile | same |
| "We're ready for you." / "Come on down." | 2025 first card | E t004.800 |
| "Swipe up for more" | 2025 coach mark | E t007.500 |
| "You listened. We counted." | 2025 | D minutes; E sheet |
| "You listened for {n} minutes. That's {d} days. Nice." | 2025 big-number card | D minutes |
| "Taste like yours can't be defined. But let's try anyway." / "You listened to {n} genres." | 2025 | D genres |
| "Your top genres" | 2025 | D genres |
| "You streamed {n} minutes of podcasts." / "Good chat." | 2025 | D podcasts |
| "Once upon a time, there was a book lover." / "(It was you.)" | 2025 | D audiobooks |
| "You listened to {n} audiobooks." / "And your top genre was {genre}." | 2025 | D audiobooks |
| "Swipe up for a bonus chapter." | 2025 | D audiobooks |
| "Your listening age" / "Since you were into music from the Late 70s. You're an old soul." | 2025 | E t048 sheet |
| "You listened to {n} songs this year." / "But can you guess your #1?" | 2025 | E t054, t060 |
| "Make your pick." / "You got it!" | 2025 quiz | E sheet |
| "Your top song" / "You listened {n} times." | 2025 | E sheet |
| "You listened to {n} albums this year." / "Long live the album." | 2025 | E sheet |
| "You listened to {n} artists this year." / "And these 5 were extra special." | 2025 | E sheet |
| "And now, a word from one of your favorites." | 2025 | E sheet |
| "Time for your victory lap." / "And if you're not ready for Wrapped to be over, well..." | 2025 outro | E sheet |
| "One more thing..." | 2025 outro | E t258 |
| "We pulled some of your files, just in case." / "Take a look at more 2025 highlights." / "Get your report" / "See your report" | 2025 archive | E sheet |
| "Share this story" | 2024 + 2025 per-card share | A, C, D |
| "Share" / "Replay from beginning" | 2024 summary | B |
| "It's that time of year again. Wrapped's ready. Are you?" | 2024 intro subline | `wrapped24-rec-xenarxoxo-sheet-every3s.png` |
| "Life moves fast" / "Luckily, we took notes." | 2024 | xenarxoxo t7.5 s shows "Luckily, we took notes."; emilycraig t16.5 s shows "Luckily we took notes." (both checked at full resolution; the comma differs between the two users' runs) |
| "You listened for {n} minutes this year" | 2024 | A, C |
| "Your biggest listening day was {date} with {n} minutes" / "Where do you find the time?" | 2024 | A, C sheet |
| "You played {n} songs this year" / "And one song again, and again, and again, and again…" | 2024 | C sheet |
| "You've changed. And so has your listening." / "Let's look at your 2024 Music Evolution." | 2024 | xenarxoxo sheet |
| "{Month} was your {X} phase" | 2024 | C sheet |
| "Who else got a lot of play this year?" / "Big reveal in 3... 2... 1..." | 2024 | xenarxoxo sheet |
| "Oh, looks like we have company" | 2024 | C sheet |
| "Thanks for coming along for the ride" / "Until we meet again..." | 2024 outro | xenarxoxo sheet |

**Voice pattern (Wrapped).** Sentence case. Second person ("you/your") for the user and first person plural
("we") for the app. Headlines are 2–9 words. Full sentences end with a period. Labels ("Your top genres", "Your listening
age") have no period. The second beat is a short aside of 1–5 words that is wry or affectionate ("Nice.",
"Good chat.", "(It was you.)", "Long live the album."), often opened by "But", "And" or "Luckily". Teasers end in an
ellipsis ("One more thing...", "Big reveal in 3... 2... 1..."). There are no emoji and no exclamation marks in card
copy, except the quiz confirmation "You got it!". Numbers sit inline and bold in sublines. Buttons are
sentence-case verb phrases ("Share this story", "Let's go").

Proposed pattern ids for `design/COPY.md` (examples above):
- **P-YS-1 two-beat headline** — "You {verb}. We {verb}." ("You listened. We counted.")
- **P-YS-2 setup + aside** — a sentence and a 1–5 word wry aside ("Life moves fast" / "Luckily, we took notes."; "Once upon a time, there was a book lover." / "(It was you.)")
- **P-YS-3 section label** — "Your {noun phrase}", no period ("Your top genres", "Your listening age")
- **P-YS-4 teaser** — short line ending with "..." ("One more thing...")
- **P-YS-5 welcome / farewell** — invitational second person ("We're ready for you." / "Come on down."; "Thanks for coming along for the ride" / "Until we meet again...")

### 1.6 Do-not-copy (year.story)

- Percentile and rank comparisons: "That puts you in the top {n}% of listeners worldwide.", "You were in the top 0.1% of listeners globally.", "You're a top 5% fan…", Fan Leaderboard, "While it's not a competition... There is a leaderboard." (comparison and competition: tenet 3 "the group, not the individual"; tenet 2).
- Volume-as-achievement praise: "You overachiever." (xenarxoxo sheet) and "Commitment never sounded so good." (read from the 180 px emilycraig contact-sheet tile only; not re-verified at full resolution) (performance framing).
- "Where do you find the time?" (mild judgement of consumption; tenet 5).
- Big-number cards that count consumption (minutes, plays, streams): the layout is recorded, but counts conflict with "no likes or counts". Owner decision before any count appears in our year story.
- Wrapped Party awards ("Most Minutes", etc.) and the "streak" chips in the 2025 monthly race ("3-day streak", "12-day streak", E sheet) — streaks are forbidden.
- Spotify logo in the chrome, Spotify colours, Spotify Mix/Circular, the "2025" artwork, the expressive logo animations.
- "Report powered by AI" archive reports (no AI-written content in this product).

### 1.7 Not found (year.story)

- Tap-zone widths and whether a hold pauses (only press says "tap the left or right of the screen"; recordings show no touches). Tried: newsroom 2024/2025 pages, support.spotify.com (no hit in search), Uproxx.
- Auto-advance per beat (only per chapter measurable; beats inside a chapter are art-driven).
- The 2025 speed/replay control UI (newsroom text only; not seen in recording E).
- Share-sheet contents after tapping "Share this story" (not shown in any recording found).
- iOS recording of either year (both recordings are Android); iOS safe-area placement of the chrome.
- Exact story canvas corner radius on device (renders show rounded screens only because of the phone frame).

---

## 2. `birthday.request` — Tribute and VidDay (the private request to contribute)

Our surface: a private request to group members to add one photo and one line for someone's birthday. The
references request **video** messages; only structure, copy pattern and tone transfer. Tribute has no native app
(web only; see `references/auto/tribute/INDEX.md`). VidDay has iOS app id6748774475 (v2.1, 2026-08-11).

### 2.1 Reference images

| # | file | what |
|---|---|---|
| T1 | `references/auto/tribute/mockups/tribute-home-phone-step-1-contribution-page.png` | current Tribute contribution page (official mockup): recipient photo, "Congrats Tribute for Ollie!", "Submit by Wednesday, December 31, 2025", welcome message, "Record Your Video" |
| T2 | `references/auto/tribute/web/tribute-web-testimonials-contribution-page-viewport.png` (+ computed styles) | live legacy contribution page, VERIFIED |
| T3 | `references/auto/tribute/web/tribute-web-ayejaye-contribution-page-viewport.png` | live legacy page, birthday occasion |
| V1 | `references/auto/vidday/store/vidday-store-01.png` | VidDay contribution page (App Store panel): "Harper / Birthday Video", "Message Ideas", "Submissions are due in: 3d 12h 34m", "Add to Calendar", "Record / Upload Now" |
| V2 | `references/auto/vidday/frames/vidday-tour-t064-phone.png` | invitee page ("Review Mode"): photo, "Celebration video for / Amelia Harris", message, "RECORD OR UPLOAD" |
| V3 | `references/auto/vidday/frames/vidday-tour-t036-phone.png`, `-t042-phone.png` | invitation editor: default message, 216/500 counter, "Contribute before… Friday, May 14" |
| V4 | `references/auto/vidday/frames/vidday-tour-t072-phone.png` | the SMS the invitee receives |

### 2.2 Layout (top → bottom)

- **Tribute (current, T1):** recipient photo (wide, rounded) → title "{Occasion} Tribute for {Name}!" → "Submit by
  {weekday, month day, year}" → welcome message in a bordered box → full-width primary button "Record Your Video".
  The creator's own panel adds settings (Allow Gifts) below; invitees do not see it.
- **Tribute (legacy, T2/T3):** hero photo with the title and welcome message over it → full-width "Add Your Video"
  button → countdown "Tribute Ends In:" D/H/M/S (do-not-copy) → "Questions to answer in your video" (dark header bar +
  bulleted prompts) → share buttons → list of submitted videos (public on this template; not for us).
- **VidDay (V1, V2):** recipient photo (circle in V1, rounded square in V2) on an occasion banner → recipient name →
  occasion line ("Birthday Video") or "Celebration video for" above the name → welcome message → "Message Ideas"
  with 2 prompt cards (V1) → due date (V1 countdown, do-not-copy; V3 "Contribute before…" date) → "Add to Calendar"
  → primary button "Record / Upload Now" (V1) / "RECORD OR UPLOAD" (V2).
- Privacy rule (VidDay help "How does the process work?"): "Invitees can only upload their media—they won't be able
  to see anyone else's submissions." Matches our "private request".

### 2.3 Measured values

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| 15 px | page side margin (legacy Tribute) | T2 computed | x 15 for title, button, lists | getBoundingClientRect | exact | VERIFIED |
| 360 × 62, radius 8, `#FF4B4A`, label 22/600 white | "Add Your Video" button | T2 computed | y 380.8 | computed style | exact (CSS px = pt) | VERIFIED |
| 24/600, white, line-height 28.8 | page title | T2 computed | y 84 | computed style | exact | VERIFIED |
| 16/400, line-height 28 | welcome message | T2 computed | y 133.8 | computed style | exact | VERIFIED |
| 15/500 white on `#292D34`, bar 360 × 42 | "Questions to answer in your video" header | T2 computed | y 559.8 | computed style | exact | VERIFIED |
| 15/400 `#333333`, line-height 18.75 | prompt list items | T2 computed | y 625.8 | computed style | exact | VERIFIED |
| `#F6F4F3` | page background (legacy Tribute) | T2 computed | body | computed style | exact | VERIFIED |
| Figtree (OFL) | Tribute web font | T2 computed | all text | computed `font-family` | exact | VERIFIED (font proposed as PLATFORM for consistency; see notes) |
| 327.8 × 67.4 pt, centred, side inset ≈33 pt, `#0086FE` | "RECORD OR UPLOAD" button (VidDay) | V2 (tour t064, phone screen x 688–1229 = 542 px) | x 734–1185, y 894–986 | extent × 393/542; median colour 5×20 px | ±1.5 pt; ±3/255 | SOURCED |
| 26.8 pt ascender | recipient name "Amelia Harris" | V2 | y 579–615 | ascender height × 393/542 | ±0.7 pt | SOURCED |
| 12.3 pt ascender | "Celebration video for" | V2 | y 545–561 | same | ±0.7 pt | SOURCED |
| 24.3 pt | welcome message line pitch | V2 | line tops 659 → 693 → 726 | mean difference | ±0.7 pt | SOURCED |
| 500 characters | max length of the invitation message | V3 | counter "216/500" | read from UI | exact | SOURCED |

### 2.4 Copy (verbatim)

| string | source |
|---|---|
| "Hi everyone! You're invited to submit a video message and join in on the fun of making a personalized video for Amelia. It's quick and easy. It's your contribution that will help to make this unforgettable. Thank you!" | VidDay default invitation message, V3 (tour t036/t042) |
| "Hi everyone! You're invited to submit a video message and join in on the fun of making a personalized video for Amelia. It's quick and easy. It's your contribution that will help to make this unforgettable. Go to share.vidday.com/b-5f0h9q to submit before May 14." | VidDay SMS as received, V4 (tour t072) |
| "Contribute before…" / "Friday, May 14" | VidDay editor, V3 |
| "Celebration video for" / "{Full name}" / "RECORD OR UPLOAD" | VidDay invitee page, V2 |
| "{Name}" / "Birthday Video" / "Message Ideas" / "What do you appreciate most about Harper?" / "How has Harper impacted your life?" / "Submissions are due in:" / "Add to Calendar" / "Record / Upload Now" | VidDay App Store panel, V1 |
| "Congrats Tribute for Ollie!" / "Submit by" / "Record Your Video" / "We're so proud of Ollie and all he's achieved. Help us celebrate this special moment by sharing your love, memories, and well wishes to make it even more meaningful for him." | Tribute mockup, T1 |
| "Add Your Video" / "Questions to answer in your video" | Tribute live, T2 |
| "Hey — I'm organizing a birthday video for [Name]'s birthday on [date]. Would love a short clip from you. Click the link, record for 30-60 seconds, and share a specific memory or something you've always wanted to tell them. Deadline is [date]. Thank you!" | Tribute's suggested invitation text, https://blog.tribute.co/birthday-video-from-friends/ (2026-04-12) |
| "Tell contributors: 30 seconds is enough. Recorded on a phone is fine. One specific memory is better than a long polished statement. Imperfect and real beats perfect and absent." | same blog (guidance, not UI) |
| "The due date is more of a guideline than a hard cutoff. In fact, most videos are submitted after the deadline passes." | https://www.tribute.co/help/creators/can-videos-be-submitted-after-the-due-date/ |
| "Turn your phone sideways, find a window to face, and tell us your favorite memory of Dad." | Tribute example Participant Prompt, https://www.tribute.co/help/creators/what-should-i-do-if-a-tribute-invitee-submits-a-video-recorded-vertically/ |

Channel and reminder facts: VidDay sends invitations by email/SMS ("Smart Invites") or a link via WhatsApp, Messenger,
text etc. (https://help.vidday.com/how-to-send-your-invitations/). Tribute "sends up to five emails to anyone who
hasn't submitted yet": Invitation, Halfway, Day before the deadline, Day of the deadline, Day after the deadline
(https://www.tribute.co/help/creators/how-are-tribute-participants-reminded-to-submit-a-video/).

**Voice pattern (requests).** Warm, second person, addressed to a group ("Hi everyone!", "Hey —"). One sentence names
the person and the occasion; one sentence lowers the bar ("It's quick and easy.", "30 seconds is enough."); prompts
are open questions about the person ("What do you appreciate most about {name}?"). Buttons are imperative verb
phrases in Title Case ("Record Your Video", "Add Your Video", "Record / Upload Now"). Exclamation marks appear in
greetings and titles only. No emoji. Proposed pattern ids:
- **P-BR-1 invitation** — "You're invited to {action} for {name}." + "It's quick and easy." (VidDay)
- **P-BR-2 prompt** — "What do you appreciate most about {name}?" (VidDay)
- **P-BR-3 due line** — "Submit by {date}" (Tribute) — a date, never a countdown.

### 2.5 Do-not-copy

- Countdown timers to the deadline: VidDay "Submissions are due in: 3d 12h 34m", Tribute "Tribute Ends In:" D/H/M/S (urgency; tenet 5).
- Repeated reminder emails including one the day after the deadline (Tribute's five-email chase); VidDay's listing: "Our built-in tools handle the "nagging" for you." (tenet 5: no nagging).
- "It's your contribution that will help to make this unforgettable." (obligation framing; tenet 5).
- Public list of everyone's submitted videos on the legacy Tribute page (privacy; our request is private).
- Pre-ticked "Send me offers & updates!" opt-in (Tribute upload step 1).
- Group gift money collection ("Allow Gifts", VidDay "Funds were collected…"): not in scope; payments.

### 2.6 Not found

- The **email/SMS invitation text Tribute itself sends** (only the creator's suggested text was found). Tried: Tribute help center (23 creator + 1 participant articles), blog, WebSearch; help.tribute.co legacy URL now redirects to /help/; web.archive.org unreachable from this machine.
- Tribute's push/notification text (Tribute has no app).
- VidDay reminder email/SMS wording (only that reminders exist).
- Any reference's wording for a **photo + one-line** request (both references ask for video).

---

## 3. `birthday.contribute` — Tribute and VidDay (the contribution flow)

### 3.1 Reference images

| # | file | what |
|---|---|---|
| T4 | `references/auto/tribute/web/tribute-web-testimonials-upload-step1-info.png` (+ computed styles) | live upload flow, step 1 of 4 (Info · Video · Photos · Done) |
| T1 | `references/auto/tribute/mockups/tribute-home-phone-step-1-contribution-page.png` | entry point ("Record Your Video") |
| V5 | `references/auto/vidday/frames/vidday-tour-t102-phone.png` | "Let's add media!" chooser (VIDEOS & PHOTOS / TEXT CARD / CANCEL; creator-side but same component) |
| V6 | `references/auto/vidday/frames/vidday-tour-t096-phone.png` | a received clip: player, "Submitted by Emma Williams" |

### 3.2 Flow (verbatim steps from help centers)

- **Tribute, phone** (https://www.tribute.co/help/creators/how-do-i-upload-a-video/): "Click **Record Video**." → "On a
  phone, choose Record or Upload Video — your phone offers you the camera or your camera roll." → "Watch it back.
  Click **Retake** if you want another go." → "Add your name and email, then click **Submit**." → "You'll see **Video
  Upload Complete!** when it's through." Contributors can send more than one ("They return to the same page…").
- **Tribute, live step 1 (T4):** 4-step stepper (Info, Video, Photos, Done); "Let's record a video for Tribute!"
  (the page's recipient name is "Tribute"), "Thank you for taking the time to participate!", Your Name, Your Email,
  Continue.
- **VidDay, phone** (https://help.vidday.com/how-to-record-a-video-with-a-phone/): "Open the invitation link and tap
  **Record/Upload**." → "Select Camera or Files" → "choose Take Video" → "tap Play to review it" → "Tap **Retake** to
  record again" → "tap **Use Video** to upload it" → "a confirmation page, where you can add your name and email
  (optional)" → "If the final video is shared with you, you'll receive an email when it's ready." "Submit Another"
  after an upload (https://help.vidday.com/how-many-people-can-i-invite/).

### 3.3 Limits (verbatim)

| limit | value | source |
|---|---|---|
| recommended clip length | "30-120 seconds" | VidDay, https://help.vidday.com/how-many-people-can-i-invite/ |
| recommended clip length | "record for 30-60 seconds" | Tribute blog (2026-04-12) |
| media per upload session | "10 files per session" | VidDay, https://help.vidday.com/how-to-upload-media-using-a-phone/ |
| size per upload | "954 MB per upload" | VidDay, same |
| size per file | "up to 4 GB per file" | Tribute, how-do-i-upload-a-video |
| minimum length | "longer than two seconds" | Tribute, same |
| minimum dimensions | "more than 180 pixels wide and tall" | Tribute, same |
| audio | "the file must contain an audio track" | Tribute, same |
| photos per batch (creator) | "up to 25 at a time" | Tribute, how-do-i-add-photos-to-my-project |
| invitation message | 500 characters | VidDay editor counter (V3) |
| contributor's text message length | **not found** | — |

### 3.4 Measured values (Tribute step 1, VERIFIED)

| value | element | file | px coords | method | level |
|---|---|---|---|---|---|
| 40 px circles, radius 9999; active `#B8B9B9` label white 14/600; inactive `rgba(255,255,255,0.22)` label `rgba(255,255,255,0.55)`; step label 10 px | 4-step stepper | T4 computed | y 104 | computed style | VERIFIED |
| 20/500 white | step heading | T4 computed | y 274 | computed style | VERIFIED |
| 16/400 `rgba(255,255,255,0.72)` | step sub-heading | T4 computed | y 314 | computed style | VERIFIED |
| 350 × 46, radius 8, fill `rgba(255,255,255,0.08)`, value 16/400 | text input | T4 computed | y 390 | computed style | VERIFIED |
| 350 × 50, radius 8, label 16/600 `#1A1A1A` | Continue button | T4 computed | y 556 | computed style (background is an image gradient; colour not sampled) | VERIFIED |
| 20 px | page side margin | T4 computed | x 20 | computed style | VERIFIED |

### 3.5 Copy (verbatim) and voice

"Record Video", "Record or Upload Video", "Retake", "Submit", "Video Upload Complete!", "Let's record a video for
{name}!", "Thank you for taking the time to participate!", "Your Name", "Your Email", "Continue" (Tribute);
"Record/Upload", "Take Video", "Use Video", "Submit Another", "Let's add media!", "VIDEOS & PHOTOS", "TEXT CARD",
"CANCEL", "Submitted by {name}" (VidDay).

Voice: short imperative buttons; one exclamation for the completion state ("Video Upload Complete!") and the step
greeting ("Let's record a video for …!"); thanks stated once ("Thank you for taking the time to participate!").
Proposed pattern ids: **P-BC-1 step greeting** "Let's {verb} a {noun} for {name}!"; **P-BC-2 completion** "{Noun} Upload
Complete!"; **P-BC-3 buttons** single verbs ("Retake", "Submit", "Continue").

### 3.6 Do-not-copy / Not found

- Do-not-copy: marketing opt-in pre-ticked; asking for email from people already in the group.
- Not found: the contributor record/upload screens of either service (would require submitting to a live service;
  not done). The text-field label/placeholder for a written line; per-contribution caption limits; the screen a
  contributor sees after the deadline; any "only your own photos" filter (our rule: only photos you posted or are
  tagged in — no reference has it).

---

## 4. `birthday.tribute` — the finished video for the birthday person

### 4.1 Reference images and videos

| # | file | what |
|---|---|---|
| T5 | `references/auto/tribute/frames/tribute-sample-tess-t007.080-first-clip.png`, `-t012.000.png`, `-t050.000.png`, `tribute-sample-tess-clips-7.2-94.0s-every2s.png` | Tribute sample "Birthday Tribute for Tess", https://website.tribute.co/6KY_IZ1tLME.mp4 (640×360, 29.97 fps, 104.28 s) |
| T6 | `references/auto/tribute/frames/tribute-sample-doug-clips-7.2-62.2s-every2s.png` | Tribute sample "Happy Birthday to Doug!", https://website.tribute.co/QQe5RpbFIyI.mp4 (72.49 s) |
| T7 | `references/auto/tribute/mockups/tribute-home-phone-step-3-completed-page.png` | finished Tribute page (player, share icons, Download) |
| V7 | `references/auto/vidday/frames/vidday-tour-t116.500-phone.png` … `-t120.000-phone.png` | VidDay recipient page: gift wrap → unwrap → title card → first photo |
| V8 | `references/auto/vidday/store/vidday-store-08.png`, `-09.png` | gift-wrap picker, "Present Now", "Download", "Send to Harper / A private link to share"; final player "0:46 / 8:30" |
| V9 | `references/auto/vidday/frames/vidday-tour-t111-phone.png`, `-t114-phone.png` | "Preview & Finalize", "Create Your Video", "It'll take 10 – 30 minutes to finalize your video." |

### 4.2 Structure

- **Tribute (T5, T6):** intro sting 7.0 s (Tribute brand animation; do-not-copy) → contributor clips joined by **hard cuts**
  (single-frame changes at every one of 28 + 22 cuts; no crossfades) → outro sting ≈10.1 s (brand; do-not-copy).
  Portrait clips are **pillarboxed on black** inside 16:9 (T5 t007.080: content 204 px of 640). Help: "A vertical video
  is fine. It plays inside your Tribute with the background filling the space on either side, and nothing gets cut
  off." No automatic name captions or title card in either sample. Optional, creator-added: title slides
  ("Open with the recipient's name and the occasion"; duration set per slide), text on a clip ("Name whoever is
  speaking… 'Auntie Jean, Chicago' at the bottom of the frame"), background music under everything with two volume
  levels (under videos vs under photos/titles: "Keep it low under videos so voices carry, and bring it up under photos").
  Photos "stay on screen for a set number of seconds" (value not found).
- **VidDay (V7–V9):** recipient opens a private gift page; the video is wrapped ("Gift Wrap Effect … with a single click,
  the video unwraps and begins to play"); tap "UNWRAP VIDEO" → ribbons slide away → **title card** "HAPPY BIRTHDAY,
  AMELIA!" on the theme background → **crossfade** to the first photo, which is inset in a theme frame and slowly zooms.
  Custom intro photo can replace the VidDay logo ($4.99, help "Can I add a custom intro?"). Finalised video: "1080p HD",
  "We automatically normalize the volume between clips", "Personal Gift Page … Post a thank-you video".

### 4.3 Measured values

| value | element | file | method | precision | level |
|---|---|---|---|---|---|
| hard cut (0 frames) | transition between contributor clips | T5 (28 cuts), T6 (22 cuts) | ffmpeg scene score > 0.25, then per-frame mean abs diff: one spike frame, flat on both sides | ±1 frame | SOURCED |
| 7.0 s / ≈10.1 s | intro / outro sting length | T5 (0–7.04 s, 94.19–104.28 s), T6 (0–7.01 s, 62.40–72.49 s) | cut times | ±1 frame | SOURCED (brand; do-not-copy) |
| 0.6–10.3 s, median 1.9–2.8 s | shot length in the marketing samples | T5, T6 | differences between cuts | ±1 frame | SOURCED — these are highlight edits, **not** per-contributor length (see 3.3) |
| black | pillarbox fill behind portrait clips | T5 t007.080 | luma ≤ 20 outside x 218–421 | ±2/255 | SOURCED |
| ≈0.47 s | gift-wrap ribbons clear after the unwrap tap | V7 (tour 117.20–117.67 s) | per-frame diff on phone crop | ±2 frames; marketing edit | SOURCED |
| ≥1.3 s | title card hold before the crossfade | V7 (117.67–118.97 s) | static frames | lower bound (tour may be edited) | SOURCED |
| ≈0.6 s | crossfade title card → first photo | V7 (118.97–≈119.57 s) | decaying per-frame diff 8.6 → 2.7 | ±2 frames | SOURCED |
| slow zoom (duration only) | photo motion inside the video | V7 (119.6–121 s) | constant small per-frame diff (≈2–3) | curve not measurable | SOURCED |
| 10–30 min | time to render the final video | V9 text | read | — | SOURCED |

### 4.4 Copy (verbatim)

VidDay: "UNWRAP VIDEO", "HAPPY BIRTHDAY, AMELIA!", "Share" / "Send a special link", "Present Now", "Download",
"Send to Harper" / "A private link to share", "Preview & Finalize", "This is where your media gets compiled into one
personalized video.", "Want a sneak peek?", "MAKE A PREVIEW", "Create Your Video", "FINALIZE", "It'll take 10 – 30
minutes to finalize your video.". Tribute: "Download Tribute", "Copy link to Tribute", "Share it for me.", "I'll share
it.", "Share with participants?" (https://www.tribute.co/help/creators/how-will-the-final-tribute-be-delivered-to-me/),
"Completed" (T7). VidDay recipient help: "A VidDay is a collection of videos and photos from people who love you,
brought together in a video montage as a gift." (https://help.vidday.com/i-received-a-vidday-how-does-this-work/).

Voice: celebratory title card (all caps in VidDay's theme rendering, so case is a style), plain verb buttons, one
explanatory sentence per step. Proposed pattern id: **P-BT-1 title card** "Happy birthday, {name}!" (VidDay title card,
case normalised).

### 4.5 Do-not-copy / Not found

- Do-not-copy: brand intro/outro stings and watermarks; gift-card money ("Funds were collected to redeem as a gift");
  paid upsells (custom intro $4.99, Video Book, DVD/USB); clip/contributor counts on the cover ("From Russell and 36
  others" — a count).
- Not found: per-contribution layout with **name + one line over a photo** (neither sample shows automatic captions);
  photo hold duration default; music default and fade timings; end card of a full (non-marketing) VidDay; a
  full-length real Tribute (samples are highlight cuts); push/email text that tells the recipient their video is ready.

---

## 5. `invite.web` — Partiful event page seen before install

### 5.1 Reference images

| # | file | what |
|---|---|---|
| P1 | `references/auto/partiful/web/pf-web-public-light-01.png` … `-04.png` (+ `pf-web-public-light.computed-styles.json`) | live public event, light theme (https://partiful.com/e/egrwj3biCR6g5MLJ0dbv) |
| P2 | `references/auto/partiful/web/pf-web-public-dark-01.png` … `-04.png` (+ computed styles) | live public event, dark theme (https://partiful.com/e/tdWKXXnFRQqtuxOcPz5e) |
| P3 | `references/auto/partiful/web/pf-web-private-past-01.png` … `-03.png` (+ computed styles) | live **non-public** (link-only) event, logged out (https://partiful.com/e/6p1Hm5OlE2YIH1VX515z) — the closest analogue to a private group invite |
| P4 | `references/auto/partiful/web/pf-web-public-light-rsvp-sheet.png`, `pf-web-public-dark-rsvp-sheet.png` (+ computed styles) | the RSVP sheet (opened, nothing submitted) |
| P5 | `references/auto/partiful/store/partiful-store-01.png` | in-app event page ("lexi's 26th": title, poster, date, "Hosted by", host, location, floating "Going" button) |
| P6 | `references/auto/partiful/css/partiful-web-css-excerpt-2026-10-15.css` | production design tokens (light/dark semantic colours, type scale, spacing, radii, durations) |

All three live pages were rendered by the same build (`dpl_68jTrKjNvy2nK2x5FYwMN16Zt8Yv`), 2026-10-15.

### 5.2 Layout (390 pt wide, top → bottom)

1. Acquisition banner (fixed top, 0–56): "Events can be easy 🕺" + outlined pill "Make your own" (do-not-copy as an upsell; see 5.6).
2. Header: logo (left, 32 px mark + 80 px wordmark) and a black "Login" pill (68 × 36) at right.
3. Public events only: pill "See all in 🗽 Trending in NYC ↗" (centred, 40.6 high, outlined).
4. **Event title**, centred, display face, 2 lines max observed.
5. **Poster**: full content width (358), own aspect ratio, no corner radius.
6. **Date** (28/500) then **time** (20/400, dimmer), then timezone pills (PT / ET) — left aligned.
7. Action row (public events): "Remind me" pill + icon pills (link, more).
8. **"Hosted by"** row: crown icon + label; then host avatars (48, gap 4) each with a 20 px black crown badge at the
   bottom-right; for an org host, name (16/600) + "{n} upcoming events" + Follow.
9. **Location**: pin icon, place name (16/600), address or "Sign in for full location" (16/400, dimmer).
10. Description (16/400, line height 22.4).
11. **Guest List** (18/700) with counts line "{n} Going · {n} Interested · {n} Maybe" (14/400) and "View all";
    then a row of 48 px avatars (gap 4) ending in a "+{n}" overflow disc.
12. Public only: "Trending This Week" carousel (grey band).
13. **Restricted Access** card over a blurred Activity list: lock (64), "Restricted Access" (18/700), explanation (14/400),
    primary button (RSVP or Sign in), secondary "Remind me", "Already RSVP'd? Sign in".
14. Footer: logo, "Explore events", "Create a free event", links (English, Help, Blog, Careers, About), **"Get the app ↗"**, social icons.
15. Floating: bottom nav (Home, Create, Explore, Profile; 56 tall) and, on public events, the sticky RSVP group above it
    ("👍 RSVP | ☆ Interested"). On link-only events the RSVP control is the emoji sheet (P4).

The page background is the **event's theme**: a full-screen looping `<video>` (y 64–844) over a solid colour; `html`
gets class `ptf-light` or `ptf-dark`, and all text/buttons use alpha-black or alpha-white tokens so they work on any
theme colour. Observed theme colours: `#FBEBE4`, `#A7C8FF`, `#1C0606`, `#2F2F2F`, `#010019`, `#FBE4F2`, `#F7FBE4`,
`#C5DB76`, `#D4D6F1`, `#DE70D6` (body background of 10 pages) — theme-specific, not tokens.

### 5.3 Measured values (VERIFIED unless stated)

| value | element | file / evidence | coords (CSS px) | method | level |
|---|---|---|---|---|---|
| 16 | screen side margin | P6 `--spacing-screen-margin-horizontal:16px`; P1 title/poster/date x 16 | — | CSS + rect | VERIFIED |
| 2/4/8/12/16/24/40 | spacing scale | P6 `--spacing-xx-small … --spacing-xx-large` | — | CSS | VERIFIED |
| 10/12/14/16/18/24/28/40/52 | type scale (mobile) | P6 `--text-x-small-size … --text-xxxxx-large-size` | — | CSS | VERIFIED |
| 1.4 | default line height | P6 `--shared-line-height:1.4`; all body text lh = 1.4 × size | — | CSS + computed | VERIFIED |
| 700 / 700 / 600 / 400 / 400 | weights: display / header / subheader / body / detail | P6 `--text-*-font-weight` | — | CSS | VERIFIED |
| 39 / 700 / lh 46.8 / ls −0.78 (−0.02 em) | event title (26 chars); auto-fits by length: 39, 38, 32, 28, 25 seen | P1 `span.summary`; P2; 9 pages via script | y 229.6, w 323 | computed | VERIFIED |
| PartifulGrotesk (default), Goodman, Snell, Nokja, Manrope, Afacad, LibreBaskerville, Engravers, BootzyTM | title font options (host picks) | P6 font-face names; computed `font-family` on 9 pages | — | CSS + computed | VERIFIED (proprietary → PLATFORM) |
| TWK Lausanne | UI font | computed `font-family: Lausanne, "Helvetica Neue", …` | — | computed | VERIFIED (proprietary → PLATFORM) |
| 358 wide, own aspect, radius 0 | poster | P1 img | x 16, y 345, 358×286 | rect | VERIFIED |
| 28 / 500 / lh 39.2, alpha 0.9 | date | P1 `rgba(0,0,0,.9)`; P2 `rgba(255,255,255,.9)` | y 647 | computed | VERIFIED |
| 20 / 400 / lh 28, alpha 0.5 light / 0.6 dark | time | P1, P2 | y 686 | computed | VERIFIED |
| 48 × 36 pill; selected fill α .15 + 1 px border α .6; unselected fill α .05 | timezone pills | P1, P3 | y 738 | computed | VERIFIED |
| 36 high pill, fill α .05, 1 px border α .25 (light) / .4 (dark), label 14/600, icon 20 | outlined medium button ("Remind me", "View all", "Follow") | P1, P2; P6 `--button-medium-height:36px`, `--button-medium-border-radius:800px` | y 822 | computed + CSS | VERIFIED |
| 48 high, radius 4, label 16/600, h-padding 24 | large button ("RSVP", "Sign in", "Continue") | P1 restricted card; P6 `--button-large-height:48px; --button-large-border-radius:4px` | y 2027 | computed + CSS | VERIFIED |
| `#000` fill / `#FFF` label (light); `#FFF` fill / `#000` label (dark) | filled button colours | P6 `--button-filled-*` | — | CSS | VERIFIED |
| 16/400 α .8 + 20 px crown icon at x 16; text at x 44 | "Hosted by" label | P3 | y 902 | computed | VERIFIED |
| 48 × 48; circle (person) / radius 8 (org); gap 4 | host and guest avatars | P1, P3; P6 `--avatar-medium-size:48px`, `--avatar-group-gap:4px`, `--avatar-medium-square-border-radius:8px` | y 936 / 1182 | computed + CSS | VERIFIED |
| 20 px black disc, 12 px white crown, offset (+31, +31) | host badge | P3 | x 75, y 967 | rect | VERIFIED |
| 48 disc, fill α .1, label 16/400 α .8 ("+10") | avatar overflow | P3 | x 276, y 1182 | computed | VERIFIED |
| 16/600 + 16/400 α .8 | location name + detail | P3 | y 1004 / 1028 | computed | VERIFIED |
| 18 / 700 / lh 25.2 | section header ("Guest List", "Activity", "Restricted Access") | P1, P3 | y 1129 | computed | VERIFIED |
| 14 / 400, α .6 | section detail line (counts — do-not-copy) | P1, P3 | y 1154 | computed | VERIFIED |
| 358 wide, fill `rgba(255,255,255,.7)`, radius 4; lock 64; body 14/400 α .8 centred | Restricted Access card | P1, P3 | y 1340 | computed | VERIFIED |
| 263.7 × 56.4, radius 800, 1 px border, glow `0 0 12px` α .1 (light) / .25 (dark); segments padded 16 × 24; label 16/600; 1 × 16 divider α .6 | sticky RSVP group | P1, P2; P6 `PublicEventRsvpButtonGroup_*` | y 715.6 | computed + CSS | VERIFIED |
| bottom = 16 + nav height (56) | sticky RSVP group offset | P6 `RsvpActions_sticky: bottom: calc(var(--spacing-screen-margin-vertical) + var(--bottom-nav-inset))`, `--nav-button-height:56px` | — | CSS | VERIFIED |
| backdrop blur 45, height 100 on screens ≤720 px (150 wider), hidden when the bottom nav is present (`:root:has(#bottom-nav)`, i.e. on the logged-out pages captured), fill `--inverse-text-color-70` = white α .7 (light) / black α .8 (dark), mask transparent → opaque at 70% | bottom fade behind sticky actions | P6 `RsvpActions_bottomFade` | — | CSS | VERIFIED |
| 96 × 96 circles, white (light) / transparent with border α .25 (dark); emoji 28; label 12/600 | RSVP choice buttons | P4; P6 `--rsvp-button-*` | x 27/147/267, y 24 | computed + CSS | VERIFIED |
| 24 / 400, placeholder α .3 (light) / .4 (dark), underline | sheet inputs (Your Name, Phone Number) | P4 | y 171 / 244 | computed | VERIFIED |
| 14.4 / 400 α .3 | helper "Just for event updates. No spam." | P4 | y 302 | computed | VERIFIED |
| 100 / 150 / 200 / 300 / 600 ms | durations: interaction / quick / theme / default / confirmation | P6 `--animation-duration-*` | — | CSS | VERIFIED |
| 0.8 / 0.6 / 0.4 | hover / active / disabled opacity | P6 `--shared-hover-opacity`, `--shared-active-opacity`, `--shared-disabled-opacity` | — | CSS | VERIFIED |
| `#994CE6` 1 px | "Make your own" pill border | P1 | x 255, y 16 | computed | VERIFIED (upsell; do-not-copy) |

Semantic text alphas (light → dark): display/header/subheader `#000`/`#FFF`; body α .8; detail α .6; inactive α .4
(P6 `--text-body-color`, `--text-detail-color`, `--text-inactive-color`).

### 5.4 Link preview (Open Graph) — VERIFIED from page HTML

| item | value | evidence |
|---|---|---|
| `<title>` / `og:title` / `twitter:title` | "{Event title} \| Partiful" | P1, P3 HTML |
| `meta description` | event description truncated to 155 chars + "…" | P1 (156 chars incl. "…") |
| `og:description` / `twitter:description` | event description (240 chars here, untruncated) | P1 |
| `og:image` for UA `facebookexternalhit/1.1 Facebot Twitterbot/1.0` (Apple Messages/Facebook) | poster at **1200×630, fit=fill, fill=blur** | `references/auto/partiful/og/pf-og-public-crawler-1200x630.jpg` |
| `og:image` for browsers, Twitterbot, Discordbot, curl | poster at own aspect, max 834×666 (public) / 1000×1000 (link-only page) | `og/pf-og-public-browser-834x666.jpg`; P3 HTML |
| `og:image:alt` | "{Event title} Event Cover Image" (public) / image id (link-only) | P1, P3 |
| `twitter:card` | `summary_large_image` | P1 |
| robots (link-only event) | `noindex`, `nofollow` | P3 HTML |
| in-app share preview | title "RSVP to My Birthday", domain "partiful.com" | `store/partiful-store-03.png` (conflicts with og:title format above; in-app link metadata) |

### 5.5 Copy (verbatim) and voice

"Hosted by", "Sign in for full location", "Guest List", "View all", "Restricted Access", "Verify your phone number to
view event details and activity", "Only RSVP'd guests can view event activity & see who's going", "Sign in", "RSVP",
"Remind me", "Already RSVP'd? Sign in", "Going", "Maybe", "Can't Go", "Your Name", "Phone Number", "Just for event updates.
No spam.", "1 attendee", "+Post a comment", "Follow event organizer to stay in the loop", "Cancel", "Continue", "Get the
app", "Explore events", "Create a free event", "Interested", "Login". RSVP flow (help.partiful.com, via lead file 21):
after a response the guest enters name and phone, then a texted code.

Voice: Title Case for labels and buttons ("Guest List", "Restricted Access", "Can't Go"); sentence case with a period
for explanations; ampersand allowed ("view event activity & see who's going"); emoji only as RSVP glyphs and in the
marketing banner. Proposed pattern ids: **P-IW-1 gate explanation** "Verify your phone number to view {things}";
**P-IW-2 reassurance** "Just for {purpose}. No spam."; **P-IW-3 returning-user link** "Already {state}? Sign in".

### 5.6 Do-not-copy (invite.web)

- Guest counts "9514 Going · 7475 Interested · 753 Maybe", "11 Went · 4 Maybe", "+3.3k", "{n} updates", "{n} upcoming
  events", "spots left" (counts; tenet 2).
- "Trending This Week" and "See all in Trending in NYC" (public discovery; we have no public feed).
- "Events can be easy 🕺 / Make your own", "Create a free event" (acquisition upsell on someone else's invite).
- "Interested", "Follow", "Remind me" (public-event follow mechanics; follower model).
- Activity feed timestamps of RSVPs ("rsvped Going 👍 5/19") (performative activity log).
- Partiful logo, PartifulGrotesk, Lausanne, theme videos.

### 5.7 Not found

- An **upcoming link-only (private) event** page with its RSVP buttons in place (private links are not indexed; P3 is
  past, so the RSVP area is replaced by the restricted card). The emoji sheet P4 is the public-event version.
- The page as seen in iOS Safari (Smart App Banner rendering; Chromium does not render `apple-itunes-app`).
- What a signed-in guest sees after RSVP (requires a phone number).

---

## 6. `invite.appclip` — App Clip and app hand-off

### 6.1 Evidence

| item | value | evidence | level |
|---|---|---|---|
| App Clip exists and is bound to the domain | `appclips.apps = ["Z9A649Q6W9.com.partiful.partiful.Clip"]`; `applinks` include `/e/*` (and exclude `/e/*/promoter_dashboard/*`) | https://partiful.com/.well-known/apple-app-site-association (fetched 2026-10-15) | VERIFIED |
| Smart App Banner with App Clip | `<meta name="apple-itunes-app" content="app-id=1662982304, app-clip-bundle-id=com.partiful.partiful.Clip">` on every `/e/` page | P1, P2, P3 HTML | VERIFIED |
| Android hand-off | `assetlinks.json` → `com.partiful.partiful` (`delegate_permission/common.handle_all_urls`) | https://partiful.com/.well-known/assetlinks.json | VERIFIED |
| App Clip card in Messages | header image (event poster on blurred backdrop) with "partiful.com" domain chip; footer: app-clip icon, **title** "Book Club", **subtitle** "Make memories", blue **"View"** button | `references/auto/partiful/store/partiful-store-04.png` (crop y 1400–2688) | SOURCED |
| Share sheet in the app | "Share Link" / "Anyone with the link can RSVP"; preview card "RSVP to My Birthday" / "partiful.com"; targets Copy Link, Messages, WhatsApp, More | `references/auto/partiful/store/partiful-store-03.png` | SOURCED |
| App Store marketing line | "Send your invite by text, DM, email, or sharable link. No app needed to RSVP" | `store/partiful-store-03.png` | SOURCED |
| listing copy | "Invite anyone with a link — guests don't need the app! One link works for both Apple and Non-Apple users, and you can track RSVPs in real time." | `store/listing.html` (v3.10.09) | SOURCED |

The App Clip's own screens (what opens after "View") were **not found** — App Clips cannot be launched here. App
Clip card limits (header image size, title/subtitle length) belong to Apple HIG (other pass); not verified here.

### 6.2 Copy

Verbatim usable: "View" (App Clip action; one of Apple's preset verbs), "Anyone with the link can RSVP" (pattern for
our "Anyone with the link can join"), "Copy Link", "Share Link". Do-not-copy: "track RSVPs in real time" (counting).

---

## 7. Summary per surface

| surface | status | basis |
|---|---|---|
| `invite.web` | **fully sourced** for structure, type scale, spacing, radii, button/avatar specs, semantic colours, durations, OG format (VERIFIED from live pages + production CSS) | gaps: private upcoming state, iOS Safari banner |
| `invite.appclip` | **partly sourced**: association, banner meta, Messages card anatomy and copy; App Clip screens not found | — |
| `year.story` | **sourced with approximations**: progress-bar geometry (3 images, ±0.3–0.5 pt; side-inset conflict), fill timing and easing, text reveal motion, 2025 paging/coach motion, type sizes via cap-height matching (font PLATFORM), share pill; tap zones and pause gesture **not found** | — |
| `birthday.request` | **sourced (layout + copy)**; sizes VERIFIED only for Tribute's legacy page; VidDay sizes approximated from its tour video (±1.5 pt); Tribute's own email text **not found** | — |
| `birthday.contribute` | **copy and limits sourced**; screens partly (Tribute step 1 VERIFIED); recorder/upload screens **not found** | — |
| `birthday.tribute` | **structure and transitions sourced** (hard cuts; title card + 0.6 s crossfade; pillarbox); per-contribution caption layout, photo hold, music timing **not found** | — |

## 8. Smallest owner captures that would close the gaps

1. `year.story`: one 30-second iPhone screen recording (Settings → Accessibility → Touch → AssistiveTouch "show touches" or a second phone filming) of tapping through any Instagram-style story player **in Spotify Wrapped's "Your Stories" replay** with taps on left, right and a press-and-hold — settles tap zones and hold-to-pause.
2. `invite.web`: one link to any **upcoming private Partiful invite** the owner has received (or a 10-second recording of opening it logged out on iPhone Safari) — settles the private RSVP state and the Smart App Banner.
3. `invite.appclip`: one 15-second iPhone recording of tapping that Partiful link in Messages (App Clip card → clip opening).
4. `birthday.request`/`contribute`: forward one real Tribute or VidDay **invitation email/SMS** the owner received, plus a 30-second phone recording of opening it and reaching the recorder (no need to submit).
5. `birthday.tribute`: one finished birthday Tribute or VidDay link (any length) the owner has — settles title card, captions, photo hold and end card.
