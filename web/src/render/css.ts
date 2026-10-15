// Surface: invite.web — reference app: Partiful (event invite page).
// Reference images: references/auto/partiful/web/pf-web-private-past-01..03.png,
// pf-web-public-light-01..04.png, pf-web-public-dark-01..04.png, pf-web-notfound-01.png
// (design/surfaces/invite.web.md).
//
// The page stylesheet, built from tokens only. Colours are the theme's text colour at the token
// alphas; sizes are token values in CSS px (1 pt = 1 px). Literal numbers in this file are CSS
// mechanics (0, 100%, flex), never design values.

import { cssColor, cssEasing, cssFontFamily, cssWeight, layout, num, px, str } from "../design.js";
import type { Scheme, Theme } from "../theme.js";
import type { SizeStep } from "../titleFit.js";

const fgHex = (s: Scheme) => (s === "light" ? str("invite.web.color.text.light") : str("invite.web.color.text.dark"));
const fg = (s: Scheme, alpha = 1) => cssColor(fgHex(s), alpha);
const pick = (s: Scheme, light: number, dark: number) => (s === "light" ? light : dark);

function base(theme: Theme): string {
  const s = theme.scheme;
  const text = layout<{ fontSmoothing: string }>("invite.web.layout.text");
  const link = layout<{ textDecoration: string }>("invite.web.layout.link");
  const colourT = `${num("invite.web.duration.button.colour")}ms ${cssEasing("invite.web.easing.button")}`;
  const opacityT = `${num("invite.web.duration.button.opacity")}ms ${cssEasing("invite.web.easing.button")}`;
  const outlinedBorder = pick(s, num("invite.web.opacity.button.outlined.border.light"), num("invite.web.opacity.button.outlined.border.dark"));
  const borderW = px("invite.web.dimension.button.outlined.border");
  return `
*,*::before,*::after{box-sizing:border-box}
html{background:${theme.background};color-scheme:${s === "dark" ? "dark" : "light"};-webkit-text-size-adjust:100%}
body{margin:0;font-family:${cssFontFamily("invite.web.font")};font-size:${px("invite.web.fontSize.body")};font-weight:${cssWeight("invite.web.fontWeight.body")};line-height:${num("invite.web.lineHeight.default")};color:${fg(s)};-webkit-font-smoothing:${text.fontSmoothing};-moz-osx-font-smoothing:grayscale}
.page{min-height:100vh;min-height:100dvh;display:flex;flex-direction:column;align-items:center}
.column{width:100%;max-width:${px("invite.web.dimension.columnMaxWidth")};padding:0 ${px("invite.web.dimension.margin")};container-type:inline-size}
a{color:inherit;text-decoration:${link.textDecoration}}
:focus-visible{outline:${borderW} solid ${fg(s)};outline-offset:${px("invite.web.dimension.focus.offset")}}
.btn{display:inline-flex;align-items:center;justify-content:center;gap:${px("invite.web.dimension.button.gap")};font-weight:${cssWeight("invite.web.fontWeight.button")};white-space:nowrap;user-select:none;-webkit-user-select:none;cursor:pointer;transition:background-color ${colourT},color ${colourT},opacity ${opacityT}}
@media (any-hover:hover){.btn:hover{opacity:${num("invite.web.opacity.button.hover")}}}
.btn:active{opacity:${num("invite.web.opacity.button.active")}}
.btn-filled{height:${px("invite.web.dimension.button.large.height")};padding:0 ${px("invite.web.dimension.button.large.paddingH")};border:none;border-radius:${px("invite.web.radius.button.large")};font-size:${px("invite.web.fontSize.body")};background:${cssColor(s === "dark" ? str("invite.web.color.button.filled.fill.dark") : str("invite.web.color.button.filled.fill.light"))};color:${cssColor(s === "dark" ? str("invite.web.color.button.filled.label.dark") : str("invite.web.color.button.filled.label.light"))}}
.btn-outlined{height:${px("invite.web.dimension.button.medium.height")};padding:0 calc(${px("invite.web.dimension.button.medium.paddingH")} - ${borderW});border:${borderW} solid ${fg(s, outlinedBorder)};border-radius:${px("invite.web.radius.button.medium")};font-size:${px("invite.web.fontSize.button.medium")};background:${fg(s, num("invite.web.opacity.button.outlined.fill"))};-webkit-backdrop-filter:blur(${px("invite.web.blur.button.outlined")});backdrop-filter:blur(${px("invite.web.blur.button.outlined")})}
@media (any-hover:hover){.btn-outlined:hover{background:${fg(s, num("invite.web.opacity.button.outlined.hover.fill"))};border-color:${fg(s, outlinedBorder)};opacity:1}}
.btn-outlined:active{background:${fg(s, num("invite.web.opacity.button.outlined.active.fill"))};border-color:${fg(s, num("invite.web.opacity.button.outlined.active.border"))};opacity:1}
summary{list-style:none}
summary::-webkit-details-marker{display:none}
footer{align-self:stretch;margin-top:auto;padding-top:${px("invite.web.dimension.footer.paddingTop")}}
.divider{border-bottom:${borderW} solid ${fg(s, num("invite.web.opacity.footer.divider"))}}
.footer-content{display:flex;flex-direction:column;align-items:center;padding:${px("invite.web.dimension.footer.contentPaddingV")} ${px("invite.web.dimension.margin")}}
.get-app{display:inline-flex;align-items:center;gap:${px("invite.web.dimension.footer.linkGap")};font-weight:${cssWeight("invite.web.fontWeight.button")};transition:color ${colourT}}
.get-app svg{width:${px("invite.web.dimension.footer.arrow")};height:${px("invite.web.dimension.footer.arrow")};color:${fg(s, num("invite.web.opacity.footer.arrow"))}}
`;
}

