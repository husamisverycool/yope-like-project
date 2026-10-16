#!/usr/bin/env python3
"""Regenerates the memory group's Android verification (docs/SCREENS_BRIEF.md rule 8, Pass 4 Retro redesign).

For every memory surface: design/verification/<surface>.android.md — the spec's values (token → expected → what our
screen lays out → reference evidence) with matched / approximated / not matched — and <surface>.android.png, our
snapshots (light, and dark for the primary state) next to the Retro references the spec names (tools/sidebyside.py).

Inputs (run the module's tests first: ./gradlew :feature:memory:testDebugUnitTest):
  - android/feature/memory/build/verification/*.json  laid-out bounds and text baselines (MeasurementTest), dp
  - android/feature/memory/build/verification/*.png   the same screens with photos drawn black (2 px/dp), for ink,
                                                       circle and tick measurements
  - android/feature/memory/src/test/snapshots/         Roborazzi renders (393 × 852 dp at 2 px/dp, real sample photos)
  - design/tokens/*.json                               expected values and their evidence

Run from anywhere:  python3 -I android/feature/memory/verification/checklists.py [--no-images]
"""
import json
import math
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
MOD = os.path.join(ROOT, "android", "feature", "memory")
MEAS = os.path.join(MOD, "build", "verification")
SNAP = os.path.join(MOD, "src", "test", "snapshots")
OUT = os.path.join(ROOT, "design", "verification")
REF = os.path.join(ROOT, "references", "auto", "retro")
PX = 2.0  # px per dp (xhdpi renders)
W, H = 393.0, 852.0
TOL = 0.5  # dp: a laid-out value within half a dp of the token is a match
APPROX = 2.0  # dp: within two dp is an approximation

TOKENS = {}
for name in sorted(os.listdir(os.path.join(ROOT, "design", "tokens"))):
    if name.endswith(".json"):
        with open(os.path.join(ROOT, "design", "tokens", name)) as f:
            TOKENS.update(json.load(f).get("tokens", {}))


def tok(name, key=None, appearance="light"):
    v = TOKENS[name]["value"]
    if isinstance(v, dict) and key is not None:
        v = v[key]
    if isinstance(v, dict) and appearance in v:
        v = v[appearance]
    return v


def ev(name):
    e = TOKENS.get(name, {}).get("evidence", "")
    return (e[:100] + "…") if len(e) > 100 else e


_meas = {}


def m(name):
    if name not in _meas:
        p = os.path.join(MEAS, name + ".json")
        if not os.path.exists(p):
            sys.exit(f"missing {p}: run ./gradlew :feature:memory:testDebugUnitTest first")
        with open(p) as f:
            _meas[name] = json.load(f)
    return _meas[name]


_img = {}


def img(name):
    if name not in _img:
        _img[name] = Image.open(os.path.join(MEAS, name + ".png")).convert("RGB")
    return _img[name]


def snap(path):
    return os.path.join(SNAP, path)


def ink(name, rect, bg=None, thr=48):
    """Bounding box (dp) of the pixels in rect (dp: l, t, r, b) that differ from bg by more than thr."""
    im = img(name)
    l, t, r, b = (int(round(v * PX)) for v in rect)
    l, t, r, b = max(l, 0), max(t, 0), min(r, im.width), min(b, im.height)
    bg = bg or im.getpixel((l, t))
    xs, ys = [], []
    for y in range(t, b):
        for x in range(l, r):
            c = im.getpixel((x, y))
            if max(abs(c[i] - bg[i]) for i in range(3)) > thr:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return (min(xs) / PX, min(ys) / PX, (max(xs) + 1) / PX, (max(ys) + 1) / PX)


def first_glyph(name, node, bg=None, thr=48):
    """Ink box (dp) of a text node's first glyph (a capital in every probe): its top is the cap top."""
    rect = (node["left"], node["top"], node["right"], node["bottom"])
    whole = ink(name, rect, bg, thr)
    if whole is None:
        return None
    im = img(name)
    t, b = int(round(node["top"] * PX)), int(round(node["bottom"] * PX))
    bg = bg or im.getpixel((int(round(node["left"] * PX)), t))
    hit = lambda c: max(abs(c[i] - bg[i]) for i in range(3)) > thr
    x = int(round(whole[0] * PX))
    cols = []
    while x < im.width:
        ys = [y for y in range(t, b) if hit(im.getpixel((x, y)))]
        if not ys:
            break
        cols.append((x, min(ys), max(ys)))
        x += 1
    return (cols[0][0] / PX, min(c[1] for c in cols) / PX, (cols[-1][0] + 1) / PX, (max(c[2] for c in cols) + 1) / PX)


def brightest(name, rect):
    im = img(name)
    l, t, r, b = (int(round(v * PX)) for v in rect)
    best = (0, 0, 0)
    for y in range(max(t, 0), min(b, im.height)):
        for x in range(max(l, 0), min(r, im.width)):
            c = im.getpixel((x, y))
            if sum(c) > sum(best):
                best = c
    return best


def hexc(c):
    return "#%02X%02X%02X" % c[:3]


def over_black(hex8):
    """An #RRGGBBAA colour composited on black, as #RRGGBB."""
    h = hex8.lstrip("#")
    a = int(h[6:8], 16) / 255 if len(h) == 8 else 1
    return "#%02X%02X%02X" % tuple(round(int(h[i:i + 2], 16) * a) for i in (0, 2, 4))


def cy(b):
    return (b["top"] + b["bottom"]) / 2


def cx(b):
    return (b["left"] + b["right"]) / 2


def fmt(v):
    if v is None:
        return "—"
    if isinstance(v, float):
        return f"{round(v, 2):g}"
    return str(v)


class Sheet:
    def __init__(self, surface, intro, side_note):
        self.surface, self.intro, self.side_note = surface, intro, side_note
        self.sections = []
        self.counts = {}
        self.extra = ""

    def section(self, name):
        self.sections.append((name, []))

    def row(self, status, token, expected, ours, evidence="", note=""):
        self.sections[-1][1].append((status, token, expected, ours, evidence, note))
        self.counts[status] = self.counts.get(status, 0) + 1

    def dp(self, token, expected, ours, note="", evidence=None, tol=TOL, approx_note=None):
        """A laid-out dp value against its token value."""
        if ours is None:
            st = "not matched"
        else:
            d = abs(ours - expected)
            st = "match" if d <= tol else "approx" if d <= APPROX else "not matched"
        if st == "approx" and approx_note:
            note = (note + "; " if note else "") + approx_note
        name = token.split(" ")[0].strip("`")
        self.row(st, token, fmt(float(expected)), fmt(ours), ev(name) if evidence is None else evidence, note)

    def colour(self, token, expected_hex, ours_rgb, note="", tol=6):
        e = expected_hex.upper()[:7]
        er = tuple(int(e[i:i + 2], 16) for i in (1, 3, 5))
        st = "match" if ours_rgb and max(abs(a - b) for a, b in zip(er, ours_rgb)) <= tol else "not matched"
        self.row(st, token, expected_hex.upper(), hexc(ours_rgb) if ours_rgb else "—", ev(token.split(" ")[0].strip("`")), note)

    def token(self, token, ours, note="", evidence=None):
        name = token.split(" ")[0].strip("`")
        v = TOKENS.get(name, {}).get("value", "")
        if isinstance(v, dict):
            v = "; ".join(f"{k}: {x}" for k, x in list(v.items())[:4])
        self.row("match (token)", token, str(v)[:90], ours, ev(name) if evidence is None else evidence, note)

    def check(self, status, element, expected, ours, note="", evidence=""):
        self.row(status, element, expected, ours, evidence, note)

    def write(self, renders):
        total = sum(self.counts.values())
        order = ["match", "match (token)", "approx", "not matched"]
        summary = ", ".join(f"{self.counts[k]} {k}" for k in order if self.counts.get(k))
        lines = [
            f"# Verification — `{self.surface}` (Android)",
            "",
            self.intro,
            "",
            "Generated by `android/feature/memory/verification/checklists.py` (Pass 4, Retro redesign) from "
            "`MeasurementTest` (laid-out bounds and text baselines read back from the composed screens, dp, screen "
            "top-left, 393 × 852 dp, no status / navigation bar in Robolectric — on a device the safe-area offsets add to "
            "the top- and bottom-anchored values) and its renders with the photos drawn black (2 px/dp: ink, circles, "
            "ticks; ±0.5 dp). Expected values come from `design/tokens/*.json` and `design/surfaces/"
            f"{self.surface}.md`. Rows marked *match (token)* are drawn straight from the generated constant or a "
            "core:ui component (no read-back).",
            "",
            f"Side by side: [`{self.surface}.android.png`]({self.surface}.android.png) — {self.side_note}",
            "",
            "Snapshots (real sample photos, `fixtures/photos/`): " + ", ".join(f"`{r}`" for r in renders),
            "",
            f"**Result: {total} checks — {summary}.**",
            "",
        ]
        cell = lambda s: str(s).replace("|", "/").replace("\n", " ")
        for name, rows in self.sections:
            lines += [f"## {name}", "", "| status | token / element | expected | ours | reference evidence | note |", "|---|---|---|---|---|---|"]
            for r in rows:
                lines.append("| " + " | ".join(cell(x) for x in r) + " |")
            lines.append("")
        path = os.path.join(OUT, f"{self.surface}.android.md")
        with open(path, "w") as f:
            f.write("\n".join(lines) + self.extra)
        print(path, total, summary)


