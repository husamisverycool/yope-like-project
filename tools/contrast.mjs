#!/usr/bin/env node
// WCAG 2.2 contrast checks for the design tokens (SC 1.4.3 text, SC 1.4.11 non-text), in both
// appearances.
//
//   node tools/contrast.mjs <fg> <bg> [text|large|nontext] [--appearance light|dark]
//        one pair. A color is a token name (color.global.textPrimary) or #RRGGBB / #RRGGBBAA.
//        A translucent color is composited over the next color: "<fg>" over "<bg>[,<base>...]",
//        e.g. node tools/contrast.mjs '#CAC4D066' color.global.system.surfaceContainerLow nontext
//        A token whose value is {light, dark} resolves to the appearance asked for; without
//        --appearance the pair is checked in both and one line per appearance is printed.
//   node tools/contrast.mjs --pairs
//        every pair the foundations imply (PAIRS below), as a Markdown table: one row per
//        appearance when any color in the pair differs between appearances, else one row ("both").
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
const APPEARANCES = ["light", "dark"];

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
/** true when the reference (a token or a stack "a,b") resolves differently in light and dark */
export function isThemed(ref) {
  return String(ref).split(",").some((s) => {
    const t = TOKENS[s.trim()];
    return t && t.type === "color" && t.value && typeof t.value === "object";
  });
}
function resolveColor(ref, appearance) {
  if (ref.startsWith("#")) return { hex: ref.toUpperCase(), ...parseHex(ref) };
  const t = TOKENS[ref];
  if (!t) throw new Error(`unknown token ${ref}`);
  if (t.type !== "color") throw new Error(`${ref} is not a color token`);
  if (t.value === null || t.value === undefined) throw new Error(`${ref} has no value (${t.level})`);
  const v = typeof t.value === "object" ? t.value[appearance] : t.value;
  if (!v) throw new Error(`${ref} has no ${appearance} value`);
  return { hex: v.toUpperCase(), ...parseHex(v) };
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

// fg over bg (bg may itself be a list "a,b" = a over b), in one appearance
export function check(fgRef, bgRef, kind = "text", appearance = "light") {
  const bgStack = String(bgRef).split(",").map((s) => resolveColor(s.trim(), appearance));
  const bg = composite(bgStack);
  const fg = composite([resolveColor(fgRef, appearance), ...bgStack]);
  const r = ratio(fg, bg);
  const need = threshold(kind);
  return { fg: toHex(fg), bg: toHex(bg), ratio: r, need, pass: r + 1e-9 >= need, appearance };
}

// ---------- the pairs the foundations imply ----------
// kind: text = 4.5:1 (text up to 17 pt, not bold); large = 3:1 (18 pt+, or bold); nontext = 3:1 (SC 1.4.11).
// "use" names the measured element the pair comes from (design/research/retro-*.md, design/components.md).
// Optional 5th element: "light" | "dark" to check one appearance only (e.g. a pair that exists only there).
export const PAIRS = [
  // Page text (iOS page colour; Android page colour where Android differs)
  ["color.global.textPrimary", "color.global.background", "text", "body / names 15 pt on the page (iOS)"],
  ["color.global.textPrimary", "color.global.background.android", "text", "body / names on the Android page"],
  ["color.global.textSecondary", "color.global.background", "text", "secondary text 13–15 pt regular on the page: date range, real name, list subtitle, legal 14 pt (iOS)"],
  ["color.global.textSecondary", "color.global.background", "large", "grey 'Friends Only' 30 pt on the landing (large text)"],
  ["color.global.textSecondary.android", "color.global.background.android", "text", "Android meta lines (black 50 % / white 60 %) on the page"],
  ["color.global.textSecondary.android", "color.global.surfaceSecondary.android", "text", "Android row subtitle on a grouped row"],
  ["color.global.textTertiary", "color.global.background", "text", "tertiary / disabled text (WCAG exempts inactive components)"],
  ["color.global.textTertiary", "color.global.background.android", "text", "tertiary / disabled text on the Android page"],
  // Fills (tiles, fields, pills, circles, grouped rows)
  ["color.global.textPrimary", "color.global.control", "text", "typed text in a field; 'Create' fill-pill label 15 semibold; row text on an iOS grouped row"],
  ["color.global.textPrimary", "color.global.control", "nontext", "'+' glyph on the add tile / '+' circle; '×' on a light sheet's close circle"],
  ["color.global.textSecondary", "color.global.control", "text", "placeholder 'Search' 17 pt and row subtitles on a fill (iOS)"],
  ["color.global.textPrimary", "color.global.surfaceSecondary.android", "text", "Android grouped-row title / chip label"],
  ["color.global.control", "color.global.background", "nontext", "tile / field / circle / grouped-row fill against the page"],
  ["color.global.surfaceSecondary.android", "color.global.background.android", "nontext", "Android grouped-row / chip fill against the page"],
  ["color.global.emptyTileText", "color.global.control", "text", "empty-day tile month / weekday 14 pt"],
  ["color.global.emptyTileText", "color.global.control", "large", "empty-day tile day number 28 pt semibold (large text)"],
  // Buttons
  ["color.global.onAccent", "color.global.accent", "text", "primary capsule label 17 semibold; medium capsule label 15 semibold"],
  ["color.global.accent", "color.global.background", "nontext", "primary capsule against the page"],
  ["color.global.accent", "color.global.background.android", "nontext", "primary capsule against the Android page"],
  ["color.global.textPrimary", "color.global.background", "nontext", "outline capsule 1 pt border against the page"],
  ["color.global.controlRaised", "color.global.background", "nontext", "disabled primary capsule fill (inactive component: exempt)"],
  // Tab bar, badges, dots
  ["color.global.tabInactive", "color.global.background", "nontext", "unselected tab glyph against the bar (= page)"],
  ["color.global.textPrimary", "color.global.tabInactive", "nontext", "selected vs unselected tab glyph — the state change itself"],
  ["color.global.badge", "color.global.background", "nontext", "4 pt unread dot under a tab glyph"],
  ["color.global.onBadge", "color.global.badge", "text", "'new' label 11 semibold on the red badge"],
  ["color.global.onBadge", "color.global.badgeMuted", "text", "'Last Week' label (small semibold) on the grey pill"],
  ["color.global.pageDotInactive", "color.global.background", "nontext", "inactive page dot on the page"],
  ["color.global.pageDotInactive", "color.global.backgroundDeep", "nontext", "inactive page dot on a media surface (recap preview)"],
  ["color.global.textPrimary", "color.global.pageDotInactive", "nontext", "active vs inactive page dot (state)"],
  ["color.global.selection", "color.global.background", "nontext", "system-blue check circle / switch on the page (iOS)"],
  // Destructive
  ["color.global.destructive", "color.global.background", "text", "red destructive row / menu text 15–17 regular on the page"],
  ["color.global.destructive", "color.global.control", "text", "red destructive text on an iOS grouped row"],
  ["color.global.destructive", "color.global.surfaceSecondary.android", "text", "red destructive text on an Android grouped row"],
  ["color.global.destructive", "color.global.controlOnDeep", "nontext", "red mic / trash glyph in the voice capsule on media (#262626; dark value in both appearances)", "dark"],
  // Hairline (decorative)
  ["color.global.separator", "color.global.background", "nontext", "hairline divider (decorative: not required by SC 1.4.11)"],
  // Cards on backdrops
  ["color.global.textPrimary", "color.global.surfaceElevated", "text", "text on the recap / plan card"],
  ["color.global.textSecondary", "color.global.surfaceElevated", "text", "secondary text ('retro.app'-style footer, plan footnote) on the card"],
  // Media surfaces (black in both appearances)
  ["color.global.textOnMedia", "color.global.backgroundDeep", "text", "viewer header name 15 semibold, comment text on black"],
  ["color.global.textSecondary", "color.global.backgroundDeep", "text", "viewer 'Week 49' / date 15 regular on black (media surfaces take the dark appearance's value in both appearances: iOS forces .dark, Android reads Tokens.ColorsDark)", "dark"],
  ["color.global.textOnMedia", "color.global.controlOnDeep", "text", "position pill / 'Add a message' label on #262626"],
  ["color.global.textOnMedia", "color.global.controlOnDeep", "nontext", "close / edit glyph in a #262626 circle"],
  ["color.global.textSecondary", "color.global.controlOnDeep", "text", "comment-field placeholder on #262626 (media: dark value in both appearances)", "dark"],
  ["color.global.controlOnDeep", "color.global.backgroundDeep", "nontext", "#262626 circle / pill / field against black"],
  ["color.global.onSurfaceLight", "color.global.surfaceLight", "text", "'Share' / 'Send Postcard' label on the white pill"],
  ["color.global.textSecondary", "color.global.surfaceLight", "text", "recap card detail line on the white card (white in both appearances: it takes the light value)", "light"],
  ["color.global.surfaceLight", "color.global.backgroundDeep", "nontext", "white pill against black"],
  // Over photos (worst case: a white photo)
  ["color.global.textOnMedia", "#00000066,#FFFFFF", "text", "weekday tile label 13 semibold at its baseline (scrim ≈40 % there) over a WHITE photo — worst case"],
  ["color.global.textOnMedia", "color.global.scrim,#FFFFFF", "text", "white text at the tile's bottom edge (scrim 60 %) over a white photo"],
  ["color.global.textOnMedia", "color.global.glass,#FFFFFF", "nontext", "white glyph in a glass circle over a white photo — worst case"],
  ["color.global.textOnMedia", "color.global.glass,#7D7263", "nontext", "white glyph in a glass circle over the measured Rewind photo (RWA outside #7D7263)"],
  ["color.global.tabInactiveOnMedia", "#322C25", "nontext", "unselected tab glyph over the measured Rewind photo and scrim (RWA #322C25)"],
  // Material 3 system surfaces (Android; Retro's scheme + M3 baseline)
  ["color.global.system.onSurface", "color.global.system.surface", "text", "M3 list item label (bodyLarge) on surface"],
  ["color.global.system.onSurfaceVariant", "color.global.system.surface", "text", "M3 supporting text (bodyMedium 14) on surface"],
  ["color.global.system.onSurface", "color.global.system.surfaceContainerHigh", "text", "M3 dialog headline / text on the dialog container"],
  ["color.global.system.onSurfaceVariant", "color.global.system.surfaceContainerHigh", "text", "M3 dialog supporting text"],
  ["color.global.system.primary", "color.global.system.surfaceContainerHigh", "text", "M3 dialog action label (labelLarge 14/500) in Retro blue"],
  ["color.global.system.primary", "color.global.system.surface", "text", "M3 text button / link in Retro blue on surface"],
  ["color.global.system.error", "color.global.system.surface", "text", "M3 error / destructive text on surface"],
  ["color.global.system.error", "color.global.system.surfaceContainerHigh", "text", "M3 destructive action label in a dialog"],
  ["color.global.system.onSurface", "color.global.system.surfaceContainerLow", "text", "M3 bottom-sheet list text"],
  ["color.global.system.outline", "color.global.system.surface", "nontext", "M3 outline (outlined field border)"],
  ["#CAC4D066", "color.global.system.surfaceContainerLow", "nontext", "M3 sheet drag handle: on-surface-variant at 0.4 opacity (dark)", "dark"],
  ["#49454F66", "color.global.system.surfaceContainerLow", "nontext", "M3 sheet drag handle: on-surface-variant at 0.4 opacity (light)", "light"],
];

function fmt(r) {
  return r.toFixed(2) + ":1";
}
/** rows for one pair: [appearance, result] per appearance it is checked in */
export function checkPair([fg, bg, kind, , only]) {
  const apps = only ? [only] : isThemed(fg) || isThemed(bg) ? APPEARANCES : ["both"];
  return apps.map((a) => [a, check(fg, bg, kind, a === "both" ? "light" : a)]);
}
export function table() {
  let out = "| # | foreground | background | kind | appearance | ratio | needs | result | use |\n|---|---|---|---|---|---|---|---|---|\n";
  PAIRS.forEach((pair, i) => {
    const [fg, bg, kind, use] = pair;
    let rows;
    try {
      rows = checkPair(pair).map(([a, c]) => {
        const fgLabel = fg.startsWith("#") ? `\`${fg}\`` : `\`${fg}\` ${c.fg}`;
        return `| ${i + 1} | ${fgLabel} | \`${bg}\` ${c.bg} | ${kind} | ${a} | ${fmt(c.ratio)} | ${c.need}:1 | ${c.pass ? "pass" : "**FAIL**"} | ${use} |`;
      });
    } catch (e) {
      rows = [`| ${i + 1} | \`${fg}\` | \`${bg}\` | ${kind} | — | — | — | not computed: ${e.message} | ${use} |`];
    }
    out += rows.join("\n") + "\n";
  });
  return out;
}

// ---------- CLI ----------
const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  const argv = process.argv.slice(2);
  const ai = argv.indexOf("--appearance");
  const appearance = ai >= 0 ? argv[ai + 1] : null;
  const args = ai >= 0 ? argv.filter((_, i) => i !== ai && i !== ai + 1) : argv;
  if (appearance && !APPEARANCES.includes(appearance)) { console.error("--appearance must be light or dark"); process.exit(2); }
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
    const kind = args[2] ?? "text";
    const apps = appearance ? [appearance] : isThemed(args[0]) || isThemed(args[1]) ? APPEARANCES : ["light"];
    for (const a of apps) {
      const c = check(args[0], args[1], kind, a);
      const label = appearance || apps.length > 1 ? ` [${a}]` : "";
      console.log(`${c.fg} on ${c.bg}${label}: ${fmt(c.ratio)} (needs ${c.need}:1) ${c.pass ? "pass" : "FAIL"}`);
    }
  } else {
    console.error("usage: node tools/contrast.mjs <fg> <bg> [text|large|nontext] [--appearance light|dark] | --pairs | --write");
    process.exit(2);
  }
}