/** Stylesheet of the invite page (valid state). */
export function inviteCss(theme: Theme, steps: SizeStep[]): string {
  const s = theme.scheme;
  const title = layout<{ textAlign: string }>("invite.web.layout.title");
  const [first, ...rest] = steps;
  const sizeRules = rest.map((st) => `@container (min-width:${st.minWidth}px){.title{font-size:${st.size}px}}`).join("\n");
  const avatar = px("invite.web.dimension.avatar");
  const card = s === "light"
    ? cssColor(str("invite.web.color.gateCard.light"), num("invite.web.opacity.gateCard.light"))
    : cssColor(str("invite.web.color.gateCard.dark"), num("invite.web.opacity.gateCard.dark"));
  return (
    base(theme) +
    `
.invite{padding-top:${px("invite.web.dimension.titleTop")}}
.title{margin:0 0 ${px("invite.web.dimension.titleToCover")};text-align:${title.textAlign};font-weight:${cssWeight("invite.web.fontWeight.title")};line-height:${num("invite.web.lineHeight.title")};letter-spacing:${num("invite.web.letterSpacing.title")}em;font-size:${first ? first.size : num("invite.web.fontSize.title.min")}px;overflow-wrap:break-word}
${sizeRules}
.cover{display:block;width:100%;height:auto;border-radius:${px("invite.web.radius.cover")};margin:0 0 ${px("invite.web.dimension.coverToNext")}}
.field{margin:0;padding:${px("invite.web.dimension.fieldRow.paddingV")} 0;color:${fg(s, num("invite.web.opacity.text.body"))}}
.members{position:relative;margin-top:${px("invite.web.dimension.sectionGap")}}
.members-head{display:flex;align-items:center;min-height:${px("invite.web.dimension.button.medium.height")}}
.section-title{margin:0;font-size:${px("invite.web.fontSize.sectionHeader")};font-weight:${cssWeight("invite.web.fontWeight.sectionHeader")};line-height:${num("invite.web.lineHeight.default")}}
.avatars{list-style:none;margin:${px("invite.web.dimension.headerToAvatars")} 0 0;padding:0;display:flex;flex-wrap:wrap;gap:${px("invite.web.dimension.avatarGap")}}
.avatar{display:block;width:${avatar};height:${avatar};border-radius:${px("invite.web.radius.avatar")};object-fit:cover}
.initials{display:flex;align-items:center;justify-content:center;width:${avatar};height:${avatar};border-radius:${px("invite.web.radius.avatar")};background:${fg(s, pick(s, num("invite.web.opacity.avatar.minimal.fill.light"), num("invite.web.opacity.avatar.minimal.fill.dark")))};color:${fg(s, num("invite.web.opacity.avatar.minimal.text"))};font-size:${px("invite.web.fontSize.body")};font-weight:${cssWeight("invite.web.fontWeight.body")}}
.all>summary{position:absolute;top:0;right:0}
.rows{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:${px("invite.web.dimension.userRow.listGap")}}
.row{display:flex;align-items:center;gap:${px("invite.web.dimension.userRow.columnGap")};padding:${px("invite.web.dimension.userRow.paddingV")} 0}
.row-name{font-weight:${cssWeight("invite.web.fontWeight.userRow.name")}}
.gate{margin-top:${px("invite.web.dimension.sectionGap")};padding:${px("invite.web.dimension.gateCard.padding")};border-radius:${px("invite.web.radius.gateCard")};background:${card};display:flex;flex-direction:column;align-items:center;text-align:center}
.lock{display:block;width:${px("invite.web.dimension.gateCard.glyph")};height:${px("invite.web.dimension.gateCard.glyph")}}
.gate .section-title{margin-top:${px("invite.web.dimension.gateCard.glyphToTitle")}}
.gate-body{margin:${px("invite.web.dimension.gateCard.titleToBody")} 0 0;font-size:${px("invite.web.fontSize.detail")};color:${fg(s, num("invite.web.opacity.text.body"))}}
.gate .btn-filled{margin-top:${px("invite.web.dimension.gateCard.bodyToButton")};width:100%}
`
  );
}

/** Stylesheet of the non-ideal states (not found, link no longer works, error). */
export function stateCss(theme: Theme): string {
  const s = theme.scheme;
  const t = layout<{ textTransform: string; textAlign: string }>("invite.web.layout.state.title");
  return (
    base(theme) +
    `
.header-space{flex:none;height:${px("invite.web.dimension.state.headerSpace")}}
.state{margin-top:auto;margin-bottom:auto;display:flex;flex-direction:column;align-items:center;text-align:${t.textAlign}}
.glyph{margin:0 0 ${px("invite.web.dimension.state.glyphToTitle")};font-size:${px("invite.web.fontSize.state.glyph")};line-height:${num("invite.web.lineHeight.default")}}
.state-title{margin:0;font-size:${px("invite.web.fontSize.state.title")};font-weight:${cssWeight("invite.web.fontWeight.state.title")};line-height:${num("invite.web.lineHeight.default")};text-transform:${t.textTransform}}
.state-body{margin:${px("invite.web.dimension.gateCard.titleToBody")} 0 0;font-size:${px("invite.web.fontSize.detail")};color:${fg(s, num("invite.web.opacity.text.body"))}}
.state .btn-filled{margin-top:${px("invite.web.dimension.state.bodyToAction")}}
`
  );
}
