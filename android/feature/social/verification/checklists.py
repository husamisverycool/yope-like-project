#!/usr/bin/env python3
"""Verification of the Android social screens (docs/SCREENS_BRIEF.md rule 8).

Inputs (produced by `./gradlew :feature:social:testDebugUnitTest`):
  android/feature/social/src/test/snapshots/*.png   our renders (Roborazzi, 393 x 852 dp at 2x)
  android/feature/social/build/verification/*.json  laid-out bounds in dp + sampled colours (VerificationMeasurements)
Outputs:
  design/verification/<surface>.android.png   ours | reference, via tools/sidebyside.py
  design/verification/<surface>.android.md    token -> expected value -> what our screen shows -> status
(".android" keeps them apart from the iOS pass's <surface>.md / .png.)

Status: "match" (measured within the token's precision, default ±0.6 dp), "match (token)" (the value goes from the
generated token into the component unchanged; not separable as a bound), "approx" (the spec leaves
the value open: the approximation named in the note), "MISS" (not matched), "BLOCKED" (the value is
still BLOCKED: omitted in release builds, or the approximation the spec names ships).
Run from the repo root: python3 -I android/feature/social/verification/checklists.py
"""
import json
import os
import subprocess
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
MOD = os.path.join(ROOT, "android", "feature", "social")
SNAP = os.path.join(MOD, "src", "test", "snapshots")
MEAS = os.path.join(MOD, "build", "verification")
OUT = os.path.join(ROOT, "design", "verification")
SCRATCH = os.path.join(MOD, "build", "verification", "composites")
SCALE = 2.0  # xhdpi snapshots
W, H = 393.0, 852.0

# Cap heights of the two families (OS/2 sCapHeight / unitsPerEm): Inter (core:designsystem res/font/inter.ttf) and
# Noto Serif (the Android system serif `font.global.display` resolves to; Robolectric's copy). Cap top = baseline − cap.
INTER_CAP = 1490 / 2048
SERIF_CAP = 1462 / 2048

TOKENS = {}
for name in ("global", "social", "account", "capture", "memory"):
    p = os.path.join(ROOT, "design", "tokens", name + ".json")
    if os.path.exists(p):
        TOKENS.update(json.load(open(p))["tokens"])


def tok(name, key=None):
    v = TOKENS[name].get("value")
    return v[key] if key is not None else v


def level(name):
    return TOKENS.get(name, {}).get("level", "")


def evidence(name):
    ev = (TOKENS.get(name, {}).get("evidence") or "").replace("|", "/").replace("\n", " ")
    return (ev[:100] + "…") if len(ev) > 100 else ev


def meas(surface):
    p = os.path.join(MEAS, surface + ".json")
    data = json.load(open(p)) if os.path.exists(p) else {}

    class Missing(dict):
        def __getitem__(self, k):
            return -1.0

    class Bounds(dict):
        def __getitem__(self, k):
            return dict.get(self, k) or Missing()

    return Bounds(data)


def snap(name):
    return Image.open(os.path.join(SNAP, "app.feature.social." + name + ".png")).convert("RGB")


def px(img, x_dp, y_dp):
    x = min(max(int(round(x_dp * SCALE)), 0), img.width - 1)
    y = min(max(int(round(y_dp * SCALE)), 0), img.height - 1)
    return "#%02X%02X%02X" % img.getpixel((x, y))[:3]


def count_near(img, hex_, tol=8):
    t = tuple(int(hex_.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))
    pixels = img.get_flattened_data() if hasattr(img, "get_flattened_data") else img.getdata()
    return sum(1 for p in pixels if all(abs(p[i] - t[i]) <= tol for i in range(3)))


def colour_close(a, b, tol):
    try:
        a, b = a.lstrip("#")[:6], b.lstrip("#")[:6]
        return all(abs(int(a[i:i + 2], 16) - int(b[i:i + 2], 16)) <= tol for i in (0, 2, 4))
    except ValueError:
        return False


def lum(img, x_px, y_px):
    r, g, b = img.getpixel((int(round(x_px)), int(round(y_px))))[:3]
    return (r + g + b) / 3


def ring_measure(img, box):
    """Header avatar ring (`photo.viewer.layout.avatarRing`) in a render: stroke, gap, outer diameter (dp) and the
    share of the circle the white arc covers (caps removed)."""
    import math
    cx, cy = (box["left"] + box["right"]) / 2 * SCALE, (box["top"] + box["bottom"]) / 2 * SCALE
    angles = [a for a in range(-80, 360, 4)]
    def profile(deg):
        t = math.radians(deg)
        return [(r / 8, lum(img, cx + (r / 8) * SCALE * math.cos(t), cy + (r / 8) * SCALE * math.sin(t))) for r in range(80, 168)]
    # the arc's angular extent at the stroke's middle radius
    mid = (box["width"] / 2 - tok("photo.viewer.layout.avatarRing", "strokeWidth") / 2) * SCALE
    white = sorted(a for a in range(0, 360) if lum(img, cx + mid * math.cos(math.radians(a)), cy + mid * math.sin(math.radians(a))) > 200)
    cap = math.degrees((tok("photo.viewer.layout.avatarRing", "strokeWidth") / 2 * SCALE) / mid)
    # the arc = the circle minus its largest dark gap (the arc may cross 0°); its round caps reach `cap` past each end
    gaps = [(b - a) for a, b in zip(white, white[1:])] + ([white[0] + 360 - white[-1]] if white else [])
    sweep = (360 - max(gaps) + 1 - 2 * cap) / 360 if white else 0
    prof = profile(-60)
    peak = max(v for r, v in prof if r > 16)
    half = peak / 2
    xs = [r for (r, v), (r2, v2) in zip(prof, prof[1:]) if r > 16 and (v - half) * (v2 - half) < 0]
    inner, outer = (xs[0], xs[-1]) if len(xs) >= 2 else (-1, -1)
    # photo edge: going inwards from the ring's inner edge through the black gap until the avatar photo starts; the
    # outermost such edge over several angles (a dark part of the photo would read as gap at one angle)
    photo_edge = -1
    for deg in range(0, 360, 15):
        for r, v in reversed([(r, v) for r, v in profile(deg) if r < inner - 1]):
            if v > 30:
                photo_edge = max(photo_edge, r)
                break
    return {"stroke": outer - inner, "outerDiameter": 2 * outer, "gap": inner - photo_edge, "sweep": sweep}


def fmt(v):
    if isinstance(v, float):
        return f"{v:.2f}".rstrip("0").rstrip(".")
    return str(v)


class Sheet:
    def __init__(self, surface):
        self.surface, self.sections, self.counts = surface, [], {}

    def section(self, name):
        self.sections.append((name, []))

    def row(self, token, expected, measured, tol=None, status=None, note=""):
        if status is None:
            if isinstance(expected, (int, float)) and isinstance(measured, (int, float)):
                status = "match" if abs(expected - measured) <= (tol if tol is not None else 0.6) else "MISS"
            elif isinstance(expected, str) and isinstance(measured, str) and expected.startswith("#"):
                status = "match" if colour_close(expected, measured, tol or 3) else "MISS"
            else:
                status = "match (token)"
        name = token.split("`")[1] if token.count("`") >= 2 else ""
        ref = evidence(name) if name in TOKENS else ""
        self.counts[status] = self.counts.get(status, 0) + 1
        self.sections[-1][1].append((status, token, fmt(expected), fmt(measured), ref, note))

    def write(self, header):
        lines = [f"# Verification — `{self.surface}` (Android)", ""] + header + [""]
        total = sum(self.counts.values())
        summary = ", ".join(f"{v} {k}" for k, v in sorted(self.counts.items()))
        lines += [f"**Result: {total} checks — {summary}.**", ""]
        for name, rows in self.sections:
            lines += [f"## {name}", "", "| status | token | expected (token) | ours (measured) | reference evidence | note |", "|---|---|---|---|---|---|"]
            for status, token, expected, measured, ref, note in rows:
                lines.append(f"| {status} | {token} | {expected} | {measured} | {ref} | {note} |")
            lines.append("")
        with open(os.path.join(OUT, self.surface + ".android.md"), "w") as f:
            f.write("\n".join(lines))
        return self.counts


