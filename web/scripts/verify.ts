/// <reference lib="dom" />
// Verification of invite.web against Partiful (design/surfaces/invite.web.md).
//
//   npm run verify     (needs the local Supabase stack: cd backend && npm run db:start)
//
// Seeds two groups (light cover, dark cover) and an expired invite in the local stack, serves the
// real app, renders it in Playwright Chromium (/opt/pw-browsers) at 390×844 CSS px @3x with an
// iPhone user agent — the capture setup of design/research/wrapped-tribute-partiful.md — and writes
//   design/verification/invite.web.png  side by side, ours left, Partiful right, same height:
//       row 1  top of the page            | pf-web-private-past-01.png (link-only event, logged out)
//       row 2  scrolled to 'Invited by'   | pf-web-private-past-02.png ('Hosted by' at the same y)
//       row 3  not-found state            | pf-web-notfound-01.png
//   design/verification/invite.web.md   every token: reference value vs computed style read back
//                                         from the page, plus the WCAG contrast results.
// Everything seeded is deleted at the end.

import fs from "node:fs";
import type { AddressInfo } from "node:net";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { serve } from "@hono/node-server";
import { chromium, type Page } from "playwright-core";
import sharp, { type OverlayOptions } from "sharp";
import { createApp } from "../src/app.js";
import { invitePairs, statePairs, type PairResult } from "../src/contrastReport.js";
import { num, tokens, type TokenName } from "../src/design.js";
import { InviteService } from "../src/inviteService.js";
import { supabaseUpstream } from "../src/supabase.js";
import { defaultTheme, themeFromColour, type Rgb } from "../src/theme.js";
import { titleSize } from "../src/titleFit.js";
import { IPHONE, testConfig } from "../test/support/app.js";
import {
  ANON_KEY,
  cleanup,
  createGroup,
  createInvite,
  createUser,
  deleteUser,
  expireInvite,
  joinGroup,
  removeObjects,
  SERVICE_ROLE_KEY,
  setAvatar,
  stackAvailable,
  SUPABASE_URL,
  upload,
  type SeededGroup,
} from "../test/support/seed.js";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const OUT_PNG = path.join(ROOT, "design/verification/invite.web.png");
const OUT_MD = path.join(ROOT, "design/verification/invite.web.md");
const REF = (f: string) => path.join(ROOT, "references/auto/partiful/web", f);

// ---------- test images (synthetic; no reference image is reused as content) ----------
async function radial(w: number, h: number, inner: Rgb, outer: Rgb): Promise<Buffer> {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><defs><radialGradient id="g" cx="50%" cy="45%" r="70%"><stop offset="0" stop-color="rgb(${inner})"/><stop offset="1" stop-color="rgb(${outer})"/></radialGradient></defs><rect width="100%" height="100%" fill="url(#g)"/></svg>`;
  return sharp(Buffer.from(svg)).jpeg().toBuffer();
}

interface Seed {
  group: SeededGroup;
  name: string;
}

async function seed(name: string, cover: Buffer, members: { name: string; avatar?: Rgb }[]): Promise<Seed> {
  const users: string[] = [];
  const paths: string[] = [];
  for (const m of members) {
    const id = await createUser(m.name);
    users.push(id);
    if (m.avatar) {
      const p = `avatars/${id}/${crypto.randomUUID()}.jpg`;
      await upload(p, await radial(300, 300, m.avatar, m.avatar.map((c) => c * 0.55) as Rgb));
      await setAvatar(id, p);
      paths.push(p);
    }
  }
  const coverPath = `u/${users[0]}/covers/${crypto.randomUUID()}.jpg`;
  await upload(coverPath, cover);
  paths.push(coverPath);
  const groupId = await createGroup({ name, coverPath, createdBy: users[0]! });
  const token = await createInvite(groupId, users[0]!);
  for (const u of users.slice(1)) await joinGroup(token, u);
  return { name, group: { groupId, token, users, paths, memberIds: { ana: users[0]!, rui: users[1]!, anon: users[2]! } } };
}

// ---------- server ----------
async function start(url: string) {
  const config = testConfig({ supabase: { url, anonKey: ANON_KEY, serviceRoleKey: SERVICE_ROLE_KEY } });
  const invites = new InviteService(supabaseUpstream({ url, anonKey: ANON_KEY, serviceRoleKey: SERVICE_ROLE_KEY, timeoutMs: 3000 }), { ttlSeconds: 60, signedUrlSeconds: 120 });
  const app = createApp({ config, invites, log: () => {} });
  const server = serve({ fetch: app.fetch, port: 0, hostname: "127.0.0.1" });
  await new Promise((r) => server.once("listening", r));
  return { server, base: `http://127.0.0.1:${(server.address() as AddressInfo).port}` };
}

// ---------- measuring ----------
type Box = { x: number; y: number; w: number; h: number; bottom: number; right: number };
async function measure(page: Page, sel: string): Promise<{ box: Box; s: Record<string, string> }> {
  return page.evaluate((sel) => {
    const el = document.querySelector(sel);
    if (!el) throw new Error(`no element ${sel}`);
    const r = el.getBoundingClientRect();
    const cs = getComputedStyle(el);
    const s: Record<string, string> = {};
    for (const p of ["color", "background-color", "font-size", "font-weight", "line-height", "letter-spacing", "text-align", "text-transform", "border-radius", "border-top", "border-bottom", "padding-left", "padding-top", "padding-bottom", "margin-bottom", "height", "width", "max-width", "opacity", "backdrop-filter", "outline", "outline-offset", "transition", "text-decoration-line", "font-family"]) s[p] = cs.getPropertyValue(p);
    const y = r.y + window.scrollY;
    return { box: { x: +r.x.toFixed(2), y: +y.toFixed(2), w: +r.width.toFixed(2), h: +r.height.toFixed(2), bottom: +(y + r.height).toFixed(2), right: +(r.x + r.width).toFixed(2) }, s };
  }, sel);
}

