# Yope, research pass B (`yope-b`): chat, photo viewer, walls, recaps, share, collage composition

Researcher: agent yope-b · date: 2026-10-15 · reference app: **Yope** (App Store id1600195477,
listing version 1.229.0 of 2026-10-01; Google Play `app.salo`, updated 2026-09-29).
Surfaces: `chat.thread`, `chat.composer`, `chat.voice`, `photo.viewer` (Yope parts), `walls.mine`,
`walls.member`, `walls.browse`, `week.recap`, `week.edit`, `albums.list`, `albums.view`, `collage.share`,
plus the **collage composition facts** for `collage.view`.

Machine-readable output: `design/proposals/yope-b.tokens.json`, `design/proposals/yope-b.copy.json`.
Images: `references/auto/yope/frames/b-*` (rows appended to `references/auto/yope/INDEX.md`).

---

## 0. Sources

| id | file (repo-relative unless noted) | origin | date / version | level |
|---|---|---|---|---|
| S1 | `references/auto/yope/store/yope-store-05.png` (1242×2688 PNG) | App Store screenshot 5, group chat ("react. talk. go chaotic.") | listing 1.229.0 | SOURCED |
| S1r | `references/auto/yope/frames/b-derot-store-05-rot-1.68.png` | S1 rotated −1.68° (PIL `rotate(-1.68, BICUBIC, center=(621,1344))`) so the phone is upright; **all S1 coordinates below are in S1r** unless marked "orig" | derived | SOURCED |
| S2 | `references/auto/yope/store/yope-store-04.png` | App Store screenshot 4, recap scrapbook ("your life = daily & monthly recaps") | listing 1.229.0 | SOURCED |
| S2r | `references/auto/yope/frames/b-derot-store-04-rot-3.65.png` | S2 rotated −3.65° about (621,1344) | derived | SOURCED |
| S3 | `references/auto/yope/frames/b-play-03.png`, `b-play-04.png`, `b-play-05.png` (1080×1920) | Google Play screenshots 3–5 (`https://play-lh.googleusercontent.com/<id>=w2560`, ids in INDEX) | Play listing updated 2026-09-29 | SOURCED |
| S3r | `references/auto/yope/frames/b-derot-play-05-rot+3.3.png` | Play 5 rotated +3.3° about (540,960) | derived | SOURCED |
| S4 | `references/auto/yope/frames/b-presskit-wall.png`, `b-presskit-profile.png` (804×1748 = 402×874 pt @2x, i.e. an iPhone 16 Pro screen) | Yope press kit `https://yope.app/assets/press/yope-press-kit.zip` (files dated 2026-07-22; "logos, icons & product shots — free to use with attribution to Yope") | Jul 2026 | SOURCED |
| S4g | press kit `wall.gif` (1000×2167, 36 frames), `splitview.gif` (51 frames) — kept in `/tmp`, not committed (13–29 MB) | same zip | Jul 2026 | SOURCED |
| S5 | TikTok @yopeapp `https://www.tiktok.com/@yopeapp/video/7591560669967682847` (720×1280, 30 fps, 122.7 s), frames `b-yopeapp-7591560669967682847-t*.png` | official account; screen recordings composited over a presenter | posted 2026-01-04 (screens show Dec 2025 content) | SOURCED |
| S6 | TikTok @alexaa.yope `https://www.tiktok.com/@alexaa.yope/video/7652512140875566349` (720×1280, 30 fps), frames `b-alexaa-*` | creator | 2026-06-17 (screens dated "26 May") | SOURCED |
| S7 | TikTok @yrrah.yope `https://www.tiktok.com/@yrrah.yope/video/7673901254787009810` (1080×1920, 25 fps), frame `b-yrrah-*` | creator | 2026-08-14 | SOURCED |
| S8 | TikTok @itsaubreyyope `https://www.tiktok.com/@itsaubreyyope/video/7521021527354068255`, frame `b-itsaubrey-*` | creator; exported walls | 2025-06-28 (older than 12 months; used only for export watermark placement) | SOURCED |
| O1 | `references/owner/yope-04-chat.webp` | owner INSPO, same panel as S1 at 460×996 (not independent of S1) | — | CAPTURED |
| O2 | `references/owner/yope-03-recaps-collage.webp` | owner INSPO, same panel as S2 | — | CAPTURED |
| O3 | `references/owner/yope-week-recap.jpg` (540×960; screen 442.5 px wide → 0.888 pt/px) | owner TikTok frame, week recap | ~Dec 2025/Jan 2026 (overlay text "…in 2026") | CAPTURED |
| O4 | `references/owner/yope-1on1-feed.jpg`, `yope-1on1-feed-2.jpg` (same scale as O3) | owner TikTok frames, 1:1 space | same video as O3 | CAPTURED |
| O5 | `references/owner/yope-01-find-friends-profile.webp` | owner INSPO, profile panel | — | CAPTURED |
| W1 | `references/auto/yope/store/listing.html` | App Store listing: description + version history (verbatim release notes) | fetched 2026-10-15 | SOURCED |
| W2 | `https://yope.app/` and `https://yope.app/press` | marketing site, press page | fetched 2026-10-15 | SOURCED |

False lead logged: `https://www.tiktok.com/@hachishigatsu/video/7582174535005310215` is a **Locket** recap
(captions "#locket", every card labelled "LOCKET"), not Yope. Not used.
Other videos downloaded and checked but not used for values: @yopeapp 7629132041472232734 (no app UI),
@yopeapp 7562212814845152543 (no app UI), @yrrah.yope 7588595583561043207 (iPad filmed at an angle, Wrapped 2025;
too oblique to measure), @yrrah.yope 7648314950217157896 (no readable UI). @yrrah.yope 7570368488167050504:
"Your IP address is blocked from accessing this post".

### Scale conventions
- **S1/S2 (store 1242×2688):** phone screen measured in the de-rotated image: S1r screen x 169.7–1054.6 =
  **884.9 px**, y ≈616–2531 (ratio 2.164); S2r screen x 166.5–1053 = 886.5 px. Assumed **393 pt** wide
  (brief default) → S1 1 pt = 2.252 px. The 2.164 ratio fits 390/393/414/428/430-pt devices equally, so a
  systematic −1 %/+9 % scale uncertainty exists on top of the stated measurement precision.
  **Cross-check:** header buttons measure 43.5 pt in S1 and 44.3 pt in S6 (June 2026 screen recording, a
  different device), which supports the 393-pt assumption.
- **S5 (TikTok 720×1280):** phone screen overlay x 95.5–623.5 = 528 px → 0.744 pt/px at 393.
- **S6:** screen inside the creator's lime frame x 72–648 = 576 px → 0.682 pt/px.
- **O3/O4:** screen x 48.5–491 = 442.5 px → 0.888 pt/px.
- **S4:** 804 px = 402 pt → pt = px/2 (exact device size; no assumption needed).
- **S3 (Play 5):** S3r screen x 170.1–939.5 = 769.4 px → 0.511 pt/px at 393.

