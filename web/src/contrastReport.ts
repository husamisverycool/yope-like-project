// WCAG 2.2 contrast of every text/background (and control/background) pair the invite page draws
// (design/surfaces/invite.web.md "Accessibility"). Values are the sourced ones; nothing here adjusts
// them — failures are reported (design/verification/invite.web.md, development log), never corrected.
//
// Thresholds: layout.global.contrast.{text,largeText,nonText} (W3C WCAG 2.2 SC 1.4.3 / 1.4.11).
// "Large" follows WCAG's definition for the web: 18 pt = 24 CSS px, or 14 pt = 18.66 CSS px at
// weight ≥ 700 (the token's "18 pt" is the app's point, which on the web is the CSS px; WCAG's point
// is 1/72 inch = 1.333 CSS px).
//
// On the mobile card the backdrop is a photo, so those pairs depend on the invite: they are computed
// for a backdrop colour (the spec's sample is Retro's #4A1D17; per invite, the mean of the blurred
// backdrop's lower half, where the text sits).

import { cssWeight, num, parseHex, rgba, tokens, type Rgb, type TokenName } from "./design.js";

export type Kind = "text" | "large" | "nontext";

export interface PairResult {
  element: string;
  kind: Kind;
  fg: string;
  bg: string;
  ratio: number;
  need: number;
  pass: boolean;
}

export const toHex = ([r, g, b]: Rgb): string =>
  "#" + [r, g, b].map((v) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, "0")).join("").toUpperCase();

/** WCAG 2.2 relative luminance of an sRGB colour (0–255 channels). */
export function relativeLuminance([r, g, b]: Rgb): number {
  const lin = (c: number) => {
    const s = c / 255;
    return s <= 0.04045 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
  };
  return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
}

/** WCAG 2.2 contrast ratio (1–21). */
export function contrastRatio(a: Rgb, b: Rgb): number {
  const la = relativeLuminance(a);
  const lb = relativeLuminance(b);
  const [hi, lo] = la > lb ? [la, lb] : [lb, la];
  return (hi + 0.05) / (lo + 0.05);
}

/** Source-over composite of `fg` at `alpha` on an opaque `bg` (how the browser paints rgb(… / a)). */
export function over(fg: Rgb, alpha: number, bg: Rgb): Rgb {
  return [0, 1, 2].map((i) => fg[i]! * alpha + bg[i]! * (1 - alpha)) as Rgb;
}

/** A colour token painted on an opaque background (its own alpha applied). */
const on = (name: TokenName, bg: Rgb, opacity = 1): Rgb => {
  const c = rgba(name);
  return over(c.rgb, c.alpha * opacity, bg);
};

const need = (kind: Kind): number => {
  const name = { text: "layout.global.contrast.text", large: "layout.global.contrast.largeText", nontext: "layout.global.contrast.nonText" }[kind];
  return (tokens[name as TokenName] as { ratio: number }).ratio;
};

export const textKind = (sizePx: number, weight: number): Kind => (sizePx >= 24 || (sizePx >= 18.66 && weight >= 700) ? "large" : "text");

function pair(element: string, kind: Kind, fg: Rgb, bg: Rgb): PairResult {
  const ratio = contrastRatio(fg, bg);
  const n = need(kind);
  return { element, kind, fg: toHex(fg), bg: toHex(bg), ratio, need: n, pass: ratio + 1e-9 >= n };
}

/** Retro's backdrop under the text in references/auto/retro/web/retro.app-u-nathan-iphone.png (spec sample). */
export const SPEC_BACKDROP_SAMPLE: Rgb = parseHex("#4A1D17").rgb; // provenance-ok: the spec's measured sample (invite.web.md Accessibility)

/** Pairs on the mobile card of a valid invite, over a backdrop colour. */
export function cardPairs(backdrop: Rgb): PairResult[] {
  const white = rgba("color.global.textOnMedia").rgb;
  const headline = num("fontSize.global.displayMedium");
  const pill = on("invite.web.color.pill", backdrop);
  return [
    pair(`headline (${headline} px regular, color.global.textOnMedia)`, textKind(headline, cssWeight("fontWeight.global.displayMedium")), white, backdrop),
    pair(`line (${num("invite.web.fontSize.body")} px, invite.web.color.body)`, "text", on("invite.web.color.body", backdrop), backdrop),
    pair(`'Let's go' label (${num("invite.web.fontSize.pill")} px ${cssWeight("invite.web.fontWeight.pill")}) on invite.web.color.pill`, textKind(num("invite.web.fontSize.pill"), cssWeight("invite.web.fontWeight.pill")), white, pill),
    pair("'Let's go' label on invite.web.color.pillHover", "text", white, on("invite.web.color.pillHover", backdrop)),
    pair("pill fill vs backdrop", "nontext", pill, backdrop),
    pair(`footer links (${num("invite.web.fontSize.footer")} px, color.global.textOnMedia)`, "text", white, backdrop),
  ];
}

/** Pairs of the desktop column (white page). */
export function desktopPairs(): PairResult[] {
  const page = rgba("color.global.background").rgb;
  const ink = rgba("color.global.textPrimary").rgb;
  const headline = num("invite.web.fontSize.headlineDesktop");
  return [
    pair(`headline (${headline} px regular, color.global.textPrimary)`, textKind(headline, 400), ink, page),
    pair(`line (${num("invite.web.fontSize.bodyDesktop")} px, invite.web.color.bodyDesktop)`, textKind(num("invite.web.fontSize.bodyDesktop"), 400), on("invite.web.color.bodyDesktop", page), page),
    pair(`'Download the app' (${num("fontSize.global.textButton")} px, color.global.textPrimary)`, textKind(num("fontSize.global.textButton"), cssWeight("fontWeight.global.textButton")), ink, page),
    pair(`footer links (${num("fontSize.global.caption")} px, invite.web.color.bodyDesktop)`, textKind(num("fontSize.global.caption"), cssWeight("fontWeight.global.caption")), on("invite.web.color.bodyDesktop", page), page),
    pair("QR modules (color.global.textPrimary) vs page", "nontext", ink, page),
  ];
}

/** Pairs of the state card (not found, link no longer works, error, too many requests): color.global.backgroundDeep. */
export function statePairs(): PairResult[] {
  return cardPairs(rgba("color.global.backgroundDeep").rgb);
}
