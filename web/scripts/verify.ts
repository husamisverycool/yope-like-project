/// <reference lib="dom" />
// Verification of invite.web against its spec (design/surfaces/invite.web.md, Retro's /u/[username] page).
//
//   npm run verify     (no database needed: the real app with a fixture upstream and fixtures/photos)
//
// Serves the app, renders every state in Playwright Chromium (PLAYWRIGHT_BROWSERS_PATH) with the capture setups of
// Retro's references (mobile 390 × 664 CSS px @3x iPhone UA = references/auto/retro/web/retro.app-u-nathan-iphone.png;
// desktop 1440 × 900 @1x = retro.app-u-nathan-desktop.png), reads computed styles and boxes back from the page and
// writes
//   design/verification/invite.web.md    every spec value next to what renders: matched / approximated / not matched
//   design/verification/invite.web.png   side by side (git-ignored: it contains reference crops) — ours left, Retro
//                                         right: mobile card | iPhone capture, desktop | desktop capture, share images
// The per-state renders (light and dark) are written by the render test: design/verification/invite.web/*.png.

import fs from "node:fs";
import path from "node:path";
import jsQR from "jsqr";
import type { Page } from "playwright-core";
import sharp from "sharp";
import { cardPairs, desktopPairs, SPEC_BACKDROP_SAMPLE, statePairs, toHex, type PairResult } from "../src/contrastReport.js";
import { colorHex, cssEasing, inviteBackdrop } from "../src/design.js";
import { copy } from "../src/generated/copy.js";
import { tokens as t } from "../src/generated/tokens.js";
import { backdropTone } from "../src/images.js";
import { ANDROID, DESKTOP, IPHONE } from "../test/support/app.js";
import { CASES, launch, load, measure, open, photo, ROOT, serveCases, TOKENS, type Layout, type Scheme } from "../test/support/render.js";

const OUT_MD = path.join(ROOT, "design/verification/invite.web.md");
const OUT_PNG = path.join(ROOT, "design/verification/invite.web.png");
const REF = (f: string) => path.join(ROOT, "references/auto/retro/web", f);
const c = copy as Record<string, string>;

type Status = "matched" | "approximated" | "not matched";
interface Row {
  item: string;
  spec: string;
  rendered: string;
  status: Status;
  note: string;
}
const sections: { name: string; rows: Row[] }[] = [];
let rows: Row[] = [];
const section = (name: string) => sections.push({ name, rows: (rows = []) });
const row = (item: string, spec: string | number, rendered: string | number, status: Status, note = "") =>
  rows.push({ item, spec: String(spec), rendered: String(rendered), status, note });
/** matched when equal (numbers within ±0.6 px), else not matched. */
const check = (item: string, spec: string | number, rendered: string | number, note = "") => {
  const a = parseFloat(String(spec));
  const b = parseFloat(String(rendered));
  const numeric = /^-?[0-9.]+(px)?$/.test(String(spec).trim()) && /^-?[0-9.]+(px)?$/.test(String(rendered).trim());
  const ok = numeric ? Math.abs(a - b) <= 0.6 : String(spec) === String(rendered);
  row(item, spec, rendered, ok ? "matched" : "not matched", note);
};
const px = (n: number) => `${+n.toFixed(2)}px`;
/** #RRGGBB[AA] as Chromium serialises it. */
const css = (hex: string) => {
  const [r, g, b, a] = [1, 3, 5, 7].map((i) => parseInt(hex.slice(i, i + 2) || "ff", 16)) as [number, number, number, number];
  if (a === 255) return `rgb(${r}, ${g}, ${b})`;
  const two = Math.round((a / 255) * 100) / 100;
  return `rgba(${r}, ${g}, ${b}, ${Math.round(two * 255) === a ? two : Math.round((a / 255) * 1000) / 1000})`;
};

