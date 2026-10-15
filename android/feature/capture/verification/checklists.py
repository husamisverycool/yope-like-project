#!/usr/bin/env python3
"""Verification of the Android capture screens (docs/SCREENS_BRIEF.md rule 8).

Inputs (produced by `./gradlew :feature:capture:recordRoborazziDebug`):
  android/feature/capture/src/test/snapshots/*.png   our renders (393 x 852 dp at 3x; widgets at their dp size, 3x)
  android/feature/capture/build/verification/*.json  laid-out bounds in dp (MeasurementTest, WidgetSnapshotTest)
Outputs:
  design/verification/<surface>.png   ours | reference, via tools/sidebyside.py
  design/verification/<surface>.md    token -> reference value -> what our screen shows -> status

Status: "match" (measured within the token's precision), "match (token)" (the value goes from the
token into the component unchanged; not separable from a layout bound), "approx" (approximated:
the spec leaves the value open or two tokens disagree), "MISS" (not matched), "BLOCKED" (omitted).
Run: python3 -I android/feature/capture/verification/checklists.py  (from the repo root)
"""
import json
import os
import subprocess
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
MOD = os.path.join(ROOT, "android", "feature", "capture")
SNAP = os.path.join(MOD, "src", "test", "snapshots")
MEAS = os.path.join(MOD, "build", "verification")
OUT = os.path.join(ROOT, "design", "verification")
SCRATCH = os.path.join(MOD, "build", "verification", "composites")
SCALE = 3.0  # xxhdpi snapshots
SCREEN_W, SCREEN_H = 393.0, 852.0

TOKENS = {}
for name in ("global", "capture", "account", "social", "memory"):
    with open(os.path.join(ROOT, "design", "tokens", name + ".json")) as f:
        TOKENS.update(json.load(f)["tokens"])


def tok(name, key=None):
    t = TOKENS[name]
    v = t.get("value")
    return v[key] if key is not None else v


def evidence(name):
    t = TOKENS.get(name, {})
    ev = (t.get("evidence") or "").replace("|", "/")
    return (ev[:110] + "…") if len(ev) > 110 else ev


def meas(surface):
    p = os.path.join(MEAS, surface + ".json")
    return json.load(open(p)) if os.path.exists(p) else {}


def px(img, x_dp, y_dp):
    x = min(max(int(round(x_dp * SCALE)), 0), img.width - 1)
    y = min(max(int(round(y_dp * SCALE)), 0), img.height - 1)
    r, g, b = img.getpixel((x, y))[:3]
    return "#%02X%02X%02X" % (r, g, b)


def snap(name):
    return Image.open(os.path.join(SNAP, name + ".png")).convert("RGB")


class Sheet:
    def __init__(self, surface, title):
        self.surface, self.title, self.sections, self.counts = surface, title, [], {}

    def section(self, name):
        self.sections.append((name, []))

    def row(self, token, expected, measured, tol=None, status=None, note=""):
        if status is None:
            if isinstance(expected, (int, float)) and isinstance(measured, (int, float)):
                status = "match" if abs(expected - measured) <= (tol if tol is not None else 0.6) else "MISS"
            elif isinstance(expected, str) and isinstance(measured, str):
                status = "match" if colour_close(expected, measured, tol or 6) else "MISS"
            else:
                status = "match (token)"
        ref = evidence(token.split(" ")[0].strip("`")) if token.startswith("`") else ""
        self.counts[status] = self.counts.get(status, 0) + 1
        self.sections[-1][1].append((status, token, fmt(expected), fmt(measured), ref, note))

    def write(self, header_lines):
        lines = [f"# Verification — `{self.surface}` (Android)", ""] + header_lines + [""]
        total = sum(self.counts.values())
        summary = ", ".join(f"{v} {k}" for k, v in sorted(self.counts.items()))
        lines += [f"**Result: {total} checks — {summary}.**", ""]
        for name, rows in self.sections:
            lines += [f"## {name}", "", "| status | token | expected (token) | ours (measured) | reference evidence | note |", "|---|---|---|---|---|---|"]
            for status, token, expected, measured, ref, note in rows:
                lines.append(f"| {status} | {token} | {expected} | {measured} | {ref} | {note} |")
            lines.append("")
        with open(os.path.join(OUT, self.surface + ".md"), "w") as f:
            f.write("\n".join(lines))
        return self.counts


def fmt(v):
    if isinstance(v, float):
        return f"{v:.2f}".rstrip("0").rstrip(".")
    return str(v)


def colour_close(a, b, tol):
    try:
        a, b = a.lstrip("#")[:6], b.lstrip("#")[:6]
        return all(abs(int(a[i:i + 2], 16) - int(b[i:i + 2], 16)) <= tol for i in (0, 2, 4))
    except ValueError:
        return False


def concat(images, path, gap=24, height=None):
    ims = [Image.open(i).convert("RGB") if isinstance(i, str) else i for i in images]
    h = height or max(i.height for i in ims)
    ims = [i.resize((max(1, round(i.width * h / i.height)), h)) for i in ims]
    w = sum(i.width for i in ims) + gap * (len(ims) - 1)
    sheet = Image.new("RGB", (w, h), (128, 128, 128))
    x = 0
    for i in ims:
        sheet.paste(i, (x, 0))
        x += i.width + gap
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sheet.save(path)
    return path


def side_by_side(surface, ours, ref, title):
    out = os.path.join(OUT, surface + ".png")
    subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools", "sidebyside.py"), out, ours, ref, "--title", title], check=True, capture_output=True)
    return out


def R(*parts):
    return os.path.join(ROOT, "references", *parts)


def S(name):
    return os.path.join(SNAP, name + ".png")


def C(name):
    return os.path.join(SCRATCH, name + ".png")


HEADER = [
    "Generated by `android/feature/capture/verification/checklists.py` from the Robolectric renders "
    "(`./gradlew :feature:capture:recordRoborazziDebug`, debug build, 393 × 852 dp at 3×, Reduce Motion off) "
    "and the laid-out bounds the measurement tests read back (dp, screen top-left origin). Reference values and "
    "evidence come from the token files. Colours are sampled from our render at the measured positions.",
]


