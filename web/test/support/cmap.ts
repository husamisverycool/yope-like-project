// Reads the character map of a TrueType / OpenType font file (cmap formats 4 and 12), so tests can check which
// font in fonts/ and fonts/fallback/ covers a code point without depending on fontconfig.
import fs from "node:fs";

/** Every code point the font maps to a glyph other than .notdef. */
export function cmapCodePoints(file: string): Set<number> {
  const b = fs.readFileSync(file);
  const numTables = b.readUInt16BE(4);
  let cmap = -1;
  for (let i = 0; i < numTables; i++) {
    const rec = 12 + 16 * i;
    if (b.toString("latin1", rec, rec + 4) === "cmap") cmap = b.readUInt32BE(rec + 8);
  }
  if (cmap < 0) throw new Error(`${file}: no cmap table`);
  const subtables: Array<{ platform: number; encoding: number; offset: number }> = [];
  for (let i = 0; i < b.readUInt16BE(cmap + 2); i++) {
    const r = cmap + 4 + 8 * i;
    subtables.push({ platform: b.readUInt16BE(r), encoding: b.readUInt16BE(r + 2), offset: cmap + b.readUInt32BE(r + 4) });
  }
  const pick =
    subtables.find((t) => t.platform === 3 && t.encoding === 10) ??
    subtables.find((t) => t.platform === 0 && (t.encoding === 4 || t.encoding === 6)) ??
    subtables.find((t) => t.platform === 3 && t.encoding === 1) ??
    subtables.find((t) => t.platform === 0);
  if (!pick) throw new Error(`${file}: no Unicode cmap`);
  const out = new Set<number>();
  const o = pick.offset;
  const format = b.readUInt16BE(o);
  if (format === 12) {
    const groups = b.readUInt32BE(o + 12);
    for (let g = 0; g < groups; g++) {
      const r = o + 16 + 12 * g;
      const start = b.readUInt32BE(r);
      const end = b.readUInt32BE(r + 4);
      const glyph = b.readUInt32BE(r + 8);
      for (let c = start; c <= end; c++) if (glyph + (c - start) !== 0) out.add(c);
    }
  } else if (format === 4) {
    const segX2 = b.readUInt16BE(o + 6);
    const ends = o + 14;
    const starts = ends + segX2 + 2;
    const deltas = starts + segX2;
    const ranges = deltas + segX2;
    for (let s = 0; s < segX2 / 2; s++) {
      const end = b.readUInt16BE(ends + 2 * s);
      const start = b.readUInt16BE(starts + 2 * s);
      const delta = b.readInt16BE(deltas + 2 * s);
      const rangeOffset = b.readUInt16BE(ranges + 2 * s);
      for (let c = start; c <= end && c !== 0xffff; c++) {
        let glyph: number;
        if (rangeOffset === 0) glyph = (c + delta) & 0xffff;
        else {
          const at = ranges + 2 * s + rangeOffset + 2 * (c - start);
          glyph = b.readUInt16BE(at);
          if (glyph !== 0) glyph = (glyph + delta) & 0xffff;
        }
        if (glyph !== 0) out.add(c);
      }
    }
  } else {
    throw new Error(`${file}: cmap format ${format} not read`);
  }
  return out;
}
