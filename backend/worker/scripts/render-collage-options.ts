// Renders the same-moment collage options for the owner (directive Part 3: show 2–3 options,
// each composed strictly from BeReal's dual image + Yope's walls, every value traced).
// Output: design/collage-options/option-{A,B,C}.jpg. Photos are CC0 / public-domain
// fixtures. The captions on these sheets are for the owner's review only; they are not app UI.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import sharp, { type OverlayOptions } from "sharp";
import { layoutCollage } from "../src/collage/layout.js";
import { renderPage } from "../src/collage/render.js";
import { collageParams } from "../src/collage/params.js";
import { sampleAnswers } from "../test/fixtures/answers.js";

const OUT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../../design/collage-options");
fs.mkdirSync(OUT, { recursive: true });
const { dual, options, colors } = collageParams();
const COUNTS = [1, 2, 3, 5, 8, 12, 20, 30];
const WIDTH = 360;
const CAPTION = 44;
const PAD = 24;

function caption(text: string, w: number): Buffer {
  return Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${CAPTION}"><rect width="100%" height="100%" fill="#ffffff"/><text x="0" y="30" font-family="Roboto, sans-serif" font-size="22" fill="#111111">${text}</text></svg>`);
}

const images = await sampleAnswers(30, (i) => i % 9 === 8); // every 9th answer has no front photo (single-camera fallback)
for (const [name, option] of Object.entries(options)) {
  const cells: { buf: Buffer; w: number; h: number }[] = [];
  for (const n of COUNTS) {
    const pages = layoutCollage(images.slice(0, n).map((im) => ({ hasFront: im.front !== null })), option, dual, WIDTH);
    const renders = await Promise.all(pages.map((p) => renderPage(p, images, colors)));
    const w = pages.length * WIDTH + (pages.length - 1) * 12;
    const h = Math.max(...pages.map((p) => p.height));
    const layers: OverlayOptions[] = [{ input: caption(`${n} ${n === 1 ? "person" : "people"}${pages.length > 1 ? ` · ${pages.length} pages` : ""}`, w), left: 0, top: 0 }];
    renders.forEach((r, i) => layers.push({ input: r, left: i * (WIDTH + 12), top: CAPTION }));
    const cell = await sharp({ create: { width: w, height: h + CAPTION, channels: 4, background: "#ffffff" } }).composite(layers).png().toBuffer();
    cells.push({ buf: cell, w, h: h + CAPTION });
  }
  // sheet: cells in rows, wrapping at ~2200 px
  const rows: (typeof cells)[] = [[]];
  let rowW = 0;
  for (const c of cells) {
    if (rowW + c.w > 2200 && rows[rows.length - 1]!.length) { rows.push([]); rowW = 0; }
    rows[rows.length - 1]!.push(c);
    rowW += c.w + PAD;
  }
  const sheetW = Math.max(...rows.map((r) => r.reduce((a, c) => a + c.w + PAD, PAD)));
  const sheetH = rows.reduce((a, r) => a + Math.max(...r.map((c) => c.h)) + PAD, PAD);
  const layers: OverlayOptions[] = [];
  let y = PAD;
  for (const r of rows) {
    let x = PAD;
    for (const c of r) { layers.push({ input: c.buf, left: x, top: y }); x += c.w + PAD; }
    y += Math.max(...r.map((c) => c.h)) + PAD;
  }
  await sharp({ create: { width: sheetW, height: sheetH, channels: 4, background: "#ffffff" } }).composite(layers).flatten({ background: "#ffffff" }).jpeg({ quality: 82, mozjpeg: true }).toFile(path.join(OUT, `option-${name}.jpg`));
  console.log(`option ${name}: ${sheetW}×${sheetH}`);
}