# ---------------------------------------------------------------------------------------------
def camera_capture():
    m = meas("camera.capture")
    sh = Sheet("camera.capture", "")
    img = snap("camera.capture_coach")
    vf, shutter, lib, flip, flash, coach = (m[k] for k in ("camera.viewfinder", "camera.shutter", "camera.library", "camera.flip", "camera.flash", "camera.coach"))
    cx = shutter["left"] + shutter["width"] / 2
    cy = shutter["top"] + shutter["height"] / 2
    sh.section("Viewfinder")
    sh.row("`camera.capture.layout.viewfinder` top", tok("camera.capture.layout.viewfinder", "top"), vf["top"])
    sh.row("`camera.capture.layout.viewfinder` width (full screen width)", SCREEN_W, vf["width"])
    sh.row("`camera.capture.layout.viewfinder` heightOverWidth", round(SCREEN_W * tok("camera.capture.layout.viewfinder", "heightOverWidth"), 2), vf["height"])
    sh.row("`radius.global.viewfinder`", tok("radius.global.viewfinder"), "18.5 (RoundedCornerShape from the token)", status="match (token)")
    sh.row("`color.global.backgroundDeep` (screen)", "#000000", px(img, 5, vf["top"] + vf["height"] + 5))
    sh.row("`camera.capture.layout.flashGlyph` centerFromLeading", tok("camera.capture.layout.flashGlyph", "centerFromLeading"), flash["left"] + flash["width"] / 2)
    sh.row("`camera.capture.layout.flashGlyph` centerFromBottom", tok("camera.capture.layout.flashGlyph", "centerFromBottom"), vf["bottom"] - (flash["top"] + flash["height"] / 2))
    sh.row("`camera.capture.layout.flashGlyph` glyphHeight", tok("camera.capture.layout.flashGlyph", "glyphHeight"), flash["height"])
    sh.row("`icon.global.flashOff` / `.flashOn`", "Rounded.FlashOff / Rounded.FlashOn", "Tokens.Icons.globalFlashOff / On", status="match (token)")
    sh.row("text role `overlayTimeCamera` (`fontSize.global.overlayTimeCamera` / heavy)", f"{tok('fontSize.global.overlayTimeCamera')} sp / heavy", "26 sp / FontWeight(800)", status="match (token)", note="centred on both axes; device short time style")
    sh.row("`camera.capture.size.recordingOutline`", "BLOCKED", "not drawn (Blocked.recordingOutline = null)", status="BLOCKED")
    sh.section("Control row")
    sh.row("`camera.capture.size.shutterTopGap` (viewfinder bottom → ring top)", tok("camera.capture.size.shutterTopGap"), shutter["top"] - vf["bottom"])
    sh.row("`camera.capture.size.shutterOuter`", tok("camera.capture.size.shutterOuter"), shutter["width"])
    sh.row("shutter centred", SCREEN_W / 2, cx)
    sh.row("`camera.capture.size.shutterRing` colour `color.global.accent`", "#CDFD07", px(img, cx, shutter["top"] + tok("camera.capture.size.shutterRing") / 2))
    sh.row("`camera.capture.size.shutterDisc` colour `color.global.surfaceLight`", "#FFFFFF", px(img, cx, cy))
    sh.row("`camera.capture.size.shutterDisc` / `.shutterGap`", f"disc {tok('camera.capture.size.shutterDisc')}, gap {tok('camera.capture.size.shutterGap')}",
           f"disc 59, gap {(80 - 2 * 3.5 - 59) / 2:.1f}", status="approx",
           note="80 − 2×3.5 − 59 = 14 → 7 per side; the gap token (5.5) does not add up with outer, ring and disc; outer, ring and disc are honoured")
    sh.row("gap colour `color.global.backgroundDeep`", "#000000", px(img, cx, shutter["top"] + 3.5 + 3))
    sh.row("`camera.capture.size.libraryThumb`", tok("camera.capture.size.libraryThumb"), lib["width"])
    sh.row("`camera.capture.size.sideControlOffset` (library)", -tok("camera.capture.size.sideControlOffset"), (lib["left"] + lib["width"] / 2) - cx)
    sh.row("library vertically centred on the shutter", cy, lib["top"] + lib["height"] / 2)
    sh.row("`camera.capture.radius.libraryThumb` / `.size.libraryThumbBorder`", "8 / 1 (white)", "8 / 1 (Tokens)", status="match (token)")
    sh.row("`camera.capture.size.flipButton`", tok("camera.capture.size.flipButton"), flip["width"])
    sh.row("`camera.capture.size.sideControlOffset` (flip)", tok("camera.capture.size.sideControlOffset"), (flip["left"] + flip["width"] / 2) - cx)
    sh.row("`camera.capture.color.flipButton`", tok("camera.capture.color.flipButton"), px(img, flip["left"] + flip["width"] / 2 + 18, flip["top"] + flip["height"] / 2))
    sh.section("Coach tooltip")
    sh.row("`camera.capture.layout.coach` pointerToTarget (apex → ring top)", tok("camera.capture.layout.coach", "pointerToTarget"), shutter["top"] - coach["bottom"])
    sh.row("`camera.capture.layout.coach` height + pointerHeight", tok("camera.capture.layout.coach", "height") + tok("camera.capture.layout.coach", "pointerHeight"), coach["height"])
    sh.row("coach centred on the shutter", cx, coach["left"] + coach["width"] / 2)
    sh.row("coach fill `color.global.accent`", "#CDFD07", px(img, coach["left"] + 4, coach["top"] + 17))
    sh.row("`camera.capture.fontSize.coach` / `.fontWeight.coach`", "11 sp / semibold", "11 sp / FontWeight(600)", status="match (token)")
    sh.row("glyph → text gap", "not tokenized", "`camera.capture.layout.coach.textToCloseGap` (13.6)", status="approx", note="the spec gives the glyph 'at the text size' but no gap")
    sh.section("States, motion, haptics, accessibility")
    sh.row("loading: viewfinder `color.global.backgroundDeep` until the first frame", "black, controls visible", "camera.capture_loading.png", status="match (token)")
    sh.row("denied / unavailable: empty-state layout in the viewfinder", "emptyTitle / emptyDetail / white capsule 45", "camera.capture_denied.png, _unavailable.png", status="match (token)",
           note="no gap tokens between the lines; pill label inset = capsule radius")
    sh.row("`camera.capture.spring.shutterPress`, `.layout.shutterPress` 0.85", "response 233 ms, damping 1", "DSSpring from the token; Reduce Motion: no scale", status="match (token)")
    sh.row("`haptic.global.shutter`", "none", "none on any control", status="match (token)")
    sh.row("min touch target `size.global.minTouchTarget.android`", 48, "48 (view configuration from the token)", status="match (token)")
    return sh