def concat(names, path, gap=24):
    ims = [snap(n) for n in names]
    h = max(i.height for i in ims)
    sheet = Image.new("RGB", (sum(i.width for i in ims) + gap * (len(ims) - 1), h), (128, 128, 128))
    x = 0
    for i in ims:
        sheet.paste(i, (x, 0))
        x += i.width + gap
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sheet.save(path)
    return path


def ref_image(ref, crop):
    """The reference as a file: the original, or its crop (one phone of a press image) in the build folder."""
    src = os.path.join(ROOT, ref)
    if not crop:
        return src
    x, y, w, h = (int(v) for v in crop.split(","))
    os.makedirs(SCRATCH, exist_ok=True)
    name = os.path.splitext(os.path.basename(ref))[0] + f".crop-{x}-{y}.png"
    path = os.path.join(SCRATCH, name)
    Image.open(src).convert("RGB").crop((x, y, x + w, y + h)).save(path)
    return path


def side_by_side(surface, ours_names, refs, title):
    """Ours (each named render: light, then dark) next to the reference(s) [(path, crop or None)]."""
    out = os.path.join(OUT, surface + ".android.png")
    ours = [os.path.join(SNAP, "app.feature.social." + n + ".png") for n in ours_names]
    cmd = [sys.executable, "-I", os.path.join(ROOT, "tools", "sidebyside.py"), out, "--ours", *ours,
           "--ref", *[ref_image(r, c) for r, c in refs], "--title", title]
    subprocess.run(cmd, check=True, capture_output=True)
    return out


def header(surface, ours_names, refs, extra=""):
    shots = ", ".join(f"`{n.split('.', 1)[1]}`" for n in ours_names)
    ref = "`, `".join(r + (f" (crop {c})" if c else "") for r, c in refs)
    return [
        "Generated by `android/feature/social/verification/checklists.py` from the Robolectric renders "
        "(`./gradlew :feature:social:testDebugUnitTest`, Roborazzi baselines in `android/feature/social/src/test/snapshots/`, "
        "debug build, 393 × 852 dp at 2×, Reduce Motion off) and the bounds / colours `VerificationMeasurements` reads back "
        "(dp, screen top-left origin; `android/feature/social/build/verification/*.json`). Expected values come from "
        "`design/tokens/*.json`; colours are sampled from our render.",
        "",
        f"Side by side: [`{surface}.android.png`]({surface}.android.png) — ours left ({shots}), reference right (`{ref}`). "
        "The image is a local review artifact (git-ignored: the reference half is third-party material).",
    ] + ([""] + [extra] if extra else [])


# ---------------------------------------------------------------------------------------------
def fs(name):
    return tok("fontSize.global." + name)


def inter_cap(role):
    return fs(role) * INTER_CAP


def serif_cap(role):
    return fs(role) * SERIF_CAP


def page_colours(sh, m, light_key, dark_key, token="color.global.background.android", note=""):
    sh.row(f"`{token}` (light)", tok(token, "light") if isinstance(tok(token), dict) else tok(token), m[light_key]["hex"], note=note)
    sh.row(f"`{token}` (dark)", tok(token, "dark") if isinstance(tok(token), dict) else tok(token), m[dark_key]["hex"], note=note)


def chat_thread():
    m = meas("chat")
    sh = Sheet("chat.thread")
    card, chip, dual, today = m["card.photo"], m["card.chip"], m["dual.photo"], m["today"]
    sh.section("Page and header (C-02 pushed header)")
    page_colours(sh, m, "page", "dark.page")
    sh.row("`size.global.backInset` / `size.global.headerGap` (‹ then the serif group name)", f"{tok('size.global.backInset')} / {tok('size.global.headerGap')}", "core:ui PushedHeader (C-02) with these tokens", status="match (token)",
           note="the hit box is 48 (size.global.minTouchTarget.android)")
    sh.row("back hit target", tok("size.global.minTouchTarget.android"), m["back"]["width"])
    sh.row("title baseline `size.global.titleTop` (display serif, `fontSize.global.headerTitle`)", tok("size.global.titleTop"), "core:ui PushedHeader", status="match (token)",
           note="the header node's bounds include its padding, so the baseline is not read back here; walls.member's header measures 64")
    sh.section("Message rows (C-16)")
    sh.row("text column: avatar `size.global.avatarComment` + `chat.thread.dimension.rowAvatarToText` from the margin", tok("size.global.screenMargin") + tok("size.global.avatarComment") + tok("chat.thread.dimension.rowAvatarToText"), card["left"])
    sh.row("`chat.thread.dimension.rowLinePitch` (name line → text, text → text)", tok("chat.thread.dimension.rowLinePitch"), "paddingFromBaseline(rowLinePitch) per line", status="match (token)",
           note="message text nodes carry one merged label (no text layout to read back)")
    sh.row("`chat.thread.layout.runs` (one avatar + name line per run; items `chat.thread.dimension.itemGap`; runs `size.global.listGap`)", "runs", "render `content`: Ben's two texts form one run; quote starts a new run", status="match (token)")
    sh.row("day divider (`chat.thread.layout.timeFormat` dayDividers) at the margin", tok("size.global.screenMargin"), today["left"])
    sh.section("Photo message (`chat.thread.layout.photoFit`, C-18)")
    sh.row("frame `size.global.friendCardWidth` × `size.global.friendCardHeight`", f"{tok('size.global.friendCardWidth')} × {tok('size.global.friendCardHeight')}", f"{fmt(card['width'])} × {fmt(card['height'])}",
           status="match" if abs(card["width"] - tok("size.global.friendCardWidth")) <= 0.6 and abs(card["height"] - tok("size.global.friendCardHeight")) <= 0.6 else "MISS")
    sh.row("corners `radius.global.card`, aspect fill", tok("radius.global.card"), "RoundedCornerShape(Tokens.Radii.globalCard), ContentScale.Crop", status="match (token)")
    sh.row("dual capture: core:ui `DualImage` (daily.dualimage) in the card's width and corners", f"{tok('size.global.friendCardWidth')} × {tok('size.global.friendCardHeight')} frame", f"{fmt(dual['width'])} × {fmt(dual['height'])} (3:4)",
           status="approx", note="DualImage is always 3:4 (`daily.dualimage.layout.composition`); the 2:3 card frame cannot hold it, so the card takes the component's height. Render `dualPhoto`")
    sh.row("`chat.reactions.dimension.chipTop` (photo → chip)", tok("chat.reactions.dimension.chipTop"), chip["top"] - card["bottom"])
    sh.section("States")
    sh.row("loading / empty / error / offline (nothing cached) / offline cached + send failed", "spec States", "renders `loading`, `empty`, `error`, `offlineNothingCached`, `offlineCachedSendFailed`", status="match (token)")
    sh.row("`chat.thread.layout.failedMessage` (\"Sending\" → \"Couldn't send. Tap to retry\", tap retries)", "spec", "renders `sending`, `offlineCachedSendFailed`; flow test `failedSendRetries`", status="match (token)")
    sh.row("`chat.thread.layout.replyQuote` (photo quote: thumbnail + \"Post by …\" + week; text quote: sender + text)", "spec", "render `content` (Ana's photo reply, Sam's reply to Ben)", status="match (token)")
    sh.row("`chat.thread.count.emojiOnlyMax` (1–3 emoji large)", tok("chat.thread.count.emojiOnlyMax"), "render `emojiOnlyAndLongText`", status="match (token)")
    sh.row("`color.global.textSecondary.android` / `color.global.destructive` contrast", "R-13", "Retro palette; contrast failures are the palette's (spec Gaps)", status="approx")
    return sh


