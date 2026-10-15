#!/usr/bin/env node
// Generates platform constants and ledgers from the canonical design files.
//
//   node tools/designgen.mjs           validate + generate
//   node tools/designgen.mjs --check   validate only (exit 1 on problems)
//
// Inputs:  design/tokens.json + design/tokens/*.json, design/copy.json + design/copy/*.json,
//          design/copy-patterns.md, config/app.json
// Outputs: ios/Packages/AppCore/Sources/DesignSystem/Generated/{Tokens,Copy}.swift
//          ios/Packages/AppCore/Sources/DesignSystem/Generated/Blocked*.swift  (DEBUG only)
//          ios/Config/InfoPlist.generated.xcconfig  (purpose strings: copy entries with infoPlistKey)
//          android/core/designsystem/src/main/kotlin/app/designsystem/generated/Tokens.kt
//          android/core/designsystem/src/main/res/values/strings.xml
//          android/core/designsystem/src/debug/res/values/strings_blocked.xml (debug only)
//          backend/worker/src/generated/{copy,tokens}.ts, web/src/generated/{copy,tokens}.ts
//          design/SOURCES.md, design/COPY.md, design/BLOCKED.md
//
// BLOCKED values are emitted only into debug-only outputs, so any release build that uses
// one fails to compile. Strings containing {app_name} are BLOCKED until config/app.json
// has a displayName.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const rd = (p) => JSON.parse(fs.readFileSync(path.join(ROOT, p), "utf8"));
const wr = (p, s) => {
  const f = path.join(ROOT, p);
  fs.mkdirSync(path.dirname(f), { recursive: true });
  fs.writeFileSync(f, s);
};
const exists = (p) => fs.existsSync(path.join(ROOT, p));

const LEVELS = ["SOURCED", "CAPTURED", "VERIFIED", "PLATFORM", "BLOCKED"];
const TYPES = {
  color: "Colors", dimension: "Sizes", radius: "Radii", fontSize: "FontSizes",
  fontWeight: "FontWeights", lineHeight: "LineHeights", letterSpacing: "Tracking",
  duration: "Durations", easing: "Easings", spring: "Springs", opacity: "Opacities",
  blur: "Blurs", shadow: "Shadows", icon: "Icons", haptic: "Haptics", font: "Fonts",
  layout: "Layouts", aspectRatio: "AspectRatios", count: "Counts",
};
const CATEGORY_WORDS = new Set([
  "color", "colors", "dimension", "size", "space", "spacing", "radius", "font", "weight",
  "fontsize", "lineheight", "tracking", "letterspacing", "duration", "easing", "spring",
  "opacity", "blur", "shadow", "icon", "haptic", "layout", "aspect", "aspectratio", "count",
]);
const SWIFT_WEIGHTS = { ultralight: ".ultraLight", thin: ".thin", light: ".light", regular: ".regular", medium: ".medium", semibold: ".semibold", bold: ".bold", heavy: ".heavy", black: ".black" };
const NUM_WEIGHTS = { ultralight: 200, thin: 100, light: 300, regular: 400, medium: 500, semibold: 600, bold: 700, heavy: 800, black: 900 };


function camel(parts) {
  const words = parts.flatMap((p) => p.split(/[^A-Za-z0-9]+/)).filter(Boolean);
  return words.map((w, i) => (i === 0 ? w[0].toLowerCase() + w.slice(1) : w[0].toUpperCase() + w.slice(1))).join("");
}
function ident(name) {
  let parts = name.split(".");
  while (parts.length > 1 && CATEGORY_WORDS.has(parts[0].toLowerCase())) parts = parts.slice(1);
  let id = camel(parts);
  if (/^[0-9]/.test(id)) id = "_" + id;
  return id;
}
function snake(key) { return key.replace(/[^A-Za-z0-9]+/g, "_").toLowerCase(); }

const problems = [];
const problem = (m) => problems.push(m);