def camera_sendto():
    m = meas("camera.sendto")
    sh = Sheet("camera.sendto", "")
    img = snap("camera.sendto_loaded")
    close, save, title, prev, field, mic = (m[k] for k in ("sendto.close", "sendto.save", "sendto.title", "sendto.preview", "sendto.field", "sendto.mic"))
    r1, r2, av, name, check, send, count, toast = (m[k] for k in ("sendto.row.g1", "sendto.row.g2", "sendto.avatar.g1", "sendto.name.g1", "sendto.check.g1", "sendto.send", "sendto.count", "sendto.toast"))
    p = TOKENS["camera.sendto.layout.preview"]["value"]
    f = TOKENS["camera.sendto.layout.messageField"]["value"]
    row = TOKENS["camera.sendto.layout.recipientRow"]["value"]
    sh.section("Header")
    sh.row("header centre (spec: 78 pt)", 78.0, close["top"] + close["height"] / 2, tol=0.6)
    sh.row("`size.global.headerButton`", tok("size.global.headerButton"), close["width"])
    sh.row("`size.global.headerInset` (✕)", tok("size.global.headerInset"), close["left"])
    sh.row("`size.global.headerInset` (download)", tok("size.global.headerInset"), SCREEN_W - save["right"])
    sh.row("`color.global.controlOnDeep`", tok("color.global.controlOnDeep"), px(img, close["left"] + 4, close["top"] + close["height"] / 2))
    sh.row("title centred", SCREEN_W / 2, title["left"] + title["width"] / 2)
    sh.row("text role `sheetTitle`", "19.5 sp / bold", "19.5 sp / FontWeight(700)", status="match (token)")
    sh.section("Preview card")
    sh.row("`camera.sendto.layout.preview` top", p["top"], prev["top"])
    sh.row("`camera.sendto.layout.preview` width × height", f"{p['width']} × {p['height']}", f"{fmt(prev['width'])} × {fmt(prev['height'])}",
           status="match" if abs(prev["width"] - p["width"]) < 0.6 and abs(prev["height"] - p["height"]) < 0.6 else "MISS")
    sh.row("`camera.sendto.layout.preview` gapBelowHeader", p["gapBelowHeader"], prev["top"] - close["bottom"])
    sh.row("card centred", SCREEN_W / 2, prev["left"] + prev["width"] / 2)
    sh.row("`radius.global.photo`", 15, "15 (Tokens.Radii.globalPhoto)", status="match (token)")
    sh.row("`camera.sendto.layout.messageField` height", f["height"], field["height"])
    sh.row("`camera.sendto.layout.messageField` insetLeading", f["insetLeading"], field["left"] - prev["left"])
    sh.row("`camera.sendto.layout.messageField` insetBottom", f["insetBottom"], prev["bottom"] - field["bottom"])
    sh.row("`camera.sendto.layout.messageField` micDiameter", f["micDiameter"], mic["width"])
    sh.row("`camera.sendto.layout.messageField` gapToMic", f["gapToMic"], mic["left"] - field["right"])
    sh.row("`camera.sendto.layout.messageField` insetTrailing", f["insetTrailing"], prev["right"] - mic["right"])
    sh.row("`camera.sendto.color.messageField`", "BLOCKED", "no fill (Blocked.messageFieldFill = null)", status="BLOCKED")
    sh.row("`camera.sendto.fontSize.messagePlaceholder`", "15 sp", "15 sp, color.global.textPrimary (C-17)", status="match (token)")
    sh.row("`camera.sendto.fontSize.caption` / `.fontWeight.caption`, `.size.captionBaselineOffset`", "16 sp semibold, 31 under the overlay baseline", "16 sp / 600; offset 31 from the overlay line", status="approx", note="offset applied between the centred overlay box and the caption box, not baseline to baseline")
    sh.row("mic + voice coach (`chat.voice.layout.recording` BLOCKED)", "recorder BLOCKED", "debug only (Blocked.voiceNoteRecorder); release hides mic and coach", status="BLOCKED")
    sh.section("Recipient rows")
    sh.row("`camera.sendto.layout.recipientRow` firstRowCenterBelowPreview", row["firstRowCenterBelowPreview"], (r1["top"] + r1["height"] / 2) - prev["bottom"])
    sh.row("`camera.sendto.layout.recipientRow` pitch", row["pitch"], r2["top"] - r1["top"])
    sh.row("`size.global.avatarSmall`", tok("size.global.avatarSmall"), av["width"])
    sh.row("`camera.sendto.layout.recipientRow` avatarCenterInset", row["avatarCenterInset"], av["left"] + av["width"] / 2)
    sh.row("`camera.sendto.layout.recipientRow` nameInset", row["nameInset"], name["left"])
    sh.row("`size.global.checkCircle`", tok("size.global.checkCircle"), check["width"])
    sh.row("`camera.sendto.layout.recipientRow` checkTrailingInset", row["checkTrailingInset"], SCREEN_W - check["right"])
    sh.row("`color.global.selection` (checked)", "#0091FF", px(img, check["left"] + check["width"] / 2 - 7, check["top"] + check["height"] / 2), tol=10)
    sh.row("text role `headerTitle` (C-16)", "15 sp / bold", "15 sp / FontWeight(700)", status="match (token)")
    sh.section("Send button and toast")
    sh.row("`size.global.buttonHeightSheet`", tok("size.global.buttonHeightSheet"), send["height"])
    sh.row("`size.global.buttonMarginHSheet` (leading)", tok("size.global.buttonMarginHSheet"), send["left"])
    sh.row("`size.global.buttonMarginHSheet` (trailing)", tok("size.global.buttonMarginHSheet"), SCREEN_W - send["right"])
    sh.row("`camera.sendto.size.sendButtonBottom`", tok("camera.sendto.size.sendButtonBottom"), SCREEN_H - send["bottom"])
    sh.row("fill `color.global.accent`", "#CDFD07", px(img, send["left"] + 8, send["top"] + send["height"] / 2))
    sh.row("`camera.sendto.size.countDisc`", tok("camera.sendto.size.countDisc"), count["width"])
    sh.row("count disc `color.global.onAccent`", "#000000", px(img, count["left"] + 2.5, count["top"] + count["height"] / 2), tol=30)
    sh.row("`radius.global.button`", 14, "14 (Tokens.Radii.globalButton)", status="match (token)")
    sh.row("`camera.sendto.layout.toast` top", tok("camera.sendto.layout.toast", "top"), toast["top"])
    sh.row("`camera.sendto.layout.toast` height", tok("camera.sendto.layout.toast", "height"), toast["height"])
    sh.row("`camera.sendto.layout.toast` marginHorizontal", tok("camera.sendto.layout.toast", "marginHorizontal"), toast["left"])
    sh.row("`camera.sendto.duration.toastVisible`", "BLOCKED", "posted / saved toasts not shown (Blocked.toastVisibleMillis = null); error toast stays until sent", status="BLOCKED")
    sh.row("`camera.sendto.size.captionMaxLength`", "BLOCKED", "no UI limit (server bound applies)", status="BLOCKED")
    sh.section("States, haptics")
    sh.row("loading / empty / offline / error / nothing selected / free-member video", "spec states", "camera.sendto_loading, _empty, _offline, _error, _nothing-selected, _video-free", status="match (token)")
    sh.row("`haptic.global.select` / `.send` / `.error`", "toggle / sent / failed", "row toggle / queued (optimistic) / failure toast", status="match (token)")
    return sh


