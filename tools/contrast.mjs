#!/usr/bin/env node
// WCAG 2.2 contrast checks for the design tokens (SC 1.4.3 text, SC 1.4.11 non-text).
//
//   node tools/contrast.mjs <fg> <bg> [text|large|nontext]
//        one pair. A color is a token name (color.global.textPrimary) or #RRGGBB / #RRGGBBAA.
//        A translucent color is composited over the next color: "<fg>" over "<bg>[,<base>...]",
//        e.g. node tools/contrast.mjs '#CAC4D066' color.global.system.surfaceContainerLow nontext
//   node tools/contrast.mjs --pairs
//        every pair the foundations imply (PAIRS below), as a Markdown table.
//   node tools/contrast.mjs --write
//        rewrites the table in design/CONTRAST.md between the contrast:begin / contrast:end markers.
//
// Formulas are the W3C WCAG 2.2 definitions (https://www.w3.org/TR/WCAG22/, Recommendation
// 2024-12-12, "relative luminance" and "contrast ratio"):
//   channel c = C8/255; c <= 0.04045 ? c/12.92 : ((c + 0.055)/1.055)^2.4
//   L = 0.2126 R + 0.7152 G + 0.0722 B;  ratio = (L1 + 0.05) / (L2 + 0.05), L1 the lighter.
// Alpha compositing is source-over on gamma-encoded sRGB channels (out = a·fg + (1 − a)·bg),
// the way UIKit/Compose/CSS blend a translucent fill onto an opaque one.
// Thresholds are read from the tokens layout.global.contrast.text / .largeText / .nonText.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

// ---------- tokens (same file set as tools/designgen.mjs) ----------
function loadTokens() {
  const files = [];
  if (fs.existsSync(path.join(ROOT, "design/tokens.json"))) files.push("design/tokens.json");
  const dir = path.join(ROOT, "design/tokens");
  if (fs.existsSync(dir)) for (const f of fs.readdirSync(dir).sort()) if (f.endsWith(".json")) files.push(`design/tokens/${f}`);
  const out = {};
  for (const f of files) Object.assign(out, JSON.parse(fs.readFileSync(path.join(ROOT, f), "utf8")).tokens ?? {});
  return out;
}
const TOKENS = loadTokens();

function threshold(kind) {
  const name = { text: "layout.global.contrast.text", large: "layout.global.contrast.largeText", nontext: "layout.global.contrast.nonText" }[kind];
  if (!name) throw new Error(`unknown kind ${kind} (text | large | nontext)`);
  const t = TOKENS[name];
  if (!t || typeof t.value?.ratio !== "number") throw new Error(`threshold token ${name} missing`);
  return t.value.ratio;
}

// ---------- color math ----------
function parseHex(hex) {
  const m = /^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$/.exec(hex);
  if (!m) throw new Error(`not a #RRGGBB(AA) color: ${hex}`);
  const n = parseInt(m[1], 16);
  return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255, a: m[2] ? parseInt(m[2], 16) / 255 : 1 };
}
function resolveColor(ref) {
  if (ref.startsWith("#")) return { hex: ref.toUpperCase(), ...parseHex(ref) };
  const t = TOKENS[ref];
  if (!t) throw new Error(`unknown token ${ref}`);
  if (t.type !== "color") throw new Error(`${ref} is not a color token`);
  if (t.value === null || t.value === undefined) throw new Error(`${ref} has no value (${t.level})`);
  return { hex: t.value.toUpperCase(), ...parseHex(t.value) };
}
// stack: [top, ..., bottom]; the bottom-most color must be opaque.
function composite(stack) {
  let out = null;
  for (let i = stack.length - 1; i >= 0; i--) {
    const c = stack[i];
    if (out === null) {
      if (c.a < 1) throw new Error(`bottom color ${c.hex} is translucent; add an opaque color beneath it`);
      out = { r: c.r, g: c.g, b: c.b };
    } else {
      out = { r: c.a * c.r + (1 - c.a) * out.r, g: c.a * c.g + (1 - c.a) * out.g, b: c.a * c.b + (1 - c.a) * out.b };
    }
  }
  return out;
}
const lin = (c8) => {
  const c = c8 / 255;
  return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
};
export const luminance = ({ r, g, b }) => 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
export function ratio(c1, c2) {
  const [hi, lo] = [luminance(c1), luminance(c2)].sort((a, b) => b - a);
  return (hi + 0.05) / (lo + 0.05);
}
const toHex = ({ r, g, b }) => "#" + [r, g, b].map((v) => Math.round(v).toString(16).padStart(2, "0")).join("").toUpperCase();