// ---------- load ----------
const app = rd("config/app.json");
const appName = app.displayName?.value ?? null;
// Canonical files: design/tokens.json + design/tokens/*.json, design/copy.json + design/copy/*.json
// (split by surface group so several people can edit without conflicts). A key defined twice is an error.
function loadAll(single, dir, field) {
  const files = [];
  if (exists(single)) files.push(single);
  if (exists(dir)) for (const f of fs.readdirSync(path.join(ROOT, dir)).sort()) if (f.endsWith(".json")) files.push(`${dir}/${f}`);
  const out = {};
  const origin = {};
  for (const f of files) {
    const data = rd(f)[field] ?? {};
    for (const [k, v] of Object.entries(data)) {
      if (k in out) problems.push(`${field} key ${k} defined in both ${origin[k]} and ${f}`);
      out[k] = v;
      origin[k] = f;
    }
  }
  return out;
}
const tokens = loadAll("design/tokens.json", "design/tokens", "tokens");
const strings = loadAll("design/copy.json", "design/copy", "strings");

// ---------- validate ----------
for (const [name, t] of Object.entries(tokens)) {
  for (const f of ["type", "source_app", "surface", "element", "evidence", "level"]) if (t[f] === undefined || t[f] === "") problem(`token ${name}: missing ${f}`);
  if (t.level && !LEVELS.includes(t.level)) problem(`token ${name}: bad level ${t.level}`);
  if (t.type && !TYPES[t.type]) problem(`token ${name}: unknown type ${t.type}`);
  if (t.level !== "BLOCKED" && (t.value === undefined || t.value === null)) problem(`token ${name}: no value but level ${t.level}`);
  if (t.type === "color" && t.value && !/^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(t.value)) problem(`token ${name}: color must be #RRGGBB or #RRGGBBAA`);
  if (t.type === "icon" && t.value && (!t.value.ios || !t.value.android)) problem(`token ${name}: icon needs {ios, android}`);
  if (t.type === "haptic" && t.value && (!t.value.ios || !t.value.android)) problem(`token ${name}: haptic needs {ios, android}`);
  if (["SOURCED", "CAPTURED"].includes(t.level) && !["icon", "font", "haptic"].includes(t.type) && !t.method) problem(`token ${name}: ${t.level} needs method`);
}
for (const [key, s] of Object.entries(strings)) {
  for (const f of ["text", "origin", "source_app", "surface", "evidence", "level"]) if (s[f] === undefined || s[f] === "") problem(`copy ${key}: missing ${f}`);
  if (s.level && !LEVELS.includes(s.level)) problem(`copy ${key}: bad level ${s.level}`);
  if (s.origin && !["verbatim", "adapted", "new"].includes(s.origin)) problem(`copy ${key}: bad origin ${s.origin}`);
  if (s.origin && s.origin !== "verbatim" && !s.pattern) problem(`copy ${key}: ${s.origin} string needs a pattern`);
}
// identifier collisions
const seen = {};
for (const [name, t] of Object.entries(tokens)) {
  const k = `${TYPES[t.type]}.${ident(name)}`;
  if (seen[k]) problem(`identifier collision ${k}: ${seen[k]} vs ${name}`);
  seen[k] = name;
}

if (problems.length) {
  console.error(problems.map((p) => "  - " + p).join("\n"));
  console.error(`designgen: ${problems.length} problem(s)`);
  process.exit(1);
}
if (process.argv.includes("--check")) {
  console.log(`designgen: ok (${Object.keys(tokens).length} tokens, ${Object.keys(strings).length} strings)`);
  process.exit(0);
}

const isBlockedToken = (t) => t.level === "BLOCKED";
const isBlockedString = (s) => s.level === "BLOCKED" || (s.text.includes("{app_name}") && !appName);
const resolveText = (s) => (appName ? s.text.replaceAll("{app_name}", appName) : s.text);
const placeholders = (text) => [...new Set([...text.matchAll(/\{([a-zA-Z_][a-zA-Z0-9_]*)\}/g)].map((m) => m[1]))].filter((p) => p !== "app_name" || !appName);

