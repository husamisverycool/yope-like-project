// HTTP routes of the web service.
//
//   GET /i/:token                 invite page (invite.web), every state
//   GET /i/:token/cover.jpg       group cover, re-encoded (no metadata)
//   GET /i/:token/avatar/:n.jpg   member n's avatar, re-encoded
//   GET /i/:token/og.png          600×600 link-preview image (invite.web.layout.ogImage)
//   GET /i/:token/preview.json    the same preview for the App Clip and the apps before joining
//   GET /fonts/:file              the page's bundled display face (WOFF2, immutable)
//   GET /.well-known/apple-app-site-association, /.well-known/assetlinks.json
//   GET /privacy, /terms          redirect to the owner's documents (404 until configured)
//   GET /delete-account           how to delete an account, in the app or by email (account.delete.web; Google Play)
//   GET /support                  the support address (support.web; the App Store's Support URL), once support.email is set
//   GET /healthz

import { randomBytes } from "node:crypto";
import { Hono, type Context } from "hono";
import { appClipBundleId, type Config } from "./config.js";
import { cardPairs } from "./contrastReport.js";
import { fontFile } from "./fonts.js";
import type { InviteService, LoadedInvite } from "./inviteService.js";
import { appStoreUrl, detectPlatform, getAppUrl, letsGoUrl } from "./platform.js";
import { clientAddress, RateLimiter } from "./rateLimit.js";
import { deleteAccountPage, invitePage, statePage, supportPage, type PageContext, type StateKind } from "./render/pages.js";
import { UpstreamError } from "./supabase.js";
import { isTokenFormat } from "./token.js";
import { appleAppSiteAssociation, assetLinks } from "./wellKnown.js";

export interface AppDeps {
  config: Config;
  invites: InviteService | null;
  /** Socket peer address of the request (node server); undefined in tests. */
  peer?: (c: Context) => string | undefined;
  log?: (line: string) => void;
}

/** Paths with the token replaced, for logs (tokens are capabilities). */
export const redact = (path: string): string => path.replace(/^\/i\/[^/]+/, "/i/<token>");

