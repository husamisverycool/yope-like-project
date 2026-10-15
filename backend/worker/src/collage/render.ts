// Renders a collage page layout to an image with sharp (libvips). Deterministic: identical inputs
// and sharp version give byte-identical output (asserted in test/collage.render.test.ts).

import sharp, { type OverlayOptions } from "sharp";
import type { PageLayout, Rect } from "./layout.js";

export interface AnswerImages {
  back: Buffer;
  front: Buffer | null;
}

function roundedRectMask(w: number, h: number, radius: number): Buffer {
  return Buffer.from(
    `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><rect x="0" y="0" width="${w}" height="${h}" rx="${radius}" ry="${radius}" fill="#fff"/></svg>`,
  );
}

async function cover(image: Buffer, w: number, h: number, radius: number): Promise<Buffer> {
  let img = sharp(image).rotate().resize(w, h, { fit: "cover", position: "centre" }).ensureAlpha();
  if (radius > 0) img = img.composite([{ input: roundedRectMask(w, h, radius), blend: "dest-in" }]);
  return img.png().toBuffer();
}

async function solid(w: number, h: number, hex: string, radius: number): Promise<Buffer> {
  return sharp(
    Buffer.from(
      `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><rect x="0" y="0" width="${w}" height="${h}" rx="${radius}" ry="${radius}" fill="${hex}"/></svg>`,
    ),
  )
    .png()
    .toBuffer();
}

function shrink(rect: Rect, by: number): Rect {
  return { x: rect.x + by, y: rect.y + by, w: rect.w - 2 * by, h: rect.h - 2 * by };
}

export interface RenderColors {
  /** token color.collage.matte */
  matte: string;
  /** token color.collage.insetBorder */
  insetBorder: string;
}

/** Renders one page to a PNG with transparent outer corners (master rendition). */
export async function renderPage(page: PageLayout, images: AnswerImages[], colors: RenderColors): Promise<Buffer> {
  const layers: OverlayOptions[] = [];
  for (const tile of page.tiles) {
    const img = images[tile.answer];
    if (!img) throw new Error(`missing images for answer ${tile.answer}`);
    layers.push({ input: await cover(img.back, tile.rect.w, tile.rect.h, tile.radius), left: tile.rect.x, top: tile.rect.y });
    if (tile.inset && img.front) {
      const { outer, border, outerRadius, innerRadius } = tile.inset;
      layers.push({ input: await solid(outer.w, outer.h, colors.insetBorder, outerRadius), left: outer.x, top: outer.y });
      const innerRect = shrink(outer, border);
      layers.push({ input: await cover(img.front, innerRect.w, innerRect.h, innerRadius), left: innerRect.x, top: innerRect.y });
    }
  }
  const base = sharp({ create: { width: page.width, height: page.height, channels: 4, background: colors.matte } }).composite(layers);
  let out = await base.png().toBuffer();
  if (page.outerRadius > 0) {
    out = await sharp(out)
      .composite([{ input: roundedRectMask(page.width, page.height, page.outerRadius), blend: "dest-in" }])
      .png()
      .toBuffer();
  }
  return out;
}

/** Flattens a master onto the matte color as JPEG (widget/display renditions). */
export async function toJpeg(master: Buffer, matte: string, width?: number, quality = 85): Promise<Buffer> {
  let img = sharp(master).flatten({ background: matte });
  if (width) img = img.resize({ width });
  return img.jpeg({ quality, mozjpeg: true }).toBuffer();
}
