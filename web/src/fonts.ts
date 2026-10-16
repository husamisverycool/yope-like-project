// The faces the page serves (design.ts WEB_FONTS, web/assets/fonts): read once at start-up, served under
// /fonts/<file> with a year-long immutable cache. The stylesheet's URL carries a content hash (?v=), so a changed
// file is fetched afresh under the same name.

import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { WEB_FONTS, webFont, type TokenName } from "./design.js";

const FONT_DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "assets", "fonts");

const files = new Map<string, { body: Buffer; version: string }>();
for (const { file } of Object.values(WEB_FONTS)) {
  const body = fs.readFileSync(path.join(FONT_DIR, file));
  files.set(file, { body, version: createHash("sha256").update(body).digest("hex").slice(0, 12) });
}

/** A served font file by name (null for anything else). */
export const fontFile = (file: string): Buffer | null => files.get(file)?.body ?? null;

/** @font-face rule of a bundled font token at the given CSS weight. */
export function fontFace(name: TokenName, weight: number): string {
  const f = webFont(name);
  if (!f) throw new Error(`token ${name} is not a served face`);
  const { version } = files.get(f.file)!;
  return `@font-face{font-family:"${f.family}";src:url("/fonts/${f.file}?v=${version}") format("woff2");font-weight:${weight};font-style:normal;font-display:swap}`;
}
