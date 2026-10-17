// Surface: invite.web — reference: Retro's /u/[username] invite page.
// Reference images: references/auto/retro/web/retro.app-u-nathan-iphone.png, retro.app-u-nathan-pixel7.png
// (mobile card), retro.app-u-nathan-desktop.png (desktop column: QR with the inviter's photo in its centre, then
// headline and line — the order of Retro's DOM, references/auto/retro/web/retro.app-web-copy-excerpts.txt
// "ProfilePageContent,children:[QR(data, profilePhotoURL), h1, p]"), retro.app-og-userogsquare-nathan.png (share
// image). Build spec: design/surfaces/invite.web.md.
//
// Server-rendered HTML for every state of GET /i/:token. Every word comes from copy (text()), every value from
// tokens (via the stylesheet); database values are escaped. The only script is the "Let's go" busy state
// (aria-busy + "Opening…"); without it the pill is a plain link.

import { num, text, type RequiredCopyKey } from "../design.js";
import type { LoadedInvite } from "../inviteService.js";
import { InviteService } from "../inviteService.js";
import { pageCss } from "./css.js";
import { esc } from "./html.js";
import { icon } from "./icons.js";
import { qrSvg } from "./qr.js";
import { OG_HEIGHT, OG_WIDTH } from "../images.js";

export interface PageContext {
  /** CSP nonce for the inline stylesheet and script. */
  nonce: string;
  /** Absolute origin of invite links, e.g. https://example.com */
  origin: string;
  /** The app's name for {app_name}, or null while BLOCKED. */
  appName: string | null;
  /** "Let's go" (mobile): App Clip on iOS, Play on Android, else a store; null while BLOCKED. */
  letsGoUrl: string | null;
  /** "Download the app" (desktop) and the error state's store fallback; null while BLOCKED. */
  getAppUrl: string | null;
  /**
   * iPhone only: the App Store listing, in the mobile footer next to "Terms & Privacy" for people who want the full app
   * rather than the App Clip "Let's go" opens; null elsewhere or while `ios.appStoreId` is not set.
   */
  mobileAppStoreUrl: string | null;
  /** apple-itunes-app content without app-argument, or null while its ids are BLOCKED. */
  smartBanner: string | null;
  termsUrl: string | null;
  privacyUrl: string | null;
  /** config/app.json support.email: "Contact Us" in the footer and the deletion request; null until set. */
  supportEmail: string | null;
}

/** How many avatars of `diameter` overlapping by `overlap` fit in `width` (C-23: never a "+N"). */
export function fittingCount(width: number, diameter: number, overlap: number): number {
  if (diameter <= 0 || width < diameter) return 0;
  return Math.floor((width - diameter) / (diameter - overlap) + 1e-9) + 1;
}

const MEMBERS_SHOWN = fittingCount(num("invite.web.size.textMaxWidth"), num("size.global.avatarSmall"), num("size.global.avatarStackOverlap"));

const title = (ctx: PageContext, t: string) => text("invite.web.documentTitle", { title: t, ...(ctx.appName ? { app_name: ctx.appName } : {}) });