def renders(surface):
    d = os.path.join(SNAP, surface)
    return sorted(f"{surface}/{n}" for n in os.listdir(d) if n.endswith(".png"))


def states(s, surface, rows):
    """State rows: (state, snapshot stem, design note)."""
    have = set(renders(surface))
    for state, stem, note in rows:
        files = [f"{surface}/{stem}-light.png", f"{surface}/{stem}-dark.png"]
        shown = [f for f in files if f in have]
        s.check("match" if shown else "not matched", f"state `{state}`", "spec → States", ", ".join(os.path.basename(f) for f in shown) or "—", note)


# ---------------------------------------------------------------------------------------------------------- onthisday


def ray_extent(name, centre, deg, r0, r1, thr=40):
    """Along a ray from the dial centre (dp) at deg (clockwise from 3 o'clock), the lit radii between r0 and r1."""
    im = img(name)
    lit = []
    steps = int((r1 - r0) * PX * 4)
    for i in range(steps + 1):
        r = r0 + (r1 - r0) * i / steps
        x = (centre[0] + r * math.cos(math.radians(deg))) * PX
        y = (centre[1] + r * math.sin(math.radians(deg))) * PX
        c = im.getpixel((int(x), int(y)))
        if max(c) > thr:
            lit.append(r)
    return (min(lit), max(lit)) if lit else None


def onthisday():
    s = Sheet("onthisday", "Retro Rewind (`.../onthisday/`): the memory full bleed on the dark media page, the date title in "
              "the display serif with the 'On this day · {name}' line, the '•••' glass menu, and the control row — share, "
              "the 44-slot dial (tick haptic per slot crossed via `TickOnStep`), random; feature intro, menu, delete "
              "confirmation, save-denied alert; loading, empty, error, offline.",
              "ours (paused light / dark — the page is dark in both, playing, intro) next to RWB "
              "(`press/tc-2025-12-rewind-device-b.jpg`, dial at rest) and RWA (`press/tc-2025-12-rewind-device-a.png`, "
              "title + '•••').")
    j, n = m("onthisday"), "onthisday"
    t, sub, back, more = j["title"], j["subtitle"], j["back"], j["more"]
    s.section("Header (C-02 / C-35 on media)")
    bink = first_glyph(n, back, (0, 0, 0))  # the chevron: the first ink run in the back button
    s.dp("`size.global.backInset` (chevron ink from the leading edge)", tok("size.global.backInset"), bink[0], "core:ui HeaderIconButton + GlyphInk")
    tink = first_glyph(n, t, (0, 0, 0))
    s.dp("`size.global.headerGap` (chevron ink → title)", tok("size.global.headerGap"), t["left"] - bink[2], "title text box after the chevron's ink")
    s.dp("`size.global.titleTop` (title baseline)", tok("size.global.titleTop"), t["firstBaseline"], "RWA: 63.3 pt below the safe-area top")
    s.token("`fontSize.global.headerTitle` (text role `headerTitle`, `font.global.display`)", "TextRoles.headerTitle — 'Jul 22, 2022' (`layout.onthisday.dateFormat`, DateFormat MEDIUM)")
    s.colour("`color.global.textOnMedia` (title)", tok("color.global.textOnMedia"), brightest(n, (t["left"], t["top"], t["right"], t["bottom"])))
    s.dp("`dimension.onthisday.subtitleBaseline` (date baseline → subtitle baseline)", tok("dimension.onthisday.subtitleBaseline"), sub["firstBaseline"] - t["firstBaseline"], "ST-05: 26.4 pt")
    s.dp("subtitle aligned with the date's leading edge", t["left"], sub["left"], "same text box start")
    s.colour("`color.onthisday.subtitle` (#FFFFFFC2 on black)", over_black(tok("color.onthisday.subtitle")), brightest(n, (sub["left"], sub["top"], sub["right"], sub["bottom"])), "brightest pixel of the 17-sp regular line")
    mink = ink(n, (more["left"] - 2, more["top"] - 2, more["right"] + 2, more["bottom"] + 2), (0, 0, 0), thr=12)
    s.dp("`size.global.circleButtonPhoto` ('•••' glass circle)", tok("size.global.circleButtonPhoto"), mink[2] - mink[0], "C-11 glass, `CircleButtonStyle.Glass`")
    s.dp("`size.global.headerInset` (circle ink from the trailing edge)", tok("size.global.headerInset"), W - mink[2])
    cap_mid = (tink[1] + t["firstBaseline"]) / 2
    s.dp("'•••' centred on the date's cap middle", round(cap_mid, 2), (mink[1] + mink[3]) / 2, "cap middle from the 'J' ink top and the baseline", evidence="RWA '•••' 40 pt, centred on the title's cap middle", tol=0.75)
    s.colour("`color.global.glass` (#FFFFFF1F on black)", over_black(tok("color.global.glass")), img(n).getpixel((int((mink[0] + 4) * PX), int(cy(more) * PX))))
    s.section("Photo and scrim")
    p = j["photo"]
    s.check("match" if (p["left"], p["top"], p["right"], p["bottom"]) == (0, 0, W, H) else "not matched", "photo full bleed (`radius.global.photo` 0)", "0, 0 → 393 × 852", f"{fmt(p['left'])}, {fmt(p['top'])} → {fmt(p['width'])} × {fmt(p['height'])}", "aspect-fill, under the status bar; `onthisday.a11y.photo` label")
    s.token("`layout.global.photoScrim`", "core:ui PhotoScrimOverlay (black 0 → `color.global.scrim` from 55 %)")
    s.token("`layout.global.appearance`", "MediaAppearance: the page renders dark in both appearances; sheets / menus / dialogs follow the system (RM-16)")
    s.section("Control row (`layout.onthisday.controls`)")
    d, sh, rnd, play = j["dial"], j["share"], j["random"], j["play"]
    s.dp("`dimension.onthisday.dial.diameter` (dial box)", tok("dimension.onthisday.dial.diameter"), d["width"])
    s.dp("`dimension.onthisday.controls.centerY` (above the bottom)", tok("dimension.onthisday.controls.centerY"), H - cy(d), "RWB: 139.2 pt above the safe-area bottom")
    s.dp("dial centred (x)", W / 2, cx(d))
    for key, label in ((sh, "share"), (rnd, "random")):
        k = ink(n, (key["left"] - 2, key["top"] - 2, key["right"] + 2, key["bottom"] + 2), (0, 0, 0), thr=12)
        s.dp(f"`size.global.circleButtonLarge` ({label} glass circle)", tok("size.global.circleButtonLarge"), k[2] - k[0], "C-11 GlassLarge")
        s.dp(f"{label} on the dial's centre line", cy(d), cy(key))
    gaps = [sh["left"], d["left"] - sh["right"], rnd["left"] - d["right"], W - rnd["right"]]
    even = sum(gaps) / 4
    s.check("match" if max(gaps) - min(gaps) <= 1 else "not matched", "equal gaps: edge | share | dial | random | edge", f"4 × {fmt(even)}", " / ".join(fmt(g) for g in gaps), "Arrangement.SpaceEvenly", "RWB: equal gaps")
    centre = (cx(d), cy(d))
    R = tok("dimension.onthisday.dial.diameter") / 2
    geo = tok("layout.onthisday.dial")
    first, pitch = geo["firstSlotDegrees"], geo["pitchDegrees"]
    ind = ray_extent(n, centre, first, R - 30, R + 2, thr=180)
    s.dp("`dimension.onthisday.dial.indicatorLength` (slot 0, 6°)", tok("dimension.onthisday.dial.indicatorLength"), ind and ind[1] - ind[0], "visible length along the ray, round caps included (StrokeCap.Round)", tol=1.0)
    s.dp("dial outer edge (ring radius = diameter ÷ 2)", R, ind and ind[1], "outermost lit radius of the indicator", tol=1.0)
    for slot, token in ((2, "dimension.onthisday.dial.tickLong"), (1, "dimension.onthisday.dial.tickShort")):
        e = ray_extent(n, centre, first + slot * pitch, R - 30, R + 2, thr=40)
        s.dp(f"`{token}` (slot {slot}, {first + slot * pitch:.2f}°)", tok(token), e and e[1] - e[0], "visible length, measured inward from the outer edge", tol=1.0)
    e = ray_extent(n, centre, first + 2 * pitch, R - 30, R + 2, thr=40)
    mid = (e[0] + e[1]) / 2
    xs = []
    for i in range(-40, 41):
        a = math.radians(first + 2 * pitch) + math.pi / 2
        x = (centre[0] + mid * math.cos(math.radians(first + 2 * pitch)) + i / 8 * math.cos(a)) * PX
        y = (centre[1] + mid * math.sin(math.radians(first + 2 * pitch)) + i / 8 * math.sin(a)) * PX
        if max(img(n).getpixel((int(x), int(y)))) > 38:
            xs.append(i / 8)
    s.dp("`dimension.onthisday.dial.tickWidth`", tok("dimension.onthisday.dial.tickWidth"), (max(xs) - min(xs)) + 1 / PX if xs else None, "across the tick at mid-length", tol=0.75)
    ticks = 0
    on = False
    for k in range(0, 3600):
        deg = k / 10
        r = R - 4
        c = img(n).getpixel((int((centre[0] + r * math.cos(math.radians(deg))) * PX), int((centre[1] + r * math.sin(math.radians(deg))) * PX)))
        lit = max(c) > 40
        if lit and not on:
            ticks += 1
        on = lit
    s.check("match" if ticks == tok("count.onthisday.dial.ticks") else "not matched", "`count.onthisday.dial.ticks` (marks on the ring)", str(tok("count.onthisday.dial.ticks")), str(ticks), "43 ticks + the indicator, counted around the ring", ev("count.onthisday.dial.ticks"))
    tick_px = ray_extent(n, centre, first + 2 * pitch, R - 10, R - 6, thr=40)
    c = img(n).getpixel((int((centre[0] + (R - 8) * math.cos(math.radians(first + 2 * pitch))) * PX), int((centre[1] + (R - 8) * math.sin(math.radians(first + 2 * pitch))) * PX)))
    s.colour("`color.onthisday.dial.tick` (#FFFFFF4D on black)", over_black(tok("color.onthisday.dial.tick")), c)
    c = img(n).getpixel((int((centre[0] + (R - 6) * math.cos(math.radians(first))) * PX), int((centre[1] + (R - 6) * math.sin(math.radians(first))) * PX)))
    s.colour("indicator `color.global.textOnMedia`", tok("color.global.textOnMedia"), c)
    g = ink(n, (play["left"], play["top"], play["right"], play["bottom"]), (0, 0, 0))
    s.dp("`dimension.onthisday.dial.glyph` (play glyph ink height)", tok("dimension.onthisday.dial.glyph"), g[3] - g[1], "glyphBox(): the icon box sized so the ink is 35 dp", tol=1.0)
    s.dp("play glyph centred in the dial (y)", cy(d), (g[1] + g[3]) / 2, "", tol=1.0)
    s.section("Behaviour, motion, haptics")
    s.check("match", "`layout.onthisday.dial` step", "one memory per 8.18° slot crossed; clockwise = older; no wrap", "OnThisDayFlowTest: 6-slot clockwise spin from the first of 4 → 3 steps, stops at the last; counter-clockwise back stops at the first", "DialGeometryTest covers angle(slot), slotOf, slotsCrossed", ev("layout.onthisday.dial"))
    s.check("match", "`haptic.global.select` per step (`TickOnStep`)", "one tick per slot crossed and per automatic step", "3 select haptics for 3 steps (OnThisDayFlowTest)", "LocalHapticsOverride records them", ev("haptic.global.select"))
    s.token("`duration.global.crossfade`", "photo + title Crossfade while dragging")
    s.token("`duration.onthisday.playHold`", "play: next memory after the hold (OnThisDayFlowTest)")
    s.token("`duration.onthisday.memoryChange`", "cross-fade while playing; share / random fade out (`duration.global.fade`)")
    s.check("match", "shuffle (dice)", "random memory of the whole history; subtitle 'Memories · {name}'", "OnThisDayViewModelTest + flow: 'Memories · …' after the dice", "history_weeks pages of 52 weeks, random week then random post")
    s.check("match", "feature intro once per account", "C-29 FeatureIntroSheet; never again", "intro-light.png; flow: shown on first open, `onthisday.nux` marked seen", "row glyph `icon.global.rewind` (the component needs one)")
    s.check("match", "menu ('•••')", "Save to Camera Roll; Report Post (others) / Delete Post (yours), red", "menu-light.png (someone else's memory); delete-confirm-light.png", "DsDropdownMenu in the system appearance (RWP phone 2)")
    s.section("States")
    states(s, "onthisday", [
        ("paused", "paused", "primary state; dark = light (media page)"),
        ("dial step", "dial-step-2", "second memory, indicator on slot 1"),
        ("playing", "playing", "pause glyph; share and random hidden (RWP phone 1)"),
        ("shuffle", "shuffle", "'Memories · {name}'"),
        ("loading", "loading", "C-28 indicator on the black page, back only"),
        ("empty", "empty", "C-27 title on black (every memory deleted while open)"),
        ("error", "error", "C-27 error + light pill"),
        ("offline", "offline", "same block"),
        ("feature intro", "intro", "C-29 sheet over the page, system appearance"),
        ("permission-denied (save)", "save-denied", "native alert, button opens Settings"),
        ("menu", "menu", "native menu, system appearance"),
        ("delete confirmation", "delete-confirm", "native confirmation"),
    ])
    s.extra = ("\nNot built (spec, unchanged): Retro's mode menu (On this week / Pick a date / Shuffle) — the dice is shuffle. "
               "The share sheet's preview title is today's date (`layout.year.story.dateFormat`) with `onthisday.share.subtitle` "
               "as the ClipData label (Android's chooser shows the title only).\n")
    s.write(renders("onthisday"))