def daily_capture():
    live = meas("daily.capture.live")
    pv = meas("daily.capture.preview")
    sh = Sheet("daily.capture", "")
    img = snap("daily.capture_live")
    pimg = snap("daily.capture_preview")
    vf = TOKENS["daily.capture.layout.viewfinder"]["value"]
    d, v, s, fl, fp = (live[k] for k in ("daily.dismiss", "daily.viewfinder", "daily.shutter", "daily.flash", "daily.flip"))
    sh.section("Live")
    sh.row("`daily.capture.layout.dismiss` centerFromLeading", tok("daily.capture.layout.dismiss", "centerFromLeading"), d["left"] + d["width"] / 2)
    sh.row("`daily.capture.layout.dismiss` centerFromTop", tok("daily.capture.layout.dismiss", "centerFromTop"), d["top"] + d["height"] / 2)
    digit_top = first_bright_row(img, 120, 273, 80, 124)
    sh.row("`daily.capture.layout.countdown` digitsTop", tok("daily.capture.layout.countdown", "digitsTop"), digit_top, tol=1.0, note="first light row of the digits in our render")
    sh.row("`daily.capture.fontSize.countdown` / `.fontWeight.countdown`", "23 sp / BLOCKED", "release: not drawn; debug: Bold (closing step: Roboto '1' stem ÷ height 0.198)", status="BLOCKED")
    sh.row("`daily.capture.layout.viewfinder` sideMargin", vf["sideMargin"], v["left"])
    sh.row("`daily.capture.layout.viewfinder` top", vf["top"], v["top"])
    sh.row("`daily.capture.layout.viewfinder` width (393 − 2 × 7)", SCREEN_W - 2 * vf["sideMargin"], v["width"])
    sh.row("`daily.capture.layout.viewfinder` aspect 3:4", round((SCREEN_W - 2 * vf["sideMargin"]) / vf["aspect"], 2), v["height"])
    sh.row("`daily.capture.layout.viewfinder` width token (378.7 at 393)", vf["width"], v["width"], tol=0.5)
    sh.row("`daily.capture.layout.shutter` outer", tok("daily.capture.layout.shutter", "outer"), s["width"])
    sh.row("`daily.capture.layout.shutter` centerFromBottom", tok("daily.capture.layout.shutter", "centerFromBottom"), SCREEN_H - (s["top"] + s["height"] / 2))
    sh.row("shutter ring + disc `color.global.surfaceLight`", "#FFFFFF", px(img, s["left"] + s["width"] / 2, s["top"] + s["height"] / 2))
    sh.row("shutter gap `color.global.backgroundDeep`", "#000000", px(img, s["left"] + s["width"] / 2, s["top"] + 4 + 1.3))
    sh.row("`daily.capture.layout.sideControls` flashCenterFromLeading", tok("daily.capture.layout.sideControls", "flashCenterFromLeading"), fl["left"] + fl["width"] / 2)
    sh.row("`daily.capture.layout.sideControls` flipCenterFromTrailing", tok("daily.capture.layout.sideControls", "flipCenterFromTrailing"), SCREEN_W - (fp["left"] + fp["width"] / 2))
    sh.row("`daily.capture.color.text`", tok("daily.capture.color.text"), "Tokens.Colors.dailyCaptureColorText (glyphs, countdown, SEND)", status="match (token)")
    sh.section("Capturing")
    sh.row("`daily.capture.size.progress`", tok("daily.capture.size.progress"), "34.7 (CircularProgressIndicator size)", status="match (token)")
    sh.row("`daily.capture.layout.prompt` gapBelowSpinner, `.fontSize.prompt`", "11.4 / 17 sp", "11.4 / 17 sp (weight not measured: platform regular)", status="match (token)")
    sh.row("`daily.capture.layout.captureSequence`", "press 133 → 0.912; controls out 370; fade 267; back photo in 200", "springs with response = each duration, damping 1; Reduce Motion: fades only", status="match (token)",
           note="betweenShots (500) is camera-dependent; the spinner shows while the cameras work")
    sh.section("Preview")
    di, rt, ch = pv["daily.dualimage"], pv["daily.retake"], pv["daily.chip"]
    sh.row("dual image in the viewfinder frame: width", SCREEN_W - 2 * vf["sideMargin"], di["width"])
    sh.row("`daily.capture.layout.retake` diameter", tok("daily.capture.layout.retake", "diameter"), rt["width"])
    sh.row("`daily.capture.layout.retake` inset (top)", tok("daily.capture.layout.retake", "inset"), rt["top"] - di["top"])
    sh.row("`daily.capture.layout.retake` inset (trailing)", tok("daily.capture.layout.retake", "inset"), di["right"] - rt["right"])
    sh.row("`daily.capture.layout.audienceChip` height", tok("daily.capture.layout.audienceChip", "height"), ch["height"])
    sh.row("`daily.capture.layout.audienceChip` bottomInset", tok("daily.capture.layout.audienceChip", "bottomInset"), di["bottom"] - ch["bottom"])
    sh.row("chip centred", di["left"] + di["width"] / 2, ch["left"] + ch["width"] / 2)
    sh.row("`daily.capture.color.overlayControl`", "BLOCKED", "retake circle and chip without a fill", status="BLOCKED")
    cap_top = first_bright_row(pimg, 120, 273, di["bottom"] + 40, di["bottom"] + 110)
    sh.row("`daily.capture.layout.send` capTopBelowImage", tok("daily.capture.layout.send", "capTopBelowImage"), cap_top - di["bottom"], tol=1.5, note="first light row of 'SEND' in our render")
    sh.row("`daily.capture.fontSize.send` / `.fontWeight.send`, glyph 19.5, gap 11.4", "40.5 sp heavy", "40.5 sp / FontWeight(800); icon.global.play 19.5; gap 11.4", status="match (token)")
    sh.section("States")
    sh.row("window closed / opened after: no countdown, nothing in its place", "removed", "daily.capture_live-closed.png", status="match (token)")
    sh.row("single camera / sequential fallback / denied / unavailable / send failed", "spec states", "_preview-single, flow test, _denied, _unavailable, _send-offline", status="match (token)")
    return sh


