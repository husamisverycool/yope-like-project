# Selfie reactions — reference research (BeReal RealMoji, with labelled gap fillers)

Researched 2026-10-16. Feature: in `photo.viewer`, besides emoji reactions (`chat.reactions`), a member reacts with a
quick front-camera selfie, shown as small circular faces on the photo. **Mechanics reference: BeReal RealMoji** (the
Instant RealMoji in particular). **Visual reference: Retro** (owner decision 2026-10-15): every visual value in the
proposed mapping (§7) is an existing Jolt token or component; BeReal supplies mechanics, placement and measured
alternatives only. Tenets (docs/CONVENTIONS.md §6) strip every count, unlock gate and "late" label (§6).

Evidence files: `references/auto/bereal/` (`INDEX.md`, section "Selfie reactions (RealMoji) — 2026-10-16") and the
owner capture `references/owner/bereal-06-realmojis-comments.webp` (CAPTURED; the same marketing panel as S7).
Coordinates are source-image pixels. Frame numbers are 1-indexed, #N at (N − 1)/30 s, as in `design/research/bereal.md`.

## 0. Sources and how they were used

| id | source | what it is | px → pt | quality | date |
|---|---|---|---|---|---|
| **AP** | App Store App Preview video (HLS `P1262494525`, variant 886×1920 gr290, 30 fps) from https://apps.apple.com/us/app/id1459645446 | Marketing video built from screen recordings. #351–#428 are at **1:1 screen scale** (header wordmark 162 px wide on #351, #419, #423, #427, as on the frames used by bereal.md) → **2.2545 px/pt** (886 px = 393 pt). #431 onward is an editor zoom-out (image edges move 2–3 px), so measurements stop at #427 | 2.2545 | H.264, lossy | poster 2026-01-30; listing v4.96.1 |
| **AP-D** | same video, #505 | Post detail inside an editor zoom: the phone screen is drawn 818 px wide (x 25–842, keyboard rows y 1150–1650) → **2.081 px/pt** (818 / 393) | 2.081 (±1 %) | lossy, scaled | 2026-01 |
| **H-RP** | help.bereal.com attachment 21088572284317 (article 16447267594141) | Raw iPhone screenshot 1179×2556, **3x**; full-bleed post (photo x 0–1178, bottom edge y 2045.5) with a RealMoji cluster | 3.000 | lossless PNG | 2024 (article edited 2024-06-18) |
| **H-IR** | help.bereal.com attachment 21083730462621 (article 17845941900445) | Raw 3x screenshot of the Instant RealMoji unlock screen; contains a **tilted** phone illustration (perspective), used for content only (which moods exist), never for sizes | 3.000 (screen); illustration not measurable | lossless | 2024 (edited 2024-05-15) |
| **S7** | `references/auto/bereal/store/bereal-store-07.png` (1284×2778), = owner `bereal-06-realmojis-comments.webp` | Marketing composite: the reaction bubbles are enlarged and pop out of the phone frame | ratios only, marketing | lossless composite | listing v4.96.1 |
| **S8** | `references/auto/bereal/store/bereal-store-08.png` (1242×2688) | Older marketing composite (2022 design, dimmed panel), in-phone stack + decorative floating bubbles | ratios only | lossless composite | listing v4.96.1 (older asset) |
| **HC** | help.bereal.com via the Zendesk API (`/api/v2/help_center/en-us/articles.json`, 66 articles; `/api/v2/help_center/articles/search.json?query=realmoji&locale=en-us`, 9 hits). The `…/en-us/articles/search.json` form given in the brief returns `RecordNotFound`; HTML pages are behind Cloudflare | Verbatim mechanics | — | official text | per row |
| **LK** (gap filler) | `design/research/locket.md` §"How reactions show on a photo" (AS-4 = `references/auto/locket/store/locket-store-04.png`; TikTok 7460656081153445163) | Locket's emoji reaction cluster on a photo | per locket.md | SOURCED | 2025 |
| **WA / IM / ST-R** (gap fillers) | as tabled in `design/surfaces/chat.reactions.md` | remove-your-own and list-order mechanics already adopted for emoji reactions | — | SOURCED | — |
| **WCAG** | W3C WCAG 2.2 SC 2.5.7 Dragging Movements (AA) and SC 2.5.1 Pointer Gestures (A), https://www.w3.org/TR/WCAG22/ | a single-pointer alternative is required for a drag gesture | — | VERIFIED | 2024-12-12 |