# ---------------------------------------------------------------------------------------------------------- year.story


def story_chrome(s, j, n):
    screen = tok("collage.view.layout.screen")
    pill = tok("collage.share.layout.pill")
    f = j["frame"]
    s.dp("media page bottom: `mediaPageBottomFromScreenBottom`", screen["mediaPageBottomFromScreenBottom"], H - f["bottom"], "core:ui RecapPreviewScreen", ev("collage.view.layout.screen"))
    s.dp("media page width (side inset 0)", W, f["width"])
    s.token("`collage.view.layout.screen` corners 26.5", "RecapPreviewScreen: RoundedCornerShape(mediaPageCornerRadius), content clipped")
    c = j["close"]
    s.dp("close `size.global.circleButton`", tok("size.global.circleButton"), c["width"], "C-11 on media")
    s.dp("close centre from the trailing edge (`closeCentreFromTrailing`)", screen["closeCentreFromTrailing"], W - cx(c))
    s.dp("close centre below the page top (`closeCentreBelowPageTop`)", screen["closeCentreBelowPageTop"], cy(c) - f["top"])
    lead = j["leading"]
    s.dp("leading circle `size.global.circleButton`", tok("size.global.circleButton"), lead["width"])
    s.dp("leading circle at `size.global.buttonMarginH`", tok("size.global.buttonMarginH"), lead["left"])
    s.dp("bottom row centre `bottomRowCentreFromScreenBottom`", screen["bottomRowCentreFromScreenBottom"], H - cy(lead), "ST-04: 59.2 pt above the bottom", tol=0.75)
    if "share" in j:
        lab = j["share"]
        k = ink(n, (lab["left"] - 40, cy(lead) - 30, W, cy(lead) + 30), (0, 0, 0), thr=200)
        s.dp("Share pill height `collage.share.layout.pill.height`", pill["height"], k[3] - k[1], "C-09 recap size (core:ui RecapPillButton)", ev("collage.share.layout.pill"))
        s.dp("Share pill trailing inset `size.global.buttonMarginH`", tok("size.global.buttonMarginH"), W - k[2])
        s.dp("Share label padding `paddingHorizontal`", pill["paddingHorizontal"], lab["left"] - k[0], "label text box to the pill edge", tol=1.0)
        s.dp("Share pill centre above the bottom", pill["centreFromScreenBottom"], H - (k[1] + k[3]) / 2, tol=0.75)
        s.colour("Share pill `color.global.surfaceLight`", tok("color.global.surfaceLight"), img(n).getpixel((int((k[0] + 6) * PX), int((k[1] + k[3]) / 2 * PX))))