### Methods
- Colors: median of a box in the **original-resolution PNG** (S1 orig or S1r for flat areas; std ≈0 confirms
  flat). JPEG/video colors are flagged ±6/255.
- Edges: subpixel crossing of the half-way luminance between background and element along a row/column
  (`scan`, `span` scripts), corner radii by least-squares fit of the circular inset curve along the
  edge (`corner` script). Text sizes: measured x-height or cap/digit height; converted to a point size using
  SF Pro's ratios (x-height ≈0.526 em, cap height ≈0.705 em) because the build renders with the platform
  font (PLATFORM): the SF size that reproduces the measured glyph height reproduces the reference.
- Motion: frames extracted at native rate with `ffmpeg -frame_pts 1`; time = pts/30 for S5.

---

## 1. `chat.thread` (Yope group chat)

**Reference images:** S1 (group chat, primary), S3 `b-play-04.png` (same design re-rendered by Yope for Play;
not independent), O1 (same panel, owner), S5 t48.50 / t49.00 / t49.50 (1:1 space chat, Dec 2025, independent),
O4 (1:1 space, independent), S6 t5.83 (June 2026 group screen with "chat" pill + header).

### Layout (S1, top to bottom)
1. **Header** floating over content: ‹ in a 44-pt circle (left) · capsule [group avatar · name · streak pill ·
   ›] · film-strip glyph circle (right; the same glyph labels "view recap" in S6, so it opens the group's
   recaps). (S6 adds a calendar-glyph circle left of the film-strip circle.)
2. **Photo messages**: landscape-cropped photos with large rounded corners, the post's **time** ("10:00 PM")
   centred on the photo in bold white. Sender avatar sits **outside** the photo, bottom-left, aligned with
   the photo's bottom edge (first photo in S1).
3. Under a photo: a dark **reaction capsule** containing emoji + reactor avatar (no number).
4. **Text bubbles**: pill-shaped, dark gray, white text. Theirs: left-aligned after an avatar column;
   avatar shown only beside the **last** bubble of a run ("strictly vibes only tonight" + "valid" = one run,
   avatar beside "valid", bottom-aligned with it). Mine: right-aligned, **no colour difference** except a
   slightly darker gray. No tails.
5. **Emoji-only message**: rendered large, no bubble (👈👈👈 row beside an avatar).
6. **Voice message** (mine): wide rounded bubble with ▶ circle, gray waveform, "00:38".
7. **Composer** pinned at bottom (see `chat.composer`).
8. Cut-out person stickers float over the thread (**do-not-copy**: stickers are on the do-not-build list).

No day separators or timestamps are visible in S1. In the **1:1 space** (S5 t48.0–49.5, Dec 2025) the
thread is a sheet over the space's wall; photo cards show a **time pill** top-right ("6:36 PM"), an
optional caption in a translucent dark rounded box bottom-left ("Chloe and grandpa"), and a ♡ pill under the
photo's bottom-right corner; **month** ("december 2025") and **week** ("21-27 dec") labels are drawn as big
bold white lowercase text over the top-left of the first photo of that period (S5 t48.00, t49.00).

### Reply to a specific photo (S5 t49.50, `b-yopeapp-…-t49.50-reply-to-photo.png`)
A reply is **one bubble with two stacked parts**: an upper **lime** quote block containing a 1.5-pt black
vertical quote bar, the original poster's name in bold ("Gabriel"), the word "pic" (regular) under it, and a
square thumbnail of the photo at the right; and a lower dark part holding the reply text ("🥹"). Sender avatar
bottom-left outside; the message time ("8:47 PM") sits outside the bubble, right of its bottom edge.

