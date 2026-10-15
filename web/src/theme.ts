// Per-invite theme (design/surfaces/invite.web.md "Theme"): the page background is one solid
// colour taken from the cover (invite.web.layout.theme); text is black or white, whichever has the
// higher WCAG 2.2 contrast against it (invite.web.layout.themeTextColour), at Partiful's fixed
// alphas. Also the WCAG 2.2 contrast arithmetic used by the tests and the verification report.

import { hexRgb, str } from "./design.js";

export type Rgb = [number, number, number];
export type Scheme = "light" | "dark";

export interface Theme {
  /** Page background, "#RRGGBB". */
  background: string;
  /** light = black text (.ptf-light), dark = white text (.ptf-dark). */
  scheme: Scheme;
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

export const TEXT_LIGHT_SCHEME = (): Rgb => hexRgb(str("invite.web.color.text.light"));
export const TEXT_DARK_SCHEME = (): Rgb => hexRgb(str("invite.web.color.text.dark"));

/** The text colour set for a theme colour (higher WCAG contrast wins; ties go to light/black). */
export function schemeFor(background: Rgb): Scheme {
  const black = contrastRatio(TEXT_LIGHT_SCHEME(), background);
  const white = contrastRatio(TEXT_DARK_SCHEME(), background);
  return white > black ? "dark" : "light";
}

export function themeFromColour(background: Rgb): Theme {
  return { background: toHex(background), scheme: schemeFor(background) };
}

/** The default theme (no cover, and every non-ideal state). */
export function defaultTheme(): Theme {
  return themeFromColour(hexRgb(str("invite.web.color.theme.default")));
}

/** Text colour of a scheme. */
export const textColour = (scheme: Scheme): Rgb => (scheme === "light" ? TEXT_LIGHT_SCHEME() : TEXT_DARK_SCHEME());