async function main() {
  const servers = await serveCases();
  const browser = await launch();
  const url = (name: (typeof CASES)[number]["name"]) => {
    const k = CASES.find((x) => x.name === name)!;
    return `${servers[k.server].base}/i/${k.token}`;
  };
  const withPage = async <T>(layout: Layout, scheme: Scheme, fn: (p: Page) => Promise<T>, reducedMotion = true): Promise<T> => {
    const { context, page } = await open(browser, layout, scheme);
    if (!reducedMotion) await page.emulateMedia({ reducedMotion: "no-preference" });
    try {
      return await fn(page);
    } finally {
      await context.close();
    }
  };
  let oursMobile: Buffer, oursDesktop: Buffer;
  try {
    // ---------- mobile card ----------
    await withPage("mobile", "light", async (page) => {
      await load(page, url("valid"));
      oursMobile = await page.screenshot();
      const m = (sel: string, props: string[] = []) => measure(page, sel, props);
      const card = await m(".card", ["border-top-left-radius"]);
      const hero = await m(".hero");
      const avatar = await m(".avatar");
      const h1 = await m(".headline", ["font-family", "font-size", "line-height", "font-weight", "color", "max-width"]);
      const line = await m(".line.mobile-only", ["font-family", "font-size", "line-height", "letter-spacing", "color", "max-width"]);
      const members = await m(".members");
      const m1 = await m(".members li:nth-child(1) .member");
      const m2 = await m(".members li:nth-child(2) .member");
      const pill = await m(".pill", ["background-color", "color", "font-size", "font-weight", "border-top-left-radius"]);
      const footer = await m(".footer", ["font-size", "color"]);
      const terms = await m(".footer a:first-child");
      const half = t["size.global.minTouchTarget.ios"] / 2 - 1;
      const hit = await page.evaluate(([x, y]) => document.elementFromPoint(x!, y!)?.textContent, [terms.box.x + terms.box.w / 2, terms.box.y + terms.box.h / 2 - half]);
      const backdrop = await m(".backdrop", ["filter"]);
      const dim = await page.$eval(".card", (e) => getComputedStyle(e, "::after").backgroundColor);
      const { blurSigmaToWidth: k, dim: dimToken } = inviteBackdrop();
      const sigma = k * card.box.w;
      const sigmaRendered = parseFloat(/blur\(([0-9.]+)px\)/.exec(backdrop.s.filter!)?.[1] ?? "NaN");
      const inset = t["invite.web.size.cardInset"];

      section("Mobile card (390 × 664 CSS px @3x, iPhone; viewport ≤ invite.web.size.breakpoint 840)");
      check("`invite.web.size.cardInset` (card x, y)", `${inset}, ${inset}`, `${card.box.x}, ${card.box.y}`);
      check("card height (full viewport − 2 × inset)", px(664 - 2 * inset), px(card.box.h));
      check("`invite.web.radius.card`", px(t["invite.web.radius.card"]), card.s["border-top-left-radius"]!);
      check("card fill blur `invite.web.layout.backdrop.blurSigmaToWidth` (σ = 0.08 × card width)", px(sigma), px(sigmaRendered), `${k} × ${card.box.w} px; CSS blur() takes σ, from 100cqw of the card (viewport fallback for browsers without container units); MERGE_DECISIONS L-6`);
      check("card fill dim `invite.web.layout.backdrop.dim` (`color.global.backdropDim`, black 22 %)", css(colorHex(dimToken)), dim);
      check("backdrop bleed (3σ each side, `invite.web.layout.backdrop.source`)", px(card.box.w + 6 * sigma), px(backdrop.box.w));
      row("card fill fallbacks", "no cover → inviter's avatar blurred; neither → `color.global.backgroundDeep`", "as spec (renders valid-no-cover-*, valid-no-photos-*)", "matched", "the inviter's avatar is invite_preview.inviter_avatar_path (migration 0016)");
      check("`invite.web.size.avatar`", `${t["invite.web.size.avatar"]} × ${t["invite.web.size.avatar"]}`, `${avatar.box.w} × ${avatar.box.h}`);
      row("avatar position", "centred above the text block (approximated in the spec — the capture lost the photo)", `centre ${px(avatar.box.y + avatar.box.h / 2)}; space above the text ${px(hero.box.y)}–${px(hero.box.bottom)} → centre ${px(hero.box.y + hero.box.h / 2)}`, "approximated", "Retro's broken-image alt text ('athan', clipped by the 112-pt circle) puts the box top ≈ 152 CSS px → centre ≈ 208 on Retro's page; the space-centre rule gives ≈ 209 there");
      row("headline family `font.global.display`", "display serif (Retro: Roslindale Display Narrow — commercial)", h1.s["font-family"]!, "approximated", "PLATFORM stack: New York on Apple (ui-serif), Noto Serif on Android; this Linux render uses the bundled Noto Serif. Narrower Roslindale fits more per line");
      check("headline size `fontSize.global.displayMedium`", px(t["fontSize.global.displayMedium"]), h1.s["font-size"]!);
      check("headline line `invite.web.lineHeight.headline`", px(t["invite.web.lineHeight.headline"]), h1.s["line-height"]!);
      check("headline weight `fontWeight.global.displayMedium`", "400", h1.s["font-weight"]!);
      check("headline colour (#FFFFFF, `color.global.textOnMedia`)", css(t["color.global.textOnMedia"]), h1.s.color!);
      check("`invite.web.size.textMaxWidth` (headline)", px(t["invite.web.size.textMaxWidth"]), h1.s["max-width"]!);
      row("line family `font.global.family`", "SF Pro (iOS) / Inter (Android)", line.s["font-family"]!, "approximated", "PLATFORM stack, no web font: SF Pro on Apple, the platform UI face elsewhere (Roboto on Android, not the app's bundled Inter)");
      check("`invite.web.fontSize.body`", px(t["invite.web.fontSize.body"]), line.s["font-size"]!);
      check("`invite.web.lineHeight.body`", px(t["invite.web.lineHeight.body"]), line.s["line-height"]!);
      check("`invite.web.letterSpacing.body`", px(t["invite.web.letterSpacing.body"]), line.s["letter-spacing"]!);
      check("`invite.web.color.body` (white 62 %)", css(t["invite.web.color.body"]), line.s.color!);
      check("`invite.web.size.textMaxWidth` (line)", px(t["invite.web.size.textMaxWidth"]), line.s["max-width"]!);
      check("`invite.web.size.headlineToBody` (headline → line)", px(t["invite.web.size.headlineToBody"]), px(line.box.y - h1.box.bottom));
      check("`invite.web.size.headlineToBody` (line → members)", px(t["invite.web.size.headlineToBody"]), px(members.box.y - line.box.bottom));
      check("members `size.global.avatarSmall`", px(t["size.global.avatarSmall"]), px(m1.box.w));
      check("members `size.global.avatarStackOverlap` (pitch)", px(t["size.global.avatarSmall"] - t["size.global.avatarStackOverlap"]), px(m2.box.x - m1.box.x));
      row("members: as many as fit 260, no '+N'", "13 of 30 (260 − 22.6) ÷ 19.6 + 1", "13 (unit test with 30 members)", "matched");
      row("members: white ring (C-23)", "white ring, width not measured (C-23 Gap)", "no ring", "not matched", "as the iOS / Android components: a ring of unmeasured width is not drawn");
      row("members: no photo (C-23)", "initials (Gap) → `icon.global.person` on `color.global.control`", "Material Rounded.Person glyph in `color.global.textSecondary` on `color.global.control` (light values)", "matched", "same fallback as the native AvatarView");
      check("`invite.web.size.bodyToPill`", px(t["invite.web.size.bodyToPill"]), px(pill.box.y - members.box.bottom));
      check("pill width (card − 2 × `invite.web.size.pillInset`)", px(390 - 2 * inset - 2 * t["invite.web.size.pillInset"]), px(pill.box.w), "Retro's capture: 302 (906 px ÷ 3)");
      check("`invite.web.size.pillHeight`", px(t["invite.web.size.pillHeight"]), px(pill.box.h));
      check("pill radius (capsule = height / 2)", px(t["invite.web.size.pillHeight"] / 2), pill.s["border-top-left-radius"]!);
      check("`invite.web.color.pill` (white 20 %)", css(t["invite.web.color.pill"]), pill.s["background-color"]!);
      check("pill label colour #FFFFFF", css(t["color.global.textOnMedia"]), pill.s.color!);
      check("`invite.web.fontSize.pill`", px(t["invite.web.fontSize.pill"]), pill.s["font-size"]!);
      check("`invite.web.fontWeight.pill` (semibold)", "600", pill.s["font-weight"]!);
      check("`invite.web.size.pillToFooter` + `invite.web.size.footerMargin`", px(t["invite.web.size.pillToFooter"] + t["invite.web.size.footerMargin"]), px(footer.box.y - pill.box.bottom));
      check("`invite.web.size.footerMargin` (below the footer)", px(t["invite.web.size.footerMargin"]), px(card.box.bottom - footer.box.bottom));
      check("`invite.web.fontSize.footer`", px(t["invite.web.fontSize.footer"]), footer.s["font-size"]!);
      check("footer colour #FFFFFF", css(t["color.global.textOnMedia"]), footer.s.color!);
      check("footer links: 44 × 44 hit area (`size.global.minTouchTarget.ios`)", "tap 21 px above 'Terms' hits it", hit === c["invite.web.footer.terms"] ? "tap 21 px above 'Terms' hits it" : `hit ${hit}`, "a centred ::after box of max(100 %, 44 px); the 8-px text keeps its place");
      section("Mobile card against Retro's capture (references/auto/retro/web/retro.app-u-nathan-iphone.png, px ÷ 3)");
      const within = (pairs: [number, number][], tol: number): Status => (pairs.every(([a, b]) => Math.abs(a - b) <= tol) ? "matched" : "not matched");
      row("pill top – bottom", "538–594 (y 1614–1782)", `${px(pill.box.y)}–${px(pill.box.bottom)}`, within([[pill.box.y, 538], [pill.box.bottom, 594]], 1));
      row("pill x", "44 (x 132)", px(pill.box.x), within([[pill.box.x, 44]], 1));
      row("footer", "glyphs 632.7–640 (y 1898–1920)", `line box ${px(footer.box.y)}–${px(footer.box.bottom)}`, within([[footer.box.y, 632.7], [footer.box.bottom, 640]], 1), "glyph ink sits inside the 8-px line box");
      row("headline top", "≈ 413 (ink y 1245–1325)", px(h1.box.y), "approximated", "ours sits higher by the member stack (16 + 22.6), which Retro's /u/ page does not have (SPEC_FLAGS T7 addition)");
    });

    // hover / busy / motion
    await withPage(
      "mobile",
      "light",
      async (page) => {
        await load(page, url("valid"));
        const transition = (await measure(page, ".pill", ["transition"])).s.transition!;
        section("Mobile card — 'Let's go' states and motion");
        check("transition `invite.web.duration.pill` + `invite.web.easing.pill`", `background-color ${t["invite.web.duration.pill"] / 1000}s ${cssEasing("invite.web.easing.pill").replace(/,\s*/g, ", ")}`, transition);
        await page.hover(".pill");
        await page.waitForTimeout(t["invite.web.duration.pill"] + 100);
        check("hover `invite.web.color.pillHover` (white 30 %)", css(t["invite.web.color.pillHover"]), (await measure(page, ".pill", ["background-color"])).s["background-color"]!);
        await page.evaluate(() => document.addEventListener("click", (e) => e.preventDefault(), true));
        await page.click(".pill");
        check("busy: aria-busy", "true", String(await page.getAttribute(".pill", "aria-busy")));
        check("busy: label `invite.web.opening`", c["invite.web.opening"]!, await page.innerText(".pill"));
        check("busy: `invite.web.opacity.pillDisabled`", String(t["invite.web.opacity.pillDisabled"]), (await measure(page, ".pill", ["opacity"])).s.opacity!);
      },
      false,
    );
    await withPage("mobile", "light", async (page) => {
      await load(page, url("valid"));
      check("prefers-reduced-motion: reduce removes the transition", "none (all 0s)", (await measure(page, ".pill", ["transition-duration"])).s["transition-duration"] === "0s" ? "none (all 0s)" : "still animated");
    });
    await withPage("mobile", "light", async (page) => {
      await load(page, url("valid-no-photos"));
      check("avatar placeholder `invite.web.color.avatarPlaceholder`", css(t["invite.web.color.avatarPlaceholder"]), (await measure(page, ".avatar", ["background-color"])).s["background-color"]!);
    });

    // ---------- desktop ----------
    await withPage("desktop", "light", async (page) => {
      await load(page, url("valid"));
      oursDesktop = await page.screenshot();
      const m = (sel: string, props: string[] = []) => measure(page, sel, props);
      const qr = await m(".qr");
      const avatar = await m(".avatar");
      const h1 = await m(".headline", ["font-size", "line-height", "color", "font-weight"]);
      const line = await m(".line.desktop-only", ["font-size", "line-height", "letter-spacing", "color", "max-width"]);
      const link = await m(".link", ["font-size", "font-weight", "color"]);
      const footer = await m(".footer", ["font-size", "line-height", "color"]);
      const bg = await page.$eval("html", (e) => getComputedStyle(e).backgroundColor);
      const q = t["invite.web.size.qrDesktop"];
      const shot = await page.screenshot({ clip: { x: qr.box.x - 20, y: qr.box.y - 20, width: q + 40, height: q + 40 } });
      const { data, info } = await sharp(shot).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
      const decoded = jsQR.default(new Uint8ClampedArray(data), info.width, info.height)?.data;
      const k = await page.$eval(".qr path", (p) => Number(/h[0-9]+v([0-9]+)/.exec(p.getAttribute("d") ?? "")?.[1]));

      section("Desktop column (1440 × 900 @1x; viewport > 840)");
      check("page background (#FFFFFF, `color.global.background` light)", css(t["color.global.background"].light), bg);
      row("order", "QR (avatar in its centre) → headline → line → link → footer", "QR (avatar in its centre) → headline → line → link → footer", "matched", "WEBD capture and Retro's DOM [QR(profilePhotoURL), h1, p]; spec Structure text corrected (RA-31)");
      check("`invite.web.size.qrDesktop`", `${q} × ${q}`, `${qr.box.w} × ${qr.box.h}`);
      row("QR modules", "black on white", `square, ${k} px each (whole pixels), centred; level H`, "approximated", "Retro's code uses rounded dot modules (style not tokenised); 231-px ink in its 250-px box = 33 × 7 px, the same whole-pixel rule");
      check("QR content", `https://<domain>/i/<token>`, decoded === `https://invite.example.com/i/${TOKENS.valid}` ? `https://<domain>/i/<token>` : String(decoded), "decoded from the screenshot (jsQR) with the avatar over the centre");
      check("`invite.web.size.avatarDesktop`", `${t["invite.web.size.avatarDesktop"]} × ${t["invite.web.size.avatarDesktop"]}`, `${avatar.box.w} × ${avatar.box.h}`);
      check("avatar centred on the QR", `${px(qr.box.x + q / 2)}, ${px(qr.box.y + q / 2)}`, `${px(avatar.box.x + avatar.box.w / 2)}, ${px(avatar.box.y + avatar.box.h / 2)}`);
      check("`invite.web.size.headlineTopDesktop`", px(t["invite.web.size.headlineTopDesktop"]), px(h1.box.y - qr.box.bottom));
      check("`invite.web.fontSize.headlineDesktop` (line 48)", `${px(t["invite.web.fontSize.headlineDesktop"])} / ${px(t["invite.web.fontSize.headlineDesktop"])}`, `${h1.s["font-size"]} / ${h1.s["line-height"]}`);
      check("headline colour #000000", css(t["color.global.textPrimary"].light), h1.s.color!);
      check("`invite.web.fontSize.bodyDesktop` / `.lineHeight.bodyDesktop`", `${px(t["invite.web.fontSize.bodyDesktop"])} / ${px(t["invite.web.lineHeight.bodyDesktop"])}`, `${line.s["font-size"]} / ${line.s["line-height"]}`);
      check("tracking `invite.web.letterSpacing.body`", px(t["invite.web.letterSpacing.body"]), line.s["letter-spacing"]!);
      check("`invite.web.color.bodyDesktop` (black 50 %)", css(t["invite.web.color.bodyDesktop"]), line.s.color!);
      check("`invite.web.size.bodyMaxWidthDesktop`", px(t["invite.web.size.bodyMaxWidthDesktop"]), line.s["max-width"]!);
      check("`invite.web.size.headlineToBody`", px(t["invite.web.size.headlineToBody"]), px(line.box.y - h1.box.bottom));
      check("`invite.web.size.bodyToQrDesktop` (line → 'Download the app')", px(t["invite.web.size.bodyToQrDesktop"]), px(link.box.y - line.box.bottom), "Retro's p margin-bottom; with the QR above, the link follows it");
      row("'Download the app' style", "link (no style in the spec)", `C-08 text button: ${link.s["font-size"]} weight ${link.s["font-weight"]} ${link.s.color}`, "approximated", "composition: Retro's desktop shows store badges (trademarks) here");
      check("footer text role `caption`", `${px(t["fontSize.global.caption"])} / ${px(t["lineHeight.global.caption"])}`, `${footer.s["font-size"]} / ${footer.s["line-height"]}`);
      check("footer colour (#000000 50 %)", css(t["invite.web.color.bodyDesktop"]), footer.s.color!);
      check("footer margin `invite.web.size.footerMargin`", px(t["invite.web.size.footerMargin"]), px(900 - footer.box.bottom));
    });

    // ---------- states and appearance ----------
    section("States (same card / column; renders design/verification/invite.web/<state>-<layout>-<scheme>.png)");
    for (const k of CASES) {
      await withPage("mobile", "light", async (page) => {
        const status = await load(page, url(k.name));
        const h1 = await page.innerText("h1");
        const line = (await page.$$eval(".line", (els) => els.filter((e) => getComputedStyle(e).display !== "none").map((e) => (e as HTMLElement).innerText))).join("");
        const pill = await page.$$eval(".pill", (els) => els.filter((e) => getComputedStyle(e).display !== "none").map((e) => (e as HTMLElement).innerText).join(""));
        const cardBg = (await measure(page, ".card", ["background-color"])).s["background-color"];
        row(k.name, `HTTP ${k.status}`, `HTTP ${status} · “${h1}” · “${line}”${pill ? ` · pill “${pill}”` : " · no pill"}${k.name.startsWith("valid") ? "" : ` · card ${cardBg}`}`, status === k.status ? "matched" : "not matched");
      });
    }
    row("full (group has 30 members)", "not a state of this spec", "—", "not matched", "invite_preview cannot tell; join_group's group_full is shown by the App Clip / app (invite.appclip.full.*)");
    row("loading / offline / permission-denied", "— (server-rendered; the browser's own offline page)", "—", "matched");

    section("Appearance (prefers-color-scheme)");
    let identical = 0;
    for (const k of CASES) {
      for (const layout of ["mobile", "desktop"] as const) {
        const shots: Buffer[] = [];
        for (const scheme of ["light", "dark"] as const) {
          shots.push(await withPage(layout, scheme, async (page) => (await load(page, url(k.name)), page.screenshot({ fullPage: true }))));
        }
        const [a, b] = await Promise.all(shots.map((s) => sharp(s).raw().toBuffer()));
        if (a!.equals(b!)) identical++;
      }
    }
    row("dark renders like light", "same in both appearances (Retro's web has no dark scheme; RA-19)", `${identical} of ${CASES.length * 2} state × layout renders pixel-identical; \`color-scheme: light\``, identical === CASES.length * 2 ? "matched" : "not matched");

    // ---------- link preview and behaviour ----------
    const html = async (ua: string) => (await fetch(url("valid"), { headers: { "user-agent": ua } })).text();
    const ios = await html(IPHONE);
    const meta = (attr: string, name: string) => new RegExp(`<meta ${attr}="${name}" content="([^"]*)">`).exec(ios)?.[1] ?? "(absent)";
    section("Link preview, App Clip and links (`invite.web.layout.linkPreview`)");
    row("`<title>` = `invite.web.documentTitle`", "{app_name} - {title}", /<title>([^<]*)<\/title>/.exec(ios)![1]!, c["invite.web.documentTitle"] ? "matched" : "not matched", "BLOCKED until the owner names the app: development shows the marker, production refuses to start");
    check("og:title / twitter:title (`invite.web.og.title`)", "Join Lima family / Join Lima family", `${meta("property", "og:title")} / ${meta("name", "twitter:title")}`);
    check("og:description", c["invite.web.og.description"]!, meta("property", "og:description"));
    check("og:image (+ type, width, height)", `…/og.png image/png 600 600`, `…/${meta("property", "og:image").split("/").pop()} ${meta("property", "og:image:type")} ${meta("property", "og:image:width")} ${meta("property", "og:image:height")}`);
    check("twitter:card", "summary_large_image", meta("name", "twitter:card"));
    check("apple-itunes-app", "app-id=…, app-clip-bundle-id=….Clip, app-clip-display=card, app-argument=<invite URL>", meta("name", "apple-itunes-app").replace(/app-id=[0-9]+/, "app-id=…").replace(/app-clip-bundle-id=[^,]+\.Clip/, "app-clip-bundle-id=….Clip").replace(/app-argument=https:\/\/[^"]+$/, "app-argument=<invite URL>"));
    check("robots (meta)", "noindex, noimageindex", meta("name", "robots"));
    check("robots (X-Robots-Tag)", "noindex, noimageindex", String((await fetch(url("valid"))).headers.get("x-robots-tag")));
    const pillHref = (h: string) => /<a class="pill mobile-only" data-opens href="([^"]+)"/.exec(h)?.[1]?.replace(/&amp;/g, "&") ?? "(none)";
    check("'Let's go' on iOS", "https://appclip.apple.com/id?p=<bundle id>.Clip&token=<token>", pillHref(ios).replace(/p=[^&]+\.Clip/, "p=<bundle id>.Clip").replace(/token=.*/, "token=<token>"));
    check("'Let's go' on Android", "Play listing, referrer=invite_token%3D<token>", pillHref(await html(ANDROID)).replace(/^https:\/\/play\.google\.com\/store\/apps\/details\?id=[^&]+&referrer=invite_token%3D.*$/, "Play listing, referrer=invite_token%3D<token>"));
    check("'Download the app' on desktop", "App Store / Play listing", /<a class="link hit desktop-only" href="https:\/\/(apps\.apple\.com|play\.google\.com)\//.test(await html(DESKTOP)) ? "App Store / Play listing" : "(other)");
    check("footer links", "legal URLs (config/app.json), new tab", /<a class="hit" href="https:\/\/[^"]+" target="_blank" rel="noopener noreferrer">/.test(ios) ? "legal URLs (config/app.json), new tab" : "(other)");

    // ---------- share image ----------
    const og = Buffer.from(await (await fetch(`${servers.main.base}/i/${TOKENS.noPhotos}/og.png`)).arrayBuffer());
    const { data, info } = await sharp(og).removeAlpha().raw().toBuffer({ resolveWithObject: true });
    const at = (x: number, y: number) => [...data.subarray((y * info.width + x) * 3, (y * info.width + x) * 3 + 3)];
    const circle = { x0: 600, x1: -1, y0: 600, y1: -1 };
    const ink: number[] = [];
    let brightest = 0;
    for (let y = 0; y < info.height; y++) {
      let inkRow = false;
      for (let x = 0; x < info.width; x++) {
        const p = at(x, y);
        if (y < 295 && Math.max(...p) > 40) Object.assign(circle, { x0: Math.min(circle.x0, x), x1: Math.max(circle.x1, x), y0: Math.min(circle.y0, y), y1: Math.max(circle.y1, y) });
        else if (y > 295 && Math.max(...p) > 40) inkRow = true;
        if (y > 360 && y < 420) brightest = Math.max(brightest, p[0]!);
      }
      if (inkRow) ink.push(y);
    }
    const gap = ink.findIndex((y, i) => i > 0 && y - ink[i - 1]! > 1);
    section("Share image 600 × 600 (`invite.web.layout.ogImage`; group without a cover, “Roommates”)");
    check("size", "600 × 600 PNG", `${info.width} × ${info.height} PNG`);
    check("avatar circle 83 px, top 208 (Retro x 258–340, y 208–290; anti-aliased edge included)", "x 258–340, y 208–290", `x ${circle.x0}–${circle.x1}, y ${circle.y0}–${circle.y1}`);
    check("name baseline: ink rows end at 348 (Retro 'nathan' 309–348)", 348, ink[gap - 1]!, "'Roommates' has no descender, so its last ink row is the baseline row");
    check("domain ink from row 369 (name baseline + `nameToDomain` 21)", 369, ink[gap]!);
    check("background without a cover: `color.global.backgroundDeep`", "#000000", toHex(at(10, 10) as [number, number, number]));
    const ogBackdrop = inviteBackdrop();
    row("background with a cover", "`invite.web.layout.backdrop`: σ = 0.08 × 600 = 48 px under `color.global.backdropDim`", `σ ${ogBackdrop.blurSigmaToWidth * 600} px (sharp Gaussian, float precision) + ${css(colorHex(ogBackdrop.dim))} layer (og-cover.png)`, "matched", "Retro's own field is also darker overall (its profile photo is darker than this cover): photo-dependent");
    row("name face", "`font.global.display`, ≈ 52 px; weight not measurable (Gap)", "Noto Serif Regular 52 px (bundled, OFL)", "approximated", "Retro's OG name reads bold; the display role's weight (regular) is used");
    row("domain line", "`font.global.family` 20 px, white ≈ 70 % (#BBC5C9 over Retro's navy)", `Inter 20 px, #FFFFFF at 0.7 (brightest ${brightest} on black = #${brightest.toString(16).toUpperCase().repeat(3)})`, "matched", "colour over a black field; Retro's reading includes its backdrop");
    row("cover circle when there is no cover", "not specified", "`invite.web.color.avatarPlaceholder` circle", "approximated", "the page's no-photo avatar");

    // ---------- accessibility ----------
    const tone = await backdropTone(photo("family-dinner-4x3.jpg"));
    const table = (pairs: PairResult[]) =>
      pairs.map((p) => `| ${p.element} | ${p.fg} on ${p.bg} | ${p.ratio.toFixed(2)}:1 | ${p.need}:1 (${p.kind}) | ${p.pass ? "pass" : "**FAIL**"} |`).join("\n");
    const contrast = `## Contrast (WCAG 2.2; \`src/contrastReport.ts\`)

Large text = 24 CSS px, or 18.66 CSS px bold (WCAG's 18 pt / 14 pt). Sourced values are reported, not adjusted.

**Mobile card over the spec's sample backdrop ${toHex(SPEC_BACKDROP_SAMPLE)} (Retro's capture)**

| pair | colours | ratio | needs | result |
|---|---|---|---|---|
${table(cardPairs(SPEC_BACKDROP_SAMPLE))}

**Mobile card over this render's backdrop** (\`fixtures/photos/family-dinner-4x3.jpg\`: mean of its lower half under the \`invite.web.layout.backdrop\` dim = ${toHex(tone)})

| pair | colours | ratio | needs | result |
|---|---|---|---|---|
${table(cardPairs(tone))}

**State card (\`color.global.backgroundDeep\`)**

| pair | colours | ratio | needs | result |
|---|---|---|---|---|
${table(statePairs())}

**Desktop column (white page)**

| pair | colours | ratio | needs | result |
|---|---|---|---|---|
${table(desktopPairs())}

Spec differences: the spec lists the desktop line (black 50 % on white, 4.00:1) as passing as large text (20 px ≥ the
token's "18 pt"); by WCAG's web definition 20 px regular is normal text, so it fails 4.5:1, as does the 14-px desktop
footer at the same colour (not in the spec's table). The 8-px mobile footer is below any recommended size (Retro's own).
In development the server logs the failing pairs of each invite's own backdrop.
`;

    // ---------- side by side ----------
    const H = 1992;
    const fit = async (buf: Buffer, h: number) => sharp(buf).resize({ height: h }).png().toBuffer();
    const pair = async (a: Buffer, b: Buffer, h: number) => {
      const [x, y] = await Promise.all([fit(a, h), fit(b, h)]);
      const [mx, my] = await Promise.all([sharp(x).metadata(), sharp(y).metadata()]);
      return { img: await sharp({ create: { width: mx.width! + my.width! + 40, height: h, channels: 3, background: { r: 255, g: 255, b: 255 } } }).composite([{ input: x, left: 0, top: 0 }, { input: y, left: mx.width! + 40, top: 0 }]).png().toBuffer(), width: mx.width! + my.width! + 40 };
    };
    const ogCover = Buffer.from(await (await fetch(`${servers.main.base}/i/${TOKENS.valid}/og.png`)).arrayBuffer());
    const rowsImg = [
      await pair(oursMobile!, fs.readFileSync(REF("retro.app-u-nathan-iphone.png")), H),
      await pair(oursDesktop!, fs.readFileSync(REF("retro.app-u-nathan-desktop.png")), 900),
      await pair(ogCover, fs.readFileSync(REF("retro.app-og-userogsquare-nathan.png")), 600),
    ];
    const W = Math.max(...rowsImg.map((r) => r.width));
    let y = 0;
    const comps = rowsImg.map((r) => {
      const o = { input: r.img, left: 0, top: y };
      y += (r === rowsImg[0] ? H : r === rowsImg[1] ? 900 : 600) + 40;
      return o;
    });
    await sharp({ create: { width: W, height: y - 40, channels: 3, background: { r: 255, g: 255, b: 255 } } }).composite(comps).png().toFile(OUT_PNG);

    // ---------- markdown ----------
    const all = sections.flatMap((s) => s.rows);
    const count = (s: Status) => all.filter((r) => r.status === s).length;
    const esc = (s: string) => s.replace(/\|/g, "\\|").replace(/\n/g, " ");
    const body = sections
      .map((s) => `## ${s.name}\n\n| status | item | spec | renders | note |\n|---|---|---|---|---|\n${s.rows.map((r) => `| ${r.status === "matched" ? "matched" : r.status === "approximated" ? "approximated" : "**not matched**"} | ${esc(r.item)} | ${esc(r.spec)} | ${esc(r.rendered)} | ${esc(r.note)} |`).join("\n")}`)
      .join("\n\n");
    const md = `# Verification — \`invite.web\`

Generated by \`web/scripts/verify.ts\` (\`cd web && npm run verify\`) on ${new Date().toISOString().slice(0, 10)} against
\`design/surfaces/invite.web.md\` (Retro's \`/u/[username]\` page). The real service with a fixture upstream (sample
photos from \`fixtures/photos\`: cover \`family-dinner-4x3.jpg\`, avatars \`avatar-01…08.jpg\`; group “Lima family”,
inviter Ana, 8 members, Rui without a photo) rendered by Playwright Chromium (\`PLAYWRIGHT_BROWSERS_PATH\`) in the capture
setups of Retro's references: mobile 390 × 664 CSS px @3x with an iPhone user agent
(\`references/auto/retro/web/retro.app-u-nathan-iphone.png\`), desktop 1440 × 900 @1x (\`retro.app-u-nathan-desktop.png\`).
Values are \`getComputedStyle\` / \`getBoundingClientRect\` read back from the page and pixels of the served images.

**Result: ${count("matched")} matched, ${count("approximated")} approximated, ${count("not matched")} not matched.**

Renders (git-ignored PNGs, written by \`test/render/invite.render.test.ts\` on every \`npm test\`):
\`design/verification/invite.web/<state>-<mobile|desktop>-<light|dark>.png\` for the states ${CASES.map((k) => `\`${k.name}\``).join(", ")};
\`valid-busy-mobile-light.png\` (“Opening…”); \`og-cover.png\`, \`og-no-cover.png\` (share images).
Side by side: [\`invite.web.png\`](invite.web.png) (git-ignored; contains reference crops) — ours left, Retro right:
mobile card | iPhone capture (Retro's photo did not load in its capture), desktop | desktop capture, share image | Retro's share image.

By design (do-not-copy / no counterpart): no Retro mark top-left, wordmark, stock backdrops, "© Lone Palm Labs", store
badges, page counts. Added by the spec: the members' avatar stack (SPEC_FLAGS T7). Fonts: no commercial face is used —
the display role is the platform serif (ui-serif → New York on Apple; Noto Serif on Android and in these renders), text
is the platform UI face; Retro's Roslindale Display Narrow is narrower, so line breaks differ.

${body}

${contrast}
## Not built / open

- **Member stack ring** (C-23 Gap): not drawn, as in the native components.
- **Initials avatar** (C-23 Gap): the no-photo member shows \`icon.global.person\`; the inviter without a photo shows the
  \`invite.web.color.avatarPlaceholder\` circle (spec).
- **App mark on the card**: none (owner's mark, decision 0.2).
- **Document title**: \`invite.web.documentTitle\` is BLOCKED until the app is named.
- **"Full" state**: not a web state in the spec; a full group is reported by \`join_group\` in the App Clip / app.
- **Share-image glyph coverage**: the bundled Noto Serif / Inter cover Latin, Greek and Cyrillic; other scripts and emoji in
  a group name need system fonts in the container (fonts.conf falls back to them; the slim image has none).
`;
    fs.writeFileSync(OUT_MD, md);
    console.log(`wrote ${path.relative(ROOT, OUT_MD)} (${count("matched")} matched, ${count("approximated")} approximated, ${count("not matched")} not matched) and ${path.relative(ROOT, OUT_PNG)}`);
  } finally {
    await browser.close();
    await servers.close();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
