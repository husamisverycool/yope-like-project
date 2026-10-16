// Image processing for the invite page (sharp). Every output is re-encoded, which drops the
// source's EXIF/XMP/ICC metadata (camera, time, GPS) before anything reaches a non-member.
//
// Pixel sizes are token sizes times device pixel ratio: avatars at the mobile avatar size
// (invite.web.size.avatar) at 3x, which also covers the desktop avatar and the member stack; the
// cover at the widest viewport the mobile card is drawn in (invite.web.size.breakpoint) at 2x.
// The backdrop (C-34) is the photo blurred to a colour field; the share image follows
// invite.web.layout.ogImage.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import sharp, { type OverlayOptions } from "sharp";
import { BACKDROP_BLUR_OF_WIDTH, colorHex, layout, layoutNumber, num, rgba, tokens, type Rgb, type TokenName } from "./design.js";

export const COVER_MAX_WIDTH = Math.round(num("invite.web.size.breakpoint") * 2);
export const AVATAR_PX = Math.round(num("invite.web.size.avatar") * 3);
/** Backdrop raster width: 4 samples per σ of the blur, so the browser's upscaling of the field stays smooth. */
export const BACKDROP_WIDTH = Math.ceil(4 / BACKDROP_BLUR_OF_WIDTH);

/** Bounded decoding: refuse decompression bombs. */
const input = (buf: Buffer) => sharp(buf, { limitInputPixels: 64_000_000, failOn: "error" });

/** Flatten colour for transparent sources: the card's empty fill. */
const flattenTo = () => {
  const [r, g, b] = rgba("color.global.backgroundDeep").rgb;
  return { r, g, b };
};

export interface ProcessedCover {
  jpeg: Buffer;
  width: number;
  height: number;
}

export async function processCover(buf: Buffer): Promise<ProcessedCover> {
  const { data, info } = await input(buf)
    .rotate()
    .flatten({ background: flattenTo() })
    .resize({ width: COVER_MAX_WIDTH, withoutEnlargement: true })
    .jpeg({ mozjpeg: true })
    .toBuffer({ resolveWithObject: true });
  return { jpeg: data, width: info.width, height: info.height };
}

export async function processAvatar(buf: Buffer): Promise<Buffer> {
  return input(buf)
    .rotate()
    .flatten({ background: flattenTo() })
    .resize(AVATAR_PX, AVATAR_PX, { fit: "cover", position: "centre" })
    .jpeg({ mozjpeg: true })
    .toBuffer();
}

export interface Backdrop {
  /** The colour field, BACKDROP_WIDTH wide, lossless (upscaled by the browser; JPEG blocks would show). */
  png: Buffer;
  /** Mean colour of the field's lower half, where the text sits (contrast reporting). */
  under: Rgb;
}

/** C-34 backdrop: the (already re-encoded) photo blurred to a colour field. */
export async function blurredBackdrop(jpeg: Buffer): Promise<Backdrop> {
  const meta = await sharp(jpeg).metadata();
  const height = Math.max(1, Math.round((BACKDROP_WIDTH * (meta.height ?? 1)) / (meta.width ?? 1)));
  const { data, info } = await sharp(jpeg)
    .resize(BACKDROP_WIDTH, height, { fit: "fill" })
    .blur(BACKDROP_BLUR_OF_WIDTH * BACKDROP_WIDTH)
    .png()
    .toBuffer({ resolveWithObject: true });
  const lower = await sharp(data)
    .extract({ left: 0, top: Math.floor(info.height / 2), width: info.width, height: Math.ceil(info.height / 2) })
    .stats();
  return { png: data, under: lower.channels.slice(0, 3).map((c) => c.mean) as Rgb };
}

// ---------- share image (invite.web.layout.ogImage) ----------

// Fonts of the share image. A server has no platform fonts, so the image uses the Android values of the font
// tokens (PLATFORM): font.global.display {android: "serif"} → Noto Serif, font.global.family {android: "Inter"} →
// Inter (the face the Android app bundles). Both are SIL OFL 1.1 files in web/assets/fonts with their licences; no
// Retro face is used. fonts.conf there makes them visible to librsvg (FONTCONFIG_FILE is read when fontconfig first
// initialises, i.e. at the first text render), after the system fonts, which only supply missing glyphs.
const FONT_DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "assets", "fonts");
const FACES: Record<"display" | "text", { token: TokenName; android: string; family: string; file: string }> = {
  display: { token: "font.global.display", android: "serif", family: "Noto Serif", file: "NotoSerif-Regular.ttf" },
  text: { token: "font.global.family", android: "Inter", family: "Inter Variable", file: "Inter-Variable.ttf" },
};
for (const f of Object.values(FACES)) {
  const android = (tokens[f.token] as { android?: string }).android;
  if (android !== f.android) throw new Error(`${f.token}.android is ${android}; the share image bundles ${f.family} for "${f.android}"`);
  if (!fs.existsSync(path.join(FONT_DIR, f.file))) throw new Error(`missing font file ${path.join(FONT_DIR, f.file)}`);
}
if (!process.env.FONTCONFIG_FILE) process.env.FONTCONFIG_FILE = path.join(FONT_DIR, "fonts.conf");

