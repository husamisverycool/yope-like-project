#!/usr/bin/env node
// Enforces "no design decision is ours" in code (docs/CONVENTIONS.md §5):
//  1. design/tokens.json and design/copy.json validate (tools/designgen.mjs --check);
//  2. app UI code contains no literal colors, sizes, durations, fonts or user-facing strings —
//     only generated Tokens / Copy (Swift), Tokens / R.string (Kotlin), copy (TypeScript);
//  3. no forbidden taste-based reasoning in code, comments or docs.
// Exit code 1 lists every violation as file:line.
//
// A line may opt out only for non-design literals with a trailing marker naming why:
//   // provenance-ok: <reason>      (e.g. "0 = no offset", "accessibility identifier")

import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const violations = [];

try {
  execFileSync(process.execPath, [path.join(ROOT, "tools/designgen.mjs"), "--check"], { stdio: "pipe" });
} catch (e) {
  violations.push(`design files: ${String(e.stdout ?? "") + String(e.stderr ?? "")}`.trim());
}

function walk(dir, exts, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) {
      if (["build", ".build", "node_modules", "Generated", "generated", ".gradle", "DerivedData"].includes(e.name)) continue;
      walk(p, exts, out);
    } else if (exts.some((x) => e.name.endsWith(x))) out.push(p);
  }
  return out;
}
const isTest = (f) => /(Tests?|test|androidTest|testFixtures|Snapshots?|Previews?)\//.test(f) || /Tests?\.(swift|kt)$/.test(f);