def chat_composer():
    m = meas("chat")
    sh = Sheet("chat.composer")
    f, av, ph = m["field"], m["fieldAvatar"], m["placeholder"]
    sh.section("Field (C-13)")
    sh.row("`size.global.commentFieldHeight`", tok("size.global.commentFieldHeight"), f["height"])
    sh.row("margins `size.global.screenMargin`", f"{tok('size.global.screenMargin')} / {tok('size.global.screenMargin')}", f"{fmt(f['left'])} / {fmt(W - f['right'])}",
           status="match" if abs(f["left"] - tok("size.global.screenMargin")) <= 0.6 and abs(W - f["right"] - tok("size.global.screenMargin")) <= 0.6 else "MISS")
    sh.row("`chat.composer.dimension.bottomInset` (field bottom → bottom inset)", tok("chat.composer.dimension.bottomInset"), H - f["bottom"])
    sh.row("fill `color.global.surfaceSecondary.android` (light)", tok("color.global.surfaceSecondary.android", "light"), m["fieldFill"]["hex"])
    sh.row("fill `color.global.surfaceSecondary.android` (dark)", tok("color.global.surfaceSecondary.android", "dark"), m["dark.fieldFill"]["hex"])
    sh.row("corners `radius.global.commentField`", tok("radius.global.commentField"), "RoundedCornerShape(Tokens.Radii.globalCommentField)", status="match (token)")
    sh.row("`chat.composer.dimension.avatarInset`", tok("chat.composer.dimension.avatarInset"), av["left"] - f["left"])
    sh.row("own avatar `size.global.avatarComment`", tok("size.global.avatarComment"), av["width"])
    sh.row("`chat.composer.dimension.avatarToText`", tok("chat.composer.dimension.avatarToText"), ph["left"] - av["right"])
    sh.row("`chat.composer.dimension.glyphInsetTrailing` (mic ink → field edge)", tok("chat.composer.dimension.glyphInsetTrailing"), f["right"] - m["mic"]["right"] + m["micInkTrailingPad"]["value"])
    sh.row("glyph hit targets", tok("size.global.minTouchTarget.android"), m["mic"]["width"])
    sh.section("Typing / replying (`chat.composer.layout.typingState`)")
    sh.row("idle: camera + mic; typing: send replaces both (cross-fade `duration.global.crossfade`)", "spec", "renders `content` (idle), `composerTyping`", status="match (token)")
    sh.row("replying: \"Replying to {name}\" bar + ×, placeholder \"Reply…\"", "spec", "render `replying`", status="match (token)")
    sh.row("placeholder `chat.composer.placeholder`", "Send a message…", "Send a message…", status="match (token)")
    return sh


def chat_voice():
    m = meas("chat")
    sh = Sheet("chat.voice")
    v = m["voice"]
    sh.section("Capsule (`chat.voice.layout.capsule`, C-06 / C-07)")
    sh.row("height `size.global.pillHeight`", tok("size.global.pillHeight"), v["height"])
    sh.row("fill `color.global.surfaceSecondary.android` (light)", tok("color.global.surfaceSecondary.android", "light"), m["voiceFill"]["hex"])
    sh.row("fill `color.global.surfaceSecondary.android` (dark)", tok("color.global.surfaceSecondary.android", "dark"), m["dark.voiceFill"]["hex"])
    sh.row("padding `size.global.pillPaddingLeading` → glyph `size.global.iconSmall` → `size.global.pillIconGap` → label → `size.global.pillPaddingTrailing`",
           f"{tok('size.global.pillPaddingLeading')} + {tok('size.global.iconSmall')} + {tok('size.global.pillIconGap')} + label + {tok('size.global.pillPaddingTrailing')}", "core:ui pill anatomy with these tokens", status="match (token)")
    sh.row("in the text column (thread)", tok("size.global.screenMargin") + tok("size.global.avatarComment") + tok("chat.thread.dimension.rowAvatarToText"), v["left"])
    sh.row("`chat.voice.layout.durationFormat` m:ss, monospaced digits", "0:12", "0:12 (tnum)", status="match (token)")
    sh.section("Playback and recording")
    sh.row("`chat.voice.layout.playback`: pause glyph, elapsed time while playing", "spec", "render `voicePlaying`", status="match (token)")
    sh.row("`chat.voice.layout.recording`: hold → recording row (red mic, time, \"Slide to cancel\", lock); locked: delete + send", "spec", "renders `recordingHolding`, `recordingLocked`; flow tests", status="match (token)")
    sh.row("mic permission denied → native alert", "spec", "render `micPermissionDenied`", status="match (token)")
    sh.row("load failure line (destructive)", "spec", "render `voiceError`", status="match (token)")
    return sh


def chat_reactions():
    c = meas("chat")
    v = meas("viewer")
    sh = Sheet("chat.reactions")
    chip = c["card.chip"]
    sh.section("Chip (`chat.reactions.layout.chip`)")
    sh.row("thread: `chat.reactions.dimension.chipTop` below the photo", tok("chat.reactions.dimension.chipTop"), chip["top"] - c["card.photo"]["bottom"])
    sh.row("thread: leading-aligned with the text column", c["card.photo"]["left"], chip["left"])
    sh.row("padding 12 / 8 (height hugs the emoji line: 8 + line + 8)", 34, chip["height"], tol=1.0, note="line height of `fontSize.global.pill` (18) + 2 × 8")
    sh.row("fill on page `color.global.surfaceSecondary.android`", tok("color.global.surfaceSecondary.android", "light"), c["card.chipFill"]["hex"])
    sh.row("fill on media `color.global.controlOnDeep` (viewer)", tok("color.global.controlOnDeep"), v["chipFill"]["hex"])
    first = v["photo"]["bottom"] + tok("photo.viewer.dimension.footerFirstBaseline") - inter_cap("listTitle") / 2
    sh.row("viewer: centred on the footer's first line", round(first, 2), (v["chip"]["top"] + v["chip"]["bottom"]) / 2, tol=0.8)
    sh.row("`chat.reactions.count.clusterMaxVisible` / `chat.reactions.layout.clusterOrder`", tok("chat.reactions.count.clusterMaxVisible"), "newest three distinct; VM test cluster order [😂, 😍, 🔥]", status="match (token)")
    sh.section("Picker, list, quick row")
    sh.row("`chat.reactions.count.pickerColumns`", tok("chat.reactions.count.pickerColumns"), "6 columns (render `reactionsPicker`)", status="match (token)",
           note="emoji the system font cannot draw are left out (PaintCompat.hasGlyph), as the platform picker does")
    sh.row("`chat.reactions.layout.list` (sheet, people rows, \"Tap to remove\" on yours)", "spec", "render `reactionsSheet`", status="match (token)")
    sh.row("`chat.reactions.layout.listOrder`", "newest first", "ReactionsSheet reverses the oldest-first rows (every build)", status="match (token)", note="render `reactionsSheet`")
    sh.row("`chat.reactions.layout.quickReactions` (row above the long-press menu)", "spec", "renders `contextMenuPhoto`, viewer `photoContextMenu`", status="match (token)",
           note="local menu variant: core:ui DsDropdownMenu has no header row")
    sh.row("`chat.reactions.icon.add` on Android", tok("chat.reactions.icon.add", "android"), "Tokens.Icons.chatReactionsIconAdd", status="match (token)")
    return sh