### Measured values

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| #171717 | thread background | S1 orig | (600,2250),(800,2150),(400,2000) 15×15 | median, std 0 | ±1/255 | SOURCED |
| #171717 (L 23) | 1:1 sheet background | S5 t49.50 | (100–620, 500–1150) row scans | luminance plateau 23 | ±3/255 (video) | SOURCED |
| #181619 | 1:1 sheet background | O4 `yope-1on1-feed.jpg` | (100,480) 7×7 | median | ±6/255 (JPEG) | CAPTURED |
| #2B2B2B | theirs bubble fill ("valid") | S1r | (350,1560),(350,1615) 5×17 | median | ±2/255 | SOURCED |
| #232323 (#222222–#242424 top→bottom) | mine bubble fill ("no way") | S1r | (900,1820),(900,1875) 5×17 | median | ±2/255 | SOURCED |
| #404040 peak | bubble rim (1 px light stroke, brighter at top; bottom rim #323232–#393939) | S1r | col 350 y 1548; col 880 y 1808 | column profile | ±6/255 | SOURCED |
| #FFFFFF | message text | S1r | glyph cores in "valid" (col 370 y 1586–1595 = 255) | profile | exact | SOURCED |
| 35.6 pt (80.2 px) | single-line bubble height | S1r | valid y 1546.8–1627.2; no way 1806.8–1887.0 | subpixel crossing | ±0.5 pt | SOURCED |
| 16 pt (15.4–16.0; 34.6/36.0 px) | bubble corner radius (≈ capsule: h/2 = 17.8) | S1r | valid TL (283.5,1546.8); no-way TR (1002.7,1806.8) | circle fit | ±1.5 pt | SOURCED |
| 59.2 pt (133.3 px) | "valid" bubble width | S1r | x 283.5–416.8 at y 1587 | crossing | ±0.5 pt | SOURCED |
| 77.7 pt (175 px) | "no way" bubble width | S1r | x 827.5–1002.5 at y 1847 | crossing | ±0.5 pt | SOURCED |
| 210.7 pt (474.5 px) | widest bubble seen ("strictly vibes only tonight", one line) | S1r | x 284.1–758.6 at y 1500 | crossing | ±0.5 pt | SOURCED |
| 11.5 pt (≈25–27 px each side) | horizontal text padding | S1r | no-way text x 857–971 in bubble 827.5–1002.5 | glyph extents (includes side bearings) | ±1 pt | SOURCED |
| 8.9 pt (20 px) | message x-height → **17 pt** | S1r | "no way" rows 1841–1860; "valid" 1581–1600 | glyph rows | ±0.5 pt → ±1 pt size | SOURCED |
| 23.0 pt (51.9 px) | mine bubble right inset from screen edge | S1r | 1054.6 − 1002.7 | difference | ±0.5 pt | SOURCED |
| 50.5 pt (113.8 px) | theirs bubble left inset (= avatar inset + avatar + gap) | S1r | 283.5 − 169.7 | difference | ±0.5 pt | SOURCED |
| 32.6 pt (73.5 px) | sender avatar diameter | S1r | x 195–268, y 1556–1628 ("valid"); y 1700–1773 (emoji row) | row/col scan | ±0.5 pt | SOURCED |
| 11.2 pt (25.3 px) | avatar left inset | S1r | 195 − 169.7 | difference | ±0.5 pt | SOURCED |
| 6.7 pt (15 px) | avatar → bubble gap | S1r | 283.5 − 268 | difference | ±0.5 pt | SOURCED |
| bottom-aligned | avatar vs. last bubble | S1r | avatar bottom 1628, bubble bottom 1627 | — | ±0.5 pt | SOURCED |
| 3.6 pt (8 px) | gap between consecutive bubbles, same sender | S1r | "strictly" bottom 1539 → "valid" top 1547 | profile | ±0.5 pt | SOURCED |
| 4.7 pt (10.5 px) | gap text bubble → voice bubble, same sender | S1r | 1887 → 1897.5 | profile | ±0.5 pt | SOURCED |
| ≈15 pt (34 px) | gap between sender runs (avatar bottom 1773 → next bubble top 1806.8) | S1r | — | difference | ±1 pt | SOURCED |
| 323 pt × 174 pt (727 × 392 px) | photo message (theirs) size; aspect 1.86 | S1r | x 285–1012.5, y 963.5–1355.5 | edge scans | ±0.5 pt | SOURCED |
| 18.7 pt (42 px) | photo message right inset | S1r | 1054.6 − 1012.5 | difference | ±0.5 pt | SOURCED |
| 15 pt (33–34.5 px) | photo message corner radius | S1r | BR (1012.5,1355.5); TR (1012.5,963.5) | circle fit | ±1 pt | SOURCED |
| 15.3 pt (34.5 px) | gap between consecutive photos | S1r | photo 1 bottom 929 → photo 2 top 963.5 | col scan | ±0.5 pt | SOURCED |
| 14.9 pt (33.5 px) cap height → **21 pt**, bold/heavy (stem/cap ≈0.24), white | photo time overlay "10:00 PM", centred in photo | S1r | glyph rows 1143–1176, x 536–774 (centre 655 vs photo centre 649) | glyph rows | ±1 pt | SOURCED |
| 24 pt (54 px); gap 6.7 pt under photo | reaction capsule height / spacing | S1r | y 1370.5–1424.5; photo bottom 1355.5 | col 480 profile | ±0.5 pt | SOURCED |
| #2C2C2C (L 44) | reaction capsule fill | S1r | col 480 y 1372–1379 | profile | ±3/255 | SOURCED |
| ≈47.5 pt (107 px) glyph width | emoji-only message emoji size | S1r | 👈 yellow bbox x 287–393 | colour mask | ±3 pt | SOURCED |
| 43.5 pt (98 px) | header circle buttons (‹, film strip) | S1r | ‹ x 195.5–293.5, y 688.3–786.3; right x 931.5–1028.5 | crossing | ±0.5 pt | SOURCED |
| 44.3 pt (65 px @0.682) | header circle (June 2026) | S6 t5.83 | ‹ x 89–153 at y 123 | run scan | ±1 pt | SOURCED |
| 43.3 pt × 223 pt | header capsule (name-dependent width) | S1r | x 310–812.5, y 688.5–786 | crossing | ±0.5 pt | SOURCED |
| 11.5 pt (25.8 px) | header side inset | S1r | 195.5 − 169.7; 1054.6 − 1028.5 = 26.1 | difference | ±0.5 pt | SOURCED |
| 7.3 pt (16.5 px) | gap ‹ circle → capsule | S1r | 293.5 → 310 | difference | ±0.5 pt | SOURCED |
| #131313 | header circle fill over black (June 2026) | S6 t5.83 | (100,110),(140,135) 5×5 | median | ±3/255 | SOURCED |
| #2A2A2A → #333333 (top→bottom) | header circle fill over photo (translucent) | S1r | col 245 y 692–783 | profile | ±3/255 | SOURCED |

