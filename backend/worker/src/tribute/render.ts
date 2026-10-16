// Tribute video (surface birthday.tribute): title card → one card per contribution (photo +
// contributor first name + their one line) → end card, rendered with sharp (cards; text in the app's fonts: Roboto Serif Headline display, Inter UI,
// with the fallback set of fonts/fallback for other scripts and colour emoji — fonts/fonts.conf)
// and ffmpeg (sequence, transitions, H.264 MP4).
//
// Structure and timings come from design tokens (research: design/research/wrapped-tribute-
// partiful.md §4), read by name at runtime; a missing one fails the job with "missing design token
// <name>". Nothing here invents a duration, position, size or color. Token shapes are listed in
// backend/worker/COPY_KEYS.md ("Design tokens the worker reads").

import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import sharp, { type OverlayOptions, type Sharp } from "sharp";
import { designToken } from "../tokens.js";
import { ffmpeg } from "../media/ffmpeg.js";
import { JPEG_OPTIONS } from "../media/renditions.js";
import { WORKER_ROOT } from "../config.js";

/**
 * fontconfig reads FONTCONFIG_FILE once, at its first use (the first text or SVG render in the process), so it is set
 * when this module loads: the app's faces plus the fallback set (fonts/fonts.conf → ../../../fonts/fallback), no system
 * fonts. An operator's own FONTCONFIG_FILE wins.
 */
export const FONTCONFIG_FILE = path.join(process.env.FONTS_DIR || path.join(WORKER_ROOT, "fonts"), "fonts.conf");
process.env.FONTCONFIG_FILE ||= FONTCONFIG_FILE;

export interface CardTextLayout {
  /** #RRGGBB card background */
  background: string;
  /** #RRGGBB text color */
  textColor: string;
  /** CSS numeric weight (100–900) */
  fontWeight: number;
  /** font size ÷ video height */
  fontSizeRatio: number;
  /** text box width ÷ video width (text wraps inside it, centered) */
  maxWidthRatio: number;
  /** vertical center of the text ÷ video height */
  centerYRatio: number;
}

export interface CaptionLayout {
  textColor: string;
  nameFontWeight: number;
  nameFontSizeRatio: number;
  lineFontWeight: number;
  lineFontSizeRatio: number;
  /** left edge of the caption ÷ video width */
  leftRatio: number;
  /** distance of the caption's last baseline box from the bottom ÷ video height */
  bottomRatio: number;
  maxWidthRatio: number;
  /** gap between name and line ÷ video height */
  gapRatio: number;
  /** optional #RRGGBBAA band behind the caption */
  scrim?: string | null;
}

export interface TributeTokens {
  video: { width: number; height: number; fps: number };
  titleHoldMs: number;
  titleCrossfadeMs: number;
  photoHoldMs: number;
  clipTransitionMs: number;
  endTransitionMs: number;
  endHoldMs: number;
  pillarbox: string;
  titleCard: CardTextLayout;
  endCard: CardTextLayout;
  caption: CaptionLayout;
}

export const TRIBUTE_TOKEN_NAMES = {
  video: "layout.birthday.tribute.video",
  titleHoldMs: "duration.birthday.tribute.titleHold",
  titleCrossfadeMs: "duration.birthday.tribute.titleCrossfade",
  photoHoldMs: "duration.birthday.tribute.photoHold",
  clipTransitionMs: "duration.birthday.tribute.clipTransition",
  endTransitionMs: "duration.birthday.tribute.endTransition",
  endHoldMs: "duration.birthday.tribute.endHold",
  pillarbox: "color.birthday.tribute.pillarbox",
  titleCard: "layout.birthday.tribute.titleCard",
  endCard: "layout.birthday.tribute.endCard",
  caption: "layout.birthday.tribute.caption",
} as const satisfies Record<keyof TributeTokens, string>;