Not reachable (recorded in INDEX.md): YouTube (bot check / 403), TikTok tag and search pages, petapixel.com (403),
Firecrawl (out of credits). No official @bereal TikTok showing RealMojis could be located without search access;
the AP covers the Instant flow end to end instead.

---

## 1. Mechanics (verbatim, official)

| topic | BeReal text (verbatim) | source |
|---|---|---|
| what it is | "React to your friend's BeReal with RealMojis, personalized emojis created by you." | HC 7536240858653 (edited 2022-12-05) |
| the set | "There are six RealMojis, including an Instant RealMoji.⚡ An Instant RealMoji is a one-time live reaction to a BeReal." | same |
| open | "Tap the smiley face icon at the bottom right of your friend's BeReal or double-tap anywhere on the BeReal to open the RealMoji view." | same; repeated in 17845941900445 and 16447267594141 |
| create a mood RealMoji | "Choose the RealMoji you want to create." · "Tap the white button to capture your reaction." · "Tap "Continue" to save your RealMoji." · "Tap the RealMoji you just created to react to your friend's BeReal." | 7536240858653 |
| take an Instant RealMoji | "Press and hold the Instant RealMoji button." · "Drag your finger to the middle of the screen and release it once you're ready to capture your Instant RealMoji." · "Once captured, your Instant RealMoji will be directly sent to the BeReal you want to react to." | 17845941900445 (edited 2024-05-15) |
| unlock gate (do-not-copy) | "To unlock your Instant RealMoji, you need to send a certain number of RealMoji. The specific number can be found on the Instant RealMoji screen." Screen: `UNLOCKABLE`, `10/20`, `Send 20 RealMoji to Unlock` | 17845941900445; H-IR |
| one per post, replace | "The rule is one RealMoji per BeReal. However, you can change your RealMoji reaction at any time." (tap another RealMoji) | 7536240858653 |
| delete a stored mood selfie | "You cannot directly replace a RealMoji. You'll need to delete it … and creating a new one." · "Long press the RealMoji you want to delete until a red cross appears." · "Tap the RealMoji you want to delete, and confirm your choice." · "You cannot recover a RealMoji once deleted." | 7536240858653 |
| own post | "Real tip! You cannot react to your own BeReal." | 7536240858653 |
| author removes others' | "You can delete RealMojis and comments left by other users on your BeReal." · "Tap the RealMoji reactions under your BeReal." · "Long press the RealMoji you want to delete." · "Tap the option to delete." | 7545622582429 (2022-11-03) |
| report one | "Tap the RealMoji you want to report." · "Tap the three-dot menu in the top right." · "Select the report option." | 10100086147229 (edited 2026-09-17) |
| who sees | Friends' posts: the post's audience (no restriction stated). Friends of Friends feed: "You can react to BeReal in the Friends of Friends feed with RealMoji but can't leave or view comments." RealPeople: "Other users can only view a selection of random RealMojis" (not applicable) | 11773264475933; 16447267594141 |
| archive | "RealMojis and comments are now saved to Memories." (Memories are private to the poster) | 7531349180829 (edited 2025-04-08) |
| store listing | "React on your friend's BeReal with a RealMoji, your own emojis representation" (lead, apkmirror listing copy; not re-verified on the store page) · Google Play: "WIDGETMOJI • See your friends right on your Home Screen when they react to your BeReal with a widget." · Google Play uses the word **"selfie"** for the front-camera photo ("designed to take both a selfie and a frontal photo simultaneously", bereal.md §2) | Play listing 2026-10-07 |
| notification | **Not found.** No help article quotes a RealMoji push; the only reaction-related system surface found is the Android WIDGETMOJI widget | HC (66 articles grepped for notif/push × react/RealMoji) |

**The six RealMojis** (H-IR illustration, content only): five moods with emoji badges **👍 😃 😲 😍 😂** and a sixth
dark circle with a yellow **⚡** (the Instant button), in one row over the bottom of the post image.

---

## 2. Taking one — the Instant RealMoji capture layer (AP, 2026)

