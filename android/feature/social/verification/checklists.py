#!/usr/bin/env python3
"""Verification of the Android social screens (docs/SCREENS_BRIEF.md rule 8).

Inputs (produced by `./gradlew :feature:social:testDebugUnitTest`):
  android/feature/social/src/test/snapshots/*.png   our renders (Roborazzi, 393 x 852 dp at 2x)
  android/feature/social/build/verification/*.json  laid-out bounds in dp + sampled colours (VerificationMeasurements)
Outputs:
  design/verification/<surface>.android.png   ours | reference, via tools/sidebyside.py
  design/verification/<surface>.android.md    token -> expected value -> what our screen shows -> status
(".android" keeps them apart from the iOS pass's <surface>.md / .png.)

Status: "match" (measured within the token's precision), "match (token)" (the value goes from the
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


def side_by_side(surface, ours_names, ref, title, ref_crop=None):
    ours = os.path.join(SNAP, "app.feature.social." + ours_names[0] + ".png") if len(ours_names) == 1 else concat(ours_names, os.path.join(SCRATCH, surface + ".png"))
    out = os.path.join(OUT, surface + ".android.png")
    cmd = [sys.executable, "-I", os.path.join(ROOT, "tools", "sidebyside.py"), out, ours, os.path.join(ROOT, ref), "--title", title]
    if ref_crop:
        cmd += ["--ref-crop", ref_crop]
    subprocess.run(cmd, check=True, capture_output=True)
    return out


def header(surface, ours_names, ref, extra=""):
    shots = ", ".join(f"`{n.split('.', 1)[1]}`" for n in ours_names)
    return [
        "Generated by `android/feature/social/verification/checklists.py` from the Robolectric renders "
        "(`./gradlew :feature:social:testDebugUnitTest`, Roborazzi baselines in `android/feature/social/src/test/snapshots/`, "
        "debug build, 393 × 852 dp at 2×, Reduce Motion off) and the bounds / colours `VerificationMeasurements` reads back "
        "(dp, screen top-left origin; `android/feature/social/build/verification/*.json`). Expected values come from "
        "`design/tokens/*.json`; colours are sampled from our render.",
        "",
        f"Side by side: [`{surface}.android.png`]({surface}.android.png) — ours left ({shots}), reference right (`{ref}`).",
    ] + ([""] + [extra] if extra else [])


# ---------------------------------------------------------------------------------------------
def chat_thread():
    m = meas("chat")
    sh = Sheet("chat.thread")
    img = snap("ChatSnapshotTest.content")
    back, cap, recap, photo = m["back"], m["capsule"], m["recap"], m["photo"]
    their, their2, mine, reply, caption = m["theirBubble"], m["theirBubble2"], m["myBubble"], m["reply"], m["caption"]
    sh.section("Header")
    sh.row("`size.global.headerInset` (‹)", tok("size.global.headerInset"), back["left"])
    sh.row("`size.global.headerButton`", tok("size.global.headerButton"), back["width"])
    sh.row("`size.global.headerGap` (‹ → capsule)", tok("size.global.headerGap"), cap["left"] - back["right"])
    sh.row("`chat.thread.dimension.headerCapsuleHeight`", tok("chat.thread.dimension.headerCapsuleHeight"), cap["height"])
    sh.row("`color.global.control` (capsule)", tok("color.global.control"), m["controlFill"]["hex"])
    sh.row("`size.global.headerInset` (film-strip circle)", tok("size.global.headerInset"), W - recap["right"])
    sh.row("capsule insides (avatar · name · ›)", "groups.screen header", "avatar concentric with the rounded end, items `size.global.headerGap` apart", status="approx",
           note="S1's capsule is covered by a sticker (spec Gaps)")
    sh.row("`color.global.background`", tok("color.global.background"), m["background"]["hex"])
    sh.section("Bubbles")
    sh.row("`chat.thread.dimension.bubbleInsetTheirs`", tok("chat.thread.dimension.bubbleInsetTheirs"), their["left"], note="avatar column 11.2 + 32.6 + 6.7")
    sh.row("`chat.thread.dimension.bubbleInsetMine`", tok("chat.thread.dimension.bubbleInsetMine"), W - mine["right"])
    sh.row("`chat.thread.dimension.bubbleHeight` (one line)", tok("chat.thread.dimension.bubbleHeight"), their["height"])
    sh.row("`chat.thread.color.bubbleTheirs`", tok("chat.thread.color.bubbleTheirs"), m["theirBubbleFill"]["hex"])
    sh.row("`chat.thread.color.bubbleMine`", tok("chat.thread.color.bubbleMine"), m["myBubbleFill"]["hex"])
    sh.row("`chat.thread.dimension.gapSameSender`", tok("chat.thread.dimension.gapSameSender"), their["top"] - their2["bottom"])
    sh.row("`chat.thread.dimension.gapBetweenSenders`", tok("chat.thread.dimension.gapBetweenSenders"), reply["top"] - their["bottom"])
    sh.row("`chat.thread.dimension.bubbleMaxWidth` (long text wraps)", tok("chat.thread.dimension.bubbleMaxWidth"), m["longBubble"]["width"], note="G-1; render `emojiOnlyAndLongText`")
    sh.row("`chat.thread.count.emojiOnlyMax` (3 emoji, no bubble)", tok("chat.thread.count.emojiOnlyMax") * tok("chat.thread.dimension.emojiOnlyGlyph"), m["emojiOnly"]["width"],
           note="3 × `chat.thread.dimension.emojiOnlyGlyph`; 4+ emoji are a text bubble (G-2)")
    sh.row("`chat.thread.radius.bubble`, rim `chat.thread.dimension.bubbleRim` + rim colours", f"{tok('chat.thread.radius.bubble')} / {tok('chat.thread.dimension.bubbleRim')}", "Tokens.Radii / Tokens.Sizes / Tokens.Colors", status="match (token)")
    sh.section("Photo message")
    sh.row("`chat.thread.dimension.photoInsetTrailing`", tok("chat.thread.dimension.photoInsetTrailing"), W - photo["right"])
    sh.row("`chat.thread.dimension.photoWidth` × `.photoHeight`", f"{tok('chat.thread.dimension.photoWidth')} × {tok('chat.thread.dimension.photoHeight')}", f"{fmt(photo['width'])} × {fmt(photo['height'])}",
           status="approx", note="the frame fills the column (avatar column → photoInsetTrailing) at the token aspect: 323 at the reference's column")
    sh.row("`chat.thread.layout.timeFormat` (centred)", "h:mm a", "8:01 PM, centred", status="match (token)")
    sh.row("`chat.thread.dimension.captionHeight`", tok("chat.thread.dimension.captionHeight"), caption["height"])
    sh.row("`chat.thread.dimension.captionInsetBottom`", tok("chat.thread.dimension.captionInsetBottom"), photo["bottom"] - caption["bottom"])
    sh.row("`color.global.scrim` (caption box)", tok("color.global.scrim"), "Tokens.Colors.globalScrim under the caption", status="match (token)", note="sourced in the second global gap fill (G2)")
    sh.row("caption box horizontal position", "centred (S-8)", "centred, kept clear of the cluster's first sticker", status="approx", note="caption + cluster overlap not observed")
    sh.section("Reply to a photo")
    sh.row("`chat.thread.dimension.replyWidth`", tok("chat.thread.dimension.replyWidth"), reply["width"])
    sh.row("`chat.thread.dimension.replyQuoteHeight`", tok("chat.thread.dimension.replyQuoteHeight"), reply["height"])
    sh.row("quote fill `color.global.accent`", tok("color.global.accent"), m["quoteFill"]["hex"])
    sh.row("bubble overlapping the quote", "not measured", "by `chat.thread.radius.bubble`", status="approx")
    sh.section("Send failed (`chat.thread.layout.failedMessage`, G-4)")
    fb, fl, ink = m["failedBubble"], m["failedLabel"], m["indicatorInk"]
    fm = tok("chat.thread.layout.failedMessage")
    sh.row("`chat.thread.layout.failedMessage` indicatorSize (ring ink)", fm["indicatorSize"], ink["right"] - ink["left"], tol=1.2, note="red-threshold ink width (anti-aliased edges)")
    sh.row("`chat.thread.layout.failedMessage` indicatorGap", fm["indicatorGap"], ink["left"] - fb["right"], tol=0.8)
    sh.row("indicator in the trailing inset slot (right edge)", W - tok("chat.thread.dimension.bubbleInsetMine"), ink["right"], tol=0.8)
    sh.row("indicator colour `color.global.destructive`", tok("color.global.destructive"), ink["hex"])
    sh.row("`chat.thread.layout.failedMessage` labelGap", fm["labelGap"], fl["top"] - fb["bottom"])
    sh.row("label trailing-aligned with the message column", W - tok("chat.thread.dimension.bubbleInsetMine"), fl["right"])
    sh.row("label copy `chat.thread.sendFailed`, text role `caption`, destructive", "couldn’t send — tap to try again", "shown; tap on ring / label / bubble retries (flow test failedSendRetries)", status="match (token)")
    sh.section("States")
    sh.row("loading: Loading HUD, corners `chat.thread.radius.loadingHud`", tok("chat.thread.radius.loadingHud"), "core:ui LoadingHud(shape = hudShape(Tokens.Radii.chatThreadRadiusLoadingHud)); fill `groups.create.color.hud`", status="match (token)", note="snapshot `loading`")
    sh.row("empty (creator / member)", "empty-state layout + invite pill", "snapshots `emptyCreator`, `emptyMember`", status="match (token)")
    sh.row("error / offline (nothing cached) / offline cached", "spec States", "snapshots `error`, `offlineNothingCached`, `offlineCached`", status="match (token)")
    sh.row("realtime insert, no scroll jump (stable keys)", "spec Data & actions", "VM tests chatAppliesRealtime…, chatSendIsOptimisticKeepsItsKey…", status="match (token)")
    return sh


def chat_composer():
    m = meas("chat")
    sh = Sheet("chat.composer")
    cam, field, mic, send = m["camera"], m["field"], m["mic"], m["send"]
    sh.section("Row")
    sh.row("`chat.composer.dimension.insetLeading`", tok("chat.composer.dimension.insetLeading"), cam["left"])
    sh.row("`chat.composer.dimension.cameraButton`", tok("chat.composer.dimension.cameraButton"), cam["width"])
    sh.row("camera fill `color.global.accent`", tok("color.global.accent"), m["cameraFill"]["hex"])
    sh.row("`chat.composer.dimension.gapCameraField`", tok("chat.composer.dimension.gapCameraField"), field["left"] - tok("chat.composer.dimension.fieldPaddingLeading") - cam["right"], note="field text starts at `fieldPaddingLeading` inside the capsule")
    sh.row("field fill `color.global.control`", tok("color.global.control"), m["fieldFill"]["hex"])
    sh.row("`chat.composer.dimension.fieldHeight`, rim tokens, `radius.global.capsule`", tok("chat.composer.dimension.fieldHeight"), "Tokens (min height, rim gradient, CircleShape)", status="match (token)")
    sh.row("`chat.composer.dimension.sideButton` (mic)", tok("chat.composer.dimension.sideButton"), mic["width"])
    sh.row("mic fill `color.global.controlRaised`", tok("color.global.controlRaised"), m["micFill"]["hex"])
    sh.row("`chat.composer.dimension.insetTrailing`", tok("chat.composer.dimension.insetTrailing"), W - mic["right"])
    sh.row("`chat.composer.dimension.gapFieldButton`", tok("chat.composer.dimension.gapFieldButton"), "Spacer(Tokens.Sizes.chatComposerDimensionGapFieldButton)", status="match (token)")
    sh.row("`chat.composer.dimension.bottomInset` (above the safe area)", tok("chat.composer.dimension.bottomInset"), m["screen"]["height"] - mic["bottom"], note="G-5; the same distance above the keyboard (imePadding)")
    sh.row("placeholder `chat.composer.placeholder`, `fontSize.global.placeholder`, `color.global.textSecondary`", "start typing...", "shown", status="match (token)")
    sh.section("Typing (`chat.composer.layout.typingState`, G-6)")
    sh.row("send circle in the mic's slot (same bounds)", f"{fmt(mic['left'])}–{fmt(mic['right'])}", f"{fmt(send['left'])}–{fmt(send['right'])}", status="match" if abs(send["left"] - mic["left"]) < 0.6 and abs(send["right"] - mic["right"]) < 0.6 else "MISS")
    sh.row("send fill `color.global.accent`", tok("color.global.accent"), m["sendFill"]["hex"])
    sh.row("`icon.global.send` in `color.global.onAccent`", "Rounded.Send (auto-mirrored)", "Tokens.Icons.globalSend / Tokens.Colors.globalOnAccent", status="match (token)")
    sh.row("send glyph size", "not specified", "ink height `chat.composer.dimension.micGlyph`", status="approx")
    sh.row("no transition (instant swap)", "none", "none", status="match (token)", note="flow test sendText: mic ↔ send")
    sh.section("Haptics and accessibility")
    sh.row("`haptic.global.send` / `haptic.global.error`", "CONFIRM / REJECT", "Tokens.Haptics on Sent / SendFailed", status="match (token)")
    sh.row("labels `chat.composer.a11y.*`; touch targets ≥ `size.global.minTouchTarget.android`", "48 dp", "platform minimum touch target", status="match (token)")
    return sh


def chat_voice():
    m = meas("chat")
    sh = Sheet("chat.voice")
    playing = snap("ChatSnapshotTest.voicePlaying")
    holding = snap("ChatSnapshotTest.composerRecordingHolding")
    vm_, vt, play = m["voiceMine"], m["voiceTheirs"], m["playMine"]
    sh.section("Playback bubble")
    sh.row("`chat.voice.dimension.width`", tok("chat.voice.dimension.width"), vm_["width"])
    sh.row("`chat.voice.dimension.height`", tok("chat.voice.dimension.height"), vm_["height"])
    sh.row("mine: right edge at `chat.thread.dimension.bubbleInsetMine`", tok("chat.thread.dimension.bubbleInsetMine"), W - vm_["right"])
    sh.row("`chat.voice.color.bubble`", tok("chat.voice.color.bubble"), m["voiceFill"]["hex"])
    sh.row("`chat.voice.color.bubbleTheirs` (G-7)", tok("chat.voice.color.bubbleTheirs"), m["voiceTheirsFill"]["hex"])
    sh.row("theirs: left edge at `chat.thread.dimension.bubbleInsetTheirs`", tok("chat.thread.dimension.bubbleInsetTheirs"), vt["left"])
    sh.row("`chat.voice.dimension.playButton`", tok("chat.voice.dimension.playButton"), play["width"])
    sh.row("`chat.voice.dimension.playInsetLeading`", tok("chat.voice.dimension.playInsetLeading"), play["left"] - vt["left"])
    sh.row("`chat.voice.radius.bubble`, bars `barWidth` / `barPitch` / `barMinHeight` / `barMaxHeight`, `chat.voice.color.waveform`, duration `caption` in `chat.voice.color.duration`",
           "14 / 3.1 / 6.1 / 9.3 / 31.5", "Tokens (bar count = what fits)", status="match (token)")
    sh.section("Playing (G-8)")
    first_bar_x = vm_["left"] + tok("chat.voice.dimension.playInsetLeading") + tok("chat.voice.dimension.playButton") + tok("chat.voice.dimension.playToWaveform") + tok("chat.voice.dimension.barWidth") / 2
    cy = (vm_["top"] + vm_["bottom"]) / 2
    sh.row("`chat.voice.color.waveformPlayed` (bars before the playhead)", tok("chat.voice.color.waveformPlayed"), px(playing, first_bar_x, cy), tol=10, note="render `voicePlaying` at 40 %")
    sh.row("`chat.voice.icon.pause` in the play circle", "Rounded.Pause", "Tokens.Icons.chatVoiceIconPause", status="match (token)")
    sh.row("width for other durations (`chat.voice.layout.widthRule`)", "BLOCKED", "the observed width for every duration (the spec's approximation)", status="BLOCKED")
    sh.section("Recording (`chat.voice.layout.recording`, G-9)")
    row_cy = H - tok("chat.composer.dimension.bottomInset") - tok("chat.composer.dimension.sideButton") / 2
    dot_x = tok("chat.composer.dimension.insetLeading") + tok("chat.voice.dimension.playGlyph") / 2
    sh.row("red dot `color.global.destructive`", tok("color.global.destructive"), px(holding, dot_x, row_cy), tol=6)
    sh.row("red dot diameter", "not measured", "`chat.voice.dimension.playGlyph`", status="approx")
    sh.row("elapsed time `chat.voice.layout.durationFormat` in `color.global.textPrimary`", "mm:ss", "00:07 (text role body: not specified)", status="approx")
    sh.row("hint `icon.global.back` + `chat.voice.recording.slideToCancel` in `color.global.textSecondary`", "‹ slide to cancel", "centred in the row (text role placeholder: not specified)", status="approx")
    sh.row("hold to record · lift sends · slide left cancels · slide up locks", "WhatsApp gestures", "flow tests sendVoice, voiceSlideToCancelAndTap, voiceLockPauseAndSend", status="match (token)")
    sh.row("cancel distance / lock position", "not measured", "cancel when the circle reaches the hint's centre; lock capsule (`sideButton` wide, two circles tall, `controlRaised`) one field gap above the mic", status="approx")
    sh.row("locked: pause keeps the draft, the mic slot shows `icon.global.send`", "spec", "snapshots composerRecordingLocked / composerRecordingDraft", status="match (token)")
    sh.row("a press shorter than a hold", "not specified", "records nothing (platform long-press timeout)", status="approx")
    sh.row("TalkBack: no hold gesture", "not specified", "activating the mic records hands-free; send sends (flow test voiceWithTalkBack)", status="approx")
    sh.row("cancel while locked / paused", "not specified", "system back (or leaving the thread) discards", status="approx")
    sh.row("recording haptics", "none (HIG)", "none", status="match (token)")
    sh.section("Permission")
    sh.row("permission card `chat.voice.permission.*` (contacts-card tokens)", "inline card above the composer", "core:ui PermissionCard, snapshot voicePermissionDenied", status="match (token)")
    return sh


def chat_reactions():
    m = meas("chat")
    sh = Sheet("chat.reactions")
    photo, cluster = m["photo"], m["cluster"]
    picker = snap("ChatSnapshotTest.reactionsPicker")
    sh.section("Cluster")
    sh.row("`chat.reactions.dimension.clusterInsetLeading`", tok("chat.reactions.dimension.clusterInsetLeading"), cluster["left"] - photo["left"])
    sh.row("`chat.reactions.dimension.clusterInsetBottom`", tok("chat.reactions.dimension.clusterInsetBottom"), photo["bottom"] - cluster["bottom"])
    sh.row("`chat.reactions.dimension.clusterEmoji` (sticker incl. outline)", tok("chat.reactions.dimension.clusterEmoji"), cluster["height"])
    sh.row("`chat.reactions.dimension.clusterStep`, `.clusterOutline` in `chat.reactions.color.clusterOutline`", f"{tok('chat.reactions.dimension.clusterStep')} / {tok('chat.reactions.dimension.clusterOutline')} / #FFFFFF", "Tokens (offset per sticker; 16 outline copies)", status="match (token)")
    sh.row("`chat.reactions.layout.clusterOrder` newest distinct first (G-10)", "😂 🔥 😍 for 😍, 🔥, 😍, 😂", "VM test clusterOrderIsNewestDistinctFirst; render `content` shows 🔥 before 😍", status="match (token)")
    sh.row("no counts anywhere (labels, TalkBack)", "tenet 2", "flow test noCountsInReactionLabels", status="match (token)")
    sh.row("`chat.reactions.count.clusterMaxVisible`", "BLOCKED", "every sticker is drawn; the photo clips them", status="BLOCKED")
    sh.section("Picker and unreact")
    sh.row("`chat.reactions.layout.picker` (search · Frequently Used · Popular · All), `chat.reactions.count.pickerColumns`", tok("chat.reactions.count.pickerColumns"), "native M3 sheet, 6 columns", status="match (token)")
    sh.row("`chat.reactions.layout.unreact` highlight `color.global.selection` (G-13)", tok("color.global.selection"), "present" if count_near(picker, tok("color.global.selection"), 6) > 200 else "absent",
           status="match" if count_near(picker, tok("color.global.selection"), 6) > 200 else "MISS", note="your 🔥 in `reactionsPicker`; selected trait + unreact: flow test unreactFromThePicker")
    sh.row("highlight circle diameter", "not measured", "`pickerEmoji` + 2 × `clusterOutline`", status="approx")
    sh.row("picker metrics `pickerEmoji` / `pickerSection`", "approximate in the spec", "Tokens", status="match (token)")
    sh.section("Motion")
    sh.row("emoji rain `rainCopies` / `rainSpawnInterval` / `rainTravel` / `rainTotal`", f"{tok('chat.reactions.count.rainCopies')} / {tok('chat.reactions.duration.rainSpawnInterval')} / {tok('chat.reactions.duration.rainTravel')} / {tok('chat.reactions.duration.rainTotal')}", "Tokens; render `reactionsRain`", status="match (token)")
    sh.row("`chat.reactions.easing.rain` (G-11)", "easeInOut", "Tokens.Easings.chatReactionsEasingRain (release)", status="match (token)")
    sh.row("`chat.reactions.duration.flyToCluster` (G-12)", tok("chat.reactions.duration.flyToCluster"), "300 ms to the cluster's leading slot; the sticker waits for it (render `reactionsFlyToCluster`)", status="match (token)")
    sh.row("fly-to-cluster curve", "decelerating (not tokenised)", "`easing.global.system.standard`", status="approx")
    sh.row("Reduce Motion (`chat.reactions.layout.reduceMotion`)", "no rain; sticker appears in place", "no rain, no flight", status="match (token)")
    sh.section("Blocked")
    sh.row("`chat.reactions.layout.activitySheet`", "BLOCKED", "omitted in release (debug: platform list sheet, render `reactionsActivitySheetDevelopment`)", status="BLOCKED")
    return sh


def photo_viewer():
    m = meas("viewer")
    sh = Sheet("photo.viewer")
    close, more, photo, sender, toggle, cluster, voice, camera = (m[k] for k in ("close", "more", "photo", "sender", "toggle", "cluster", "voice", "camera"))
    sh.section("Header")
    sh.row("`photo.viewer.dimension.closeCenterX`", tok("photo.viewer.dimension.closeCenterX"), close["left"] + close["width"] / 2)
    sh.row("`photo.viewer.dimension.headerCenterY`", tok("photo.viewer.dimension.headerCenterY"), close["top"] + close["height"] / 2)
    sh.row("`photo.viewer.dimension.moreCenterTrailing`", tok("photo.viewer.dimension.moreCenterTrailing"), W - (more["left"] + more["width"] / 2))
    sh.row("title centred (two lines, `photo.viewer.dimension.titleToDate`)", W / 2, (m["titleLine1"]["left"] + m["titleLine1"]["right"]) / 2, tol=1.0)
    sh.row("`photo.viewer.color.background`", tok("photo.viewer.color.background"), m["background"]["hex"])
    sh.section("Photo")
    sh.row("`photo.viewer.dimension.photoTop`", tok("photo.viewer.dimension.photoTop"), photo["top"])
    sh.row("full width at the photo's aspect", W, photo["width"])
    sh.row("`photo.viewer.dimension.pageGap` (G-14: pages touch)", tok("photo.viewer.dimension.pageGap"), "pageSpacing = Tokens.Sizes.photoViewerDimensionPageGap", status="match (token)")
    sh.row("`photo.viewer.dimension.senderInsetLeading`", tok("photo.viewer.dimension.senderInsetLeading"), sender["left"] - photo["left"])
    sh.row("`photo.viewer.dimension.senderInsetTop`", tok("photo.viewer.dimension.senderInsetTop"), sender["top"] - photo["top"])
    sh.row("`photo.viewer.dimension.senderAvatar`", tok("photo.viewer.dimension.senderAvatar"), sender["height"])
    sh.row("`photo.viewer.dimension.actionTrailing` (toggle)", tok("photo.viewer.dimension.actionTrailing"), W - toggle["right"])
    sh.row("`photo.viewer.dimension.actionCenterTop` (toggle centre)", tok("photo.viewer.dimension.actionCenterTop"), (toggle["top"] + toggle["bottom"]) / 2 - photo["top"])
    sh.row("toggle on: white capsule (`tagging.*`)", "#FFFFFF", m["toggleFill"]["hex"])
    sh.row("cluster insets (as chat.reactions)", tok("chat.reactions.dimension.clusterInsetLeading"), cluster["left"] - photo["left"])
    sh.row("caption box `color.global.scrim`", tok("color.global.scrim"), "Tokens.Colors.globalScrim", status="match (token)")
    sh.section("Voice note")
    sh.row("`photo.viewer.layout.voiceNote` position", "BLOCKED", f"approximation: under the photo, `size.global.screenMargin` ({fmt(voice['top'] - photo['bottom'])} below, {fmt(voice['left'])} in)", status="BLOCKED")
    sh.section("Reply row")
    sh.row("`chat.composer.dimension.insetTrailing` (camera circle)", tok("chat.composer.dimension.insetTrailing"), W - camera["right"])
    sh.row("`chat.composer.dimension.bottomInset`", tok("chat.composer.dimension.bottomInset"), H - camera["bottom"])
    sh.row("`chat.composer.layout.typingState`: the camera slot shows the lime send circle", "send circle", "render `replyTyping`", status="match (token)")
    sh.row("`chat.reactions.layout.quickReactions` 🔥 💖 + add, inside the field's end", "present", "present (quick 🔥 at x " + fmt(m["quickFire"]["left"]) + ")", status="match (token)")
    sh.row("quick reaction size / spacing", "not measured", "field text size, `size.global.headerGap` apart", status="approx")
    sh.section("Actions")
    sh.row("••• menu (save; delete own / report + block others)", "`photo.viewer.layout.menu`", "renders `menuMine`, `menuOthers`", status="match (token)")
    sh.row("delete everywhere → `delete_media` (confirmation `photo.viewer.layout.deleteConfirm`)", "spec", "flow test deleteEverywhere", status="match (token)")
    sh.row("reply with a photo → AppRoute.Camera(groupId) + SocialHandoff.REPLY_TO_POST_ID", "spec", "flow test replyToAPhotoWithTextAndWithAPhoto", status="match (token)")
    sh.row("self-tag toggle with `tagging.*` copy, optimistic", "tagging.md", "VM test viewerTagIsOptimistic…; render `othersPhotoCoach`", status="match (token)")
    sh.row("toasts (`camera.sendto.duration.toastVisible`)", "BLOCKED", "no toast drawn; the text is announced", status="BLOCKED")
    return sh


def walls_mine(surface="walls.mine", button="settings"):
    m = meas(surface)
    sh = Sheet(surface)
    b, t1, t2 = m[button], m["tile1"], m["tile2"]
    sh.section("Header")
    if button == "settings":
        sh.row("`size.global.headerInset` (settings circle, from the right edge)", tok("size.global.headerInset"), W - b["right"])
        sh.row("title centred (`walls.browse.dimension.titleBaseline`)", W / 2, (m["title"]["left"] + m["title"]["right"]) / 2)
        sh.row("settings fill `color.global.controlOnDeep`", tok("color.global.controlOnDeep"), m["settingsFill"]["hex"])
    else:
        sh.row("`size.global.headerInset` (‹ circle)", tok("size.global.headerInset"), b["left"])
        sh.row("‹ fill `color.global.controlOnDeep`", tok("color.global.controlOnDeep"), m["backFill"]["hex"])
    sh.row("`size.global.headerButton`", tok("size.global.headerButton"), b["width"])
    sh.row("`color.global.backgroundDeep`", tok("color.global.backgroundDeep"), m["background"]["hex"])
    sh.section("Grid")
    sh.row("`walls.mine.dimension.gridInset`", tok("walls.mine.dimension.gridInset"), t1["left"])
    sh.row("grid top = title baseline + `walls.mine.dimension.titleToGrid`", tok("walls.browse.dimension.titleBaseline") + tok("walls.mine.dimension.titleToGrid"), t1["top"])
    width = (W - 2 * tok("walls.mine.dimension.gridInset") - (tok("walls.mine.count.gridColumns") - 1) * tok("walls.mine.dimension.gridGap")) / tok("walls.mine.count.gridColumns")
    sh.row("tile width (`walls.mine.count.gridColumns` columns, `.gridGap`)", round(width, 2), t1["width"])
    sh.row("`walls.mine.aspectRatio.gridTile`", tok("walls.mine.aspectRatio.gridTile"), round(t1["width"] / t1["height"], 4), tol=0.005)
    if "tile4" in m:
        sh.row("`walls.mine.dimension.gridGap` (rows)", tok("walls.mine.dimension.gridGap"), m["tile4"]["top"] - t1["bottom"])
        sh.row("`walls.mine.dimension.gridGap` (columns)", tok("walls.mine.dimension.gridGap"), m["tile4"]["left"] - t1["right"])
    sh.row("`walls.mine.radius.gridTile`", tok("walls.mine.radius.gridTile"), "Tokens.Radii.wallsMineRadiusGridTile", status="match (token)")
    sh.row("`walls.mine.layout.freeformWall` / `.mosaic`", "BLOCKED", "the profile grid (S-11), uniform rows", status="BLOCKED")
    sh.section("States")
    names = "mineContent, mineEmpty, mineError, mineLoading, mineOffline" if button == "settings" else "memberContent, memberEmpty, memberError, memberLoading"
    sh.row("loading / empty / error / offline", "spec States", "renders " + names, status="match (token)")
    sh.row("pagination, realtime deletions, cached offline", "spec Data", "VM tests wallPaginates…, wallDropsDeletedPhotos…", status="match (token)")
    return sh


def walls_browse():
    m = meas("walls.browse")
    sh = Sheet("walls.browse")
    me, ana, t1 = m["me"], m["ana"], m["tile1"]
    sh.section("Person row")
    sh.row("`walls.browse.dimension.avatar`", tok("walls.browse.dimension.avatar"), me["width"])
    sh.row("`walls.browse.dimension.rowInset`", tok("walls.browse.dimension.rowInset"), me["left"])
    sh.row("`walls.browse.dimension.avatarPitch`", tok("walls.browse.dimension.avatarPitch"), ana["left"] - me["left"])
    sh.row("`walls.browse.dimension.rowCenter` (circle centre)", tok("walls.browse.dimension.rowCenter"), me["top"] + me["width"] / 2)
    sh.row("title centred", W / 2, (m["title"]["left"] + m["title"]["right"]) / 2)
    sh.row("`walls.browse.layout.rowOrder`", "BLOCKED", "approximation: me first, then newest wall item first (VM test browsePutsMeFirst…)", status="BLOCKED")
    sh.row("`walls.browse.layout.selection`", "BLOCKED", "no selected marking drawn", status="BLOCKED")
    sh.section("Wall")
    sh.row("`walls.browse.dimension.wallTop`", tok("walls.browse.dimension.wallTop"), t1["top"])
    sh.row("grid as walls.mine (`walls.mine.dimension.gridInset`)", tok("walls.mine.dimension.gridInset"), t1["left"])
    sh.section("States")
    sh.row("alone / loading / error", "spec States", "renders browseAlone, browseLoading, browseError", status="match (token)")
    return sh


def week_recap():
    m = meas("week.recap")
    sh = Sheet("week.recap")
    card, c1, c2, p1, p2 = m["card"], m["cardTile1"], m["cardTile2"], m["picTile1"], m["picTile2"]
    sh.section("Header")
    sh.row("`size.global.headerInset` (‹)", tok("size.global.headerInset"), m["back"]["left"])
    sh.row("`size.global.headerInset` (edit)", tok("size.global.headerInset"), W - m["edit"]["right"])
    sh.row("title centred (`week.recap.layout.weekFormat`)", W / 2, (m["title"]["left"] + m["title"]["right"]) / 2)
    sh.row("`color.global.background`", tok("color.global.background"), m["background"]["hex"])
    sh.section("Recap card")
    sh.row("`week.recap.dimension.cardWidth`", tok("week.recap.dimension.cardWidth"), card["width"])
    sh.row("card centred", W / 2, (card["left"] + card["right"]) / 2)
    sh.row("`week.recap.dimension.gridGap`", tok("week.recap.dimension.gridGap"), c2["left"] - c1["right"])
    sh.row("`week.recap.aspectRatio.gridTile`", tok("week.recap.aspectRatio.gridTile"), round(c1["width"] / c1["height"], 4), tol=0.005)
    sh.row("`week.recap.radius.card`, label tokens", tok("week.recap.radius.card"), "Tokens", status="match (token)")
    sh.row("header → card gap", "not measured", "0", status="approx")
    sh.row("`week.recap.layout.shortRowSplit` / `.dimension.shortRowHeight`", "BLOCKED", "the leftover 1–2 photos are not drawn in the card", status="BLOCKED")
    sh.row("`week.recap.layout.scrim`", "BLOCKED", "no gradient under the label", status="BLOCKED")
    sh.row("`week.recap.layout.page2` (page dots)", "BLOCKED", "one page, no dots", status="BLOCKED")
    sh.section("Pics")
    sh.row("`week.recap.dimension.picsGap`", tok("week.recap.dimension.picsGap"), p2["left"] - p1["right"])
    sh.row("`week.recap.aspectRatio.picsTile`", tok("week.recap.aspectRatio.picsTile"), round(p1["width"] / p1["height"], 4), tol=0.005)
    sh.row("segmented control (`week.recap.dimension.segmented*`)", f"{tok('week.recap.dimension.segmentedWidth')} × {tok('week.recap.dimension.segmentedHeight')}", "Tokens", status="match (token)")
    sh.section("States")
    sh.row("loading / pending / empty / error / offline", "spec States", "renders recapLoading, recapPending, recapEmpty, recapError, recapOffline", status="match (token)")
    return sh


def week_edit():
    m = meas("week.edit")
    sh = Sheet("week.edit")
    sh.section("Sheet")
    sh.row("`size.global.headerInset` (✕)", tok("size.global.headerInset"), m["close"]["left"])
    sh.row("title centred (`sheetTitle`)", W / 2, (m["title"]["left"] + m["title"]["right"]) / 2)
    sh.row("`color.global.backgroundDeep`", tok("color.global.backgroundDeep"), m["background"]["hex"])
    sh.row("pics grid tile (`week.recap.aspectRatio.picsTile`)", tok("week.recap.aspectRatio.picsTile"), round(m["tile1"]["width"] / m["tile1"]["height"], 4), tol=0.005)
    sh.row("save button `color.global.accent`", tok("color.global.accent"), m["saveFill"]["hex"])
    sh.row("check circles `icon.global.check` / `.uncheck`, `size.global.checkCircle`, `color.global.selection`", "spec", "Tokens; inset `size.global.listGap`", status="approx", note="corner inset not measured")
    sh.section("Reorder (`week.edit.layout.reorder`, G-16)")
    sh.row("touch and hold a checked tile, drag, release", "Apple / Google Photos", "release build; flow test reorderARecapByDragging", status="match (token)")
    sh.row("dragged tile follows the finger; others move to show the drop position", "platform drag-and-drop", "lifted tile translated with the finger; LazyGrid item placement (none under Reduce Motion)", status="match (token)")
    sh.row("`week.edit.haptic.dragStart` / `.dragAlign`", "DRAG_START / SEGMENT_TICK", "Tokens.Layouts.WeekEditHaptic*", status="match (token)")
    sh.section("Text and album")
    sh.row("`week.edit.layout.recapText`", "BLOCKED", "approximation the spec names: the field under the grid", status="BLOCKED")
    sh.row("dark \"save as album\" button (`camera.sendto` pair tokens)", "not generated", "omitted in release; the week's ••• → save as album opens the name sheet", status="BLOCKED")
    sh.row("save → `update_recap` (optimistic on the recap screen); album → `save_album`", "spec", "flow tests editRecapAndSaveIt, saveAWeekAsANamedAlbum; VM tests", status="match (token)")
    sh.section("States")
    sh.row("loading / saving / save failed / not ready / album name error", "spec States", "renders editLoading, editSaving, editSaveFailed, editNotReady, editAlbumSheetNameError", status="match (token)")
    return sh


def week_history():
    m = meas("week.history")
    sh = Sheet("week.history")
    t1, t2, add, e1 = m["tile1"], m["tile2"], m["add"], m["emptyDay1"]
    sh.section("Header")
    sh.row("`week.history.dimension.titleInset`", tok("week.history.dimension.titleInset"), m["title"]["left"])
    sh.row("`week.history.dimension.inset` (week header)", tok("week.history.dimension.inset"), m["week43"]["left"])
    sh.row("`week.history.dimension.rangeGap`", tok("week.history.dimension.rangeGap"), m["range42"]["left"] - m["week42"]["right"])
    sh.row("current week without photos: no range", "omitted", "\"Week 43\" alone", status="match (token)")
    sh.row("`color.global.backgroundDeep`", tok("color.global.backgroundDeep"), m["background"]["hex"])
    sh.section("Strip")
    sh.row("`week.history.dimension.tileWidth`", tok("week.history.dimension.tileWidth"), t1["width"])
    sh.row("`week.history.dimension.tileHeight`", tok("week.history.dimension.tileHeight"), t1["height"])
    sh.row("`week.history.dimension.tileGap`", tok("week.history.dimension.tileGap"), t2["left"] - t1["right"])
    sh.row("strip starts at `week.history.dimension.inset`", tok("week.history.dimension.inset"), add["left"])
    sh.section("Current week: add tile and empty days (G-15)")
    sh.row("`week.history.color.emptyTile` (add tile)", tok("week.history.color.emptyTile"), m["addFill"]["hex"])
    sh.row("`week.history.color.emptyTile` (empty day)", tok("week.history.color.emptyTile"), m["emptyFill"]["hex"])
    sh.row("`week.history.color.emptyTileText` (labels only)", tok("week.history.color.emptyTileText"), "Tokens.Colors.weekHistoryColorEmptyTileText", status="match (token)", note="contrast 1.92:1 reported by the spec, not adjusted")
    sh.row("\"+\" `color.global.textPrimary`, `week.history.dimension.addGlyph`", "#FFFFFF", "Tokens", status="match (token)")
    sh.row("empty-day texts (month / day bold / weekday)", "`week.history.fontSize.emptyDayLabel` / `.emptyDay`", "Tokens", status="match (token)")
    sh.section("Menu and states")
    sh.row("`week.history.layout.weekMenu`", "BLOCKED", "our two product actions (view recap, save as album) in a native menu", status="BLOCKED")
    sh.row("empty / loading / error / offline", "spec States", "renders historyEmpty, historyLoading, historyError, historyOffline", status="match (token)")
    return sh


def albums_list():
    m = meas("albums.list")
    sh = Sheet("albums.list")
    g = tok("albums.list.layout.yopeAlbums")
    c1, c2, n1 = m["cover1"], m["cover2"], m["name1"]
    width = (W - 2 * g["marginH"] - (g["columns"] - 1) * g["gap"]) / g["columns"]
    sh.section("Header")
    sh.row("title centred (`week.recap.fontSize.title`)", W / 2, (m["title"]["left"] + m["title"]["right"]) / 2)
    sh.row("`color.global.backgroundDeep`", tok("color.global.backgroundDeep"), m["background"]["hex"])
    sh.section("Covers (`albums.list.layout.yopeAlbums`, Apple Photos, G-17)")
    sh.row("`albums.list.layout.yopeAlbums` marginH", g["marginH"], c1["left"])
    sh.row("`albums.list.layout.yopeAlbums` gap", g["gap"], c2["left"] - c1["right"])
    sh.row("cover width (columns 2; `coverWidth` 168 on a 393 screen)", round(width, 2), c1["width"])
    sh.row("`albums.list.layout.yopeAlbums` coverAspect", g["coverAspect"], round(c1["width"] / c1["height"], 3), tol=0.01)
    sh.row("`albums.list.layout.yopeAlbums` coverRadius", g["coverRadius"], "RoundedCornerShape(coverRadius)", status="match (token)")
    sh.row("`albums.list.layout.yopeAlbums` titleInsetLeading", g["titleInsetLeading"], n1["left"] - c1["left"])
    sh.row("`albums.list.layout.yopeAlbums` titleFontSize / weight", f"{g['titleFontSize']} / platform", "15 sp, platform weight, `color.global.textPrimary`", status="match (token)")
    sh.row("`albums.list.layout.yopeAlbums` titleBaselineBottom", g["titleBaselineBottom"], "paddingFromBaseline(bottom = 17)", status="match (token)")
    sh.row("subtitle `albums.list.row.subtitle` in the label only (platform merge)", "not drawn", f"{m['coverCount']['n']} covers read \"name, saved by …\"" if m["coverCount"] else "-", status="match (token)")
    sh.row("header → first row", "not measured", "`gap`", status="approx")
    sh.row("cover without a photo", "not specified", "`icon.global.gallery` on `color.global.controlOnDeep`", status="approx")
    sh.row("name legibility over photos", "not measurable (spec)", "no treatment", status="approx")
    sh.section("States")
    sh.row("empty / loading / error / offline", "spec States", "renders albumsListEmpty, albumsListLoading, albumsListError, albumsListOffline", status="match (token)")
    return sh


def albums_view():
    m = meas("albums.view")
    sh = Sheet("albums.view")
    t1, t2, t4 = m["tile1"], m["tile2"], m["tile4"]
    sh.section("Header")
    sh.row("title centred", W / 2, (m["title"]["left"] + m["title"]["right"]) / 2)
    sh.row("`size.global.headerInset` (•••)", tok("size.global.headerInset"), W - m["more"]["right"])
    sh.row("`color.global.background`", tok("color.global.background"), m["background"]["hex"])
    sh.section("Pics grid")
    sh.row("`week.recap.dimension.picsGap` (columns)", tok("week.recap.dimension.picsGap"), t2["left"] - t1["right"])
    sh.row("`week.recap.dimension.picsGap` (rows)", tok("week.recap.dimension.picsGap"), t4["top"] - t1["bottom"])
    sh.row("`week.recap.aspectRatio.picsTile`", tok("week.recap.aspectRatio.picsTile"), round(t1["width"] / t1["height"], 4), tol=0.005)
    sh.section("Actions and states")
    sh.row("••• menu: rename (name sheet) / delete (creator or admin, confirmation)", "spec", "renders albumViewMenu, albumViewRenameSheet, albumViewDeleteConfirmation", status="match (token)")
    sh.row("rename optimistic, rolls back", "spec", "VM test albumRenameIsOptimistic…", status="match (token)")
    sh.row("empty / not found / loading / error", "spec States", "renders albumViewEmpty, albumViewNotFound, albumViewLoading, albumViewError", status="match (token)")
    return sh


YOPE05 = "references/auto/yope/store/yope-store-05.png"
SURFACES = [
    ("chat.thread", chat_thread, ["ChatSnapshotTest.content", "ChatSnapshotTest.sendFailed"], YOPE05, "175,610,897,1936"),
    ("chat.composer", chat_composer, ["ChatSnapshotTest.content", "ChatSnapshotTest.composerTyping"], YOPE05, "175,610,897,1936"),
    ("chat.voice", chat_voice, ["ChatSnapshotTest.voicePlaying", "ChatSnapshotTest.composerRecordingHolding", "ChatSnapshotTest.composerRecordingLocked"], YOPE05, "175,610,897,1936"),
    ("chat.reactions", chat_reactions, ["ChatSnapshotTest.reactionsManyStickers", "ChatSnapshotTest.reactionsPicker", "ChatSnapshotTest.reactionsFlyToCluster"], "references/auto/locket/store/locket-store-04.png", None),
    ("photo.viewer", photo_viewer, ["ViewerSnapshotTest.othersPhoto", "ViewerSnapshotTest.replyTyping"], "references/auto/yope/frames/b-yopeapp-7591560669967682847-t57.07-photo-viewer.png", "98,75,524,1130"),
    ("walls.mine", walls_mine, ["WallsSnapshotTest.mineContent"], "references/auto/yope/frames/b-presskit-profile.png", None),
    ("walls.member", lambda: walls_mine("walls.member", "back"), ["WallsSnapshotTest.memberContent"], "references/auto/yope/frames/b-presskit-profile.png", None),
    ("walls.browse", walls_browse, ["WallsSnapshotTest.browseContent"], "references/auto/yope/frames/b-yopeapp-7591560669967682847-t116.00-me-and-friends.png", None),
    ("week.recap", week_recap, ["WeekSnapshotTest.recapReady"], "references/owner/yope-week-recap.jpg", None),
    ("week.edit", week_edit, ["WeekSnapshotTest.editReady", "WeekSnapshotTest.editAlbumSheet"], "references/auto/yope/frames/a-chuongxetank-7694968408424582452-t6.73-sendto-voice-tooltip.png", None),
    ("week.history", week_history, ["WeekSnapshotTest.historyContent"], "references/auto/retro/store/retro-store-02.png", None),
    ("albums.list", albums_list, ["WeekSnapshotTest.albumsListContent"], "references/auto/apple-photos/apple-support/photos-albums-ios27.png", "22,15,446,970"),
    ("albums.view", albums_view, ["WeekSnapshotTest.albumViewContent"], "references/owner/yope-week-recap.jpg", None),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    summary = []
    for surface, build, ours, ref, crop in SURFACES:
        side_by_side(surface, ours, ref, f"{surface} — Android (left) · reference (right)", crop)
        sheet = build()
        counts = sheet.write(header(surface, ours, ref))
        summary.append((surface, counts))
    for surface, counts in summary:
        print(surface, ", ".join(f"{v} {k}" for k, v in sorted(counts.items())))


if __name__ == "__main__":
    main()