// ---------- Swift ----------
function hexParts(hex) {
  const h = hex.slice(1);
  const r = parseInt(h.slice(0, 2), 16), g = parseInt(h.slice(2, 4), 16), b = parseInt(h.slice(4, 6), 16);
  const a = h.length === 8 ? parseInt(h.slice(6, 8), 16) / 255 : 1;
  return { r, g, b, a };
}
const num = (v) => (Number.isInteger(v) ? `${v}` : `${+v.toFixed(4)}`);
function swiftValue(t) {
  const v = t.value;
  switch (t.type) {
    case "color": { const { r, g, b, a } = hexParts(v); return { type: "Color", expr: `Color(.sRGB, red: ${num(r / 255)}, green: ${num(g / 255)}, blue: ${num(b / 255)}, opacity: ${num(a)})` }; }
    case "dimension": case "radius": case "fontSize": case "lineHeight": case "letterSpacing": case "blur": case "count":
      return { type: "CGFloat", expr: num(v) };
    case "aspectRatio": return { type: "CGFloat", expr: num(typeof v === "object" ? v.width / v.height : v) };
    case "opacity": return { type: "Double", expr: num(v) };
    case "duration": return { type: "TimeInterval", expr: num(v / 1000) };
    case "fontWeight": { const w = String(v).toLowerCase(); return { type: "Font.Weight", expr: SWIFT_WEIGHTS[w] ?? ".regular" }; }
    case "easing": {
      if (typeof v === "string") return { type: "DSEasing", expr: `.${v}` };
      return { type: "DSEasing", expr: `.cubicBezier(${num(v.x1)}, ${num(v.y1)}, ${num(v.x2)}, ${num(v.y2)})` };
    }
    case "spring": return { type: "DSSpring", expr: `DSSpring(response: ${num(v.response)}, dampingFraction: ${num(v.dampingFraction)})` };
    case "shadow": { const { r, g, b } = hexParts(v.color); return { type: "DSShadow", expr: `DSShadow(color: Color(.sRGB, red: ${num(r / 255)}, green: ${num(g / 255)}, blue: ${num(b / 255)}, opacity: ${num(v.opacity ?? 1)}), radius: ${num(v.blur)}, x: ${num(v.x ?? 0)}, y: ${num(v.y ?? 0)})` }; }
    case "icon": return { type: "String", expr: JSON.stringify(v.ios) };
    case "haptic": return { type: "DSHaptic", expr: `.${camel(v.ios.split("."))}` };
    case "font": return { type: "DSFontFamily", expr: v.ios === "system" ? ".system" : `.custom(${JSON.stringify(v.ios)})` };
    case "layout": return null;
  }
  return null;
}
function swiftComment(t) { return `${t.source_app} · ${t.surface} · ${t.element} · ${t.level}`.replace(/\n/g, " "); }

function genSwiftTokens(blocked) {
  const byType = {};
  for (const [name, t] of Object.entries(tokens)) {
    if (isBlockedToken(t) !== blocked) continue;
    (byType[TYPES[t.type]] ??= []).push([name, t]);
  }
  let out = `// GENERATED by tools/designgen.mjs from design/tokens.json — do not edit.\n// Every value below is traced in design/SOURCES.md.\n${blocked ? "#if DEBUG\n" : ""}import SwiftUI\n\n`;
  out += blocked ? "/// BLOCKED values: available in DEBUG builds only, so a release build that uses one fails to compile.\npublic enum BlockedTokens {\n" : "public enum Tokens {\n";
  for (const [enumName, list] of Object.entries(byType).sort()) {
    out += `    public enum ${enumName} {\n`;
    for (const [name, t] of list.sort((a, b) => a[0].localeCompare(b[0]))) {
      out += `        /// ${swiftComment(t)}\n        /// token: \`${name}\`\n`;
      if (t.level === "BLOCKED" && (t.value === null || t.value === undefined)) {
        out += `        public static var ${ident(name)}: Never { fatalError("BLOCKED token ${name}") }\n`;
        continue;
      }
      if (t.type === "layout") {
        out += `        public enum ${ident(name)[0].toUpperCase() + ident(name).slice(1)} {\n`;
        for (const [k, v] of Object.entries(t.value)) out += `            public static let ${camel([k])}: ${typeof v === "number" ? "CGFloat" : "String"} = ${typeof v === "number" ? num(v) : JSON.stringify(String(v))}\n`;
        out += `        }\n`;
        continue;
      }
      const sv = swiftValue(t);
      out += `        public static let ${ident(name)}: ${sv.type} = ${sv.expr}\n`;
    }
    out += `    }\n`;
  }
  out += "}\n" + (blocked ? "#endif\n" : "");
  return out;
}