def year_story():
    s = Sheet("year.story", "Year in Photos (`.../yearstory/`): the cards tap through inside core:ui's recap preview "
              "(`app.ui.recap.RecapPreviewScreen` — media page, close circle, position pill, pause / play / replay, Share "
              "pill, page dots on the summary); text cards on the blurred cover, full-bleed photo cards, fitted collages; "
              "the summary pager of the recap card (`RecapCard`, white in both appearances, L-4) and the full-bleed cover; "
              "1080 × 1920 share images.",
              "ours (intro light / dark, most-reacted photo, summary card) next to ST-04 (`store/retro-store-04.png`, "
              "recap preview), TC-REC phone 2 (recap card) and phone 3 (full-bleed style) from `press/tc-2023-12-recaps.png`.")
    s.section("Recap preview chrome (core:ui `RecapPreviewScreen`, ST-04)")
    j = m("year.story-fact")
    story_chrome(s, j, "year.story-fact")
    pill = ink("year.story-fact", (0, 20, 200, 56), (0, 0, 0), thr=20)
    close = j["close"]
    s.dp("position pill `size.global.positionPillHeight`", tok("size.global.positionPillHeight"), pill[3] - pill[1], "C-22 PositionPill, `controlOnDeep`")
    s.dp("position pill leading `dimension.year.story.frame.padding`", tok("dimension.year.story.frame.padding"), pill[0])
    s.dp("position pill centred on the close circle's centre line", cy(close), (pill[1] + pill[3]) / 2)
    s.section("Text card")
    t = m("year.story-text")
    h, sl, f = t["headline"], t["subline"], t["frame"]
    pad = tok("dimension.year.story.frame.padding")
    s.dp("text block width = frame − 2 × `dimension.year.story.frame.padding`", W - 2 * pad, h["width"])
    s.dp("text block centred", W / 2, cx(h))
    s.token("headline `font.global.display`, text role `displayMedium`", "TextRoles.displayMedium, centred, LineBreak.Heading, `color.global.textOnMedia`")
    sink = first_glyph("year.story-text", sl, (0, 0, 0))
    s.dp("subline cap top `dimension.birthday.request.headlineToMessage` below the headline baseline", tok("dimension.birthday.request.headlineToMessage"), sink[1] - h["lastBaseline"], "subline 'Sunday Lunch · 2026', text role `textButton`", tol=0.75)
    fact = m("year.story-fact")["headline"]
    s.check("match", "headline wraps inside the block", "≤ 2 balanced lines", f"{fact['lines']} lines ('Sunday Lunch shared 1,284 photos this year')", "LineBreak.Heading")
    s.token("`layout.global.materials.backdrop` (cover blurred)", "core:ui BlurredBackdrop (σ `size.global.backdropBlur`, `color.global.backdropDim`, L-5) + PhotoScrimOverlay")
    s.section("Photo card")
    p = m("year.story-photo")
    date, name, fr = p["date"], p["name"], p["frame"]
    box_bottom = cy(fr) + W * 16 / 9 / 2
    s.dp("footer at `dimension.year.story.frame.padding` (date leading)", pad, date["left"])
    s.dp("'Post by Ana' right-aligned at the padding", W - pad, name["right"])
    s.dp("`dimension.year.story.footer.baseline` above the 9:16 box bottom", tok("dimension.year.story.footer.baseline"), round(box_bottom - date["lastBaseline"], 2), "the footer sits in the card's 9:16 box (what the share image renders)")
    s.dp("same baseline for the name", date["lastBaseline"], name["lastBaseline"])
    s.check("approx", "footer baseline above the frame bottom", f"{tok('dimension.year.story.footer.baseline')} (spec: frame bottom)", fmt(fr["bottom"] - date["lastBaseline"]),
            "Robolectric has no status bar, so the frame (393 × 757) is taller than 9:16 and the 9:16 box sits 29 dp above its bottom; on a phone with a status bar the frame is ≈ 9:16 (ST-04: 393 × 698) and the two coincide", "TC-REC p3: 24.8 above the frame bottom")
    s.token("date text role `displaySmall`", "TextRoles.displaySmall, `layout.year.story.dateFormat` ('Wednesday, February 25'); wraps to 2 lines beside the name (weight 1)")
    s.section("Summary — recap card (`layout.year.story.recapCard`, L-4 white)")
    rc = m("year.story-recapcard")
    spec = tok("layout.year.story.recapCard")
    card, c0, c1, c4, c23 = rc["card"], rc["cell0"], rc["cell1"], rc["cell4"], rc["cell23"]
    width = 0.825 * W
    sm = ink("year.story-summary", (0, 100, W, 740), (0, 0, 0), thr=200)
    s.dp("card width `widthRatio` × frame (82.5 %)", round(spec["widthRatio"] * W, 2), sm[2] - sm[0], "the white card on the summary page", ev("layout.year.story.recapCard"), tol=1.0)
    s.dp("card centred", W / 2, (sm[0] + sm[2]) / 2, tol=1.0)
    s.dp("padding `paddingRatio` × card width", round(spec["paddingRatio"] * card["width"], 2), c0["left"] - card["left"], "standalone RecapCard 324 dp wide (week.recap's call)")
    s.dp("cells `cellAspect` (width ÷ height)", spec["cellAspect"], round(c0["width"] / c0["height"], 3), tol=0.01)
    s.dp("cell gap `size.global.stripGap`", tok("size.global.stripGap"), c1["left"] - c0["right"])
    s.dp("row gap `size.global.stripGap`", tok("size.global.stripGap"), c4["top"] - c0["bottom"])
    s.dp("4 columns fill the padded width", card["width"] - 2 * (c0["left"] - card["left"]), round(4 * c0["width"] + 3 * (c1["left"] - c0["right"]), 2), "bounds are rounded to 0.5 dp", tol=1.0)
    s.check("match" if abs(c23["bottom"] - (c0["top"] + 6 * c0["height"] + 5 * 2)) < 1 else "not matched", "`maxRows` 6 (24 photos)", "6 full rows", f"cell 24 bottom at {fmt(c23['bottom'] - card['top'])} dp", "only full rows; short sets keep whole rows (RecapCardMetrics.shown)")
    s.dp("footer `footerHeightRatio` × card width", round(spec["footerHeightRatio"] * card["width"], 2), card["bottom"] - c23["bottom"], tol=0.75)
    s.dp("year leading at the card padding", c0["left"], rc["title"]["left"])
    s.dp("group name right-aligned at the padding", c23["right"], rc["name"]["right"])
    s.token("year `font.global.display` text role `headerTitle`, `color.global.onSurfaceLight`", "RecapFooter(TextRoles.headerTitle, onSurfaceLight) — the card stays white in dark (L-4)")
    dark = Image.open(snap("year.story/recap-card-dark.png")).convert("RGB")
    s.colour("card `color.global.surfaceLight` in the dark appearance (L-4)", tok("color.global.surfaceLight"), dark.getpixel((int((16 + 200) * PX), int((dark.height / PX - 16 - 10) * PX))), "recap-card-dark.png, footer area")
    s.token("corners `cornerRadiusRatio` × width", "RoundedCornerShape(RecapCardMetrics.corner(width)); the grid is clipped to corner − padding")
    s.row("not matched", "app line `year.story.card.app`", "under the group name (BLOCKED copy)", "left out", ev("layout.year.story.recapCard"), "BLOCKED until the owner names the app (spec)")
    s.section("Summary — pager and dots")
    sj = m("year.story-summary")
    rp = sj["leading"]
    s.dp("replay circle (`icon.year.story.replay`) at `size.global.buttonMarginH`", tok("size.global.buttonMarginH"), rp["left"], "the leading circle on the summary")
    s.dp("replay circle on the bottom row", tok("collage.view.layout.screen")["bottomRowCentreFromScreenBottom"], H - cy(rp), tol=0.75)
    s.check("match" if "share" in sj else "not matched", "Share = the style in view", "pill on the summary", "Share pill shown", "summary-card / summary-cover")
    fbot = H - tok("collage.view.layout.screen")["mediaPageBottomFromScreenBottom"]
    dots = ink("year.story-summary", (150, fbot + 4, 243, fbot + 30), (0, 0, 0), thr=40)
    s.dp("dots centre `dimension.year.story.dots.offset` below the frame", tok("dimension.year.story.dots.offset"), (dots[1] + dots[3]) / 2 - fbot, "RecapDots.BelowPage", tol=0.75)
    s.dp("dot `size.global.pageDot`", tok("size.global.pageDot"), dots[3] - dots[1], tol=0.75)
    s.dp("two dots: width = `pageDotPitch` + `pageDot`", tok("size.global.pageDotPitch") + tok("size.global.pageDot"), dots[2] - dots[0], tol=0.75)
    s.section("Share image (`layout.year.story.shareCard`)")
    shares = sorted(os.listdir(os.path.join(SNAP, "year.story", "share")))
    sizes = {Image.open(os.path.join(SNAP, "year.story", "share", x)).size for x in shares}
    s.check("match" if sizes == {(1080, 1920)} else "not matched", "1080 × 1920 PNG of the card in view", "1080 × 1920", ", ".join(f"{a} × {b}" for a, b in sizes), f"{len(shares)} images (year.story/share/): fact cards, photos, collage, outro, both summary styles", ev("layout.year.story.shareCard"))
    s.check("match", "share sheet preview title", "`year.story.entry.subtitle` ('2026 Recap')", "EXTRA_TITLE '2026 Recap' (YearStoryFlowTest)", "")
    s.section("Behaviour")
    s.check("match", "`layout.year.story.navigation`", "right half next, left half previous; auto-advance `duration.year.story.card`", "YearStoryFlowTest: taps both ways, advances on its own, pause holds", "TalkBack: custom actions next / previous; touch exploration pauses")
    s.check("match", "Share pill only on shareable cards", "fact cards, photos, collages, outro, summary", "no pill on intro (flow), pill on moments", "RecapPill(busy) while the image renders")
    s.section("States")
    states(s, "year.story", [
        ("intro (primary)", "card-01-intro", "light and dark (media: identical)"),
        ("look back", "card-02-look-back", ""), ("photos shared", "card-03-moments", "Share pill"),
        ("busiest month", "card-04-busiest-month", ""), ("most reacted setup", "card-05-most-reacted-setup", ""),
        ("most reacted photo", "card-06-most-reacted-photo-p1", "portrait; p2 = landscape"),
        ("together setup", "card-07-together-setup", ""), ("together day", "card-08-together-day", "collage fitted, never cropped"),
        ("outro", "card-09-outro", ""), ("summary card", "summary-card", "light and dark"),
        ("summary cover", "summary-cover", ""), ("summary, cover only (< 4 photos)", "summary-cover-only", "no recap card offered"),
        ("loading", "loading", "C-28 in the frame"), ("error", "error", ""), ("offline", "offline", ""),
        ("recap card (public)", "recap-card", "white in both appearances (L-4)"),
    ])
    s.write(renders("year.story"))


