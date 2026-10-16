#!/usr/bin/env python3
"""Verification of the Android account screens (docs/SCREENS_BRIEF.md rule 8; Pass 4, Retro redesign).

Inputs:
  android/feature/account/src/test/snapshots/<surface>/<state>-<light|dark>.png  our renders (ScreenSnapshotTest,
      `./gradlew :feature:account:recordRoborazziDebug`; 393 x 852 dp at 2 px/dp, no system-bar insets)
  design/surfaces/<surface>.md, design/tokens/*.json, design/copy/*.json      the spec, its tokens and copy
  android/core/designsystem/.../generated/Tokens.kt                          token -> Kotlin accessor
Outputs:
  design/verification/<surface>.android.png  ours (light, dark) | Retro reference(s) (tools/sidebyside.py)
  design/verification/<surface>.android.md   token -> reference value -> what our screen shows -> status
(".android" keeps them apart from the iOS pass's <surface>.md / .png.)

Rows:
  * measured   - pixel measurements on our snapshot (measure.py), compared with the token value:
                 "match" within tolerance, "MISS" outside it.
  * every token the spec names - "match (token)" when the account screens / core:ui reference its
                 generated accessor (the value goes into the component unchanged); otherwise the reviewed
                 note in NOTES says how the spec item is met ("match (behaviour)" for a descriptive layout
                 or platform token implemented as written, "approx", "n/a" for another platform or another
                 pass's surface, "BLOCKED" for an omitted value, "MISS" for a gap).
  * every copy key the spec names - "match (copy)" when R.string.<key> is used; BLOCKED copy ({app_name})
                 is debug-only (BlockedCopy); other cases from NOTES.
Run from the repo root: python3 -I android/feature/account/verification/checklists.py [surface ...]
"""
import glob
import json
import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True  # no __pycache__ next to the sources
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import measure as M  # noqa: E402
from notes import COPY_NOTES, NOTES  # noqa: E402
from surfaces import SURFACES  # noqa: E402

ROOT = M.ROOT
OUT = os.path.join(ROOT, "design", "verification")

TOKENS, COPY = {}, {}
for name in ("global", "capture", "account", "social", "memory", "invite"):
    with open(os.path.join(ROOT, "design", "tokens", name + ".json")) as f:
        TOKENS.update(json.load(f)["tokens"])
for name in ("account", "capture", "social", "memory", "invite"):
    with open(os.path.join(ROOT, "design", "copy", name + ".json")) as f:
        COPY.update(json.load(f)["strings"])

with open(os.path.join(ROOT, "android", "core", "designsystem", "src", "main", "kotlin", "app", "designsystem", "generated", "Tokens.kt")) as f:
    _gen = f.read()
ACCESSOR = {m.group(1): m.group(2) for m in re.finditer(r"token `([^`]+)`[^\n]*\*/\s*\n\s*(?:const )?(?:val|object) (\w+)", _gen)}

CODE_DIRS = ["android/feature/account/src/main", "android/feature/account/src/debug", "android/core/ui/src/main", "android/app/src/main"]
CODE = ""
for d in CODE_DIRS:
    for p in glob.glob(os.path.join(ROOT, d, "**", "*.kt"), recursive=True):
        with open(p) as f:
            CODE += f.read() + "\n"
with open(os.path.join(ROOT, "android", "feature", "account", "src", "debug", "kotlin", "app", "feature", "account", "blocked", "BlockedCopy.kt")) as f:
    BLOCKED_COPY = f.read()


def res_name(key):
    return re.sub(r"[^a-z0-9_]", "_", key.lower().replace(".", "_"))


def token_used(key):
    a = ACCESSOR.get(key)
    return bool(a) and re.search(r"\b" + re.escape(a) + r"\b", CODE) is not None


def copy_used(key):
    return re.search(r"R\.string\." + res_name(key) + r"\b", CODE) is not None


def fmt_value(t):
    v = t.get("value")
    if v is None:
        return "BLOCKED"
    if isinstance(v, dict):
        if "android" in v:
            v = v["android"]
        else:
            v = "; ".join(f"{k}: {x}" for k, x in v.items())
    s = str(v)
    unit = t.get("unit")
    if unit and isinstance(t.get("value"), (int, float)):
        s += " " + unit
    return clip(s, 90)


