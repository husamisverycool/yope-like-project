import sharp from "sharp";
import { beforeAll, describe, expect, it } from "vitest";
import { copy } from "../../src/generated/copy.js";
import { tokens } from "../../src/generated/tokens.js";
import { AVATAR_PX } from "../../src/images.js";
import type { InvitePreview } from "../../src/supabase.js";
import { ANDROID, DESKTOP, FULL_APP_JSON, IPHONE, testApp } from "../support/app.js";
import { FakeUpstream } from "../support/fakeUpstream.js";
import { EXIF_MARKER, testJpeg } from "../support/seed.js";

const UID_A = "11111111-2222-4333-8444-555555555555";
const UID_B = "66666666-7777-4888-9999-aaaaaaaaaaaa";
const TOKEN = "Tok3n_valid-Abcdefghijkl";
const COVER = `u/${UID_A}/covers/cover.jpg`;
const AVATAR = `avatars/${UID_A}/a.jpg`;
const c = copy as Record<string, string>;

const preview = (over: Partial<InvitePreview> = {}): InvitePreview => ({
  group_name: "Lima family",
  group_kind: "family",
  cover_path: COVER,
  inviter_first_name: "Ana",
  inviter_avatar_path: AVATAR,
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

/** Text in the document (both layouts; CSS shows one of them): the body without tags, styles and scripts. */
const visibleText = (html: string) =>
  html
    .replace(/<head>[\s\S]*?<\/head>/, "")
    .replace(/<style[\s\S]*?<\/style>/g, "")
    .replace(/<script[\s\S]*?<\/script>/g, "")
    .replace(/<svg[\s\S]*?<\/svg>/g, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim();

const get = (app: ReturnType<typeof testApp>["app"], path: string, ua = IPHONE) => app.request(path, { headers: { "user-agent": ua } });
const page = async (p = preview(), ua = IPHONE, appJson?: unknown) => (await get(testApp(fake(p), {}, appJson).app, `/i/${TOKEN}`, ua)).text();
const FOOTER = `${c["invite.web.footer.terms"]} & ${c["invite.web.footer.privacy"]}`;

describe("GET /i/:token — valid invite", () => {
  it("renders Retro's /u/ anatomy with copy only, and no counts", async () => {
    const { app } = testApp(fake());
    const res = await get(app, `/i/${TOKEN}`);
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toBe("text/html; charset=utf-8");
    const html = await res.text();
    const text = visibleText(html);
    expect(text).toBe(
      [
        c["invite.web.invitedBy"]!.replace("{first_name}", "Ana"),
        c["invite.web.body"]!.replace("{group_name}", "Lima family"),
        c["invite.web.desktop.scan"]!.replace("{group_name}", "Lima family"),
        c["invite.web.cta"],
        c["invite.web.opening"],
        c["invite.web.getApp"],
        // iPhone: the App Store listing first in the footer (Retro's separator)
        `${c["invite.web.getApp"]} · ${FOOTER}`,
      ].join(" "),
    );
    expect(text).not.toMatch(/[0-9]/); // no member count, no number of anything
    expect(html.match(/<h1/g)).toHaveLength(1);
    expect(html).toContain(`<h1 class="headline">Ana Invited You!</h1>`);
    expect(html).toContain(`<main class="card photo">\n<img class="backdrop" src="/i/${TOKEN}/cover.jpg" alt="Lima family cover">`);
    expect(html).toContain(`<img class="avatar" src="/i/${TOKEN}/avatar/0.jpg" alt="Ana">`);
  });

  it("draws the members' avatar stack in joining order, first names as alt text, no '+N'", async () => {
    const html = await page();
    expect(html).toContain(`<ul class="members mobile-only" aria-label="Members of Lima family">`);
    expect(html).toContain(`<li><img class="member" src="/i/${TOKEN}/avatar/0.jpg" alt="Ana" decoding="async"></li>`);
    expect(html).toMatch(/<li><span class="member" role="img" aria-label="Rui"><svg class="" viewBox="0 0 24 24" aria-hidden="true"/);
    // the member whose avatar could not be signed and who has no name: a decorative circle
    expect(html).toMatch(/<li><span class="member" aria-hidden="true"><svg/);
    expect(html).not.toContain(`/avatar/2.jpg`);
    // as many as fit invite.web.size.textMaxWidth at size.global.avatarSmall − overlap (13), never a count
    const many = preview({ members: Array.from({ length: 30 }, (_, i) => ({ first_name: `M${String.fromCharCode(97 + (i % 26))}`, avatar_path: null })) });
    const crowded = await page(many);
    const width = tokens["invite.web.size.textMaxWidth"];
    const d = tokens["size.global.avatarSmall"];
    const pitch = d - tokens["size.global.avatarStackOverlap"];
    expect(crowded.match(/class="member"/g)).toHaveLength(Math.floor((width - d) / pitch) + 1);
    expect(visibleText(crowded)).not.toMatch(/\+|[0-9]/);
  });

  it("shows the inviter's photo from invite_preview.inviter_avatar_path, not a first-name match", async () => {
    // two members named Ana: the inviter is the second one (her avatar path decides)
    const AVATAR_2 = `avatars/${UID_B}/b.jpg`;
    const up = fake(preview({ inviter_avatar_path: AVATAR_2, members: [{ first_name: "Ana", avatar_path: AVATAR }, { first_name: "Ana", avatar_path: AVATAR_2 }] }));
    up.objects.set(AVATAR_2, avatarJpeg);
    const html = await (await get(testApp(up).app, `/i/${TOKEN}`)).text();
    expect(html).toContain(`<img class="avatar" src="/i/${TOKEN}/avatar/1.jpg" alt="Ana">`);
  });

  it("falls back when the inviter has no photo or no name", async () => {
    const noPhoto = await page(preview({ inviter_avatar_path: null }));
    expect(noPhoto).toContain(`<span class="avatar" role="img" aria-label="Ana"></span>`);
    const noName = await page(preview({ inviter_first_name: null, inviter_avatar_path: null }));
    expect(noName).toContain(`<h1 class="headline">${c["invite.web.invitedFallback"]!.replace(/'/g, "&#39;")}</h1>`);
    expect(noName).toContain(`<span class="avatar" aria-hidden="true"></span>`);
  });

  it("backdrop (invite.web.layout.backdrop): the cover, else the inviter's avatar (decorative), else none; blurred and dimmed", async () => {
    const html = await page();
    const k = tokens["invite.web.layout.backdrop"].blurSigmaToWidth;
    expect(html).toContain(`filter:blur(calc(${k} * 100cqw))`);
    expect(html).toContain(`filter:blur(calc(${k} * (100vw - 2 * ${tokens["invite.web.size.cardInset"]}px)))`); // without container units
    expect(html).toContain("container-type:inline-size");
    expect(html).toMatch(/\.photo::after\{content:"";position:absolute;inset:0;z-index:-1;background:rgb\(0 0 0 \/ 0\.22[0-9]*\)\}/);
    const noCover = await page(preview({ cover_path: null }));
    expect(noCover).toContain(`<main class="card photo">\n<img class="backdrop" src="/i/${TOKEN}/avatar/0.jpg" alt="">`);
    const nothing = await page(preview({ cover_path: null, members: [{ first_name: "Ana", avatar_path: null }] }));
    expect(nothing).not.toContain(`class="backdrop"`);
    expect(nothing).toContain(`<main class="card">`);
  });

  it("exposes no non-preview field, storage path, user id, Supabase URL or key", async () => {
    const html = await page(preview({ group_kind: "roommates" }));
    for (const leak of [UID_A, UID_B, "avatars/", "/u/", "supabase", "storage", "anon", "service", "roommates", "group_kind", "Lastname"]) {
      expect(html.includes(leak), leak).toBe(false);
    }
    expect(html).not.toMatch(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/);
  });

  it("escapes database text", async () => {
    const html = await page(preview({ group_name: `<script>alert("x")</script>`, inviter_first_name: `<img src=x onerror=1>` }));
    expect(html).not.toContain("<script>alert");
    expect(html).not.toContain("<img src=x");
    expect(html).toContain("&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;");
  });

  it("has the link-preview tags of invite.web.layout.linkPreview", async () => {
    const html = await page();
    const meta = (attr: string, name: string) => new RegExp(`<meta ${attr}="${name}" content="([^"]*)">`).exec(html)?.[1];
    const title = c["invite.web.documentTitle"] ? c["invite.web.documentTitle"].replace("{title}", "Lima family") : "[BLOCKED invite.web.documentTitle]";
    expect(html).toContain(`<title>${title}</title>`);
    expect(meta("property", "og:title")).toBe("Join Lima family");
    expect(meta("name", "twitter:title")).toBe("Join Lima family");
    expect(meta("property", "og:description")).toBe(c["invite.web.og.description"]);
    expect(meta("name", "twitter:description")).toBe(c["invite.web.og.description"]);
    expect(meta("property", "og:url")).toBe(`https://invite.example.com/i/${TOKEN}`);
    expect(meta("property", "og:image")).toBe(`https://invite.example.com/i/${TOKEN}/og.png`);
    expect(meta("property", "og:image:type")).toBe("image/png");
    expect(meta("property", "og:image:width")).toBe("600");
    expect(meta("property", "og:image:height")).toBe("600");
    expect(meta("property", "og:image:alt")).toBe("Lima family cover");
    expect(meta("name", "twitter:card")).toBe("summary_large_image");
    expect(meta("name", "twitter:image")).toBe(`https://invite.example.com/i/${TOKEN}/og.png`);
    expect(meta("name", "robots")).toBe("noindex, noimageindex");
    expect(meta("name", "color-scheme")).toBe("light");
  });

  it("has the App Clip card meta tag (Retro's format, with the invite URL as app-argument)", async () => {
    const html = await page();
    expect(html).toContain(
      `<meta name="apple-itunes-app" content="app-id=1234567890, app-clip-bundle-id=com.example.groupphotos.Clip, app-clip-display=card, app-argument=https://invite.example.com/i/${TOKEN}">`,
    );
  });

  it("omits it and leaves the pill without a destination while the ids are BLOCKED", async () => {
    const html = await page(preview(), IPHONE, { ...FULL_APP_JSON, ios: { ...FULL_APP_JSON.ios, appStoreId: null, teamId: null } });
    expect(html).not.toContain("apple-itunes-app");
    expect(html).toContain(`<a class="pill mobile-only" data-opens aria-disabled="true" data-blocked="ios.appStoreId">`);
  });

  it.each([
    [IPHONE, `https://appclip.apple.com/id?p=com.example.groupphotos.Clip&amp;token=${TOKEN}`, "https://apps.apple.com/app/id1234567890"],
    [ANDROID, `https://play.google.com/store/apps/details?id=com.example.groupphotos&amp;referrer=invite_token%3D${TOKEN}`, `https://play.google.com/store/apps/details?id=com.example.groupphotos&amp;referrer=invite_token%3D${TOKEN}`],
    [DESKTOP, "https://apps.apple.com/app/id1234567890", "https://apps.apple.com/app/id1234567890"],
  ])("'Let's go' and 'Download the app' go to the App Clip / store (%#)", async (ua, letsGo, getApp) => {
    const html = await page(preview(), ua);
    expect(html).toContain(`<a class="pill mobile-only" data-opens href="${letsGo}" rel="noreferrer"><span class="label">${c["invite.web.cta"]!.replace(/'/g, "&#39;")}</span><span class="busy">${c["invite.web.opening"]}</span></a>`);
    expect(html).toContain(`<a class="link hit desktop-only" href="${getApp}" rel="noreferrer">${c["invite.web.getApp"]}</a>`);
  });

  it("footer: Terms & Privacy open the owner's documents in a new tab", async () => {
    const html = await page(preview(), ANDROID);
    expect(html).toContain(
      `<footer class="footer"><a class="hit" href="https://legal.example.com/terms" target="_blank" rel="noopener noreferrer">${c["invite.web.footer.terms"]}</a>&nbsp;&amp;&nbsp;<a class="hit" href="https://legal.example.com/privacy" target="_blank" rel="noopener noreferrer">${c["invite.web.footer.privacy"]}</a></footer>`,
    );
    const blocked = await page(preview(), IPHONE, { ...FULL_APP_JSON, legal: { privacyUrl: null, termsUrl: null } });
    expect(blocked).toContain(`data-blocked="legal.termsUrl"`);
    expect(blocked).toContain(`data-blocked="legal.privacyUrl"`);
  });

  it("iPhone footer: the App Store listing next to Terms & Privacy (the App Clip is 'Let's go'); not on Android or desktop", async () => {
    const download = `<span class="mobile-only"><a class="hit" href="https://apps.apple.com/app/id1234567890" rel="noreferrer">${c["invite.web.getApp"]}</a>&nbsp;·&nbsp;</span>`;
    expect(await page()).toContain(`<footer class="footer">${download}<a class="hit" href="https://legal.example.com/terms"`);
    expect(await page(preview(), ANDROID)).not.toContain("apps.apple.com");
    expect(await page(preview(), DESKTOP)).not.toContain(download);
    const noStore = await page(preview(), IPHONE, { ...FULL_APP_JSON, ios: { ...FULL_APP_JSON.ios, appStoreId: null } });
    expect(noStore).not.toContain(`<span class="mobile-only">`);
  });

  it("draws the desktop QR code inline (decorative; the line next to it says what it is)", async () => {
    const html = await page();
    expect(html).toMatch(new RegExp(`<div class="hero"><svg class="qr" viewBox="0 0 ${tokens["invite.web.size.qrDesktop"]} ${tokens["invite.web.size.qrDesktop"]}" shape-rendering="crispEdges" aria-hidden="true" focusable="false"><path fill="currentColor" d="M`));
  });

  it("the only script is the nonce'd 'Let's go' busy state; the pill works without it", async () => {
    const res = await get(testApp(fake()).app, `/i/${TOKEN}`);
    const html = await res.text();
    const nonce = /script-src 'nonce-([A-Za-z0-9+/=]+)'/.exec(res.headers.get("content-security-policy")!)![1]!;
    expect(html.match(/<script/g)).toHaveLength(1);
    expect(html).toContain(`<script nonce="${nonce}">`);
    expect(html).toContain(`setAttribute("aria-busy","true")`);
    expect(html).toMatch(/<a class="pill mobile-only" data-opens href="https:/);
  });

  it("answers HEAD", async () => {
    const res = await testApp(fake()).app.request(`/i/${TOKEN}`, { method: "HEAD" });
    expect(res.status).toBe(200);
  });
});

describe("GET /i/:token — other states", () => {
  it("unknown token → 404 not-found state, no member data", async () => {
    const up = fake();
    const res = await get(testApp(up).app, `/i/${"Z".repeat(24)}`);
    expect(res.status).toBe(404);
    const html = await res.text();
    expect(visibleText(html)).toBe(`${c["invite.web.notFound.title"]} ${FOOTER}`);
    expect(html).toContain(`<h1 class="headline">${c["invite.web.notFound.title"]!.replace(/'/g, "&#39;")}</h1>`);
    expect(html).toMatch(new RegExp(`<title>(${(c["invite.web.documentTitle"] ?? "").replace("{title}", c["invite.web.notFound.documentTitle"]!)}|\\[BLOCKED invite.web.documentTitle\\])</title>`));
    expect(html).not.toContain("Lima");
    expect(html).not.toContain("apple-itunes-app");
    expect(html).not.toContain("og:image");
    expect(html).not.toContain("<script");
    expect(res.headers.get("cache-control")).toBe("no-store");
    expect(up.calls.preview).toBe(1);
  });

  it.each(["short", "x".repeat(25), "with.dot.aaaaaaaaaaaaaaaa", "%2e%2e%2f%2e%2e%2fetc%2fpasswd", "AAAAAAAAAAAAAAAAAAAAAAA%3D"])("malformed token %s → 404 without any database call", async (bad) => {
    const up = fake();
    const { app } = testApp(up);
    expect((await get(app, `/i/${bad}`)).status).toBe(404);
    for (const sub of ["cover.jpg", "og.png", "avatar/0.jpg", "preview.json"]) {
      expect((await get(app, `/i/${bad}/${sub}`)).status).toBe(404);
    }
    expect(up.calls.preview + up.calls.sign + up.calls.fetch).toBe(0);
  });

  it.each(["expired", "revoked"] as const)("%s invite → 410, same page for both, no member data", async (reason) => {
    const up = fake();
    up.previews.set(TOKEN, { status: "unavailable", reason });
    const res = await get(testApp(up).app, `/i/${TOKEN}`);
    expect(res.status).toBe(410);
    const html = await res.text();
    expect(visibleText(html)).toBe(`${c["invite.web.unavailable.title"]} ${c["invite.web.unavailable.body"]} ${FOOTER}`);
    expect(html).not.toContain(reason);
    expect(html).not.toContain(`class="pill`);
    expect(res.headers.get("cache-control")).toBe("no-store");
  });

  it("upstream failure → 503 error state with a retry pill (mobile) and link (desktop), never cached", async () => {
    const up = fake();
    up.failPreview = true;
    const { app, logs } = testApp(up);
    const res = await get(app, `/i/${TOKEN}`);
    expect(res.status).toBe(503);
    const html = await res.text();
    const retry = c["invite.web.error.retry"];
    expect(visibleText(html)).toBe(`${c["invite.web.error.title"]} ${c["invite.web.error.body"]} ${retry} ${retry} ${FOOTER}`);
    expect(html).toContain(`<a class="pill mobile-only" href="/i/${TOKEN}">${retry}</a>`);
    expect(html).toContain(`<a class="link hit desktop-only" href="/i/${TOKEN}">${retry}</a>`);
    expect(res.headers.get("cache-control")).toBe("no-store");
    expect(logs.join("\n")).not.toContain(TOKEN);
    up.failPreview = false;
    expect((await get(app, `/i/${TOKEN}`)).status).toBe(200);
    expect(up.calls.preview).toBe(2);
  });

  it("no Supabase configured → 503", async () => {
    expect((await get(testApp(null).app, `/i/${TOKEN}`)).status).toBe(503);
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
    await get(app, `/i/${TOKEN}/og.png`);
    expect(up.calls.preview).toBe(1);
    up.previews.set(TOKEN, { status: "unavailable", reason: "revoked" });
    now = 59_000;
    expect((await get(app, `/i/${TOKEN}`)).status).toBe(200);
    now = 60_001;
    expect((await get(app, `/i/${TOKEN}`)).status).toBe(410);
    for (const sub of ["cover.jpg", "avatar/0.jpg", "og.png"]) expect((await get(app, `/i/${TOKEN}/${sub}`)).status).toBe(410);
    expect(up.calls.preview).toBe(2);
  });
});

/** Pixel reader for a decoded RGB(A) image. */
async function pixels(buf: Buffer) {
  const { data, info } = await sharp(buf).removeAlpha().raw().toBuffer({ resolveWithObject: true });
  return { info, at: (x: number, y: number) => [...data.subarray((y * info.width + x) * 3, (y * info.width + x) * 3 + 3)] };
}

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

  it("avatars are the mobile avatar size at 3x, square; missing ones are 404", async () => {
    const { app } = testApp(fake());
    const res = await get(app, `/i/${TOKEN}/avatar/0.jpg`);
    const meta = await sharp(Buffer.from(await res.arrayBuffer())).metadata();
    expect(AVATAR_PX).toBe(tokens["invite.web.size.avatar"] * 3);
    expect([meta.width, meta.height]).toEqual([AVATAR_PX, AVATAR_PX]);
    for (const p of ["avatar/1.jpg", "avatar/2.jpg", "avatar/3.jpg", "avatar/99.jpg", "avatar/x.jpg", "avatar/0.png"]) expect((await get(app, `/i/${TOKEN}/${p}`)).status).toBe(404);
  });

  it("og.png is the 600 × 600 share image of invite.web.layout.ogImage", async () => {
    const up = fake();
    up.objects.set(COVER, darkCover);
    const res = await get(testApp(up).app, `/i/${TOKEN}/og.png`);
    expect([res.status, res.headers.get("content-type"), res.headers.get("cross-origin-resource-policy")]).toEqual([200, "image/png", "cross-origin"]);
    const buf = Buffer.from(await res.arrayBuffer());
    const { info, at } = await pixels(buf);
    expect([info.width, info.height]).toEqual([600, 600]);
    // cover circle 83 px at x 258–340, y 208–290 (the dark cover: dark inside; corners of its box show the field)
    const inside = at(299, 249);
    expect(Math.max(...inside)).toBeLessThan(60);
    // text ink rows: bright pixels in the centre column band
    const rows: number[] = [];
    for (let y = 292; y < 420; y++) {
      for (let x = 100; x < 500; x++) {
        if (Math.min(...at(x, y)) > 120) {
          rows.push(y);
          break;
        }
      }
    }
    // name ("Lima family": ascenders l/f, descender y): ink from row 309 (avatar row 290 + 19)
    expect(rows[0]).toBeGreaterThanOrEqual(308);
    expect(rows[0]).toBeLessThanOrEqual(310);
    // domain line: its ink starts at row 369 (name baseline row 348 + 21)
    const domainTop = rows.find((y, i) => i > 0 && y - rows[i - 1]! > 1 && y > 360);
    expect(domainTop).toBeGreaterThanOrEqual(369);
    expect(domainTop).toBeLessThanOrEqual(370); // the top anti-aliased row may fall under the brightness threshold
  });

  it("og.png without a cover: color.global.backgroundDeep field and the placeholder circle", async () => {
    const res = await get(testApp(fake(preview({ cover_path: null }))).app, `/i/${TOKEN}/og.png`);
    expect(res.status).toBe(200);
    const { at } = await pixels(Buffer.from(await res.arrayBuffer()));
    expect(at(20, 20)).toEqual([0, 0, 0]);
    expect(at(299, 249)).toEqual([0xed, 0xed, 0xed]);
  });
});

describe("preview.json (App Clip and apps before joining)", () => {
  it("returns exactly the preview, with this service's image URLs", async () => {
    const res = await get(testApp(fake()).app, `/i/${TOKEN}/preview.json`);
    expect(res.status).toBe(200);
    expect(await res.json()).toStrictEqual({
      group_name: "Lima family",
      group_kind: "family",
      inviter_first_name: "Ana",
      inviter_avatar_url: `https://invite.example.com/i/${TOKEN}/avatar/0.jpg`,
      cover: { url: `https://invite.example.com/i/${TOKEN}/cover.jpg`, width: 1200, height: 900 },
      members: [
        { first_name: "Ana", avatar_url: `https://invite.example.com/i/${TOKEN}/avatar/0.jpg` },
        { first_name: "Rui", avatar_url: null },
        { first_name: null, avatar_url: null },
      ],
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
    expect(csp).toBe(`default-src 'none'; img-src 'self'; font-src 'self'; style-src 'nonce-${nonce}'; script-src 'nonce-${nonce}'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`);
    expect(await res.text()).toContain(`<style nonce="${nonce}">`);
    expect(res.headers.get("x-content-type-options")).toBe("nosniff");
    expect(res.headers.get("referrer-policy")).toBe("no-referrer");
    expect(res.headers.get("x-frame-options")).toBe("DENY");
    expect(res.headers.get("cross-origin-opener-policy")).toBe("same-origin");
    expect(res.headers.get("x-robots-tag")).toBe("noindex, noimageindex");
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

  it("every response carries the headers, including errors, images and JSON", async () => {
    const { app } = testApp(fake());
    for (const path of ["/nope", "/healthz", "/.well-known/assetlinks.json", `/i/${TOKEN}/og.png`, `/i/${TOKEN}/cover.jpg`]) {
      const res = await get(app, path);
      expect(res.headers.get("x-content-type-options"), path).toBe("nosniff");
      expect(res.headers.get("content-security-policy"), path).toBeTruthy();
      expect(res.headers.get("x-robots-tag"), path).toBe("noindex, noimageindex");
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
    expect(visibleText(await third.text())).toBe(`${c["invite.web.error.title"]} ${c["invite.web.rateLimited.body"]} ${FOOTER}`);
    expect(up.calls.preview).toBe(2);
  });

  it("cached lookups do not count; all requests have a ceiling", async () => {
    const up = fake();
    const { app } = testApp(up, { rateLimitLookups: 1, rateLimitRequests: 4 });
    for (let i = 0; i < 4; i++) expect((await get(app, `/i/${TOKEN}`)).status).toBe(200);
    expect((await get(app, `/i/${TOKEN}`)).status).toBe(429);
  });
});

describe("served face (font.global.displayNarrow, MERGE_DECISIONS L-8)", () => {
  it("the stylesheet declares it (swap, content-hashed URL) and the headline uses it", async () => {
    const html = await page();
    const m = /@font-face\{font-family:"Roboto Serif Headline";src:url\("(\/fonts\/RobotoSerifHeadline-Regular\.woff2\?v=[0-9a-f]{12})"\) format\("woff2"\);font-weight:400;font-style:normal;font-display:swap\}/.exec(html);
    expect(m).not.toBeNull();
    expect(html).toContain(`font-family:"Roboto Serif Headline", ui-serif, serif;`);
    const res = await testApp(null).app.request(m![1]!);
    expect([res.status, res.headers.get("content-type"), res.headers.get("cache-control")]).toEqual([200, "font/woff2", "public, max-age=31536000, immutable"]);
    const buf = Buffer.from(await res.arrayBuffer());
    expect(buf.subarray(0, 4).toString("latin1")).toBe("wOF2");
  });

  it("serves nothing else under /fonts/", async () => {
    const { app } = testApp(null);
    for (const p of ["/fonts/Inter-Variable.ttf", "/fonts/RobotoSerifHeadline-Regular.ttf", "/fonts/fonts.conf", "/fonts/..%2Fsrc%2Fapp.ts", "/fonts/"]) {
      expect((await app.request(p)).status, p).toBe(404);
    }
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
    expect(await res.text()).toContain(c["invite.web.notFound.title"]!.replace(/'/g, "&#39;"));
  });
});