function swiftStringLit(s) { return JSON.stringify(s).replace(/\\u([0-9a-f]{4})/g, "\\u{$1}"); }
function genSwiftCopy(blocked) {
  let out = `// GENERATED by tools/designgen.mjs from design/copy.json — do not edit.\n// Every string below is traced in design/COPY.md.\n${blocked ? "#if DEBUG\n" : ""}import Foundation\n\n`;
  out += blocked ? "/// BLOCKED strings: DEBUG builds only.\npublic enum BlockedCopy {\n" : "public enum Copy {\n";
  for (const [key, s] of Object.entries(strings).sort((a, b) => a[0].localeCompare(b[0]))) {
    if (isBlockedString(s) !== blocked) continue;
    const id = camel(key.split("."));
    const text = resolveText(s);
    const ph = placeholders(text);
    out += `    /// "${text.replace(/\n/g, "\\n")}" — ${s.source_app} · ${s.surface} · ${s.origin} · ${s.level}\n`;
    if (!ph.length) out += `    public static var ${id}: String { CopyLookup.string(${JSON.stringify(key)}, default: ${swiftStringLit(text)}) }\n`;
    else {
      const params = ph.map((p) => `${camel([p])}: String`).join(", ");
      const dict = ph.map((p) => `${JSON.stringify(p)}: ${camel([p])}`).join(", ");
      out += `    public static func ${id}(${params}) -> String { CopyLookup.format(${JSON.stringify(key)}, default: ${swiftStringLit(text)}, [${dict}]) }\n`;
    }
  }
  out += "}\n" + (blocked ? "#endif\n" : "");
  return out;
}

