import { describe, expect, it } from "vitest";
import sharp from "sharp";
import { layoutCollage } from "../src/collage/layout.js";
import { renderPage, toJpeg } from "../src/collage/render.js";
import { collageColors, dualTileParams } from "../src/collage/params.js";
import { reviewOptions } from "../scripts/collage-proposals.js";
import { sampleAnswers } from "./fixtures/answers.js";

const dual = dualTileParams();
const options = reviewOptions();
const colors = collageColors();

describe("collage rendering", () => {
  for (const [name, option] of Object.entries(options)) {
    it(`option ${name}: renders deterministically (byte-identical on re-render) at the layout size`, async () => {
      const images = await sampleAnswers(7, (i) => i === 4);
      const [page] = layoutCollage(images.map((im) => ({ hasFront: im.front !== null })), option, dual, 540);
      const a = await renderPage(page!, images, colors);
      const b = await renderPage(page!, images, colors);
      expect(Buffer.compare(a, b)).toBe(0);
      const meta = await sharp(a).metadata();
      expect([meta.width, meta.height]).toEqual([page!.width, page!.height]);
      const jpeg = await toJpeg(a, colors.matte, 270);
      expect((await sharp(jpeg).metadata()).width).toBe(270);
    }, 30_000);
  }

  it("draws the front inset with the black border at the top-left of a tile", async () => {
    const images = await sampleAnswers(3);
    const [page] = layoutCollage(images.map(() => ({ hasFront: true })), options.A!, dual, 600);
    const png = await renderPage(page!, images, colors);
    const t = page!.tiles[0]!;
    const { outer, border } = t.inset!;
    // middle of the left border edge of the inset must be the border color (#000000)
    const px = await sharp(png).extract({ left: outer.x + Math.floor(border / 2), top: outer.y + Math.floor(outer.h / 2), width: 1, height: 1 }).raw().toBuffer();
    expect([px[0], px[1], px[2]]).toEqual([0, 0, 0]);
  }, 30_000);
});