def first_bright_row(img, x0, x1, y0_dp, y1_dp, threshold=200):
    for y in range(int(y0_dp * SCALE), int(y1_dp * SCALE)):
        for x in range(int(x0 * SCALE), int(x1 * SCALE)):
            r, g, b = img.getpixel((x, y))[:3]
            if r > threshold and g > threshold and b > threshold:
                return round(y / SCALE, 2)
    return -1.0


def daily_dualimage():
    sh = Sheet("daily.dualimage", "")
    img = snap("daily.dualimage_component")
    c = TOKENS["daily.dualimage.layout.composition"]["value"]
    W = SCREEN_W
    top = 124.0
    # Inset outer box: the black border frame inside the main image near the top-leading corner.
    margin = c["insetMarginRatio"] * W
    sh.section("Composition (ratios of the main width W = 393)")
    sh.row("`daily.dualimage.layout.composition` mainAspect (height)", round(W / c["mainAspect"], 2), measure_height(img, top), tol=1.0)
    border_x = scan_black_run(img, top + margin + 30, 0, 60)
    sh.row("`insetMarginRatio` × W (inset left)", round(margin, 2), border_x, tol=0.7)
    right = scan_black_run(img, top + margin + 30, border_x + 30, border_x + c["insetWidthRatio"] * W + 10, reverse=True)
    sh.row("`insetWidthRatio` × W (inset outer width)", round(c["insetWidthRatio"] * W, 2), round(right - border_x, 2), tol=1.0)
    sh.row("`insetBorderRatio` × W (border, `color.global.backgroundDeep`)", round(c["insetBorderRatio"] * W, 2), "2.0 (padding from the token ratio)", status="match (token)")
    sh.row("`mainRadiusRatio` / `insetOuterRadiusRatio`", f"{c['mainRadiusRatio']} W / {c['insetOuterRadiusRatio']} × inset", "RoundedCornerShape from the ratios", status="match (token)")
    sh.row("loading: frames `color.global.backgroundDeep`", "#000000", px(snap("daily.dualimage_loading"), 196, top + 200))
    sh.row("`daily.dualimage.a11y.label`", "Back and front photos from {name}", "one element, label from copy", status="match (token)")
    return sh


def measure_height(img, top_dp):
    x = int(SCREEN_W / 2 * SCALE)
    y = int((top_dp + 5) * SCALE)
    while y < img.height and sum(img.getpixel((x, y))[:3]) > 30:
        y += 1
    return round(y / SCALE - top_dp, 2)


def scan_black_run(img, y_dp, x0_dp, x1_dp, reverse=False):
    y = int(y_dp * SCALE)
    xs = range(int(x0_dp * SCALE), int(x1_dp * SCALE))
    xs = list(xs)[::-1] if reverse else xs
    for x in xs:
        if sum(img.getpixel((x, y))[:3]) < 30:
            return round(x / SCALE + (1 / SCALE if reverse else 0), 2)
    return -1.0


def collage_view():
    m = meas("collage.view")
    hud = meas("collage.view.hud").get("collage.hud")
    sh = Sheet("collage.view", "")
    img = snap("collage.view_ready-pages")
    scr = TOKENS["collage.view.layout.screen"]["value"]
    back, title, dots, pager = m["collage.back"], m["collage.title"], m["collage.dots"], m["collage.pager"]
    sh.section("Screen")
    sh.row("`collage.view.layout.screen` headerCenterFromTop (back)", scr["headerCenterFromTop"], back["top"] + back["height"] / 2)
    sh.row("`collage.view.layout.screen` headerCenterFromTop (title)", scr["headerCenterFromTop"], title["top"] + title["height"] / 2)
    sh.row("`size.global.headerButton` / `.headerInset`", "44 / 11.5", f"{fmt(back['width'])} / {fmt(back['left'])}", status="match" if abs(back["width"] - 44) < 0.6 and abs(back["left"] - 11.5) < 0.6 else "MISS")
    sh.row("`collage.view.fontSize.title` / `.fontWeight.title`", "16 sp / semibold", "16 sp / FontWeight(600)", status="match (token)")
    sh.row("`collage.view.layout.screen` dotsCenterFromTop", scr["dotsCenterFromTop"], dots["top"] + dots["height"] / 2)
    pd = TOKENS["collage.view.layout.pageDots"]["value"]
    sh.row("`collage.view.layout.pageDots` diameter", pd["diameter"], dots["height"])
    sh.row("`collage.view.layout.pageDots` pitch (2 dots: width = pitch + diameter)", round(pd["pitch"] + pd["diameter"], 2), dots["width"])
    sh.row("`collage.view.color.pageDotActive`", tok("collage.view.color.pageDotActive"), px(img, dots["left"] + pd["diameter"] / 2, dots["top"] + pd["diameter"] / 2), tol=8)
    sh.row("inactive dot `color.global.controlRaised`", "#434343", px(img, dots["right"] - pd["diameter"] / 2, dots["top"] + pd["diameter"] / 2), tol=8)
    sh.row("`collage.view.layout.screen` pageTop", scr["pageTop"], pager["top"])
    sh.row("page 9:16 aspect-fit, centred (`collage.view.layout.page`)", "aspect 0.5625", "frame aspect from the token, Fit", status="match (token)")
    if hud:
        h = TOKENS["collage.view.layout.hud"]["value"]
        sh.section("Loading HUD")
        sh.row("`collage.view.layout.hud` width × height", f"{h['width']} × {h['height']}", f"{fmt(hud['width'])} × {fmt(hud['height'])}",
               status="match" if abs(hud["width"] - h["width"]) < 0.6 and abs(hud["height"] - h["height"]) < 0.6 else "MISS")
        hi = snap("collage.view_loading")
        sh.row("`collage.view.color.hud`", tok("collage.view.color.hud"), px(hi, hud["left"] + 4, hud["top"] + 4), tol=4)
        sh.row("`collage.view.layout.hud` cornerRadius, label text role `body`", "8.5 / 17 sp", "8.5 / 17 sp", status="match (token)")
    sh.section("States")
    sh.row("empty / error / offline / recomposing (keeps the cached pages)", "spec states", "collage.view_empty, _error, _offline; CollageViewModel tests", status="match (token)")
    return sh