// ---------- Kotlin ----------
function ktValue(t, imports) {
  const v = t.value;
  switch (t.type) {
    case "color": { const { r, g, b, a } = hexParts(v); const argb = ((Math.round(a * 255) << 24) >>> 0) + (r << 16) + (g << 8) + b; return { type: "Color", expr: `Color(0x${argb.toString(16).toUpperCase().padStart(8, "0")})` }; }
    case "dimension": case "radius": case "blur": return { type: "Dp", expr: `${num(v)}.dp` };
    case "fontSize": case "lineHeight": case "letterSpacing": return { type: "TextUnit", expr: `${num(v)}.sp` };
    case "count": return { type: "Int", expr: `${Math.round(v)}` };
    case "aspectRatio": return { type: "Float", expr: `${num(typeof v === "object" ? v.width / v.height : v)}f` };
    case "opacity": return { type: "Float", expr: `${num(v)}f` };
    case "duration": return { type: "Int", expr: `${Math.round(v)}` };
    case "fontWeight": { const w = String(v).toLowerCase(); return { type: "FontWeight", expr: `FontWeight(${NUM_WEIGHTS[w] ?? 400})` }; }
    case "easing": {
      if (typeof v === "string") return { type: "Easing", expr: { linear: "LinearEasing", easeInOut: "FastOutSlowInEasing", easeOut: "LinearOutSlowInEasing", easeIn: "FastOutLinearInEasing" }[v] ?? "FastOutSlowInEasing" };
      return { type: "Easing", expr: `CubicBezierEasing(${num(v.x1)}f, ${num(v.y1)}f, ${num(v.x2)}f, ${num(v.y2)}f)` };
    }
    case "spring": {
      // SwiftUI response/dampingFraction → Compose stiffness/dampingRatio (mass 1): stiffness = (2π / response)²
      const stiffness = Math.pow((2 * Math.PI) / v.response, 2);
      return { type: "DSSpring", expr: `DSSpring(dampingRatio = ${num(v.dampingFraction)}f, stiffness = ${num(stiffness)}f)` };
    }
    case "shadow": { const { r, g, b } = hexParts(v.color); const argb = ((Math.round((v.opacity ?? 1) * 255) << 24) >>> 0) + (r << 16) + (g << 8) + b; return { type: "DSShadow", expr: `DSShadow(color = Color(0x${argb.toString(16).toUpperCase().padStart(8, "0")}), blur = ${num(v.blur)}.dp, x = ${num(v.x ?? 0)}.dp, y = ${num(v.y ?? 0)}.dp)` }; }
    case "icon": {
      // "Rounded.Mic" or "AutoMirrored.Outlined.Send" (mirrored in right-to-left layouts)
      const parts = v.android.split(".");
      const nm = parts.pop();
      const alias = parts.join("") + nm;
      imports.add(`import androidx.compose.material.icons.${parts.map((p) => p.toLowerCase()).join(".")}.${nm} as ${alias}`);
      return { type: "ImageVector", expr: `androidx.compose.material.icons.Icons.${parts.join(".")}.${alias}`, alias };
    }
    case "haptic": return { type: "Int", expr: `HapticFeedbackConstants.${v.android}` };
    case "font": return { type: "DSFontFamily", expr: v.android === "system" ? "DSFontFamily.System" : `DSFontFamily.Custom(${JSON.stringify(v.android)})` };
  }
  return null;
}
function genKotlinTokens() {
  const imports = new Set();
  const byType = {};
  for (const [name, t] of Object.entries(tokens)) { if (isBlockedToken(t)) continue; (byType[TYPES[t.type]] ??= []).push([name, t]); }
  let body = "object Tokens {\n";
  for (const [objName, list] of Object.entries(byType).sort()) {
    body += `    object ${objName} {\n`;
    for (const [name, t] of list.sort((a, b) => a[0].localeCompare(b[0]))) {
      body += `        /** ${swiftComment(t).replace(/\*\//g, "* /")} — token \`${name}\` */\n`;
      if (t.type === "layout") {
        body += `        object ${ident(name)[0].toUpperCase() + ident(name).slice(1)} {\n`;
        for (const [k, v] of Object.entries(t.value)) body += `            const val ${camel([k])}: ${typeof v === "number" ? "Float" : "String"} = ${typeof v === "number" ? num(v) + "f" : JSON.stringify(String(v))}\n`;
        body += `        }\n`;
        continue;
      }
      const kv = ktValue(t, imports);
      if (t.type === "icon") body += `        val ${ident(name)}: ImageVector get() = ${kv.expr}\n`;
      else body += `        val ${ident(name)}: ${kv.type} = ${kv.expr}\n`;
    }
    body += `    }\n`;
  }
  body += "}\n";
  // Icons are extension properties imported under an alias and called on the fully qualified
  // receiver, because Tokens.Icons shadows androidx.compose.material.icons.Icons here.
  return `// GENERATED by tools/designgen.mjs from design/tokens.json — do not edit.\n// Every value below is traced in design/SOURCES.md.\n@file:Suppress("unused")\n\npackage app.designsystem.generated\n\nimport android.view.HapticFeedbackConstants\nimport androidx.compose.animation.core.*\nimport androidx.compose.ui.graphics.Color\nimport androidx.compose.ui.graphics.vector.ImageVector\nimport androidx.compose.ui.text.font.FontWeight\nimport androidx.compose.ui.unit.Dp\nimport androidx.compose.ui.unit.TextUnit\nimport androidx.compose.ui.unit.dp\nimport androidx.compose.ui.unit.sp\nimport app.designsystem.DSFontFamily\nimport app.designsystem.DSShadow\nimport app.designsystem.DSSpring\n${[...imports].sort().join("\n")}\n\n${body}`;
}
function xmlEscape(text) {
  let s = text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/\\/g, "\\\\").replace(/'/g, "\\'").replace(/"/g, '\\"').replace(/\n/g, "\\n");
  if (s.startsWith("@") || s.startsWith("?")) s = "\\" + s;
  return s;
}
function genStringsXml(blocked) {
  let out = `<?xml version="1.0" encoding="utf-8"?>\n<!-- GENERATED by tools/designgen.mjs from design/copy.json — do not edit. -->\n<resources>\n`;
  for (const [key, s] of Object.entries(strings).sort((a, b) => a[0].localeCompare(b[0]))) {
    if (isBlockedString(s) !== blocked) continue;
    let text = resolveText(s);
    const ph = placeholders(text);
    let esc = xmlEscape(text);
    ph.forEach((p, i) => { esc = esc.replaceAll(`{${p}}`, `%${i + 1}$s`); });
    out += `    <!-- ${s.source_app} · ${s.surface} · ${s.origin} · ${s.level}${ph.length ? " · args: " + ph.join(", ") : ""} -->\n    <string name="${snake(key)}"${ph.length ? "" : ' formatted="false"'}>${esc}</string>\n`;
  }
  return out + "</resources>\n";
}

