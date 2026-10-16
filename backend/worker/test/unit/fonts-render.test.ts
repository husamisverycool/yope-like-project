// Tribute card text in every script a member's name or line may use, and emoji (fonts/fallback/SOURCE.txt): each
// character has a glyph in the worker's font set, the render differs from the same text drawn without fallback fonts
// (Pango's hex boxes), and emoji come out in colour. Renders are kept in os.tmpdir()/worker-font-renders for review.
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import sharp from "sharp";
import { describe, expect, it } from "vitest";
import { REPO_ROOT, WORKER_ROOT } from "../../src/config.js";
import { EMOJI_FAMILY, FONTCONFIG_FILE, emojiMarkup, fontDescription, fontFile, textImage, type FontRole } from "../../src/tribute/render.js";
import { cmapCodePoints } from "../helpers/cmap.js";

const FONTS_DIR = path.join(WORKER_ROOT, "fonts");
const FALLBACK_DIRS = ["scripts", "emoji-color"].map((d) => path.join(REPO_ROOT, "fonts", "fallback", d));
const OUT = path.join(os.tmpdir(), "worker-font-renders");
fs.mkdirSync(OUT, { recursive: true });

/** A member's name and line per script (the fallback set's coverage), plus emoji sequences. */
const SAMPLES: Record<string, string> = {
  cyrillic: "Наташа · С днём рождения!",
  greek: "Ελένη · Χρόνια πολλά!",
  arabic: "نور · عيد ميلاد سعيد",
  hebrew: "שרה · יום הולדת שמח",
  devanagari: "प्रिया · जन्मदिन मुबारक",
  thai: "สมใจ · สุขสันต์วันเกิด",
  han: "美咲 · 王小明 · 生日快乐",
  kana: "さくら · おたんじょうび",
  hangul: "지은 · 생일 축하해",
  emoji: "Ana 🎉❤️👩🏽‍🦱🇧🇷1️⃣",
};

/** Code points that are sequence glue rather than glyphs of their own. */
const JOINERS = new Set([0x200d, 0xfe0f, 0x20e3]);

describe("font set", () => {
  const files = [
    ...[FONTS_DIR, ...FALLBACK_DIRS].flatMap((d) => fs.readdirSync(d).filter((f) => f.endsWith(".ttf")).map((f) => path.join(d, f))),
  ];
  const maps = files.map((f) => ({ file: path.basename(f), cps: cmapCodePoints(f) }));

  it("reads fonts.conf, which lists the app's faces, the script fallbacks and the colour emoji — no system fonts", () => {
    expect(process.env.FONTCONFIG_FILE).toBe(FONTCONFIG_FILE);
    const conf = fs.readFileSync(FONTCONFIG_FILE, "utf8");
    const dirs = [...conf.matchAll(/<dir prefix="relative">([^<]+)<\/dir>/g)].map((m) => path.resolve(path.dirname(FONTCONFIG_FILE), m[1]!));
    expect(dirs).toEqual([FONTS_DIR, ...FALLBACK_DIRS]);
    expect(conf).not.toMatch(/<include/);
  });

  it.each(Object.entries(SAMPLES))("%s: every character has a glyph", (_script, text) => {
    for (const ch of text) {
      const cp = ch.codePointAt(0)!;
      if (JOINERS.has(cp) || ch === " ") continue;
      expect(maps.some((m) => m.cps.has(cp)), `U+${cp.toString(16).toUpperCase()} ${ch}`).toBe(true);
    }
  });
});

/** The same text with font fallback switched off: what the card showed before the fallback set (hex boxes). */
async function withoutFallback(text: string, role: FontRole, weight: number, sizePx: number): Promise<Buffer> {
  const { data } = await sharp({
    text: {
      text: `<span foreground="#FFFFFF" fallback="false">${text.replace(/&/g, "&amp;").replace(/</g, "&lt;")}</span>`,
      font: fontDescription(role, weight, sizePx),
      fontfile: fontFile(FONTS_DIR, weight, role),
      width: 1600,
      dpi: 72,
      rgba: true,
    },
  })
    .png()
    .toBuffer({ resolveWithObject: true });
  return data;
}

async function onDark(png: Buffer): Promise<{ data: Buffer; width: number; height: number }> {
  const { data, info } = await sharp(png).flatten({ background: "#000000" }).raw().toBuffer({ resolveWithObject: true });
  return { data, width: info.width, height: info.height };
}

/** Pixels whose colour is clearly not grey (white text on black is grey at every edge pixel; colour emoji are not). */
function colourPixels(img: { data: Buffer; width: number; height: number }): number {
  let n = 0;
  for (let i = 0; i < img.width * img.height; i++) {
    const r = img.data[i * 3]!;
    const g = img.data[i * 3 + 1]!;
    const b = img.data[i * 3 + 2]!;
    if (Math.max(r, g, b) - Math.min(r, g, b) > 30) n++;
  }
  return n;
}

describe("card text renders every script and emoji", () => {
  const roles: Array<[FontRole, number]> = [["display", 400], ["ui", 400], ["ui", 600]];

  it.each(Object.keys(SAMPLES).flatMap((script) => roles.map(([role, weight]) => [script, role, weight] as const)))(
    "%s in the %s role at %i",
    async (script, role, weight) => {
      const text = SAMPLES[script]!;
      const sizePx = 64;
      const rendered = await textImage(text, { fontsDir: FONTS_DIR, role, weight, sizePx, color: "#FFFFFF", width: 1600, align: "left" });
      const file = path.join(OUT, `${script}-${role}-${weight}.png`);
      await sharp(rendered.data).flatten({ background: "#000000" }).png().toFile(file);
      expect(rendered.width).toBeGreaterThan(0);
      const tofu = await withoutFallback(text, role, weight, sizePx);
      // Without the fallback set Pango draws hex boxes; with it the glyphs differ — except where the app's own face has
      // the script (Inter: Cyrillic and Greek; Roboto Serif: Cyrillic), which must stay in that face.
      const ownFace = script === "cyrillic" || (script === "greek" && role === "ui");
      expect(rendered.data.equals(tofu), file).toBe(ownFace);
      const colour = colourPixels(await onDark(rendered.data));
      if (script === "emoji") expect(colour, `colour emoji in ${file}`).toBeGreaterThan(500);
      else expect(colour, `text only, no colour, in ${file}`).toBe(0);
    },
  );

  it("sets RGI emoji sequences in the colour font and leaves a bare ❤ as text", () => {
    expect(emojiMarkup("Ana ❤️ & 👩🏽‍🦱")).toBe(
      `Ana <span font_family="${EMOJI_FAMILY}">❤️</span> &amp; <span font_family="${EMOJI_FAMILY}">👩🏽‍🦱</span>`,
    );
    expect(emojiMarkup("<3 ❤")).toBe("&lt;3 ❤");
  });

  // ❤️: Inter has a text ❤; 🎉: default emoji presentation; 👩🏽‍🦱: ZWJ + skin tone; 🇧🇷: flag; 1️⃣: keycap.
  it.each(["❤️", "🎉", "👩🏽‍🦱", "🇧🇷", "1️⃣"])("draws %s in colour in both roles", async (emoji) => {
    for (const role of ["display", "ui"] as const) {
      const rendered = await textImage(emoji, { fontsDir: FONTS_DIR, role, weight: 400, sizePx: 64, color: "#FFFFFF", width: 400, align: "left" });
      expect(colourPixels(await onDark(rendered.data)), `${emoji} ${role}`).toBeGreaterThan(300);
    }
  });
});
