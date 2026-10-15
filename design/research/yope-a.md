# Yope — research pass A (auth, onboarding permissions, groups, camera, foundations, copy voice)

Researcher: yope-a · Date: 2026-10-15 · Reference app: **Yope** (`yope: friends-only social game`, Salo App, Inc.),
App Store id1600195477 listing version **1.229.0** (released 2026-10-01), Google Play `app.salo` (updated 2026-09-29).
Companion pass: `design/research/yope-b.md` (chat, walls, recaps). Where both passes measured the same thing, the
conflict is noted, not resolved.

## 0. Sources and method

### 0.1 Evidence used

| id | file (repo-relative) | source | date / version | notes |
|---|---|---|---|---|
| S1–S7 | `references/auto/yope/store/yope-store-01..07.png` (1242×2688) | App Store screenshots (see `references/auto/yope/INDEX.md`) | listing 1.229.0 | original PNGs; marketing mocks (see 0.3) |
| L | `references/auto/yope/store/listing.html` | https://apps.apple.com/us/app/id1600195477 | fetched 2026-10-15 | JSON blob inside: description, full version history 1.201.2–1.229.0, developer replies to reviews, age rating, IAP |
| P1–P5 | `references/auto/yope/play/a-play-01..05.png` (1080×1920) | https://play.google.com/store/apps/details?id=app.salo&hl=en_US, images `play-lh.googleusercontent.com/{KXJBNhu…,NYFbbHm…,2eqEnDU…,CaO2EUM…,CfQKnoV…}=w2560` | Play "Updated on Sep 29, 2026" | same campaign as iOS; P5 = profile ("collect best memories in your profile") |
| V-virgi | `references/auto/yope/frames/a-virgi-7686278541255642390-*.png` | https://www.tiktok.com/@virgi.lifestyle/video/7686278541255642390 | posted 2026-09-16 | **full onboarding walkthrough**, Spanish (es) locale; 576×1024, 30 fps |
| V-mthu | `frames/a-itsmthuyope-7644974799302823175-*.png` | https://www.tiktok.com/@itsmthuyope/video/7644974799302823175 | posted 2026-05-28 | **group creation flow**, UI in English; 576×1024 |
| V-chuong | `frames/a-chuongxetank-7694968408424582452-*.png` | https://www.tiktok.com/@chuongxetank/video/7694968408424582452 | posted 2026-10-10 | camera, send-to, contacts card; English; 576×1024 |
| V-sav | `frames/a-savannahclooney-7683341732695592206-*.png` | https://www.tiktok.com/@savannahclooney/video/7683341732695592206 | posted 2026-09-09 | home list, send-to; English; 720×1280 |
| V-jacob | `frames/a-jacob-7691153057177931039-*.png` | https://www.tiktok.com/@jacob.jessi/video/7691153057177931039 | posted 2026-09-30 | camera, send-to; English; 720×1280 |
| V-arkadeep | `frames/a-arkadeep896-7644663053807586591-t32.73-profile-recaps-empty-skip-queue.png` | https://www.tiktok.com/@arkadeep896/video/7644663053807586591 | posted 2026-05-27 | own profile recaps tab empty state, 3-item tab bar; English |
| V-alexaa | `frames/a-alexaa-7684388619099933966-t5.23-camera-hold-to-record-tabbar.png` | https://www.tiktok.com/@alexaa.yope/video/7684388619099933966 | posted 2026-09-11 | camera with tooltip and 5-item capsule tab bar; English; 720×1280 |
| V-yrrah24 | `frames/a-yrrah-{7454430216123862280,7434441926000037121,7452976839846382855}-*.png` | https://www.tiktok.com/@yrrah.yope/video/7454430216123862280 , …/7434441926000037121 , …/7452976839846382855 | posted 2024-11-07 … 2024-12-31 (**older than 12 months**, pre-1.206 "cleaner onboarding") | sign-up, purpose strings, invite link, group menu, members list, create group (old build) |
| BI | `references/auto/yope/web/a-bi-2025-onboarding-composite.jpg`, `a-bi-2025-create-group-composite.jpg` | Business Insider via AOL, https://www.aol.com/trying-buzzy-social-media-platform-110601376.html | 2025-03-09 (older than 12 months) | onboarding + create-group screenshots |
| W-inv | `references/auto/yope/web/a-yope-tv-invite-expired-393w.png` | https://yope.tv/i/8a61w (Playwright, 393×852 @3x, iPhone UA) | live 2026-10-15 | expired-invite web page + its CSS (`/_next/static/css/af7c918c1d60a4a0.css`, `bb6277609d714d54.css`) |
| W-site | (CSS text only) | https://yope.app/ (`:root` custom properties) | fetched 2026-10-15 | website tokens; **not** the app |
| T | (text) | https://www.yope.tv/legal (Terms of use + Privacy policy; linked from the App Store "Privacy Policy") | fetched 2026-10-15 | age, phone, verification, birthday, contacts |
| O | `references/owner/yope-0*.webp`, `yope-*.jpg` | owner INSPO (CAPTURED) | see owner INDEX | cross-checks only (lower resolution than S1–S7) |

Owner images were used as second images where they overlap (tab bar: `references/owner/yope-01-find-friends-profile.webp`
= S2; composer: `yope-04-chat.webp` = S5; header: `yope-05-hourly-group.webp` = S1). The owner `.webp` panels are a
460-px re-encode of the same App Store panels, so they are not independent of S1–S7; independence comes from the videos.

### 0.2 Search log (what was tried)
- App Store page JSON (`listing.html`): full description, version history, 8 developer replies, age rating, IAP.
- Google Play page: description, "Rated for 12+", 5M+ downloads, 5 screenshots.
- yope.app (site CSS + text), yope.app/press, yope.app/careers, creators.yope.app, yope.tv/legal, an invite link (yope.tv/i/8a61w).
- `www.yope.app` failed TLS (self-signed upstream certificate); `yope.app` works.
- TikTok: rendered discover pages (`yope-app-tutorial`, `how-to-use-yope-app-for-friends`, vi/th/ja variants), tag pages
  `#yopeapp` / `#yope`, profiles @yopeapp, @yrrah.yope, @alexaa.yope, @memories.withzoe, @jessicaa.yope, @kaitlyn.yope,
  @yope.ellie with Playwright; ~500 candidate URLs → metadata with yt-dlp → 57 downloaded to `/tmp/claude-0/yope-a/vids/`
  (scratch, not committed) → contact sheets → 8 videos used.
- Press: TechCrunch/PetaPixel (via earlier dossiers), Business Insider (screenshots used), EFTM 2025-12 (photos of a
  phone, too oblique to measure), Qustodio (no app screenshots). eSafety page reset the connection.
- Not reachable: Instagram @yope.app (login wall), Firecrawl (account out of credits), Mobbin/Lazyweb/ScreensDesign
  (no Yope entry), YouTube (bot-blocked per brief, not attempted).
- WebSearch for phone/verification/birthday screens: no Yope-specific results.

### 0.3 Measurement method
- **Store PNGs (S1–S7)**: phone screen width found by scanning rows for the black bezel (lum < 8–12). S5 inner screen
  x 189…1074 at y 2000 → **885 px**; S2 x 182…1068 at y 1800 → **886 px**; S1 x 120…1107 at y 800 → **987 px**.
  `pt = px / screen_px × 393` (393 pt assumed — the brief's default; the home indicator in S2 measures 295 px = 130.9 pt,
  consistent with a 393-pt-class device, iOS draws it ~134 pt). S5/S2 phones are rotated ~1.7° (bezel shifts 3 px per
  100 rows); widths corrected by cos θ (negligible) and heights of wide elements corrected for tilt where noted.
  **S1's photo cards overflow the bezel (marketing scale-up) and S3 (lock screen) is an illustration** (its flashlight
  button is 180 px = 20 % of screen width, impossible on a real lock screen) — neither is used for sizes.
