// Access to the generated design constants (tools/designgen.mjs → src/generated/). UI code reads
// tokens and copy only through this module; it holds no design value of its own, only the mapping
// from token values to CSS (colour syntax, weight numbers, easing curves, font stacks).
//
// designgen leaves BLOCKED strings (e.g. every string containing {app_name} while the owner has
// not named the app) out of src/generated/copy.ts. Every key the pages need is listed in
// REQUIRED_COPY: production refuses to start while one is missing, development renders a visible
// marker in its place.
//
// Appearance: the invite page has one appearance. Retro's web pages have no dark scheme
// (references/auto/retro/web/retro.app-web-copy-excerpts.txt "prefers-color-scheme: dark changes
// nothing"; design/research/retro-package-copy-motion.md §7), and design/surfaces/invite.web.md /
// design/MERGE_DECISIONS.md RA-19 keep it "the same in both appearances". Colour tokens that carry
// {light, dark} are therefore read at their light value (PAGE_APPEARANCE) whatever the viewer's
// prefers-color-scheme, and the page declares `color-scheme: light`.

import { copy } from "./generated/copy.js";
import { tokens, type TokenName } from "./generated/tokens.js";

export { tokens };
export type { TokenName };

export const REQUIRED_COPY = [
  "invite.web.documentTitle",
  "invite.web.og.title",
  "invite.web.og.description",
  "invite.web.invitedBy",
  "invite.web.invitedFallback",
  "invite.web.body",
  "invite.web.cta",
  "invite.web.opening",
  "invite.web.desktop.scan",
  "invite.web.footer.terms",
  "invite.web.footer.privacy",
  "invite.web.cover.alt",
  "invite.web.avatar.alt",
  "invite.web.members.title",
  "invite.web.getApp",
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

// ---------- numbers ----------

export function num(name: TokenName): number {
  const v = tokens[name];
  if (typeof v !== "number") throw new Error(`token ${name} is not a number`);
  return v;
}

/** A numeric token in CSS px (1 pt = 1 CSS px). */
export const px = (name: TokenName): string => `${num(name)}px`;

export function str(name: TokenName): string {
  const v = tokens[name];
  if (typeof v !== "string") throw new Error(`token ${name} is not a string`);
  return v;
}

export function layout<T = Record<string, unknown>>(name: TokenName): T {
  const v = tokens[name];
  if (typeof v !== "object" || v === null) throw new Error(`token ${name} is not a layout object`);
  return v as T;
}

/**
 * A number written inside a layout token's prose (e.g. invite.web.layout.ogImage.avatar "… circle, 83 px, centred;
 * top at 208 px"). `pattern` must capture the number; a token whose wording changes fails loudly instead of
 * silently falling back.
 */
export function layoutNumber(name: TokenName, field: string, pattern: RegExp): number {
  const v = layout<Record<string, unknown>>(name)[field];
  if (typeof v === "number") return v;
  const m = typeof v === "string" ? pattern.exec(v) : null;
  if (!m?.[1]) throw new Error(`token ${name}.${field}: ${JSON.stringify(v)} does not match ${pattern}`);
  return Number(m[1]);
}

// ---------- colours ----------

export type Rgb = [number, number, number];
export interface Rgba {
  rgb: Rgb;
  alpha: number;
}

/** The appearance the page is drawn in (see the header comment). */
export const PAGE_APPEARANCE = "light" as const;

/** The hex value of a colour token in the page's appearance ({light, dark} tokens resolve to PAGE_APPEARANCE). */
export function colorHex(name: TokenName): string {
  const v = tokens[name] as unknown;
  if (typeof v === "string") return v;
  if (typeof v === "object" && v !== null && typeof (v as Record<string, unknown>)[PAGE_APPEARANCE] === "string") {
    return (v as Record<string, string>)[PAGE_APPEARANCE]!;
  }
  throw new Error(`token ${name} is not a colour`);
}

/** "#RRGGBB" or "#RRGGBBAA" → channels (0–255) and alpha (0–1). */
export function parseHex(hex: string): Rgba {
  const m = /^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})?$/i.exec(hex);
  if (!m) throw new Error(`not a #RRGGBB[AA] colour: ${hex}`);
  return { rgb: [parseInt(m[1]!, 16), parseInt(m[2]!, 16), parseInt(m[3]!, 16)], alpha: m[4] ? parseInt(m[4], 16) / 255 : 1 };
}