// fg over bg (bg may itself be a list "a,b" = a over b)
export function check(fgRef, bgRef, kind = "text") {
  const bgStack = String(bgRef).split(",").map((s) => resolveColor(s.trim()));
  const bg = composite(bgStack);
  const fg = composite([resolveColor(fgRef), ...bgStack]);
  const r = ratio(fg, bg);
  const need = threshold(kind);
  return { fg: toHex(fg), bg: toHex(bg), ratio: r, need, pass: r + 1e-9 >= need };
}

// ---------- the pairs the foundations imply ----------
// kind: text = 4.5:1 (text up to 17 pt, not bold); large = 3:1 (18 pt+, or bold); nontext = 3:1 (SC 1.4.11).
// "use" names the measured element the pair comes from (design/research/*.md).
export const PAIRS = [
  // Yope app surfaces
  ["color.global.textPrimary", "color.global.background", "text", "message / body text 17 regular on group & chat screens"],
  ["color.global.textPrimary", "color.global.backgroundDeep", "text", "names, titles, body on black screens (home, sheets, camera)"],
  ["color.global.textPrimary", "color.global.control", "text", "typed text in the composer field; header capsule title"],
  ["color.global.textPrimary", "color.global.controlRaised", "text", "selected tab glyph / inner header pill text"],
  ["color.global.textPrimary", "color.global.controlOnDeep", "nontext", "✕ / ↓ glyphs in header circles on black"],
  ["color.global.textPrimary", "color.global.control", "nontext", "‹ / film-strip glyphs in header circles on #171717"],
  ["color.global.textSecondary", "color.global.background", "text", "secondary text on group & chat screens"],
  ["color.global.textSecondary", "color.global.backgroundDeep", "text", "section label 'suggested friends' (16 semibold) on black"],
  ["color.global.textSecondary", "color.global.control", "text", "placeholder 'start typing...' (17 regular) in the composer field"],
  ["color.global.textSecondary", "color.global.control", "nontext", "inactive tab-bar glyphs on the tab-bar capsule"],
  ["color.global.onAccent", "color.global.accent", "text", "primary button label (15 semibold) and tooltip text on lime"],
  ["color.global.onAccent", "color.global.accent", "nontext", "camera glyph on the lime composer button"],
  ["color.global.accent", "color.global.background", "text", "lime text on #171717 (sender name, links)"],
  ["color.global.accent", "color.global.backgroundDeep", "text", "lime text on black (sender name on home, 'try other options' link)"],
  ["color.global.accent", "color.global.background", "nontext", "lime button / shutter ring against #171717"],
  ["color.global.accent", "color.global.backgroundDeep", "nontext", "lime button / shutter ring against black"],
  ["color.global.onSurfaceLight", "color.global.surfaceLight", "text", "label on white pill buttons ('invite more friends', 'enable')"],
  ["color.global.surfaceLight", "color.global.backgroundDeep", "nontext", "white pill button against black"],
  ["color.global.surfaceLight", "color.global.background", "nontext", "white pill / selected segment against #171717"],
  ["color.global.control", "color.global.background", "nontext", "circle button / capsule fill against #171717"],
  ["color.global.controlOnDeep", "color.global.backgroundDeep", "nontext", "header circle fill against black"],
  ["color.global.controlRaised", "color.global.control", "nontext", "selected tab pill against the tab-bar capsule"],
  ["color.global.textPrimary", "color.global.textSecondary", "nontext", "selected (white) vs inactive (gray) tab glyph — the state change itself"],
  ["color.global.selection", "color.global.backgroundDeep", "nontext", "filled check circle on black pickers"],
  ["color.global.selection", "color.global.background", "nontext", "filled check circle on #171717"],
  ["color.global.textPrimary", "color.global.accentSecondary", "large", "white name on the pink sticker (heavy display text, large/bold threshold)"],
  ["color.global.textPrimary", "color.global.accentSecondary", "text", "white text under 18 pt, not bold, on the pink (not observed; shows the limit)"],
  ["color.global.accentSecondary", "color.global.background", "nontext", "pink card outline against #171717"],
  ["color.global.destructive", "color.global.background", "text", "red destructive menu text (systemRed, dark) on #171717"],
  ["color.global.destructive", "color.global.backgroundDeep", "text", "red destructive text (systemRed, dark) on black"],
  // Material 3 system surfaces (Android, baseline dark scheme)
  ["color.global.system.onSurface", "color.global.system.surface", "text", "M3 list item label (bodyLarge 16) on surface"],
  ["color.global.system.onSurfaceVariant", "color.global.system.surface", "text", "M3 supporting text (bodyMedium 14) on surface"],
  ["color.global.system.onSurface", "color.global.system.surfaceContainerHigh", "text", "M3 dialog headline / text on dialog container"],
  ["color.global.system.onSurfaceVariant", "color.global.system.surfaceContainerHigh", "text", "M3 dialog supporting text"],
  ["color.global.system.primary", "color.global.system.surfaceContainerHigh", "text", "M3 dialog action label (labelLarge 14/500)"],
  ["color.global.system.error", "color.global.system.surface", "text", "M3 error / destructive text on surface"],
  ["color.global.system.error", "color.global.system.surfaceContainerHigh", "text", "M3 destructive action label in a dialog"],
  ["color.global.system.onSurface", "color.global.system.surfaceContainerLow", "text", "M3 bottom-sheet list text"],
  ["color.global.system.outline", "color.global.system.surface", "nontext", "M3 list divider (1 dp outline)"],
  ["#CAC4D066", "color.global.system.surfaceContainerLow", "nontext", "M3 sheet drag handle: on-surface-variant at 0.4 opacity"],
];

