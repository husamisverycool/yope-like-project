import sharp from "sharp";
import { beforeAll, describe, expect, it } from "vitest";
import { copy } from "../../src/generated/copy.js";
import type { InvitePreview } from "../../src/supabase.js";
import { ANDROID, DESKTOP, FULL_APP_JSON, IPHONE, testApp } from "../support/app.js";
import { FakeUpstream } from "../support/fakeUpstream.js";
import { EXIF_MARKER, testJpeg } from "../support/seed.js";

const UID_A = "11111111-2222-4333-8444-555555555555";
const UID_B = "66666666-7777-4888-9999-aaaaaaaaaaaa";
const TOKEN = "Tok3n_valid-Abcdefghijkl";
const COVER = `u/${UID_A}/covers/cover.jpg`;
const AVATAR = `avatars/${UID_A}/a.jpg`;

const preview = (over: Partial<InvitePreview> = {}): InvitePreview => ({
  group_name: "Lima family",
  group_kind: "family",
  cover_path: COVER,
  inviter_first_name: "Ana",
  members: [
    { first_name: "Ana", avatar_path: AVATAR },
    { first_name: "Rui", avatar_path: null },
    { first_name: null, avatar_path: `avatars/${UID_B}/missing.jpg` },
  ],
  ...over,
});

let coverJpeg: Buffer;
let darkCover: Buffer;
let avatarJpeg: Buffer;
beforeAll(async () => {
  coverJpeg = await testJpeg(1200, 900, [167, 200, 255], [251, 235, 228]);
  darkCover = await testJpeg(800, 800, [20, 10, 10], [40, 20, 20]);
  avatarJpeg = await testJpeg(400, 300, [200, 120, 90], [40, 60, 90]);
});

function fake(p = preview()) {
  const up = new FakeUpstream();
  up.setPreview(TOKEN, p);
  up.objects.set(COVER, coverJpeg);
  up.objects.set(AVATAR, avatarJpeg);
  return up;
}

