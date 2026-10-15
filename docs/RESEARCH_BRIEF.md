# Reference research brief (for every research pass)

You are gathering design references for a private photo app for close friends and family
(groups up to 30, no public feed, no likes or counts, no streaks, no ads). The build directive
forbids any design decision based on taste: every color, size, radius, font, icon, motion value,
haptic and user-facing word must trace to a reference app screen, image or video, logged with
evidence. Your job is to find that evidence and extract values from it. Read
`docs/CONVENTIONS.md` and `docs/SURFACES.md` first.

## Rules
- Never invent or guess a value. If you cannot find evidence, record the item under
  "Not found" with what you tried. A missing value is fine; an invented one is not.
- At least **2 independent images per surface** before extracting values, where they exist.
  Prefer the most recent material (last 12 months) and note app version/date.
- Colors: sample from the clearest, least-compressed image (prefer the original-resolution
  App Store PNGs in `references/auto/<app>/store/`). Record hex, file, pixel coordinates, and the
  method (e.g. median of a 7×7 box). Avoid anti-aliased edges. Note when a color sits under a
  photo tint or blur.
- Sizes: measure relative to the phone screen in the image. For App Store marketing panels, find
  the phone screen's width in px and convert: `pt = px / screen_px_width × 393` (or 430 for
  Pro Max-sized devices; say which you assumed and why). For raw screenshots at 3x, pt = px / 3.
  State precision honestly (e.g. ±1 pt).
- Motion: from videos, extract frames with ffmpeg at the native frame rate, find first/last
  changed frame, and record URL, timestamps, fps, duration, and an honest precision (±1 frame).
  Name the easing only if it is measurable (plot position vs. time); otherwise say
  "duration only; curve not measurable".
- Copy: gather real strings verbatim (App Store descriptions, release notes, screenshots, videos,
  help centers, websites). Record each with its source. Also write down the **voice pattern**
  (case, person, length, punctuation, emoji use) with 3+ examples, so new strings can follow it.
- Haptics cannot be observed: do not propose haptic values from videos (the build uses PLATFORM
  generators).
- Fonts: identify the typeface if a reliable source says so (e.g. the company's site CSS,
  a design-reference site, press kit). If it is proprietary or unknown, record that; the build will
  use the platform font (PLATFORM).
- Record but mark **do-not-copy** anything that violates the product's tenets: streaks
  (🔥N pills), counts of likes/reactions/views, "late" labels, retake counts, guilt or nag copy,
  public profiles/followers, ads, mascots.
- Legal: never save or propose another company's logo, wordmark, mascot, proprietary
  illustration or font file. Screenshots are kept for internal reference only.
- Don't commit to git. Write only inside your assigned paths. Other agents work in parallel.

## Tools that work here
- App Store pages: `curl -sL -A "<Safari UA>" https://apps.apple.com/us/app/id<ID>` (see
  `tools/fetch_appstore.py`; screenshots at original size via `/9999x0w.png` on the mzstatic
  thumb URL). Other storefronts (`/gb/`, `/de/`, ...) sometimes carry different screenshots.
- Google Play: `https://play.google.com/store/apps/details?id=<pkg>&hl=en_US` (screenshots on
  `play-lh.googleusercontent.com`; append `=w2560` for full size).
- TikTok: `yt-dlp <url>` works (curl_cffi installed). YouTube is bot-blocked from this
  machine; try other mirrors/search results, but don't spend long on it.
- Web search / fetch: load `WebSearch`, `WebFetch` via ToolSearch; Firecrawl tools
  (`mcp__Firecrawl__firecrawl_search`, `mcp__Firecrawl__firecrawl_scrape`, which can also take
  screenshots of web pages) are available.
- Playwright + Chromium (`/opt/pw-browsers`) for screenshots of web pages (e.g. a real
  invite page, a help center).
- `ffmpeg`, `ffprobe`, Python 3 with Pillow and numpy, ImageMagick `convert`.
- The `Read` tool shows you images; crop/zoom with Pillow first to read small details.
- Earlier research (for leads only, re-verify and log real URLs):
  `/home/user/newproject/research/*.md` (dossiers on Locket, Yope, Retro, BeReal, Wrapped,
  Partiful, Apple HIG). Owner-provided images: `references/owner/` (CAPTURED, see its INDEX.md).

## Outputs (all paths relative to the repo root `/home/user/yope-like-project`)
1. Images/frames you use → `references/auto/<app>/...`, each row in `references/auto/<app>/INDEX.md`
   (`| file | source URL | accessed | what it shows | version/date |`). Store screenshots are
   already there in `store/`.
2. Findings → `design/research/<your-file>.md`, organized by surface id. For every surface:
   - the reference images used (≥2 where possible);
   - layout description (structure, alignment, order of elements);
   - a measured-values table: `value | element | file | px coords | method | precision | level`;
   - verbatim copy with sources, and the voice pattern;
   - motion measurements;
   - do-not-copy items;
   - "Not found" list.
3. Machine-readable proposals → `design/proposals/<your-file>.tokens.json` and
   `design/proposals/<your-file>.copy.json` in the schemas of `docs/CONVENTIONS.md`. Use the
   surface ids from `docs/SURFACES.md`. Validate that both files parse as JSON.
4. Finish with a short report: which surfaces are fully sourced, approximated (and how), and
   not found; and the **smallest** owner capture that would settle each gap (e.g. "one 20-second
   screen recording of X in app Y").