// ---------- TypeScript ----------
function genTs() {
  const entries = Object.entries(strings).filter(([, s]) => !isBlockedString(s)).sort((a, b) => a[0].localeCompare(b[0]));
  let out = `// GENERATED by tools/designgen.mjs from design/copy.json — do not edit.\n// Every string below is traced in design/COPY.md.\n\nconst table = {\n`;
  for (const [key, s] of entries) out += `  ${JSON.stringify(key)}: ${JSON.stringify(resolveText(s))}, // ${s.source_app} · ${s.surface} · ${s.level}\n`;
  out += `} as const;\n\nexport type CopyKey = keyof typeof table;\nexport const copy: Readonly<Record<CopyKey, string>> = table;\n\nexport function t(key: CopyKey, params: Record<string, string> = {}): string {\n  const text: string = copy[key];\n  return text.replace(/\\{([a-zA-Z_][a-zA-Z0-9_]*)\\}/g, (m: string, p: string) => params[p] ?? m);\n}\n`;
  return out;
}

function genTsTokens() {
  const entries = Object.entries(tokens).filter(([, t]) => !isBlockedToken(t)).sort((a, b) => a[0].localeCompare(b[0]));
  let out = `// GENERATED by tools/designgen.mjs from design/tokens.json — do not edit.\n// Every value below is traced in design/SOURCES.md. Units: pt for sizes (1 pt = 1 px at @1x), ms for durations.\n\nexport const tokens = {\n`;
  for (const [name, t] of entries) out += `  ${JSON.stringify(name)}: ${JSON.stringify(t.value)}, // ${t.source_app} · ${t.surface} · ${t.level}\n`;
  out += `} as const;\n\nexport type TokenName = keyof typeof tokens;\n`;
  return out;
}

// ---------- ledgers ----------
const mdCell = (s) => String(s ?? "").replace(/\|/g, "\\|").replace(/\n/g, " ");
function fmtValue(t) {
  if (t.value === null || t.value === undefined) return "—";
  if (typeof t.value === "object") return "`" + JSON.stringify(t.value) + "`";
  return "`" + t.value + (t.unit ? " " + t.unit : "") + "`";
}
function genSources() {
  const bySurface = {};
  for (const [name, t] of Object.entries(tokens)) (bySurface[t.surface] ??= { tokens: [], copy: [] }).tokens.push([name, t]);
  for (const [key, s] of Object.entries(strings)) (bySurface[s.surface] ??= { tokens: [], copy: [] }).copy.push([key, s]);
  const counts = Object.fromEntries(LEVELS.map((l) => [l, 0]));
  for (const t of Object.values(tokens)) counts[t.level]++;
  for (const s of Object.values(strings)) counts[isBlockedString(s) ? "BLOCKED" : s.level]++;
  let out = `# SOURCES — every design decision and its evidence\n\nGenerated by \`tools/designgen.mjs\` from \`design/tokens.json\` and \`design/copy.json\`. Do not edit by hand.\n\n`;
  out += `Totals: ${LEVELS.map((l) => `${l} ${counts[l]}`).join(" · ")}\n\n`;
  out += `Columns follow the directive: decision | value | source app | screen / element | evidence | evidence level (+ method/precision).\n`;
  for (const surface of Object.keys(bySurface).sort()) {
    const { tokens: ts, copy: cs } = bySurface[surface];
    out += `\n## \`${surface}\`\n\n| decision | value | source app | screen / element | evidence | level | method / precision |\n|---|---|---|---|---|---|---|\n`;
    for (const [name, t] of ts.sort((a, b) => a[0].localeCompare(b[0]))) out += `| \`${name}\` | ${mdCell(fmtValue(t))} | ${mdCell(t.source_app)} | ${mdCell(t.element)} | ${mdCell(t.evidence)} | ${t.level} | ${mdCell([t.method, t.precision, t.notes].filter(Boolean).join(" · "))} |\n`;
    for (const [key, s] of cs.sort((a, b) => a[0].localeCompare(b[0]))) out += `| copy \`${key}\` | “${mdCell(s.text)}” | ${mdCell(s.source_app)} | ${mdCell(s.origin)} | ${mdCell(s.evidence)} | ${isBlockedString(s) ? "BLOCKED" : s.level} | ${mdCell([s.pattern, s.notes].filter(Boolean).join(" · "))} |\n`;
  }
  return out;
}
function genCopyMd() {
  let out = `# COPY — every user-facing string\n\nGenerated by \`tools/designgen.mjs\`. The voice patterns below are maintained in \`design/copy-patterns.md\`; the string table is generated from \`design/copy.json\`.\n\n`;
  if (exists("design/copy-patterns.md")) out += fs.readFileSync(path.join(ROOT, "design/copy-patterns.md"), "utf8") + "\n";
  out += `\n## Strings\n\n| key | text | origin | pattern followed | source app · surface | evidence | level |\n|---|---|---|---|---|---|---|\n`;
  for (const [key, s] of Object.entries(strings).sort((a, b) => a[0].localeCompare(b[0]))) out += `| \`${key}\` | “${mdCell(s.text)}” | ${s.origin} | ${mdCell(s.pattern ?? "")} | ${mdCell(s.source_app)} · \`${s.surface}\` | ${mdCell(s.evidence)} | ${isBlockedString(s) ? "BLOCKED" : s.level} |\n`;
  return out;
}
function genBlocked() {
  let out = `# BLOCKED values\n\nGenerated. These may not ship; release builds fail to compile if code uses any of them.\n\n| item | surface | why |\n|---|---|---|\n`;
  for (const [n, t] of Object.entries(tokens)) if (isBlockedToken(t)) out += `| token \`${n}\` | ${t.surface} | ${mdCell(t.notes ?? t.evidence)} |\n`;
  for (const [k, s] of Object.entries(strings)) if (isBlockedString(s)) out += `| copy \`${k}\` | ${s.surface} | ${s.level === "BLOCKED" ? mdCell(s.notes ?? s.evidence) : "uses {app_name}; owner has not named the app"} |\n`;
  return out;
}

