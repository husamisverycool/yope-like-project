// Surface: invite.web — reference app: Partiful (event invite page).
// Reference images: references/auto/partiful/web/pf-web-private-past-01..03.png (closest analogue:
// link-only event, logged out), pf-web-public-light-01..04.png, pf-web-public-dark-01..04.png,
// pf-web-notfound-01.png. Build spec: design/surfaces/invite.web.md.
//
// Server-rendered HTML for every state of GET /i/:token. No script; the member list disclosure is
// a native <details> element. Every word comes from copy (text()), every value from tokens (via the
// stylesheet); database values are escaped.

import { text, tokens } from "../design.js";
import type { LoadedInvite } from "../inviteService.js";
import { defaultTheme, type Theme } from "../theme.js";
import { titleSteps } from "../titleFit.js";
import { inviteCss, stateCss } from "./css.js";
import { esc } from "./html.js";
import { icon } from "./icons.js";

export interface PageContext {
  /** CSP nonce for the inline stylesheet. */
  nonce: string;
  /** Where "Get the app" goes for this visitor (null while the store id is BLOCKED). */
  getAppUrl: string | null;
  /** Content of <meta name="apple-itunes-app">, or null while its ids are BLOCKED. */
  smartBanner: string | null;
  /** Absolute origin for og:url / og:image, e.g. https://example.com */
  origin: string;
}

const OG_WIDTH = (tokens["invite.web.layout.ogImage"] as { width: number }).width;
const OG_HEIGHT = (tokens["invite.web.layout.ogImage"] as { height: number }).height;
const COLUMN_MIN = 0;
const COLUMN_MAX = (tokens["invite.web.dimension.columnMaxWidth"] as number) - 2 * (tokens["invite.web.dimension.margin"] as number);