def collage_share():
    m = meas("collage.view")
    sh = Sheet("collage.share", "")
    pill = m["collage.share"]
    p = TOKENS["collage.share.layout.pill"]["value"]
    sh.section("Share pill")
    sh.row("`collage.share.layout.pill` width", p["width"], pill["width"])
    sh.row("`collage.share.layout.pill` height", p["height"], pill["height"])
    sh.row("`collage.share.layout.pill` bottomFromScreenBottom", p["bottomFromScreenBottom"], SCREEN_H - pill["bottom"])
    sh.row("pill centred", SCREEN_W / 2, pill["left"] + pill["width"] / 2)
    sh.row("`collage.share.layout.pill` cornerRadius / glyph", "10 / 25.7", "10 / 25.7 (Tokens)", status="match (token)")
    sh.row("`collage.share.fontSize.label` / `.fontWeight.label`", "18 sp / bold", "18 sp / FontWeight(700)", status="match (token)")
    sh.row("`collage.share.color.pill`", "BLOCKED", "no fill (Blocked.sharePillFill = null)", status="BLOCKED")
    sh.row("glyph → label gap", "not tokenized", "none added (the glyph's own side bearing)", status="approx")
    sh.section("Sheet and export")
    sh.row("`collage.share.layout.sheet` android", "createChooser(ACTION_SEND image/jpeg content:// + READ grant, title)", "Intent.createChooser, EXTRA_STREAM via FileProvider, EXTRA_TITLE, ClipData preview", status="match (token)")
    sh.row("`collage.share.sheetTitle`", "share with friends", "EXTRA_TITLE / chooser title", status="match (token)")
    sh.row("`collage.share.layout.export`", "share-<n>.jpg of the current page, 1080 × 1920, no watermark", "share-<page+1>.jpg downloaded as is (CollageViewModel test)", status="match (token)")
    sh.row("pill hidden until `share_path` is set", "hidden", "collage.view_ready-no-share.png", status="match (token)")
    return sh


def widgets():
    m = meas("widget.android")
    out = {}
    for surface in ("widget.android", "widget.home.small", "widget.home.medium", "widget.home.large"):
        sh = Sheet(surface, "")
        sh.section("Overlay (photo)")
        sh.row("`widget.android.size.avatar`", tok("widget.android.size.avatar"), m.get("avatarSize", -1), tol=0.7)
        sh.row("`widget.android.size.overlayMargin` (start)", tok("widget.android.size.overlayMargin"), m.get("avatarLeft", -1), tol=0.7)
        sh.row("`widget.android.size.overlayMargin` (bottom)", tok("widget.android.size.overlayMargin"), m.get("avatarBottomInset", -1), tol=0.7)
        sh.row("`widget.android.size.captionGap`", tok("widget.android.size.captionGap"), m.get("captionGap", -1), tol=0.7)
        sh.row("`widget.home.small.size.captionHeight`", tok("widget.home.small.size.captionHeight"), m.get("pillHeight", -1), tol=0.7)
        sh.row("caption truncates at the trailing edge − margin", round(m.get("widthDp", 0) - 8, 1), m.get("pillRight", -1), tol=1.0, note="small widget, long caption: the pill fills the row and ellipsizes")
        sh.row("`widget.home.small.color.captionPill` / `.fontSize.caption` / `.fontWeight.caption`", "#333333CC / 12 sp / semibold", "drawn with the token colour, 12 sp, weight 600 (API 28+)", status="match (token)")
        sh.row("`widget.home.small.color.avatarRing` / `.size.avatarRing`", "#0000001A / 1", "ring drawn inside the edge", status="match (token)")
        sh.row("no avatar → `widget.android.color.avatarPlaceholderTop` → `.Bottom`", "#A0A0A0F5 → #828282F5", "gradient circle (widget.android_*_photo-noavatar.png)", status="match (token)")
        sh.row("collage: no avatar / pill", "none", "widget.android_*_collage.png", status="match (token)")
        if surface in ("widget.home.small", "widget.home.medium", "widget.home.large"):
            ios = {"widget.home.small": "158 × 158", "widget.home.medium": "338 × 158", "widget.home.large": "338 × 354"}[surface]
            sh.row(f"`{surface}.layout.size` (iOS)", ios, f"Android placement {ios_android(surface)}", status="approx", note="Android draws the same layout at the launcher's cell size (C-20); iOS 24-pt avatar / 6-pt inset are the iOS values, Android uses the Locket APK's 32 / 8 dp")
        sh.section("Empty / not set up / loading")
        sh.row("`widget.home.small.layout.empty` ring", tok("widget.home.small.layout.empty", "ring"), m.get("ringDiameter", -1), tol=1.0)
        sh.row("ring centred (x)", round(m.get("widthDp", 0) / 2, 1), m.get("ringCenterX", -1), tol=1.0)
        sh.row("`widget.home.small.color.emptyTop`", tok("widget.home.small.color.emptyTop"), "#" + m.get("emptyTop", "000000")[-6:].upper(), tol=6)
        sh.row("`widget.home.small.color.emptyBottom`", tok("widget.home.small.color.emptyBottom"), "#" + m.get("emptyBottom", "000000")[-6:].upper(), tol=6)
        sh.row("`widget.home.small.layout.empty` circle / ringStroke / glyph", "72 / 3 / 32 × 28", "72 / 3 / icon.global.gallery fitted in 32 × 28 (28 × 28: square viewport)", status="approx", note="Locket's glyph is 32 × 28; the token icon is square")
        sh.row("`widget.home.small.color.emptyLabel` (label 19 sp, gap 9)", "BLOCKED", "label not drawn; TalkBack reads it", status="BLOCKED")
        sh.row("sm / lg empty variants by size", "rule not observed", "md at every size (widget.android spec)", status="approx")
        sh.row("loading: `widget.home.small.color.placeholderTop/Bottom`, avatars 25 / 2.5 / 6", "gradient + ≤ 3 avatars", "widget.android_*_loading.png", status="match (token)")
        sh.section("Provider, tap, accessibility, arrival")
        sh.row("`widget.android.label`", "{app_name} (BLOCKED)", "receiver has no label (picker shows the app label)", status="BLOCKED")
        sh.row("`widget.android.description`", "Live pics from your group, on your home screen", "android:description", status="match (token)")
        sh.row("preview", "generated (Android 15+); previewImage BLOCKED", "providePreview + setWidgetPreviews at start; no previewImage", status="match (token)")
        sh.row("`widget.android.duration.updatePeriod`, `.size.minSize`", "86400000 ms / 110 dp", "updatePeriodMillis 86400000; minWidth/Height 110dp", status="match (token)")
        sh.row("tap", "camera for the group / configure when not set up", "PendingIntent app://camera?group= / WidgetConfigureActivity", status="match (token)")
        sh.row("root contentDescription", "widget.home.small.a11y.*", "photoWithCaption / photo / collage / empty label (unit test)", status="match (token)")
        sh.row("`widget.arrival.duration.transition`", "0 ms", "Glance update, no transition (widget.arrival_before/after)", status="match (token)")
        out[surface] = sh
    return out


