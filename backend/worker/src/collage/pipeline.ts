// From answer images to the collage files, using the existing compositor (layout.ts + render.ts):
//   master-<n>.png  one per page, transparent outer corners (render.ts renderPage)
//   display-<n>.jpg the page flattened on the matte color (render.ts toJpeg)
//   widget.jpg      page 1 at the widget rendition width (src/media/renditions.ts); for the tall
//                   options A and C only its top, as tall as the largest widget (the widget crops
//                   the top of a tall image, design/collage-options/README.md)
//   share-<n>.jpg   9:16 Stories image. Option B pages are 9:16 at the Stories canvas width, so
//                   they are the share images; options A and C need a share layout no reference
//                   shows (README "What the choice changes elsewhere"), so none is produced.

import sharp from "sharp";
import { layoutCollage, type Answer } from "./layout.js";
import { renderPage, toJpeg, type AnswerImages } from "./render.js";
import { collageParams } from "./params.js";
import { designToken } from "../tokens.js";
import { JPEG_OPTIONS, renditionSpecs } from "../media/renditions.js";

export type CollageOption = "A" | "B" | "C";

export function isCollageOption(v: unknown): v is CollageOption {
  return v === "A" || v === "B" || v === "C";
}

export interface CollageFiles {
  width: number;
  masters: Buffer[];
  displays: Buffer[];
  widget: Buffer;
  shares: Buffer[] | null;
}

/**
 * Collage width in px: the Stories canvas width (token dimension.collage.share.storyCanvas,
 * 1080 = Meta's 9:16 frame at 1080 wide, ≥ the 720×1280 minimum), so option B pages are the
 * share images without resampling.
 */
export function collageWidth(): number {
  return designToken<{ width: number; height: number }>("dimension.collage.share.storyCanvas").width;
}

export async function composeCollage(images: AnswerImages[], option: CollageOption, width = collageWidth()): Promise<CollageFiles> {
  if (!images.length) throw new Error("a collage needs at least one answer");
  const params = collageParams();
  const answers: Answer[] = images.map((im) => ({ hasFront: im.front !== null }));
  const pages = layoutCollage(answers, params.options[option], params.dual, width);
  const masters: Buffer[] = [];
  for (const page of pages) masters.push(await renderPage(page, images, params.colors));
  const displays: Buffer[] = [];
  for (const m of masters) displays.push(await toJpeg(m, params.colors.matte));

  const w = renditionSpecs().widget;
  const first = masters[0] as Buffer;
  let widget: Buffer;
  if (option === "B") {
    widget = await toJpeg(first, params.colors.matte, Math.min(w.width, width));
  } else {
    const scaled = await sharp(first).flatten({ background: params.colors.matte }).resize({ width: Math.min(w.width, width) }).png().toBuffer();
    const meta = await sharp(scaled).metadata();
    const top = Math.min(meta.height ?? w.height, w.height);
    widget = await sharp(scaled).extract({ left: 0, top: 0, width: meta.width ?? w.width, height: top }).jpeg(JPEG_OPTIONS).toBuffer();
  }

  let shares: Buffer[] | null = null;
  if (option === "B") {
    const canvas = designToken<{ width: number; height: number }>("dimension.collage.share.storyCanvas");
    const firstPage = pages[0];
    if (firstPage && firstPage.width === canvas.width && firstPage.height === canvas.height) shares = displays;
  }
  return { width, masters, displays, widget, shares };
}