function head(title: string, css: string, ctx: PageContext, extra: string): string {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<meta name="referrer" content="no-referrer">
<title>${esc(title)}</title>
<meta property="og:title" content="${esc(title)}">
<meta name="twitter:title" content="${esc(title)}">
${extra}<style nonce="${ctx.nonce}">${css}</style>
</head>`;
}

/** "Get the app" link; without a destination while the store id is BLOCKED (development only). */
function getAppLink(url: string | null, className: string, inner: string, newTab: boolean): string {
  if (!url) return `<a class="${className}" aria-disabled="true" data-blocked="ios.appStoreId">${inner}</a>`;
  const target = newTab ? ` target="_blank" rel="noopener noreferrer"` : ` rel="noreferrer"`;
  return `<a class="${className}" href="${esc(url)}"${target}>${inner}</a>`;
}

function footer(ctx: PageContext): string {
  const inner = `<span>${esc(text("invite.web.getApp"))}</span>${icon("invite.web.icon.getApp", "")}`;
  return `<footer><div class="divider"></div><div class="footer-content">${getAppLink(ctx.getAppUrl, "get-app", inner, true)}</div></footer>`;
}

/** First grapheme of a first name, upper-cased (initials disc for members without a photo). */
export function initial(name: string): string {
  const seg = new Intl.Segmenter(undefined, { granularity: "grapheme" });
  const first = seg.segment(name.trim())[Symbol.iterator]().next().value?.segment ?? "";
  return first.toLocaleUpperCase();
}

function avatarCell(token: string, invite: LoadedInvite, i: number, decorative: boolean): string {
  const name = invite.preview.members[i]!.first_name;
  if (invite.avatarIndexes.has(i)) {
    const alt = decorative || !name ? "" : esc(name);
    return `<img class="avatar" src="/i/${token}/avatar/${i}.jpg" alt="${alt}" width="${tokens["invite.web.dimension.avatar"]}" height="${tokens["invite.web.dimension.avatar"]}" decoding="async">`;
  }
  const letter = name ? esc(initial(name)) : "";
  if (decorative || !name) return `<span class="initials" aria-hidden="true">${letter}</span>`;
  return `<span class="initials" role="img" aria-label="${esc(name)}">${letter}</span>`;
}

export function invitePage(token: string, invite: LoadedInvite, ctx: PageContext): string {
  const p = invite.preview;
  const title = text("invite.web.documentTitle", { title: p.group_name });
  const coverAlt = text("invite.web.cover.alt", { group_name: p.group_name });
  const og = invite.cover
    ? `<meta property="og:image" content="${esc(`${ctx.origin}/i/${token}/og.jpg`)}">
<meta property="og:image:type" content="image/jpeg">
<meta property="og:image:width" content="${OG_WIDTH}">
<meta property="og:image:height" content="${OG_HEIGHT}">
<meta property="og:image:alt" content="${esc(coverAlt)}">
<meta name="twitter:image" content="${esc(`${ctx.origin}/i/${token}/og.jpg`)}">
<meta name="twitter:image:alt" content="${esc(coverAlt)}">
`
    : "";
  const extra = `<meta property="og:type" content="website">
<meta property="og:url" content="${esc(`${ctx.origin}/i/${token}`)}">
<meta name="twitter:card" content="${esc(String((tokens["invite.web.layout.linkPreview"] as { twitterCard: string }).twitterCard))}">
${og}${ctx.smartBanner ? `<meta name="apple-itunes-app" content="${esc(ctx.smartBanner)}">\n` : ""}`;

  const steps = titleSteps(p.group_name, COLUMN_MIN, COLUMN_MAX);
  const cover = invite.cover
    ? `<img class="cover" src="/i/${token}/cover.jpg" width="${invite.cover.width}" height="${invite.cover.height}" alt="${esc(coverAlt)}">`
    : "";
  const invitedBy = p.inviter_first_name ? `<p class="field">${esc(text("invite.web.invitedBy", { first_name: p.inviter_first_name }))}</p>` : "";
  const avatars = p.members.map((_, i) => `<li>${avatarCell(token, invite, i, false)}</li>`).join("");
  const rows = p.members
    .map((m, i) => `<li class="row">${avatarCell(token, invite, i, true)}${m.first_name ? `<span class="row-name">${esc(m.first_name)}</span>` : ""}</li>`)
    .join("");

  return `${head(title, inviteCss(invite.theme, steps), ctx, extra)}
<body>
<div class="page">
<main class="column invite">
<h1 class="title">${esc(p.group_name)}</h1>
${cover}
${invitedBy}
<section class="members" aria-labelledby="members-title">
<div class="members-head"><h2 class="section-title" id="members-title">${esc(text("invite.web.members.title"))}</h2></div>
<ul class="avatars" aria-labelledby="members-title">${avatars}</ul>
<details class="all"><summary class="btn btn-outlined">${esc(text("invite.web.members.viewAll"))}</summary><ul class="rows" aria-labelledby="members-title">${rows}</ul></details>
</section>
<section class="gate" aria-labelledby="gate-title">
${icon("invite.web.icon.lock", "lock")}
<h2 class="section-title" id="gate-title">${esc(text("invite.web.gate.title"))}</h2>
<p class="gate-body">${esc(text("invite.web.gate.body"))}</p>
${getAppLink(ctx.getAppUrl, "btn btn-filled", esc(text("invite.web.getApp")), false)}
</section>
</main>
${footer(ctx)}
</div>
</body>
</html>
`;
}

export type StateKind = "not_found" | "unavailable" | "error" | "rate_limited";

export function statePage(kind: StateKind, ctx: PageContext & { retryUrl?: string }): string {
  const theme: Theme = defaultTheme();
  const heading = {
    not_found: text("invite.web.notFound.title"),
    unavailable: text("invite.web.unavailable.title"),
    error: text("invite.web.error.title"),
    rate_limited: text("invite.web.error.title"),
  }[kind];
  const shortTitle = kind === "not_found" ? text("invite.web.notFound.documentTitle") : heading;
  const body = {
    not_found: "",
    unavailable: text("invite.web.unavailable.body"),
    error: text("invite.web.error.body"),
    rate_limited: text("invite.web.rateLimited.body"),
  }[kind];
  const action =
    kind === "error" && ctx.retryUrl
      ? `<a class="btn btn-filled" href="${esc(ctx.retryUrl)}">${esc(text("invite.web.error.retry"))}</a>`
      : "";
  return `${head(text("invite.web.documentTitle", { title: shortTitle }), stateCss(theme), ctx, "")}
<body>
<div class="page">
<div class="header-space"></div>
<main class="column state">
<div class="glyph" role="img" aria-label="${esc(text("invite.web.state.glyphLabel"))}">${esc(text("invite.web.state.glyph"))}</div>
<h1 class="state-title">${esc(heading)}</h1>
${body ? `<p class="state-body">${esc(body)}</p>` : ""}
${action}
</main>
${footer(ctx)}
</div>
</body>
</html>
`;
}