**1:1 space, Dec 2025 (alternative values, independent of S1):**

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| 244 pt × (photo) ; right inset 15.6 pt | mine photo card width | S5 t49.50 | x 274.5–602.5; screen right 623.5 | row scan ×0.744 | ±1 pt | SOURCED |
| 16.5 pt (22.2 px) | photo card radius | S5 t49.50 | TR (602.5,668.5), TL (274.5,668.5) | circle fit | ±1.5 pt | SOURCED |
| 19 pt (21.5 px ×0.888) | photo card radius | O4 `yope-1on1-feed.jpg` | TL (65.5,508.5), TR (473.5,508.5) | circle fit | ±1.5 pt | CAPTURED |
| 362 pt, insets 15.5 pt | photo card width (full width) | O4 | x 65.5–473.5 | row scan | ±1 pt | CAPTURED |
| 66.6 × 28 pt; translucent dark (#4F4A47 over photo) | time pill on photo, top-right | O4 | x 381–456, y 525–557 | scan | ±1.5 pt | CAPTURED |
| ≈46 × 34 pt, fill #211F22, dark 1-px outline | ♡ pill straddling photo's bottom edge, right-aligned | O4 | x 421–473, y 454–490 | scan | ±2 pt | CAPTURED |
| 142 pt wide; lime part 64 pt tall; dark part 36 pt | reply-to-photo bubble | S5 t49.50 | x 171.5–362, lime y 523–609.5, dark 610–658.5 | col 250 profile | ±1 pt | SOURCED |
| #D2FC09 | reply quote block fill | S5 t49.50 | (200,540) 5×5 | median | ±6/255 (video) | SOURCED |
| #444145 (L 67) | reply text part fill (1:1, Dec 2025) | S5 t49.50 | (250,640) | median | ±6/255 | SOURCED |
| 1.5 pt (2 px) black, inset 16 pt | quote bar | S5 t49.50 | x 193–194 at y 560 | row profile | ±0.7 pt | SOURCED |

### Copy (verbatim)
- "10:00 PM" (photo time format `h:mm AM/PM`) — S1. "8:47 PM", "1:29 PM", "6:36 PM" — S5.
- "pic" (reply-quote label for a photo) and the quoted poster's first name "Gabriel" — S5 t49.50.
- "december 2025" (month label), "21-27 dec" (week label) — S5 t48.00 / t49.00.
- "chat" (pill that opens the chat from the group's photo cards) — S6 t5.83 and S4g `splitview.gif`.
- Message content in S1 ("strictly vibes only tonight", "valid", "no way") is user content, not UI copy.

### Do-not-copy
- Streak pill in the header capsule ("🔥451" S1, "🔥264" store-01, "🔥0" S5, lime "🔥5" S6/O4).
- Cut-out person stickers placed over the thread (S1); stickers are do-not-build.
- `chat.reactions` belongs to Locket per SURFACES.md; the Yope reaction capsule is recorded only for layout context.

### Not found (`chat.thread`)
- Max bubble width (only one-line bubbles seen; widest 210.7 pt). Multi-line bubble layout/line height.
- Corner changes for grouped bubbles (all bubbles are uniform capsules in S1).
- Day separators / date headers inside the **group** chat (none in S1; only 1:1 month/week overlays in S5).
- Message status (sent/read), long-press menu, failed-send state.
- Tried: App Store/Play screenshots, press kit, 9 TikToks; the official @yopeapp profile grid could not be
  listed (TikTok "Something went wrong" for anonymous browsing; yt-dlp user extraction returned no entries).

---

## 2. `chat.composer`

**Reference images:** S1 (group chat, "start typing..."), S3 `b-play-04.png` (same design), S5 t48.50
(1:1, "message..."), O4 (1:1, "message..."), O5 (profile, "message to Sabrina...."), S5 t57.07 (viewer,
"message to Oblong").

### Layout
- **Group chat (S1):** [lime circle with black camera glyph] [capsule text field "start typing..."]
  [dark circle with a sticker glyph] [dark circle with mic glyph]. All four share one centre line; equal
  heights (≈40 pt).
- **1:1 space (S5 Dec 2025):** [dark circle sticker glyph] [capsule "message..." with ❤️ 😂 🔥 quick
  reactions inside its right end] [dark circle with camera glyph]. **O4:** lime camera circle at the left
  instead, same field. So the lime camera position changed between builds; S1 (left, lime) is the group-chat
  reference.

### Measured values

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| 40.6 pt (91.5 px) | lime camera button diameter | S1r | x 221–312, y 2394–2484 | run scan | ±0.5 pt | SOURCED |
| #CDFD07 | lime camera fill | S1r | (240,2420),(300,2460) 5×5 | median, std <1 | ±2/255 | SOURCED |
| black (L≈0) | camera glyph on lime | S1r | glyph pixels inside button | visual + profile | — | SOURCED |
| 39.5 pt (89 px) | text field height (capsule) | S1r | col 559 y 2395–2484 | run scan | ±0.5 pt | SOURCED |
| 206.5 pt (465 px) | text field width (flexes) | S1r | x 327–791 | run scan | ±0.5 pt | SOURCED |
| 19 pt (42.8 px) | field corner radius (≈ h/2 → capsule) | S1r | TL (327,2395) | circle fit | ±1.5 pt | SOURCED |
| #2E2E2E (#2C2C2C top → #313131 bottom) | field fill | S1r | (700,2405/2440/2475) 5×5 | median | ±2/255 | SOURCED |
| 1–2 px light rim (#535353 peak top, #474747 bottom) | field stroke | S1r | col 559 y 2395–2396, 2481–2482 | profile | ±6/255 | SOURCED |
| #A3A3A3 | placeholder text colour | S1r | brightest 10 % of glyph px in x 340–600, y 2405–2475 | median | ±6/255 | SOURCED |
| 8.9 pt (20 px) x-height → **17 pt** | placeholder size | S1r | rows 2432–2451 | glyph rows | ±1 pt | SOURCED |
| 39.5 pt (89 px) | sticker / mic button diameter | S1r | x 808–896 / 914–1002; y 2394–2484 | run scan | ±0.5 pt | SOURCED |
| #3F3F3F (#3E3C3D–#3F3F3F) | sticker / mic button fill | S1r | (830,2470),(935,2470) | median | ±2/255 | SOURCED |
| white | mic / sticker glyphs | S1r | col 958 y 2414–2460 L 245–255 | profile | — | SOURCED |
| 6.2 / 7.1 / 7.5 pt (14 / 16 / 17 px) | gaps camera→field, field→sticker, sticker→mic | S1r | 312→327, 791→808, 896→914 | differences | ±0.5 pt | SOURCED |
| 22.8 pt / 23.4 pt | left / right inset of composer row | S1r | 169.7→221; 1002→1054.6 | differences | ±0.5 pt | SOURCED |
| 21.3 pt (48 px) | field bottom → screen bottom (marketing mock, no home indicator drawn) | S1r | 2483 → 2531 | difference | ±1 pt | SOURCED |
| **49 pt** (66 px ×0.744) | 1:1 composer height (all three controls) | S5 t48.50 | x 117–182 / 190–530 / 537–602, y 1088–1152 | run scans | ±1 pt | SOURCED |
| 50.6 pt / 48.8 pt | 1:1 lime camera / field height | O4 | x 65–120, y 855–911 / 856–910 | run scans | ±1 pt | CAPTURED |
| #D1FF17 | lime (JPEG) | O4 | (80,883) 5×5 | median | ±6/255 | CAPTURED |

**Conflict:** composer height 40 pt (S1 group chat, marketing render) vs 49–51 pt (1:1 space, S5 and O4).
Both are Yope; different screens/builds. S1 is the group-chat reference; flag for reconciliation.

### Copy (verbatim)
"start typing..." (S1 group chat) · "message..." (S5, O4 1:1) · "message to Oblong" (S5 t57.07 viewer) ·
"message to Sabrina...." (O5, four dots, verbatim).

### Not found
Typing state (send button replacing mic?), attachment picker, camera-from-chat flow, keyboard-up layout.

---

## 3. `chat.voice`

**Reference images:** S1 (playback bubble), S3 `b-play-04.png` (same design), O1. **Only one independent
design source**; the release note W1 1.212.x confirms the feature ("send voice messages in chat").

### Layout (S1, mine, right-aligned)
Rounded bubble (not a full capsule): [▶ in a dark circle] [waveform of vertical gray bars, same baseline
centre] [duration "00:38", gray, semibold, right]. Same fill as a mine text bubble.

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| 44.9 pt (101 px) | voice bubble height | S1r | y 1897.5–1998.5 (col 980) | crossing | ±0.5 pt | SOURCED |
| 271.8 pt (612 px) | voice bubble width for a 0:38 message | S1r | x 390.9–1002.9 at y 1950 | crossing | ±0.5 pt | SOURCED |
| 14 pt (31.7 px) | voice bubble radius | S1r | TR (1002.9,1897.5) | circle fit | ±1.5 pt | SOURCED |
| #222222 | voice bubble fill (= mine bubble) | S1r | col 400 y 1903–1910 (L 33–34) | profile | ±2/255 | SOURCED |
| 31.5 pt (71 px) | play button diameter | S1r | x 408.5–479.5, y 1912.5–1983.5 | crossing | ±0.5 pt | SOURCED |
| 8.0 pt / 6.7 pt | play button left / top inset in bubble | S1r | 390.5→408.5; 1897.5→1912.5 | differences | ±0.5 pt | SOURCED |
| #313131 (L 46–53 gradient) + light rim | play button fill | S1r | col 445 y 1916–1936, 1958–1980 | profile | ±4/255 | SOURCED |
| white, 11.5 pt wide | ▶ glyph | S1r | x 433–458, y 1939–1956 | L = 255 run | ±0.5 pt | SOURCED |
| 3.1 pt (7 px) | waveform bar width | S1r | row 1948 runs 607–613, 620–626 … | run scan | ±0.5 pt | SOURCED |
| 6.1 pt (13.75 px) | waveform bar pitch (≈3 pt gap) | S1r | 607→620→634→648→662 | run starts | ±0.3 pt | SOURCED |
| 31.5 pt (71 px) max; also 21.5, 18.6, 9.3 pt | waveform bar heights (rounded ends) | S1r | e.g. x 620 y 1913–1983; x 607 y 1921–1969 | col scans (bars not covered by stickers) | ±0.5 pt | SOURCED |
| #919191 | waveform bar colour | S1r | row 1948 bar centres (145) | median | ±3/255 | SOURCED |
| 8.3 pt (18.5 px) digit height → **12 pt** semibold | duration text "00:38" | S1r | rows 1938–1957, x 907–983 | glyph rows | ±1 pt | SOURCED |
| #949494 | duration colour | S1r | glyph px > 140 | median | ±3/255 | SOURCED |
| 8.9 pt / 9.7 pt | last bar → text gap / text → bubble right edge | S1r | 887→907; 983→1002.9 | differences | ±0.5 pt | SOURCED |

Duration format: `mm:ss` with leading zero ("00:38").

**Not found:** recording UI (hold-to-record vs tap, lock, cancel, live waveform, timer), playback progress
colour, playing state (pause glyph), voice note attached to a photo ("add voice to your memories", W1),
theirs voice bubble. Smallest capture: 15-s screen recording of recording, sending and playing a voice
message in a Yope group chat.

---

## 4. `photo.viewer` (Yope parts)

**Reference images:** S5 t57.07 (viewer), S5 t57.20/57.30/57.40 (swipe between photos), O4 (♡ pill and time
pill on feed cards). Only **one** independent full-screen viewer source → approximated.

### Layout (S5 t57.07, Dec 2025)
Top bar: ✕ (left) · two-line centred title: "you" (white bold) "sent to" (gray) "Oblong" (white bold), and
under it the date "Oct 30 2025" (gray) · ••• (right). Below: the photo, full screen width, rounded top
corners, overlaid with the sender avatar + "you" + streak pill (top-left; **do-not-copy** streak) and a
"✂ create sticker" chip (top-right; stickers are do-not-build). Bottom: the reply composer (sticker circle ·
"message to Oblong" field · camera circle), dimmed. Horizontal swipe moves to the adjacent photo (see §10).
Save/download and heart were **not observed in the viewer** (the ••• menu was never opened). In the 1:1 feed
(O4, S5) each photo has the ♡ pill under its bottom-right corner; a floating ↓ circle stays fixed bottom-right
above the composer while the list scrolls (S5 t49.00 vs t49.50), so it is **not** a per-photo save button;
its function is unverified.

Copy (verbatim): "you sent to Oblong" → pattern "you sent to {name}"; "Oct 30 2025" (date format `Mon D YYYY`);
"message to Oblong".

**Not found:** caption display in the viewer, save/download action, ♡ in the viewer, close gesture/animation,
open animation from the thread. Smallest capture: 10-s recording: tap a photo in a Yope group chat, swipe to
the next, open •••, close.

---

## 5. `walls.mine`, `walls.member`, `walls.browse`

**What a wall is in Yope (2026):** "recaps are now walls / edit them, remix them, make your own memory albums /
save it or share it with your friends" (W1, v1.214.0, 2026-04-06). A wall is a full-bleed **9:16 collage
canvas** of the photos posted to a space; posting to a group is "sent a pic to the wall" (S7 t11.30, Live
Activity, Aug 2026).

**Reference images:** S4 `b-presskit-wall.png` (wall editor, Jul 2026), S4 `b-presskit-profile.png` (profile
"pics" grid, Jul 2026), S3 `b-play-05.png` / S3r (profile grid of walls), S3 `b-play-03.png` and S2 (wall
recap scrapbook), S5 t52.00 (1:1 space: wall behind the chat sheet), S5 t116.00 / t118.00 ("me & friends"
wall browser), S8 (exported walls, 2025).

### Layout
- **walls.mine / profile (S4 profile, S3 Play 5):** profile header (cut-out photo, name, handle/"customize
  profile") then either a **"pics ›" 3-column photo grid** (S4, Jul 2026) or a **2-column grid of wall
  thumbnails** (S3, Play listing). Both are vertical scrolls on a dark background.
- **walls.member (S5 t52.00):** in a 1:1 space the other person's/our shared wall fills the screen; the chat
  sheet collapses to a header strip (avatar + name) at the bottom; two floating circles at the right edge
  (camera, share ↗).
- **walls.browse (S5 t116.00, Dec 2025):** title "me & friends"; a horizontal row of circles: first a yellow
  circle with the recap/stack glyph labelled "friends..." (truncated), then member avatars with a red dot
  (new) labelled by first name ("Meera", "Our ban...", "María", "Maddi"); below, the selected wall fills the
  width and scrolls vertically; a label "friends wall" with the stack glyph sits top-left of the wall
  (t118.00, legible at low resolution); right-edge floating circles (camera, share ↗); tab bar at bottom.
- **Wall editor (S4 wall.png):** canvas on top, a black toolbar of 7 circular buttons: photo, "Aa" text,
  sticker, colour dot (lime), cut-out person, music ♪, shuffle (remix). A music chip "♪ Breathe | ✕" at the top.

### Measured values (see also §8 Collage composition facts)

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| 9:16 (804 × 1430 px = 402 × 715 pt) | wall canvas in editor, full screen width | S4 wall.png | x 0–804, y 123–1553 | alpha/edge scan; 804×16/9 = 1429.3 | ±1 px | SOURCED |
| 61.5 pt (123 px) | canvas top (below status bar) | S4 wall.png | y 123 | col scans x=100/400/700 | ±0.5 pt | SOURCED |
| ≈20 pt (≈40 px) | canvas corner radius (all four) | S4 wall.png | BL inset 25 px at 2.5 px from edge → 0 at 32.5 px | circle model fit by hand | ±2 pt | SOURCED |
| 40 pt (80 px) circles, pitch 52 pt (104 px) | editor toolbar buttons (7) | S4 wall.png | row 1640 runs 51–130, 155–234 … 675–754 | run scan | ±1 pt | SOURCED |
| #000000 / button fill #262120 | toolbar background / button fill | S4 wall.png | (20,1640); (62,1621) | median | ±3/255 | SOURCED |
| #CDFE08 | lime colour dot and lime cut-out outlines | S4 wall.png | all lime-mask px | median | ±2/255 | SOURCED |
| 2 columns, tiles 185 × 329 pt (9:16), gap 5.6 pt, side insets 8.5 pt, radius ≈15 pt | profile grid of wall thumbnails | S3r Play 5 | tiles x 186.5–549.5 / 560.5–922.5, y 1081.5–1725.5; next row 1736 | crossing ×0.511 pt/px | ±1 pt (+scale) | SOURCED |
| #171717 | profile grid background | S3r Play 5 | row 1300 x 925–937 (L 23) | profile | ±2/255 | SOURCED |
| 3 columns, tiles ≈115 × 158.5 pt (aspect 0.73), gap 4 pt, side insets 24 pt, radius 6.5 pt | profile "pics" grid | S4 profile.png | tiles x 48–281, 290–521, 530–755; y 1374–1691; next row 1700 | run scans /2 | ±0.5 pt; tile widths vary 113–117 pt in the mock | SOURCED |
| #000000 | profile background under the pics grid | S4 profile.png | (30,1500),(780,1500),(400,1300) | median | exact | SOURCED |

### Copy (verbatim)
"me & friends", "friends wall", "friends..." (S5) · "pics" (S4 profile section header) · "customize profile"
(S4) · "sent a pic to the wall" (S7, in "yrrah sent a pic to the wall · 9:00 PM") · "every day = wall
recap", "collect best memories in your profile" (S3 Play captions) · W1 v1.214.0 note (above).

### Do-not-copy
Cut-out person stickers and their outlines (stickers are do-not-build; record only the canvas/grid facts),
streak "🔥0" on the collapsed sheet (S5 t52.00), red "new" dots and the numeric "3" chat-tab badge (counts),
"customize profile" vibe/wallpaper features (profile customisation is not a product feature here),
YOPE wordmark.

### Not found
Wall of a member restricted to shared groups (no evidence of how Yope scopes it), empty wall state, wall
edit flow beyond the toolbar (no recording of remix/shuffle), how wall tiles are ordered. Smallest capture:
20-s screen recording: open own wall, a friend's wall, tap shuffle once, tap edit, back.

---

## 6. `week.recap` and `week.edit`

**Reference images:** O3 `yope-week-recap.jpg` (week recap screen, CAPTURED), S6 t5.33 ("26 May" day view
with "view recap" pill, June 2026), S2 + S3 `b-play-03.png` (recap/wall scrapbook with "today" pill and
"share"), S5 t48.00/t49.00 (week/month labels in the 1:1 feed). Week recap **grid** has only one image (O3)
→ approximated where noted.

### Layout (O3)
Header: ‹ in a dark circle (left) and centred title "18 aug-24 aug". Below: a **recap card** (paged
horizontally; 2 page dots below it) showing a grid collage of the week's photos with a bottom gradient scrim,
the label "18 AUG-24 AUG" bottom-left (white, heavy, uppercase) and a wordmark + "@handle" bottom-right
(**do-not-copy** wordmark). Under the dots, the page continues with the week's photos in a **full-bleed
3-column grid** (blurred in O3). A floating segmented capsule "recap | pics" sits above the home indicator
(selected = white pill with black text; unselected = white text on the dark capsule). An iOS scroll indicator
at the right edge shows the page scrolls vertically; the card's **top edge is clipped** under the header
(square top corners vs rounded bottom corners), so the first grid row is partially hidden.

Entry points: the film-strip glyph circle in the group header (S1) and the "view recap" pill at the bottom of
a past day's photo cards (S6 t5.33). The day view title is "26 May" (S6).

### Measured values

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| 334 pt (376 px) wide; insets 30 pt left / 28.9 pt right | recap card | O3 | x 82.5–458.5 | edge rows 150/250/420 | ±1 pt | CAPTURED |
| 3 equal columns, **0 gap** | recap grid rows 2–3 | O3 | seams x 207.5, 332.5 (strong gradient peaks); widths 125/125/126 px | column-gradient seams | ±1 px (±0.9 pt) | CAPTURED |
| 111 pt × 167 pt (125 × 188 px), aspect 0.665 (≈2:3) | grid tile (rows 2–3) | O3 | row seams y 240.5, 429.5; card bottom 617 | gradient seams | ±1 pt | CAPTURED |
| 2 tiles, seam x≈320 (unequal); height not measurable (clipped) | grid row 1 | O3 | y 109.5–240.5 visible | gradient | low | CAPTURED |
| ≈12 pt (≈14 px) | card bottom corner radius | O3 | BL inset 12 px at 1 px → 0 at 10 px | inset profile | ±3 pt (JPEG) | CAPTURED |
| 14.2 pt (16 px) cap height → **20 pt** heavy, white, uppercase | recap label "18 AUG-24 AUG" | O3 | x 111–278, y 571–586 | threshold >200 | ±1 pt | CAPTURED |
| 25.3 pt / 27.5 pt | label inset from card left / baseline to card bottom | O3 | 82.5→111; 586→617 | differences | ±1 pt | CAPTURED |
| x-height 8.9 pt → **17 pt** semibold, centred | title "18 aug-24 aug" | O3 | x 207–333 (centre 270 = screen centre), x-height rows 82–91 | glyph rows | ±1 pt | CAPTURED |
| 8 pt dots, centre pitch 17.3 pt; active white, inactive #4B4B4B | page dots | O3 | active x 255.5–264.5, inactive 274.5–284.5, y 640.5–649.5 | profiles | ±1 pt | CAPTURED |
| outer ≈160 × 47.5 pt; selected pill 83 × 40.4 pt white; inset ≈3.5 pt | segmented "recap | pics" | O3 | outer x≈180–360, y 858.5–912; pill x 183.5–277, y 862.5–908 | profiles (outer edge low contrast) | outer ±3 pt, pill ±1 pt | CAPTURED |
| x-height 8.4–8.9 pt → **16–17 pt** semibold | segment labels | O3 | "recap" rows 882–891; "pics" 882–891 | glyph rows | ±1 pt | CAPTURED |
| 3 columns, full-bleed, tiles 131 × 175 pt (3:4), gap ≈1 pt, square corners | week "pics" grid under the card | O3 | seams x 196, 343.5; rows y 694.5–891.5 | profiles | gap ±0.5 pt | CAPTURED |
| ≈160 × 52.5 pt pill, fill #090909, light rim | "view recap" pill (June 2026) | S6 t5.33 | x 242.5–477, y 1151–1228 | row/col profile ×0.682 | ±1.5 pt | SOURCED |

### Copy (verbatim)
"18 aug-24 aug" (title), "18 AUG-24 AUG" (label), "recap", "pics" (O3) · "view recap" (S6) · "26 May" (S6
day title) · "today" (S2 pill on the recap) · "your life = daily & monthly recaps" (S2 headline) ·
"every day = wall recap" (S3) · "today's recap" (W2 yope.app) · "AI turns shared moments into personalized
memory recaps." (W2 press page) · "35M+ AI recaps watched" (W2 press).

### `week.edit`
Only verbs are sourced: "edit them, remix them, make your own memory albums / save it or share it with your
friends" (W1 v1.214.0). The wall editor toolbar (S4) shows the editing affordances (photo, text, sticker,
colour, cut-out, music, shuffle). **No reorder/remove UI, no save-as-album flow found.**

### Do-not-copy
Wordmark + "@handle" watermark on the card (O3), streaks, Wrapped-style counts (the iPad Wrapped 2025 video was
not used).

### Not found
Recap generation timing/copy ("recap ready"), recap card layouts for N≠9 photos, swipe to page 2 content,
week.edit reorder/remove, empty week. Smallest capture: 20-s recording opening a weekly recap, swiping
recap pages, toggling recap/pics, tapping edit.

---

## 7. `albums.list`, `albums.view`

Only evidence: "make your own memory albums" (W1, v1.214.0–1.215.0, Apr 2026). TikTok creators call a Yope
group a "secret album" (search snippets for @yrrah.yope 2024–2025 videos; older than 12 months, not
verified). **No album list or album screen found.** Smallest capture: one screenshot of Yope's album list
and one of an open album.

---

## 8. Collage composition facts (for `collage.view` and `collage.share`)

Every Yope collage/grid seen, with its layout rules. Values in pt (scale per §0); "0 gap" means tiles touch.

| # | collage | file(s) | canvas / container | grid & spans | tile sizes / aspect | gaps | corner radius | edges, overlap, rotation | level |
|---|---|---|---|---|---|---|---|---|---|
| C1 | **Week recap card** | O3 | card 334 pt wide, 30/28.9 pt side insets; height ≥451 pt (top clipped) | rows 2–3: 3 equal columns; row 1: 2 unequal tiles (seam at ≈61 % of width), height unknown | rows 2–3: 111 × 167 pt (≈2:3 portrait) | **0** (no gutters, no border) | outer ≈12 pt (bottom corners seen); tiles square-cornered inside | none; bottom scrim gradient (dark) under label; label bottom-left 25 pt inset, wordmark bottom-right | CAPTURED |
| C2 | **Week "pics" grid** | O3 | full screen width, no side inset | 3 equal columns, rows continue | 131 × 175 pt (3:4) | ≈1 pt both directions | 0 (square) | none | CAPTURED |
| C3 | **Profile "pics" grid** (Jul 2026) | S4 profile.png | 24 pt side insets | 3 columns | ≈115 × 158.5 pt (0.73) | 4 pt both directions | 6.5 pt per tile | none | SOURCED |
| C4 | **Profile grid of walls** | S3r Play 5 | 8.5 pt side insets | 2 columns | 185 × 329 pt (**9:16**) | 5.6 pt both directions | ≈15 pt per tile | none | SOURCED |
| C5 | **Wall canvas** (editor) | S4 wall.png | full width 402 pt, **9:16**, top at 61.5 pt | free-form (no grid) | photos of mixed sizes | 0 between abutting rectangular photos; free overlap | canvas ≈20 pt | rectangular photos axis-aligned or rotated (a white-bordered instant-photo frame ≈7 pt side border, rotated ≈4.6°); cut-outs with lime outline ≈13 pt median (8–16 pt, irregular offset path) or blue #1499F2 ≈7 pt; decorations overlap | SOURCED |
| C6 | **Recap scrapbook** | S2 / O2 / S3 Play 3 | full screen | free-form | rectangular photos stacked edge to edge (no gaps) at the right column (hooded girl photo, girl-with-phone photo), cut-outs and decorations overlap across them | 0 | screen corners | overlapping, several elements break the screen edge (marketing embellishment) | SOURCED |
| C7 | **Exported/shared wall** | S5 t66.00, S8 | **9:16** image | free-form wall | — | 0 | ≈ rounded in the preview | preview tilted ≈−2° in the share sheet; watermark (wordmark + group/handle name) bottom-right | SOURCED |

**Rules that hold across C1–C7 (traceable):**
1. **Canvas aspect is 9:16** for walls and their exports (C4 thumbnails 185×329 pt = 0.5623; C5 804×1430 px =
   0.5622; C7 preview 279×500 pt = 0.558 after −2° tilt correction).
2. **Photo-to-photo gap is 0** inside a recap/wall collage (C1 seams, C5/C6 abutting photos); gaps appear only
   between **separate items in a grid of items** (C3 4 pt, C4 5.6 pt, C2 ≈1 pt).
3. **No borders between tiles** in the recap grid (C1); a white border exists only on the instant-photo
   decoration in walls (C5).
4. **Rounded outer corners, square inner corners** for the recap card (C1, ≈12 pt outer, 0 inner); walls canvas
   ≈20 pt (C5); wall thumbnails ≈15 pt (C4).
5. **Columns for N photos:** only the N≈8–9 case is observed (C1: one row of 2 + two rows of 3). A rule for
   other N is **not found**.
6. **Text on the collage:** bottom-left label over a dark bottom scrim, uppercase heavy white, 25 pt inset
   (C1); export watermark bottom-right (C1, C7, S8).
7. **Rotation:** recap grid tiles are not rotated (C1); wall elements may be rotated (C5 ≈4.6°); the share
   preview is shown tilted ≈−2° (C7).

---

## 9. `collage.share`

**Reference images:** S2/O2 ("share" pill on the recap), S3 Play 3 (same), S5 t66.00 ("share with friends"
sheet, Dec 2025), S8 (exported walls with watermark), O3 (watermark on the recap card).

### Layout
- **Share pill (S2):** a frosted translucent rounded rectangle at the bottom centre of the recap with a white
  filled share glyph (box + up arrow) and "share" in white bold.
- **Share sheet (S5 t66.00):** a bottom sheet (grabber) with an orange gradient background, the title
  "share with friends" (black, heavy, 2 lines, centred), a **preview of the 9:16 wall export** tilted ≈−2°
  with rounded corners, and a row of share targets: an Instagram-gradient pill "share", then square buttons
  for Snapchat, WhatsApp, and a blue "save" (download glyph).
- **Export (S8, C7):** full-bleed collage; watermark = app wordmark + space name ("Bestiesss", "Our band")
  bottom-right. **Do-not-copy** the wordmark; third-party brand buttons are replaced by the platform share sheet
  in our build (PLATFORM).

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| 126 × 58 pt (285 × 131 px) | share pill | S2r | x 466–751, y 2328–2459 | rim profiles | ±1.5 pt | SOURCED |
| ≈10 pt | share pill corner radius | S2r | visual on 2× zoom | estimate | ±2 pt | SOURCED |
| frosted, backdrop-dependent (#ABA79E over light, #7B6955 over dark) + light rim | share pill fill | S2r | (495,2350),(720,2350) | median | n/a (translucent) | SOURCED |
| x-height 9.3 pt → **18 pt** bold, white | "share" label | S2r | rows 2384–2404 | glyph rows | ±1 pt | SOURCED |
| 25.7 pt tall, white filled | share glyph | S2r | rows 2360–2418 | glyph rows | ±1 pt | SOURCED |
| 90.6 × 50.5 pt capsule, #FFFFFF, black heavy text | "today" pill | S2r | x 798.5–1003, y 1019.5–1133.5 | crossing | ±0.5 pt | SOURCED |
| 5.3 × 50 pt lime #CCFD07 bar, 7 pt right of the pill | lime bar beside "today" (looks like a text caret; meaning unverified) | S2r | x 1019–1030, y 1021–1133 | colour mask | ±0.5 pt | SOURCED |
| #FDB000 → #FE7700 (top → middle) | share sheet gradient | S5 t66.00 | (130,200),(590,200),(120,700) | median | ±6/255 | SOURCED |
| 279 × 500 pt (9:16), tilted ≈−2° | export preview in sheet | S5 t66.00 | left edge 164→186 over y 400→1040; col 350 y 377–1049 | edge scans ×0.744 | ±2 pt, ±0.3° | SOURCED |
| 49 pt tall; pill 137 pt; squares 48 pt; gaps 15.6 pt | share target row | S5 t66.00 | x 140–323, 345–409, 430–495, 516–581; y 1090–1155 | run scans | ±1 pt | SOURCED |

Copy (verbatim): "share" (S2), "share with friends" (S5 t66.00), "share" on the Instagram pill (S5).

**Not found:** exported image pixel size (no original export file), whether the export includes the scrim
label, save-confirmation copy. Smallest capture: one image exported with Yope's "save" (the actual file).

---

## 10. Motion

| motion | file | timestamps (fps) | first/last changed frame | duration | curve | precision |
|---|---|---|---|---|---|---|
| Viewer: horizontal swipe to the adjacent photo (gesture-driven) | S5 `b-yopeapp-…-t57.20/57.30/57.40` | 57.20–57.40 s (30 fps) | first movement f1717, settled f1722 (pts/30) | ≈167 ms (5 frames) | not measurable (finger-driven; incoming photo enters from the left; pages separated by a thin dark gap) | ±1 frame (±33 ms) |
| Bottom sheet presentation (sticker-options sheet; the feature is do-not-build, the sheet motion is Yope's generic sheet) | S5 `…-t57.97-sheet-before`, `…-t58.10-sheet-overshoot`, `…-t58.20-sheet-settled` | 57.97–58.20 s | starts between f1739 and f1740; lime button top y: f1741 1144, f1742 1066, **f1743 1064 (peak)**, f1744 1074, f1745 1084, f1746 1086 (rest) | ≈200–230 ms total (6–7 frames); rise ≈100 ms, settle ≈100 ms | spring with visible **overshoot ≈16 pt** (22 px ×0.744) past rest; 5 samples, curve not fittable | ±1 frame; source fps of the screen recording unknown (TikTok re-encode 30 fps) |
| Wall "living" animation (press-kit GIF) | S4g `wall.gif` | 36 frames, frame durations 140–150 ms (230/240 ms last two) | every frame shifts collage elements slightly (stop-motion jitter); whole-canvas mean diff 2.6–5.1 /255 per frame | loop ≈5.2 s | stepwise, ≈7 fps | GIF metadata exact; whether the app animates walls this way is **not verified** |
| Hourly cards scroll ("split view", groups.screen — yope-a's surface) | S4g `splitview.gif` | 51 frames at 110–130 ms | — | — | marketing GIF of a scroll | not used |

Not found: message send/arrival, photo open/close from the thread, recap page swipe, segmented
"recap | pics" toggle, voice record/playback. Haptics are not observable (PLATFORM).

---

## 11. Voice pattern (Yope copy on these surfaces)

- **Lowercase** for UI labels and titles, including sentence starts: "start typing...", "view recap",
  "share with friends", "me & friends", "recap", "pics", "today", "18 aug-24 aug", "december 2025",
  "you sent to Oblong" (proper nouns keep their capital). Release notes also lowercase ("recaps are now
  walls"). Exceptions: the recap **label** is uppercase ("18 AUG-24 AUG"); the viewer date is "Oct 30 2025";
  the day title "26 May".
- **Length:** 1–3 words for buttons/labels; placeholders 1–3 words + "..." (three periods; O5 shows four).
- **Person:** second person / first person plural implied ("you sent to …", "me & friends"); no "I".
- **Punctuation:** no terminal period on labels; "&" instead of "and" ("me & friends", "daily & monthly
  recaps"); ranges with a bare hyphen, no spaces ("18 aug-24 aug", "21-27 dec"); em dash with spaces in
  longer sentences ("— so you can find us faster", W1).
- **Emoji:** none in UI chrome on these surfaces; emoji appear only as quick reactions (❤️ 😂 🔥 in the 1:1
  field) and in user content.
- Examples: "start typing..." (S1), "view recap" (S6), "share with friends" (S5), "me & friends" (S5),
  "recaps are now walls" (W1).

## 12. Typography

The in-app typeface is **not identified** by any reliable source. yope.app's CSS uses Unbounded (display) and
Space Grotesk (body) for the **website** (`--disp`, `--body` variables in W2); no source ties them to the app.
Font token → `{ "ios": "system", "android": "system" }`, level PLATFORM. Sizes above are SF-equivalent sizes
derived from measured glyph heights.

## 13. Conflicts to reconcile (with yope-a and between Yope screens)

- Background: chat thread / 1:1 sheet **#171717** (S1, S5, O4) vs group photo-cards screen **#000000**
  (S6, June 2026) vs profile **#000000** (S4) vs profile grid of walls **#171717** (S3).
- Lime: **#CDFD07** (S1 PNG), #CCFD07 (S2), #CDFE08 (S4); website CSS `--lime: #c8ff2e` (W2, site only).
- Composer height 40 pt (S1 group) vs 49–51 pt (S5, O4 1:1).
- Bubble fill theirs #2B2B2B / mine #232323 (S1) vs reply/text part #444145 (S5 1:1, video).
- Photo radius 15 pt (S1) vs 16.5–19 pt (S5, O4).

## 14. Smallest owner captures that would close the gaps

1. `chat.thread` + `chat.composer` + `chat.voice`: **one 30-s screen recording in a Yope group chat**: type and
   send a two-line text, send a photo, reply to a photo, hold the mic to record a voice message, play it.
2. `photo.viewer`: **one 10-s recording**: tap a photo in the chat, swipe to the next, open •••, close.
3. `walls.*`: **one 20-s recording**: own wall, a friend's wall, "me & friends" row, tap shuffle once, tap edit.
4. `week.recap` / `week.edit`: **one 20-s recording**: open a weekly recap, swipe recap pages, toggle
   recap/pics, tap edit/remix, save.
5. `albums.*`: **two screenshots**: album list and one open album.
6. `collage.share`: **one exported file** saved via Yope's "save" button (gives pixel size + watermark).
