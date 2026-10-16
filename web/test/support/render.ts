/// <reference lib="dom" />
/// <reference lib="dom.iterable" />
// Rendering harness for the invite page: serves the real app (fake upstream, real sample photos from
// fixtures/photos) on a local port and opens it in Playwright Chromium (PLAYWRIGHT_BROWSERS_PATH, e.g.
// /opt/pw-browsers). Used by test/render/invite.render.test.ts and scripts/verify.ts.
//
// Viewports are the capture setups of Retro's references: mobile = Playwright "iPhone 13" (390 × 664 CSS px at 3x,
// references/auto/retro/web/retro.app-u-nathan-iphone.png is 1170 × 1992), desktop = 1440 × 900 at 1x
// (retro.app-u-nathan-desktop.png).

import fs from "node:fs";
import type { AddressInfo } from "node:net";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { serve } from "@hono/node-server";
import { chromium, type Browser, type BrowserContext, type Page } from "playwright-core";
import type { InvitePreview } from "../../src/supabase.js";
import { DESKTOP, IPHONE, testApp } from "./app.js";
import { FakeUpstream } from "./fakeUpstream.js";

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
export const OUT_DIR = path.join(ROOT, "design/verification/invite.web");
export const photo = (name: string): Buffer => fs.readFileSync(path.join(ROOT, "fixtures/photos", name));

const UID = ["11111111-2222-4333-8444-555555555555", "66666666-7777-4888-9999-aaaaaaaaaaaa"] as const;
export const TOKENS = {
  valid: "Va1id_invite-Abcdefghijk",
  noCover: "NoCover_invite-Abcdefghi",
  noPhotos: "NoPhoto_invite-Abcdefghi",
  expired: "Expired_invite-Abcdefghi",
  revoked: "Revoked_invite-Abcdefghi",
  unknown: "Unknown_invite-Abcdefghi",
} as const;

const avatarPath = (n: number) => `avatars/${UID[n % 2]}/a${n}.jpg`;
const COVER = `u/${UID[0]}/covers/family-dinner.jpg`;

export const GROUP = "Lima family";
const MEMBERS = ["Ana", "Rui", "Bea", "Joana", "Tiago", "Marta", "Duarte", "Inês"];
/** Who has a photo (Rui has none: the C-23 no-photo circle). */
const HAS_PHOTO = [true, false, true, true, true, true, true, true];

export function fixtureUpstream(): FakeUpstream {
  const up = new FakeUpstream();
  const members = MEMBERS.map((first_name, i) => ({ first_name, avatar_path: HAS_PHOTO[i] ? avatarPath(i) : null }));
  const base: InvitePreview = { group_name: GROUP, group_kind: "family", cover_path: COVER, inviter_first_name: "Ana", members };
  up.setPreview(TOKENS.valid, base);
  up.setPreview(TOKENS.noCover, { ...base, group_name: "Roommates", cover_path: null, members: members.slice(0, 3) });
  up.setPreview(TOKENS.noPhotos, { ...base, group_name: "Roommates", cover_path: null, inviter_first_name: "Rui", members: [members[1]!] });
  up.previews.set(TOKENS.expired, { status: "unavailable", reason: "expired" });
  up.previews.set(TOKENS.revoked, { status: "unavailable", reason: "revoked" });
  up.objects.set(COVER, photo("family-dinner-4x3.jpg"));
  MEMBERS.forEach((_, i) => {
    if (HAS_PHOTO[i]) up.objects.set(avatarPath(i), photo(`avatar-${String(i + 1).padStart(2, "0")}.jpg`));
  });
  return up;
}

export interface Server {
  base: string;
  close: () => Promise<void>;
}

/** Serves an app on 127.0.0.1 (random port). */
export async function serveApp(app: ReturnType<typeof testApp>["app"]): Promise<Server> {
  const server = serve({ fetch: app.fetch, port: 0, hostname: "127.0.0.1" });
  await new Promise((r) => server.once("listening", r));
  const base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  return { base, close: () => new Promise((r) => server.close(() => r())) };
}

export type Layout = "mobile" | "desktop";
export type Scheme = "light" | "dark";

