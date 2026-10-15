// WCAG 2.2 contrast of every text/background (and control/background) pair the invite page draws,
// for a given theme. Values are the sourced ones; nothing here adjusts them — failures are
// reported (design/verification/invite.web.md, development log), never corrected.
//
// Thresholds: layout.global.contrast.{text,largeText,nonText} (W3C WCAG 2.2 SC 1.4.3 / 1.4.11).
// "Large" follows WCAG's web definition: ≥ 24 CSS px, or ≥ 18.66 CSS px (14 pt) at weight ≥ 700.

import { cssWeight, hexRgb, num, str, tokens, type TokenName } from "./design.js";
import { contrastRatio, defaultTheme, over, textColour, toHex, type Rgb, type Theme } from "./theme.js";

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

/** Pairs on the invite page (valid state) for `theme`; `titleSize` = rendered title size in px. */
export function invitePairs(theme: Theme, titleSize = num("invite.web.fontSize.title.min")): PairResult[] {
  const s = theme.scheme;
  const bg = hexRgb(theme.background);
  const fg = textColour(s);
  const a = (n: TokenName) => num(n);
  const card: Rgb =
    s === "light"
      ? over(hexRgb(str("invite.web.color.gateCard.light")), a("invite.web.opacity.gateCard.light"), bg)
      : over(hexRgb(str("invite.web.color.gateCard.dark")), a("invite.web.opacity.gateCard.dark"), bg);
  const disc = over(fg, s === "light" ? a("invite.web.opacity.avatar.minimal.fill.light") : a("invite.web.opacity.avatar.minimal.fill.dark"), bg);
  const pill = over(fg, a("invite.web.opacity.button.outlined.fill"), bg);
  const fillHex = s === "light" ? str("invite.web.color.button.filled.fill.light") : str("invite.web.color.button.filled.fill.dark");
  const labelHex = s === "light" ? str("invite.web.color.button.filled.label.light") : str("invite.web.color.button.filled.label.dark");
  const body = a("invite.web.fontSize.body");
  const bold = cssWeight("invite.web.fontWeight.title");
  return [
    pair(`title (${titleSize} px bold)`, textKind(titleSize, bold), fg, bg),
    pair("'Invited by …' (16 px, text alpha 0.8)", textKind(body, 400), over(fg, a("invite.web.opacity.text.body"), bg), bg),
    pair("'Member List' header (18 px bold)", textKind(a("invite.web.fontSize.sectionHeader"), cssWeight("invite.web.fontWeight.sectionHeader")), fg, bg),
    pair("'View all' label (14 px semibold) on its 0.05 fill", "text", fg, pill),
    pair("'View all' border vs page", "nontext", over(fg, s === "light" ? a("invite.web.opacity.button.outlined.border.light") : a("invite.web.opacity.button.outlined.border.dark"), bg), bg),
    pair("initials (16 px, alpha 0.8) on the initials disc", "text", over(fg, a("invite.web.opacity.avatar.minimal.text"), disc), disc),
    pair("member names in 'View all' (16 px semibold)", "text", fg, bg),
    pair("'Restricted Access' (18 px bold) on the card", textKind(a("invite.web.fontSize.sectionHeader"), cssWeight("invite.web.fontWeight.sectionHeader")), fg, card),
    pair("card body (14 px, alpha 0.8) on the card", "text", over(fg, a("invite.web.opacity.text.body"), card), card),
    pair("lock glyph on the card", "nontext", fg, card),
    pair("'Get the app' button label on its fill", "text", hexRgb(labelHex), hexRgb(fillHex)),
    pair("'Get the app' button fill vs the card", "nontext", hexRgb(fillHex), card),
    pair("footer 'Get the app' link (16 px semibold)", "text", fg, bg),
    pair("footer arrow glyph (alpha 0.8)", "nontext", over(fg, a("invite.web.opacity.footer.arrow"), bg), bg),
    pair("focus ring (1 px, text colour)", "nontext", fg, bg),
  ];
}

/** Pairs on the non-ideal state pages (default theme). */
export function statePairs(): PairResult[] {
  const theme = defaultTheme();
  const bg = hexRgb(theme.background);
  const fg = textColour(theme.scheme);
  const fillHex = theme.scheme === "light" ? str("invite.web.color.button.filled.fill.light") : str("invite.web.color.button.filled.fill.dark");
  const labelHex = theme.scheme === "light" ? str("invite.web.color.button.filled.label.light") : str("invite.web.color.button.filled.label.dark");
  return [
    pair("state title (24 px bold, uppercase)", textKind(num("invite.web.fontSize.state.title"), cssWeight("invite.web.fontWeight.state.title")), fg, bg),
    pair("state body (14 px, alpha 0.8)", "text", over(fg, num("invite.web.opacity.text.body"), bg), bg),
    pair("'Try again' button label on its fill", "text", hexRgb(labelHex), hexRgb(fillHex)),
    pair("'Try again' button fill vs page", "nontext", hexRgb(fillHex), bg),
    pair("footer 'Get the app' link", "text", fg, bg),
    pair("footer arrow glyph (alpha 0.8)", "nontext", over(fg, num("invite.web.opacity.footer.arrow"), bg), bg),
  ];
}