def clip(s, n):
    s = str(s).replace("|", "/").replace("\n", " ")
    return s if len(s) <= n else s[: n - 1] + "…"


def evidence(key):
    return clip(TOKENS.get(key, {}).get("evidence") or "", 80)


class Sheet:
    def __init__(self, surface):
        self.surface, self.sections, self.counts = surface, [], {}

    def section(self, name):
        self.sections.append((name, []))

    def add(self, status, token, expected, ours, ref="", note=""):
        key = status.split(" ")[0]
        self.counts[key] = self.counts.get(key, 0) + 1
        self.sections[-1][1].append((status, token, str(expected), str(ours), ref, note))

    def measured(self, label, token, expected, ours, tol=0.75, note="", unit="", status=None):
        if status is not None:
            ok = None
        elif isinstance(expected, str) and isinstance(ours, str) and expected.startswith("#") and ours.startswith("#"):
            ok = M.near(expected[:7], tol if tol > 1 else 8)(M.rgb(ours))
        elif isinstance(expected, str) or isinstance(ours, str):
            ok = str(expected) == str(ours)
        elif ours is None:
            ok = False
        else:
            ok = abs(float(expected) - float(ours)) <= tol
        show = (lambda v: f"{v:.2f}".rstrip("0").rstrip(".") + unit if isinstance(v, float) else f"{v}{unit}")
        tok = f"`{token}`" if token in TOKENS else token
        verdict = status or ("match" if ok else "MISS")
        self.add(verdict, f"{label}: {tok}" if label else tok, show(expected), "—" if ours is None else show(ours), evidence(token), note)


def token_rows(sheet, surface, spec, measured_tokens):
    keys = list(dict.fromkeys(k for k in re.findall(r"`([A-Za-z0-9_.\-]+)`", spec) if k in TOKENS))
    sheet.section("Tokens named in the spec")
    for k in keys:
        t = TOKENS[k]
        level = t.get("level")
        note = NOTES.get((surface, k)) or NOTES.get(("*", k))
        expected = fmt_value(t)
        if level == "BLOCKED":
            sheet.add("BLOCKED", f"`{k}`", "BLOCKED", note[1] if note else "omitted in release", "", note[2] if note and len(note) > 2 else "")
        elif note and note[0] != "match (token)":
            sheet.add(note[0], f"`{k}`", expected, note[1], evidence(k), note[2] if len(note) > 2 else "")
        elif token_used(k):
            ours = f"Tokens.{_kind(k)}.{ACCESSOR[k]}" if ACCESSOR.get(k) and ACCESSOR[k][0].islower() else f"Tokens.Layouts.{ACCESSOR.get(k)}"
            extra = " · measured above" if k in measured_tokens else ""
            sheet.add("match (token)", f"`{k}`", expected, ours + extra, evidence(k), note[1] if note else "")
        else:
            sheet.add("UNREVIEWED", f"`{k}`", expected, "not referenced", evidence(k), "")
    return keys


def _kind(key):
    m = re.search(r"\b(?:val|object) " + re.escape(ACCESSOR[key]) + r"\b", _gen)
    obj = None
    for o in re.finditer(r"\n    object (\w+)", _gen):
        if o.start() < m.start():
            obj = o.group(1)
    return obj or "?"


def copy_rows(sheet, surface, spec):
    keys = list(dict.fromkeys(k for k in re.findall(r"`([A-Za-z0-9_.\-]+)`", spec) if k in COPY))
    if not keys:
        return
    sheet.section("Copy named in the spec")
    for k in keys:
        c = COPY[k]
        text = clip(c.get("text") or "BLOCKED", 60)
        note = COPY_NOTES.get((surface, k)) or COPY_NOTES.get(("*", k))
        if "{app_name}" in (c.get("text") or ""):
            sheet.add("BLOCKED", f"`{k}`", text, "debug only (BlockedCopy); omitted in release until `app_name` is set", "", "{app_name}")
        elif note:
            sheet.add(note[0], f"`{k}`", text, note[1], "", note[2] if len(note) > 2 else "")
        elif copy_used(k):
            sheet.add("match (copy)", f"`{k}`", text, f"R.string.{res_name(k)}", "", "")
        else:
            sheet.add("UNREVIEWED", f"`{k}`", text, "not referenced", "", "")