export const rgba = (name: TokenName): Rgba => parseHex(colorHex(name));

/** CSS colour of a colour token, optionally at an extra opacity (an opacity token's value). */
export function cssColor(name: TokenName, opacity = 1): string {
  const { rgb, alpha } = rgba(name);
  const a = +(alpha * opacity).toFixed(4);
  return a === 1 ? `rgb(${rgb.join(" ")})` : `rgb(${rgb.join(" ")} / ${a})`;
}

// ---------- type and motion ----------

/** CSS font-weight number for a named weight token (CSS Fonts 4 §2.2 weight names ↔ numbers). */
export function cssWeight(name: TokenName): number {
  const w = String(tokens[name]).toLowerCase();
  const map: Record<string, number> = { thin: 100, ultralight: 200, light: 300, regular: 400, medium: 500, semibold: 600, bold: 700, heavy: 800, black: 900 };
  const n = map[w];
  if (n === undefined) throw new Error(`token ${name}: unknown weight ${w}`);
  return n;
}

/** CSS timing function of an easing token: {x1, y1, x2, y2} → cubic-bezier(). */
export function cssEasing(name: TokenName): string {
  const v = tokens[name] as unknown as { x1?: number; y1?: number; x2?: number; y2?: number };
  if ([v?.x1, v?.y1, v?.x2, v?.y2].some((n) => typeof n !== "number")) throw new Error(`token ${name} is not a cubic-bezier easing`);
  return `cubic-bezier(${v.x1}, ${v.y1}, ${v.x2}, ${v.y2})`;
}

/**
 * CSS font stack for a font token (PLATFORM: the page loads no web font, so every face is one the visitor's system
 * already has; Retro's own faces — Roslindale, SF Pro Display by name — are never referenced or bundled):
 *
 * - `font.global.family` {ios: "system", android: "Inter"} → `-apple-system, BlinkMacSystemFont, system-ui,
 *   sans-serif`: -apple-system / BlinkMacSystemFont select SF Pro in Safari / Chromium on Apple platforms (the iOS
 *   value "system", and the face of Retro's web stack 'SF Pro Display, -apple-system, BlinkMacSystemFont, …');
 *   system-ui is the platform UI face elsewhere (Roboto on Android, Segoe UI on Windows) — Inter is the Android app's
 *   bundled face and is not installed on visitors' devices; sans-serif is the last resort.
 * - `font.global.display` {ios: "system-serif", android: "serif"} → `ui-serif, "Noto Serif", serif`: ui-serif is
 *   New York in Safari on Apple platforms (the iOS value "system-serif"); "Noto Serif" is Android's serif (the
 *   Android value "serif") when a browser does not map the generic family to it; serif is the generic fallback
 *   (Times on desktops without either face).
 */
export function cssFontStack(name: TokenName): string {
  const v = tokens[name] as unknown as { ios?: string; android?: string };
  if (v?.ios === "system") return "-apple-system, BlinkMacSystemFont, system-ui, sans-serif";
  if (v?.ios === "system-serif" && v?.android === "serif") return 'ui-serif, "Noto Serif", serif';
  throw new Error(`token ${name}: no web font stack for ${JSON.stringify(v)}`);
}

/**
 * GAP — backdrop blur radius (design/surfaces/invite.web.md "Gaps"; design/components.md C-34: "blur radius not
 * measurable"). Approximation until a token exists: a Gaussian with σ = 5 % of the backdrop's width. Method: the
 * low-frequency fall-off of Retro's own stock invite backdrop (references/auto/retro/web/
 * retro.app-invite-background-bg2.jpeg, 673 px wide) fits σ ≈ 28–38 px (4–6 % of its width) under a 1/f² source
 * model; the fit rests on two spectrum bins, so it is recorded as approximated (design/verification/invite.web.md).
 */
export const BACKDROP_BLUR_OF_WIDTH = 0.05; // provenance-ok: Gap approximation documented above
