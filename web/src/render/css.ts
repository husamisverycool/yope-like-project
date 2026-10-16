// Surface: invite.web — reference: Retro's /u/[username] invite page.
// Reference images: references/auto/retro/web/retro.app-u-nathan-iphone.png (mobile card),
// retro.app-u-nathan-pixel7.png, retro.app-u-nathan-desktop.png (desktop column), CSS
// references/auto/retro/web/retro.app-5bff8a0be69f7ec7.css (.page_mobileProfilePageContent,
// .page_invitePillButton, .page_mobileInviteFooter, .page_newProfilePageContent, .page_profilePicture,
// @media (max-width:840px)). Build spec: design/surfaces/invite.web.md.
//
// The page stylesheet, built from tokens only (sizes in CSS px, 1 pt = 1 px). Literal numbers in this
// file are CSS mechanics (0, 50%, 100%, 1, flex, z-order), never design values. `line-height: 1` where
// no line-height token exists is Retro's own reset (retro.app-c857ab11667cdfc8.css `body{line-height:1}`,
// which is why its h1 computes 32px/32px and 48px/48px). One appearance: see src/design.ts.
//
// Layout: one DOM for both layouts, like Retro's CSS: the desktop column is the default and
// `@media (max-width: invite.web.size.breakpoint)` turns it into the mobile card.

import { cssColor, cssEasing, cssFontStack, cssWeight, inviteBackdrop, num, px } from "../design.js";
import { fontFace } from "../fonts.js";

const capsule = (height: string) => `calc(${height} / 2)`; // radius.global.capsule: "height / 2"