const COLOR_NAMES = "white|black|red|green|blue|yellow|orange|pink|purple|gray|grey|brown|cyan|mint|teal|indigo";
const SWIFT_RULES = [
  [/\bColor\(\s*(red:|\.sRGB|hex|white:|hue:|"|uiColor)/, "literal Color — use Tokens.Colors.*"],
  [/\bUIColor\(\s*(red:|white:|hue:|named:)/, "literal UIColor — use Tokens.Colors.*"],
  [new RegExp(`(?<![A-Za-z])(Color|UIColor)\\.(${COLOR_NAMES})\\b`), "named system color — use Tokens.Colors.*"],
  [new RegExp(`\\.(foregroundStyle|foregroundColor|background|tint|fill|stroke)\\(\\s*\\.(${COLOR_NAMES})\\b`), "named system color — use Tokens.Colors.*"],
  [/\.font\(\s*\.(system|largeTitle|title|title2|title3|headline|subheadline|body|callout|footnote|caption|caption2)\b/, "literal font — use DS text styles built from tokens"],
  [/\bFont\.system\(\s*size:/, "literal font size — use Tokens.FontSizes.*"],
  [/\.(padding|offset)\(\s*(\.[a-z]+\s*,\s*)?-?[1-9][0-9.]*\s*\)/, "literal spacing — use Tokens.Sizes.*"],
  [/\b(width|height|minWidth|minHeight|maxWidth|maxHeight|spacing|cornerRadius|radius|lineWidth|blur|x|y):\s*-?[1-9][0-9.]*\b/, "literal size — use Tokens.*"],
  [/\.(opacity|blur)\(\s*(radius:\s*)?0?\.[0-9]+/, "literal opacity/blur — use Tokens.*"],
  [/\b(duration|delay|response|dampingFraction):\s*[0-9.]+/, "literal motion value — use Tokens.Durations/Springs"],
  [/\.(easeIn|easeOut|easeInOut|linear|spring|bouncy|snappy|smooth)\b(?!\s*\()/, "literal animation curve — use Tokens.Easings/Springs (unless PLATFORM token)"],
  [/\b(Text|Label|Button|Toggle|TextField|SecureField|Link|Section|Menu|Picker)\(\s*"[^"]*[A-Za-z][^"]*"/, "literal user-facing string — use Copy.*"],
  [/\.(navigationTitle|accessibilityLabel|accessibilityHint|alert|confirmationDialog|help)\(\s*"[^"]*[A-Za-z]/, "literal user-facing string — use Copy.*"],
  [/\bString\(localized:\s*"/, "inline localized string — add it to design/copy.json"],
];
const KOTLIN_RULES = [
  [/\bColor\(\s*0x[0-9A-Fa-f]+/, "literal Color — use Tokens.Colors.*"],
  [/\bColor\(\s*(red\s*=|[0-9.]+f?\s*,)/, "literal Color — use Tokens.Colors.*"],
  [new RegExp(`\\bColor\\.(White|Black|Red|Green|Blue|Yellow|Gray|Cyan|Magenta|LightGray|DarkGray)\\b`), "named color — use Tokens.Colors.*"],
  [/(?<![A-Za-z_.])[1-9][0-9.]*\.(dp|sp)\b/, "literal dp/sp — use Tokens.*"],
  [/\b(durationMillis|delayMillis)\s*=\s*[0-9]/, "literal duration — use Tokens.Durations.*"],
  [/\btween\(\s*[0-9]/, "literal duration — use Tokens.Durations.*"],
  [/\b(stiffness|dampingRatio)\s*=\s*[0-9]/, "literal spring — use Tokens.Springs.*"],
  [/\balpha\s*=\s*0?\.[0-9]+f?/, "literal opacity — use Tokens.Opacities.*"],
  [/\bText\(\s*(text\s*=\s*)?"[^"]*[A-Za-z]/, "literal user-facing string — use stringResource(R.string.*)"],
  [/\b(contentDescription|label|title|placeholder)\s*=\s*"[^"]*[A-Za-z]/, "literal user-facing string — use stringResource(R.string.*)"],
  [/\bfontSize\s*=\s*[0-9]/, "literal font size — use Tokens.FontSizes.*"],
];
const TS_UI_RULES = [
  [/#[0-9a-fA-F]{3,8}\b(?![^"'`]*generated)/, "literal color — use tokens"],
];
const PHRASES = /\b(looks clean|feels nice|a nice touch|for polish|a reasonable default|I think)\b|\bmodern\b(?![-_ ]?(?:concurrency|api|swift|android|kotlin))/i;

function scan(files, rules, { ui = true } = {}) {
  for (const f of files) {
    const rel = path.relative(ROOT, f);
    const lines = fs.readFileSync(f, "utf8").split("\n");
    lines.forEach((line, i) => {
      if (line.includes("provenance-ok:")) return;
      const code = line.replace(/\/\/.*$/, "");
      if (ui && !isTest(rel)) for (const [re, msg] of rules) if (re.test(code)) violations.push(`${rel}:${i + 1}: ${msg}\n      ${line.trim()}`);
      if (PHRASES.test(line)) violations.push(`${rel}:${i + 1}: forbidden taste-based wording (directive Part 2)\n      ${line.trim()}`);
    });
  }
}

// UI code: app targets. The DesignSystem primitives that *apply* tokens live in DesignSystem/ and are allowed
// to reference SwiftUI/Compose APIs with token arguments; they are scanned with the same rules.
scan(walk(path.join(ROOT, "ios"), [".swift"]), SWIFT_RULES);
// Android: data and model modules hold no UI (serialization names like @SerialName("text") are wire values).
const androidNonUi = (f) => /android\/core\/(data|model)\//.test(f);
scan(walk(path.join(ROOT, "android"), [".kt"]).filter((f) => !androidNonUi(f)), KOTLIN_RULES);
scan(walk(path.join(ROOT, "android"), [".kt"]).filter(androidNonUi), [], { ui: false });
scan(walk(path.join(ROOT, "web/src"), [".tsx", ".css"]), TS_UI_RULES);
scan(walk(path.join(ROOT, "backend"), [".ts", ".sql"]), [], { ui: false });
scan(walk(path.join(ROOT, "docs"), [".md"]).filter((f) => !f.endsWith("CONVENTIONS.md")), [], { ui: false });

if (violations.length) {
  console.error(violations.join("\n"));
  console.error(`\nprovenance-check: ${violations.length} violation(s)`);
  process.exit(1);
}
console.log("provenance-check: ok");