// ---------- iOS Info.plist strings ----------
// Copy entries with "infoPlistKey" (e.g. NSCameraUsageDescription) become INFOPLIST_KEY_* build
// settings, so purpose strings are traced like every other string.
function genInfoPlistXcconfig() {
  let out = "// GENERATED by tools/designgen.mjs from design/copy.json — do not edit.\n";
  for (const [key, s] of Object.entries(strings).sort((a, b) => a[0].localeCompare(b[0]))) {
    if (!s.infoPlistKey) continue;
    if (isBlockedString(s)) { out += `// ${s.infoPlistKey}: BLOCKED (${key})\n`; continue; }
    const v = resolveText(s).replace(/\\/g, "\\\\").replace(/\$/g, "$$$$").replace(/\/\//g, "/$()/");
    out += `// ${key} — ${s.source_app} · ${s.surface} · ${s.level}\nINFOPLIST_KEY_${s.infoPlistKey} = ${v}\n`;
  }
  return out;
}

// ---------- write ----------
const SW = "ios/Packages/AppCore/Sources/DesignSystem/Generated";
wr(`${SW}/Tokens.swift`, genSwiftTokens(false));
wr(`${SW}/BlockedTokens.swift`, genSwiftTokens(true));
wr(`${SW}/Copy.swift`, genSwiftCopy(false));
wr(`${SW}/BlockedCopy.swift`, genSwiftCopy(true));
wr("ios/Config/InfoPlist.generated.xcconfig", genInfoPlistXcconfig());
wr("android/core/designsystem/src/main/kotlin/app/designsystem/generated/Tokens.kt", genKotlinTokens());
wr("android/core/designsystem/src/main/res/values/strings.xml", genStringsXml(false));
wr("android/core/designsystem/src/debug/res/values/strings_blocked.xml", genStringsXml(true));
wr("backend/worker/src/generated/copy.ts", genTs());
wr("backend/worker/src/generated/tokens.ts", genTsTokens());
wr("web/src/generated/tokens.ts", genTsTokens());
wr("web/src/generated/copy.ts", genTs());
wr("design/SOURCES.md", genSources());
wr("design/COPY.md", genCopyMd());
wr("design/BLOCKED.md", genBlocked());
console.log(`designgen: generated (${Object.keys(tokens).length} tokens, ${Object.keys(strings).length} strings, app name ${appName ? "set" : "BLOCKED"})`);