- **Colors**: median of an eroded mask (5×5 or 7×7 erosion so anti-aliased edges are excluded) or a 5×5/9×9 box with
  sd ≈ 0. Store PNGs are lossless; video colors are H.264 and read **darker** than the PNG for the same surface
  (group-chat background: PNG #171717 vs video #101010), so video colors carry ±8/255.
- **Videos**: every video uses the same creator template (lime outline). Inner screen = x 56…519 (464 px) in 576-px
  videos → **1.181 px/pt**; x 72…647 (576 px) in 720-px videos → **1.466 px/pt** (393 pt assumed). Content margins are
  symmetric inside those bounds (e.g. "create group" button 22 px / 23 px), which supports the bounds. Device width is
  unknown; **if a recording came from a 430/440-pt device every video dimension below is 9–12 % too small.** The
  Dynamic-Island width could not be used for calibration (it is expanded by the recording indicator). Two different
  devices (V-sav vs V-virgi) give list-card heights of 98.2 and 101.6 pt, so device error appears to be within ~±3 %.
- **Font sizes** from glyph heights: ascender ≈ 0.74 em, x-height ≈ 0.53–0.55 em, cap/digit height ≈ 0.72 em. At 1.18 px/pt
  a glyph is 9–15 px tall, so video font sizes are **±1.5–2 pt**. Store PNG sizes ±1 pt.
- Frame timestamps are the true PTS of the decoded frame (matched by MSE = 0 against a `select` decode).

---

## 1. Foundations (Yope-wide)

### 1.1 Colors

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| **#171717** | screen background, group/chat screens (S1 hourly group, S5 chat, S2 profile) | S5; S1; S2 | S5 (600,1700); S1 row 720 x125–148; S2 (300,2500) | 9×9 / 5×5 box, sd 0 | ±1/255 | SOURCED |
| **#000000** | screen background, home list, "new group", send-to, camera, sign-up | V-sav t6.73; V-mthu t49.23; V-chuong t6.73; V-jacob t3.73 | e.g. V-mthu row 282 x126–469 | runs, flat | ±3/255 (video) | SOURCED |
| **#2E2E2E** | control surface: header circle buttons, header capsule, tab-bar capsule, composer field | S1; S2; S5 | S1 bbox x149–257 y664–772 (median); S2 (640,2380) box5; S5 bbox x361–822 y2391–2489 | bbox median / box sd 0 | ±2/255 | SOURCED |
| **#434343** | raised surface: selected tab pill, inner pill in header capsule, inactive page dots (#424242) | S2; S1 | S2 (480,2370) #424242; S1 bbox x630–779 y689–770; S1 row 832 x506–524 | box / bbox median | ±2/255 | SOURCED |
| **#FFFFFF** | primary text and glyphs | S1, S5 | S1 row 720 x192–197 (chevron) | runs | — | SOURCED |
| **#969696** | secondary text / inactive icons / chevrons / placeholder | S2; S1; S5 | S2 row 2412 x319–337 (tab icon); S1 row 720 x796–799 (capsule chevron); S5 x395–580 y2415–2465 (placeholder, top-5 % luminance pixels) | runs / percentile median | ±3/255 | SOURCED |
| **#CDFD07** | lime accent (composer camera button; "today" bar) | S5; S4 | S5 mask bbox x256–342 y2406–2492, n=2859, p10=p90=(205,253,7)/(205,254,8); S4 bbox x998–1016 y996–1108, n=799 | 5×5-eroded mask median | ±2/255 | SOURCED |
| **#FE1F84** | pink accent (profile name sticker, card outline) | S2 | interior n=41,703 in x180–1100 y1000–2320, p10=p90=(254,31,132) | 7×7-eroded mask median | ±1/255 | SOURCED |
| #000000 | label on lime buttons | V-mthu t49.23 | x234–341 y946–961, darkest 15 % = #000900 | percentile median | ±8/255 | SOURCED |
| #181818 | list cards on black (home) | V-sav t6.73 | col 400 runs y512–655 etc. | runs | ±8/255 (video; PNG value unknown) | SOURCED |
| #141414 | text field on black ("name group (optional)") | V-mthu t49.23 | col 150 y144–192 | runs | ±8/255 | SOURCED |
| #131313 | permission card on black (contacts card) | V-chuong t7.73 | col 150 y600–625, 698–719 | runs | ±8/255 | SOURCED |
| #101010 | header circle buttons on black sheets (✕, download) | V-chuong t6.73; V-mthu t49.23 | row 97 x73–125; row 88 x75–126 | runs | ±8/255 | SOURCED |
| #1F1F1F (#1F1C20) | camera flip button | V-jacob t3.73 | bbox x486–554 y1018–1086 | bbox median | ±8/255 | SOURCED |
| ≈#166AFA | selection check (filled circle) = iOS system blue | V-mthu t49.23; V-chuong t6.73 (#1868FC/#1169F9) | row 282 x474–495 | runs | video; use PLATFORM `systemBlue` | PLATFORM |
| #FDFDFD → white | secondary pill buttons ("invite more friends", "enable", "new recap") | V-mthu t51.23; V-chuong t7.73 | row 418 x168–408 | runs | ±3/255 | SOURCED |

Website only (not app; recorded so they are not mistaken for app values): yope.app `:root{--bg:#050505; --ink:#fafafa;
--dim:#9a9a9a; --lime:#c8ff2e; --card:#101010}`, light theme `--bg:#faf9f5; --limeInk:#478400`; invite page CSS lime
`#c8ff2e`, text on lime `#050505`, description `#aaa`. **App lime (#CDFD07, PNG) ≠ web lime (#C8FF2E, CSS).**

Conflict with yope-b: yope-b reports composer placeholder #A3A3A3 (different pixel selection); this pass measures
secondary text #969696 from three different elements (tab icon, capsule chevron, placeholder core).

### 1.2 Typography
- **Typeface**: not identified for the app. The website loads Unbounded (display) + Space Grotesk (body) from Google
  Fonts; the invite page uses Poppins (headings, 36px) and Raleway (body). No source says which face the iOS/Android
  app uses → token `font.family.ui = system` (PLATFORM). The custom "YOPE" logotype is a wordmark (do-not-copy).
- **Case**: all in-app UI strings are lowercase (see §4).

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| ≈40 pt, heavy | onboarding/sign-up title ("registrarse") | V-virgi t31.23 (f65 equivalent) | bbox x148–427 y438–484 (47 px asc+desc) | (asc+desc ≈0.95 em) /1.181 | ±3 pt | SOURCED |
| ≈19.5 pt, bold | sheet title "send to..." | V-chuong t6.73 | bbox x236–339 y≈85–101 (17 px 'd' ascender) | asc/0.74 /1.181 | ±2 pt | SOURCED |
| ≈14.5 pt, medium | sheet title "new group" | V-mthu t49.23 | 'n' x-height 9 px (y86–94) | xh/0.53 /1.181 | ±2 pt | SOURCED |
| 15 pt, bold | header capsule title ("super squad") | S1 | 's' x-height 21 px (y712–732); 'd' ascender 28 px (y705–732) | em≈37.5 px /2.511 | ±1 pt | SOURCED |
| ≈17.5 pt, bold | list row name ("kylee") | V-sav t6.73 | 'k' ascender 19 px (y869–887) | asc/0.74 /1.466 | ±1.5 pt | SOURCED |
| ≈14 pt, regular, #969696-class | list row subtitle ("new pic added · 9:43 AM") | V-sav t6.73 | 'd' ascender 15 px (y908–922) | asc/0.74 /1.466 | ±1.5 pt | SOURCED |
| ≈16 pt, semibold, gray | section label ("suggested friends") | V-chuong t7.73 | bbox y561–578 (18 px asc+desc) | /0.95 /1.181 | ±2 pt | SOURCED |
| ≈17 pt bold / ≈14 pt gray | permission card title / detail ("can't see your friends?" / "enable contacts") | V-chuong t7.73 | 2-line bbox y626–673 (line pitch ≈24 px); 'b' asc 12 px | line pitch ÷1.2; asc/0.74 | ±2 pt | SOURCED |
| ≈15 pt, semibold, #000 | primary button label ("send", "create group") | V-chuong t6.73; V-mthu t49.23 | 's' x-height 10 px, 'd' asc 13 px; 'create' x-height 9 px | xh/0.54, asc/0.74 | ±1.5 pt | SOURCED |
| ≈16 pt, regular | chat bubble text | S5 | "valid" ascender 27 px (y1582–1608) | asc/0.74 /2.252 | ±1 pt | SOURCED (yope-b: 17 pt) |
| ≈26 pt, heavy | hour overlay on camera viewfinder ("5:00 PM") | V-jacob t3.73 | digits 27 px (y531–557) | cap/0.72 /1.466 | ±2 pt | SOURCED |
| ≈27 pt, heavy | hour overlay on send-to preview ("4:00 PM") | V-chuong t6.73 | digits 23 px | cap/0.72 /1.181 | ±2 pt | SOURCED |
| ≈21 pt, heavy | hour overlay on chat photo ("10:00 PM") | S5 | bbox y1139–1179 minus tilt 7 px → 34 px | cap/0.72 /2.252 | ±1.5 pt | SOURCED (yope-b: 21) |
| ≈16 pt bold / ≈14 pt italic | empty-state title / detail ("you created group" / "and added mẹ, Anh") | V-mthu t51.23 | 'd' ascender 14 px; detail bbox 16 px | asc/0.74 /1.181 | ±2 pt | SOURCED |
| ≈12 pt, gray | legal footer on sign-up | V-virgi t31.23 | 3 lines y918–973 (pitch ≈18 px) | pitch/1.25 /1.181 | ±2 pt | SOURCED |

### 1.3 Radii, sizes, spacing (pt at 393)

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| 44 | header circle icon buttons (back, close, download, film-strip) | S1; V-chuong t6.73; V-mthu t49.23 | S1 bbox 109×109 px (x149–257, y664–772) → 43.4; V-chuong row 97 x73–125 (53 px) → 44.9; V-mthu row 88 x75–126 → 43.2 | bbox / runs ÷ scale | ±1.5 | SOURCED |
| 13 | header side inset | S1; V-chuong | S1 x120→149 = 31 px → 12.3, right 33 px → 13.1; V-chuong 17 px → 14.4 | difference ÷ scale | ±1 | SOURCED |
| 225 × 44, full pill | header title capsule | S1 | bbox x277–841 y664–772 | bbox | ±1 | SOURCED |
| 28 | avatar inside header capsule | S1 | 2× crop 140 px → 70 px | crop ÷ 2.511 | ±1 | SOURCED |
| 7.6, pitch 15.5 | page dots (inactive #424242, active #F4F4F4) | S1 | row 832 x506–524 … x703–720 | runs | ±0.5 | SOURCED |
| full pill (height/2) | text field, header capsule, chat bubbles, tab-bar capsule, tooltip ends | S1, S2, S5 | visual: straight sides + semicircular ends | geometry | — | SOURCED |
| 17 | list card corner radius (home) | V-sav t6.73 | top-left corner of card at y823: inset 25 px → 0 at d≈21 px; fits r≈25 px | circle fit ÷1.466 | ±2 | SOURCED |
| 14 | primary (lime) button corner radius | V-mthu t49.23 | button top y925: inset 16→0 at d=11; fits r≈16–17 px | circle fit ÷1.181 | ±2 | SOURCED |
| 12 | text-field corner radius ("name group (optional)") | V-mthu t49.23 | field top y143: fits r≈14 px | circle fit ÷1.181 | ±2 | SOURCED |
| 18.5 | camera viewfinder corner radius | V-jacob t3.73 | top y150: inset 21→0 at d=16; fits r≈26–28 px | circle fit ÷1.466 | ±2 | SOURCED |
| ~16 | send-to preview card radius | V-chuong t6.73 | visual on 1.6× crop (~30 px crop) | estimate | ±3 | SOURCED (approx) |
| ≈10 (not full pill) | white secondary button ("invite more friends") | V-mthu t51.23 | visual | estimate | ±3 | SOURCED (approx) |

### 1.4 Buttons

| style | evidence | measured | level |
|---|---|---|---|
| **Primary**: lime #CDFD07 fill, #000 semibold ~15 pt lowercase label, full width, r≈14 | V-mthu t49.23 "create group": x≈81–495 → **350 × 44.9 pt**, margins 19 pt; V-chuong t6.73 "send ❷": x88–487, y914–969 → **338 × 47 pt**, margins 27 pt (bottom of a sheet); V-virgi t11.23 "añadir widget" (same style) | two sizes observed (44.9 / 47) — report both | SOURCED |
| Primary + count | "send ❷": a black filled circle with the lime-coloured number after the label (count of selected recipients, not a social count) | V-chuong t6.73; V-virgi t56.23 "enviar ❸" | SOURCED |
| **Secondary (light)**: white fill, black label, leading glyph, hug width | "invite more friends" 205 × ~45 pt (V-mthu t51.23 row 418 x168–408, col 200 y394–446); "enable" ≈91 × 37 pt (V-chuong t7.73 x373–481, y638–681); "new recap" (V-mthu) | ±3 pt | SOURCED |
| **Secondary (dark)**: #171717-class fill on black, white label | sign-up Google/Facebook halves and "continue as …" (V-virgi t31.23: y594–650 ≈47 pt; gap ≈8 pt); "more friends" beside "send ❶" (V-chuong t3.73) | ±3 pt | SOURCED |
| Small add pill | "+ agregar" (es) gray pill right-aligned in rows (V-virgi t44.23, t49.23); English label not observed | — | SOURCED (es only) |
| **Circular icon buttons** | header 44 pt #2E2E2E (on #171717) / #101010 (on black); composer 39 pt (#404040–#434141, lime 38.6 pt for camera) S5 bbox 87–89 px; camera flip 47 pt #1F1F1F | see 1.1/1.3 | SOURCED |
| Tooltip/coach mark | lime rounded pill with pointer triangle, black text + leading glyph + trailing ✕; "hold down to record" (V-jacob t3.73: bbox 270 × 66 px incl. pointer → ≈184 × 37 pt body ≈34 pt); "add a voice memo on this pic" (V-chuong t6.73) | ±3 pt | SOURCED |
| Toast | lime full-width rounded bar with check glyph, "posted in the wall" (V-chuong t7.73) | not measured (partly under status bar) | SOURCED |

### 1.5 Navigation structure
- **Tab bar** (S2 = owner `yope-01`, V-virgi t36.23/t40.23, V-sav t6.73, V-jacob t3.73): floating capsule, 5 items, no
  labels: chats (two bubbles), cards/discovery (stacked cards), camera, wall/recaps (film-strip stack), me (own avatar).
  Measured on S2: capsule **344 × 58 pt** (row 2412 x251–1026; col 900 y2336–2466), fill #2E2E2E with 1-px lighter rim,
  side insets 22 pt; selected item = #434343 pill **74 × ~48 pt**; icons ≈20–23 pt glyphs (#969696 inactive, #FFFFFF
  selected); avatar ≈34 pt. Badges: red numeric badges on chats and me (V-sav) → do-not-copy (counts).
  Variants (version/experiment differences, not resolved): 5 items in capsule (S2; V-alexaa t5.23 camera selected,
  2026-09; V-virgi 2026-09), 4 items (camera, chats, wall, me; V-chuong t4.73, 2026-10), 3 items (chats, camera, me;
  V-arkadeep t32.73, 2026-05); on V-jacob's camera (2026-09) the capsule fill is absent (icons on black).
- **Camera is a tab**, and also opens from the composer's lime camera button and from each home row's camera glyph.
- Sheets: "new group" and "send to..." are full-height screens with ✕ (left) and title (centre); `duration.sheet.present`
  is measured by yope-b.

### 1.6 Avatars (pt)
| size | where | evidence |
|---|---|---|
| 64 | home list row | V-sav t6.73 col 160 y848–941 (94 px) |
| 40 | "new group" picker row | V-mthu t49.23 (47.5 px) |
| 32 | send-to recipient row | V-chuong t6.73 (~38 px) |
| 32–33 | chat bubble avatar | S5; yope-b 32.6 |
| 28 | header capsule | S1 (70 px) |
| ~34 | tab bar "me" | S2 col 945 y2363–2438 |
Avatars are either circles or **cut-out stickers** of the person with a coloured outline (V-sav, V-chuong) — the cut-out
treatment is Yope's ML sticker feature (walls; yope-b).

### 1.7 Iconography (glyph → SF Symbol / Material Symbol; PLATFORM assets)
| glyph seen | where | SF Symbol | Material Symbol | match |
|---|---|---|---|---|
| ‹ in circle | headers | `chevron.left` | `chevron_left` | exact |
| ✕ in circle | sheets | `xmark` | `close` | exact |
| ↓ to line | send-to header | `arrow.down.to.line` | `download` | exact |
| pencil | send-to header (edit) | `pencil` | `edit` | exact |
| magnifier | home header | `magnifyingglass` | `search` | exact |
| + | home header (Sep 2026) | `plus` | `add` | exact |
| two people + plus | home header (May 2026, opens "new group") | `person.2.badge.plus`* | `group_add` | *nearest; verify symbol exists in target SF version |
| camera (filled) | composer, row quick-camera, tab | `camera.fill` | `photo_camera` | exact |
| two overlapping bubbles | chats tab | `bubble.left.and.bubble.right.fill` | `forum` | close |
| stacked cards | discovery tab | `rectangle.portrait.on.rectangle.portrait.fill` | `filter_none` | close |
| film-strip stack | wall/recaps tab, group header | `film.stack` | `video_library` | close (yope-b uses same) |
| calendar | group header | `calendar` | `calendar_month` | exact |
| ⚡︎ slashed | camera flash off | `bolt.slash.fill` | `flash_off` | exact |
| circular arrows | camera flip | `arrow.triangle.2.circlepath` | `cameraswitch` | close |
| stacked photos | camera gallery (es build) | `photo.on.rectangle` | `photo_library` | close |
| video camera | "hold down to record" tooltip | `video.fill` | `videocam` | exact |
| mic | send-to caption, composer | `mic.fill` | `mic` | exact |
| speaker | send-to preview (video) | `speaker.wave.2.fill` | `volume_up` | exact |
| link | "invite more friends" | `link` | `link` | exact |
| ✓ in filled circle / empty circle | pickers | `checkmark.circle.fill` / `circle` | `check_circle` / `radio_button_unchecked` | exact |
| ••• | group profile, members | `ellipsis` | `more_horiz` | exact |
| › | header capsule | `chevron.right` | `chevron_right` | exact |
| ⌄ | under home cover photo | `chevron.down` | `expand_more` | exact |
| share (square + arrow) | members list, menu "share invite" | `square.and.arrow.up` | `ios_share` | exact |
| tray + arrow down | menu "download all photos" | `square.and.arrow.down` | `download` | exact |
| video | menu "get group recap" | `video` | `videocam` | close |
| door/arrow | menu "leave group" | `rectangle.portrait.and.arrow.right` | `logout` | close |
| flag | menu "report" | `flag.fill` | `flag` | exact |
| person silhouette | default avatar (members) | `person.fill` | `person` | exact |
| sticker (circle, peeled corner) | composer | none exact | none exact | **not mappable — BLOCKED** |

### 1.8 Loading / empty / error / offline visuals
- **Loading**: centred HUD, dark rounded square ≈100 × 98 pt (V-mthu t50.60: ≈118 × 116 px, fill median ≈#262626 on
  black), platform activity indicator + "Loading" (es: "Cargando", V-virgi signup). Spinner = PLATFORM.
- **Empty (group)**: "you created group" / italic "and added …" / white "invite more friends" pill over a faint
  outlined "YOPE" word pattern (do-not-copy wordmark) — V-mthu t51.23. Group profile empty: progress bar + "Add 20 pics
  more to get a recap", "skip the queue and create one now" + "new recap" (V-mthu, V-arkadeep* see 2.8).
- **Empty (old build, 2024)**: "No messages yet!" / "Chat with someone new" (V-yrrah24 t18.73).
- **Error**: only the web expired-invite page (W-inv): "A NEW LINK, A FRESH START" (lime, uppercase letter-spaced),
  "This invite has expired", "Ask your friend to send you a new link. Your next memories are waiting.", lime pill
  "Go to YOPE", footer "Life’s better with your people."; CSS: button `padding:16px 32px; border-radius:999px;
  background:#c8ff2e; color:#050505; font-size:15px`, icon tile 88×88 radius 28 rotated −8°.
- **Offline / in-app error states / permission-denied states: not found.**

---

## 2. Surfaces

### 2.1 `auth.phone` — NOT FOUND (screen); policy SOURCED
- Images: none show a phone-number screen. Current builds (V-virgi 2026-09, es; V-yrrah24 2024-12, en) open on a
  **social sign-in** screen: Sign in with Apple (white, full width), Google and Facebook (dark halves), "continue as
  <username>" (returning account), and a lime top-right text link "probar otras opciones" (es; = "try other options",
  translation not verbatim). The phone path is presumably behind "try other options" — not observed.
- Terms (T): "When you register, you must provide your cell phone number in order to create an Account." Privacy: phone
  verification via Firebase Authentication. Review (L, 2025-11-18): "I used my phone number to signup".
- Sign-up layout (V-virgi t31.23, es): title ≈40 pt heavy centred at ~45 % height; Apple button 342 × ~48 pt white,
  margins 25 pt; Google/Facebook 47 pt dark (#171717) halves with ≈8 pt gap; "continue as …" 47 pt dark at bottom;
  footer legal ≈12 pt gray, 3 lines, bold "Términos de uso"/"Política de privacidad".
- English sign-up copy (old build only, V-yrrah24 t6.73): "sign up or log in" / *"to join or create your friends
  groups"* (italic) / "Sign in with Apple" / "Sign in with Google" / "Sign in with Facebook" (system-style labels) /
  "By continuing, you agree to our Terms of Use and Privacy Policy" (small, partly legible — not used).
- Smallest capture to close: **one 30-s screen recording of a fresh install up to the first camera screen, in English,
  tapping "try other options" → phone.**

### 2.2 `auth.code` — NOT FOUND
- Terms: "you will be provided a verification code to your Account Phone Number and asked to input the verification
  code." No screen, length, resend timer or copy observed. Capture: same recording as 2.1.

### 2.3 `auth.agegate` — NOT FOUND (screen); policy SOURCED
- Terms §1d: "You affirm that you are 13 years of age or older … If you are between 13 and 18 years old, you may use
  the App only with the involvement of a parent or guardian." Privacy: "children under 13 are not eligible".
- Privacy: account data includes "the date of your birthday"; "If you choose to provide them, we collect your birth day
  and month so people you know get reminded when it’s your birthday." (supports `birthday.add` opt-in framing).
- Store ratings: App Store **4+** ("Contains: Messaging and Chat, User-Generated Content"; L informationRibbon);
  Google Play **"Rated for 12+"**. These conflict with the Terms (13+); recorded, not resolved.
- No birthday screen observed in 2024–2026 videos (Apple/Google sign-in may skip it). Capture: same as 2.1.

### 2.4 `auth.profile` — NOT FOUND (in-app); website demo only
- The website's interactive demo shows "pick your face", "add face", "tap to pick ✨", "vibe color", "wallpaper",
  "randomize", "your profile — tap anything" (W-site text) — a marketing simulation, not app evidence.
- After Apple sign-in the virgi flow goes straight to camera permission (name/avatar presumably from the identity
  provider; not visible). Capture: same as 2.1.

### 2.5 `onboarding.permission.notifications` — SOURCED (es) / English copy NOT FOUND
- Images: V-virgi t7.23 (pre-prompt), t9.23 (system alert); V-yrrah24 t5.23 (2024 system alert, en).
- Layout (2026): black screen, bold title centred near top ("mantente al tanto con tus amigos", es ≈ "stay up to date
  with your friends" — translation, not verbatim). Below, a **custom card that replicates the iOS alert** ("“yope” quiere
  enviarte notificaciones." + system body text) whose "Allow" button is a lime pill, with a lime arrow pointing at it;
  tapping it shows the real iOS alert. → **do-not-copy** (imitates system UI, tenet "invitations, never obligations";
  Apple HIG discourages custom alerts that look like system ones). Build ours on the Apple HIG / Material pre-prompt.
- Order in onboarding (2026-09, es): splash → notifications pre-prompt → system alert → intro animation "SHARE DAILY
  LIFE WITH FRIENDS" → widget pre-prompt "añadir widget" → (widget gallery) → ATT tracking alert (do-not-copy: ads) →
  sign-up → camera alert → microphone alert → camera.
- 2024 build had a Live Activity pre-prompt: "your activity is now live on your lock screen" / "tap once on the iphone
  side button then again to see it" / "continue", "tap one time", "tap ‘allow’" (BI 2025, V-yrrah24 t6.23) — Live
  Activities belong to `daily.liveactivity` (BeReal); recorded for voice only.
- Capture: one 15-s English recording of the notifications pre-prompt.

### 2.6 `onboarding.permission.camera` — SOURCED (purpose string, 2 sources); pre-prompt NOT FOUND
- Images: V-virgi t35.23 (2026-09), V-yrrah24 t13.23 (2024-12).
- No pre-prompt screen: the system alert appears directly over the camera screen the first time it opens.
- Purpose string (identical in both, English even in the es build): **"Allow camera access. So you can take and share
  pics with friends"** (no final period).
- Microphone (V-virgi t35.93): **"We need your mic to record your voice in video reactions."** (appears right after
  camera; context = video recording; our voice notes would adapt it).

### 2.7 `onboarding.permission.photos` — SOURCED (1 source, 2024); pre-prompt do-not-copy
- V-yrrah24 t21.23: system alert body **"This lets you share memories from your library."** (Limited Access / Allow Full
  Access / Don’t Allow — PLATFORM). Behind it the old build showed "share what you’re up to" / "to unlock the group for
  24h" → **do-not-copy** (post-to-unlock gate). No 2026 evidence. Capture: one screenshot of the 2026 photo-library prompt.

### 2.8 `onboarding.permission.contacts` — SOURCED (1 source, 2026); system purpose string NOT FOUND
- V-chuong t7.73 (2026-10, en): on the home list under the section label **"suggested friends"**, an inline card
  (#131313, 356 × 101 pt, r ≈ list-card radius, margins 18 pt): leading illustration (contacts-app-like icon with red
  "!" badge — **do-not-copy**, resembles Apple's Contacts icon), title **"can’t see / your friends?"** (bold ~17 pt, 2
  lines), detail **"enable contacts"** (~14 pt gray), trailing white button **"enable"** (≈91 × 37 pt), dismiss ✕ at
  top-right. Skippable (dismiss) — matches our "optional contacts".
- V-virgi t44.23 (es): suggested list with subtitles "de tus contactos" / "tiene amigos en común" and "+ agregar".
- Privacy policy: "Contact syncing is optional … you can still use the app without giving it access to your contacts".
- Do-not-copy: reviews (L) report the app "seemingly Require[s] u to add atleast 5 people before you can continue"
  (2025-09-18) and "prevents you from accessing basic features until you send invite links" (2025-03-20) — forced invites.
- Capture: one screenshot of the iOS contacts alert in 2026 build (purpose string).

### 2.9 `groups.list` — SOURCED (3 videos, 2026)
- Images: V-sav t6.73 (en, Sep 2026), V-virgi t40.23 (es, Sep 2026), V-mthu t44.23 (en UI, May 2026); S2 tab bar.
- Layout: top = the newest photo full-bleed with rounded bottom corners and a ⌄ under it; overlaid header row: search
  circle (left, translucent dark, ≈44 pt), "YOPE" wordmark (centre, do-not-copy), + circle (right) (May 2026 build:
  stacked member avatars with red badge centre, "add people" glyph right → opens "new group"). Below: vertical list of
  **cards** (one per group or 1:1): #181818 on black, **≈100 pt tall** (98.2 / 101.6 pt in two videos), **gap 7–7.5 pt**,
  side margins 12 pt, radius ≈17 pt. Card content: avatar 64 pt (circle or cut-out sticker, green presence dot) at
  16 pt inset; name ~17.5 pt bold white; **streak pill** (lime, 🔥N — do-not-copy); subtitle ~14 pt gray: "new pic
  added · 10:10 AM", or sender name in lime + "new pi…" (group), or "recap" + progress bar (weekly recap filling),
  or "you’re friends!✨ share a pic?" (new friend); right: red unread badge (do-not-copy count) and a camera glyph
  (≈16 pt) that opens the camera aimed at that conversation. A row with a fresh photo shows the photo blurred as the
  card background (V-sav "youuuuu(o…" row).
- Then "suggested friends" section and the contacts card (2.8). Floating tab bar overlays the bottom.
- Do-not-copy: streak pills, unread numeric badges, flame-rain animation over rows (V-sav, V-chuong), wordmark.

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| 98.2 / 101.6 pt | card height | V-sav t6.73; V-virgi t40.23 | V-sav col 520 cards y512–655, 667–811, 823–966, 978–1121; V-virgi col 380 y424–543 … | dark-gap runs ÷ scale | ±3 | SOURCED |
| 7.5 / 7 pt | card gap | same | V-sav gaps 11 px; V-virgi 8–9 px | runs | ±1 | SOURCED |
| 12 pt | card side margin | V-sav t6.73 | card x90 vs screen x72 (18 px) | diff | ±1 | SOURCED |
| 17 pt | card radius | V-sav t6.73 | corner fit at y823 | circle fit | ±2 | SOURCED |
| 64 pt | avatar | V-sav t6.73 | col 160 y848–941 | runs | ±2 | SOURCED |
| 16 pt | avatar inset | V-sav t6.73 | x113 vs card x90 | diff | ±1 | SOURCED |
| #181818 | card fill | V-sav t6.73 | col 400 | runs | ±8/255 | SOURCED |

### 2.10 `groups.create` — SOURCED (2026 en + 2025 + 2024)
- Images: V-mthu t45.23 (empty), t49.23 (filled), t50.60 (loading), t51.23 (created); BI 2025 composites; V-yrrah24
  t3.73 ("create new group", 2024).
- **Current flow (May 2026)**: home header "add people" glyph → full-screen **"new group"** (title centred, ✕ circle
  left) → text field **"name group (optional)"** (full width, 44 pt, #141414, r≈12, centred text) → label **"who would
  you like to add?"** (gray) → list of friends: avatar 40 pt, bold name, trailing empty circle / filled blue check
  (24 pt) → bottom lime **"create group"** (350 × 45 pt, r≈14, margins 19 pt) → Loading HUD → pushes into the new group
  chat with the empty state (2.12).
- No cover-photo or group-type step in the 2026 flow. **Cover photo existed in 2024–2025**: "create your / first group"
  (2nd line lime) over a photo with a camera glyph, name field ("Jordan’s besties"), lime **"continue"** (BI 2025); 2024:
  "create new group" (2nd part lime), grey rounded cover placeholder with camera glyph, "group name" field, "continue".
- Onboarding variant (BI 2025): "create your first group" / "to share pics daily and get recaps on your memories" /
  lime "create group" / "or" / dark "join friends by link".
- Group type (friends/family/roommates/custom): **not found** in any build. 2024 "group suggestions" carousel showed
  name presets ("school squad", "birthday blitz", "random trip") with "hide" (V-yrrah24 t18.73; partly legible).

| value | element | file | px coords | method | precision | level |
|---|---|---|---|---|---|---|
| 44 pt | name field height | V-mthu t49.23 | col 150 y142–194 | runs ÷1.181 | ±1 | SOURCED |
| 12 pt | name field radius | V-mthu t49.23 | corner fit y143 | circle fit | ±2 | SOURCED |
| 54.5 pt | picker row pitch | V-mthu t49.23 | avatar centres 64.3 px apart | ÷1.181 | ±1 | SOURCED |
| 40 pt | picker avatar | V-mthu t49.23 | 47.5 px | ÷1.181 | ±1 | SOURCED |
| 24 pt | check / radio circle | V-mthu t49.23; V-chuong t6.73 | 27.5 px; 30 px | ÷1.181 | ±1.5 | SOURCED |
| 350 × 45 pt, r 14 | "create group" | V-mthu t49.23 | x81–495, y925–977 | runs, circle fit | ±1 / ±2 | SOURCED |
| 19 pt | button side margin | V-mthu t49.23 | 22–23 px | ÷1.181 | ±1 | SOURCED |

Motion (V-mthu, 30 fps, 2026-05): "create group" → HUD (50.60 s) → the sheet content leaves to the left between
50.667 and 50.767 s (visible on 2 intermediate frames) ≈ **100 ms ±33 ms**, horizontal push; empty state then rises with
the keyboard 50.867–51.000 s (≈133 ms, keyboard = PLATFORM). Curve not measurable; screen recordings can drop frames,
so treat as duration only, low confidence.

### 2.11 `groups.invite` — SOURCED (2026 entry point; 2024 link/share sheet)
- 2026: after creation, white pill **"invite more friends"** with link glyph in the group empty state (V-mthu t51.23).
  What it opens: not seen (2024 equivalent below).
- 2024 (V-yrrah24 t10.73): screen "Add friends to / <group name>" (2nd line lime, on a blue card) with "You" + "Add"
  avatars; "Friends" row of avatars + "Show more"; **"Share this group link to invite"** with app row WhatsApp /
  Instagram / Snapchat / Messages / "Other app" (chain-link glyph → iOS share sheet → Copy); "Continue".
- Link format: **https://yope.tv/i/<5-char code>** (V-yrrah24 t16.23: `https://yope.tv/i/8a61w`). The expired link now
  serves the W-inv page (error copy in §1.8). Onboarding alternative: "join friends by link" (BI 2025).
- Contacts: suggested friends "+ add" (es "+ agregar") and "pending" (es "pendiente") states (V-virgi t44.23, t52.23).
- Do-not-copy: third-party app names/logos in the share row; forced-invite gating (2.8).

### 2.12 `groups.screen` — SOURCED (2026)
- Images: V-mthu t43.73 (hourly group), t51.23 (created empty state), t51.73 (group profile); V-chuong t8.73; S1, S5.
- Header (S1; matches yope-b `dimension.chat.header.*`): ‹ circle 44 pt · capsule 225 × 44 pt (group avatar 28 pt +
  bold 15 pt name + streak pill (do-not-copy) + ›) · calendar circle · film-strip circle (or "new recap" sticker).
- Body: hour slots ("6:00 PM" placeholder slots with the member avatar, filled slots show the photo with the hour
  overlay), "add more" pill on a filled slot, floating **"chat"** pill at the bottom (opens chat; red badge = count →
  do-not-copy). S1 shows the same as a stack of cards with page dots (5) under the header.
- Empty state after creation (V-mthu t51.23): bg #171717 (PNG-class; video #101010), centred **"you created group"**
  (bold ~16 pt), *"and added mẹ, Anh"* (italic ~14 pt), white pill "invite more friends"; composer at the bottom
  (lime camera · "start typing..." · sticker · mic — see yope-b `chat.composer`).
- Group profile (tap capsule; V-mthu t51.73): ‹ and •••, overlapping member avatars, group name (bold), thin progress
  bar + "Add **20 pics more** to get a recap" (number bold), segmented control **"pics | wall | recaps"** (selected =
  white pill, black text; capsule track #171717-class). Older builds: "chat | wall | recap" (BI 2025), "recap | pics"
  (owner `yope-week-recap.jpg`).
- System message pill: "<name> joined" (BI 2025 "Kailyn joined"; V-yrrah24 "Belle joined").

### 2.13 `groups.settings` (Yope's parts) — SOURCED for 2024 build only
- V-yrrah24 t33.73 (2024-11): group profile ••• opens a dark menu: "download all photos" (tray-down), "get group recap"
  (video), "share invite" (share), **"leave group"** (red, door glyph), **"report"** (red, flag). Lowercase, destructive
  items red.
- V-yrrah24 t43.23: "121 members" title with share glyph; rows: avatar (+ green presence dot), bold display name, gray
  username, gray "Pending" pill for invited-not-joined, ••• per row (admin actions not visible).
- 2026 menu contents, admin remove, mute, quiet hours: **not found**. Capture: one screenshot of the ••• menu on the 2026
  group profile + one of a member row's ••• menu.

### 2.14 `camera.capture` — SOURCED (3 videos, 2026)
- Images: V-jacob t3.73, V-chuong t4.73, V-virgi t36.23 (es); S1/O for hour concept.
- Layout: "YOPE" wordmark centred at top (do-not-copy) → **viewfinder full screen width, top at ~151 px/103 pt from
  screen top, aspect ≈ 1 : 1.38 (393 × 544 pt), radius ≈18.5 pt** → hour overlay centred (≈26 pt heavy, e.g. "5:00 PM",
  the hour slot the photo will land in) → bottom of viewfinder: flash-off glyph (left), filter names carousel (centre,
  mixed display fonts), "1x" (right) → lime tooltip "🎥 hold down to record ✕" pointing at the shutter (first use) →
  controls row: gallery thumbnail (left, rounded square with white border), **shutter** (centre), flip (right, 47 pt
  #1F1F1F circle) → tab bar.
- Shutter: white disc **59 pt** + black gap **≈5.5 pt** + lime ring **≈3.5 pt** = outer **≈80 pt** (±2) (V-jacob: ring
  x≈298–420, disc x317–403 / y1009–1095). Tap = photo, hold = video ("hold down to record").
- Live Photo (our requirement): not observed. Release notes 1.199.0 mention live photos (earlier dossier; not in the
  current version-history window).

### 2.15 `camera.sendto` — SOURCED (4 videos, 2026)
- Images: V-chuong t3.73 / t6.73, V-sav t5.73, V-jacob t4.73, V-virgi t56.23 (es).
- Layout: header ✕ (left circle) · **"send to..."** (bold ≈19.5 pt) · edit (pencil) + download circles (right) →
  centred **preview card** 218 × 290 pt (3:4), r ≈16, with the hour overlay (≈27 pt) and the caption typed directly
  under it (white semibold, centred, e.g. "i got here so early"); at the card's bottom a dark translucent field
  **"add a message"** + mic circle (voice memo); first-use lime tooltip **"add a voice memo on this pic" ✕** pointing at
  the mic → recipients list: own wall first (**"my wall"** / older "my moments", subtitle **"just for friends"**), then
  people/groups; avatar 32 pt, bold name (+ streak pill, do-not-copy); trailing check circle 24 pt (iOS blue filled when
  selected); multi-select → bottom lime button **"send ⓝ"** (338 × 47 pt, margins 27 pt) with a black count circle;
  compact variant with dark **"more friends"** + lime "send ❶" side by side (V-chuong t3.73).
- After send: lime toast **"posted in the wall"** (V-chuong t7.73); the photo appears on recipients' lock screen as a
  Live Activity with emoji quick-reactions (not my surface).
- No mandatory edit step (matches our directive). Caption is optional; voice optional.

---

## 3. Copy — verbatim strings (English unless marked)

### 3.1 Store and marketing (L = App Store JSON; Play identical)
- Title "yope: friends-only social game"; subtitle "real moments every hour".
- Description (verbatim, line breaks as published): "yope is the friends-only photo sharing app" / "it’s the safest,
  simplest way to stay close. share real photos with your closest circle — they appear instantly on friends’ lock
  screens and widgets." / "on Instagram, you’re performing. on Yope, you’re just living." / "we made Yope because social
  media became too fake. filters, edits, likes — all noise." / "Yope is different. no audience. no pressure. just you and
  the people you actually care about." / "why people switch to yope" / "• private by design – only your friends see your
  photos" / "• surprise lockscreen updates – stay connected without opening the app" / "• widget on your homescreen –
  daily moments in one glance" / "• fast, easy photo sharing – one tap, no edits, no stress" / "• built-in photo chats –
  skip the texting, share visually" / "• different groups, different energy – show your real self in every circle" /
  "• streaks that make friendships stronger – post together, grow together" (do-not-copy) / "real people. real photos.
  no performance." / "share what matters. see the moments that do." / "no likes. no rankings. no stress. just real
  updates — from people you love."
- Screenshot headlines: S1 "REAL MOMENTS. EVERY HOUR. EVERY FRIEND." · S2 "find friends **like you**" · S3 "put them on
  **your lock screen**" · S4 "your life = **daily & monthly recaps**" · S5 "react. talk. **go chaotic.**" · S6 "CUSTOM
  STICKERS OF YOU AND FRIENDS" · S7 "USE THEM EVERYWHERE IN IMESSAGE" (trademark) · Play: "SHARE DAILY LIFE WITH FRIENDS",
  "on their **lock & home screens**", "every day = **wall recap**", "collect **best memories** in your profile".
- What’s New (version history, L): 1.229.0 "your space with friends got a glow up / share your day, see theirs, stay
  close / all your moments together, in one place" · 1.216.0–1.227.0 "New split view just dropped / See what your
  friends are up to right now / And drop yours back" · 1.214.0–1.215.0 "recaps are now walls / edit them, remix them,
  make your own memory albums / save it or share it with your friends" · 1.210.0–1.212.1 "yope is all about sharing
  moments — and now you can share your voice too. / add voice to your memories or send voice messages in chat to stay
  even closer with your friends. / and for some of you, fun new face-swap stickers are live — so you can turn yourself
  into the meme and make chats even more chaotic." · 1.206.0–1.208.1 "we made yope way simpler. / this update focuses on
  what matters most: sharing pics back and forth with friends. / cleaner onboarding, easier posting, and a simpler app
  overall. / fewer steps. less noise. more sharing." · 1.202.x "Wrapped 2025 is here — a personal year-in-review
  highlighting your photos, moments, and close friends in a story-style recap." · 1.201.2–1.201.3 "just a lil metadata
  update — so you can find us faster".
- Developer replies to reviews (L; support/apology voice): "thanks for the awesome review! 💖 so glad you’re loving the
  app and features like personal streaks and customization! we totally hear you about the contact syncing bug, and we’ll
  look into it. if you have more ideas or just wanna chat, hit us up on instagram @yope.app! 🫶 🫶" · "thx for keeping it
  real 🙏 we hear u & we’re working hard to make yope more fun + actually useful for everyone 💖🛠️" · "hey, totally get
  where you’re coming from 💜 really appreciate you giving the app a shot, even if it didn’t click — that helps us learn
  a lot 🫶 …" · "thanks for the feedback 💖🥹 sorry about the crashes 😭 please send your username, device model, and a
  screen recording showing the issue to support@yope.app so our team can investigate and fix it as quickly as possible
  🫶✨" · "ouchhh 😭🙏 we hear u loud & clear. sorry the vibe didn’t land for u — def not the experience we want anyone to
  have. we’re still building & fixing lots of glitches, and feedback like urs helps us tons to improve 🛠️✨ thx for
  giving it a try tho, means a lot 🫶" · "hey! so sorry u had that experience 😭 we’ll reply to ur support email asap and
  help u get back into ur old account. ty for being patient with us 💖" · one formal reply (2025-04, Sentence case:
  "Hi there, We’re really sorry to hear about your experience …").
- Website (W-site): "don't perform. just yope." · "the AI-native app for your micro-communities — real life, shared
  only with the people you actually know." · "make it yours, then hit 📷 and snap ↓" · "ok, you get it. now for real." ·
  "that's the whole app: your own page, your camera — and every snap lands on your friends' lock screens. no feed, no
  likes, no algorithm." · "maybe later" · "ok fine, you win 🙂" · "get the app ↗".

### 3.2 In-app (with surface and evidence)
| string | surface | evidence |
|---|---|---|
| "sign up or log in" / "to join or create your friends groups" | auth.phone (sign-up) | V-yrrah24 t6.73 (2024) |
| "Allow camera access. So you can take and share pics with friends" | onboarding.permission.camera | V-virgi t35.23; V-yrrah24 t13.23 |
| "We need your mic to record your voice in video reactions." | (mic, voice) | V-virgi t35.93 |
| "This lets you share memories from your library." | onboarding.permission.photos | V-yrrah24 t21.23 |
| "suggested friends" · "can’t see your friends?" · "enable contacts" · "enable" | onboarding.permission.contacts | V-chuong t7.73 |
| "new pic added" · "you’re friends!✨ share a pic?" · "recap" | groups.list | V-sav t6.73, V-mthu t44.23; V-mthu t44.23; V-chuong t7.73 |
| "new group" · "name group (optional)" · "who would you like to add?" · "create group" | groups.create | V-mthu t45.23/t49.23 (+ BI 2025 "create group") |
| "create your first group" · "to share pics daily and get recaps on your memories" · "or" · "join friends by link" · "continue" | groups.create (onboarding variant, 2025) | BI 2025 |
| "Loading" | loading state | V-mthu t50.60 |
| "you created group" · "and added {names}" · "invite more friends" | groups.screen / groups.invite | V-mthu t51.23 |
| "Add {n} pics more to get a recap" · "pics" · "wall" · "recaps" · "skip the queue and create one now" · "new recap" · "add more" · "chat" · "{name} joined" | groups.screen | V-mthu t51.73, t43.73; V-arkadeep (https://www.tiktok.com/@arkadeep896/video/7644663053807586591, 2026-05-27, contact sheet only); BI 2025; V-yrrah24 |
| "Share this group link to invite" · "Add friends to {group}" · "Friends" · "Show more" · "Other app" · "Continue" | groups.invite (2024, Capitalised) | V-yrrah24 t10.73 |
| "download all photos" · "get group recap" · "share invite" · "leave group" · "report" · "{n} members" · "Pending" | groups.settings (2024) | V-yrrah24 t33.73, t43.23 |
| "No messages yet!" · "Chat with someone new" | empty (2024) | V-yrrah24 t18.73 |
| "hold down to record" | camera.capture | V-jacob t3.73; owner-independent V-alexaa (https://www.tiktok.com/@alexaa.yope/video/7684388619099933966) |
| "send to..." · "add a message" · "add a voice memo on this pic" · "my wall" · "my moments" · "just for friends" · "more friends" · "send" · "posted in the wall" | camera.sendto | V-chuong t3.73/t6.73/t7.73; V-sav t5.73; V-jacob t4.73 |
| "This invite has expired" · "Ask your friend to send you a new link." · "Your next memories are waiting." · "A new link, a fresh start" · "Go to YOPE" · "Life’s better with your people." | groups.invite error (web) | W-inv (title "Invite expired · YOPE") |
| "registrarse", "continuar con Apple", "seguir como …", "probar otras opciones", "al continuar, aceptas nuestros Términos de uso y nuestra Política de privacidad", "mantente al tanto con tus amigos", "recibe fotos de tus amigos directamente en tu pantalla de inicio", "añadir widget", "enviar a...", "mis momentos", "solo para amigos", "amigos sugeridos", "de tus contactos", "tiene amigos en común", "+ agregar", "pendiente", "buscar amigos", "nueva foto añadida", "añadir más", "mantenga presionado para grabar" | es locale (structure only — English equivalents not observed) | V-virgi |

## 4. Voice patterns (ids for `design/COPY.md`)

| id | rule | verbatim examples (source) |
|---|---|---|
| `yope.voice.lowercase` | Every in-app string is lowercase — first word, product name ("yope") and headings included. Proper names keep their own case. (2024 build and some web/system strings use Sentence case; treat those as exceptions.) | "who would you like to add?" (V-mthu) · "you created group" (V-mthu) · "hold down to record" (V-jacob) · "yope is all about sharing moments" (L 1.212) |
| `yope.voice.second-person` | Speaks to the user as "you/your", about "friends"; casual, present tense; never "users". | "can’t see your friends?" (V-chuong) · "who would you like to add?" (V-mthu) · "you’re friends!✨ share a pic?" (V-mthu) · "your space with friends got a glow up" (L 1.229) |
| `yope.voice.button` | 1–3 words, lowercase, verb-first, no final punctuation, no emoji; a count may follow as a separate badge. | "create group" · "invite more friends" (V-mthu) · "enable" (V-chuong) · "send" (V-chuong) · "continue" / "join friends by link" (BI) · "new recap" (V-mthu) |
| `yope.voice.title` | Short lowercase noun phrase; pickers end with "..." (three dots, no space). | "new group" (V-mthu) · "send to..." (V-chuong, V-sav, V-jacob) · "suggested friends" (V-chuong) |
| `yope.voice.placeholder` | Lowercase instruction; "(optional)" marks optional fields; "..." for open text. | "name group (optional)" (V-mthu) · "add a message" (V-chuong) · "start typing..." (S5) · "message..." (yope-b) |
| `yope.voice.coach` | First-use tooltip: lowercase imperative, ≤ 6 words, dismissible ✕, no emoji. | "hold down to record" (V-jacob) · "add a voice memo on this pic" (V-chuong, V-jacob) · "tap one time" / "tap ‘allow’" (2024) |
| `yope.voice.confirmation` | Past-tense statement of what happened, lowercase, no exclamation. | "posted in the wall" (V-chuong) · "you created group" (V-mthu) · "new pic added" (V-sav) · "Kailyn joined" (BI) |
| `yope.voice.empty-state` | Bold statement + italic/gray detail naming people + one light pill action. | "you created group" / "and added mẹ, Anh" / "invite more friends" (V-mthu) · "Add 20 pics more to get a recap" (V-mthu) · "skip the queue and create one now" / "new recap" (V-mthu) |
| `yope.voice.permission` | In-app ask = friend-benefit question + plain action; system purpose string = one benefit sentence ("So you can …", "This lets you …", "We need your mic to …"). | "can’t see your friends?" / "enable contacts" / "enable" (V-chuong) · "Allow camera access. So you can take and share pics with friends" (V-virgi, V-yrrah24) · "This lets you share memories from your library." (V-yrrah24) · "We need your mic to record your voice in video reactions." (V-virgi) |
| `yope.voice.error` | Calm, blame-free, tells the next step, ends warm; no emoji in product UI. | "This invite has expired" / "Ask your friend to send you a new link." / "Your next memories are waiting." (W-inv) · support: "sorry about the crashes 😭 please send your username, device model, and a screen recording…" (L) |
| `yope.voice.release-notes` | Lowercase line-broken fragments; triplets with periods; em dashes; light slang. | "fewer steps. less noise. more sharing." (L 1.208) · "no audience. no pressure." (L) · "just a lil metadata update — so you can find us faster" (L 1.201) |
| `yope.voice.support` (do not use in product UI) | Very casual text-speak (u, ur, thx, ty, tho), many emoji (💖🫶🙏😭✨🛠️). | the 7 lowercase developer replies in §3.1 |
| `yope.voice.emoji` | In-app UI: at most one emoji, used as warmth, never in buttons. | "you’re friends!✨ share a pic?" (V-mthu); none in buttons/titles across all frames |

## 5. Do-not-copy (tenet violations or third-party marks)
- Streaks everywhere: 🔥N pills in home rows, send-to rows, group header capsule; "streaks that make friendships
  stronger"; flame rain over rows; "+1 streak" (V-yrrah24); warnings that the "24-hour timeframe to send pics was closing"
  (BI 2025 text).
- Numeric badges: unread counts on rows, chat pill and tabs (V-sav, V-chuong).
- Notification pre-prompt that imitates the iOS alert with a lime "Allow" and an arrow (V-virgi t7.23).
- ATT tracking prompt "Your data will be used to analyze the efficiency of our marketing channels" (V-virgi) and Terms
  §1e advertisements.
- Forced invites before using the app (reviews in L) and "share what you’re up to / to unlock the group for 24h" (2024).
- Public discovery: "find friends like you", "find friends" toggle, interests/"things in common" stranger cards (S2,
  V-alexaa) — no public profiles in our product.
- Brand marks: "YOPE" logotype (headers, empty-state pattern, splash), app icon, cut-out sticker marketing art,
  third-party app names/logos (Instagram, Snapchat, WhatsApp, iMessage, Apple Contacts-like icon).

## 6. Not found (what was tried)
- `auth.phone`, `auth.code`, `auth.agegate`, `auth.profile` screens and copy in English (all videos 2024–2026 show social
  sign-in; "try other options" path never opened on camera; web search returned nothing).
- English notifications pre-prompt copy (only es). Contacts system purpose string. 2026 photo-library prompt.
- Group type selection; 2026 group settings (mute, quiet hours, admin remove); invite sheet in 2026 build.
- Offline and permission-denied states for every surface; in-app error strings.
- Live Photo capture UI.
- App typeface (no reliable source).
- Exact device width of each recording (pt values assume 393).
