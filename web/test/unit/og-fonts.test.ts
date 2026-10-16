// The invite share image (og.png) with group names in every script a group may be named in, and emoji
// (fonts/fallback/SOURCE.txt): every character has a glyph in the web's font set, a name renders differently from the
// same SVG under a font set without the fallbacks (what og.png drew before: tofu), and emoji are drawn in the
// monochrome emoji font. Renders are kept in os.tmpdir()/web-og-renders for review.
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";
import { describe, expect, it } from "vitest";
import { EMOJI_FAMILY, FONTCONFIG_FILE, composeOgImage, emojiTspans, textSvg } from "../../src/images.js";
import { cmapCodePoints } from "../support/cmap.js";

const WEB = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const FONT_DIR = path.join(WEB, "assets", "fonts");
const FALLBACK_DIRS = ["scripts", "emoji-mono"].map((d) => path.resolve(WEB, "..", "fonts", "fallback", d));
const OUT = path.join(os.tmpdir(), "web-og-renders");
fs.mkdirSync(OUT, { recursive: true });

const NAMES: Record<string, string> = {
  cyrillic: "Семья Петровых",
  greek: "Οικογένεια",
  arabic: "عائلة نور",
  hebrew: "משפחת כהן",
  devanagari: "शर्मा परिवार",
  thai: "ครอบครัวสมใจ",
  han: "王家 美咲",
  kana: "さくらの家族",
  hangul: "지은이네 가족",
  emoji: "Lima 🎉❤️👩🏽‍🦱🇧🇷",
};
const JOINERS = new Set([0x200d, 0xfe0f, 0x20e3]);

describe("share image font set", () => {
  it("reads fonts.conf: the bundled faces, the script fallbacks and the monochrome emoji — no system fonts", () => {
    expect(process.env.FONTCONFIG_FILE).toBe(FONTCONFIG_FILE);
    const conf = fs.readFileSync(FONTCONFIG_FILE, "utf8");
    const dirs = [...conf.matchAll(/<dir prefix="relative">([^<]+)<\/dir>/g)].map((m) => path.resolve(FONT_DIR, m[1]!));
    expect(dirs).toEqual([FONT_DIR, ...FALLBACK_DIRS]);
    expect(conf).not.toMatch(/<include/);
  });

  const maps = [FONT_DIR, ...FALLBACK_DIRS].flatMap((d) =>
    fs.readdirSync(d).filter((f) => f.endsWith(".ttf")).map((f) => cmapCodePoints(path.join(d, f))),
  );
  it.each(Object.entries(NAMES))("%s: every character has a glyph", (_script, name) => {
    for (const ch of name) {
      const cp = ch.codePointAt(0)!;
      if (JOINERS.has(cp) || ch === " ") continue;
      expect(maps.some((m) => m.has(cp)), `U+${cp.toString(16).toUpperCase()} ${ch}`).toBe(true);
    }
  });

  it("sets RGI emoji sequences in the emoji font and escapes the rest", () => {
    expect(emojiTspans("Lima & ❤️")).toBe(`Lima &#38; <tspan font-family="${EMOJI_FAMILY}">❤️</tspan>`);
    expect(emojiTspans("<3 ❤")).toBe("&#60;3 ❤");
  });
});

/** The same SVG rendered by a separate process whose fontconfig sees only the bundled faces (no fallbacks). */
function withoutFallback(svg: Buffer): Buffer {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "og-nofallback-"));
  fs.writeFileSync(
    path.join(dir, "fonts.conf"),
    `<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd"><fontconfig><dir>${FONT_DIR}</dir><cachedir>${dir}/cache</cachedir></fontconfig>`,
  );
  fs.writeFileSync(path.join(dir, "in.svg"), svg);
  const script = `const sharp = require(${JSON.stringify(path.join(WEB, "node_modules", "sharp"))}); sharp(process.argv[1]).png().toFile(process.argv[2]).then(() => {}, (e) => { console.error(e); process.exit(1); });`;
  execFileSync(process.execPath, ["-e", script, path.join(dir, "in.svg"), path.join(dir, "out.png")], { env: { ...process.env, FONTCONFIG_FILE: path.join(dir, "fonts.conf") } });
  return fs.readFileSync(path.join(dir, "out.png"));
}

async function raw(png: Buffer): Promise<Buffer> {
  return (await sharp(png).ensureAlpha().raw().toBuffer({ resolveWithObject: true })).data;
}

describe("share image text renders every script and emoji", () => {
  it.each(Object.keys(NAMES).flatMap((script) => (["display", "text"] as const).map((face) => [script, face] as const)))(
    "%s in the %s face",
    async (script, face) => {
      const svg = textSvg(NAMES[script]!, face, 44, 300, 1);
      const withFallback = await sharp(svg).png().toBuffer();
      await sharp(withFallback).flatten({ background: "#1C1C1E" }).png().toFile(path.join(OUT, `${script}-${face}.png`));
      const same = (await raw(withFallback)).equals(await raw(withoutFallback(svg)));
      // the bundled faces have Cyrillic (both) and Greek (Inter): those stay in them; everything else needs the fallbacks
      expect(same).toBe(script === "cyrillic" || (script === "greek" && face === "text"));
    },
  );

  it("draws emoji in the text's colour (monochrome): no coloured pixels", async () => {
    const { data, info } = await sharp(textSvg("🎉❤️👩🏽‍🦱🇧🇷", "display", 44, 300, 1)).flatten({ background: "#000000" }).raw().toBuffer({ resolveWithObject: true });
    let ink = 0;
    let coloured = 0;
    for (let i = 0; i < info.width * info.height; i++) {
      const [r, g, b] = [data[i * 3]!, data[i * 3 + 1]!, data[i * 3 + 2]!];
      if (Math.max(r, g, b) > 128) ink++;
      if (Math.max(r, g, b) - Math.min(r, g, b) > 30) coloured++;
    }
    expect(ink).toBeGreaterThan(1000);
    expect(coloured).toBe(0);
  });

  it.each(Object.keys(NAMES))("og.png with a %s group name", async (script) => {
    const png = await composeOgImage({ cover: null, groupName: NAMES[script]!, domain: "invite.example.com" });
    fs.writeFileSync(path.join(OUT, `og-${script}.png`), png);
    const meta = await sharp(png).metadata();
    expect([meta.width, meta.height]).toEqual([600, 600]);
  });
});