/** Declared value of a rule in the inline stylesheet (for states that need a pointer: :hover/:active). */
async function ruleValue(page: Page, selector: string, prop: string): Promise<string> {
  // A string expression: tsx's name helpers must not leak into the browser context.
  return page.evaluate(`(() => {
    const sel = ${JSON.stringify(selector)}, prop = ${JSON.stringify(prop)};
    const stack = [...document.styleSheets].flatMap((s) => [...s.cssRules]);
    while (stack.length) {
      const r = stack.shift();
      if (r instanceof CSSStyleRule && r.selectorText === sel) return r.style.getPropertyValue(prop);
      if (r.cssRules) stack.push(...r.cssRules);
    }
    return "";
  })()`);
}

interface Row {
  token: string;
  reference: string;
  expected: string;
  actual: string;
  ok: boolean;
}
const rows: { section: string; rows: Row[] }[] = [];
let current: Row[] = [];
function section(name: string) {
  current = [];
  rows.push({ section: name, rows: current });
}
const close = (a: string, b: string) => {
  const na = parseFloat(a);
  const nb = parseFloat(b);
  if (!Number.isNaN(na) && !Number.isNaN(nb) && /^-?[0-9.]+(px|em)?$/.test(a.trim()) && /^-?[0-9.]+(px|em)?$/.test(b.trim())) return Math.abs(na - nb) <= 0.06;
  return a.replace(/\s+/g, " ").trim() === b.replace(/\s+/g, " ").trim();
};
function check(token: string, reference: string, expected: string | number, actual: string | number) {
  const e = String(expected);
  const a = String(actual);
  current.push({ token, reference, expected: e, actual: a, ok: close(e, a) });
}
const pxv = (n: TokenName) => `${num(n)}px`;
const rgba = (rgb: string, a: number) => `rgba(${rgb}, ${a})`;
const round = (n: number) => +n.toFixed(2);