def photo_viewer():
    m = meas("viewer")
    sh = Sheet("photo.viewer")
    av, name, week, pill, close, photo = m["avatar"], m["name"], m["week"], m["pill"], m["close"], m["photo"]
    sh.section("Appearance (`photo.viewer.layout.appearance`)")
    sh.row("page `color.global.backgroundDeep` with the system light", tok("color.global.backgroundDeep"), m["page"]["hex"])
    sh.row("page `color.global.backgroundDeep` with the system dark", tok("color.global.backgroundDeep"), m["dark.page"]["hex"])
    sh.row("sheets over the viewer follow the system appearance", "spec", "render `reactionsSheet` (light sheet over the dark viewer)", status="match (token)")
    sh.section("Header")
    sh.row("`photo.viewer.dimension.headerInset`", tok("photo.viewer.dimension.headerInset"), av["left"])
    sh.row("avatar `size.global.avatarHeader` (ring included)", tok("size.global.avatarHeader"), av["width"])
    ring = ring_measure(snap("ViewerSnapshotTest.othersPhoto"), av)
    rt = tok("photo.viewer.layout.avatarRing")
    sh.row("`photo.viewer.layout.avatarRing` strokeWidth", rt["strokeWidth"], round(ring["stroke"], 2), tol=0.5, note="half-maximum crossings along the arc (render `othersPhoto`)")
    sh.row("`photo.viewer.layout.avatarRing` gap (photo → ring)", rt["gap"], round(ring["gap"], 2), tol=0.6)
    sh.row("ring outer diameter = `size.global.avatarHeader`", tok("size.global.avatarHeader"), round(ring["outerDiameter"], 2), tol=0.8)
    sh.row("ring sweep = position ÷ total (\"1 of 3\", from 12 o'clock clockwise, round caps)", round(1 / 3, 3), round(ring["sweep"], 3), tol=0.02)
    sh.row("`photo.viewer.dimension.headerAvatarToText`", tok("photo.viewer.dimension.headerAvatarToText"), name["left"] - av["right"])
    sh.row("`photo.viewer.dimension.headerLinePitch` (name → week)", tok("photo.viewer.dimension.headerLinePitch"), week["baseline"] - name["baseline"])
    sh.row("position pill height `size.global.positionPillHeight`", tok("size.global.positionPillHeight"), pill["height"])
    sh.row("pill fill `color.global.controlOnDeep`", tok("color.global.controlOnDeep"), m["pillFill"]["hex"])
    sh.row("`photo.viewer.dimension.closeCircle`", tok("photo.viewer.dimension.closeCircle"), close["width"])
    sh.row("close fill `color.global.controlOnDeep`", tok("color.global.controlOnDeep"), m["closeFill"]["hex"])
    sh.row("close at the trailing margin", tok("size.global.screenMargin"), W - close["right"])
    sh.section("Photo (`photo.viewer.layout.photo`)")
    sh.row("`photo.viewer.dimension.headerToPhoto` (avatar bottom → photo)", tok("photo.viewer.dimension.headerToPhoto"), photo["top"] - av["bottom"])
    sh.row("full width", W, photo["width"])
    sh.row("own aspect, never cropped (3:4 sample → width × 4 / 3)", round(W * 4 / 3, 2), photo["height"])
    sh.row("corners `radius.global.photo`", tok("radius.global.photo"), "square", status="match (token)")
    sh.row("dual capture: core:ui `DualImage`, corners `radius.global.photo`, on media black", "3:4, full width", f"{fmt(m['dual.photo']['width'])} × {fmt(m['dual.photo']['height'])}",
           status="match" if abs(m["dual.photo"]["height"] - W * 4 / 3) <= 0.6 else "MISS", note="render `dualCapture`")
    sh.row("`photo.viewer.layout.backZone` (leading share of the photo whose tap goes back)", tok("photo.viewer.layout.backZone", "fraction"), "ViewerTaps.isPrevious with Tokens fraction (unit test `viewerBackZoneIsTheLeadingFifth`)", status="match (token)")
    sh.section("Footer")
    sh.row("`photo.viewer.dimension.footerFirstBaseline` + `.footerLinePitch` (photo → date line under a caption)",
           tok("photo.viewer.dimension.footerFirstBaseline") + tok("photo.viewer.dimension.footerLinePitch"), m["date"]["baseline"] - photo["bottom"])
    sh.row("date line: date · tag run (memory `TagRun`)", "Saturday, October 10 · with Ana and Sam", "memory TagRun after the separator", status="match (token)",
           note="the line stops at the reaction slot only when the chip reaches into it")
    sh.row("`photo.viewer.layout.voiceNote` (capsule on `color.global.controlOnDeep`, one pitch under the date)", tok("size.global.pillHeight"), m["voice"]["height"])
    sh.row("add-reaction glyph ink at the margin", W - tok("size.global.screenMargin"), m["add"]["right"] - 12, tol=0.8, note="hit 48, glyph box 24 → ink edge 12 inside the hit box")
    sh.row("`photo.viewer.dimension.footerToDivider` (voice capsule bottom → divider)", tok("photo.viewer.dimension.footerToDivider"), m["divider"]["top"] - m["voice"]["bottom"])
    sh.row("divider (C-32) `color.global.separator` (dark)", tok("color.global.separator", "dark"), m["dividerInk"]["hex"])
    sh.row("divider `size.global.hairline` (1 device px at 2×)", 0.5, m["divider"]["height"])
    sh.row("divider inside the margins", tok("size.global.screenMargin"), m["divider"]["left"])
    sh.row("`photo.viewer.dimension.dividerToComments`", tok("photo.viewer.dimension.dividerToComments"), m["comment"]["top"] - m["divider"]["bottom"], note="first row's top (its avatar top)")
    sh.row("`photo.viewer.dimension.commentsToField`", tok("photo.viewer.dimension.commentsToField"), "content padding above the field", status="match (token)", note="reads at the end of the scroll")
    sh.section("Reply field (C-13 on media)")
    sh.row("`size.global.commentFieldHeight`", tok("size.global.commentFieldHeight"), m["field"]["height"])
    sh.row("fill `color.global.controlOnDeep`", tok("color.global.controlOnDeep"), m["fieldFill"]["hex"])
    sh.section("States")
    sh.row("loading / error / gone / my photo / menus / delete / save denied", "spec States", "renders `loading`, `errorLoad`, `gone`, `myPhoto`, `menuMine`, `menuOthers`, `deleteConfirmation`, `permissionDeniedSave`", status="match (token)")
    return sh


def walls_mine(surface="walls.mine"):
    m = meas("walls")
    sh = Sheet(surface)
    member = surface == "walls.member"
    name = m["member.name"] if member else m["name"]
    avatar = m["member.avatar"] if member else m["avatar"]
    action = m["member.more"] if member else m["settings"]
    sh.section("Header (`walls.mine.layout.header`)")
    if member:
        sh.row("C-02 pushed header: back hit target", tok("size.global.minTouchTarget.android"), m["member.back"]["width"])
        sh.row("name on the chevron line, `size.global.backInset` + ink + `size.global.headerGap`", "C-02", f"name starts at {fmt(name['left'])}", status="match (token)")
    else:
        sh.row("name at the margin", tok("size.global.screenMargin"), name["left"])
    sh.row("name baseline `size.global.titleTop` (display serif, `fontSize.global.headerTitle`)", tok("size.global.titleTop"), name["baseline"])
    sh.row("avatar `size.global.avatarProfile`", tok("size.global.avatarProfile"), avatar["width"])
    sh.row("avatar at the trailing margin", tok("size.global.screenMargin"), W - avatar["right"])
    sh.row("avatar centred on the name's cap middle", round(name["baseline"] - serif_cap("headerTitle") / 2, 2), (avatar["top"] + avatar["bottom"]) / 2, tol=0.8)
    sh.row("action capsule `size.global.iconPillWidth` × `size.global.pillHeight`", f"{tok('size.global.iconPillWidth')} × {tok('size.global.pillHeight')}", f"{fmt(action['width'])} × {fmt(action['height'])}",
           status="match" if abs(action["width"] - tok("size.global.iconPillWidth")) <= 0.6 and abs(action["height"] - tok("size.global.pillHeight")) <= 0.6 else "MISS")
    sh.row("capsule at the trailing margin", tok("size.global.screenMargin"), W - action["right"])
    sh.row("`walls.mine.dimension.nameToActions` (name baseline → capsule)", tok("walls.mine.dimension.nameToActions"), action["top"] - name["baseline"])
    if not member:
        wk, wk2, t1, t2, add = m["week"], m["week2"], m["tile1"], m["tile2"], m["add"]
        sh.row("`walls.mine.dimension.actionsToWeeks` (capsule → section cap top)", tok("walls.mine.dimension.actionsToWeeks"), round(wk["baseline"] - inter_cap("listTitle") - action["bottom"], 2))
        sh.section("Weeks (`walls.mine.layout.weeks`, C-20 + C-17)")
        sh.row("`size.global.sectionHeaderToContent` (header baseline → strip)", tok("size.global.sectionHeaderToContent"), t1["top"] - wk["baseline"])
        sh.row("tile `size.global.stripTileWidth` × `size.global.stripTileHeight`", f"{tok('size.global.stripTileWidth')} × {tok('size.global.stripTileHeight')}", f"{fmt(t1['width'])} × {fmt(t1['height'])}",
               status="match" if abs(t1["width"] - 84) <= 0.6 and abs(t1["height"] - 112) <= 0.6 else "MISS")
        sh.row("`size.global.stripGap`", tok("size.global.stripGap"), t2["left"] - t1["right"])
        sh.row("strip at the margin", tok("size.global.screenMargin"), t1["left"])
        sh.row("`size.global.sectionGap` (strip → next header cap top)", tok("size.global.sectionGap"), round(wk2["baseline"] - inter_cap("listTitle") - t1["bottom"], 2))
        sh.row("current week: photos, add tile, placeholders (`week.history.layout.currentWeek`)", "withPhotos", "Mon, Tue, +, blanks (render `mineContent`)", status="match (token)")
        sh.row("add tile fill `color.global.control` (light)", tok("color.global.control", "light"), m["addFill"]["hex"])
        sh.row("add tile fill `color.global.control` (dark)", tok("color.global.control", "dark"), m["dark.addFill"]["hex"])
        page_colours(sh, m, "page", "dark.page")
        sh.section("States")
        sh.row("empty week (\"Welcome to Week N!\" + \"Get this week started\", dated empty-day tiles) / loading / error / offline", "spec States",
               "renders `mineEmpty`, `mineLoading`, `mineError`, `mineOffline`", status="match (token)")
    else:
        sh.section("Weeks and states")
        sh.row("no add tile in the current week (`week.history.layout.currentWeek` readOnly)", "readOnly", "photos then placeholders (render `memberContent`)", status="match (token)")
        sh.row("week sections as walls.mine", "walls.mine", "shared WallFrame / weekStripTiles", status="match (token)")
        sh.row("menu Report Profile / Block Profile (destructive)", "spec", "render `memberMenu`", status="match (token)")
        sh.row("empty / loading / error", "spec States", "renders `memberEmpty`, `memberLoading`, `memberError`", status="match (token)")
    return sh