export function createApp(deps: AppDeps): Hono {
  const { config } = deps;
  const log = deps.log ?? ((l: string) => console.log(l));
  const app = new Hono({ strict: false });
  const requests = new RateLimiter(config.rateLimitRequests);
  const lookups = new RateLimiter(config.rateLimitLookups);
  const ttl = config.inviteCacheSeconds;
  const production = config.mode === "production";

  // Generated once at startup from config/app.json.
  const aasa = JSON.stringify(appleAppSiteAssociation(config.app));
  const assetlinks = JSON.stringify(assetLinks(config.app));
  const smartBanner =
    config.app.ios.appStoreId && config.app.ios.teamId
      ? `app-id=${config.app.ios.appStoreId}, app-clip-bundle-id=${appClipBundleId(config.app)}, app-clip-display=card`
      : null;

  const origin = (c: Context): string => (config.app.domain ? `https://${config.app.domain}` : new URL(c.req.url).origin);
  const address = (c: Context): string => clientAddress(deps.peer?.(c), c.req.header("x-forwarded-for"), config.trustProxyHops);

  // ---------- headers on every response ----------
  app.use("*", async (c, next) => {
    const started = Date.now();
    await next();
    const h = c.res.headers;
    h.set("X-Content-Type-Options", "nosniff");
    h.set("Referrer-Policy", "no-referrer");
    h.set("X-Frame-Options", "DENY");
    h.set("Cross-Origin-Opener-Policy", "same-origin");
    if (!h.has("Cross-Origin-Resource-Policy")) h.set("Cross-Origin-Resource-Policy", "same-origin");
    h.set("Permissions-Policy", "camera=(), microphone=(), geolocation=(), payment=(), usb=(), browsing-topics=()");
    h.set("X-Robots-Tag", "noindex, noimageindex"); // invite.web.layout.linkPreview robots
    if (!h.has("Content-Security-Policy")) h.set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'");
    if (!h.has("Cache-Control")) h.set("Cache-Control", "no-store");
    if (production) h.set("Strict-Transport-Security", "max-age=63072000; includeSubDomains");
    if (config.mode !== "test") log(`${c.req.method} ${redact(c.req.path)} ${c.res.status} ${Date.now() - started}ms`);
  });

  // script-src: the one inline script (the "Let's go" busy state), by nonce like the stylesheet.
  const pageCsp = (nonce: string) =>
    `default-src 'none'; img-src 'self'; font-src 'self'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'` +
    (production ? "; upgrade-insecure-requests" : "");

  function html(c: Context, status: number, body: string, nonce: string, cache: string) {
    return c.body(body, status as 200, {
      "Content-Type": "text/html; charset=utf-8",
      "Content-Security-Policy": pageCsp(nonce),
      "Cache-Control": cache,
      Vary: "User-Agent",
    });
  }

  function context(c: Context, token: string | null, nonce: string): PageContext {
    const platform = detectPlatform(c.req.header("user-agent"));
    return {
      nonce,
      origin: origin(c),
      appName: config.app.displayName,
      letsGoUrl: token ? letsGoUrl(config.app, platform, token) : null,
      getAppUrl: getAppUrl(config.app, platform, token),
      mobileAppStoreUrl: platform === "ios" ? appStoreUrl(config.app) : null,
      smartBanner,
      termsUrl: config.app.legal.termsUrl,
      privacyUrl: config.app.legal.privacyUrl,
      supportEmail: config.app.support.email,
    };
  }

  function state(c: Context, kind: StateKind, status: number, extra: { retryUrl?: string; retryAfter?: number } = {}) {
    const nonce = randomBytes(16).toString("base64");
    const res = html(c, status, statePage(kind, { ...context(c, null, nonce), retryUrl: extra.retryUrl }), nonce, "no-store");
    if (extra.retryAfter) res.headers.set("Retry-After", String(extra.retryAfter));
    return res;
  }

  type Resolved = { ok: true; invite: LoadedInvite } | { ok: false; response: Response };

  /** Token check → rate limits → cached lookup. Invalid tokens never reach the database. */
  async function resolve(c: Context, wantsHtml: boolean): Promise<Resolved> {
    const token = c.req.param("token") ?? "";
    const fail = (kind: StateKind, status: number, extra?: { retryUrl?: string; retryAfter?: number }): Resolved =>
      wantsHtml ? { ok: false, response: state(c, kind, status, extra) } : { ok: false, response: c.body(null, status as 404, extra?.retryAfter ? { "Retry-After": String(extra.retryAfter) } : {}) };
    const who = address(c);
    const r = requests.take(who);
    if (!r.ok) return fail("rate_limited", 429, { retryAfter: r.retryAfterSeconds });
    if (!isTokenFormat(token)) return fail("not_found", 404);
    if (!deps.invites) return fail("error", 503, { retryUrl: `/i/${token}` });
    if (!deps.invites.isCached(token)) {
      const l = lookups.take(who);
      if (!l.ok) return fail("rate_limited", 429, { retryAfter: l.retryAfterSeconds });
    }
    try {
      const result = await deps.invites.lookup(token);
      if (result.status === "not_found") return fail("not_found", 404);
      if (result.status === "unavailable") return fail("unavailable", 410);
      return { ok: true, invite: result };
    } catch (e) {
      log(`invite lookup failed: ${e instanceof UpstreamError ? e.message : (e as Error).stack ?? e}`);
      return fail("error", 503, { retryUrl: `/i/${token}` });
    }
  }

  const image = (c: Context, buf: Buffer, crossOrigin = false, type = "image/jpeg") =>
    c.body(new Uint8Array(buf), 200, {
      "Content-Type": type,
      "Cache-Control": `private, max-age=${ttl}`,
      ...(crossOrigin ? { "Cross-Origin-Resource-Policy": "cross-origin" } : {}),
    });

  // ---------- invite routes ----------
  app.get("/i/:token", async (c) => {
    const r = await resolve(c, true);
    if (!r.ok) return r.response;
    const token = c.req.param("token");
    const nonce = randomBytes(16).toString("base64");
    if (config.mode === "development") {
      // Sourced values are never adjusted; failing WCAG pairs over this invite's backdrop are reported.
      const tone = await deps.invites!.backdropTone(token).catch(() => null);
      if (tone) {
        const failing = cardPairs(tone).filter((p) => !p.pass);
        if (failing.length) log(`WCAG: backdrop ${failing[0]!.bg} fails ${failing.map((p) => `${p.element} ${p.ratio.toFixed(2)}:1 < ${p.need}:1`).join("; ")}`);
      }
    }
    return html(c, 200, invitePage(token, r.invite, context(c, token, nonce)), nonce, `private, max-age=${ttl}`);
  });

  app.get("/i/:token/cover.jpg", async (c) => {
    const r = await resolve(c, false);
    if (!r.ok) return r.response;
    return r.invite.cover ? image(c, r.invite.cover.jpeg) : c.body(null, 404);
  });

  app.get("/i/:token/avatar/:file", async (c) => {
    const m = /^([0-9]{1,2})\.jpg$/.exec(c.req.param("file"));
    if (!m) return c.body(null, 404);
    const r = await resolve(c, false);
    if (!r.ok) return r.response;
    try {
      const buf = await deps.invites!.avatar(c.req.param("token"), Number(m[1]));
      return buf ? image(c, buf) : c.body(null, 404);
    } catch (e) {
      log(`avatar failed: ${(e as Error).message}`);
      return c.body(null, 503);
    }
  });

  app.get("/i/:token/og.png", async (c) => {
    const r = await resolve(c, false);
    if (!r.ok) return r.response;
    try {
      const domain = config.app.domain ?? new URL(c.req.url).host;
      const buf = await deps.invites!.ogImage(c.req.param("token"), domain);
      return buf ? image(c, buf, true, "image/png") : c.body(null, 404);
    } catch (e) {
      log(`og image failed: ${(e as Error).message}`);
      return c.body(null, 503);
    }
  });

  app.get("/i/:token/preview.json", async (c) => {
    const r = await resolve(c, false);
    if (!r.ok) return r.response;
    const token = c.req.param("token");
    const base = `${origin(c)}/i/${token}`;
    const { preview, cover, avatarIndexes } = r.invite;
    return c.json(
      {
        group_name: preview.group_name,
        group_kind: preview.group_kind,
        inviter_first_name: preview.inviter_first_name,
        inviter_avatar_url: r.invite.inviterIndex !== null && avatarIndexes.has(r.invite.inviterIndex) ? `${base}/avatar/${r.invite.inviterIndex}.jpg` : null,
        cover: cover ? { url: `${base}/cover.jpg`, width: cover.width, height: cover.height } : null,
        members: preview.members.map((m, i) => ({ first_name: m.first_name, avatar_url: avatarIndexes.has(i) ? `${base}/avatar/${i}.jpg` : null })),
      },
      200,
      { "Cache-Control": `private, max-age=${ttl}` },
    );
  });

  // ---------- the page's served face ----------
  app.get("/fonts/:file", (c) => {
    const body = fontFile(c.req.param("file"));
    if (!body) return state(c, "not_found", 404);
    return c.body(new Uint8Array(body), 200, { "Content-Type": "font/woff2", "Cache-Control": "public, max-age=31536000, immutable" });
  });

  // ---------- association files ----------
  const wellKnown = (body: string) => (c: Context) =>
    c.body(body, 200, { "Content-Type": "application/json", "Cache-Control": "public, max-age=3600", "Cross-Origin-Resource-Policy": "cross-origin" });
  app.get("/.well-known/apple-app-site-association", wellKnown(aasa));
  app.get("/.well-known/assetlinks.json", wellKnown(assetlinks));

  // ---------- legal + health ----------
  app.get("/privacy", (c) => (config.app.legal.privacyUrl ? c.redirect(config.app.legal.privacyUrl, 302) : state(c, "not_found", 404)));
  app.get("/terms", (c) => (config.app.legal.termsUrl ? c.redirect(config.app.legal.termsUrl, 302) : state(c, "not_found", 404)));
  app.get("/delete-account", (c) => {
    const nonce = randomBytes(16).toString("base64");
    return html(c, 200, deleteAccountPage(context(c, null, nonce)), nonce, "public, max-age=3600");
  });
  app.get("/support", (c) => {
    const email = config.app.support.email;
    if (!email) return state(c, "not_found", 404);
    const nonce = randomBytes(16).toString("base64");
    return html(c, 200, supportPage(context(c, null, nonce), email), nonce, "public, max-age=3600");
  });
  app.get("/healthz", (c) => c.json({ status: "ok" }, 200, { "Cache-Control": "no-store" }));

  app.notFound((c) => state(c, "not_found", 404));
  app.onError((e, c) => {
    log(`unhandled: ${(e as Error).stack ?? e}`);
    return state(c, "error", 500);
  });
  return app;
}