/** All tribute tokens, or MissingTokenError for the first one that is not there. */
export function tributeTokens(): TributeTokens {
  const out = {} as Record<keyof TributeTokens, unknown>;
  for (const [k, name] of Object.entries(TRIBUTE_TOKEN_NAMES) as Array<[keyof TributeTokens, string]>) out[k] = designToken(name);
  return out as unknown as TributeTokens;
}

export interface TributeCardInput {
  image: Buffer;
  name: string;
  line: string;
}

export interface TributeTexts {
  title: string;
  end: string;
}

/**
 * Fonts the video text is set in, matching the app (design/tokens/global.json): title and end cards use the
 * narrow display serif role (`font.global.displayNarrow` → Roboto Serif Headline, the app's bundled headline face,
 * SIL OFL — MERGE_DECISIONS L-8), captions the UI role
 * (`font.global.family` on Android → Inter, SIL OFL, static instances of the app's variable font).
 * Files and licences: fonts/SOURCE.txt.
 */
export type FontRole = "display" | "ui";
/**
 * `fallback` is the fontconfig alias (fonts/fonts.conf) whose fonts supply what the app's face lacks: serif Noto faces
 * for the display role, sans for the UI role (Greek, Arabic, Hebrew, Devanagari, Thai, CJK, Hangul).
 */
const FONTS: Record<FontRole, { family: string; fallback: string; files: Array<[number, string]> }> = {
  display: { family: "Roboto Serif Headline", fallback: "serif", files: [[400, "RobotoSerifHeadline-Regular.ttf"]] },
  ui: { family: "Inter Variable", fallback: "sans-serif", files: [[400, "Inter-Regular.ttf"], [600, "Inter-SemiBold.ttf"]] },
};

/** The colour emoji font (fonts/fallback/NotoColorEmoji-COLRv1.ttf; libvips text draws COLRv1 in colour). */
export const EMOJI_FAMILY = "Noto Color Emoji";
const PANGO_WEIGHTS: Record<number, string> = { 100: "Thin", 200: "Ultra-Light", 300: "Light", 400: "", 500: "Medium", 600: "Semi-Bold", 700: "Bold", 800: "Ultra-Bold", 900: "Heavy" };

function nearest(role: FontRole, weight: number): [number, string] {
  let best = FONTS[role].files[0] as [number, string];
  for (const w of FONTS[role].files) if (Math.abs(w[0] - weight) < Math.abs(best[0] - weight)) best = w;
  return best;
}

export function fontFile(fontsDir: string, weight: number, role: FontRole = "ui"): string {
  return path.join(fontsDir, nearest(role, weight)[1]);
}

/** Pango font description for the file `fontFile` picks: family then its fallback alias, weight keyword, size. */
export function fontDescription(role: FontRole, weight: number, sizePx: number): string {
  const w = PANGO_WEIGHTS[nearest(role, weight)[0]] ?? "";
  return `${FONTS[role].family},${FONTS[role].fallback}${w ? " " + w : ""} ${Math.max(1, Math.round(sizePx))}`;
}

const pango = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

// The `v` flag (properties of strings, Node ≥ 20) is newer than the ES2023 target, so the pattern is built at run time.
const RGI_EMOJI = () => new RegExp("\\p{RGI_Emoji}", "gv");

/**
 * Pango markup of `text` with every RGI emoji sequence (❤️, 👩🏽‍🦱, 🇧🇷, 1️⃣ …) set in the colour emoji font: Inter has
 * text glyphs for a few emoji code points (❤ ☀ ↔ ‼) and Pango would otherwise keep them in the text face, in the text
 * colour. A code point without the emoji variation selector (a bare ❤) stays text, as Unicode presents it.
 */
export function emojiMarkup(text: string): string {
  let out = "";
  let last = 0;
  for (const m of text.matchAll(RGI_EMOJI())) {
    out += pango(text.slice(last, m.index)) + `<span font_family="${EMOJI_FAMILY}">${m[0]}</span>`;
    last = m.index + m[0].length;
  }
  return out + pango(text.slice(last));
}