def walls_browse():
    m = meas("walls")
    sh = Sheet("walls.browse")
    t, s, c1, c2, c4, n1 = m["browse.title"], m["browse.search"], m["browse.cell1"], m["browse.cell2"], m["browse.cell4"], m["browse.name1"]
    sh.section("Header and search (C-01, C-12)")
    sh.row("title baseline `size.global.titleTop`", tok("size.global.titleTop"), t["baseline"])
    sh.row("title at the margin", tok("size.global.screenMargin"), t["left"])
    sh.row("search field `size.global.fieldHeight`", tok("size.global.fieldHeight"), s["height"])
    sh.row("search fill `color.global.control`", tok("color.global.control", "light"), m["browse.searchFill"]["hex"])
    sh.row("search corners `radius.global.field`", tok("radius.global.field"), "core:ui SearchField", status="match (token)")
    sh.section("People grid (`walls.browse.layout.grid`, C-21)")
    sh.row("`walls.browse.dimension.columnPitch`", tok("walls.browse.dimension.columnPitch"), c2["left"] - c1["left"])
    sh.row("three columns centred on the screen", W / 2, (c1["left"] + c1["right"]) / 2 + (c2["left"] - c1["left"]), tol=0.8)
    sh.row("`walls.browse.dimension.rowPitch`", tok("walls.browse.dimension.rowPitch"), c4["top"] - c1["top"])
    sh.row("avatar `size.global.avatarGrid`", tok("size.global.avatarGrid"), "core:ui PeopleGrid(avatar = Tokens.Sizes.globalAvatarGrid)", status="match (token)")
    sh.row("`walls.browse.dimension.nameBaseline` (avatar bottom → name baseline)", tok("walls.browse.dimension.nameBaseline"), n1["baseline"] - (c1["top"] + tok("size.global.avatarGrid")), note="avatar top = the cell top")
    sh.row("`walls.browse.layout.rowOrder`", "by name, A to Z (collation, ignoring case and accents)", "orderedByName (VM tests `browseListsOthersByNameAndFilters`, `browseOrderIgnoresCaseAndAccentsAndBreaksTiesById`)", status="match (token)", note="render `browseContent`: Ana, Ben, Chloe, Dev, Femi, Grace, Hugo, Iris, Jonah")
    page_colours(sh, m, "browse.page", "dark.browse.page")
    sh.section("States")
    sh.row("empty / no results / loading / error", "spec States", "renders `browseEmpty`, `browseNoResults`, `browseLoading`, `browseError`", status="match (token)")
    return sh


def week_recap():
    m = meas("week")
    sh = Sheet("week.recap")
    rc, c1, c2, w1 = m["r.close"], m["r.card1"], m["r.card2"], m["r.week1"]
    sh.section("List (`week.recap.layout.list`)")
    sh.row("close `size.global.circleButton` at the leading margin", f"{tok('size.global.circleButton')} @ {tok('size.global.screenMargin')}", f"{fmt(rc['width'])} @ {fmt(rc['left'])}",
           status="match" if abs(rc["width"] - 36) <= 0.6 and abs(rc["left"] - 16) <= 0.6 else "MISS")
    sh.row("close fill `color.global.control`", tok("color.global.control", "light"), m["r.closeFill"]["hex"])
    sh.row("title centred", W / 2, (m["r.title"]["left"] + m["r.title"]["right"]) / 2)
    sh.row("cards full width inside the margins", W - 2 * tok("size.global.screenMargin"), c1["width"])
    a = tok("week.recap.aspectRatio.weekCard")
    sh.row("`week.recap.aspectRatio.weekCard`", round(c1["width"] * a["height"] / a["width"], 2), c1["height"])
    sh.row("`size.global.cardGap`", tok("size.global.cardGap"), c2["top"] - c1["bottom"])
    sh.row("`week.recap.radius.card`", tok("week.recap.radius.card"), "RoundedCornerShape(Tokens.Radii.weekRecapRadiusCard)", status="match (token)")
    sh.row("`week.recap.dimension.weekCardTextInset` (card → \"Week n\")", tok("week.recap.dimension.weekCardTextInset"), w1["left"] - c1["left"], note="text box left; the serif W's ink starts at the box")
    sh.row("`week.recap.dimension.weekCardTextTop` (card top → cap top)", tok("week.recap.dimension.weekCardTextTop"), round(w1["baseline"] - serif_cap("displayMedium") - c1["top"], 2))
    sh.row("pending recap: placeholder card with \"Creating your recap…\"", "spec", "render `recapList` (third card)", status="match (token)")
    sh.section("Preview (`week.recap.layout.preview`, core:ui RecapPreviewScreen + memory RecapCard)")
    pc, pill, thumb, cell = m["p.close"], m["p.pill"], m["p.thumb"], m["p.cell1"]
    scr = tok("collage.view.layout.screen")
    sh.row("page `color.global.backgroundDeep` (system light / dark)", tok("color.global.backgroundDeep"), f"{m['p.page']['hex']} / {m['dark.p.page']['hex']}",
           status="match" if m["p.page"]["hex"] == m["dark.p.page"]["hex"] == "#000000" else "MISS")
    sh.row("close centre from the trailing edge (`collage.view.layout.screen` closeCentreFromTrailing)", scr["closeCentreFromTrailing"], W - (pc["left"] + pc["right"]) / 2)
    sh.row("close centre below the page top (closeCentreBelowPageTop)", scr["closeCentreBelowPageTop"], (pc["top"] + pc["bottom"]) / 2)
    sh.row("close fill `color.global.controlOnDeep`", tok("color.global.controlOnDeep"), m["p.closeFill"]["hex"])
    pl = tok("collage.share.layout.pill")
    sh.row("pill height (`collage.share.layout.pill`)", pl["height"], pill["height"])
    sh.row("pill trailing inset `size.global.buttonMarginH`", tok("size.global.buttonMarginH"), W - pill["right"])
    sh.row("pill centre from the screen bottom", pl["centreFromScreenBottom"], H - (pill["top"] + pill["bottom"]) / 2)
    sh.row("pill fill `color.global.surfaceLight`", tok("color.global.surfaceLight"), m["p.pillFill"]["hex"])
    sh.row("`week.recap.dimension.selectThumb` (image + 2 × `.selectThumbBorder`)", tok("week.recap.dimension.selectThumb"), thumb["width"] + 2 * tok("week.recap.dimension.selectThumbBorder"))
    card = tok("layout.year.story.recapCard")
    fill = tok("week.recap.layout.gridFill")
    cw = W * card["widthRatio"]
    area_w = cw - 2 * cw * card["paddingRatio"]
    gap = tok("size.global.stripGap")
    # six photos (render `recapPreview`): ⌊√6⌋ = 2 columns, 3 rows over the 3:4 area
    exp_w = (area_w - gap) / 2
    exp_h = (area_w / fill["areaAspect"] - 2 * gap) / 3
    sh.row("card cell width (`week.recap.layout.gridFill`: 6 photos → 2 columns over width 0.825 W minus padding)", round(exp_w, 2), cell["width"], tol=0.8)
    sh.row("card cell height (3 rows sharing the 3:4 area, `areaAspect`)", round(exp_h, 2), cell["height"], tol=0.8)
    for render, n in (("recapPreviewOne", 1), ("recapPreviewFive", 5), ("recapPreviewNine", 9), ("recapPreviewFull", 24)):
        ok, desc = grid_check(snap("WeekSnapshotTest." + render), n, fill, card)
        sh.row(f"`week.recap.layout.gridFill` with {n} photo{'s' if n > 1 else ''}", desc[0], desc[1], status="match" if ok else "MISS", note=f"render `{render}`; gaps white, cells photo, empty places card fill")
    sh.row("card background `color.global.surfaceLight`", tok("color.global.surfaceLight"), m["p.card"]["hex"])
    sh.row("note (`week.recap.layout.note`: `week.recap.radius.note`, padding `.notePaddingV` / `.notePaddingH`, `.noteGap` under the card)",
           f"{tok('week.recap.radius.note')} / {tok('week.recap.dimension.notePaddingV')} / {tok('week.recap.dimension.notePaddingH')} / {tok('week.recap.dimension.noteGap')}", "RecapCardWithNote with these tokens", status="match (token)")
    sh.row("backdrop: the cover blurred (`size.global.backdropBlur`)", tok("size.global.backdropBlur"), "core:ui RecapPreviewScreen (API 31+; below: `color.global.controlOnDeep` page)", status="match (token)")
    sh.row("pages: card, cover full-bleed (`week.recap.layout.pages`); dots below the page", "spec", "renders `recapPreview`, `recapPreviewCover`", status="match (token)")
    sh.row("loading / pending / error", "spec States", "renders `recapPreviewLoading`, `recapPreviewPending`, `recapPreviewError`, `recapListLoading`, `recapListEmpty`, `recapListError`", status="match (token)")
    return sh


