# Overnight photos and the weekly group question — reference research

Researched 2026-10-16. Two new features, both drawn **only** in Retro's visual system (owner decision 2026-10-15: Retro is
the single visual anchor; Dispo, Lapse, Apple Journal and others supply **mechanics and copy patterns only**):

- **(a) Overnight photos** — `camera.overnight`: a camera mode whose photos nobody (the author included) sees until they
  develop at a set morning time in the group's time zone. Mechanics references: **Dispo**, **Lapse**.
- **(b) Weekly group question** — `question.weekly`: one light prompt per group per week, answered with a photo; the
  answers show together. Mechanics / copy references: **Retro's own "what to share" prompt cards**, **Apple Journal's
  reflection prompts**; BeReal's prompts (already in `bereal.md`) for contrast.

Evidence files: `references/auto/dispo/`, `references/auto/lapse/`, `references/auto/apple-journal/` (each with
`INDEX.md`: file → source URL, access date 2026-10-16, app version) plus existing `references/auto/retro/` and
`design/research/bereal.md`. Draft specs: `design/surfaces/camera.overnight.md`, `design/surfaces/question.weekly.md`.
Backend note: `design/research/overnight-and-questions-data.md`.

---

## 0. Sources and how they were used

| id | source | what it is | quality / scale | date |
|---|---|---|---|---|
| **DX1** | `dispo/store/dispo-store-X-1.png` (1284 × 2778) | App Store render of the camera in a phone mock-up | lossless; screen inside the frame x 120.4–1165.6, y 422.2–2684.8 = 1045.2 × 2262.6 px, aspect 0.4620 = 393 × 852 pt → **2.660 px/pt** (±0.5 %) | listing 4.6.0 (2026-03-20) |
| DX2, DX3 | `dispo/store/dispo-store-X-2.png`, `-X-3.png` | paid camera skin; paid print order "YOUR ORDER IS DEVELOPING!" | layout only (do-not-copy content) | 4.6.0 |
| **DUG** | `dispo/help/help-4410178185492_userguide-nov21.png` | official user guide (camera with roll chips on the top bar; "New Roll") | render, 4 phones; ratios only | Nov 2021 |
| **DLIB** | `dispo/help/help-360097208771_library.png` (1290 × 1690) | official Library screenshot: "15 photos developing" banner, 4-column grid | 3x (430-pt screen) crop: pt = px / 3 | 2021-07 |
| DH-TP, DH-W, DH-L, DN | Dispo help articles (Zendesk API) and Notion page "How do I use Dispo?" — URLs in `dispo/INDEX.md` | verbatim mechanics text | official text | 2021–2022 |
| DAS | Dispo App Store description, listing 4.6.0 | "Photos develop every day at 9am" | official text | 2026-03 |
| **L01** | `lapse/store/lapse-store-01.png` (1242 × 2688) | full-width camera render | ratios to screen width (render device unknown, see `lapse/INDEX.md`); converted with **pt = fraction × 393** | listing 4.1.1 (2025-12-06) |
| L05 | `lapse/store/lapse-store-05.png` | same camera in a mock-up; screen x 87.5–1153.5 (1066 px) | ratios; cross-check of L01 (shutter 0.2545 × screen in both) | 4.1.1 |
| **L03** | `lapse/store/lapse-store-03.png` | review of developed photos "Your snaps / 2 of 9" | layout only | 4.1.1 |
| **LSE3** | `lapse/store/lapse-store-se-3.png` (1242 × 2208) | composite: developing tiles with lock glyph + "SNAPS DEVELOPED" banner | ratios only | 4.1.1 |
| LSE1 | `lapse/store/lapse-store-se-1.png` | earlier camera with "10+" inbox badge and stack "6" | layout only | 4.1.1 |
| LAS, LWEB, TC21 | Lapse App Store text; https://lapse.app/ FAQ; TechCrunch 2021-12-20 (press) | mechanics text | official text (TC21 = press) | 2021–2025 |
| **AJ2** | `apple-journal/store/journal-store-iPhone_2_Suggestions.png` (1290 × 2796) | raw 3x Suggestions sheet with the REFLECTION card | **pt = px / 3** (status bar at native size; 430 × 932 pt) | listing 1.7 (2025-12-12) |
| AJ7 | `apple-journal/store/journal-store-iPhone_7_Widget.png` | Home Screen widget with a prompt | 3x | 1.7 |
| AJN-* | `apple-journal/newsroom/*.jpg` | newsroom renders (notification, suggestions, editor) | ratios only | 2023-12-11 |
| AJS | support.apple.com iPhone User Guide (Journal pages, iOS 27) | verbatim behaviour | **VERIFIED** (official documentation) | 2026 |
| **R-NUX** | `retro/apk/retro-android-2026.10.1150-strings.txt` keys `nux_card_title_what_to_share_0..7`, `nux_card_cta_what_to_share`, `post_reminder_notification_*`; card photo `retro/apk/nux_card_what_to_share_0.webp` (393 × 538 dp) | Retro's prompt cards and reminder copy | text; **caveat**: read from Retro's Android package, whose status as evidence is left to the owner (OWNER_DECISIONS #22, OWNER_SETUP §0 item 9) | Android 2026.10.1150 |
| BR | `design/research/bereal.md` §2 "On-screen prompts", §5 Bonus | BeReal's in-capture prompts and the locked Bonus | existing research | 2023–2026 |
| TC-REC | `retro/press/tc-2023-12-recaps.png` phone 1 | Retro's native segmented control on a black page, full width between the header and the first card ("Yearly · Monthly · Weekly · All Posts", Monthly selected) | render; layout only | 2023-12 |

**Methods.** Edges: luminance (mean of R, G, B) threshold crossings with linear sub-pixel interpolation along a row or
column (script `prof.py`: `row|col index from to threshold`), on lossless PNGs. Flat colours: median of a box. Text
colour: median of the pixels above a brightness threshold inside the glyph box. Text size: cap height (or ascender
height where noted) in px ÷ scale; no typeface is inferred (Dispo, Lapse and Apple use their own or system faces; Jolt
uses Retro's roles). Corner radius: per-row inset profile fitted to a circle at 10 px depth (approximate; continuous
corners read slightly larger).

---

## 1. Overnight photos — mechanics

### 1.1 Side by side

| mechanic | Dispo | Lapse | evidence |
|---|---|---|---|
| what it is | "the digital disposable camera" | "Turn your phone into a disposable camera" · "Shoot first, develop later" | DAS; LAS |
| **reveal time** | **09:00 local, the next morning**: "Photos develop every day at 9am"; "wait for them to develop at 9 AM the next morning"; "get access to your developed photos at 9 AM" | not documented officially for v4. 2021: group roll developed "24 hours after the roll has started" (press); current press figures conflict (10 min – 3 h) | DAS; DH-W; DN; TC21 |
| who sees before reveal | nobody, the photographer included (the reveal is the event) | nobody, the photographer included ("a mystery …until later") | DH-W; LSE3 headline |
| **mode switch** | yes: a labelled 2-segment control **`DEVELOP` — `9AM` · `NOW`** on the camera's top row (beside `LENS` and `TIMER`); "you have the option to decide whether you'd like your photos developed traditionally at 9 AM, or immediately … can be changed for individual dispos" | none: every photo develops | DX1 (515–795 × 576–688 px); DH-TP |
| default | `9AM` selected in every store image; help calls 9 AM "traditionally" | (always delayed) | DX1, DUG |
| viewfinder | **small window**: 145.1 × 258.7 pt (9:16) set inside an illustrated camera body (body = brand illustration, do-not-copy) | **normal**: full-width rounded viewfinder with live preview, zoom pill, flip, timer | DX1; L01, L05 |
| after the shutter | no preview; photo goes to Library / the chosen rolls | no preview; photo joins a **stack** at the leading slot of the control row, drawn as fanned gradient cards **with a number** (9, 16, 32, 6, 2 in the store images) | DX1; L01, L05, LSE1 |
| destination | chosen **before** shooting: "tap the ⊕ … choose which rolls you want to shoot to … the selected roll(s) will be ready for you to shoot to"; "Any dispos shot directly to a roll will also be developed to your Library" | your own snaps; later reviewed one at a time ("Your snaps · 2 of 9", ✕, "Undo") and added to "your Journal" (friends-only) | DH-TP; DN; L03 |
| developing placeholder | Library banner "**15 photos developing**" (count) over a fanned stack + film-canister illustration; grid of iridescent colour-field tiles | grid tiles drawn as **colour-gradient fields with a centred translucent lock glyph** | DLIB; LSE3 |
| reveal notification | "We'll be sure to give you a shout as soon as they're developed" (verbatim push text **not found**) | "💥SNAPS DEVELOPED💥" / "**5 snaps** ready to view 🎞️" | DH-W; LSE3 |
| reveal presentation | photos appear in Library / roll (no recording found) | sequential review "Your snaps 2 of 9" with swipe to Journal and "Undo"; 2021: "sent into the group chat … in a super-fast slideshow" | L03; TC21 |
| **"roll"** | a **roll = a shared album** (private or public) that friends shoot into; "Ready to roll?" | 2021: a **collective roll of 36 photos** per group; press: "a 'roll' of 36 shots to take daily" | DN; TC21; press (not official) |
| limits | none documented ("take one, ten, or hundreds of photos") | 36 per roll / per day (press, not official; not visible in v4 store images) | DAS; TC21 |
| paid mechanics | camera skins / film stocks ("OGcam", "Vibecam", "Noir Cam", "Matte Cam", "SPRINGSHOT"), "Dispo MAX", paid prints "YOUR ORDER IS DEVELOPING!" | none in the store images ("Lapse is totally free") | DX2, DX3; Dispo help "Cameras"; LWEB |
| offline | capture works offline; "cloud icon with an X" until upload | — | Dispo help 360062068852 |

### 1.2 What Jolt takes (decisions from evidence)

| # | decision | from | why this one |
|---|---|---|---|
| O-1 | **Reveal at 09:00 in the group's time zone**, the first 09:00 after capture | Dispo (DAS, DH-W, DN) | the only documented fixed time; Lapse's delay is undocumented. Group time zone because `groups.time_zone` already drives invitations, weeks and on-this-day (docs/API.md §5.3) |
| O-2 | **A two-way mode control on the camera, segments "9 AM" · "Now" (Dispo's order)**, default **Now** | Dispo's `DEVELOP 9AM NOW` control (DX1; DH-TP "toggle") | Dispo is the only reference with a switch (Lapse has no immediate mode). Default Now keeps `camera.capture` unchanged for people who never touch it (tenet 5: an invitation); Dispo's default 9AM is recorded as the conflict |
| O-3 | Keep Jolt's **normal viewfinder** (no small window) | Lapse (L01, L05) | Dispo's small window is part of its illustrated camera body (do-not-copy); Lapse, the reference that shares with friends, keeps a full viewfinder |
| O-4 | **No preview after the shutter**; the photo goes straight to the chosen groups | Dispo (shoot-to-roll), Lapse (stack) | both references skip the preview; that is the mechanic |
| O-5 | **Destination chosen once, before shooting**, shown on the camera and kept for the session | Dispo (DH-TP, DN: choose rolls, then "ready for you to shoot to") | lets a member take "one, ten, or hundreds" of photos (DAS) without a per-photo step |
| O-6 | **One "developing" tile per group, no number, no names** | Dispo's single Library banner (DLIB), number removed | Lapse's per-photo tiles and both apps' numbers would show *how many* and *who* — a count (tenets) |
| O-7 | Placeholder drawn as Retro's **C-17 placeholder tile** (`color.global.control`) with the word "Developing" centred | fill: Retro C-17 / C-28; word: Dispo ("developing", DLIB); centring: Lapse (LSE3 glyph centred) | the colour-field look (Dispo, Lapse) would need pixels derived from the photo before the reveal (privacy: nobody sees anything); Lapse's lock glyph reads as Retro's "Post to see" lock (Retro do-not-copy) |
| O-8 | **One push per group at the reveal**, no count, no emoji | Lapse's banner structure (LSE3) in Retro's push voice (`retro.voice.push`) | Lapse sends one aggregated alert; its count and 💥 are stripped |
| O-9 | Reveal opens the **revealed photos in sequence** in `photo.viewer` | Lapse "Your snaps · 2 of 9" (L03), TC21 slideshow | the "%1$d of %2$d" position badge is already Retro's viewer pattern (`retro.voice.terse-numbers`) |
| O-10 | **No roll object, no shot limit** | Dispo ("hundreds of photos") over Lapse's 36 | a limit needs a counter ("24 shots left") — rejected (flag F-1) |
| O-11 | **Photos only** in 9 AM mode (hold-to-record off) | Dispo "dispos", Lapse "snaps" are photos | no reference develops videos |

---

## 2. Overnight photos — measured values

Dispo DX1: pt = px / 2.660. Lapse L01: fraction of screen width (1242 px) × 393. Lapse LSE3: ratios to the tile.
DLIB: pt = px / 3.

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| 2 segments, `9AM` · `NOW`; caps; header `DEVELOP` above | develop control | DX1 | 515–795 × 576–688 | visual + row 600 crossings (thr 15 / 100) | — | SOURCED |
| 105.3 × 42.5 pt (280 × 113 px) | develop control size | DX1 | x 515–795, y 576–688/689 | threshold 15 crossings (row 600, col 740) | ±0.5 pt | SOURCED |
| selected segment 53.4 pt wide (x 516–657) | 9AM segment | DX1 | row 600 thr 100 | crossing | ±0.5 pt | SOURCED |
| ≈ 11 pt | control corner radius | DX1 | rows 576–610, left edge 539 → 514 | inset profile, circle fit | ±1.5 pt | SOURCED |
| 6.8 pt | gap to the next control (`TIMER`) | DX1 | 795 → 813 | difference | ±0.5 pt | SOURCED |
| #B4CDE2 selected fill / #191D21 unselected fill / #000000 page | develop control colours | DX1 | (530–545, 600–615); (680–700, 600–615); (300–400, 470–480) | box median | ±2/255 | SOURCED — **not adopted** (Dispo palette) |
| 10.5 pt cap height `NOW` (#B4CDE2); `9AM` black on the selected fill | segment labels | DX1 | NOW 686–768 × 618–645 | ink bbox (L > 120) | ±0.5 pt | SOURCED — not adopted (C-30 is native) |
| 7.5 pt cap height `DEVELOP`; cap bottom → control top 8.3 pt | control header | DX1 | 565–704 × 535–554 | ink bbox | ±0.5 pt | SOURCED |
| 14.7 pt | control bottom → camera body | DX1 | 688 → 727 (cols 300, 640, 1000) | first L > 12 | ±0.5 pt | SOURCED |
| 145.1 × 258.7 pt, aspect 0.561 (9:16); 0.369 × screen width; top 290.5 pt | Dispo viewfinder window | DX1 | x 368–754 (rows 1250–1400), y 1194.9–1883 (mean of cols 400–720) | crossings thr 90; row-mean profile | ±1 pt | SOURCED — **not adopted** (O-3) |
| 0.2545 × screen width → **100.0 pt** at 393 | Lapse shutter outer diameter | L01; L05 | L01 x 462.46–778.53, y 2306.73–2623.0; L05 x 483.48–754.7 | crossings thr 128 | ±0.3 pt | SOURCED — not adopted (Jolt keeps `camera.capture.size.shutter*`) |
| ring 1.0 pt / gap 9.1 pt / disc 79.9 pt; ring #FFFFFF, disc #CFCFCF | Lapse shutter parts | L01 | 462.46→465.61→494.31→746.68 | crossings, × 393 / 1242 | ±0.3 pt | SOURCED — not adopted |
| 64.0 pt circle, fill ≈ #29251F | Lapse flash circle | L01 | x 908.78–1111.03, y 2363.39–2566.05 | crossings thr 20 | ±0.5 pt | SOURCED — equals Jolt's `size.global.circleButtonLarge` (64) |
| leading slot of the control row; fanned cards, top card a magenta–purple gradient, white number | Lapse developing stack | L01, L05, LSE1 | L01 bbox 111–419 × 2300–2580 (incl. glow); digit 183–227 × 2438–2498 | bbox | — | SOURCED — **number not copied** (F-1) |
| tile aspect 0.811 (516 × 636 px; ≈ 4:5); 2 columns | Lapse developing tiles | LSE3 | x 100–615 / 625–1141; y 1429–2064 | gap-colour scan (#2F2F32) | ±0.5 % | SOURCED — not adopted (Jolt keeps C-17 3:4 tiles) |
| gap 1.4–1.7 % of tile width (7–9 px), #2F2F32 | Lapse grid gap | LSE3 | x 616–624; y 1422–1428 | colour match | ±1 px | SOURCED |
| glyph 0.244 × tile width, 0.261 × tile height; centred horizontally (357.5 = 357.5), 1.7 % above centre vertically | Lapse lock glyph in a developing tile | LSE3 | 295–420 × 1653–1818 in tile 100–615 × 1429–2064 | bbox (L > 170) | ±1 px | SOURCED — glyph not adopted (O-7); **centring adopted** |
| white at ≈ 55–60 % opacity | lock glyph fill | LSE3 | glyph median (225,191,165) over tile (195,104,27) | per-channel alpha solve | ±5 % | SOURCED — not adopted |
| "15 photos developing" right-aligned on a banner ≈ 396.7 × 98.7 pt over a fanned stack | Dispo developing banner | DLIB | ≈ 48–1238 × 364–660 | visual bbox ÷ 3 | ±1 pt | SOURCED — count not copied |
| 4-column grid, ≈ 2 pt gaps, dated header "March 1" | Dispo Library grid | DLIB | header y ≈ 780–830; grid from y ≈ 864 | visual | ±1 pt | SOURCED |
| `💥SNAPS DEVELOPED💥` / `5 snaps ready to view 🎞️` | Lapse reveal banner | LSE3 | banner ≈ 66–1170 × 755–1030 | transcription | exact | SOURCED (marketing composite of a notification) |
| "Your snaps" / "2 of 9", ✕ leading, "Undo" capsule trailing | Lapse reveal review header | L03 | top ≈ 700–760 px | transcription | exact | SOURCED |

Motion and haptics of the capture-to-stack hand-off and of the reveal: **not observed** (no App Preview for either app;
no official recording reachable) → BLOCKED (§9).

---

## 3. Weekly group question — mechanics

| mechanic | Retro | Apple Journal | BeReal | evidence |
|---|---|---|---|---|
| prompt form | a question about a moment, second person, "?": "Caught up with a friend?", "Did something nice for yourself?", "Something unfortunate happened?", "Ate something tasty?", "Took a nice fit pic?", "Made something you're proud of?", "Took a cute selfie?", "Anything else you want to remember?" | "Think about something you love to do and why it brings you joy." (AJ2, AJN); "What's something nice you can do for yourself today?" (AJ7); editor placeholder "What will you remember most about your outing?" (AJN) | in-capture lines "Smile now, uh I mean now", "Keep smiling and don't change a thing" (instructions, not questions) | R-NUX; AJ2; AJ7; BR §2 |
| call to action | one button: "Add a memory" (`nux_card_cta_what_to_share`) | tap the card to start an entry; refresh glyph swaps the prompt | — | R-NUX; AJ2 |
| where | cards in the home feed ("Tips from Retro", "Ideas to share"), shown as a sequence ("Tap anywhere to advance") on a full-width photo card 393 × 538 dp | a REFLECTION card in the Suggestions sheet; a Home Screen widget whose prompt "change[s] throughout the day" | over the camera during capture | R-NUX; AJ2; AJ7; Journal App Store text; BR |
| who gets the same prompt | each person (single-player) | each person; **refresh is per person** | everyone gets the same moment | — |
| reminders | member-chosen cadence "Sharing Reminders — Daily / Weekly / Monthly / Never"; weekly body "Anything from today you want to remember?" | notifications are a **user-set schedule** ("set a schedule for journaling"); can turn prompts off ("turn off … Get Writing Prompts") | the daily push (time-sensitive, 2 min) | RP §4.2, §6.2; AJS |
| dismiss | — | "touch and hold the suggestion, then tap Remove" | — | AJS |
| gating | Retro's "Post to see" lock (do-not-copy) | none | Bonus BeReal "locked" if you posted late (do-not-copy) | components.md do-not-copy; BR |
| progress / streaks | "Weeks Posted: N" (do-not-copy) | "insights and streaks" (do-not-copy) | streaks / "late" (do-not-copy) | Journal App Store text |

**Not researched / not found:** Lapse has no prompt feature in its v4 store images or site text (its "Journal" is where
developed snaps go). Gas / NGL question-card layouts were not collected (time); none is needed because the card uses
Retro's feed card.

### 3.1 What Jolt takes

| # | decision | from | why |
|---|---|---|---|
| Q-1 | One question per group per **group week** (Monday start, group time zone), **the same for every member** | weekly cadence: Retro (weekly journal, ISO weeks); same-for-all: BeReal's shared moment | "answers show together" needs one shared question; Apple's per-person refresh is therefore **not** taken |
| Q-2 | Question text = a short second-person question about a moment, "?" | Retro `retro.voice.prompt` (R-NUX), Apple reflection prompts (AJ2, AJ7) | both references; Retro is the voice anchor |
| Q-3 | Shown as a **feed card in the group screen's pager** with one light pill "Add a photo" | Retro's prompt cards live in its home feed with one CTA "Add a memory" (R-NUX); `groups.screen` §8 already holds Retro's feed cards | composition of existing Retro components |
| Q-4 | A **label line naming the feature** above the card ("This Week's Question") | Apple's eyebrow "REFLECTION" (AJ2); Retro feed-card header line (`groups.screen` §8) | tells the card apart from a member's photos |
| Q-5 | **No push for the question** | Apple: notifications only on a schedule the user sets (AJS); Retro: reminders at a member-chosen cadence | the daily invitation is the group's one regular alert; a weekly push would be a second, unrequested one (tenet 5) |
| Q-6 | Each member may **remove the card for themselves** | Apple "Remove" (AJS) | an invitation can be declined |
| Q-7 | **No gate, no tally**: answers are visible whether or not you answered; no "N answered", no names of who has / hasn't | BeReal Bonus lock and Retro "Post to see" are do-not-copy | tenets 3, 5 |
| Q-8 | Answers are ordinary posts of the group (strip, viewer, recap) linked to the question | Jolt data model (posts) | nothing gets lost (tenet 4) |

---

## 4. Weekly question — measured values (Apple Journal REFLECTION card, AJ2, pt = px / 3)

None of these values is adopted: Jolt draws the card with Retro's tokens (§7). They are recorded to show the layout
pattern the mapping follows (eyebrow → prompt → affordance).

| value | element | px coords | method | precision | level |
|---|---|---|---|---|---|
| 396.7 × 163.0 pt; margins 17.3 / 16.0 pt | card | x 52–1241, y 1944–2432 | colour mask ±12 of #DD5A58 | ±0.5 pt | SOURCED |
| #DD5A58 (221, 90, 88) on a #FDFDFD page | card fill | (600–700, 2100–2120) | box median | ±2/255 | SOURCED — not adopted |
| ≈ 14.5 pt | card corner | top-left inset profile (dy 0 → 30 px: 51 → 0 px) | circle fit at 10 px depth | ±1.5 pt | SOURCED |
| cap height 8.7 pt; top 24.3 pt below card top; leading inset 15.7 pt; caps, tracked | eyebrow "REFLECTION" | 99–327 × 2017–2042 | ink bbox | ±0.4 pt | SOURCED |
| #FFABA7 = white ≈ 48 % over the fill | eyebrow colour | ink median | per-channel alpha solve | ±3 % | SOURCED |
| 37.7 × 31.3 pt; 17.7 pt from the card's trailing edge; top 20 pt below card top | refresh glyph (two circular arrows) | 1075–1188 × 2004–2098 | ink bbox | ±0.4 pt | SOURCED — mechanic not taken (Q-1) |
| ascender height 16.0 pt; line pitch 26.0 pt; 3 lines; leading inset 15.3 pt; eyebrow cap bottom → first line top 41 pt; last line → card bottom 17 pt | prompt text | "Th" 98–199 × 2165–2213; lines 2165 / 2243 / 2321 | ink rows | ±0.4 pt | SOURCED |
| #FFFBF5 | prompt colour | ink median | box | ±3/255 | SOURCED |
| "Tuesday, Apr 1" over the prompt; "+" and refresh circles at the bottom corners | widget prompt | AJ7 | visual | — | SOURCED |

Retro prompt card photo: 393 × 538 dp (aspect 0.730), dark bottom gradient for text — R-NUX image. Retro's prompt-card
**layout** (text position, sizes) was **not captured** (only strings + background) → the Jolt card uses the
`groups.screen` feed-card composition, not a Retro prompt-card measurement (§9).

---

## 5. Do-not-copy

**Dispo:** its name, wordmark, star mark, app icon; the illustrated camera bodies, film canisters, batteries, glitter
textures; camera / film-stock names ("OGcam", "Vibecam", "Noir Cam", "Matte Cam", "SPRINGSHOT", "Dispo MAX"); the
lime / blue-grey palette (#B4CDE2) and its typefaces; "15 photos developing" (count); paid camera skins, paid prints
("YOUR ORDER IS DEVELOPING!", "50 Photos 4" × 6""), public rolls, follower counts on profiles (DUG phone 4); "dispos" as
a noun; "Ready to roll?"; the brand used as a verb ("Dispo away!").

**Lapse:** its name and "Friends not followers®" (registered mark), app icon, serif/italic marketing type, gradient
palette of the developing cards; the **number on the developing stack** (9 / 16 / 32 / 6 / 2); "SNAPS DEVELOPED" in caps,
the 💥 and 🎞️ emoji, "5 snaps" (count); the "10+" inbox badge (count); 36-shot rolls / daily shot allowance; the lock
glyph on developing tiles (reads as Retro's do-not-copy "Post to see" lock); "snaps" as a noun.

**Apple Journal:** streaks and insights; the coral / lavender card fills; the per-person refresh of a shared question;
the Journal app icon and butterfly mark.

**BeReal / Retro (already listed):** Bonus lock for late posters, "late" labels, ⚠️ urgency, "Post to see", "Weeks Posted".

**Urgency anywhere:** no "you missed it", "last chance", "ends soon", countdown to 9 AM, or "N shots left".

---

## 6. Tenet review

| tenet | overnight photos | weekly question |
|---|---|---|
| Closeness without effort | one mode switch; destination chosen once per session (O-5) | one card; answering = the normal camera |
| Real, not performed | strong fit: no preview, no retake (Lapse: "free from the pressure of over-curation"). **Risk F-2:** photos of other people reach the group without anyone reviewing them (Dispo's roll model; Lapse instead lets the author review before sharing, L03) | prompts that invite performance are dropped: Retro's "Took a nice fit pic?" and "Took a cute selfie?" (F-4) |
| The group, not the individual | one developing tile per group, no names or numbers (O-6) | no tally of who answered (Q-7); same question for all (Q-1) |
| Nothing gets lost | offline capture must queue the upload (Dispo offline behaviour); a photo whose upload finishes after 09:00 reveals on arrival | answers are ordinary posts and stay in the week |
| Invitations, never obligations | default "Now" (O-2); one push at the reveal, no countdown, no "don't miss" | no push (Q-5); removable card (Q-6); no gate (Q-7); no streak |

Flags:
- **F-1 (counts)** — Lapse's stack number, Dispo's "15 photos developing", Lapse's "5 snaps", 36-shot rolls: all
  rejected. No count is kept anywhere. The viewer's position badge "2 of 9" (O-9) is the one number and is Retro's
  existing viewer pattern (a position, not a tally) — listed so the owner can veto it.
- **F-2 (consent before reveal)** — nobody can see or delete an overnight photo before 09:00, the author included. A
  photo someone would not have shared becomes visible to the group at 09:00. Mitigations available today: the author
  deletes it after the reveal (normal delete), members report / block (`safety.*`). A "delete everything still
  developing" action has no reference → BLOCKED (§9).
- **F-3 (a second morning alert)** — groups with both a daily invitation and overnight photos may get two alerts in a
  morning. The reveal push is one per group per morning, silent in quiet hours, and has its own switch in
  `settings.notifications`.
- **F-4 (prompt list)** — the question list is copy, not data; every line must pass `retro.voice.prompt` and the
  "Real, not performed" tenet.

---

## 7. Mapping onto Retro's visual system (existing Jolt components and tokens only)

| our element | Jolt component · tokens | mechanic from |
|---|---|---|
| mode control "9 AM" · "Now" | **C-30** native segmented control on the camera's black media surface — Retro draws exactly this on its black "Create Recap" page: system control, full width inside the margins, between the header and the content card (TC-REC phone 1, `retro/press/tc-2023-12-recaps.png`: "Yearly · Monthly · Weekly · All Posts", Monthly selected); `haptic.global.select` on change | Dispo DX1 / DH-TP |
| its place | between the header (C-01) and the viewfinder: `size.global.titleToContent` (30) below the title baseline, then `size.global.sectionHeaderToContent` (11.7) to the viewfinder; the viewfinder shrinks (3:4 kept) per `camera.capture` § Structure 3 | Dispo order (control row above the camera) = Retro order (control above the content, TC-REC) |
| destination pill | **C-09** pill on media (fill `color.global.controlOnDeep`, `icon.global.group` + label, text role `pill`), centred, its bottom 20.5 pt above the viewfinder bottom (`camera.sendto.layout.messageField`), in the coach pill's slot | Dispo roll chips on the camera top bar (DUG phone 2; DH-TP) |
| destination sheet | `camera.sendto` group rows (C-16 + check circles) in a native sheet (C-29) | Dispo roll drawer |
| developing stack (camera) | the leading **C-11** 64-pt slot (library circle hidden in 9 AM mode); the stack drawing is **BLOCKED** (card geometry not measurable) — the slot stays empty meanwhile; never a number | Lapse stack (L01), number removed |
| developing tile (group) | **C-17 placeholder tile** (`size.global.stripTileWidth` × `.stripTileHeight`, fill `color.global.control`) with "Developing" centred, text role `tileLabel`, `color.global.textSecondary` | Retro C-17 / C-28; word from Dispo; centring from Lapse |
| reveal in place | C-17 insert motion: `duration.global.stripInsert` (250) + `duration.global.fade` from scale ≤ 0.875, `easing.global.standard`; Reduce Motion → cross-fade | Retro VM §D |
| reveal push | system notification; title `{group}`, one-line body (`retro.voice.push`) | Lapse banner structure |
| reveal sequence | `photo.viewer` with its position badge ("%1$d of %2$d") | Lapse L03; Retro viewer badge |
| question card | **feed card** of `groups.screen` §8: C-18 geometry (`size.global.friendCardWidth` × `.friendCardHeight`, `radius.global.card`); no answer yet → fill `color.global.control`, title text role `displaySmall` (`font.global.displayNarrow`) in `color.global.textPrimary`; with answers → newest answer photo + `layout.global.photoScrim`, title in `color.global.textOnMedia`; **C-09** light pill "Add a photo" | Retro prompt cards (R-NUX) + Apple eyebrow (AJ2) |
| question label | header line above the card: text role `listTitle`, `color.global.textPrimary` (the friend-card name slot, `size.global.cardHeaderGap`) | Apple eyebrow; Retro friend-card header |
| question on the camera | C-09 pill on media with the question (coach-pill slot) | BeReal prompts shown over capture (BR) |
| question remove | native context menu (C-29) item "Remove" | Apple (AJS) |

No new colour, size, radius, font or duration is introduced. Copy keys and proposed English text are in the two
surface specs.

---

## 8. Conflicts recorded

| conflict | references | resolution |
|---|---|---|
| default develop mode | Dispo default 9AM (DX1, DUG) vs Jolt camera's immediate posting (`camera.capture`) | default **Now** (tenet 5; keeps the existing camera spec) |
| segment order | Dispo `9AM · NOW`; Retro's own control does not put its selection first (TC-REC: Monthly, the 2nd segment, selected) | **"9 AM" · "Now"**, Dispo's order kept; "Now" selected by default |
| viewfinder | Dispo small window vs Lapse full | Lapse (O-3) |
| who reviews before sharing | Lapse: author reviews developed snaps, then adds to Journal (L03) vs Dispo: shot to a roll develops there automatically (DH-TP, search summary of Dispo site) | Dispo (the task's mechanic: revealed for everyone); risk F-2 |
| placeholder per photo vs one | Lapse per photo (LSE3) vs Dispo one banner (DLIB) | one (O-6) |
| reveal delay | Dispo 09:00 next morning vs Lapse 24 h (2021) / hours (press) | Dispo 09:00 (O-1) |
| shared vs personal prompt | Apple per person with refresh vs BeReal one moment for all | one for the group (Q-1) |

---

## 9. Still BLOCKED (never ships until closed)

| item | why | smallest capture / decision that closes it |
|---|---|---|
| reveal animation (the "moment") | no Dispo / Lapse recording reachable; until then the reveal uses Retro's strip insert motion | a screen recording (60 fps) of Dispo or Lapse at the moment photos develop, with the app open |
| developing stack drawing and capture → stack hand-off motion (camera, 9 AM mode) | stack measured only as a whole (L01 bbox incl. glow); motion not observed | one raw screenshot of Lapse's stack + a 60 fps recording of its shutter press up to the stack update |
| haptic on capture in 9 AM mode | Jolt's shutter plays none (`haptic.global.shutter`); Dispo "feedback on the device" is unspecified | one recording with haptics noted, or a lead decision to keep none |
| verbatim Dispo / Lapse reveal push text | only Lapse's marketing composite (with a count) found | an owner screenshot of either app's real "developed" notification |
| edge rule: photo taken at 08:59 reveals at 09:00 (seconds later) vs the next day | Dispo documents only "9 AM the next morning" / "every day at 9am" | an owner test in Dispo at 08:55 |
| "delete everything still developing" | no reference shows it (F-2) | lead decision (no reference needed if declined) |
| the "Develop" header label above the control | dropped for space (Dispo has it; Retro's TC-REC control has no label); comprehension of "9 AM · Now" alone untested | owner check with two non-technical members |
| question rotation order and the full list | Retro shows 8 prompts in a fixed order; no reference for a weekly group rotation | lead decision on the list (proposed in `question.weekly.md`) |
| weekly question default on / off for new groups | Apple: opt-in at first launch; Retro: reminder cadence chosen at onboarding | lead decision |
| question shown inside `photo.viewer` | no reference labels a photo viewer with a prompt | one screenshot of any app showing a prompt above an answer photo |
| Retro prompt-card layout | strings and background only (R-NUX); card not captured | one screenshot of Retro's "Ideas to share" card on iOS |

## 10. Sources not reachable

dispo.fun (connection reset / proxy 502); Lapse help (no help centre: Zendesk 404s, `help.`/`support.lapse.com`
refused, `lapse.com` Cloudflare 526); Medium press post (Cloudflare 403); TechCrunch images (404); TikTok `@getlapse`
listing (rate-limited after one call); Firecrawl (account out of credits). Details in each `INDEX.md`.
