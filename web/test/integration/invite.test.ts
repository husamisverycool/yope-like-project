// Integration: the web service against the local Supabase stack (cd backend && npm run db:start).
// Every run creates its own users, files, group and invites and removes them afterwards; the stack
// is shared with other test suites, so nothing here assumes an empty database.

import sharp from "sharp";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { copy } from "../../src/generated/copy.js";
import { AVATAR_PX } from "../../src/images.js";
import { InviteService } from "../../src/inviteService.js";
import { supabaseUpstream, type Upstream } from "../../src/supabase.js";
import { createApp } from "../../src/app.js";
import { IPHONE, testConfig } from "../support/app.js";
import {
  ANON_KEY,
  cleanup,
  createInvite,
  EXIF_MARKER,
  expireInvite,
  inviteExpiry,
  revokeInvite,
  SERVICE_ROLE_KEY,
  seedGroup,
  stackAvailable,
  SUPABASE_URL,
  type SeededGroup,
} from "../support/seed.js";

let g: SeededGroup;
let noCover: SeededGroup;

/** Real upstream wrapped to count calls. */
function counting(url = SUPABASE_URL) {
  const real = supabaseUpstream({ url, anonKey: ANON_KEY, serviceRoleKey: SERVICE_ROLE_KEY, timeoutMs: 3000 });
  const calls = { preview: 0, sign: 0, fetch: 0 };
  const up: Upstream = {
    invitePreview: (t) => (calls.preview++, real.invitePreview(t)),
    signPaths: (p, e) => (calls.sign++, real.signPaths(p, e)),
    fetchObject: (u) => (calls.fetch++, real.fetchObject(u)),
  };
  return { up, calls };
}

function app(opts: { url?: string; ttlSeconds?: number } = {}) {
  const config = testConfig({ supabase: { url: opts.url ?? SUPABASE_URL, anonKey: ANON_KEY, serviceRoleKey: SERVICE_ROLE_KEY }, inviteCacheSeconds: opts.ttlSeconds ?? 60 });
  const { up, calls } = counting(opts.url);
  const invites = new InviteService(up, { ttlSeconds: config.inviteCacheSeconds, signedUrlSeconds: config.signedUrlSeconds });
  return { app: createApp({ config, invites, log: () => {}, peer: () => "198.51.100.9" }), calls };
}

const get = (a: ReturnType<typeof app>["app"], path: string) => a.request(path, { headers: { "user-agent": IPHONE } });
const visible = (html: string) =>
  html
    .replace(/<head>[\s\S]*?<\/head>/, "")
    .replace(/<script[\s\S]*?<\/script>/g, "")
    .replace(/<svg[\s\S]*?<\/svg>/g, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, " ")
    .trim();

beforeAll(async () => {
  if (!(await stackAvailable())) throw new Error(`local Supabase stack not reachable at ${SUPABASE_URL} (cd backend && npm run db:start), or set WEB_SKIP_INTEGRATION=1`);
  g = await seedGroup({ name: `Lima family ${Math.random().toString(36).slice(2, 6).replace(/[0-9]/g, "x")}` });
  noCover = await seedGroup({ name: "Roommates", cover: null });
});

afterAll(async () => {
  if (g) await cleanup(g);
  if (noCover) await cleanup(noCover);
});