# ---------------------------------------------------------------------------------------------------------- birthday.add


def birthday_add():
    s = Sheet("birthday.add", "Add / manage your birthday (`.../birthday/BirthdayAdd*`): pushed header 'Birthday', the centred "
              "C-27-spaced block (serif headline, detail, privacy line, the `auth.agegate` date field), the black primary "
              "capsule and 'Maybe later' pinned to the bottom; manage: grouped row with the day and month, footer, "
              "'Remove Birthday' with a native confirmation.",
              "ours (add, light / dark; manage) next to LAND (`lazyweb/retro-lazyweb-20251119-social.png`, centred block + "
              "60-pt capsule + grey link) and H43 (`lazyweb/retro-lazyweb-20251020-week43-dark.png`, C-27 spacing).")
    j, n = m("birthday.add"), "birthday.add"
    h, de, pr, fi, co, la = j["headline"], j["detail"], j["privacy"], j["field"], j["confirm"], j["later"]
    s.section("Block (C-27 spacing)")
    s.token("header (C-02 pushed)", "core:ui PushedHeader 'Birthday', back chevron (`onthisday.a11y.back` label — copy gap)")
    s.dp("headline side margins `size.global.screenMargin`", tok("size.global.screenMargin"), h["left"])
    s.dp("headline centred", W / 2, cx(h))
    s.token("headline `font.global.display`, text role `displayMedium`", "TextRoles.displayMedium, centred, LineBreak.Heading")
    dink = first_glyph(n, de)
    s.dp("detail cap top `size.global.emptyIconToTitle` below the headline baseline", tok("size.global.emptyIconToTitle"), dink[1] - h["lastBaseline"], "capTopAt", tol=0.75)
    pink = first_glyph(n, pr)
    s.dp("privacy cap top `size.global.listGap` below the detail's last baseline", tok("size.global.listGap"), pink[1] - de["lastBaseline"], "", tol=0.75)
    s.dp("field top `size.global.emptyTitleToAction` below the privacy line", tok("size.global.emptyTitleToAction"), fi["top"] - pr["bottom"], "measured from the line box",
         approx_note=f"{fmt(fi['top'] - pr['lastBaseline'])} from its baseline")
    s.dp("field `size.global.fieldHeight`", tok("size.global.fieldHeight"), fi["height"], "C-12 (core:ui FormTextField, the auth.agegate look)")
    s.dp("field inset `size.global.screenMargin`", tok("size.global.screenMargin"), fi["left"])
    s.section("Bottom controls")
    s.dp("primary capsule `size.global.buttonHeight`", tok("size.global.buttonHeight"), co["height"], "C-05 PrimaryButton")
    s.dp("primary capsule `size.global.buttonMarginH`", tok("size.global.buttonMarginH"), co["left"])
    s.colour("primary fill `color.global.accent` (light)", tok("color.global.accent"), img(n).getpixel((int(30 * PX), int(cy(co) * PX))))
    s.dp("'Maybe later' centred", W / 2, cx(la))
    s.check("match" if la["top"] > co["bottom"] else "not matched", "'Maybe later' under the primary", "C-08 link, `listTitle`, `textSecondary`", f"{fmt(la['top'] - co['bottom'])} dp below", "core:ui TextLink")
    s.check("match", "disabled until a complete date", "C-05 disabled (`color.global.controlRaised`)", "add-empty / add-partial: disabled; add-date-entered: enabled", "")
    s.section("Manage")
    mm = m("birthday.add-manage")
    s.check("match" if mm["row"] else "not matched", "row value `layout.birthday.add.dateFormat`", "'July 5' (no year)", "'July 5'", "GroupedSection (C-14) trailing value, `body`, `textSecondary`")
    s.dp("row value at the section's trailing inset (`size.global.screenMargin` × 2)", W - 2 * tok("size.global.screenMargin"), mm["row"]["right"], "grouped inset section: margin + row padding")
    s.check("match", "footer `birthday.add.detail`", "text role `meta`, `textSecondary`", f"{mm['footer']['lines']} lines under the section", "")
    s.check("match", "'Remove Birthday' (C-10) → native confirmation", "destructive row; 'Yes, remove'", "manage-light.png, remove-confirm-light.png", "warning haptic on remove")
    s.section("States")
    states(s, "birthday.add", [
        ("not opted in (primary)", "add-empty", "light and dark"), ("partial date", "add-partial", "primary disabled"),
        ("date entered", "add-date-entered", ""), ("saving", "saving", "spinner in the capsule"), ("invalid", "invalid", "inline line"),
        ("offline", "offline", "inline line"), ("error", "error", "C-27 error block, primary → 'Try Again'"),
        ("loading", "loading", ""), ("manage", "manage", "light and dark"), ("remove confirmation", "remove-confirm", ""),
    ])
    s.write(renders("birthday.add"))


# ---------------------------------------------------------------------------------------------------------- birthday.request