function head(ctx: PageContext, documentTitle: string, extra = ""): string {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<meta name="robots" content="noindex, noimageindex">
<meta name="referrer" content="no-referrer">
<title>${esc(documentTitle)}</title>
${extra}<style nonce="${ctx.nonce}">${pageCss()}</style>
</head>`;
}

/** A link, or — while its destination is BLOCKED (development only) — the same element without one. */
function link(url: string | null, attrs: string, inner: string, blockedKey: string, newTab = false): string {
  if (!url) return `<a ${attrs} aria-disabled="true" data-blocked="${blockedKey}">${inner}</a>`;
  const target = newTab ? ` target="_blank" rel="noopener noreferrer"` : ` rel="noreferrer"`;
  return `<a ${attrs} href="${esc(url)}"${target}>${inner}</a>`;
}

/**
 * "Terms & Privacy" (design/surfaces/invite.web.md "Footer"; Retro: Terms<span>&nbsp;&amp;&nbsp;</span>Privacy). The
 * joining ampersand is the spec's own text between the two copy strings. On a valid invite seen on an iPhone with the
 * App Store listing set ([withDownload]), "Download the app" comes first, joined by Retro's own footer separator
 * (`&nbsp;·&nbsp;`, its /u/ mobile footer; its /j/ mobile footer puts the download buttons above Terms & Privacy).
 */
function footer(ctx: PageContext, withDownload = false): string {
  const terms = link(ctx.termsUrl, `class="hit"`, esc(text("invite.web.footer.terms")), "legal.termsUrl", true);
  const privacy = link(ctx.privacyUrl, `class="hit"`, esc(text("invite.web.footer.privacy")), "legal.privacyUrl", true);
  const download = withDownload && ctx.mobileAppStoreUrl
    ? `<span class="mobile-only">${link(ctx.mobileAppStoreUrl, `class="hit"`, esc(text("invite.web.getApp")), "ios.appStoreId")}&nbsp;·&nbsp;</span>`
    : "";
  // "Contact Us" (Retro's settings row, settings.root.contact) after Privacy with the same separator, once the owner
  // has set the support address.
  const contact = ctx.supportEmail ? `&nbsp;·&nbsp;<a class="hit" href="${esc(mailto(ctx.supportEmail))}">${esc(text("settings.root.contact"))}</a>` : "";
  return `<footer class="footer">${download}${terms}&nbsp;&amp;&nbsp;${privacy}${contact}</footer>`;
}

const mailto = (address: string): string => `mailto:${address}`;

const BUSY_SCRIPT = `for(const a of document.querySelectorAll("a.pill[href][data-opens]"))a.addEventListener("click",()=>a.setAttribute("aria-busy","true"));addEventListener("pageshow",()=>{for(const a of document.querySelectorAll("a.pill[aria-busy]"))a.removeAttribute("aria-busy")});`;

function memberCell(token: string, invite: LoadedInvite, i: number): string {
  const name = invite.preview.members[i]!.first_name;
  const label = name ? esc(text("invite.web.avatar.alt", { first_name: name })) : "";
  if (invite.avatarIndexes.has(i)) return `<li><img class="member" src="/i/${token}/avatar/${i}.jpg" alt="${label}" decoding="async"></li>`;
  const a11y = name ? `role="img" aria-label="${label}"` : `aria-hidden="true"`;
  return `<li><span class="member" ${a11y}>${icon("icon.global.person", "")}</span></li>`;
}

function inviterAvatar(token: string, invite: LoadedInvite): string {
  const name = invite.preview.inviter_first_name;
  const label = name ? esc(text("invite.web.avatar.alt", { first_name: name })) : "";
  const i = invite.inviterIndex;
  if (i !== null && invite.avatarIndexes.has(i)) return `<img class="avatar" src="/i/${token}/avatar/${i}.jpg" alt="${label}">`;
  return `<span class="avatar" ${name ? `role="img" aria-label="${label}"` : `aria-hidden="true"`}></span>`;
}

export function invitePage(token: string, invite: LoadedInvite, ctx: PageContext): string {
  const p = invite.preview;
  const inviteUrl = `${ctx.origin}/i/${token}`;
  const coverAlt = text("invite.web.cover.alt", { group_name: p.group_name });
  const ogTitle = text("invite.web.og.title", { group_name: p.group_name });
  const ogDescription = text("invite.web.og.description");
  const ogImage = `${inviteUrl}/og.png`;
  const meta = `<meta property="og:type" content="website">
<meta property="og:url" content="${esc(inviteUrl)}">
<meta property="og:title" content="${esc(ogTitle)}">
<meta property="og:description" content="${esc(ogDescription)}">
<meta property="og:image" content="${esc(ogImage)}">
<meta property="og:image:type" content="image/png">
<meta property="og:image:width" content="${OG_WIDTH}">
<meta property="og:image:height" content="${OG_HEIGHT}">
<meta property="og:image:alt" content="${esc(coverAlt)}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${esc(ogTitle)}">
<meta name="twitter:description" content="${esc(ogDescription)}">
<meta name="twitter:image" content="${esc(ogImage)}">
<meta name="twitter:image:alt" content="${esc(coverAlt)}">
${ctx.smartBanner ? `<meta name="apple-itunes-app" content="${esc(`${ctx.smartBanner}, app-argument=${inviteUrl}`)}">\n` : ""}`;

  // Backdrop (invite.web.layout.backdrop): the cover (named), else the inviter's avatar (decorative: the avatar itself
  // is named), blurred and dimmed by the stylesheet; without either the card is color.global.backgroundDeep.
  const source = InviteService.backdropSource(invite);
  const backdrop = !source
    ? ""
    : source.kind === "cover"
      ? `<img class="backdrop" src="/i/${token}/cover.jpg" alt="${esc(coverAlt)}">\n`
      : `<img class="backdrop" src="/i/${token}/avatar/${source.index}.jpg" alt="">\n`;
  const headline = p.inviter_first_name ? text("invite.web.invitedBy", { first_name: p.inviter_first_name }) : text("invite.web.invitedFallback");
  const shown = p.members.slice(0, MEMBERS_SHOWN);
  const members = shown.length
    ? `<ul class="members mobile-only" aria-label="${esc(text("invite.web.members.title", { group_name: p.group_name }))}">${shown.map((_, i) => memberCell(token, invite, i)).join("")}</ul>\n`
    : "";
  const pillInner = `<span class="label">${esc(text("invite.web.cta"))}</span><span class="busy">${esc(text("invite.web.opening"))}</span>`;

  return `${head(ctx, title(ctx, p.group_name), meta)}
<body>
<div class="page">
<main class="card${source ? " photo" : ""}">
${backdrop}<div class="hero">${qrSvg(inviteUrl, "qr", num("invite.web.size.qrDesktop"))}${inviterAvatar(token, invite)}</div>
<div class="text">
<h1 class="headline">${esc(headline)}</h1>
<p class="line mobile-only">${esc(text("invite.web.body", { group_name: p.group_name }))}</p>
<p class="line desktop-only">${esc(text("invite.web.desktop.scan", { group_name: p.group_name }))}</p>
${members}</div>
${link(ctx.letsGoUrl, `class="pill mobile-only" data-opens`, pillInner, "ios.appStoreId")}
${link(ctx.getAppUrl, `class="link hit desktop-only"`, esc(text("invite.web.getApp")), "ios.appStoreId")}
${footer(ctx, true)}
</main>
</div>
<script nonce="${ctx.nonce}">${BUSY_SCRIPT}</script>
</body>
</html>
`;
}

/**
 * account.delete.web (`GET /delete-account`, design/surfaces/account.delete.web.md): the web page Google Play requires
 * for deleting an account without the app. The state page's card / column: the headline, how to delete in the app (the
 * rows' own names), what goes, the subscription note, and — once the owner set support.email — how to ask by email,
 * with "Contact Us" as the pill (mobile) and link (desktop).
 */
export function deleteAccountPage(ctx: PageContext): string {
  const heading = text("settings.account.delete");
  const path = [
    text("groups.list.tab.me.accessibilityLabel"),
    text("settings.root.title"),
    text("settings.root.account"),
    text("settings.account.delete"),
  ].join(" > ");
  const lines = [
    text("account.delete.web.inApp", { path, ...(ctx.appName ? { app_name: ctx.appName } : {}) }),
    `${text("settings.account.delete.footer")} ${text("account.delete.web.kept")}`,
    text("settings.account.delete.subscriptionNote"),
  ].map((line) => `<p class="line">${esc(line)}</p>\n`);
  let request = "";
  let action = "";
  if (ctx.supportEmail) {
    const [before, after] = text("account.delete.web.request").split("{email}");
    const address = `<a href="${esc(mailto(ctx.supportEmail))}">${esc(ctx.supportEmail)}</a>`;
    request = `<p class="line">${esc(before ?? "")}${address}${esc(after ?? "")}</p>\n`;
    action = `<a class="pill mobile-only" href="${esc(mailto(ctx.supportEmail))}">${esc(text("settings.root.contact"))}</a>
<a class="link hit desktop-only" href="${esc(mailto(ctx.supportEmail))}">${esc(text("settings.root.contact"))}</a>
`;
  }
  return `${head(ctx, title(ctx, heading))}
<body>
<div class="page">
<main class="card">
<div class="hero"></div>
<div class="text">
<h1 class="headline">${esc(heading)}</h1>
${lines.join("")}${request}</div>
${action}${footer(ctx)}
</main>
</div>
</body>
</html>
`;
}

export type StateKind = "not_found" | "unavailable" | "error" | "rate_limited";

const STATE: Record<StateKind, { title: RequiredCopyKey; body: RequiredCopyKey | null }> = {
  not_found: { title: "invite.web.notFound.title", body: null },
  unavailable: { title: "invite.web.unavailable.title", body: "invite.web.unavailable.body" },
  error: { title: "invite.web.error.title", body: "invite.web.error.body" },
  rate_limited: { title: "invite.web.error.title", body: "invite.web.rateLimited.body" },
};

/** Every non-ideal state: the same card / column, title + explanation, the retry action only for errors. */
export function statePage(kind: StateKind, ctx: PageContext & { retryUrl?: string }): string {
  const s = STATE[kind];
  const heading = text(s.title);
  const documentTitle = kind === "not_found" ? text("invite.web.notFound.documentTitle") : heading;
  const retry =
    kind === "error" && ctx.retryUrl
      ? `<a class="pill mobile-only" href="${esc(ctx.retryUrl)}">${esc(text("invite.web.error.retry"))}</a>
<a class="link hit desktop-only" href="${esc(ctx.retryUrl)}">${esc(text("invite.web.error.retry"))}</a>
`
      : "";
  return `${head(ctx, title(ctx, documentTitle))}
<body>
<div class="page">
<main class="card">
<div class="hero"></div>
<div class="text">
<h1 class="headline">${esc(heading)}</h1>
${s.body ? `<p class="line">${esc(text(s.body))}</p>\n` : ""}</div>
${retry}${footer(ctx)}
</main>
</div>
</body>
</html>
`;
}
