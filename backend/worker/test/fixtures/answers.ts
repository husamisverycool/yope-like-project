// Deterministic sample answers built from the CC0 / public-domain fixture photos (LICENSES.md):
// each answer gets a different crop of a different photo for its back and front images.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";
import type { AnswerImages } from "../../src/collage/render.js";

const dir = path.dirname(fileURLToPath(import.meta.url));
const files = ["chelsea.png", "coffee.png", "camera.png", "rocket.jpg", "hubble_deep_field.jpg"];

async function variant(file: string, i: number): Promise<Buffer> {
  const img = sharp(fs.readFileSync(path.join(dir, file)));
  const { width = 0, height = 0 } = await img.metadata();
  const w = Math.round(width * (0.55 + ((i * 7) % 5) * 0.08));
  const h = Math.min(height, Math.round(w * (4 / 3)));
  const left = Math.round(((width - w) * ((i * 37) % 100)) / 100);
  const top = Math.round(((height - h) * ((i * 53) % 100)) / 100);
  let out = sharp(fs.readFileSync(path.join(dir, file))).extract({ left, top, width: w, height: h });
  if (i % 2) out = out.flop();
  return out.jpeg({ quality: 90 }).toBuffer();
}

export async function sampleAnswers(n: number, withoutFront: (i: number) => boolean = () => false): Promise<AnswerImages[]> {
  const out: AnswerImages[] = [];
  for (let i = 0; i < n; i++) {
    out.push({
      back: await variant(files[i % files.length]!, i),
      front: withoutFront(i) ? null : await variant(files[(i + 2) % files.length]!, i + 11),
    });
  }
  return out;
}
