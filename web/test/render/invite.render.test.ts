// Playwright render of every invite.web state, mobile and desktop, in light and dark
// (prefers-color-scheme). Writes design/verification/invite.web/<case>-<layout>-<scheme>.png (git-ignored)
// and checks the rendered geometry and styles against the tokens of design/surfaces/invite.web.md.
// The page has one appearance (Retro's web has no dark scheme; RA-19), so dark must render pixel for
// pixel like light.

import fs from "node:fs";
import path from "node:path";
import jsQR from "jsqr";
import sharp from "sharp";
import type { Browser, Page } from "playwright-core";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { copy } from "../../src/generated/copy.js";
import { tokens } from "../../src/generated/tokens.js";
import { CASES, launch, load, measure, open, OUT_DIR, serveCases, TOKENS, type CaseName, type Layout, type Scheme } from "../support/render.js";

const t = tokens;
const c = copy as Record<string, string>;
let browser: Browser;
let servers: Awaited<ReturnType<typeof serveCases>>;
const shots = new Map<string, Buffer>();

beforeAll(async () => {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  servers = await serveCases();
  browser = await launch();
});

afterAll(async () => {
  await browser?.close();
  await servers?.close();
});

async function withPage<T>(layout: Layout, scheme: Scheme, fn: (page: Page) => Promise<T>): Promise<T> {
  const { context, page } = await open(browser, layout, scheme);
  try {
    return await fn(page);
  } finally {
    await context.close();
  }
}

const url = (name: CaseName) => {
  const k = CASES.find((x) => x.name === name)!;
  return `${servers[k.server].base}/i/${k.token}`;
};

/** Raw RGBA pixels, to compare renders independently of PNG encoding. */
const raw = async (png: Buffer) => (await sharp(png).ensureAlpha().raw().toBuffer({ resolveWithObject: true })).data;

describe("every state renders, in light and dark, identically", () => {
  for (const k of CASES) {
    for (const layout of ["mobile", "desktop"] as const) {
      it(`${k.name} · ${layout}`, async () => {
        for (const scheme of ["light", "dark"] as const) {
          await withPage(layout, scheme, async (page) => {
            expect(await load(page, url(k.name))).toBe(k.status);
            expect(await page.evaluate(() => matchMedia("(prefers-color-scheme: dark)").matches)).toBe(scheme === "dark");
            const png = await page.screenshot({ fullPage: true });
            fs.writeFileSync(path.join(OUT_DIR, `${k.name}-${layout}-${scheme}.png`), png);
            shots.set(`${k.name}-${layout}-${scheme}`, png);
          });
        }
        const light = await raw(shots.get(`${k.name}-${layout}-light`)!);
        const dark = await raw(shots.get(`${k.name}-${layout}-dark`)!);
        expect(dark.equals(light)).toBe(true);
      });
    }
  }
});

const PX = (n: number) => `${n}px`;
/** A #RRGGBB[AA] token as Chromium serialises the computed colour (alpha: the shortest of 2 or 3 decimals that maps
 *  back to the same 8-bit value). */
const rgba = (hex: string) => {
  const [r, g, b, a] = [1, 3, 5, 7].map((i) => parseInt(hex.slice(i, i + 2) || "ff", 16)) as [number, number, number, number];
  if (a === 255) return `rgb(${r}, ${g}, ${b})`;
  const two = Math.round((a / 255) * 100) / 100;
  return `rgba(${r}, ${g}, ${b}, ${Math.round(two * 255) === a ? two : Math.round((a / 255) * 1000) / 1000})`;
};
const near = (a: number, b: number, tol = 0.6) => expect(Math.abs(a - b), `${a} vs ${b}`).toBeLessThanOrEqual(tol);