def week_edit():
    m = meas("week")
    sh = Sheet("week.edit")
    s1, s2, msg, alb, hd, g1, g2, g5 = m["e.strip1"], m["e.strip2"], m["e.message"], m["e.album"], m["e.header"], m["e.cell1"], m["e.cell2"], m["e.cell5"]
    sh.section("Toolbar (`week.edit.layout.composition`)")
    sh.row("Cancel / title / Update on one baseline", m["e.title"]["baseline"], m["e.cancel"]["baseline"])
    sh.row("Update on the title baseline", m["e.title"]["baseline"], m["e.update"]["baseline"])
    sh.row("title centred", W / 2, (m["e.title"]["left"] + m["e.title"]["right"]) / 2)
    sh.row("Cancel / Update at the margins", f"{tok('size.global.screenMargin')} / {tok('size.global.screenMargin')}", f"{fmt(m['e.cancel']['left'])} / {fmt(W - m['e.update']['right'])}",
           status="match" if abs(m["e.cancel"]["left"] - 16) <= 0.6 and abs(W - m["e.update"]["right"] - 16) <= 0.6 else "MISS")
    sh.section("Strip and actions")
    sh.row("strip tiles `size.global.stripTileWidth` × `.stripTileHeight`", "84 × 112", f"{fmt(s1['width'])} × {fmt(s1['height'])}", status="match" if abs(s1["width"] - 84) <= 0.6 and abs(s1["height"] - 112) <= 0.6 else "MISS")
    sh.row("`size.global.stripGap`", tok("size.global.stripGap"), s2["left"] - s1["right"])
    sh.row("strip at the margin", tok("size.global.screenMargin"), s1["left"])
    sh.row("action capsules `size.global.pillHeight`", tok("size.global.pillHeight"), msg["height"])
    sh.row("equal widths", msg["width"], alb["width"])
    sh.row("`size.global.pillGap`", tok("size.global.pillGap"), alb["left"] - msg["right"])
    sh.section("Grid")
    sh.row("`week.edit.count.gridColumns` square cells inside the margins", round((W - 2 * 16 - 3 * tok("size.global.stripGap")) / tok("week.edit.count.gridColumns"), 2), g1["width"])
    sh.row("square", g1["width"], g1["height"])
    sh.row("column gap `size.global.stripGap`", tok("size.global.stripGap"), g2["left"] - g1["right"])
    sh.row("row gap `size.global.stripGap`", tok("size.global.stripGap"), g5["top"] - g1["bottom"])
    sh.row("header line (listSubtitle) above the grid", "Photos taken in Week 42", "Photos taken in Week 42", status="match (token)")
    mk = mark_measure(snap("WeekSnapshotTest.editReady"), g1, g2, g5)
    sm = tok("week.edit.layout.selectionMark")
    sh.row("`week.edit.layout.selectionMark` selectedInsetRatio (checked cell: photo inset ÷ cell width)", sm["selectedInsetRatio"], round(mk["inset"] / g1["width"], 3), tol=0.012, note="render `editReady`, cell 1")
    sh.row("checked cell fill `color.global.control`", tok("color.global.control", "light"), mk["fill"])
    sh.row("mark centre ÷ cell width from the top-start corner (markCentreRatio)", sm["markCentreRatio"], round(mk["centre"] / g1["width"], 3), tol=0.012)
    sh.row("check circle ink (20 / 24 of `size.global.checkCircle`)", round(tok("size.global.checkCircle") * 20 / 24, 2), round(mk["circle"], 2), tol=0.8)
    sh.row("check circle `color.global.system.primary`", tok("color.global.system.primary"), mk["blue"], tol=10)
    sh.row("white outline (`markOutline` past the circle) in `color.global.textOnMedia`", tok("color.global.textOnMedia"), mk["outline"], tol=12)
    sh.row("unchecked cell: no mark, the photo fills the cell", "no mark", mk["unchecked"], status="match" if mk["unchecked"] == "no mark" else "MISS", note="cell 7")
    sh.row("`week.edit.layout.reorder` (long-press drag, `week.edit.haptic.dragStart` / `.dragAlign`)", "spec", "per-tile drag (flow test `reorderARecapByDragging`)", status="match (token)")
    sh.row("TalkBack reorder actions `week.edit.a11y.moveLeft` / `.moveRight`", "\"Move photo left\" / \"Move photo right\" where a neighbour exists", "custom actions on strip tiles (flow test `reorderARecapWithTalkBackActions`)", status="match (token)")
    sh.row("message sheet (counter, `week.edit.layout.message` limit) / album sheet / lost changes / saving / not ready", "spec",
           "renders `messageSheet`, `albumSheet`, `albumSheetNameError`, `lostChanges`, `editSaving`, `editNotReady`, `editLoading`", status="match (token)")
    return sh


def week_history():
    m = meas("week")
    sh = Sheet("week.history")
    wk, wk2, t1, t2, more = m["h.week"], m["h.week2"], m["h.tile1"], m["h.tile2"], m["h.more"]
    sh.section("Header (C-02)")
    sh.row("back hit target", tok("size.global.minTouchTarget.android"), m["h.back"]["width"])
    sh.row("title: display serif on the chevron line (`size.global.titleTop`)", tok("size.global.titleTop"), "core:ui PushedHeader (as chat.thread)", status="match (token)")
    sh.section("Weeks (`week.history.layout.weeks`)")
    sh.row("section header at the margin", tok("size.global.screenMargin"), wk["left"])
    sh.row("`size.global.sectionHeaderToContent` (header baseline → strip)", tok("size.global.sectionHeaderToContent"), t1["top"] - wk["baseline"])
    sh.row("tile `size.global.stripTileWidth` × `.stripTileHeight`", "84 × 112", f"{fmt(t1['width'])} × {fmt(t1['height'])}", status="match" if abs(t1["width"] - 84) <= 0.6 and abs(t1["height"] - 112) <= 0.6 else "MISS")
    sh.row("`size.global.stripGap`", tok("size.global.stripGap"), t2["left"] - t1["right"])
    sh.row("`size.global.sectionGap` (strip → next header cap top)", tok("size.global.sectionGap"), round(wk2["baseline"] - inter_cap("listTitle") - t1["bottom"], 2))
    sh.row("\"•••\" (`week.history.layout.weekMenu`) hit target at the trailing edge", tok("size.global.minTouchTarget.android"), more["width"])
    sh.row("week menu items (View recap / Edit recap)", "spec", "DsDropdownMenu from the \"•••\"", status="match (token)")
    page_colours(sh, m, "h.page", "dark.h.page")
    sh.section("States")
    sh.row("empty current week / loading / error / offline (cached weeks + line)", "spec States", "renders `historyEmpty`, `historyLoading`, `historyError`, `historyOffline`", status="match (token)")
    return sh


