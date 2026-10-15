// Access to the generated design constants (tools/designgen.mjs → src/generated/). UI code reads
// tokens and copy only through this module; it holds no design value of its own.
//
// designgen leaves BLOCKED strings (e.g. every string containing {app_name} while the owner has
// not named the app) out of src/generated/copy.ts. Every key the pages need is listed in
// REQUIRED_COPY: production refuses to start while one is missing, development renders a visible
// marker in its place.

import { copy } from "./generated/copy.js";
import { tokens, type TokenName } from "./generated/tokens.js";

export { tokens };
export type { TokenName };

export const REQUIRED_COPY = [
  "invite.web.documentTitle",
  "invite.web.cover.alt",
  "invite.web.invitedBy",
  "invite.web.members.title",
  "invite.web.members.viewAll",
  "invite.web.gate.title",
  "invite.web.gate.body",
  "invite.web.getApp",
  "invite.web.state.glyph",
  "invite.web.state.glyphLabel",
  "invite.web.notFound.title",
  "invite.web.notFound.documentTitle",
  "invite.web.unavailable.title",
  "invite.web.unavailable.body",
  "invite.web.error.title",
  "invite.web.error.body",
  "invite.web.error.retry",
  "invite.web.rateLimited.body",
] as const;
export type RequiredCopyKey = (typeof REQUIRED_COPY)[number];

const table: Readonly<Record<string, string>> = copy;

/** Required keys that the generated table does not contain (BLOCKED or not yet written). */
export function missingCopy(source: Readonly<Record<string, string>> = table): RequiredCopyKey[] {
  return REQUIRED_COPY.filter((k) => typeof source[k] !== "string");
}

/** Text shown in development in place of a BLOCKED string, so it cannot go unnoticed. */
export const blockedMarker = (key: string): string => `[BLOCKED ${key}]`;

/** A copy string with its {placeholders} filled. Placeholder values are data, inserted as-is. */
export function text(key: RequiredCopyKey, params: Record<string, string> = {}, source: Readonly<Record<string, string>> = table): string {
  const raw = source[key];
  if (typeof raw !== "string") return blockedMarker(key);
  return raw.replace(/\{([a-zA-Z_][a-zA-Z0-9_]*)\}/g, (m, p: string) => (p in params ? params[p]! : m));
}

/** A numeric token in CSS px (1 pt = 1 CSS px). */
export function px(name: TokenName): string {
  const v = tokens[name];
  if (typeof v !== "number") throw new Error(`token ${name} is not a number`);
  return `${v}px`;
}

export function num(name: TokenName): number {
  const v = tokens[name];
  if (typeof v !== "number") throw new Error(`token ${name} is not a number`);
  return v;
}

export function str(name: TokenName): string {
  const v = tokens[name];
  if (typeof v !== "string") throw new Error(`token ${name} is not a string`);
  return v;
}

export function layout<T = Record<string, string | number>>(name: TokenName): T {
  const v = tokens[name];
  if (typeof v !== "object" || v === null) throw new Error(`token ${name} is not a layout object`);
  return v as T;
}

/** "#RRGGBB" → [r, g, b] (0–255). */
export function hexRgb(hex: string): [number, number, number] {
  const m = /^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(hex);
  if (!m) throw new Error(`not a #RRGGBB colour: ${hex}`);
  return [parseInt(m[1]!, 16), parseInt(m[2]!, 16), parseInt(m[3]!, 16)];
}

/** CSS colour from a colour token (or #RRGGBB) and an optional alpha token value. */
export function cssColor(hex: string, alpha = 1): string {
  const [r, g, b] = hexRgb(hex);
  return alpha === 1 ? `rgb(${r} ${g} ${b})` : `rgb(${r} ${g} ${b} / ${alpha})`;
}

/** CSS font-weight number for a named weight token (CSS Fonts 4 §2.2 weight names ↔ numbers). */
export function cssWeight(name: TokenName): number {
  const w = String(tokens[name]).toLowerCase();
  const map: Record<string, number> = { thin: 100, ultralight: 200, light: 300, regular: 400, medium: 500, semibold: 600, bold: 700, heavy: 800, black: 900 };
  const n = map[w];
  if (n === undefined) throw new Error(`token ${name}: unknown weight ${w}`);
  return n;
}

/** CSS timing-function keyword for an easing token ("easeOut" → "ease-out"). */
export function cssEasing(name: TokenName): string {
  const v = String(tokens[name]);
  const map: Record<string, string> = { linear: "linear", easeIn: "ease-in", easeOut: "ease-out", easeInOut: "ease-in-out" };
  const k = map[v];
  if (!k) throw new Error(`token ${name}: unsupported easing ${v}`);
  return k;
}

/** CSS generic family for a font token ({ios: "system", android: "system"} → the platform UI font). */
export function cssFontFamily(name: TokenName): string {
  const v = tokens[name] as { ios?: string; android?: string };
  if (v?.ios === "system" && v?.android === "system") return "-apple-system, system-ui, sans-serif";
  throw new Error(`token ${name}: only the platform font is supported on the web`);
}