async function main() {
  if (!(await stackAvailable())) throw new Error(`local Supabase stack not reachable at ${SUPABASE_URL} (cd backend && npm run db:start)`);
  const lightCover = await radial(1080, 1080, [251, 228, 242], [167, 200, 255]);
  const darkCover = await radial(1080, 1080, [70, 24, 24], [28, 6, 6]);
  const people = [
    { name: "Ana Lima", avatar: [222, 112, 120] as Rgb },
    { name: "Rui Costa" },
    { name: "Bea Lima", avatar: [120, 170, 220] as Rgb },
    { name: "Joana Reis", avatar: [197, 219, 118] as Rgb },
    { name: "Tiago Lima" },
    { name: "Marta Sousa", avatar: [212, 214, 241] as Rgb },
    { name: "Duarte Lima", avatar: [222, 112, 214] as Rgb },
    { name: "Inês Lima" },
  ];
  const seeds: Seed[] = [];
  let expiredToken = "";
  const extraUsers: string[] = [];
  const { server, base } = await start(SUPABASE_URL);
  const broken = await start("http://127.0.0.1:9");
  const browser = await chromium.launch();
  try {
    const light = await seed("Sunday dinners at the Limas", lightCover, people);
    seeds.push(light);
    const dark = await seed("Roommates", darkCover, people.slice(0, 3));
    seeds.push(dark);
    expiredToken = await createInvite(light.group.groupId, light.group.users[0]!);
    await expireInvite(expiredToken);

    const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true, userAgent: IPHONE });
    const page = await ctx.newPage();

    // ---------- light page ----------
    await page.goto(`${base}/i/${light.group.token}`, { waitUntil: "networkidle" });
    const shotTop = await page.screenshot();
    const m = async (s: string) => measure(page, s);
    const html = await m("html");
    const body = await m("body");
    const column = await m(".column");
    const title = await m(".title");
    const cover = await m(".cover");
    const field = await m(".field");
    const members = await m(".members");
    const head = await m(".members-head");
    const header = await m("#members-title");
    const viewAll = await m(".all > summary");
    const av1 = await m(".avatars li:nth-child(1) .avatar");
    const av3 = await m(".avatars li:nth-child(3)");
    const initials = await m(".avatars li:nth-child(2) .initials");
    const gate = await m(".gate");
    const lock = await m(".gate .lock");
    const gateTitle = await m("#gate-title");
    const gateBody = await m(".gate-body");
    const gateBtn = await m(".gate .btn-filled");
    const divider = await m(".divider");
    const link = await m(".get-app");
    const linkText = await m(".get-app span");
    const arrow = await m(".get-app svg");
    const coverMean = (await sharp(Buffer.from(await (await fetch(`${base}/i/${light.group.token}/cover.jpg`)).arrayBuffer())).stats()).channels.slice(0, 3).map((c) => c.mean) as Rgb;
    const theme = themeFromColour(coverMean);
    const tSize = titleSize(light.name, round(title.box.w));

    section("Page frame and theme");
    check("invite.web.dimension.margin", "16 px: P3 title/poster/date x 16; CSS --spacing-screen-margin-horizontal", pxv("invite.web.dimension.margin"), `${cover.box.x}px`);
    check("invite.web.dimension.columnMaxWidth", "720 px: CSS @media (min-width:721px) switch", pxv("invite.web.dimension.columnMaxWidth"), column.s["max-width"]!);
    check("invite.web.layout.theme", "per-invite theme colour (P3 body rgb(167, 200, 255)); ours = mean colour of the cover", (() => { const [r, g, b] = theme.background.match(/[0-9A-F]{2}/g)!.map((h) => parseInt(h, 16)); return `rgb(${r}, ${g}, ${b})`; })(), html.s["background-color"]!);
    check("invite.web.layout.themeTextColour", "class follows the theme (P3 .ptf-light → black text)", theme.scheme === "light" ? "rgb(0, 0, 0)" : "rgb(255, 255, 255)", body.s.color!);
    check("invite.web.color.text.light", "rgb(0, 0, 0): P3 title colour", "rgb(0, 0, 0)", title.s.color!);
    check("invite.web.font", "TWK Lausanne (proprietary) → platform UI font", "-apple-system, system-ui, sans-serif", body.s["font-family"]!);
    check("invite.web.lineHeight.default", "1.4: P3 22.4 px at 16 px", `${16 * num("invite.web.lineHeight.default")}px`, field.s["line-height"]!);
    check("invite.web.layout.text", "antialiased (CSS :root)", "antialiased", await page.evaluate(() => getComputedStyle(document.body).getPropertyValue("-webkit-font-smoothing")));

    section("Title");
    check("invite.web.dimension.titleTop", "109.1 px: P3 h1 top 169.1 − 60-px banner", pxv("invite.web.dimension.titleTop"), `${title.box.y}px`);
    check("invite.web.fontSize.title.base / .singleLineMax / .min / count.title.maxLines / layout.title.fit", `P3 'Fun Times w/ the Ryans' → 39 px at 358 px; ours '${light.name}' at ${round(title.box.w)} px`, `${tSize}px`, title.s["font-size"]!);
    check("invite.web.fontWeight.title", "700: P3 span.summary", "700", title.s["font-weight"]!);
    check("invite.web.lineHeight.title", "1.2: P3 46.8/39", `${round(tSize * num("invite.web.lineHeight.title"))}px`, title.s["line-height"]!);
    check("invite.web.letterSpacing.title", "−0.02 em: P3 −0.78 px at 39 px", `${round(tSize * num("invite.web.letterSpacing.title"))}px`, title.s["letter-spacing"]!);
    check("invite.web.layout.title", "centre: P3 span centred in the column", "center", title.s["text-align"]!);
    check("invite.web.dimension.titleToCover", "25.8 px: P3 262.7 → 288.6; P1 319.3 → 345", pxv("invite.web.dimension.titleToCover"), `${round(cover.box.y - title.box.bottom)}px`);

    section("Cover");
    check("invite.web.layout.cover", "full column width, own aspect: P3 358 × 358", `358px × ${round(358 * 1)}px`, `${cover.box.w}px × ${cover.box.h}px`);
    check("invite.web.radius.cover", "0: P3 img border-radius 0px", "0px", cover.s["border-radius"]!);
    check("invite.web.dimension.coverToNext", "16 px: P3 poster bottom 646.6 → date 662.6", pxv("invite.web.dimension.coverToNext"), `${round(field.box.y - cover.box.bottom)}px`);

    section("'Invited by' row (P3 'Hosted by' row)");
    check("invite.web.fontSize.body", "16 px: P3 'Hosted by'", pxv("invite.web.fontSize.body"), field.s["font-size"]!);
    check("invite.web.fontWeight.body", "400: P3 'Hosted by'", "400", field.s["font-weight"]!);
    check("invite.web.opacity.text.body", "rgba(0, 0, 0, 0.8): P3 'Hosted by'", rgba("0, 0, 0", num("invite.web.opacity.text.body")), field.s.color!);
    check("invite.web.dimension.fieldRow.paddingV", "4 px: P1 row padding 4px 0", pxv("invite.web.dimension.fieldRow.paddingV"), field.s["padding-top"]!);

    section("Member List (P3 'Guest List')");
    check("invite.web.dimension.sectionGap", "24 px: P3 '…' button → 'Hosted by' row", pxv("invite.web.dimension.sectionGap"), `${round(members.box.y - field.box.bottom)}px`);
    check("invite.web.fontSize.sectionHeader", "18 px: P3 H3 'Guest List'", pxv("invite.web.fontSize.sectionHeader"), header.s["font-size"]!);
    check("invite.web.fontWeight.sectionHeader", "700: P3 H3", "700", header.s["font-weight"]!);
    check("invite.web.lineHeight.default (header)", "25.2 px: P3 H3", "25.2px", header.s["line-height"]!);
    check("invite.web.dimension.button.medium.height", "36 px: P3 'View all' 81.6 × 36", pxv("invite.web.dimension.button.medium.height"), `${viewAll.box.h}px`);
    check("invite.web.dimension.button.medium.paddingH", "16 px incl. 1-px border: P3 padding 0 15px", `${num("invite.web.dimension.button.medium.paddingH") - num("invite.web.dimension.button.outlined.border")}px`, viewAll.s["padding-left"]!);
    check("invite.web.radius.button.medium", "800 px: P3", pxv("invite.web.radius.button.medium"), viewAll.s["border-radius"]!);
    check("invite.web.fontSize.button.medium", "14 px: P3 'View all'", pxv("invite.web.fontSize.button.medium"), viewAll.s["font-size"]!);
    check("invite.web.fontWeight.button", "600: P3 'View all'", "600", viewAll.s["font-weight"]!);
    check("invite.web.opacity.button.outlined.fill", "rgba(0, 0, 0, 0.05): P3", rgba("0, 0, 0", num("invite.web.opacity.button.outlined.fill")), viewAll.s["background-color"]!);
    check("invite.web.opacity.button.outlined.border.light + dimension.button.outlined.border", "1px solid rgba(0, 0, 0, 0.25): P3", `1px solid ${rgba("0, 0, 0", num("invite.web.opacity.button.outlined.border.light"))}`, viewAll.s["border-top"]!);
    check("invite.web.blur.button.outlined", "blur(40px): P3 'View all'", `blur(${pxv("invite.web.blur.button.outlined")})`, viewAll.s["backdrop-filter"]!);
    check("'View all' right edge", "374 px: P3 292.4 + 81.6", "374px", `${viewAll.box.right}px`);
    check("'View all' centred on the header row", "P3: button centred on the header block", `${round(head.box.y + (head.box.h - viewAll.box.h) / 2)}px`, `${viewAll.box.y}px`);
    check("invite.web.dimension.headerToAvatars", "8 px: P3 count line → avatars (count line itself not copied)", pxv("invite.web.dimension.headerToAvatars"), `${round(av1.box.y - head.box.bottom)}px`);
    check("invite.web.dimension.avatar", "48 × 48: P3 IMG", `${num("invite.web.dimension.avatar")}px × ${num("invite.web.dimension.avatar")}px`, `${av1.box.w}px × ${av1.box.h}px`);
    check("invite.web.radius.avatar", "800 px: P3 IMG", pxv("invite.web.radius.avatar"), av1.s["border-radius"]!);
    check("invite.web.dimension.avatarGap", "4 px: P3 avatars x 16, 68, 120", "120px", `${av3.box.x}px`);
    check("invite.web.opacity.avatar.minimal.fill.light", "rgba(0, 0, 0, 0.1): P3 disc", rgba("0, 0, 0", num("invite.web.opacity.avatar.minimal.fill.light")), initials.s["background-color"]!);
    check("invite.web.opacity.avatar.minimal.text", "rgba(0, 0, 0, 0.8) 16/400: P3 'XX'", `${rgba("0, 0, 0", num("invite.web.opacity.avatar.minimal.text"))} 16px 400`, `${initials.s.color} ${initials.s["font-size"]} ${initials.s["font-weight"]}`);

    section("Members-only card (P3 'Restricted Access')");
    check("invite.web.color.gateCard.light + opacity.gateCard.light", "rgba(255, 255, 255, 0.7): P3", rgba("255, 255, 255", num("invite.web.opacity.gateCard.light")), gate.s["background-color"]!);
    check("invite.web.radius.gateCard", "4 px: P3", pxv("invite.web.radius.gateCard"), gate.s["border-radius"]!);
    check("invite.web.dimension.gateCard.padding", "24 px: P3", pxv("invite.web.dimension.gateCard.padding"), gate.s["padding-top"]!);
    check("card frame", "x 16, w 358: P3", "16px 358px", `${gate.box.x}px ${gate.box.w}px`);
    check("invite.web.dimension.sectionGap (members → card)", "24 px", pxv("invite.web.dimension.sectionGap"), `${round(gate.box.y - members.box.bottom)}px`);
    check("invite.web.dimension.gateCard.glyph + icon.lock", "64 × 64 at card top + 24: P3 svg 1364.1 (card 1340.1)", "64px × 64px at +24px", `${lock.box.w}px × ${lock.box.h}px at +${round(lock.box.y - gate.box.y)}px`);
    check("invite.web.dimension.gateCard.glyphToTitle", "8 px: P3 1428.1 → 1436.1", pxv("invite.web.dimension.gateCard.glyphToTitle"), `${round(gateTitle.box.y - lock.box.bottom)}px`);
    check("invite.web.fontSize.sectionHeader (card title)", "18/700: P3 'Restricted Access'", "18px 700", `${gateTitle.s["font-size"]} ${gateTitle.s["font-weight"]}`);
    check("invite.web.dimension.gateCard.titleToBody", "4 px: P3 1461.3 → 1465.3", pxv("invite.web.dimension.gateCard.titleToBody"), `${round(gateBody.box.y - gateTitle.box.bottom)}px`);
    check("invite.web.fontSize.detail + opacity.text.body", "14 px, rgba(0, 0, 0, 0.8), lh 19.6, centred: P3", `14px ${rgba("0, 0, 0", 0.8)} 19.6px center`, `${gateBody.s["font-size"]} ${gateBody.s.color} ${gateBody.s["line-height"]} ${gateBody.s["text-align"]}`);
    check("invite.web.dimension.gateCard.bodyToButton", "16 px: P3 1504.5 → 1520.5", pxv("invite.web.dimension.gateCard.bodyToButton"), `${round(gateBtn.box.y - gateBody.box.bottom)}px`);
    check("invite.web.dimension.button.large.height", "48 px: P3 'Sign in' 310 × 48", `${pxv("invite.web.dimension.button.large.height")} × 310px`, `${gateBtn.box.h}px × ${gateBtn.box.w}px`);
    check("invite.web.radius.button.large", "4 px: P3", pxv("invite.web.radius.button.large"), gateBtn.s["border-radius"]!);
    check("invite.web.dimension.button.large.paddingH", "24 px: P3", pxv("invite.web.dimension.button.large.paddingH"), gateBtn.s["padding-left"]!);
    check("invite.web.color.button.filled.fill.light / .label.light", "rgb(0, 0, 0) / rgb(255, 255, 255): P3 'Sign in'", "rgb(0, 0, 0) rgb(255, 255, 255)", `${gateBtn.s["background-color"]} ${gateBtn.s.color}`);
    check("large button label", "16/600: P3 'Sign in'", "16px 600", `${gateBtn.s["font-size"]} ${gateBtn.s["font-weight"]}`);
    check("invite.web.duration.button.colour / .opacity + easing.button", "200 ms / 100 ms ease-out: CSS .ptf-PM45p", "background-color 0.2s ease-out, color 0.2s ease-out, opacity 0.1s ease-out", gateBtn.s.transition!);
    check("invite.web.opacity.button.hover", "0.6: CSS --button-hover-opacity (rule read from the stylesheet)", String(num("invite.web.opacity.button.hover")), await ruleValue(page, ".btn:hover", "opacity"));
    check("invite.web.opacity.button.active", "0.4: CSS --button-active-opacity", String(num("invite.web.opacity.button.active")), await ruleValue(page, ".btn:active", "opacity"));
    check("invite.web.opacity.button.outlined.hover.fill", "rgba(0,0,0,.1): CSS --button-outlined-hover-background-color", rgba("0, 0, 0", num("invite.web.opacity.button.outlined.hover.fill")), await ruleValue(page, ".btn-outlined:hover", "background-color"));
    check("invite.web.opacity.button.outlined.active.fill / .border", "rgba(0,0,0,.25) / rgba(0,0,0,.4): CSS --button-outlined-active-*", `${rgba("0, 0, 0", num("invite.web.opacity.button.outlined.active.fill"))} ${rgba("0, 0, 0", num("invite.web.opacity.button.outlined.active.border"))}`, `${await ruleValue(page, ".btn-outlined:active", "background-color")} ${await ruleValue(page, ".btn-outlined:active", "border-top-color")}`);

    section("Footer (P3 / not-found footer)");
    check("invite.web.dimension.footer.paddingTop", "24 px: not-found FOOTER padding-top; P3 footer starts at the last content", pxv("invite.web.dimension.footer.paddingTop"), `${round(divider.box.y - gate.box.bottom)}px`);
    check("invite.web.opacity.footer.divider", "1px solid rgba(0, 0, 0, 0.1): CSS --divider-border-color", `1px solid ${rgba("0, 0, 0", num("invite.web.opacity.footer.divider"))}`, divider.s["border-bottom"]!);
    check("invite.web.dimension.footer.contentPaddingV", "40 px: not-found divider 506.3 → logo 546.3", pxv("invite.web.dimension.footer.contentPaddingV"), `${round(link.box.y - divider.box.bottom)}px`);
    check("footer link", "16/600, rgb text colour, no underline: not-found 'Get the app'", "16px 600 none", `${link.s["font-size"]} ${link.s["font-weight"]} ${link.s["text-decoration-line"]}`);
    check("invite.web.dimension.footer.arrow + icon.getApp", "16 × 16: not-found svg", "16px × 16px", `${arrow.box.w}px × ${arrow.box.h}px`);
    check("invite.web.opacity.footer.arrow", "rgba(…, 0.8): not-found svg", rgba("0, 0, 0", num("invite.web.opacity.footer.arrow")), arrow.s.color!);
    check("invite.web.dimension.footer.linkGap", "2 px: not-found .AppFooter_getAppLink gap", pxv("invite.web.dimension.footer.linkGap"), `${round(arrow.box.x - linkText.box.right)}px`);
    check("invite.web.layout.link", "text-decoration none: not-found links", "none", link.s["text-decoration-line"]!);

    section("Focus");
    await page.keyboard.press("Tab");
    const focusedTag = await page.evaluate(() => document.activeElement?.tagName ?? "");
    const focused = await m(":focus-visible");
    check("invite.web.dimension.focus.offset + border width + text colour", "1px solid primary colour, offset 2px: CSS .BottomNav_focusedProfileImageContainer", `${focusedTag} rgb(0, 0, 0) solid 1px / 2px`, `${focusedTag} ${focused.s.outline} / ${focused.s["outline-offset"]}`);

    // Row 2 of the side-by-side: 'Invited by' at the y of P3's 'Hosted by' in pf-web-private-past-02.png (≈153 px).
    await page.evaluate((y) => {
      (document.activeElement as HTMLElement | null)?.blur();
      window.scrollTo(0, y);
    }, Math.max(0, field.box.y - 153));
    await page.waitForTimeout(200);
    const shotMembers = await page.screenshot();
    await page.goto(`${base}/i/${light.group.token}`, { waitUntil: "networkidle" });
    await page.click(".all > summary");
    const row1 = await m(".rows .row:nth-child(1)");
    const row2 = await m(".rows .row:nth-child(2)");
    const rowName = await m(".rows .row:nth-child(1) .row-name");
    const rowAvatar = await m(".rows .row:nth-child(1) .avatar");
    section("'View all' list (Partiful user-row tokens)");
    check("invite.web.dimension.userRow.paddingV", "12 px: CSS --user-row-padding-vertical", "12px", row1.s["padding-top"]!);
    check("invite.web.dimension.userRow.listGap", "4 px: CSS --user-list-gap", "4px", `${round(row2.box.y - row1.box.bottom)}px`);
    check("invite.web.dimension.userRow.columnGap", "12 px: CSS --user-row-column-gap", "12px", `${round(rowName.box.x - rowAvatar.box.right)}px`);
    check("invite.web.fontWeight.userRow.name", "16/600: P3 activity names", "16px 600", `${rowName.s["font-size"]} ${rowName.s["font-weight"]}`);

    // ---------- dark page ----------
    await page.goto(`${base}/i/${dark.group.token}`, { waitUntil: "networkidle" });
    const dTitle = await m(".title");
    const dGate = await m(".gate");
    const dBtn = await m(".gate .btn-filled");
    const dView = await m(".all > summary");
    const dInit = await m(".avatars li:nth-child(2) .initials");
    section("Dark theme (cover with a dark mean colour)");
    check("invite.web.color.text.dark", "rgb(255, 255, 255): P2 title", "rgb(255, 255, 255)", dTitle.s.color!);
    check("invite.web.color.gateCard.dark + opacity.gateCard.dark", "rgba(0, 0, 0, 0.8): P2 card", rgba("0, 0, 0", num("invite.web.opacity.gateCard.dark")), dGate.s["background-color"]!);
    check("invite.web.color.button.filled.fill.dark / .label.dark", "rgb(255, 255, 255) / rgb(0, 0, 0): P2 'RSVP' in the card", "rgb(255, 255, 255) rgb(0, 0, 0)", `${dBtn.s["background-color"]} ${dBtn.s.color}`);
    check("invite.web.opacity.button.outlined.border.dark", "rgba(255, 255, 255, 0.4): CSS .ptf-dark / not-found pill", `1px solid ${rgba("255, 255, 255", num("invite.web.opacity.button.outlined.border.dark"))}`, dView.s["border-top"]!);
    check("invite.web.opacity.avatar.minimal.fill.dark", "hsla(0,0%,100%,.25): CSS .ptf-dark", rgba("255, 255, 255", num("invite.web.opacity.avatar.minimal.fill.dark")), dInit.s["background-color"]!);
    const darkCoverMean = (await sharp(Buffer.from(await (await fetch(`${base}/i/${dark.group.token}/cover.jpg`)).arrayBuffer())).stats()).channels.slice(0, 3).map((c) => c.mean) as Rgb;
    const darkTheme = themeFromColour(darkCoverMean);

    // ---------- states ----------
    await page.goto(`${base}/i/${"N".repeat(24)}`, { waitUntil: "networkidle" });
    const shotNotFound = await page.screenshot();
    const sHtml = await m("html");
    const sSpace = await m(".header-space");
    const sState = await m(".state");
    const sGlyph = await m(".glyph");
    const sTitle = await m(".state-title");
    const sFooter = await m("footer");
    section("Not-found state (pf-web-notfound-01.png)");
    check("invite.web.color.theme.default", "rgb(17, 17, 17): not-found body", "rgb(17, 17, 17)", sHtml.s["background-color"]!);
    check("invite.web.dimension.state.headerSpace", "60 px: not-found header NAV height", pxv("invite.web.dimension.state.headerSpace"), `${sSpace.box.h}px`);
    check("invite.web.fontSize.state.glyph + lineHeight.default", "50 px, line-height 70 px: not-found visual", "50px 70px", `${sGlyph.s["font-size"]} ${sGlyph.s["line-height"]}`);
    check("invite.web.dimension.state.glyphToTitle", "20 px: not-found visual margin-bottom", pxv("invite.web.dimension.state.glyphToTitle"), sGlyph.s["margin-bottom"]!);
    check("invite.web.fontSize.state.title + fontWeight.state.title", "24/700, line-height 33.6: not-found H2", "24px 700 33.6px", `${sTitle.s["font-size"]} ${sTitle.s["font-weight"]} ${sTitle.s["line-height"]}`);
    check("invite.web.layout.state.title", "uppercase, centred: not-found H2", "uppercase center", `${sTitle.s["text-transform"]} ${sTitle.s["text-align"]}`);
    check("invite.web.layout.state", "equal auto margins: not-found 99.25 × 3", `${round(sState.box.y - sSpace.box.bottom)}px`, `${round((sFooter.box.y - sState.box.bottom) / 2)}px`);
    check("invite.web.color.text.dark (state)", "rgb(255, 255, 255): not-found H2", "rgb(255, 255, 255)", sTitle.s.color!);

    await page.goto(`${base}/i/${expiredToken}`, { waitUntil: "networkidle" });
    const uBody = await m(".state-body");
    const uTitle = await m(".state-title");
    section("Link-no-longer-works state (expired invite, HTTP 410)");
    check("invite.web.dimension.gateCard.titleToBody (state)", "4 px: CSS --non-ideal-state-description-margin-top", "4px", `${round(uBody.box.y - uTitle.box.bottom)}px`);
    check("invite.web.fontSize.detail + opacity.text.body (state)", "14 px, white 0.8", `14px ${rgba("255, 255, 255", 0.8)}`, `${uBody.s["font-size"]} ${uBody.s.color}`);

    await page.goto(`${broken.base}/i/${light.group.token}`, { waitUntil: "networkidle" });
    const eBody = await m(".state-body");
    const eBtn = await m(".state .btn-filled");
    section("Error state (Supabase unreachable, HTTP 503)");
    check("invite.web.dimension.state.bodyToAction", "24 px: CSS --non-ideal-state-button-margin-top", pxv("invite.web.dimension.state.bodyToAction"), `${round(eBtn.box.y - eBody.box.bottom)}px`);
    check("filled button on the default (dark) theme", "white fill, black label (CSS .ptf-dark)", "rgb(255, 255, 255) rgb(0, 0, 0)", `${eBtn.s["background-color"]} ${eBtn.s.color}`);

    // ---------- link preview ----------
    const ogBuf = Buffer.from(await (await fetch(`${base}/i/${light.group.token}/og.jpg`)).arrayBuffer());
    const og = await sharp(ogBuf).metadata();
    const ogHtml = await (await fetch(`${base}/i/${light.group.token}`, { headers: { "user-agent": IPHONE } })).text();
    section("Link preview");
    check("invite.web.layout.ogImage", "1200 × 630 JPEG: pf-og-public-crawler-1200x630.jpg", "jpeg 1200 × 630", `${og.format} ${og.width} × ${og.height}`);
    check("invite.web.layout.linkPreview", "twitter:card summary_large_image; robots noindex, nofollow (P1/P3 HTML)", "summary_large_image noindex, nofollow", `${/twitter:card" content="([^"]+)/.exec(ogHtml)?.[1]} ${/robots" content="([^"]+)/.exec(ogHtml)?.[1]}`);
    // The fill is computed at 1/8 scale; compare it with a full-size Gaussian blur of sigma 360 (slow).
    const ogRaw = await sharp(ogBuf).removeAlpha().raw().toBuffer();
    const coverBuf = Buffer.from(await (await fetch(`${base}/i/${light.group.token}/cover.jpg`)).arrayBuffer());
    const fullBlur = await sharp(await sharp(coverBuf).resize(1200, 630, { fit: "cover" }).toBuffer()).blur(num("invite.web.blur.ogImage.fill")).removeAlpha().raw().toBuffer();
    let se = 0;
    let n = 0;
    for (let y = 0; y < 630; y++) for (const [x0, x1] of [[0, 180], [1020, 1200]] as const) for (let x = x0; x < x1; x++) for (let c = 0; c < 3; c++) {
      const i = (y * 1200 + x) * 3 + c;
      se += (ogRaw[i]! - fullBlur[i]!) ** 2;
      n++;
    }
    const rmse = Math.sqrt(se / n);
    check("invite.web.blur.ogImage.fill", `sigma 360 px at 1200 × 630 (least-squares fit, pf-og-blur-fit.csv); measured fill RMSE ${rmse.toFixed(2)}/255`, "fill RMSE vs full-size sigma-360 blur ≤ 2/255", `fill RMSE vs full-size sigma-360 blur ${rmse <= 2 ? "≤ 2/255" : "> 2/255"}`);

    // ---------- side-by-side ----------
    const tileW = 585;
    const tileH = 1266;
    const gap = 24;
    const tile = (buf: Buffer) => sharp(buf).resize(tileW, tileH, { fit: "fill" }).png().toBuffer();
    const pairs: [Buffer, string][] = [
      [shotTop, "pf-web-private-past-01.png"],
      [shotMembers, "pf-web-private-past-02.png"],
      [shotNotFound, "pf-web-notfound-01.png"],
    ];
    const composites: OverlayOptions[] = [];
    for (const [i, [ours, ref]] of pairs.entries()) {
      const top = i * (tileH + gap);
      composites.push({ input: await tile(ours), left: 0, top }, { input: await tile(fs.readFileSync(REF(ref))), left: tileW + gap, top });
    }
    fs.mkdirSync(path.dirname(OUT_PNG), { recursive: true });
    await sharp({ create: { width: tileW * 2 + gap, height: pairs.length * tileH + (pairs.length - 1) * gap, channels: 3, background: { r: 255, g: 255, b: 255 } } })
      .composite(composites)
      .png()
      .toFile(OUT_PNG);

    // ---------- contrast ----------
    const observed = ["#FBEBE4", "#A7C8FF", "#1C0606", "#2F2F2F", "#010019", "#FBE4F2", "#F7FBE4", "#C5DB76", "#D4D6F1", "#DE70D6"];
    const contrastSets: { label: string; pairs: PairResult[] }[] = [
      { label: `seeded light cover (theme ${theme.background}, title ${tSize} px)`, pairs: invitePairs(theme, tSize) },
      { label: `seeded dark cover (theme ${darkTheme.background})`, pairs: invitePairs(darkTheme, titleSize(dark.name, 358)) },
      { label: "no cover / default theme #111111", pairs: invitePairs(defaultTheme(), tSize) },
      { label: "state pages (default theme)", pairs: statePairs() },
    ];
    const sweep = observed.map((hex) => {
      const t = themeFromColour(hex.match(/[0-9A-F]{2}/g)!.map((h) => parseInt(h, 16)) as Rgb);
      return { hex, scheme: t.scheme, failing: invitePairs(t, tSize).filter((p) => !p.pass) };
    });
    // Worst case over every theme colour on the grey axis (the alpha text pairs are weakest there).
    let worst = { grey: 0, pairs: [] as PairResult[] };
    for (let v = 0; v <= 255; v++) {
      const fails = invitePairs(themeFromColour([v, v, v]), tSize).filter((p) => !p.pass);
      if (fails.length > worst.pairs.length) worst = { grey: v, pairs: fails };
    }
    const failingGreys = [...Array(256).keys()].filter((v) => invitePairs(themeFromColour([v, v, v]), tSize).some((p) => !p.pass));
    const failingTextGreys = [...Array(256).keys()].filter((v) => invitePairs(themeFromColour([v, v, v]), tSize).some((p) => !p.pass && p.kind !== "nontext"));

    writeMarkdown({ light, theme, tSize, contrastSets, sweep, worst, failingGreys, failingTextGreys });
    const failed = rows.flatMap((s) => s.rows).filter((r) => !r.ok);
    console.log(`verify: ${rows.flatMap((s) => s.rows).length} checks, ${failed.length} mismatches → ${path.relative(ROOT, OUT_MD)}, ${path.relative(ROOT, OUT_PNG)}`);
    for (const f of failed) console.log(`  ✗ ${f.token}: expected ${f.expected}, got ${f.actual}`);
    process.exitCode = failed.length ? 1 : 0;
  } finally {
    await browser.close();
    server.close();
    broken.server.close();
    for (const s of seeds) await cleanup(s.group);
    for (const u of extraUsers) await deleteUser(u);
    void removeObjects;
  }
}