def birthday_request():
    s = Sheet("birthday.request", "The private request (`.../birthday/BirthdayRequestScreen.kt`): the honoree's photo blurred "
              "behind everything (media, dark in both), glass close, a bottom-anchored block — avatar, serif headline, "
              "invitation — then the PAY-style plan card (Message ideas, two numbered prompts, 'Add your photo') or your "
              "contribution (thumbnail + line, 'Change photo' / 'Remove'), and the due line.",
              "ours (open light / dark, contributed) next to PAY (`lazyweb/retro-lazyweb-20260529-paywall.png`).")
    j, n = m("birthday.request"), "birthday.request"
    s.section("Close and who")
    c = j["close"]
    s.dp("close `size.global.circleButtonSmall`", tok("size.global.circleButtonSmall"), c["width"], "C-11 GlassSmall")
    s.dp("close right edge `dimension.birthday.request.close.inset`", tok("dimension.birthday.request.close.inset"), W - c["right"])
    s.dp("close centre `dimension.birthday.request.close.centerY`", tok("dimension.birthday.request.close.centerY"), cy(c))
    a, h, b = j["avatar"], j["headline"], j["body"]
    s.dp("avatar `size.global.avatarProfile`", tok("size.global.avatarProfile"), a["width"])
    s.dp("avatar centred", W / 2, cx(a))
    hink = first_glyph(n, h, (0, 0, 0))
    s.dp("headline cap top `size.global.emptyIconToTitle` below the avatar", tok("size.global.emptyIconToTitle"), hink[1] - a["bottom"], "", tol=0.75)
    s.dp("headline side margins `size.global.buttonMarginH`", tok("size.global.buttonMarginH"), h["left"])
    s.token("headline `font.global.display`, `displayMedium`, `textOnMedia`", "TextRoles.displayMedium, LineBreak.Heading")
    bink = first_glyph(n, b, (0, 0, 0))
    s.dp("invitation cap top `dimension.birthday.request.headlineToMessage` below the headline baseline", tok("dimension.birthday.request.headlineToMessage"), bink[1] - h["lastBaseline"], "text role `textButton`", tol=0.75)
    s.section("Plan card (C-34, PAY)")
    card = j["card"]
    s.dp("card top `dimension.birthday.request.messageToCard` below the invitation", tok("dimension.birthday.request.messageToCard"), card["top"] - b["bottom"], "from the line box",
         approx_note=f"{fmt(card['top'] - b['lastBaseline'])} from the last baseline")
    s.dp("card width = screen − 2 × `size.global.buttonMarginH`", W - 2 * tok("size.global.buttonMarginH"), card["width"])
    s.token("card `radius.global.cardLarge`, `color.global.surfaceElevated`", "core:ui PlanCard")
    ct, cd = j["cardTitle"], j["cardDetail"]
    s.dp("content inset `size.global.planCardPadding`", tok("size.global.planCardPadding"), ct["left"] - card["left"])
    s.token("title `fontSize.birthday.request.cardTitle` / `fontWeight.birthday.request.cardTitle`", "dsTextStyle(24, bold, `font.global.family`)")
    dink = first_glyph(n, cd)
    s.dp("detail cap top `dimension.birthday.request.card.titleToDetail` below the title baseline", tok("dimension.birthday.request.card.titleToDetail"), dink[1] - ct["lastBaseline"], "", tol=0.75)
    p1, p2, m1, m2 = j["prompt1"], j["prompt2"], j["marker1"], j["marker2"]
    mk = ink(n, (card["left"] + 20, p1["top"] - 4, p1["left"], p1["top"] + 26))
    s.dp("marker `dimension.birthday.request.card.marker`", tok("dimension.birthday.request.card.marker"), mk[2] - mk[0], "accent circle, number in `badge`", tol=0.75)
    s.dp("marker → text `dimension.birthday.request.card.markerGap`", tok("dimension.birthday.request.card.markerGap"), p1["left"] - mk[2], "", tol=0.75)
    p1ink = first_glyph(n, p1)
    s.dp("first prompt cap top `dimension.birthday.request.card.blockGap` below the detail", tok("dimension.birthday.request.card.blockGap"), p1ink[1] - cd["bottom"], "from the detail's line box",
         approx_note=f"{fmt(p1ink[1] - cd['lastBaseline'])} from its last baseline")
    s.dp("marker centred on the first line", (p1["top"] + p1["firstBaseline"] + 4.5) / 2, (mk[1] + mk[3]) / 2, "", tol=1.5)
    line = p2["height"]
    s.dp("prompt rows `dimension.birthday.request.card.rowPitch` apart (+ the wrapped line)", tok("dimension.birthday.request.card.rowPitch") + (p1["lines"] - 1) * line, round(cy(m2) - cy(m1), 2),
         f"prompt 1 wraps to {p1['lines']} lines in Roboto at 17 sp (one line in PAY); one-line rows are exactly 32", tol=1.0)
    cta = ink(n, (card["left"] + 12, j["cta"]["top"] - 25, card["right"] - 12, card["bottom"] - 10), None, thr=60)
    s.dp("'Add your photo' `size.global.buttonHeight`", tok("size.global.buttonHeight"), cta[3] - cta[1], "C-05 accent capsule in the card", tol=1.0)
    s.dp("capsule 16 from the card sides (C-34)", 16, cta[0] - card["left"], tol=1.0)
    s.dp("capsule 16 from the card bottom (C-34)", 16, card["bottom"] - cta[3], tol=1.0)
    du = j["due"]
    uink = first_glyph(n, du, (0, 0, 0))
    s.dp("due line cap top `dimension.birthday.request.cardToFooter` below the card", tok("dimension.birthday.request.cardToFooter"), uink[1] - card["bottom"], "text role `caption`, centred", tol=0.75)
    s.check("approx", "due line → safe-area bottom", "PAY: the line, then the safe-area bottom", f"{fmt(H - du['bottom'])} dp below the line box",
            "Robolectric has no navigation bar; on a device the bottom inset follows (windowInsetsPadding(navigationBars))", "PAY")
    s.section("After contributing")
    k = m("birthday.request-contributed")
    th, ln, ch, rm = k["thumb"], k["line"], k["change"], k["remove"]
    s.dp("thumbnail `size.global.rowThumbWidth`", tok("size.global.rowThumbWidth"), th["width"])
    s.dp("thumbnail `size.global.rowThumbHeight`", tok("size.global.rowThumbHeight"), th["height"])
    s.dp("line beside it `size.global.rowThumbGap`", tok("size.global.rowThumbGap"), ln["left"] - th["right"])
    s.dp("'Change photo' → 'Remove' `size.global.pillGap`", tok("size.global.pillGap"), rm["left"] - ch["right"], "CapsuleRowSpacing", tol=0.75)
    s.check("match", "Remove → native confirmation → 'Removed' toast", "C-29, `birthday.request.removed`", "remove-confirm-light.png; ContributeFlowTest", "warning haptic")
    s.section("States")
    states(s, "birthday.request", [
        ("open (primary)", "open", "light and dark (media: identical)"), ("open, no honoree photo", "open-no-honoree-photo", "`backgroundDeep`, avatar fallback"),
        ("contributed", "contributed", "your block"), ("closed", "closed", "C-27 in the card"), ("loading", "loading", ""),
        ("offline", "offline", ""), ("error", "error", ""), ("not found", "not-found", "also for the honoree (RLS)"),
        ("remove confirmation", "remove-confirm", ""),
    ])
    s.write(renders("birthday.request"))


# ---------------------------------------------------------------------------------------------------------- birthday.contribute