/** Text a person sees: the body without tags, styles and attributes. */
const visibleText = (html: string) =>
  html
    .replace(/<head>[\s\S]*?<\/head>/, "")
    .replace(/<style[\s\S]*?<\/style>/g, "")
    .replace(/<svg[\s\S]*?<\/svg>/g, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();

const get = (app: ReturnType<typeof testApp>["app"], path: string, ua = IPHONE) => app.request(path, { headers: { "user-agent": ua } });

describe("GET /i/:token — valid invite", () => {
  it("renders the Partiful anatomy with copy, members and no counts", async () => {
    const { app } = testApp(fake());
    const res = await get(app, `/i/${TOKEN}`);
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toBe("text/html; charset=utf-8");
    const html = await res.text();
    const text = visibleText(html);
    expect(text).toBe(
      ["Lima family", "Invited by Ana", copy["invite.web.members.title"], "R", copy["invite.web.members.viewAll"], "Ana", "R", "Rui", copy["invite.web.gate.title"], copy["invite.web.gate.body"].replace("'", "&#39;"), copy["invite.web.getApp"], copy["invite.web.getApp"]].join(" "),
    );
    expect(text).not.toMatch(/[0-9]/); // no member count, no number of anything
    expect(html).toContain(`<h1 class="title">Lima family</h1>`);
    expect(html).toContain(`alt="Lima family Group Cover Image"`);
    expect(html).toContain(`<img class="avatar" src="/i/${TOKEN}/avatar/0.jpg" alt="Ana"`);
    expect(html).toContain(`<span class="initials" role="img" aria-label="Rui">R</span>`);
    // the member whose avatar could not be signed gets an (unlabelled, nameless) disc
    expect(html).not.toContain(`/avatar/2.jpg`);
  });

  it("exposes no non-preview field, storage path, user id, Supabase URL or key", async () => {
    const { app } = testApp(fake());
    const html = await (await get(app, `/i/${TOKEN}`)).text();
    for (const leak of [UID_A, UID_B, "avatars/", "u/", "supabase", "storage", "anon", "service", "family\"", "group_kind", "token=", "Lastname"]) {
      expect(html.includes(leak), leak).toBe(false);
    }
    expect(html).not.toMatch(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/);
  });

  it("escapes database text", async () => {
    const { app } = testApp(fake(preview({ group_name: `<script>alert("x")</script>`, inviter_first_name: `<img src=x onerror=1>` })));
    const html = await (await get(app, `/i/${TOKEN}`)).text();
    expect(html).not.toContain("<script>");
    expect(html).not.toContain("<img src=x");
    expect(html).toContain("&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;");
  });

  it("has the link-preview tags (Partiful format, brand replaced by the app name)", async () => {
    const { app } = testApp(fake());
    const html = await (await get(app, `/i/${TOKEN}`)).text();
    const meta = (attr: string, name: string) => new RegExp(`<meta ${attr}="${name}" content="([^"]*)">`).exec(html)?.[1];
    const title = copy["invite.web.documentTitle" as keyof typeof copy] ? "Lima family | " : "[BLOCKED invite.web.documentTitle]";
    expect(html).toMatch(new RegExp(`<title>${title.replace(/[[\]|]/g, "\\$&")}`));
    expect(meta("property", "og:title")).toContain(title);
    expect(meta("name", "twitter:title")).toContain(title);
    expect(meta("property", "og:url")).toBe(`https://invite.example.com/i/${TOKEN}`);
    expect(meta("property", "og:image")).toBe(`https://invite.example.com/i/${TOKEN}/og.jpg`);
    expect(meta("property", "og:image:width")).toBe("1200");
    expect(meta("property", "og:image:height")).toBe("630");
    expect(meta("property", "og:image:alt")).toBe("Lima family Group Cover Image");
    expect(meta("name", "twitter:card")).toBe("summary_large_image");
    expect(meta("name", "twitter:image")).toBe(`https://invite.example.com/i/${TOKEN}/og.jpg`);
    expect(meta("name", "robots")).toBe("noindex, nofollow");
    expect(meta("name", "description")).toBeUndefined();
  });

  it("has the Smart App Banner with the App Clip card, from config", async () => {
    const { app } = testApp(fake());
    const html = await (await get(app, `/i/${TOKEN}`)).text();
    expect(html).toContain(`<meta name="apple-itunes-app" content="app-id=1234567890, app-clip-bundle-id=com.example.groupphotos.Clip, app-clip-display=card">`);
  });

  it("omits the Smart App Banner while its ids are BLOCKED", async () => {
    const { app } = testApp(fake(), {}, { ...FULL_APP_JSON, ios: { ...FULL_APP_JSON.ios, appStoreId: null, teamId: null } });
    const html = await (await get(app, `/i/${TOKEN}`)).text();
    expect(html).not.toContain("apple-itunes-app");
    expect(html).toContain(`aria-disabled="true" data-blocked="ios.appStoreId"`);
  });

  it.each([
    [IPHONE, "https://apps.apple.com/app/id1234567890"],
    [ANDROID, `https://play.google.com/store/apps/details?id=com.example.groupphotos&amp;referrer=invite_token%3D${TOKEN}`],
    [DESKTOP, "https://apps.apple.com/app/id1234567890"],
  ])("'Get the app' goes to the right store (%#)", async (ua, href) => {
    const { app } = testApp(fake());
    const html = await (await get(app, `/i/${TOKEN}`, ua)).text();
    expect(html).toContain(`<a class="btn btn-filled" href="${href}" rel="noreferrer">`);
    expect(html).toContain(`<a class="get-app" href="${href}" target="_blank" rel="noopener noreferrer">`);
  });

  it("themes the page from the cover: light cover → black text, dark cover → white text", async () => {
    const light = await (await get(testApp(fake()).app, `/i/${TOKEN}`)).text();
    expect(light).toMatch(/html\{background:#[0-9A-F]{6};color-scheme:light/);
    expect(light).toContain("body{margin:0;font-family:-apple-system, system-ui, sans-serif;font-size:16px;font-weight:400;line-height:1.4;color:rgb(0 0 0)");
    const up = fake();
    up.objects.set(COVER, darkCover);
    const dark = await (await get(testApp(up).app, `/i/${TOKEN}`)).text();
    expect(dark).toMatch(/html\{background:#1[0-9A-F]0[0-9A-F]0[0-9A-F];color-scheme:dark/);
    expect(dark).toContain("color:rgb(255 255 255)");
    const none = await (await get(testApp(fake(preview({ cover_path: null }))).app, `/i/${TOKEN}`)).text();
    expect(none).toContain("html{background:#111111;color-scheme:dark");
    expect(none).not.toContain(`class="cover"`);
    expect(none).not.toContain("og:image");
  });

  it("omits the inviter row when the inviter has no first name", async () => {
    const html = await (await get(testApp(fake(preview({ inviter_first_name: null }))).app, `/i/${TOKEN}`)).text();
    expect(html).not.toContain(`class="field"`);
  });

  it("answers HEAD", async () => {
    const { app } = testApp(fake());
    const res = await app.request(`/i/${TOKEN}`, { method: "HEAD" });
    expect(res.status).toBe(200);
  });
});

describe("GET /i/:token — other states", () => {
  it("unknown token → 404 not-found state, no member data", async () => {
    const up = fake();
    const { app } = testApp(up);
    const res = await get(app, `/i/${"Z".repeat(24)}`);
    expect(res.status).toBe(404);
    const html = await res.text();
    expect(visibleText(html)).toBe(`${copy["invite.web.state.glyph"]} ${copy["invite.web.notFound.title"]} ${copy["invite.web.getApp"]}`);
    expect(html).toContain(`role="img" aria-label="${copy["invite.web.state.glyphLabel"]}"`);
    expect(html).not.toContain("Lima");
    expect(html).not.toContain("apple-itunes-app");
    expect(res.headers.get("cache-control")).toBe("no-store");
    expect(up.calls.preview).toBe(1);
  });

  it.each(["short", "x".repeat(25), "with.dot.aaaaaaaaaaaaaaaa", "%2e%2e%2f%2e%2e%2fetc%2fpasswd", "AAAAAAAAAAAAAAAAAAAAAAA%3D"])("malformed token %s → 404 without any database call", async (bad) => {
    const up = fake();
    const { app } = testApp(up);
    const res = await get(app, `/i/${bad}`);
    expect(res.status).toBe(404);
    expect(up.calls.preview + up.calls.sign + up.calls.fetch).toBe(0);
    for (const sub of ["cover.jpg", "og.jpg", "avatar/0.jpg", "preview.json"]) {
      expect((await get(app, `/i/${bad}/${sub}`)).status).toBe(404);
    }
    expect(up.calls.preview).toBe(0);
  });

  it.each(["expired", "revoked"] as const)("%s invite → 410, same page for both, no member data", async (reason) => {
    const up = fake();
    up.previews.set(TOKEN, { status: "unavailable", reason });
    const res = await get(testApp(up).app, `/i/${TOKEN}`);
    expect(res.status).toBe(410);
    const html = await res.text();
    expect(visibleText(html)).toBe(`${copy["invite.web.state.glyph"]} ${copy["invite.web.unavailable.title"]} ${copy["invite.web.unavailable.body"]} ${copy["invite.web.getApp"]}`);
    expect(html).not.toContain(reason);
    expect(res.headers.get("cache-control")).toBe("no-store");
  });

  it("upstream failure → 503 error state with a retry link, never cached", async () => {
    const up = fake();
    up.failPreview = true;
    const { app, logs } = testApp(up);
    const res = await get(app, `/i/${TOKEN}`);
    expect(res.status).toBe(503);
    const html = await res.text();
    expect(visibleText(html)).toBe(`${copy["invite.web.state.glyph"]} ${copy["invite.web.error.title"]} ${copy["invite.web.error.body"]} ${copy["invite.web.error.retry"]} ${copy["invite.web.getApp"]}`);
    expect(html).toContain(`<a class="btn btn-filled" href="/i/${TOKEN}">${copy["invite.web.error.retry"]}</a>`);
    expect(res.headers.get("cache-control")).toBe("no-store");
    expect(logs.join("\n")).not.toContain(TOKEN);
    up.failPreview = false;
    expect((await get(app, `/i/${TOKEN}`)).status).toBe(200);
    expect(up.calls.preview).toBe(2);
  });

  it("no Supabase configured → 503", async () => {
    expect((await get(testApp(null).app, `/i/${TOKEN}`)).status).toBe(503);
  });

  it("works without JavaScript: no script element, no script allowed", async () => {
    const res = await get(testApp(fake()).app, `/i/${TOKEN}`);
    const html = await res.text();
    expect(html).not.toMatch(/<script/i);
    expect(res.headers.get("content-security-policy")).not.toContain("script-src");
    expect(html).toContain(`<details class="all"><summary`);
  });
});

describe("caching and revocation", () => {
  it("reuses a lookup for the cache TTL only, so a revoked invite disappears within it", async () => {
    let now = 0;
    const up = fake();
    const { app } = testApp(up, { inviteCacheSeconds: 60 }, undefined, { now: () => now });
    const first = await get(app, `/i/${TOKEN}`);
    expect(first.headers.get("cache-control")).toBe("private, max-age=60");
    await get(app, `/i/${TOKEN}/cover.jpg`);
    await get(app, `/i/${TOKEN}/avatar/0.jpg`);
    expect(up.calls.preview).toBe(1);
    up.previews.set(TOKEN, { status: "unavailable", reason: "revoked" });
    now = 59_000;
    expect((await get(app, `/i/${TOKEN}`)).status).toBe(200);
    now = 60_001;
    expect((await get(app, `/i/${TOKEN}`)).status).toBe(410);
    expect((await get(app, `/i/${TOKEN}/cover.jpg`)).status).toBe(410);
    expect(up.calls.preview).toBe(2);
  });
});

describe("images", () => {
  it("cover.jpg is a re-encoded JPEG without the source metadata", async () => {
    const res = await get(testApp(fake()).app, `/i/${TOKEN}/cover.jpg`);
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toBe("image/jpeg");
    expect(res.headers.get("cache-control")).toBe("private, max-age=60");
    const buf = Buffer.from(await res.arrayBuffer());
    expect(buf.includes(Buffer.from(EXIF_MARKER))).toBe(false);
    expect(coverJpeg.includes(Buffer.from(EXIF_MARKER))).toBe(true);
    const meta = await sharp(buf).metadata();
    expect([meta.format, meta.width, meta.height, meta.exif]).toEqual(["jpeg", 1200, 900, undefined]);
  });

  it("avatars are 48 pt at 3x, square; missing ones are 404", async () => {
    const { app } = testApp(fake());
    const res = await get(app, `/i/${TOKEN}/avatar/0.jpg`);
    const meta = await sharp(Buffer.from(await res.arrayBuffer())).metadata();
    expect([meta.width, meta.height]).toEqual([144, 144]);
    for (const p of ["avatar/1.jpg", "avatar/2.jpg", "avatar/3.jpg", "avatar/99.jpg", "avatar/x.jpg", "avatar/0.png"]) expect((await get(app, `/i/${TOKEN}/${p}`)).status).toBe(404);
  });

  it("og.jpg is 1200×630: the cover fitted inside a blurred fill of itself", async () => {
    const res = await get(testApp(fake()).app, `/i/${TOKEN}/og.jpg`);
    expect(res.status).toBe(200);
    expect(res.headers.get("cross-origin-resource-policy")).toBe("cross-origin");
    const img = sharp(Buffer.from(await res.arrayBuffer()));
    const meta = await img.metadata();
    expect([meta.format, meta.width, meta.height]).toEqual(["jpeg", 1200, 630]);
    const { data } = await img.raw().toBuffer({ resolveWithObject: true });
    const px = (x: number, y: number) => [...data.subarray((y * 1200 + x) * 3, (y * 1200 + x) * 3 + 3)];
    // foreground: 840×630 centred (x 180–1019); top half blue, bottom half peach, sharp edge at y 315
    expect(px(600, 100)[2]).toBeGreaterThan(240);
    expect(px(600, 530)[0]).toBeGreaterThan(240);
    // fill: blurred, so the two halves meet as a gradient instead of an edge
    const left = [px(60, 250), px(60, 315), px(60, 380)].map((p) => p[2]!);
    expect(left[0]! - left[1]!).toBeLessThan(20);
    expect(left[1]! - left[2]!).toBeLessThan(20);
  });

  it("og.jpg is 404 when the group has no cover", async () => {
    expect((await get(testApp(fake(preview({ cover_path: null }))).app, `/i/${TOKEN}/og.jpg`)).status).toBe(404);
  });
});

describe("preview.json (App Clip and apps before joining)", () => {
  it("returns exactly the preview, with this service's image URLs", async () => {
    const res = await get(testApp(fake()).app, `/i/${TOKEN}/preview.json`);
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body).toStrictEqual({
      group_name: "Lima family",
      group_kind: "family",
      inviter_first_name: "Ana",
      cover: { url: `https://invite.example.com/i/${TOKEN}/cover.jpg`, width: 1200, height: 900 },
      members: [
        { first_name: "Ana", avatar_url: `https://invite.example.com/i/${TOKEN}/avatar/0.jpg` },
        { first_name: "Rui", avatar_url: null },
        { first_name: null, avatar_url: null },
      ],
      theme: { background: expect.stringMatching(/^#[0-9A-F]{6}$/), scheme: "light" },
    });
  });

  it("is 404 / 410 without a body for other states", async () => {
    const up = fake();
    up.previews.set("R".repeat(24), { status: "unavailable", reason: "revoked" });
    const { app } = testApp(up);
    const a = await get(app, `/i/${"Q".repeat(24)}/preview.json`);
    const b = await get(app, `/i/${"R".repeat(24)}/preview.json`);
    expect([a.status, await a.text(), b.status, await b.text()]).toEqual([404, "", 410, ""]);
  });
});

describe("security headers", () => {
  it("sets a nonce-based CSP and the standard headers on pages", async () => {
    const res = await get(testApp(fake()).app, `/i/${TOKEN}`);
    const csp = res.headers.get("content-security-policy")!;
    const nonce = /style-src 'nonce-([A-Za-z0-9+/=]+)'/.exec(csp)![1]!;
    expect(csp).toBe(`default-src 'none'; img-src 'self'; style-src 'nonce-${nonce}'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`);
    expect(await res.text()).toContain(`<style nonce="${nonce}">`);
    expect(res.headers.get("x-content-type-options")).toBe("nosniff");
    expect(res.headers.get("referrer-policy")).toBe("no-referrer");
    expect(res.headers.get("x-frame-options")).toBe("DENY");
    expect(res.headers.get("cross-origin-opener-policy")).toBe("same-origin");
    expect(res.headers.get("x-robots-tag")).toBe("noindex, nofollow");
    expect(res.headers.get("permissions-policy")).toContain("camera=()");
    expect(res.headers.get("vary")).toBe("User-Agent");
    expect(res.headers.get("strict-transport-security")).toBeNull();
  });

  it("nonces differ per response", async () => {
    const { app } = testApp(fake());
    const a = (await get(app, `/i/${TOKEN}`)).headers.get("content-security-policy");
    const b = (await get(app, `/i/${TOKEN}`)).headers.get("content-security-policy");
    expect(a).not.toBe(b);
  });

  it("adds HSTS and upgrade-insecure-requests in production", async () => {
    const res = await get(testApp(fake(), { mode: "production" }).app, `/i/${TOKEN}`);
    expect(res.headers.get("strict-transport-security")).toBe("max-age=63072000; includeSubDomains");
    expect(res.headers.get("content-security-policy")).toContain("upgrade-insecure-requests");
  });

  it("every response carries the headers, including errors and JSON", async () => {
    const { app } = testApp(fake());
    for (const path of ["/nope", "/healthz", "/.well-known/assetlinks.json", `/i/${TOKEN}/og.jpg`]) {
      const res = await get(app, path);
      expect(res.headers.get("x-content-type-options"), path).toBe("nosniff");
      expect(res.headers.get("content-security-policy"), path).toBeTruthy();
    }
  });
});

describe("rate limiting", () => {
  it("limits database lookups per address (token guessing)", async () => {
    const up = fake();
    const { app } = testApp(up, { rateLimitLookups: 2 });
    expect((await get(app, `/i/${"A".repeat(24)}`)).status).toBe(404);
    expect((await get(app, `/i/${"B".repeat(24)}`)).status).toBe(404);
    const third = await get(app, `/i/${"C".repeat(24)}`);
    expect(third.status).toBe(429);
    expect(Number(third.headers.get("retry-after"))).toBeGreaterThan(0);
    expect(visibleText(await third.text())).toContain(copy["invite.web.rateLimited.body"].replace("'", "&#39;"));
    expect(up.calls.preview).toBe(2);
  });

  it("cached lookups do not count; all requests have a ceiling", async () => {
    const up = fake();
    const { app } = testApp(up, { rateLimitLookups: 1, rateLimitRequests: 4 });
    for (let i = 0; i < 4; i++) expect((await get(app, `/i/${TOKEN}`)).status).toBe(200);
    expect((await get(app, `/i/${TOKEN}`)).status).toBe(429);
  });
});

describe("other routes", () => {
  it("/privacy and /terms redirect to the owner's documents", async () => {
    const { app } = testApp(null);
    const p = await app.request("/privacy");
    expect([p.status, p.headers.get("location")]).toEqual([302, "https://legal.example.com/privacy"]);
    const t = await app.request("/terms");
    expect([t.status, t.headers.get("location")]).toEqual([302, "https://legal.example.com/terms"]);
  });

  it("/privacy and /terms are 404 until configured", async () => {
    const { app } = testApp(null, {}, { ...FULL_APP_JSON, legal: { privacyUrl: null, termsUrl: null } });
    expect((await app.request("/privacy")).status).toBe(404);
    expect((await app.request("/terms")).status).toBe(404);
  });

  it("/healthz", async () => {
    const res = await testApp(null).app.request("/healthz");
    expect([res.status, await res.json(), res.headers.get("cache-control")]).toEqual([200, { status: "ok" }, "no-store"]);
  });

  it("unknown paths render the not-found state", async () => {
    const res = await testApp(null).app.request("/i");
    expect(res.status).toBe(404);
    expect(await res.text()).toContain(copy["invite.web.notFound.title"]);
  });
});