function fmt(r) {
  return r.toFixed(2) + ":1";
}
export function table() {
  let out = "| # | foreground | background | kind | ratio | needs | result | use |\n|---|---|---|---|---|---|---|---|\n";
  PAIRS.forEach(([fg, bg, kind, use], i) => {
    let row;
    try {
      const c = check(fg, bg, kind);
      const fgLabel = fg.startsWith("#") ? `\`${fg}\`` : `\`${fg}\` ${c.fg}`;
      row = `| ${i + 1} | ${fgLabel} | \`${bg}\` ${c.bg} | ${kind} | ${fmt(c.ratio)} | ${c.need}:1 | ${c.pass ? "pass" : "**FAIL**"} | ${use} |`;
    } catch (e) {
      row = `| ${i + 1} | \`${fg}\` | \`${bg}\` | ${kind} | — | — | not computed: ${e.message} | ${use} |`;
    }
    out += row + "\n";
  });
  return out;
}

// ---------- CLI ----------
const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  const args = process.argv.slice(2);
  if (args[0] === "--pairs") {
    process.stdout.write(table());
  } else if (args[0] === "--write") {
    const f = path.join(ROOT, "design/CONTRAST.md");
    const md = fs.readFileSync(f, "utf8");
    const begin = "<!-- contrast:begin -->";
    const end = "<!-- contrast:end -->";
    const i = md.indexOf(begin), j = md.indexOf(end);
    if (i < 0 || j < 0) { console.error("design/CONTRAST.md has no contrast:begin / contrast:end markers"); process.exit(1); }
    fs.writeFileSync(f, md.slice(0, i + begin.length) + "\n" + table() + md.slice(j));
    console.log("contrast: table written to design/CONTRAST.md");
  } else if (args.length >= 2) {
    const c = check(args[0], args[1], args[2] ?? "text");
    console.log(`${c.fg} on ${c.bg}: ${fmt(c.ratio)} (needs ${c.need}:1) ${c.pass ? "pass" : "FAIL"}`);
  } else {
    console.error("usage: node tools/contrast.mjs <fg> <bg> [text|large|nontext] | --pairs | --write");
    process.exit(2);
  }
}