export const VIEWPORTS: Record<Layout, Parameters<Browser["newContext"]>[0]> = {
  mobile: { viewport: { width: 390, height: 664 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true, userAgent: IPHONE },
  desktop: { viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1, userAgent: DESKTOP },
};

/** Chromium with the bundled faces visible to it (web/assets/fonts/fonts.conf: "Noto Serif" — Android's serif, named
 *  in the display stack — then the system fonts), so renders on a Linux runner show a platform serif. */
export async function launch(): Promise<Browser> {
  return chromium.launch({ env: { ...process.env, FONTCONFIG_FILE: path.join(ROOT, "web/assets/fonts/fonts.conf") } });
}

export async function open(browser: Browser, layout: Layout, scheme: Scheme): Promise<{ context: BrowserContext; page: Page }> {
  const context = await browser.newContext({ ...VIEWPORTS[layout], colorScheme: scheme, reducedMotion: "reduce" });
  // "Let's go" leaves for the App Clip / store: never reach the network from a test.
  await context.route(/^https:\/\/(appclip\.apple\.com|apps\.apple\.com|play\.google\.com)\//, (r) => r.abort());
  return { context, page: await context.newPage() };
}

/** Navigates and waits until every image has loaded (or failed). */
export async function load(page: Page, url: string): Promise<number> {
  const res = await page.goto(url, { waitUntil: "networkidle" });
  await page.evaluate(() => Promise.all([...document.images].map((i) => (i.complete ? null : new Promise((r) => (i.onload = i.onerror = r))))));
  return res?.status() ?? 0;
}

export type Box = { x: number; y: number; w: number; h: number; bottom: number; right: number };

/** Bounding box and computed style of the first element matching `sel`. */
export async function measure(page: Page, sel: string, props: string[] = []): Promise<{ box: Box; s: Record<string, string> }> {
  return page.evaluate(
    ([sel, props]) => {
      const el = document.querySelector(sel as string);
      if (!el) throw new Error(`no element ${sel}`);
      const r = el.getBoundingClientRect();
      const cs = getComputedStyle(el);
      const s: Record<string, string> = {};
      for (const p of props as string[]) s[p] = cs.getPropertyValue(p);
      const n = (v: number) => +v.toFixed(2);
      return { box: { x: n(r.x), y: n(r.y), w: n(r.width), h: n(r.height), bottom: n(r.bottom), right: n(r.right) }, s };
    },
    [sel, props] as const,
  );
}

export type CaseName = "valid" | "valid-no-cover" | "valid-no-photos" | "unavailable" | "not-found" | "error" | "rate-limited";

/** Every state of design/surfaces/invite.web.md "States", plus the valid page's backdrop fallbacks. */
export const CASES: { name: CaseName; token: string; status: number; server: "main" | "error" | "rateLimited" }[] = [
  { name: "valid", token: TOKENS.valid, status: 200, server: "main" },
  { name: "valid-no-cover", token: TOKENS.noCover, status: 200, server: "main" },
  { name: "valid-no-photos", token: TOKENS.noPhotos, status: 200, server: "main" },
  { name: "unavailable", token: TOKENS.expired, status: 410, server: "main" },
  { name: "not-found", token: TOKENS.unknown, status: 404, server: "main" },
  { name: "error", token: TOKENS.valid, status: 503, server: "error" },
  { name: "rate-limited", token: TOKENS.unknown, status: 429, server: "rateLimited" },
];

/** The three servers the cases need: fixtures, upstream down (503), and an address over its lookup limit (429). */
export async function serveCases(): Promise<Record<"main" | "error" | "rateLimited", Server> & { close: () => Promise<void> }> {
  const main = await serveApp(testApp(fixtureUpstream()).app);
  const down = fixtureUpstream();
  down.failPreview = true;
  const error = await serveApp(testApp(down).app);
  const rateLimited = await serveApp(testApp(fixtureUpstream(), { rateLimitLookups: 1 }).app);
  await fetch(`${rateLimited.base}/i/${TOKENS.revoked}`); // the address's one lookup this minute
  return { main, error, rateLimited, close: async () => void (await Promise.all([main.close(), error.close(), rateLimited.close()])) };
}