describe("valid invite (local stack)", () => {
  it("renders the group, inviter and members, and nothing else", async () => {
    const { app: a } = app();
    const res = await get(a, `/i/${g.token}`);
    expect(res.status).toBe(200);
    const html = await res.text();
    const text = visible(html);
    expect(text).toContain(copy["invite.web.invitedBy"].replace("{first_name}", "Ana"));
    expect(html).toContain(`<img class="avatar" src="/i/${g.token}/avatar/0.jpg" alt="Ana">`);
    expect(html).toContain(`aria-label="Rui"`); // member without a photo
    expect(html).toContain(`<img class="backdrop" src="/i/${g.token}/cover.jpg" alt="`);
    expect(text).not.toContain("Lima Lastname");
    expect(text).not.toContain("Costa"); // first names only
    expect(text).not.toMatch(/[0-9]/); // no member count or any other number
    for (const id of g.users) expect(html).not.toContain(id);
    for (const p of g.paths) expect(html).not.toContain(p);
    expect(html).not.toContain(SUPABASE_URL);
    expect(html).not.toContain(ANON_KEY);
    expect(html).not.toContain(SERVICE_ROLE_KEY);
    expect(html).not.toContain(g.groupId);
    expect(html).not.toMatch(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/);
  });

  it("serves the cover and avatar re-encoded, without the uploaded metadata", async () => {
    const { app: a } = app();
    const cover = Buffer.from(await (await get(a, `/i/${g.token}/cover.jpg`)).arrayBuffer());
    expect(cover.includes(Buffer.from(EXIF_MARKER))).toBe(false);
    expect((await sharp(cover).metadata()).width).toBe(1200);
    const avatar = await get(a, `/i/${g.token}/avatar/0.jpg`);
    expect(avatar.status).toBe(200);
    const meta = await sharp(Buffer.from(await avatar.arrayBuffer())).metadata();
    expect([meta.width, meta.height, meta.exif]).toEqual([AVATAR_PX, AVATAR_PX, undefined]);
    expect((await get(a, `/i/${g.token}/avatar/1.jpg`)).status).toBe(404); // Rui has no avatar
  });

  it("serves the 600×600 link-preview image and its tags", async () => {
    const { app: a } = app();
    const html = await (await get(a, `/i/${g.token}`)).text();
    expect(html).toContain(`<meta property="og:image" content="https://invite.example.com/i/${g.token}/og.png">`);
    const og = await get(a, `/i/${g.token}/og.png`);
    const meta = await sharp(Buffer.from(await og.arrayBuffer())).metadata();
    expect([og.status, meta.format, meta.width, meta.height]).toEqual([200, "png", 600, 600]);
  });

  it("serves preview.json for the App Clip", async () => {
    const { app: a } = app();
    const body = (await (await get(a, `/i/${g.token}/preview.json`)).json()) as Record<string, any>;
    expect(Object.keys(body).sort()).toEqual(["cover", "group_kind", "group_name", "inviter_avatar_url", "inviter_first_name", "members"]);
    expect(body.inviter_avatar_url).toBe(`https://invite.example.com/i/${g.token}/avatar/0.jpg`); // from invite_preview.inviter_avatar_path
    expect(body.members).toEqual([
      { first_name: "Ana", avatar_url: `https://invite.example.com/i/${g.token}/avatar/0.jpg` },
      { first_name: "Rui", avatar_url: null },
      { first_name: null, avatar_url: null },
    ]);
    expect(JSON.stringify(body)).not.toContain("avatars/");
  });

  it("a group without a cover: the inviter's avatar is the backdrop, the preview image has a black field", async () => {
    const { app: a } = app();
    const html = await (await get(a, `/i/${noCover.token}`)).text();
    expect(html).toContain(`<img class="backdrop" src="/i/${noCover.token}/avatar/0.jpg" alt="">`);
    const og = await get(a, `/i/${noCover.token}/og.png`);
    const { data } = await sharp(Buffer.from(await og.arrayBuffer())).removeAlpha().raw().toBuffer({ resolveWithObject: true });
    expect([og.status, data[0], data[1], data[2]]).toEqual([200, 0, 0, 0]);
  });

  it("sends the security and cache headers", async () => {
    const { app: a } = app();
    const res = await get(a, `/i/${g.token}`);
    expect(res.headers.get("cache-control")).toBe("private, max-age=60");
    expect(res.headers.get("content-security-policy")).toMatch(/^default-src 'none'; img-src 'self'; font-src 'self'; style-src 'nonce-/);
    expect(res.headers.get("x-content-type-options")).toBe("nosniff");
    expect(res.headers.get("referrer-policy")).toBe("no-referrer");
    expect(res.headers.get("x-robots-tag")).toBe("noindex, noimageindex");
  });
});

describe("other states (local stack)", () => {
  it("unknown token → 404 not found", async () => {
    const { app: a, calls } = app();
    const res = await get(a, `/i/${"N".repeat(24)}`);
    expect(res.status).toBe(404);
    expect(visible(await res.text())).toContain(copy["invite.web.notFound.title"]);
    expect(calls.preview).toBe(1);
    expect(calls.sign).toBe(0);
  });

  it("malformed token → 404 without a database call", async () => {
    const { app: a, calls } = app();
    for (const bad of ["abc", `${g.token}x`, g.token.slice(0, 23) + "!"]) expect((await get(a, `/i/${encodeURIComponent(bad)}`)).status).toBe(404);
    expect(calls).toEqual({ preview: 0, sign: 0, fetch: 0 });
  });

  it("a new link has no expiry (owner decision 27) and keeps working", async () => {
    const token = await createInvite(g.groupId, g.memberIds.ana);
    expect(await inviteExpiry(token)).toBeNull();
    expect((await get(app().app, `/i/${token}`)).status).toBe(200);
  });

  it("a link given an expiry (only if invite_ttl_seconds is set) → 410 once past it", async () => {
    const token = await createInvite(g.groupId, g.memberIds.ana);
    await expireInvite(token);
    const res = await get(app().app, `/i/${token}`);
    expect(res.status).toBe(410);
    const html = await res.text();
    expect(visible(html)).toContain(copy["invite.web.unavailable.title"]);
    expect(html).not.toContain("Ana");
  });

  it("revoked invite → 410, and a cached page stops showing after the cache TTL", async () => {
    const token = await createInvite(g.groupId, g.memberIds.ana);
    const { app: a } = app({ ttlSeconds: 1 });
    expect((await get(a, `/i/${token}`)).status).toBe(200);
    await revokeInvite(token, g.memberIds.ana);
    await new Promise((r) => setTimeout(r, 1100));
    const res = await get(a, `/i/${token}`);
    expect(res.status).toBe(410);
    expect(visible(await res.text())).toContain(copy["invite.web.unavailable.body"]);
    expect((await get(a, `/i/${token}/cover.jpg`)).status).toBe(410);
  });

  it("Supabase unreachable → 503 error state", async () => {
    const res = await get(app({ url: "http://127.0.0.1:9" }).app, `/i/${g.token}`);
    expect(res.status).toBe(503);
    const html = await res.text();
    expect(visible(html)).toContain(copy["invite.web.error.title"]);
    expect(res.headers.get("cache-control")).toBe("no-store");
  });
});