def states_section(surface):
    d = os.path.join(M.SNAP, surface)
    return sorted(os.path.splitext(p)[0] for p in os.listdir(d) if p.endswith(".png")) if os.path.isdir(d) else []


def side_by_side(surface, ours, dark, refs, title):
    out = os.path.join(OUT, surface + ".android.png")
    mine = [os.path.join(M.SNAP, ours + "-light.png")] + ([os.path.join(M.SNAP, dark + "-dark.png")] if dark else [])
    subprocess.run([sys.executable, "-I", os.path.join(ROOT, "tools", "sidebyside.py"), out, "--ours", *mine, "--ref", *[os.path.join(ROOT, r) for r in refs], "--title", title], check=True)
    return os.path.basename(out)


def main():
    only = set(sys.argv[1:])
    summary = []
    for s in SURFACES:
        sid = s["id"]
        if only and sid not in only:
            continue
        with open(os.path.join(ROOT, "design", "surfaces", sid + ".md")) as f:
            spec = f.read()
        sheet = Sheet(sid)
        measured_tokens = set()
        if s.get("measure"):
            for name, rows in s["measure"]():
                sheet.section(name)
                for row in rows:
                    label, token, expected, ours = row[:4]
                    opts = row[4] if len(row) > 4 else {}
                    measured_tokens.add(token)
                    sheet.measured(label, token, expected, ours, **opts)
        token_rows(sheet, sid, spec, measured_tokens)
        copy_rows(sheet, sid, spec)
        img = None
        if s.get("refs") and s.get("ours"):
            img = side_by_side(sid, s["ours"], s.get("dark"), s["refs"], f"{sid} (Android, Pass 4) — {s['ours'].split('/')[-1]} light + {s.get('dark', '').split('/')[-1]} dark")
        lines = [f"# Verification — `{sid}` (Android)", ""]
        lines += [s["what"], ""]
        lines += [
            "Pass 4 (Retro redesign). Generated by `android/feature/account/verification/checklists.py` from the Robolectric "
            "renders (`./gradlew :feature:account:recordRoborazziDebug`, debug build, 393 × 852 dp at 2 px/dp, no system-bar "
            "insets, Reduce Motion off, font scale 1, real sample photos). Every state is rendered in light; the primary state "
            "also in dark. Measured values are read from the pixels of our render (dp); reference values and evidence come "
            "from the token files.",
            "",
        ]
        if img:
            refs = ", ".join(f"`{r}`" for r in s["refs"])
            lines += [f"Side by side: [`{img}`]({img}) — ours left (`{s['ours']}-light.png`" + (f", `{s['dark']}-dark.png`" if s.get("dark") else "") + f"), Retro reference right ({refs})." + (" " + s["ref_note"] if s.get("ref_note") else ""), ""]
        else:
            lines += ["Side by side: none — " + s.get("no_ref", "the spec names no reference image for this surface.") , ""]
        states = states_section(s.get("snapdir", sid))
        if states:
            lines += ["States rendered (`android/feature/account/src/test/snapshots/" + s.get("snapdir", sid) + "/`): " + ", ".join(f"`{x}`" for x in states) + ".", ""]
        if s.get("extra"):
            lines += [s["extra"], ""]
        total = sum(sheet.counts.values())
        order = ["match", "approx", "MISS", "BLOCKED", "n/a", "UNREVIEWED"]
        parts = [f"{sheet.counts[k]} {k}" for k in order if k in sheet.counts]
        lines += [f"**Result: {total} checks — " + ", ".join(parts) + ".** (`match` includes measured, token, behaviour and copy rows.)", ""]
        for name, rows in sheet.sections:
            if not rows:
                continue
            lines += [f"## {name}", "", "| status | token / copy | expected (spec) | ours | reference evidence | note |", "|---|---|---|---|---|---|"]
            for status, token, expected, ours, ref, note in rows:
                lines.append(f"| {status} | {token} | {clip(expected, 90)} | {clip(ours, 110)} | {ref} | {clip(note, 160)} |")
            lines.append("")
        with open(os.path.join(OUT, sid + ".android.md"), "w") as f:
            f.write("\n".join(lines))
        summary.append((sid, sheet.counts))
    for sid, c in summary:
        print(f"{sid:40s} " + ", ".join(f"{k} {v}" for k, v in sorted(c.items())))


if __name__ == "__main__":
    main()