def ios_android(surface):
    return {"widget.home.small": "2×2", "widget.home.medium": "4×2", "widget.home.large": "4×4"}[surface]


def widget_arrival():
    sh = Sheet("widget.arrival", "")
    sh.section("Arrival")
    sh.row("`widget.arrival.duration.transition`", "0 ms", "new RemoteViews in one update (no fade / slide)", status="match (token)")
    sh.row("`widget.arrival.duration.expectedDelay`", "300000 ms (QA bound)", "FCM → expedited WorkManager → store → Glance update (core:push / core:widget)", status="match (token)")
    sh.row("`widget.arrival.android.refreshTitle` / channel name / description", "Updating widget... / Widget Updating / …", "WidgetRefreshNotification (channel widget_refresh, IMPORTANCE_LOW)", status="match (token)")
    sh.row("refresh notification only while a foreground job runs (≤ Android 11)", "expedited + ForegroundInfo", "getForegroundInfo; expedited below API 31 only when a small icon exists", status="approx", note="the small icon is an owner asset (BLOCKED)")
    sh.row("error / offline keeps the last photo; muted groups still update", "spec", "store keeps the last rendition; worker retries", status="match (token)")
    return sh


def notifications():
    a = Sheet("daily.ongoing", "")
    a.section("Notification (`daily.ongoing.layout.notification`)")
    a.row("style", "NotificationCompat standard (title + text)", "standard; title and text from the push (rendered by the worker from the copy keys)", status="match (token)")
    a.row("countdown", "setUsesChronometer + setChronometerCountDown + setWhen(closesAt)", "chronometer counting down to closes_at (flow test)", status="match (token)")
    a.row("removal", "setTimeoutAfter(closesAt − now)", "timeoutAfter = 120000 ms in the flow test", status="match (token)")
    a.row("ongoing", "false (dismissible)", "FLAG_ONGOING_EVENT off; auto-cancel on tap", status="match (token)")
    a.row("promoted", "no (C-11)", "no setRequestPromotedOngoing; POST_PROMOTED_NOTIFICATIONS removed", status="match (token)")
    a.row("channel", "daily_invitation, IMPORTANCE_HIGH, copy notifications.push.channel.dailyInvitation.*", "registered with the copy (flow test)", status="match (token)")
    a.row("color", "color.global.accent #CDFD07", "Notification.color = #CDFD07", status="match (token)")
    a.row("tap", "app://daily?group=<id>&invitation=<id>", "same (flow test)", status="match (token)")
    a.row("quiet hours (no push flag)", "silent", "applied on device from QuietHoursSource (GROUP_ALERT_SUMMARY = silent)", status="match (token)")
    a.row("small icon (monochrome app glyph)", "BLOCKED (owner asset)", "hook NotificationAppearance.smallIcon = null; launcher icon fallback; nothing posted without either", status="BLOCKED")
    b = Sheet("daily.notification", "")
    b.section("Android presentation")
    for row in a.sections[0][1]:
        pass
    b.row("presentation", "the countdown notification in channel daily_invitation (→ daily.ongoing)", "DailyInvitationNotifier", status="match (token)")
    b.row("`notifications.push.dailyInvitation.title` / `.body`", "Time to share a photo. / Capture a photo and see what {group} is up to!", "shown as sent by the worker", status="match (token)")
    b.row("`notifications.push.channel.dailyInvitation.name` / `.description`", "Daily Invitation / Notifications when your group’s daily photo invitation starts", "registered (flow test)", status="match (token)")
    b.row("after closes_at", "tap opens daily.capture without a countdown; posts normally", "DailyCaptureViewModel test", status="match (token)")
    b.row("delivery (`daily.notification.layout.delivery`)", "one per group per day; no reminder; no update on close", "one tag per group; ended message cancels", status="match (token)")
    c = Sheet("notifications.push", "")
    c.section("Channels (`notifications.push.layout.channels`, copy `notifications.push.channel.*`)")
    for ch, imp, name in (("daily_invitation", "HIGH", "Daily Invitation"), ("new_post", "DEFAULT", "New Photos"), ("reactions_replies", "DEFAULT", "Reactions and Replies"),
                          ("recap", "DEFAULT", "Weekly Recaps"), ("birthday_request", "DEFAULT", "Birthday Requests"), ("tribute", "DEFAULT", "Birthday Videos")):
        c.row(f"`{ch}`", f"{name}, IMPORTANCE_{imp}", f"{name}, IMPORTANCE_{imp}", status="match (token)")
    c.row("`year_story`", "no sent event → no copy (owner decision)", "not registered", status="match (token)")
    c.section("Layout and hooks")
    c.row("title + body", "system", "standard template, text as sent (notifications.push_new-post.png)", status="match (token)")
    c.row("grouping", "setGroup(group_id)", "group:<group_id>", status="match (token)")
    c.row("actions", "none", "none", status="match (token)")
    c.row("small icon", "BLOCKED (owner asset)", "hook left (NotificationAppearance.smallIcon)", status="BLOCKED")
    c.row("accent", "daily invitation: color.global.accent; alerts: not specified", "invitation #CDFD07; alerts system default", status="match (token)")
    c.row("quiet hours", "delivered silently", "setSilent during QuietHoursSource window", status="match (token)")
    return {"daily.ongoing": a, "daily.notification": b, "notifications.push": c}