def birthday_contribute():
    s = Sheet("birthday.contribute", "The contribution sheet (`.../birthday/BirthdayContributeScreen.kt`, "
              "`BirthdayRequestDestination.kt`): step 1 'Choose a Photo' (sheet toolbar, grey line, 4-column grid with the "
              "selection check), step 2 the dark composer (photo fitted in its box, 'Add a message' pill, your line, 'Add "
              "to video'), step 2a the 'Add a Message' modal with the 0/110 counter.",
              "ours (picker light / dark, composer, message) next to VID-COMP (`video/ig-DDbA_F7x-j7-composer-f130-147-f188-197.png`), "
              "ST-03 (`store/retro-store-03.png`) and TC-R3 phone 3 (`press/tc-2023-12-retro3.png`).")
    s.section("Step 1 — Choose a Photo (VID-COMP)")
    j, n = m("birthday.contribute-picker"), "birthday.contribute-picker"
    s.dp("'Cancel' at `size.global.screenMargin`", tok("size.global.screenMargin"), j["cancel"]["left"], "core:ui SheetHeader / SheetTextAction")
    s.dp("title centred", W / 2, cx(j["title"]))
    s.dp("'Next' at `size.global.screenMargin` from the trailing edge", tok("size.global.screenMargin"), W - j["next"]["right"])
    s.dp("grey line leading `size.global.screenMargin`", tok("size.global.screenMargin"), j["subtitle"]["left"], "text role `body`, `textSecondary.android`")
    c0, c1, c4, g = j["cell0"], j["cell1"], j["cell4"], j["grid"]
    s.dp("grid full width", W, g["width"])
    s.dp("cells square", c0["width"], c0["height"])
    s.dp("gap `size.global.stripGap`", tok("size.global.stripGap"), c1["left"] - c0["right"])
    s.dp("row gap `size.global.stripGap`", tok("size.global.stripGap"), c4["top"] - c0["bottom"])
    s.dp("4 columns", W, round(4 * c0["width"] + 3 * (c1["left"] - c0["right"]), 2), "bounds are rounded to 0.5 dp", tol=1.0)
    sel = tok("color.global.selection")
    im = img(n)
    pts = [(x / PX, y / PX) for y in range(int(c1["top"] * PX), int(c1["bottom"] * PX)) for x in range(int(c1["left"] * PX), int(c1["right"] * PX))
           if max(abs(a - b) for a, b in zip(im.getpixel((x, y)), (0, 0x88, 0xFF))) < 40]
    if pts:
        l, t, r, b = min(p[0] for p in pts), min(p[1] for p in pts), max(p[0] for p in pts) + 0.5, max(p[1] for p in pts) + 0.5
        s.dp("check `size.global.checkCircle`", tok("size.global.checkCircle"), r - l, "`icon.global.check` in `color.global.selection`", tol=1.0)
        s.dp("check inset `size.global.badgeInset` (top)", tok("size.global.badgeInset"), t - c1["top"], tol=1.0)
        s.dp("check inset `size.global.badgeInset` (right)", tok("size.global.badgeInset"), c1["right"] - r, tol=1.0)
        s.colour("check `color.global.selection` (light)", sel["light"] if isinstance(sel, dict) else sel, im.getpixel((int((l + r) / 2 * PX), int((t + 4) * PX))), tol=40)
    s.section("Step 2 — composer (ST-03, dark in both)")
    j, n = m("birthday.contribute-composer"), "birthday.contribute-composer"
    t, p, pl, ln, sb, cl = j["title"], j["photo"], j["pill"], j["line"], j["submit"], j["close"]
    s.dp("title centred", W / 2, cx(t), "text role `sheetTitle`, `textOnMedia`")
    s.dp("close `size.global.circleButton`", tok("size.global.circleButton"), cl["width"], "C-11 on media")
    s.dp("photo top `dimension.birthday.contribute.titleToPhoto` below the title baseline", tok("dimension.birthday.contribute.titleToPhoto"), p["top"] - t["lastBaseline"], "header ends at the title's baseline")
    s.dp("photo box width `dimension.birthday.contribute.photoWidth`", tok("dimension.birthday.contribute.photoWidth"), p["width"], "3:4 photo fitted (own aspect)")
    s.check("match" if p["height"] <= tok("dimension.birthday.contribute.photoMaxHeight") + 0.5 else "not matched", "photo within `dimension.birthday.contribute.photoMaxHeight`", f"≤ {tok('dimension.birthday.contribute.photoMaxHeight')}", fmt(p["height"]), "297.4 ÷ 0.75 = 396.5", ev("dimension.birthday.contribute.photoMaxHeight"))
    s.dp("photo centred", W / 2, cx(p))
    s.token("`radius.birthday.contribute.photo`", "RoundedCornerShape(8.5) clip")
    s.dp("pill `size.global.pillHeight`", tok("size.global.pillHeight"), pl["height"], "core:ui MediaPill (dark) + `icon.global.edit`")
    s.dp("pill bottom `dimension.birthday.contribute.pillBottom` above the photo bottom", tok("dimension.birthday.contribute.pillBottom"), p["bottom"] - pl["bottom"])
    s.dp("pill centred on the photo", cx(p), cx(pl))
    s.dp("line `size.global.listGap` below the photo", tok("size.global.listGap"), ln["top"] - p["bottom"], "to the line box; text role `body`")
    s.dp("line side margins `size.global.buttonMarginH`", tok("size.global.buttonMarginH"), ln["left"])
    s.dp("'Add to video' `size.global.buttonHeight`", tok("size.global.buttonHeight"), sb["height"], "C-05 on media (white)")
    s.dp("'Add to video' `size.global.buttonMarginH`", tok("size.global.buttonMarginH"), sb["left"])
    s.section("Step 2a — 'Add a Message' (TC-R3 phone 3)")
    j, n = m("birthday.contribute-message"), "birthday.contribute-message"
    s.dp("title centred", W / 2, cx(j["title"]), "text role `sheetTitle`")
    s.dp("'Done' `dimension.birthday.contribute.counterInset` from the edge", tok("dimension.birthday.contribute.counterInset"), W - j["done"]["right"], "app-drawn C-08, `textButton`", tol=0.75)
    s.dp("text inset `dimension.birthday.contribute.messageInset` (leading)", tok("dimension.birthday.contribute.messageInset"), j["field"]["left"], "", tol=0.75)
    s.dp("text inset `dimension.birthday.contribute.messageInset` (trailing)", tok("dimension.birthday.contribute.messageInset"), W - j["field"]["right"], "", tol=0.75)
    ci = ink(n, (W / 2, H - 60, W, H), None, thr=40)
    zero = ink(n, (ci[2] - 6, ci[1], ci[2], ci[3] + 1), None, thr=40)
    s.dp("counter ink `dimension.birthday.contribute.counterInset` from the edge", tok("dimension.birthday.contribute.counterInset"), W - ci[2], "'28/110', tabular digits", tol=1.0)
    s.dp("counter baseline `dimension.birthday.contribute.counterAboveKeyboard` above the keyboard", tok("dimension.birthday.contribute.counterAboveKeyboard"), H - zero[3], "the last '0' sits on the baseline; no keyboard in Robolectric: above the screen bottom (imePadding on a device)", tol=1.0)
    s.check("match", "input stops at `layout.birthday.contribute.lineMax`", "110 characters", "BirthdayRequestViewModelTest (setLine caps)", "")
    s.section("Behaviour")
    s.check("match", "only eligible photos", "yours + tagged, newest first, deduplicated", "ContributeFlowTest: p-tagged and p-mine1 shown, p-other not", "")
    s.check("match", "submit → toast, own block on the request", "`birthday.contribute.done.title`", "ContributeFlowTest: 'Added to video!', line trimmed", "send haptic")
    s.section("States")
    states(s, "birthday.contribute", [
        ("picker (primary)", "photo-selected", "light and dark"), ("picker, nothing chosen", "photo-grid", "'Next' disabled"),
        ("picker loading", "photo-loading", "placeholders"), ("no eligible photos", "photo-empty", "C-27 + 'View {group}'"),
        ("picker offline", "photo-offline", ""), ("picker error", "photo-error", ""), ("not eligible", "photo-not-eligible", "inline line"),
        ("composer, no line", "composer-empty", "light and dark (media)"), ("composer with line", "composer-line", ""),
        ("composer, landscape photo", "composer-landscape", ""), ("sending", "sending", ""), ("composer error", "composer-error", ""),
        ("composer offline", "composer-offline", ""), ("closed", "closed", ""), ("message modal", "message", "light and dark"),
        ("message, empty", "message-empty", "placeholder"), ("sheet over the request", "sheet", "C-29 page sheet"),
    ])
    s.write(renders("birthday.contribute"))


# ---------------------------------------------------------------------------------------------------------- birthday.tribute


def birthday_tribute():
    s = Sheet("birthday.tribute", "The finished video (`.../birthday/TributeScreen.kt`): dark media page, serif title + group "
              "line, close circle, the 16:9 player centred between header and bar, the recap-preview bottom row (save circle "
              "+ white Share pill).",
              "ours (ready light / dark, honoree) next to RWA (title at the margin), ST-04 (bottom row) and TC-2B phone 2 "
              "(`press/tc-2023-07-retro-2b.jpg`, media at full width on black).")
    j, n = m("birthday.tribute"), "birthday.tribute"
    t, g, c, pl, sv = j["title"], j["group"], j["close"], j["player"], j["save"]
    s.section("Header")
    s.dp("title baseline `size.global.titleTop`", tok("size.global.titleTop"), t["firstBaseline"])
    s.dp("title leading `size.global.screenMargin`", tok("size.global.screenMargin"), t["left"])
    s.check("match" if t["lines"] <= 2 else "not matched", "title up to two lines", "≤ 2", str(t["lines"]), "'Ana's birthday video', `headerTitle`, LineBreak.Heading")
    s.dp("group baseline `dimension.onthisday.subtitleBaseline` below the title's", tok("dimension.onthisday.subtitleBaseline"), g["firstBaseline"] - t["lastBaseline"])
    s.colour("group `color.global.textSecondary`", tok("color.global.textSecondary"), brightest(n, (g["left"], g["top"], g["right"], g["bottom"])))
    s.dp("close `size.global.circleButton`", tok("size.global.circleButton"), c["width"])
    s.dp("close at `size.global.headerInset`", tok("size.global.headerInset"), W - c["right"])
    tink = first_glyph(n, t, (0, 0, 0))
    s.dp("close centred on the first line's cap middle", (tink[1] + t["firstBaseline"]) / 2, cy(c), "", tol=0.75)
    s.section("Player (`layout.birthday.tribute.player`)")
    s.dp("full screen width", W, pl["width"])
    s.dp("16:9", round(W * 9 / 16, 2), pl["height"])
    bar_top = H - tok("collage.view.layout.screen")["bottomRowCentreFromScreenBottom"] - tok("collage.share.layout.pill")["height"] / 2
    s.dp("centred between the header and the bar", round((g["bottom"] + bar_top) / 2, 2), cy(pl), "header bottom → Share pill top")
    s.token("native controls, poster = title card", "Media3 PlayerView (TributePlayer), no autoplay under Reduce Motion")
    s.section("Bottom row (recap preview, ST-04)")
    s.dp("save circle `size.global.circleButton`", tok("size.global.circleButton"), sv["width"], "`icon.global.download`, C-11 on media")
    s.dp("save circle at `size.global.buttonMarginH`", tok("size.global.buttonMarginH"), sv["left"])
    s.dp("row centre `bottomRowCentreFromScreenBottom`", tok("collage.view.layout.screen")["bottomRowCentreFromScreenBottom"], H - cy(sv), tol=0.75)
    lab = j["share"]
    k = ink(n, (lab["left"] - 40, cy(sv) - 30, W, cy(sv) + 30), (0, 0, 0), thr=200)
    s.dp("Share pill height", tok("collage.share.layout.pill")["height"], k[3] - k[1], "core:ui RecapPillButton")
    s.dp("Share pill at `size.global.buttonMarginH`", tok("size.global.buttonMarginH"), W - k[2])
    s.section("Behaviour")
    s.check("match", "save → add-only MediaStore.Video; denied → alert", "`birthday.tribute.saveDenied.*` (Settings)", "TributeAndAddViewModelTest; save-denied-light.png", "error haptic")
    s.section("States")
    states(s, "birthday.tribute", [
        ("ready (primary)", "ready", "member view; light and dark (media)"), ("honoree", "honoree", "'Your birthday video'"),
        ("loading", "loading", "C-28 in the player box"), ("re-rendering", "rendering", "as loading"), ("saving", "saving", ""),
        ("not found", "not-found", ""), ("error", "error", ""), ("offline", "offline", ""), ("save denied", "save-denied", "native alert"),
    ])
    s.write(renders("birthday.tribute"))