Sequence observed in AP (#351 → #427). The touch indicator (grey disc) of the screen recording is visible.

| phase | frames | time | observation |
|---|---|---|---|
| before | #351–#356 | 11.667–11.833 s | feed post; action column inside the image at the right: send, comment, **smiley** (bottom); no reaction stack shown on this post yet |
| layer fades in | #357–#365 | 300 ms | an opaque grey card replaces the post card; circle, hint text, target ring and second hint fade in together. Card patch luminance 5.0, 11.4, 18.2, 25.0, 31.2, 38.1, 44.2, 52.2, 58.9 → **linear**, 9 frames |
| waiting | #365–#391 | ≥ 870 ms | live front-camera image in the circle (subject moves); header, wordmark and feed tabs unchanged above |
| slide | #384–#392 | — | the touch indicator travels from the action column (right) into the target ring under the circle |
| armed | #393/#394–#405 | ≈ 370–400 ms | a **white ring** grows from the target ring to just inside the circle edge; top-edge position per frame from #397: 698, 663, 638.5, 621.5, 608, 598.5, 592, 588.5, 587.5 px (steps 35 → 1 px: decelerating); settled at #405 |
| held | #405–#410 | ≥ 200 ms | ring held; release time not visible |
| capture | #411 | 1 frame | everything below the header turns **white** (255; header unchanged at mean 10.9); #412 156, #413 38, #414 18, #415 0 → flash and layer gone in ≈ 133 ms |
| land | #413–#421 | ≈ 267 ms | the frozen circle shrinks and moves down-left into the stack at the image's bottom-left; it joins at the **leading** end (#423) |
| bubbles | #413–#437+ | ≥ 800 ms | faces with emoji badges rise from the stack along the left edge and fade (visual effect, §6) |

Help text matches the AP: "Press and hold the Instant RealMoji button. Drag your finger to the middle of the screen and
release it once you're ready to capture" — the circle's centre is at the screen's vertical middle (below).

### Measured values (AP #375 unless stated; pt = px / 2.2545)

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| 342.4 × 645.9 pt; x 21.1 pt from the left, 29.6 pt from the right (the 2026 feed card is off-centre: horizontal pager); top 175.4 pt | grey card under the circle (covers the post card) | `frames/appstore-preview-2026_t12.47s_instant-realmoji-capture.png` | x 47.53–819.47, y 395.48–1851.68 | half-max crossings, medians of 30 rows / 40 columns | ±0.5 pt | SOURCED |
| (64, 57, 52) ≈ #403934, uniform (row 1800 luminance 56–59 across the card) | card fill | same | (100–300, 1700–1850) | median | ±3/255 (lossy) | SOURCED |
| **338.2 pt** photo diameter (762.5 px; vertical 762, horizontal 763) = **0.988 × card width** | live circle | same; stable #363–#413 | inner edges top 578.5, bottom 1340.5, left 52.5, right 815.5 | first non-dark pixel after the border, rows/columns through the centre | ±0.5 pt | SOURCED |
| **3.4 pt** (7.65–7.8 px), black (0–3) | circle border | same | top 570.85→578.5; bottom 1340.5→1348.3 | half-max outer edge to inner edge | ±0.5 pt | SOURCED |
| centre x 192.5 pt (= card centre 192.3); centre **y 425.6 pt of an 852-pt screen (0.4995)** | circle centre | same | (434.0, 959.5) | midpoint of edges | ±0.5 pt | SOURCED |
| bold, white (≥ 235), ink 238.6 × 22.2 pt (no descenders: ascender-to-baseline), ink centre 2.2 pt above the circle centre; centred on x | hint "Slide here to react" | same | ink x 165–703, y 930–979 | threshold-235 bbox | ±0.5 pt | SOURCED |
| outer diameter **72.7 pt** (164 px), stroke **2.4 pt** (≈ 5.5 px FWHM), luminance 156 over the 58 fill (≈ white at 50 %) | target ring | same | outer x 351.5–515.5, bottom 1426.5; stroke at col 433 y 1427–1432 | threshold-110 bbox; FWHM | ±1 pt / ±0.5 pt | SOURCED |
| centred on the circle's bottom border point (ring centre y 1344.5 vs border centre line 1344.4) | target ring position | same | — | difference | ±0.5 pt | SOURCED |
| BeReal's own capture shutter is 74.0 pt (bereal.md §2): the target ring is 1.3 pt smaller | target ring vs shutter | AP #106 | — | comparison | — | SOURCED |
| bold, ink 91.4 × 9.8 pt (ascender height), colour (111, 103, 100) ≈ white at 25 % over the fill; top 16.2 pt below the ring | hint "Slide in to send" | same | ink x 331–537, y 1463–1484 | threshold-85 bbox; top-10 % median | ±0.5 pt | SOURCED |
| white (all channels ≥ 235), stroke ≈ 2.7 pt (6 px), its outer edge 4.0 pt inside the circle's photo edge | armed ring | `frames/appstore-preview-2026_t13.47s_instant-realmoji-armed.png` (#405) | top 585–590 vs photo edge 578.5 | threshold bbox along x 425–443 | ±0.7 pt (lossy) | SOURCED |
| none (no "Continue", no preview): sent on release | confirmation step (Instant) | AP #405–#423; HC 17845941900445 | — | — | — | SOURCED |

Fonts: not identifiable (bereal.md §2). The live image is the front camera; whether the stored selfie is mirrored is
**not observable**.

### Mood RealMojis (stored, reusable) — capture screen not found
The mood flow ("Choose the RealMoji you want to create", "Tap the white button", "Continue") has **no image** in any
reachable official source: the store panels, help attachments and AP show only the Instant flow and the results. Its
capture-screen geometry is **not found** (tried: App Store / Play screenshots, 66 help articles and their attachments,
AP, YouTube and TikTok — blocked).

---

## 3. How RealMojis show on a post

### 3a. Feed stack (AP #427, 2026, 1:1)

`frames/appstore-preview-2026_t14.20s_realmoji-stack.png`; main image edges x 49.0 (half-max at row 1519) and bottom
y 1601.6 (column 231); image width 763 px = 338.4 pt.

| value | element | px coords | method | precision | level |
|---|---|---|---|---|---|
| bottom-**left** corner of the main image, over the photo | stack position | — | observation (#419–#428) | — | SOURCED |
| **42.6 pt** outer diameter (96 px; same on both axes; stable #421–#428) = 0.126 × image width | stack circle | third circle: x 182.5–278.5 (row 1519), y 1471.5–1567.5 (col 234) | half-max outer edges | ±0.5 pt | SOURCED |
| 1.1–1.3 pt (2.5–3 px), black (0–3) | circle border | runs 274–277 / 1565–1567 | dark-run width | ±0.5 pt (lossy) | SOURCED |
| step **26.6 pt** (60.0 px) centre to centre; overlap 16.0 pt (0.375 × diameter) | stacking | outer left edges 62.5, 122.7, 182.5 | half-max crossings, row 1519 | ±0.5 pt | SOURCED |
| each circle to the right is drawn **over** the one to its left | z-order | #427, #431; also S8 | observation | — | SOURCED |
| 6.0 pt from the image's left edge; 15.2 pt from its bottom edge | insets | 62.5 − 49.0; 1601.6 − 1567.3 | difference | ±0.5 pt | SOURCED |
| 3 circles: 2 faces + a third face under **"+7"** (do-not-copy) | visible count | #415–#427 | observation | — | SOURCED |
| the newest joins at the **leading** (left) end | order | #421–#423 | observation | — | SOURCED |
| stack circles carry **no** emoji badge (the rising bubbles and the detail row do) | badges | #427 | observation | — | SOURCED |

### 3b. Feed cluster (H-RP, 2024, lossless 3x) — the only lossless measurement of a RealMoji on a post

`help/help-21088572284317_realpeople-realmoji-comments-3x.png`; full-bleed photo, width 393 pt.

| value | element | px coords | method | precision | level |
|---|---|---|---|---|---|
| **56.0 pt** outer diameter (168 px both axes) = 0.1425 × photo width | largest (front, newest-looking) face | x 49.0–217.0 (row 1914), y 1828.8–1996.7 (col 134); circle fit centre (133.5, 1912.9) | half-max edges; least-squares fit to border pixels | ±0.3 pt | SOURCED |
| **2.0–2.1 pt** (5.8–6.4 px), **#000000** exact | face border | left 49.0→55.3; top 1828.8→1835.2; bottom 1990.9→1996.7 | outer to inner half-max | ±0.2 pt | SOURCED |
| **16.3 pt** from the photo's left edge and **16.3 pt** from its bottom edge (equal) | insets | 49.0 px; 2045.5 − 1996.7 = 48.8 px | difference / 3 | ±0.2 pt | SOURCED |
| 42.2 pt (126.6 px), centre (+18.1, −30.5) pt from the first | second face | centre (187.8, 1821.4) | RANSAC + least-squares circle fit | ±0.5 pt | SOURCED |
| 34.0 pt (≈ 102 px), centre (−26.6, −20.4) pt from the second | third face | centre (107.9, 1760.1) | same | ±0.7 pt | SOURCED |
| faces shrink upward (×0.754, ×0.806): a rising arc, not a row (consistent with the rising bubbles of AP §2; a still of the same effect cannot be told apart from a resting layout) | cluster shape | — | — | — | SOURCED |
| emoji ink ≈ 16.3 pt (49 px) = 0.29 × face diameter; centre at 45° bottom-right, 0.86 × the outer radius from the face centre (overlaps the border) | emoji badge (😍) | ink x 160–209, y 1940.7–1989.3 | zoomed read | ±0.5 pt | SOURCED |

### 3c. Who reacted — post detail row (AP-D #505)

`frames/appstore-preview-2026_t16.80s_post-detail-realmojis-row.png`; pt = px / 2.081.

| value | element | px coords | precision | level |
|---|---|---|---|---|
| header `RealMojis` (bold, white) followed by a grey count `5` (**do-not-copy**) | section header | ink x 52–261, y 684–720 | — | SOURCED |
| a **horizontal row**: 5 faces fill the 393-pt width (more would scroll — not shown) | layout | — | — | SOURCED |
| face diameter **62.7 pt** (130–131 px); no visible border on black | face | x 54–183, 216–346, 378–508, 542–662, 704–833 at y 812 | ±1 pt | SOURCED |
| step 78.1 pt; gap 15.4 pt; first face 13.9 pt from the screen edge | spacing | lefts 54, 216, 378, 542, 704; screen left 25 | ±1 pt | SOURCED |
| emoji badge at the face's bottom right (every face) | badge | — | — | SOURCED |
| username under each face, bold white, ink height 10.1 pt, 8.2 pt below the face, centred; long names fade out at the right edge (gradient truncation) | name | ink y 896–916 | ±1 pt | SOURCED |
| comment field + keyboard directly below (comments share the detail page) | context | — | — | SOURCED |

### 3d. Marketing composites (ratios, not used for values)

| panel | what | ratio | note |
|---|---|---|---|
| S8 (2022) | in-phone stack at the bottom-left: 3 faces + a dark `+4` circle, black borders, trailing over leading | diameter / image width 0.072; step / diameter 0.86 (overlap 0.14 × d) | older, smaller and tighter than 2024–2026; floating white-ringed bubbles around the phone are decoration |
| S7 (2026) | 2 faces with emoji badges + a black `3+` circle at the image's bottom-**right**, popped out of the phone with a glow | ≈ 0.22 × image width | enlarged marketing; contradicts AP (bottom-left, 0.126) |

### 3e. Tap behaviour

- Tap the reactions → the list of RealMojis on the post ("Tap the RealMoji reactions under your BeReal", HC
  7545622582429); in 2026 the post detail shows them as the row in §3c.
- Tap one RealMoji → a view of that RealMoji with a "three-dot menu in the top right" (report path, HC 10100086147229).
  **Its layout is not found.**
- Long press one (author) → delete option (HC 7545622582429). Long press your stored mood RealMoji → red cross →
  delete (HC 7536240858653).

---

## 4. Gap fillers (labelled; used only where BeReal is silent or conflicts with Retro)

| gap | filler | evidence | level |
|---|---|---|---|
| placement of reactions over a photo | **Locket** also puts its reaction cluster at the photo's **bottom-left**, no numbers, items 39 pt with a 27-pt step, insets ≈ 17 / 20 pt | `design/research/locket.md` l.423–457 (AS-4) | SOURCED |
| step between overlapping items | BeReal 26.6 pt (AP) and Locket 27 pt (AS-4) agree within 0.4 pt | above | SOURCED |
| remove your own reaction by tapping it in the list | WhatsApp ("tap your reaction to remove it"), Messages (tap again) — already adopted as `chat.reactions.layout.unreact` | `design/surfaces/chat.reactions.md` WA, IM | SOURCED |
| who-reacted order | newest first (Stream Chat SDK) — `chat.reactions.layout.listOrder` | ST-R | SOURCED |
| alternative to the hold-and-drag gesture | required: "All functionality that uses a dragging movement for operation can be achieved by a single pointer without dragging" (SC 2.5.7, AA). BeReal's own mood flow is tap-based ("Tap the white button to capture") | WCAG 2.2; HC 7536240858653 | VERIFIED / SOURCED |
| release outside the target | BeReal: not documented. Platform: a control acts on touch-up **inside** (UIKit `.touchUpInside`; Compose `waitForUpOrCancellation` returns null when the pointer leaves the bounds) | https://developer.apple.com/documentation/uikit/uicontrol/event/touchupinside ; https://developer.android.com/reference/kotlin/androidx/compose/foundation/gestures/package-summary#waitForUpOrCancellation (API facts, not re-fetched) | PLATFORM |
| haptics | not observable in a screen recording; platform tokens apply | `haptic.global.*` | PLATFORM |
| Instagram story reactions / iMessage Tapbacks with faces | not needed: neither shows a face reaction on a photo; Tapbacks are emoji / sticker only (IM evidence above) | — | — |

---

## 5. Who sees what (BeReal → Jolt mechanics)

| question | BeReal | source |
|---|---|---|
| who can react | anyone who can see the post, except its author | HC 7536240858653 ("You cannot react to your own BeReal") |
| how many per person | one per post; a new one replaces yours | HC 7536240858653 |
| who sees a reaction | everyone who sees the post (friends; FoF viewers see RealMojis but not comments); author always | HC 11773264475933 |
| what the author sees | the stack on the post; the full list on the detail page; can delete others' RealMojis | AP; HC 7545622582429 |
| remove your own | "change your RealMoji reaction at any time" (replace); removal path for an Instant one not documented | HC 7536240858653 |
| notification to the author | **not found** (no official push text) | — |
| kept after the day | saved to the poster's private Memories | HC 7531349180829 |
| report | per RealMoji, from its own view | HC 10100086147229 |

---

## 6. Must NOT be copied

| item | where | why |
|---|---|---|
| `RealMojis 5` header count; `+7`, `+4`, `3+` overflow circles; `View all 42 comments`; `💬 37` | AP-D, AP #415–#427, S8, S7, H-RP | tenet: no counts |
| Instant RealMoji **unlock gate**: `UNLOCKABLE`, `10/20`, `Send 20 RealMoji to Unlock` | H-IR, HC 17845941900445 | counts + an obligation to react to earn a feature (tenets 2 and 5) |
| `5 min late` post-header label | AP #351 | tenet: no "late" |
| the names "RealMoji", "Instant RealMoji", "WIDGETMOJI", "BeReal", the wordmark (feed header, image watermark), "Friends of Friends" | everywhere | trademarks / branding (CONVENTIONS §4) |
| stored mood selfies reused on every post (👍 😃 😲 😍 😂 set) | HC, H-IR | a pre-posed face reused across posts is performed, not real (tenet 2); the live Instant mechanic stays |
| the ⚡ "instant" badge and emoji badges on faces | H-IR, H-RP, AP | only meaningful with the mood set; Jolt's faces are all live |
| rising-bubble burst and fly-to-stack animation | AP #413–#437 | another app's visual effect (same rule as RS-8 for Locket's rain / fly-to-cluster) |
| the white full-screen capture flash | AP #411–#415 | a visual effect; `camera.capture` has no capture flash (shutter press = platform default) |
| the warm grey card colour #403934 | AP #375 | BeReal palette; Retro supplies colours |
| "random selection" visibility for public accounts | HC 16447267594141 | not a Jolt concept |

---

## 7. Proposed mapping onto Retro (existing Jolt tokens and components)

Composition record: `level: SOURCED`, `method: "composition of Retro components C-22, C-23, C-09, C-11, C-29, C-16,
C-27 in BeReal's Instant RealMoji order"` (components.md rule). Nothing below is a new visual value except the three
rows marked **new token**, each with BeReal evidence.

| part | BeReal (mechanics / measured) | Jolt mapping | evidence for the mapping |
|---|---|---|---|
| entry | hold the smiley at the post's bottom right, slide | **touch and hold** the viewer footer's add-reaction glyph `chat.reactions.icon.add` (`face.smiling`, BeReal's smiley); tap keeps opening the emoji picker | AP #351–#392; HC 17845941900445 |
| single-pointer entry | mood flow is tap-based | context-menu item (C-29) and accessibility action "React with a selfie" → layer in **tap mode** | WCAG 2.5.7; HC 7536240858653 |
| double-tap to open | yes (BeReal) | **not adopted**: a viewer tap advances (`photo.viewer.layout.advance`) | photo.viewer.md |
| layer panel | opaque grey card over the post | full-width panel over the viewer's scroll area, `color.global.controlOnDeep` (#262626, Retro's opaque grey on media), corners `radius.global.photo` (0) | AP #375; components C-11 / C-22 |
| live circle diameter | 0.988 × the post card | `camera.capture.layout.viewfinder` width rule: screen − 2 × `size.global.screenMargin` (361 at 393) | AP #375; capture.json |
| circle centre | screen's vertical middle; horizontally centred | same | AP #375 (425.6 / 852 pt); HC "middle of the screen" |
| circle border | 3.4 pt black | **new token** `viewer.selfiereaction.size.captureBorder` = 3.4, colour `color.global.backgroundDeep` (Retro media black, the colour BeReal's border already matches, as in `daily.dualimage`) | AP #375 |
| hint over the circle | bold white line | C-09 coach pill on media (`camera.capture` coach anatomy: `color.global.controlOnDeep`, text role `pill`, `color.global.textOnMedia`, `size.global.pillHeight`), centred on the circle | AP #375; camera.capture.md |
| target ring | 72.7-pt ring, 2.4-pt stroke, ≈ white 50 %, centred on the circle's bottom edge | ring with the geometry of Jolt's shutter outer ring: `camera.capture.size.shutterOuter` (86), stroke `camera.capture.size.shutterRing` (4.5), no disc, colour `color.global.textSecondary` (dark #999999); centred on the circle's bottom edge | BeReal's ring ≈ its own shutter (72.7 vs 74.0 pt), so Jolt's ring = Jolt's shutter ring |
| hint under the ring | ≈ white 25 %, 16.2 pt below the ring | text role `meta` (13), `color.global.textSecondary`, `size.global.screenMargin` below the ring | AP #375; Retro secondary on media |
| armed ring | white, ≈ 2.7 pt, 4.0 pt inside the photo edge | `color.global.textOnMedia`, stroke `photo.viewer.layout.avatarRing.strokeWidth` (2.0), inset `photo.viewer.layout.avatarRing.gap` (3.0) inside the photo edge (Retro's white viewer ring) | AP #405; TC-2B ring |
| capture | on release inside; no preview | same; tap mode: tap the target ring | AP #411; HC |
| cancel | not documented | release outside the circle and the ring = no action (PLATFORM); tap mode: tap the panel outside the circle, Android back, iOS escape | §4 |
| face size on the photo | 42.6 pt (2026) / 56.0 pt (2024) | `size.global.avatarHeader` (40.7, ring included — Retro's viewer avatar) | AP #427; C-22 / C-23 |
| face ring | black 1.1–2.0 pt | C-23 stack ring in Retro's white: `color.global.textOnMedia`, width `photo.viewer.layout.avatarRing.strokeWidth` (2.0; equals BeReal's lossless 2.0) | C-23 (white ring; width Gap), TC-2B, H-RP |
| overlap | 16.0 pt (BeReal) / ≈ 12 pt (Locket) | **conflict**: C-23 `size.global.avatarStackOverlap` (3, Retro) is used; BeReal/Locket's 26.6–27-pt step is the alternative (lead to resolve in MERGE_DECISIONS) | C-23; AP; LK |
| position | bottom-left over the photo; insets 6.0/15.2 (2026), 16.3/16.3 (2024); Locket ≈ 17/20 | bottom-**leading** corner of the photo, `size.global.screenMargin` (16) on both axes (aligns with the footer text column; BeReal 2024 16.3) | H-RP; LK; photo.viewer footer |
| visible faces | 3 incl. a counter | `chat.reactions.count.clusterMaxVisible` (3), **no counter** | AP #427; WhatsApp |
| order / z | newest leading; trailing drawn on top | `chat.reactions.layout.clusterOrder` (newest leading); trailing on top | AP #423 |
| tap the stack | opens the list | opens the Reactions sheet (`chat.reactions.layout.list`), selfie rows mixed with emoji rows by time | HC 7545622582429; chat.reactions.md |
| list row | 62.7-pt face, name under, horizontal row | C-16 row: the selfie as the row avatar (`size.global.avatarPicker`), name, line `viewer.selfiereaction.activity.row` | chat.reactions.md (RS-8) |
| remove your own | replace any time | tap your row → remove (`chat.reactions.list.removeHint`); a new selfie replaces yours | HC; WA / IM |
| author removes others' | long press → delete | **new mechanic, needs backend**: long press a row on your own photo → C-29 menu "Remove" | HC 7545622582429 |
| report | ••• → report | row long press → "Report" → `safety.report` (needs a `reaction` kind) | HC 10100086147229 |
| layer in / out | 300 ms linear fade | `duration.global.fade` (150) + `easing.global.standard` | Retro house fade |
| face enters the stack | shrink-and-fly ≈ 267 ms + bubbles | layer fades out; the new face enters with `spring.global.playful` (Retro "avatar entries") | Retro RP; RS-8 rule |
| notification | not found | `notifications.push.reaction.*` pattern (`messaging.reaction`), channel "Post Activity" | capture.json |

New tokens proposed (not written to `design/tokens/*.json`; the consolidation pass adds them):

| token | value | evidence | level |
|---|---|---|---|
| `viewer.selfiereaction.size.captureBorder` | 3.4 pt | AP #375 top 570.85→578.5, bottom 1340.5→1348.3 (/2.2545) | SOURCED |
| `viewer.selfiereaction.layout.captureCircle` | {diameter: "screen − 2 × size.global.screenMargin", centre: "screen vertical middle, horizontally centred", fit: "aspect-fill, live front camera"} | AP #375 centre 425.6 / 852 pt; HC "middle of the screen" | SOURCED |
| `viewer.selfiereaction.layout.stack` | {anchor: "photo bottom-leading", inset: "size.global.screenMargin both axes", face: "size.global.avatarHeader", ring: "color.global.textOnMedia, 2.0", overlap: "size.global.avatarStackOverlap", max: "chat.reactions.count.clusterMaxVisible", order: "newest leading", z: "trailing on top"} | H-RP, AP #427, LK, C-23 | SOURCED |

### Still BLOCKED

| value | why | smallest owner capture |
|---|---|---|
| enlarged view of one selfie (tap a face / row) | BeReal's single-RealMoji view not found | one screenshot of a tapped RealMoji in BeReal |
| whether the stored selfie is mirrored | not observable in a recording | one RealMoji taken holding up text, then viewed |
| selfie still vs short clip; stored resolution / crop | not observable | — (product decision on the brief: still) |
| maximum hold time; behaviour when the hold ends outside | not documented (PLATFORM fill used for "outside") | 20-s recording: hold, slide out, release |
| Android capture layer | all sources are iOS | one Android screen recording of an Instant RealMoji |
| BeReal push text for a RealMoji | not found | one screenshot of the push after a friend reacts |
| camera-permission-denied state inside the layer | not observed in BeReal | — (Jolt `camera.capture.denied.*` reused) |
| armed-ring and landing curves | durations only (lossy 30 fps) | 60 fps recording |
| overlap of stacked faces | Retro C-23 (3) vs BeReal / Locket (≈ 12–16) | lead decision (MERGE_DECISIONS) |

### Tenet risks

1. **Counts** — BeReal shows `RealMojis 5`, `+7`, `3+`; the stack must never show a number, and neither may the sheet,
   pushes or accessibility labels (names only).
2. **Unlock / earn** — the Instant gate ("Send 20 RealMoji to Unlock") turns reacting into a quota; selfie reactions are
   available to every member from the start.
3. **Performed faces** — the stored mood set reuses one posed face on every post; only live capture is built.
4. **Pressure from visibility** — faces on someone's photo show who reacted; there is no "seen" list and no list of who
   did not react. Removing your own selfie is always one tap away.
5. **Faces leaving the group** — a selfie reaction is another person's face: it is never saved to the camera roll or
   shared outside the app (owner decision 12), and it is removed with the reactor's account, with a block, and with the
   photo (`delete_media` cascade).
6. **Notifications** — one push per selfie reaction on the existing "Post Activity" channel, no "and N others".
