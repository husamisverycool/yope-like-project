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