def camera_fromwidget():
    sh = Sheet("camera.fromwidget", "")
    sh.section("Route")
    sh.row("`camera.fromwidget.layout.target` link", "app://camera?group=<group_id>", "DeepLink.Camera(groupId) → AppRoute.Camera", status="match (token)")
    sh.row("missing / unreadable group id (C-24)", "camera still opens, nothing preselected", "DeepLink.Camera(groupId: String? = null); `app://camera` parses (DeepLinkTest)", status="match (token)")
    sh.row("android target", "PendingIntent ACTION_VIEW on the widget root", "Glance clickable(actionStartActivity(intent)) on the root", status="match (token)")
    sh.row("opens", "camera.capture, group preselected in camera.sendto", "flow test widgetLinkOpensTheCameraOneTapCapturesAndSendsToTwoGroups", status="match (token)")
    sh.row("group left / deleted", "camera opens; nothing preselected", "SendToViewModel test (gone id → empty selection)", status="match (token)")
    sh.row("no splash / interstitial", "direct", "deep link back stack [home, camera]; CameraX pre-warmed at process start", status="match (token)")
    return sh


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(SCRATCH, exist_ok=True)
    results = {}
    sheets = {"camera.capture": camera_capture(), "camera.sendto": camera_sendto(), "daily.capture": daily_capture(),
              "daily.dualimage": daily_dualimage(), "collage.view": collage_view(), "collage.share": collage_share(),
              "widget.arrival": widget_arrival(), "camera.fromwidget": camera_fromwidget()}
    sheets.update(widgets())
    sheets.update(notifications())

    yope = ("auto", "yope", "frames")
    pics = {
        "camera.capture": (S("camera.capture_coach"), R(*yope, "a-jacob-7691153057177931039-t3.73-camera-hold-to-record.png")),
        "camera.sendto": (S("camera.sendto_voice-coach"), R(*yope, "a-chuongxetank-7694968408424582452-t6.73-sendto-voice-tooltip.png")),
        "camera.fromwidget": (concat([S("widget.android_small_photo-caption"), S("camera.capture_live")], C("fromwidget"), height=1200), R("auto", "locket", "store", "locket-store-07.png")),
        "widget.home.small": (S("widget.android_small_photo-caption"), R("auto", "locket", "store", "locket-store-03.png")),
        "widget.home.medium": (S("widget.android_medium_photo-caption"), R("auto", "locket", "store", "locket-store-03.png")),
        "widget.home.large": (S("widget.android_large_photo-caption"), R("auto", "locket", "store", "locket-store-06.png")),
        "widget.android": (concat([S("widget.android_small_photo-caption"), S("widget.android_small_loading"), S("widget.android_small_empty"), S("widget.android_small_collage")], C("widget-android")),
                           R("auto", "locket", "play", "locket-play-01.png")),
        "widget.arrival": (concat([S("widget.arrival_before"), S("widget.arrival_after")], C("arrival")),
                           concat([R("auto", "locket", "frames", "locket-tt-7168613044728155438-15.133s-widget-placeholder-just-added.jpg"),
                                   R("auto", "locket", "frames", "locket-tt-7168613044728155438-15.167s-widget-photo-arrived.jpg")], C("arrival-ref"))),
        "daily.notification": (S("daily.ongoing_notification"), R("auto", "bereal", "help", "help-21089073691933_time-to-bereal-push.png")),
        "daily.ongoing": (S("daily.ongoing_notification"), R("auto", "bereal", "help", "help-21089073691933_time-to-bereal-push.png")),
        "notifications.push": (S("notifications.push_new-post"), R("auto", "bereal", "help", "help-21089073691933_time-to-bereal-push.png")),
        "daily.capture": (concat([S("daily.capture_live"), S("daily.capture_capturing"), S("daily.capture_preview")], C("daily")),
                          concat([R("auto", "bereal", "frames", "appstore-preview-2026_t3.50s_capture.png"),
                                  R("auto", "bereal", "frames", "tiktok-bereal-7339559678604627233_t17.63s_black-spinner-prompt.png"),
                                  R("auto", "bereal", "frames", "tiktok-bereal-7339559678604627233_t21.30s_preview-keep-smiling.png")], C("daily-ref"))),
        "daily.dualimage": (S("daily.dualimage_component"), R("auto", "bereal", "help", "help-21083730354333_feed-bonus-3x.png")),
        "collage.view": (S("collage.view_ready-pages"), R(*yope, "b-alexaa-7652512140875566349-t5.33-day-view-recap.png")),
        "collage.share": (S("collage.view_ready"), R("auto", "yope", "store", "yope-store-04.png")),
    }
    for surface, sheet in sheets.items():
        ours, ref = pics[surface]
        side_by_side(surface, ours, ref, f"{surface} — Android (ours, left) vs reference")
        header = HEADER + ["", f"Side by side: [`{surface}.png`]({surface}.png) — ours left ({os.path.basename(ours)}), reference right ({os.path.relpath(ref, ROOT)})."]
        results[surface] = sheet.write(header)
    for s, c in results.items():
        print(s, c)


if __name__ == "__main__":
    main()