function writeMarkdown(d: {
  light: Seed;
  theme: { background: string; scheme: string };
  tSize: number;
  contrastSets: { label: string; pairs: PairResult[] }[];
  sweep: { hex: string; scheme: string; failing: PairResult[] }[];
  worst: { grey: number; pairs: PairResult[] };
  failingGreys: number[];
  failingTextGreys: number[];
}) {
  const all = rows.flatMap((s) => s.rows);
  const cell = (s: string) => s.replace(/\|/g, "\\|");
  let md = `# Verification — \`invite.web\`

Generated by \`web/scripts/verify.ts\` (\`cd web && npm run verify\`) on ${new Date().toISOString().slice(0, 10)}.
Our page: the real service against the local Supabase stack, rendered by Playwright Chromium (\`/opt/pw-browsers\`)
at 390×844 CSS px @3x with an iPhone user agent — the capture setup of the research pass. Computed values are
\`getComputedStyle\` / \`getBoundingClientRect\` read back from the page; reference values are the research's
computed-style dumps and production CSS (\`references/auto/partiful/\`).

**Result: ${all.filter((r) => r.ok).length} of ${all.length} checks match.**

Side by side: [\`invite.web.png\`](invite.web.png) — ours left, Partiful right, each frame 1170×2532 px scaled to the same height:
1. top of the page | \`references/auto/partiful/web/pf-web-private-past-01.png\` (link-only event, logged out — the closest analogue)
2. scrolled so 'Invited by' sits where P3's 'Hosted by' sits | \`pf-web-private-past-02.png\`
3. not-found state | \`pf-web-notfound-01.png\`

Test data (synthetic images, no reference content): group "${d.light.name}", ${d.light.group.users.length} members (5 with photos),
cover = radial gradient, theme ${d.theme.background} (${d.theme.scheme}), title ${d.tSize} px by the auto-fit rule.
Differences that are by design (do-not-copy or no counterpart): no acquisition banner, logo, Login pill, date/time,
timezone pills, location, description, guest counts, '+N' disc, Activity list, theme video, bottom navigation (see
\`design/surfaces/invite.web.md\` → Do-not-copy). Font: Partiful's TWK Lausanne / PartifulGrotesk are proprietary; the
platform UI font is used, so glyph shapes and line breaks differ.

`;
  for (const s of rows) {
    md += `## ${s.section}\n\n| ✓ | token | reference value (evidence) | expected (from token) | computed on our page |\n|---|---|---|---|---|\n`;
    for (const r of s.rows) md += `| ${r.ok ? "✓" : "✗"} | \`${cell(r.token)}\` | ${cell(r.reference)} | \`${cell(r.expected)}\` | \`${cell(r.actual)}\` |\n`;
    md += "\n";
  }
  md += `Not rendered on the web (App Clip and App Store Connect values, verified in the iOS build): \`invite.appclip.*\` tokens.

## WCAG 2.2 contrast (sourced values, not adjusted)

Thresholds: \`layout.global.contrast.text\` 4.5:1, \`.largeText\` 3:1, \`.nonText\` 3:1. "Large" uses WCAG's web
definition (≥ 24 px, or ≥ 18.66 px bold). Translucent colours are composited (source-over) on what is beneath them.

`;
  for (const set of d.contrastSets) {
    md += `### ${set.label}\n\n| element | kind | foreground | background | ratio | needs | result |\n|---|---|---|---|---|---|---|\n`;
    for (const p of set.pairs) md += `| ${p.element} | ${p.kind} | ${p.fg} | ${p.bg} | ${p.ratio.toFixed(2)}:1 | ${p.need}:1 | ${p.pass ? "pass" : "**FAIL**"} |\n`;
    md += "\n";
  }
  md += `### Partiful's observed theme colours as our theme colour (research §5.2)\n\n| theme | text | failing pairs |\n|---|---|---|\n`;
  for (const s of d.sweep) md += `| ${s.hex} | ${s.scheme === "light" ? "black" : "white"} | ${s.failing.length ? s.failing.map((p) => `${p.element} ${p.ratio.toFixed(2)}:1`).join("; ") : "none"} |\n`;
  const hexGrey = (v: number) => `#${v.toString(16).padStart(2, "0").repeat(3).toUpperCase()}`;
  const toRanges = (vals: number[]) => {
    const out: string[] = [];
    let start = -1;
    for (let v = 0; v <= 256; v++) {
      const inSet = vals.includes(v);
      if (inSet && start < 0) start = v;
      if (!inSet && start >= 0) {
        out.push(start === v - 1 ? hexGrey(start) : `${hexGrey(start)}–${hexGrey(v - 1)}`);
        start = -1;
      }
    }
    return out.join(", ") || "none";
  };
  const ranges = [toRanges(d.failingGreys)];
  md += `\n### Worst case\n\nOn the grey axis, themes ${ranges[0]} fail at least one pair (mostly the outlined 'View all' border, a non-text
pair); themes ${toRanges(d.failingTextGreys)} fail a **text** pair. The worst is ${hexGrey(d.worst.grey)}: ${d.worst.pairs.map((p) => `${p.element} ${p.ratio.toFixed(2)}:1 (needs ${p.need}:1)`).join("; ") || "none"}.
These come from Partiful's fixed alphas (body 0.8, outlined border 0.25/0.4, avatar disc 0.1/0.25) on mid-tone theme
colours; a cover whose mean colour is mid-tone produces them. They are reported, not corrected (CONVENTIONS: no
adjusted values); the owner capture / decision is listed in \`design/surfaces/invite.web.md\` → Gaps.
`;
  fs.writeFileSync(OUT_MD, md);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