# ---------------------------------------------------------------------------------------------------------- tagging


def tagging():
    s = Sheet("tagging", "The tag run (`.../tagging/TagRun.kt`, public `TagRun(postId, …)` hosted by photo.viewer's footer): "
              "\"I'm in this\" (tags you at once) or \"with {names}\" (opens the sheet), and the 'In this photo' sheet with "
              "people rows, 'Remove tag' on your row and \"I'm in this\" when you are not tagged.",
              "ours (footer light / dark, sheet light / dark) next to TC-2B phone 2 (`press/tc-2023-07-retro-2b.jpg`, viewer "
              "footer) and TC-1B phone 2 (`press/tc-2023-07-retro-1b.webp`, people rows).")
    s.section("Footer run")
    r = m("tagging-run")["run"]
    s.token("run text role `listSubtitle`", "TextRoles.listSubtitle; toggle in `textOnMedia`, 'with …' in `textSecondary` with semibold names")
    s.check("not matched", "hit area ≥ `size.global.minTouchTarget.android`", "48 × 48", f"{fmt(r['width'])} × {fmt(r['height'])} (the line)",
            "the run is one button the size of its text: growing it to 48 would grow the viewer's footer line; needs a touch-bounds expansion in core:ui or a 48-dp footer row in photo.viewer (reported)", ev("size.global.minTouchTarget.android"))
    s.check("match", "one line, tail-truncated, never a count", "ListFormatter names", "footer-with-truncated-light.png", "android.icu ListFormatter")
    s.check("match", "\"I'm in this\" tags at once; run opens the sheet", "optimistic + `tag_self`", "TaggingSnapshotTest flow; TagRunControllerTest (revert on failure, ≤ 1 call)", "select haptic; error toast + revert")
    s.section("'In this photo' sheet (C-29 medium detent)")
    j = m("tagging-sheet")
    s.dp("title centred", W / 2, cx(j["title"]), "core:ui SheetHeader, `sheetTitle`")
    s.dp("close `size.global.circleButton`", tok("size.global.circleButton"), j["close"]["width"], "C-11 on the page (`color.global.control`)")
    s.dp("close at `size.global.screenMargin`", tok("size.global.screenMargin"), W - j["close"]["right"])
    s.token("people rows (C-16) `size.global.avatarPicker`, name `listTitle`", "core:ui PeopleRow at `size.global.screenMargin`")
    s.check("match", "'Remove tag' on your row only", "C-06 outline capsule", "sheet-tagged: on 'Jesus', not on 'Ana'", "")
    u = m("tagging-sheet-untagged")
    tg = u["toggle"]
    k = ink("tagging-sheet-untagged", (0, tg["top"] - 25, W, tg["bottom"] + 25), None, thr=60)
    s.dp("\"I'm in this\" `size.global.buttonHeight`", tok("size.global.buttonHeight"), k[3] - k[1], "C-05 primary capsule", tol=1.0)
    s.dp("\"I'm in this\" `size.global.buttonMarginH`", tok("size.global.buttonMarginH"), k[0], tol=1.0)
    s.section("States")
    states(s, "tagging", [
        ("untagged (primary)", "footer-untagged", "light and dark"), ("tagged, others", "footer-with", ""),
        ("tagged, you", "footer-with-you", "yours included"), ("many", "footer-with-truncated", "tail-truncated"),
        ("sheet, tagged", "sheet-tagged", "light and dark (follows the appearance)"), ("sheet, not tagged", "sheet-not-tagged", ""),
        ("sheet, empty", "sheet-empty", "'No one is tagged'"),
    ])
    s.write(renders("tagging"))


# ---------------------------------------------------------------------------------------------------------- side by sides

# (surface, ours [snapshot paths], references [(retro path, crop x,y,w,h or None)])
PAIRS = [
    ("onthisday", ["onthisday/paused-light.png", "onthisday/paused-dark.png", "onthisday/playing-light.png", "onthisday/intro-light.png"],
     [("press/tc-2025-12-rewind-device-b.jpg", None), ("press/tc-2025-12-rewind-device-a.png", None)]),
    ("year.story", ["year.story/card-01-intro-light.png", "year.story/card-01-intro-dark.png", "year.story/card-06-most-reacted-photo-p1-light.png", "year.story/summary-card-light.png"],
     [("store/retro-store-04.png", None), ("press/tc-2023-12-recaps.png", "1030,200,710,1445"), ("press/tc-2023-12-recaps.png", "1900,200,700,1445")]),
    ("birthday.add", ["birthday.add/add-empty-light.png", "birthday.add/add-empty-dark.png", "birthday.add/manage-light.png"],
     [("lazyweb/retro-lazyweb-20251119-social.png", None), ("lazyweb/retro-lazyweb-20251020-week43-dark.png", None)]),
    ("birthday.request", ["birthday.request/open-light.png", "birthday.request/open-dark.png", "birthday.request/contributed-light.png"],
     [("lazyweb/retro-lazyweb-20260529-paywall.png", None)]),
    ("birthday.contribute", ["birthday.contribute/photo-selected-light.png", "birthday.contribute/photo-selected-dark.png", "birthday.contribute/composer-line-light.png", "birthday.contribute/message-light.png"],
     [("video/ig-DDbA_F7x-j7-composer-f130-147-f188-197.png", "0,0,900,1116"), ("store/retro-store-03.png", None), ("press/tc-2023-12-retro3.png", "1900,200,700,1445")]),
    ("birthday.tribute", ["birthday.tribute/ready-light.png", "birthday.tribute/ready-dark.png", "birthday.tribute/honoree-light.png"],
     [("press/tc-2025-12-rewind-device-a.png", None), ("store/retro-store-04.png", None), ("press/tc-2023-07-retro-2b.jpg", "1290,100,920,1940")]),
    ("tagging", ["tagging/footer-with-light.png", "tagging/footer-untagged-dark.png", "tagging/sheet-tagged-light.png", "tagging/sheet-tagged-dark.png"],
     [("press/tc-2023-07-retro-2b.jpg", "1290,100,920,1940"), ("press/tc-2023-07-retro-1b.webp", "1290,100,920,1940")]),
]


def side_by_sides(tmp):
    os.makedirs(tmp, exist_ok=True)
    for surface, ours, refs in PAIRS:
        ref_paths = []
        for i, (ref, crop) in enumerate(refs):
            im = Image.open(os.path.join(REF, ref)).convert("RGB")
            if crop:
                x, y, w, h = (int(v) for v in crop.split(","))
                im = im.crop((x, y, x + w, y + h))
            p = os.path.join(tmp, f"{surface}-ref{i}-" + os.path.basename(ref).rsplit(".", 1)[0] + ".png")
            im.save(p)
            ref_paths.append(p)
        cmd = [sys.executable, "-I", os.path.join(ROOT, "tools", "sidebyside.py"), os.path.join(OUT, f"{surface}.android.png"),
               "--ours", *[snap(o) for o in ours], "--ref", *ref_paths, "--title", f"{surface} (Android) — ours | Retro reference", "--height", "1200"]
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)
        print(os.path.join(OUT, f"{surface}.android.png"))


if __name__ == "__main__":
    onthisday()
    year_story()
    birthday_add()
    birthday_request()
    birthday_contribute()
    birthday_tribute()
    tagging()
    if "--no-images" not in sys.argv:
        side_by_sides(os.path.join(os.environ.get("TMPDIR", "/tmp"), "memory-sbs"))
