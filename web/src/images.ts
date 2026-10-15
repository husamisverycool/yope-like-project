// Image processing for the invite page (sharp). Every output is re-encoded, which drops the
// source's EXIF/XMP/ICC metadata (camera, time, GPS) before anything reaches a non-member.
//
// Pixel sizes are the token sizes times device pixel ratio: the cover at the widest column
// (invite.web.dimension.columnMaxWidth − 2 × margin) at 2x, which also covers the 358-pt phone
// column at 3x; avatars at 3x. The link preview follows invite.web.layout.ogImage and
// invite.web.blur.ogImage.fill.

import sharp from "sharp";
import { hexRgb, layout, num, str } from "./design.js";
import type { Rgb } from "./theme.js";

const COLUMN = num("invite.web.dimension.columnMaxWidth") - 2 * num("invite.web.dimension.margin");
export const COVER_MAX_WIDTH = Math.round(COLUMN * 2);
export const AVATAR_PX = Math.round(num("invite.web.dimension.avatar") * 3);

interface OgLayout {
  width: number;
  height: number;
}
const OG = layout<OgLayout>("invite.web.layout.ogImage");
export const OG_WIDTH = OG.width;
export const OG_HEIGHT = OG.height;
const OG_SIGMA = num("invite.web.blur.ogImage.fill");
/** The fill is blurred at 1/8 scale with sigma/8 and scaled up: same result within 0.5/255 RMSE of
 *  the full-size blur on the reference (references/auto/partiful/og/pf-og-blur-fit.csv), ~50x faster. */
const OG_BLUR_SCALE = 8;

/** Flatten colour for transparent sources: the default theme colour. */
const flattenTo = (): { r: number; g: number; b: number } => {
  const [r, g, b] = hexRgb(str("invite.web.color.theme.default"));
  return { r, g, b };
};

/** Bounded decoding: refuse decompression bombs. */
const input = (buf: Buffer) => sharp(buf, { limitInputPixels: 64_000_000, failOn: "error" });

export interface ProcessedCover {
  jpeg: Buffer;
  width: number;
  height: number;
  /** Mean sRGB colour (the theme colour). */
  mean: Rgb;
}

export async function processCover(buf: Buffer): Promise<ProcessedCover> {
  const oriented = input(buf).rotate().flatten({ background: flattenTo() });
  const { data, info } = await oriented
    .clone()
    .resize({ width: COVER_MAX_WIDTH, withoutEnlargement: true })
    .jpeg({ mozjpeg: true })
    .toBuffer({ resolveWithObject: true });
  const stats = await sharp(data).stats();
  const mean = stats.channels.slice(0, 3).map((c) => c.mean) as Rgb;
  return { jpeg: data, width: info.width, height: info.height, mean };
}

export async function processAvatar(buf: Buffer): Promise<Buffer> {
  return input(buf)
    .rotate()
    .flatten({ background: flattenTo() })
    .resize(AVATAR_PX, AVATAR_PX, { fit: "cover", position: "centre" })
    .jpeg({ mozjpeg: true })
    .toBuffer();
}

/** 1200×630 link preview: the cover fitted inside, over a blurred cover filling the frame. */
export async function composeOgImage(coverJpeg: Buffer): Promise<Buffer> {
  const small = await sharp(coverJpeg)
    .resize(Math.round(OG_WIDTH / OG_BLUR_SCALE), Math.round(OG_HEIGHT / OG_BLUR_SCALE), { fit: "cover", position: "centre" })
    .blur(OG_SIGMA / OG_BLUR_SCALE)
    .toBuffer();
  const background = await sharp(small).resize(OG_WIDTH, OG_HEIGHT, { fit: "fill" }).toBuffer();
  const foreground = await sharp(coverJpeg).resize(OG_WIDTH, OG_HEIGHT, { fit: "inside" }).toBuffer();
  return sharp(background).composite([{ input: foreground, gravity: "centre" }]).jpeg({ mozjpeg: true }).toBuffer();
}