interface OgLayout {
  width: number;
  height: number;
  avatarToName: number;
  nameToDomain: number;
}
const OG = layout<OgLayout>("invite.web.layout.ogImage");
export const OG_WIDTH = OG.width;
export const OG_HEIGHT = OG.height;
const N = "invite.web.layout.ogImage" as const;
const AVATAR = layoutNumber(N, "avatar", /circle, ([0-9.]+) px/);
const AVATAR_TOP = layoutNumber(N, "avatar", /top at ([0-9.]+) px/);
const NAME_INK = layoutNumber(N, "name", /ink height ([0-9.]+) px/);
const NAME_SIZE = layoutNumber(N, "name", /≈ ([0-9.]+) px type/);
const DOMAIN_SIZE = layoutNumber(N, "domain", /, ([0-9.]+) px,/);
const DOMAIN_ALPHA = layoutNumber(N, "domain", /white ≈ ([0-9.]+) %/) / 100;
// Rows as measured on Retro's image (inclusive pixel rows): avatar 208–290, name ink 309–348, domain ink from 369.
const AVATAR_LAST_ROW = AVATAR_TOP + AVATAR - 1;
const NAME_BASELINE = AVATAR_LAST_ROW + OG.avatarToName + NAME_INK; // edge below the name's last ink row
const DOMAIN_TOP_ROW = NAME_BASELINE - 1 + OG.nameToDomain;
/** Widest name: the frame less the global screen margin each side (Retro shows one short username — Gap). */
const NAME_MAX_WIDTH = OG_WIDTH - 2 * num("size.global.screenMargin");

const xml = (s: string) => s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

function textSvg(content: string, face: "display" | "text", size: number, baseline: number, opacity: number): Buffer {
  const fill = colorHex("color.global.textOnMedia");
  return Buffer.from(
    `<svg xmlns="http://www.w3.org/2000/svg" width="${OG_WIDTH}" height="${OG_HEIGHT}">` +
      `<text x="${OG_WIDTH / 2}" y="${baseline}" text-anchor="middle" font-family="${FACES[face].family}" font-size="${size}" fill="${fill}" fill-opacity="${opacity}">${xml(content)}</text></svg>`,
  );
}

/** Ink box of a rendered text layer (null when nothing was drawn). */
async function inkBox(svg: Buffer): Promise<{ top: number; left: number; width: number; height: number } | null> {
  const { data, info } = await sharp(svg).ensureAlpha().extractChannel("alpha").raw().toBuffer({ resolveWithObject: true });
  let top = -1;
  let bottom = -1;
  let left = info.width;
  let right = -1;
  for (let y = 0; y < info.height; y++) {
    for (let x = 0; x < info.width; x++) {
      if (data[y * info.width + x]! > 0) {
        if (top < 0) top = y;
        bottom = y;
        if (x < left) left = x;
        if (x > right) right = x;
      }
    }
  }
  return top < 0 ? null : { top, left, width: right - left + 1, height: bottom - top + 1 };
}

/** The name at its measured baseline; shrunk only when it is wider than NAME_MAX_WIDTH. */
async function nameLayer(name: string): Promise<Buffer> {
  let svg = textSvg(name, "display", NAME_SIZE, NAME_BASELINE, 1);
  const box = await inkBox(svg);
  if (box && box.width > NAME_MAX_WIDTH) svg = textSvg(name, "display", (NAME_SIZE * NAME_MAX_WIDTH) / box.width, NAME_BASELINE, 1);
  return svg;
}

/** The domain with its ink top on DOMAIN_TOP_ROW (Retro's measured ink, independent of the domain's letters). */
async function domainLayer(domain: string): Promise<Buffer> {
  const probe = textSvg(domain, "text", DOMAIN_SIZE, OG_HEIGHT / 2, DOMAIN_ALPHA);
  const box = await inkBox(probe);
  return box ? textSvg(domain, "text", DOMAIN_SIZE, OG_HEIGHT / 2 + DOMAIN_TOP_ROW - box.top, DOMAIN_ALPHA) : probe;
}

export interface OgInput {
  /** Re-encoded cover, or null. */
  cover: Buffer | null;
  groupName: string;
  /** Invite-link host shown under the name, or null to leave the line out. */
  domain: string | null;
}

/** 600 × 600 share image: blurred cover field, cover in a circle, group name (serif), domain. */
export async function composeOgImage({ cover, groupName, domain }: OgInput): Promise<Buffer> {
  const [r, g, b] = rgba("color.global.backgroundDeep").rgb;
  let base: Buffer;
  let circle: Buffer;
  const mask = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${AVATAR}" height="${AVATAR}"><circle cx="${AVATAR / 2}" cy="${AVATAR / 2}" r="${AVATAR / 2}"/></svg>`);
  if (cover) {
    const field = await sharp(cover)
      .resize(BACKDROP_WIDTH, BACKDROP_WIDTH, { fit: "cover", position: "centre" })
      .blur(BACKDROP_BLUR_OF_WIDTH * BACKDROP_WIDTH)
      .toBuffer();
    base = await sharp(field).resize(OG_WIDTH, OG_HEIGHT, { fit: "fill", kernel: "cubic" }).toBuffer();
    circle = await sharp(cover).resize(AVATAR, AVATAR, { fit: "cover", position: "centre" }).composite([{ input: mask, blend: "dest-in" }]).png().toBuffer();
  } else {
    base = await sharp({ create: { width: OG_WIDTH, height: OG_HEIGHT, channels: 3, background: { r, g, b } } }).png().toBuffer();
    const [pr, pg, pb] = rgba("invite.web.color.avatarPlaceholder").rgb;
    circle = await sharp({ create: { width: AVATAR, height: AVATAR, channels: 4, background: { r: pr, g: pg, b: pb, alpha: 1 } } })
      .composite([{ input: mask, blend: "dest-in" }])
      .png()
      .toBuffer();
  }
  const layers: OverlayOptions[] = [
    { input: circle, left: Math.floor((OG_WIDTH - AVATAR) / 2), top: AVATAR_TOP },
    { input: await nameLayer(groupName), left: 0, top: 0 },
  ];
  if (domain) layers.push({ input: await domainLayer(domain), left: 0, top: 0 });
  return sharp(base).composite(layers).png().toBuffer();
}