describe("mobile card (viewport ≤ invite.web.size.breakpoint)", () => {
  it("valid: card, avatar, text block, members, pill and footer at the token values", async () => {
    await withPage("mobile", "light", async (page) => {
      await load(page, url("valid"));
      const inset = t["invite.web.size.cardInset"];
      const card = await measure(page, ".card", ["border-top-left-radius", "overflow"]);
      expect(card.box).toMatchObject({ x: inset, y: inset, w: 390 - 2 * inset, h: 664 - 2 * inset });
      expect(card.s["border-top-left-radius"]).toBe(PX(t["invite.web.radius.card"]));

      // invite.web.layout.backdrop: the cover with a Gaussian σ = blurSigmaToWidth × the card width, 3σ past the card,
      // under its dim colour
      const sigma = +(t["invite.web.layout.backdrop"].blurSigmaToWidth * card.box.w).toFixed(4);
      const backdrop = await measure(page, ".backdrop", ["filter", "object-fit"]);
      expect(backdrop.s["object-fit"]).toBe("cover");
      near(parseFloat(/blur\(([0-9.]+)px\)/.exec(backdrop.s.filter!)![1]!), sigma, 0.01);
      near(backdrop.box.x, card.box.x - 3 * sigma, 0.1);
      near(backdrop.box.w, card.box.w + 6 * sigma, 0.1);
      const dim = await page.$eval(".card", (e) => getComputedStyle(e, "::after").backgroundColor);
      expect(dim).toBe(rgba(t[t["invite.web.layout.backdrop"].dim as "color.global.backdropDim"]));

      const hero = await measure(page, ".hero");
      const avatar = await measure(page, ".avatar", ["border-radius", "object-fit"]);
      expect([avatar.box.w, avatar.box.h]).toEqual([t["invite.web.size.avatar"], t["invite.web.size.avatar"]]);
      near(avatar.box.x + avatar.box.w / 2, 195);
      near(avatar.box.y + avatar.box.h / 2, hero.box.y + hero.box.h / 2);
      expect(avatar.s["object-fit"]).toBe("cover");

      const h1 = await measure(page, ".headline", ["font-size", "line-height", "font-weight", "color", "font-family", "max-width"]);
      expect([h1.s["font-size"], h1.s["line-height"], h1.s["font-weight"], h1.s.color, h1.s["max-width"]]).toEqual([
        PX(t["fontSize.global.displayMedium"]),
        PX(t["invite.web.lineHeight.headline"]),
        "400",
        rgba(t["color.global.textOnMedia"]),
        PX(t["invite.web.size.textMaxWidth"]),
      ]);
      expect(h1.s["font-family"]).toBe('"Roboto Serif Headline", ui-serif, serif'); // font.global.displayNarrow (L-8)
      expect(await page.evaluate(() => document.fonts.check('34.4px "Roboto Serif Headline"') && [...document.fonts].some((f) => f.family.replace(/"/g, "") === "Roboto Serif Headline" && f.status === "loaded"))).toBe(true);
      near(h1.box.y, hero.box.bottom);

      const line = await measure(page, ".line.mobile-only", ["font-size", "line-height", "letter-spacing", "color", "font-family"]);
      expect([line.s["font-size"], line.s["line-height"], line.s["letter-spacing"], line.s.color]).toEqual([
        PX(t["invite.web.fontSize.body"]),
        PX(t["invite.web.lineHeight.body"]),
        PX(t["invite.web.letterSpacing.body"]),
        rgba(t["invite.web.color.body"]),
      ]);
      expect(line.s["font-family"]).toBe("-apple-system, BlinkMacSystemFont, system-ui, sans-serif");
      near(line.box.y - h1.box.bottom, t["invite.web.size.headlineToBody"]);
      expect(await page.$eval(".line.desktop-only", (e) => getComputedStyle(e).display)).toBe("none");

      const members = await measure(page, ".members");
      near(members.box.y - line.box.bottom, t["invite.web.size.headlineToBody"]);
      const m1 = await measure(page, ".members li:nth-child(1) .member");
      const m2 = await measure(page, ".members li:nth-child(2) .member");
      near(m1.box.w, t["size.global.avatarSmall"], 0.1);
      near(m2.box.x - m1.box.x, t["size.global.avatarSmall"] - t["size.global.avatarStackOverlap"], 0.1);

      const pill = await measure(page, ".pill", ["background-color", "color", "font-size", "font-weight", "border-top-left-radius", "transition"]);
      expect([pill.box.w, pill.box.h]).toEqual([390 - 2 * inset - 2 * t["invite.web.size.pillInset"], t["invite.web.size.pillHeight"]]);
      near(pill.box.x, inset + t["invite.web.size.pillInset"]);
      near(pill.box.y - members.box.bottom, t["invite.web.size.bodyToPill"]);
      expect([pill.s["background-color"], pill.s.color, pill.s["font-size"], pill.s["font-weight"], pill.s["border-top-left-radius"]]).toEqual([
        rgba(t["invite.web.color.pill"]),
        rgba(t["color.global.textOnMedia"]),
        PX(t["invite.web.fontSize.pill"]),
        "600",
        PX(t["invite.web.size.pillHeight"] / 2),
      ]);

      const footer = await measure(page, ".footer", ["font-size", "color"]);
      near(footer.box.y - pill.box.bottom, t["invite.web.size.pillToFooter"] + t["invite.web.size.footerMargin"]);
      near(card.box.bottom - footer.box.bottom, t["invite.web.size.footerMargin"]);
      expect([footer.s["font-size"], footer.s.color]).toEqual([PX(t["invite.web.fontSize.footer"]), rgba(t["color.global.textOnMedia"])]);
      // each footer link answers taps across a 44 × 44 area (size.global.minTouchTarget.ios), though its text is 8 px
      const terms = await measure(page, ".footer > a:first-of-type");
      const half = t["size.global.minTouchTarget.ios"] / 2 - 1;
      const hit = await page.evaluate(([x, y]) => document.elementFromPoint(x!, y!)?.textContent, [terms.box.x + terms.box.w / 2, terms.box.y + terms.box.h / 2 - half]);
      expect(hit).toBe(c["invite.web.footer.terms"]);
      // iPhone: "Download the app" (the App Store listing) leads the footer, in the footer's style and hit area
      const download = await measure(page, ".footer .mobile-only a", ["font-size", "color"]);
      expect([download.s["font-size"], download.s.color]).toEqual([PX(t["invite.web.fontSize.footer"]), rgba(t["color.global.textOnMedia"])]);
      expect(download.box.x).toBeLessThan(terms.box.x);
      const downloadHit = await page.evaluate(([x, y]) => document.elementFromPoint(x!, y!)?.textContent, [download.box.x + download.box.w / 2, download.box.y + download.box.h / 2 - half]);
      expect(downloadHit).toBe(c["invite.web.getApp"]);
    });
  });

  it("valid: 'Let's go' hover fill, and the busy state on tap (aria-busy, 'Opening…', opacity)", async () => {
    await withPage("mobile", "light", async (page) => {
      await load(page, url("valid"));
      await page.hover(".pill");
      expect((await measure(page, ".pill", ["background-color"])).s["background-color"]).toBe(rgba(t["invite.web.color.pillHover"]));
      await page.evaluate(() => document.addEventListener("click", (e) => e.preventDefault(), true)); // stay on the page
      await page.click(".pill");
      expect(await page.getAttribute(".pill", "aria-busy")).toBe("true");
      expect(await page.innerText(".pill")).toBe(c["invite.web.opening"]);
      expect((await measure(page, ".pill", ["opacity"])).s.opacity).toBe(String(t["invite.web.opacity.pillDisabled"]));
      fs.writeFileSync(path.join(OUT_DIR, "valid-busy-mobile-light.png"), await page.screenshot());
    });
  });

  it("states: the same card on color.global.backgroundDeep, no avatar, the pill only for errors", async () => {
    for (const name of ["unavailable", "not-found", "error", "rate-limited"] as const) {
      await withPage("mobile", "light", async (page) => {
        await load(page, url(name));
        expect((await measure(page, ".card", ["background-color"])).s["background-color"], name).toBe(rgba(t["color.global.backgroundDeep"]));
        expect(await page.$(".avatar"), name).toBeNull();
        expect(await page.$(".backdrop"), name).toBeNull();
        expect(await page.$$eval(".pill", (els) => els.filter((e) => getComputedStyle(e).display !== "none").length), name).toBe(name === "error" ? 1 : 0);
        expect(await page.locator("h1").count()).toBe(1);
      });
    }
  });
});

describe("desktop column (viewport > invite.web.size.breakpoint)", () => {
  it("valid: QR with the avatar in its centre, headline, line, link, footer", async () => {
    await withPage("desktop", "light", async (page) => {
      await load(page, url("valid"));
      expect(await page.$eval("html", (e) => getComputedStyle(e).backgroundColor)).toBe(rgba(t["color.global.background"].light));
      const qr = await measure(page, ".qr", ["color"]);
      const q = t["invite.web.size.qrDesktop"];
      expect([qr.box.w, qr.box.h]).toEqual([q, q]);
      near(qr.box.x + q / 2, 720);
      const avatar = await measure(page, ".avatar");
      expect([avatar.box.w, avatar.box.h]).toEqual([t["invite.web.size.avatarDesktop"], t["invite.web.size.avatarDesktop"]]);
      near(avatar.box.x + avatar.box.w / 2, qr.box.x + q / 2);
      near(avatar.box.y + avatar.box.h / 2, qr.box.y + q / 2);

      const h1 = await measure(page, ".headline", ["font-size", "line-height", "color"]);
      near(h1.box.y - qr.box.bottom, t["invite.web.size.headlineTopDesktop"]);
      expect([h1.s["font-size"], h1.s["line-height"], h1.s.color]).toEqual([PX(t["invite.web.fontSize.headlineDesktop"]), PX(t["invite.web.lineHeight.headlineDesktop"]), rgba(t["color.global.textPrimary"].light)]);

      const line = await measure(page, ".line.desktop-only", ["font-size", "line-height", "letter-spacing", "color", "max-width"]);
      expect([line.s["font-size"], line.s["line-height"], line.s["letter-spacing"], line.s.color, line.s["max-width"]]).toEqual([
        PX(t["invite.web.fontSize.bodyDesktop"]),
        PX(t["invite.web.lineHeight.bodyDesktop"]),
        PX(t["invite.web.letterSpacing.body"]),
        rgba(t["invite.web.color.bodyDesktop"]),
        PX(t["invite.web.size.bodyMaxWidthDesktop"]),
      ]);
      near(line.box.y - h1.box.bottom, t["invite.web.size.headlineToBody"]);
      expect(await page.$eval(".pill", (e) => getComputedStyle(e).display)).toBe("none");
      expect(await page.$eval(".members", (e) => getComputedStyle(e).display)).toBe("none");

      const link = await measure(page, ".link", ["font-size", "color"]);
      near(link.box.y - line.box.bottom, t["invite.web.size.bodyToQrDesktop"]);
      expect([link.s["font-size"], link.s.color]).toEqual([PX(t["fontSize.global.textButton"]), rgba(t["color.global.textPrimary"].light)]);
      const footer = await measure(page, ".footer", ["font-size", "line-height", "color"]);
      expect([footer.s["font-size"], footer.s["line-height"], footer.s.color]).toEqual([PX(t["fontSize.global.caption"]), PX(t["lineHeight.global.caption"]), rgba(t["invite.web.color.bodyDesktop"])]);
      near(900 - footer.box.bottom, t["invite.web.size.footerMargin"]);

      // the QR code, with the avatar over its centre, scans to the invite link
      const shot = await page.screenshot({ clip: { x: qr.box.x - 20, y: qr.box.y - 20, width: q + 40, height: q + 40 } });
      const { data, info } = await sharp(shot).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
      expect(jsQR.default(new Uint8ClampedArray(data), info.width, info.height)?.data).toBe(`https://invite.example.com/i/${TOKENS.valid}`);
    });
  });

  it("error: the retry action is a text link on the white page", async () => {
    await withPage("desktop", "light", async (page) => {
      await load(page, url("error"));
      expect(await page.innerText(".link")).toBe(c["invite.web.error.retry"]);
      expect(await page.$eval(".pill", (e) => getComputedStyle(e).display)).toBe("none");
      expect(await page.$(".qr")).toBeNull();
    });
  });
});

describe("share image", () => {
  it("writes the 600 × 600 link previews next to the page renders", async () => {
    for (const [name, token] of [["og-cover", TOKENS.valid], ["og-no-cover", TOKENS.noCover]] as const) {
      const res = await fetch(`${servers.main.base}/i/${token}/og.png`);
      const buf = Buffer.from(await res.arrayBuffer());
      expect((await sharp(buf).metadata()).width).toBe(600);
      fs.writeFileSync(path.join(OUT_DIR, `${name}.png`), buf);
    }
  });
});