/** One block of card text, wrapped inside `width`, as a transparent PNG (exported for the font tests). */
export async function textImage(
  text: string,
  opts: { fontsDir: string; role: FontRole; weight: number; sizePx: number; color: string; width: number; maxHeight?: number; align: "left" | "centre" },
): Promise<{ data: Buffer; width: number; height: number }> {
  const img = sharp({
    text: {
      text: `<span foreground="${opts.color}">${emojiMarkup(text)}</span>`,
      font: fontDescription(opts.role, opts.weight, opts.sizePx),
      fontfile: fontFile(opts.fontsDir, opts.weight, opts.role),
      width: Math.max(1, Math.round(opts.width)),
      align: opts.align,
      dpi: 72,
      rgba: true,
      // words that do not fit on a line are broken between characters
      wrap: "word-char",
    },
  });
  const { data, info } = await img.png().toBuffer({ resolveWithObject: true });
  if (info.width <= opts.width && (opts.maxHeight === undefined || info.height <= opts.maxHeight)) return { data, width: info.width, height: info.height };
  // never larger than its box (a composite larger than the card is an error)
  const fitted = await sharp(data)
    .resize({ width: Math.max(1, Math.floor(opts.width)), height: opts.maxHeight ? Math.max(1, Math.floor(opts.maxHeight)) : undefined, fit: "inside" })
    .png()
    .toBuffer({ resolveWithObject: true });
  return { data: fitted.data, width: fitted.info.width, height: fitted.info.height };
}

async function solid(w: number, h: number, color: string): Promise<Sharp> {
  return sharp({ create: { width: w, height: h, channels: 4, background: color } });
}

export async function textCard(text: string, layout: CardTextLayout, video: TributeTokens["video"], fontsDir: string): Promise<Buffer> {
  const { width: W, height: H } = video;
  const t = await textImage(text, { fontsDir, role: "display", weight: layout.fontWeight, sizePx: layout.fontSizeRatio * H, color: layout.textColor, width: layout.maxWidthRatio * W, maxHeight: H, align: "centre" });
  const left = Math.round((W - t.width) / 2);
  const top = Math.max(0, Math.round(layout.centerYRatio * H - t.height / 2));
  return (await solid(W, H, layout.background)).composite([{ input: t.data, left: Math.max(0, left), top }]).png().toBuffer();
}

export async function contributionCard(c: TributeCardInput, tk: TributeTokens, fontsDir: string): Promise<Buffer> {
  const { width: W, height: H } = tk.video;
  // the whole photo is shown ("nothing gets cut off"), on the pillarbox color
  const photo = await sharp(c.image).rotate().resize({ width: W, height: H, fit: "inside" }).png().toBuffer({ resolveWithObject: true });
  const layers: OverlayOptions[] = [{ input: photo.data, left: Math.round((W - photo.info.width) / 2), top: Math.round((H - photo.info.height) / 2) }];
  const cap = tk.caption;
  const boxW = cap.maxWidthRatio * W;
  const name = await textImage(c.name, { fontsDir, role: "ui", weight: cap.nameFontWeight, sizePx: cap.nameFontSizeRatio * H, color: cap.textColor, width: boxW, maxHeight: H / 2, align: "left" });
  const line = await textImage(c.line, { fontsDir, role: "ui", weight: cap.lineFontWeight, sizePx: cap.lineFontSizeRatio * H, color: cap.textColor, width: boxW, maxHeight: H / 2, align: "left" });
  const x = Math.round(cap.leftRatio * W);
  const lineTop = Math.max(0, Math.round(H - cap.bottomRatio * H - line.height));
  const nameTop = Math.max(0, Math.round(lineTop - cap.gapRatio * H - name.height));
  if (cap.scrim) {
    const scrimTop = nameTop;
    layers.push({ input: await (await solid(W, H - scrimTop, cap.scrim)).png().toBuffer(), left: 0, top: scrimTop });
  }
  layers.push({ input: name.data, left: x, top: nameTop }, { input: line.data, left: x, top: lineTop });
  return (await solid(W, H, tk.pillarbox)).composite(layers).png().toBuffer();
}