export function pageCss(): string {
  const bp = px("invite.web.size.breakpoint");
  const minTarget = px("size.global.minTouchTarget.ios");
  const pillT = `background-color ${num("invite.web.duration.pill")}ms ${cssEasing("invite.web.easing.pill")}`;
  const memberGlyph = `${Math.min(num("size.global.avatarSmall"), num("size.global.icon"))}px`;
  // invite.web.layout.backdrop: Gaussian σ = blurSigmaToWidth × the card's width. CSS blur() takes σ; 100cqw is the
  // card's width (the card is an inline-size container). Browsers without container units get the viewport-based
  // width of the same card (100vw − 2 × inset) from the preceding declaration. The image extends 3σ past the card
  // (clipped) so the blur has photo, not transparency, at the card's edges.
  const backdrop = inviteBackdrop();
  const sigmaCq = `calc(${backdrop.blurSigmaToWidth} * 100cqw)`;
  const sigmaVw = `calc(${backdrop.blurSigmaToWidth} * (100vw - 2 * ${px("invite.web.size.cardInset")}))`;
  const bleedRule = (sigma: string) => `top:calc(-3 * ${sigma});left:calc(-3 * ${sigma});width:calc(100% + 6 * ${sigma});height:calc(100% + 6 * ${sigma});filter:blur(${sigma})`;
  return `
${fontFace("font.global.displayNarrow", cssWeight("fontWeight.global.displayMedium"))}
:root{color-scheme:light}
*,*::before,*::after{box-sizing:border-box}
html,body{margin:0;padding:0}
html{background:${cssColor("color.global.background")};-webkit-text-size-adjust:100%}
body{font-family:${cssFontStack("font.global.family")};color:${cssColor("color.global.textPrimary")};line-height:1}
h1,p,ul{margin:0;padding:0;font-weight:${cssWeight("fontWeight.global.body")}}
a{color:inherit;text-decoration:none}
img{display:block}
.hit{position:relative}
.hit::after{content:"";position:absolute;left:50%;top:50%;width:max(100%, ${minTarget});height:max(100%, ${minTarget});transform:translate(-50%, -50%)}

/* desktop column (.page_newProfilePageContent) */
.card{position:relative;isolation:isolate;min-height:100vh;min-height:100dvh;display:flex;flex-direction:column;align-items:center;text-align:center;overflow-wrap:break-word}
.backdrop,.mobile-only{display:none}
.hero{margin-top:auto;display:grid;place-items:center}
.hero>*{grid-area:1 / 1}
.qr{display:block;width:${px("invite.web.size.qrDesktop")};height:${px("invite.web.size.qrDesktop")};color:${cssColor("color.global.textPrimary")}}
.avatar{width:${px("invite.web.size.avatarDesktop")};height:${px("invite.web.size.avatarDesktop")};border-radius:50%;object-fit:cover;background:${cssColor("invite.web.color.avatarPlaceholder")}}
.text{display:flex;flex-direction:column;align-items:center;margin-bottom:${px("invite.web.size.bodyToQrDesktop")}}
.headline{margin-top:${px("invite.web.size.headlineTopDesktop")};font-family:${cssFontStack("font.global.displayNarrow")};font-size:${px("invite.web.fontSize.headlineDesktop")};font-weight:${cssWeight("fontWeight.global.displayMedium")};line-height:1;color:${cssColor("color.global.textPrimary")}}
.line{margin-top:${px("invite.web.size.headlineToBody")};max-width:${px("invite.web.size.bodyMaxWidthDesktop")};font-size:${px("invite.web.fontSize.bodyDesktop")};line-height:${px("invite.web.lineHeight.bodyDesktop")};letter-spacing:${px("invite.web.letterSpacing.body")};color:${cssColor("invite.web.color.bodyDesktop")}}
.link{display:inline-block;font-size:${px("fontSize.global.textButton")};font-weight:${cssWeight("fontWeight.global.textButton")};color:${cssColor("color.global.textPrimary")}}
.footer{margin:auto ${px("invite.web.size.footerMargin")} ${px("invite.web.size.footerMargin")};font-size:${px("fontSize.global.caption")};font-weight:${cssWeight("fontWeight.global.caption")};line-height:${px("lineHeight.global.caption")};color:${cssColor("invite.web.color.bodyDesktop")}}
[data-blocked]{cursor:default}

/* mobile card (.page_mobileProfilePageContent, .page_invitePillButton, .page_mobileInviteFooter) */
@media (max-width:${bp}){
.desktop-only,.qr{display:none}
.mobile-only{display:revert}
.page{min-height:100vh;min-height:100dvh;padding:${px("invite.web.size.cardInset")};display:flex}
.card{flex:1 1 auto;min-height:0;border-radius:${px("invite.web.radius.card")};overflow:hidden;background:${cssColor("color.global.backgroundDeep")};container-type:inline-size}
.backdrop{display:block;position:absolute;z-index:-1;object-fit:cover;${bleedRule(sigmaVw)};${bleedRule(sigmaCq)}}
.photo::after{content:"";position:absolute;inset:0;z-index:-1;background:${cssColor(backdrop.dim)}}
.hero{margin-top:0;flex:1 1 auto;display:flex;align-items:center;justify-content:center;width:100%}
.avatar{width:${px("invite.web.size.avatar")};height:${px("invite.web.size.avatar")}}
.text{margin-bottom:${px("invite.web.size.bodyToPill")}}
.headline{margin-top:0;max-width:${px("invite.web.size.textMaxWidth")};font-size:${px("fontSize.global.displayMedium")};line-height:${px("invite.web.lineHeight.headline")};color:${cssColor("color.global.textOnMedia")}}
.line{max-width:${px("invite.web.size.textMaxWidth")};font-size:${px("invite.web.fontSize.body")};line-height:${px("invite.web.lineHeight.body")};color:${cssColor("invite.web.color.body")}}
.members{display:flex;margin-top:${px("invite.web.size.headlineToBody")};list-style:none}
.members>li+li{margin-left:-${px("size.global.avatarStackOverlap")}}
.member{display:flex;align-items:center;justify-content:center;width:${px("size.global.avatarSmall")};height:${px("size.global.avatarSmall")};border-radius:50%;object-fit:cover;background:${cssColor("color.global.control")};color:${cssColor("color.global.textSecondary")}}
.member svg{width:${memberGlyph};height:${memberGlyph}}
.pill{display:flex;justify-content:center;align-items:center;width:calc(100% - 2 * ${px("invite.web.size.pillInset")});height:${px("invite.web.size.pillHeight")};margin-bottom:${px("invite.web.size.pillToFooter")};border-radius:${capsule(px("invite.web.size.pillHeight"))};background-color:${cssColor("invite.web.color.pill")};color:${cssColor("color.global.textOnMedia")};font-size:${px("invite.web.fontSize.pill")};font-weight:${cssWeight("invite.web.fontWeight.pill")};cursor:pointer;transition:${pillT}}
.pill:hover:not([aria-busy="true"]):not([data-blocked]){background-color:${cssColor("invite.web.color.pillHover")}}
.pill .busy{display:none}
.pill[aria-busy="true"]{opacity:${num("invite.web.opacity.pillDisabled")};cursor:default}
.pill[aria-busy="true"] .label{display:none}
.pill[aria-busy="true"] .busy{display:inline}
.footer{margin:${px("invite.web.size.footerMargin")};font-size:${px("invite.web.fontSize.footer")};font-weight:${cssWeight("fontWeight.global.body")};line-height:1;color:${cssColor("color.global.textOnMedia")}}
}
@media (prefers-reduced-motion:reduce){.pill{transition:none}}
`;
}