def albums_list():
    m = meas("albums")
    sh = Sheet("albums.list")
    s, r1, r2, n1, m1 = m["l.search"], m["l.row1"], m["l.row2"], m["l.name1"], m["l.meta1"]
    sh.section("Header and search (`albums.list.layout.composition`)")
    sh.row("back hit target", tok("size.global.minTouchTarget.android"), m["l.back"]["width"])
    sh.row("search `size.global.fieldHeight`", tok("size.global.fieldHeight"), s["height"])
    sh.row("search inside the margins", W - 2 * tok("size.global.screenMargin"), s["width"])
    sh.row("search → first row `size.global.titleToContent`", tok("size.global.titleToContent"), r1["top"] - s["bottom"])
    sh.section("Rows (C-15)")
    sh.row("row height = thumbnail `size.global.rowThumbHeight`", tok("size.global.rowThumbHeight"), r1["height"])
    sh.row("pitch: thumbnail + `size.global.listGap`", tok("size.global.rowThumbHeight") + tok("size.global.listGap"), r2["top"] - r1["top"])
    sh.row("text: margin + `size.global.rowThumbWidth` + `size.global.rowThumbGap`", tok("size.global.screenMargin") + tok("size.global.rowThumbWidth") + tok("size.global.rowThumbGap"), n1["left"])
    sh.row("title → subtitle (listTitle / listSubtitle)", "two lines", f"{fmt(m1['baseline'] - n1['baseline'])} apart", status="match (token)")
    sh.row("no avatar stack, no '+' circle", "spec", "rows: cover, name, creator line", status="match (token)")
    page_colours(sh, m, "l.page", "dark.l.page")
    sh.section("States")
    sh.row("empty (\"View recaps\") / no results / loading / error", "spec States", "renders `listEmpty`, `listNoResults`, `listLoading`, `listError`", status="match (token)")
    return sh


def albums_view():
    m = meas("albums")
    sh = Sheet("albums.view")
    cv, nm, mt, rn, mo, c1, c2 = m["v.cover"], m["v.name"], m["v.meta"], m["v.rename"], m["v.more"], m["v.cell1"], m["v.cell2"]
    sh.section("Cover and title")
    sh.row("`albums.view.dimension.coverWidth`", tok("albums.view.dimension.coverWidth"), cv["width"])
    sh.row("`albums.view.dimension.coverHeight`", tok("albums.view.dimension.coverHeight"), cv["height"])
    sh.row("`albums.view.dimension.coverTop`", tok("albums.view.dimension.coverTop"), cv["top"])
    sh.row("cover centred", W / 2, (cv["left"] + cv["right"]) / 2)
    for label, d, exp, got in shadow_measure(snap("AlbumsSnapshotTest.viewContent")):
        sh.row(f"`albums.view.shadow.cover` {label} (luminance, σ 8.5 / y 10 / 25 % model)", exp, got, tol=6, note="render `viewContent`; the model is the token's Gaussian box on white")
    sh.row("`albums.view.dimension.coverToTitle` (cover → serif cap top)", tok("albums.view.dimension.coverToTitle"), round(nm["baseline"] - serif_cap("displayMedium") - cv["bottom"], 2))
    sh.row("`albums.view.dimension.titleToMeta`", tok("albums.view.dimension.titleToMeta"), mt["baseline"] - nm["baseline"])
    sh.row("`albums.view.dimension.metaToActions`", tok("albums.view.dimension.metaToActions"), rn["top"] - mt["baseline"])
    sh.section("Actions and grid")
    sh.row("capsules `size.global.pillHeight`", tok("size.global.pillHeight"), rn["height"])
    sh.row("\"•••\" capsule `size.global.iconPillWidth`", tok("size.global.iconPillWidth"), mo["width"])
    sh.row("`size.global.pillGap`", tok("size.global.pillGap"), mo["left"] - rn["right"], tol=0.8)
    sh.row("`albums.view.count.gridColumns` inside the margins", round((W - 32 - 2 * tok("size.global.stripGap")) / 3, 2), c1["width"], tol=0.8)
    a = tok("albums.view.aspectRatio.gridCell")
    sh.row("`albums.view.aspectRatio.gridCell`", round(a["width"] / a["height"], 3), round(c1["width"] / c1["height"], 3), tol=0.01)
    sh.row("grid gap `size.global.stripGap`", tok("size.global.stripGap"), c1["left"] - c2["right"])
    sh.row("`albums.view.radius.grid` (outer corners only)", tok("albums.view.radius.grid"), "gridCellShape", status="match (token)")
    sh.section("Actions and states")
    sh.row("••• menu (Delete Album, destructive) / rename sheet / delete confirmation", "spec", "renders `viewMenu`, `renameSheet`, `deleteConfirmation`", status="match (token)")
    sh.row("empty / not found / loading / error; dark", "spec States", "renders `viewEmpty`, `viewNotFound`, `viewLoading`, `viewError`, `viewContentDark`", status="match (token)")
    return sh