export interface RenderedTribute {
  mp4: Buffer;
  poster: Buffer;
  durationMs: number;
  cpuSeconds: number;
  wallMs: number;
}

/** Card sequence → MP4. Transition 0 ms = hard cut. */
export async function renderTribute(cards: TributeCardInput[], texts: TributeTexts, tk: TributeTokens, fontsDir: string): Promise<RenderedTribute> {
  if (!cards.length) throw new Error("a tribute needs at least one contribution");
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "worker-tribute-"));
  try {
    const title = await textCard(texts.title, tk.titleCard, tk.video, fontsDir);
    const end = await textCard(texts.end, tk.endCard, tk.video, fontsDir);
    const files: string[] = [];
    const write = async (name: string, b: Buffer) => {
      const f = path.join(dir, name);
      await fs.writeFile(f, b);
      files.push(f);
    };
    await write("00-title.png", title);
    for (const [i, c] of cards.entries()) await write(`${String(i + 1).padStart(2, "0")}-card.png`, await contributionCard(c, tk, fontsDir));
    await write("99-end.png", end);

    // Segment i is fully visible for hold[i]; the transition T(i) after it overlaps the end of
    // segment i and the start of segment i+1 (fade), or is a hard cut when 0 ms.
    const holds = [tk.titleHoldMs, ...cards.map(() => tk.photoHoldMs), tk.endHoldMs];
    const trans = [tk.titleCrossfadeMs, ...cards.slice(1).map(() => tk.clipTransitionMs), tk.endTransitionMs];
    const s = (ms: number) => (ms / 1000).toFixed(3);
    const inDur = (i: number) => (i > 0 ? (trans[i - 1] as number) : 0) + (holds[i] as number) + (i < trans.length ? (trans[i] as number) : 0);
    const args: string[] = ["-y"];
    files.forEach((f) => args.push("-i", f));
    // each card is decoded and converted once, then repeated for its duration (no per-frame PNG decode)
    const fps = tk.video.fps;
    const filters: string[] = [];
    files.forEach((_f, i) => {
      const frames = Math.max(1, Math.round((inDur(i) / 1000) * fps));
      filters.push(`[${i}:v]format=yuv420p,setsar=1,loop=loop=${frames - 1}:size=1:start=0,setpts=N/${fps}/TB,fps=${fps}[v${i}]`);
    });
    let prev = "v0";
    let chainMs = inDur(0);
    for (let i = 1; i < files.length; i++) {
      const t = trans[i - 1] as number;
      const out = `x${i}`;
      if (t > 0) {
        filters.push(`[${prev}][v${i}]xfade=transition=fade:duration=${s(t)}:offset=${s(chainMs - t)}[${out}]`);
        chainMs += inDur(i) - t;
      } else {
        filters.push(`[${prev}][v${i}]concat=n=2:v=1:a=0[${out}]`);
        chainMs += inDur(i);
      }
      prev = out;
    }
    const outFile = path.join(dir, "tribute.mp4");
    args.push(
      "-filter_complex", filters.join(";"),
      "-map", `[${prev}]`,
      "-r", String(tk.video.fps),
      // the frames are still cards: x264's stillimage tuning (≈ 30 % less CPU measured locally, same size)
      "-c:v", "libx264", "-tune", "stillimage", "-pix_fmt", "yuv420p", "-profile:v", "high",
      "-map_metadata", "-1", "-movflags", "+faststart",
      outFile,
    );
    const r = await ffmpeg(args, { cwd: dir });
    return {
      mp4: await fs.readFile(outFile),
      poster: await sharp(title).jpeg(JPEG_OPTIONS).toBuffer(),
      durationMs: chainMs,
      cpuSeconds: r.cpuSeconds,
      wallMs: r.wallMs,
    };
  } finally {
    await fs.rm(dir, { recursive: true, force: true });
  }
}