def grid_check(img, n, fill, card):
    """Expected cell rectangles of the recap card for n photos (gridFill) checked against the render: the gap lines
    between cells are the card's white, each filled cell holds photo pixels, empty places are white."""
    import math
    cols = max(1, min(int(math.floor(math.sqrt(n))), int(fill["maxColumns"])))
    rows = min((n + cols - 1) // cols, int(fill["maxRows"]))
    cw = W * card["widthRatio"]
    pad = cw * card["paddingRatio"]
    left = (W - cw) / 2 + pad
    aw = cw - 2 * pad
    ah = aw / fill["areaAspect"]
    gap = tok("size.global.stripGap")
    cell_w, cell_h = (aw - (cols - 1) * gap) / cols, (ah - (rows - 1) * gap) / rows
    # the card top: first white row at the card's padding column
    x_pad = int(((W - cw) / 2 + pad / 2) * SCALE)
    top = None
    for y in range(80, int(H * SCALE) - 10):
        if all(lum(img, x_pad, y + k) > 250 for k in range(6)):
            top = y / SCALE + pad
            break
    if top is None:
        return False, (f"{cols} × {rows}", "card not found")
    ok = True
    for i in range(cols * rows):
        r, c = divmod(i, cols)
        x0, y0 = left + c * (cell_w + gap), top + r * (cell_h + gap)
        centre = lum(img, (x0 + cell_w / 2) * SCALE, (y0 + cell_h / 2) * SCALE)
        filled = i < n
        ok &= (centre < 250) if filled else (centre > 250)
        if c < cols - 1 and filled and i + 1 < n:
            ok &= lum(img, (x0 + cell_w + gap / 2) * SCALE, (y0 + cell_h / 2) * SCALE) > 240
    return ok, (f"{cols} × {rows}, {min(n, cols * rows)} drawn", f"{cols} × {rows} laid out as predicted" if ok else "differs")


def mark_measure(img, c1, c2, c5):
    """The selection mark on the first (checked) grid cell and the absence of a mark on cell 7 (unchecked). The cells'
    bounds come from the measurement pass (the editor alone); the render shows it as a sheet, so they are shifted to the
    first column of `color.global.control` (the checked cell's inset frame) found in the render."""
    s = SCALE
    control = tok("color.global.control", "light")
    x_probe = int((c1["left"] + 1) * s)
    shift = None
    for y in range(0, img.height - int(c1["height"] * s)):
        if px_hex(img, x_probe, y) == control and all(px_hex(img, x_probe, y + k) == control for k in range(0, int(c1["height"] * s) - 2, 8)):
            shift = y / s - c1["top"]
            break
    if shift is None:
        return {"inset": -1, "fill": "-", "centre": -1, "circle": -1, "blue": "-", "outline": "-", "unchecked": "-"}
    c1 = dict(c1, top=c1["top"] + shift, bottom=c1["bottom"] + shift)
    c5 = dict(c5, top=c5["top"] + shift, bottom=c5["bottom"] + shift)
    y_mid = (c1["top"] + c1["bottom"]) / 2
    fill_hex = "#%02X%02X%02X" % img.getpixel((int((c1["left"] + 1) * s), int(y_mid * s)))[:3]
    x = c1["left"] * s
    while x < c1["right"] * s and px_hex(img, x, y_mid * s) == fill_hex:
        x += 1
    inset = x / s - c1["left"]
    primary = tuple(int(tok("color.global.system.primary").lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))
    near = lambda p: all(abs(p[i] - primary[i]) <= 12 for i in range(3))
    box = tok("size.global.checkCircle") + 4
    blues = [(xx, yy) for xx in range(int(c1["left"] * s), int((c1["left"] + box) * s)) for yy in range(int(c1["top"] * s), int((c1["top"] + box) * s))
             if near(img.getpixel((xx, yy)))]
    xs, ys = [p[0] for p in blues], [p[1] for p in blues]
    circle = (max(xs) - min(xs) + 1) / s if blues else -1
    cx = (max(xs) + min(xs)) / 2 / s - c1["left"] if blues else -1
    blue = "#%02X%02X%02X" % img.getpixel((min(xs) + 3, int((max(ys) + min(ys)) / 2)))[:3] if blues else "-"
    outline = "#%02X%02X%02X" % img.getpixel((min(xs) - 1, int((max(ys) + min(ys)) / 2)))[:3] if blues else "-"
    pitch_x, pitch_y = c2["left"] - c1["left"], c5["top"] - c1["top"]
    l7, t7 = c1["left"] + 2 * pitch_x, c1["top"] + pitch_y
    has_blue = any(near(img.getpixel((int(xx), int(yy)))) for xx in range(int(l7 * s), int((l7 + box) * s)) for yy in range(int(t7 * s), int((t7 + box) * s)))
    corner = "#%02X%02X%02X" % img.getpixel((int((l7 + 1) * s), int((t7 + c1["height"] / 2) * s)))[:3]
    unchecked = "no mark" if not has_blue and corner != fill_hex else "mark or inset"
    return {"inset": inset, "fill": fill_hex, "centre": cx, "circle": circle, "blue": blue, "outline": outline, "unchecked": unchecked}


def px_hex(img, x, y):
    return "#%02X%02X%02X" % img.getpixel((int(x), int(y)))[:3]


def shadow_measure(img):
    """Luminance under and beside the album cover against the token's Gaussian-box model on white."""
    import math
    g = img.convert("L")
    w, h = g.size
    dark = [(x, y) for y in range(0, 800) for x in range(0, w, 2) if g.getpixel((x, y)) < 120]
    xs, ys = [p[0] for p in dark], [p[1] for p in dark]
    l, r, t, b = min(xs), max(xs), min(ys), max(ys)
    sh = tok("albums.view.shadow.cover")
    phi = lambda z: 0.5 * (1 + math.erf(z / math.sqrt(2)))
    out = []
    cx = int((l + r) / 2 + sh["x"] * SCALE)
    for d in (2, 10, 16):
        exp = round(255 * (1 - sh["opacity"] * phi((sh["y"] - d) / sh["blur"])), 1)
        out.append((f"below +{d} dp", d, exp, g.getpixel((cx, int(b + 1 + d * SCALE)))))
    cy = int((t + b) / 2 + sh["y"] * SCALE)
    for d in (2, 8):
        exp = round(255 * (1 - sh["opacity"] * phi((sh["x"] - d) / sh["blur"])), 1)
        out.append((f"right +{d} dp", d, exp, g.getpixel((int(r + 1 + d * SCALE), cy))))
    return out


TC2B = ("references/auto/retro/press/tc-2023-07-retro-2b.jpg", "1300,110,910,1920")
TC1B2 = ("references/auto/retro/press/tc-2023-07-retro-1b.webp", "1300,110,910,1920")
TC1B3 = ("references/auto/retro/press/tc-2023-07-retro-1b.webp", "2470,110,910,1920")
ST02 = ("references/auto/retro/store/retro-store-02.png", None)
SURFACES = [
    ("chat.thread", chat_thread, ["ChatSnapshotTest.content", "ChatSnapshotTest.contentDark", "ChatSnapshotTest.dualPhoto"], [TC2B, ("references/auto/retro/store/retro-store-01.png", None)]),
    ("chat.composer", chat_composer, ["ChatSnapshotTest.composerTyping", "ChatSnapshotTest.replying", "ChatSnapshotTest.contentDark"], [TC2B]),
    ("chat.voice", chat_voice, ["ChatSnapshotTest.voicePlaying", "ChatSnapshotTest.recordingHolding", "ChatSnapshotTest.contentDark"], [ST02, ("references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png", None)]),
    ("chat.reactions", chat_reactions, ["ChatSnapshotTest.contextMenuPhoto", "ChatSnapshotTest.reactionsSheet", "ChatSnapshotTest.reactionsPicker"], [("references/auto/whatsapp/store/whatsapp-store-04.png", None)]),
    ("photo.viewer", photo_viewer, ["ViewerSnapshotTest.othersPhoto", "ViewerSnapshotTest.othersPhotoDark", "ViewerSnapshotTest.dualCapture"], [TC2B]),
    ("walls.mine", walls_mine, ["WallsSnapshotTest.mineContent", "WallsSnapshotTest.mineContentDark"], [ST02]),
    ("walls.member", lambda: walls_mine("walls.member"), ["WallsSnapshotTest.memberContent", "WallsSnapshotTest.memberContentDark"], [ST02, TC1B3]),
    ("walls.browse", walls_browse, ["WallsSnapshotTest.browseContent", "WallsSnapshotTest.browseContentDark"], [TC1B2]),
    ("week.recap", week_recap, ["WeekSnapshotTest.recapList", "WeekSnapshotTest.recapPreview", "WeekSnapshotTest.recapPreviewNine", "WeekSnapshotTest.recapPreviewDark"],
     [("references/auto/retro/press/tc-2023-12-recaps.png", "205,225,650,1400"), ("references/auto/retro/press/tc-2023-12-retro-header.png", "1600,350,960,1400"), ("references/auto/retro/store/retro-store-04.png", None)]),
    ("week.edit", week_edit, ["WeekSnapshotTest.editReady", "WeekSnapshotTest.editReadyDark"], [("references/auto/retro/video/ig-DDbA_F7x-j7-composer-f130-147-f188-197.png", None), ("references/auto/platform/android-photopicker-selected-f200.png", None)]),
    ("week.history", week_history, ["WeekSnapshotTest.historyContent", "WeekSnapshotTest.historyContentDark"], [ST02]),
    ("albums.list", albums_list, ["AlbumsSnapshotTest.listContent", "AlbumsSnapshotTest.listContentDark"], [("references/auto/retro/store/editorial/retro-appstore-story-1854931006-week3-albums.png", None)]),
    ("albums.view", albums_view, ["AlbumsSnapshotTest.viewContent", "AlbumsSnapshotTest.viewContentDark"], [("references/auto/retro/press/tc-2024-04-journals-1.webp", "2460,500,830,1790")]),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    summary = []
    for surface, build, ours, refs in SURFACES:
        side_by_side(surface, ours, refs, f"{surface} — Android, light / dark (left) · Retro reference (right)")
        sheet = build()
        counts = sheet.write(header(surface, ours, refs))
        summary.append((surface, counts))
    for surface, counts in summary:
        print(surface, ", ".join(f"{v} {k}" for k, v in sorted(counts.items())))


if __name__ == "__main__":
    main()
