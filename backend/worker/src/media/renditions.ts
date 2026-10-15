// Media renditions (job media.renditions): thumb / widget / display JPEGs of the main image (or
// the video poster) and of the front image of a dual capture; H.264/AAC MP4 for videos; location
// scrubbing of uploaded originals. Every file the worker writes carries no metadata at all (sharp
// writes none unless asked; ffmpeg runs with -map_metadata -1), and no uploaded file keeps a
// location after this job: originals with GPS EXIF / XMP and Live Photo movies with QuickTime
// location keys are replaced by scrubbed copies under r/.

import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import sharp from "sharp";
import { hasToken, designToken } from "../tokens.js";
import { ffmpeg, locationTags, probe } from "./ffmpeg.js";

export type RenditionName = "thumb" | "widget" | "display";

export interface RenditionSpec {
  width: number;
  height: number;
  /** "outside": both sides cover the box (cropped by the client to its frame); "inside": fits within it */
  fit: "outside" | "inside";
}

/**
 * Sizes in pixels. Read from the design token `layout.media.renditions`
 * ({thumb|widget|display: {width, height, fit}}) when it exists. Until then they are derived from
 * the iOS widget sizes in docs/PLATFORM_CONSTRAINTS.md §1 / design/proposals/platform.tokens.json
 * (`layout.widget.home.*.size.ios`, Apple HIG "iOS dimensions" table, VERIFIED) at the @3x scale
 * of the screens in that table:
 *  - widget:  the largest iPhone widget, systemLarge 364×382 pt on the 430×932-pt screen class,
 *             × 3 = 1092×1146 px. The photo fills the widget (Locket's photo fill), so both sides
 *             must cover that box: fit "outside". This also covers systemSmall (170×170 pt →
 *             510×510 px) and systemMedium (364×170 pt → 1092×510 px).
 *  - thumb:   the smallest home-screen widget, systemSmall 170×170 pt × 3 = 510×510 px, same rule
 *             (grid cells in the apps are smaller than a small widget).
 *  - display: the largest screen class in the table, 430×932 pt × 3 = 1290×2796 px; full screen
 *             shows the whole photo, so it fits inside: fit "inside".
 * Never enlarged (withoutEnlargement).
 * Android: the HIG figures are the only pixel sizes the constraints doc gives; a 4×3 Glance
 * widget is at most 624×422 dp (Android sizing table), i.e. ≤ 1092 px wide below 1.75× density.
 */
export const DERIVED_RENDITIONS: Record<RenditionName, RenditionSpec> = {
  widget: { width: 364 * 3, height: 382 * 3, fit: "outside" },
  thumb: { width: 170 * 3, height: 170 * 3, fit: "outside" },
  display: { width: 430 * 3, height: 932 * 3, fit: "inside" },
};

export function renditionSpecs(): Record<RenditionName, RenditionSpec> {
  if (hasToken("layout.media.renditions")) return designToken<Record<RenditionName, RenditionSpec>>("layout.media.renditions");
  return DERIVED_RENDITIONS;
}

/** Same encoder settings as the collage renderer (src/collage/render.ts toJpeg). */
export const JPEG_OPTIONS = { quality: 85, mozjpeg: true } as const;

export async function renderRendition(input: Buffer, spec: RenditionSpec): Promise<Buffer> {
  return sharp(input, { failOn: "error" })
    .rotate() // apply EXIF orientation, so the output needs no metadata
    .resize({ width: spec.width, height: spec.height, fit: spec.fit, withoutEnlargement: true })
    .jpeg(JPEG_OPTIONS)
    .toBuffer();
}

export async function renderAll(input: Buffer, names: RenditionName[] = ["thumb", "widget", "display"]): Promise<Record<RenditionName, Buffer>> {
  const specs = renditionSpecs();
  const out = {} as Record<RenditionName, Buffer>;
  for (const n of names) out[n] = await renderRendition(input, specs[n]);
  return out;
}

// ---------------------------------------------------------------------------
// Location detection / scrubbing
// ---------------------------------------------------------------------------

/** Whether a raw Exif block (as sharp returns it: "Exif\0\0" + TIFF) has a GPS IFD pointer (tag 0x8825). */
export function exifHasGps(exif: Buffer | undefined): boolean {
  if (!exif || exif.length < 14) return false;
  let base = 0;
  if (exif.subarray(0, 6).toString("latin1") === "Exif\0\0") base = 6;
  const order = exif.subarray(base, base + 2).toString("latin1");
  const le = order === "II";
  if (!le && order !== "MM") return false;
  const u16 = (o: number) => (le ? exif.readUInt16LE(o) : exif.readUInt16BE(o));
  const u32 = (o: number) => (le ? exif.readUInt32LE(o) : exif.readUInt32BE(o));
  try {
    const ifd0 = base + u32(base + 4);
    const count = u16(ifd0);
    for (let i = 0; i < count; i++) {
      const tag = u16(ifd0 + 2 + i * 12);
      if (tag === 0x8825) return true;
    }
  } catch {
    return false;
  }
  return false;
}

export function xmpHasGps(xmp: Buffer | undefined): boolean {
  return !!xmp && /GPS(Latitude|Longitude|Altitude)|exif:GPS/i.test(xmp.toString("utf8"));
}

export async function imageHasLocation(input: Buffer): Promise<boolean> {
  const meta = await sharp(input).metadata();
  return exifHasGps(meta.exif) || xmpHasGps(meta.xmp);
}

/** Full-resolution copy without any metadata (orientation applied). */
export async function scrubImage(input: Buffer): Promise<Buffer> {
  return sharp(input, { failOn: "error" }).rotate().jpeg(JPEG_OPTIONS).toBuffer();
}

async function withTemp<T>(fn: (dir: string) => Promise<T>): Promise<T> {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "worker-media-"));
  try {
    return await fn(dir);
  } finally {
    await fs.rm(dir, { recursive: true, force: true });
  }
}

export interface VideoOutputs {
  mp4: Buffer;
  poster: Buffer;
  cpuSeconds: number;
}

/**
 * Premium video: H.264 (yuv420p, High profile) + AAC in MP4 with the index up front
 * (+faststart), no metadata; libx264 / AAC at ffmpeg's default quality settings. The poster is
 * the first frame, as PNG (lossless input for the JPEG renditions).
 */
export async function transcodeVideo(input: Buffer, inputName: string): Promise<VideoOutputs> {
  return withTemp(async (dir) => {
    const src = path.join(dir, `in${path.extname(inputName) || ".mov"}`);
    await fs.writeFile(src, input);
    const out = path.join(dir, "out.mp4");
    const posterFile = path.join(dir, "poster.png");
    const a = await ffmpeg([
      "-y", "-i", src,
      "-map", "0:v:0", "-map", "0:a:0?",
      "-c:v", "libx264", "-pix_fmt", "yuv420p", "-profile:v", "high",
      "-c:a", "aac",
      "-map_metadata", "-1", "-map_chapters", "-1",
      "-movflags", "+faststart",
      out,
    ]);
    const b = await ffmpeg(["-y", "-i", out, "-frames:v", "1", "-map_metadata", "-1", posterFile]);
    return { mp4: await fs.readFile(out), poster: await fs.readFile(posterFile), cpuSeconds: a.cpuSeconds + b.cpuSeconds };
  });
}

/** Poster (first frame, PNG) of a video without transcoding it. */
export async function videoPoster(input: Buffer, inputName: string): Promise<Buffer> {
  return withTemp(async (dir) => {
    const src = path.join(dir, `in${path.extname(inputName) || ".mov"}`);
    await fs.writeFile(src, input);
    const posterFile = path.join(dir, "poster.png");
    await ffmpeg(["-y", "-i", src, "-frames:v", "1", "-map_metadata", "-1", posterFile]);
    return fs.readFile(posterFile);
  });
}

/**
 * Live Photo movie: kept as uploaded (same streams, no re-encode) so it still pairs with its
 * still. If it carries a location key, a remux without the location keys is returned; other
 * metadata (e.g. com.apple.quicktime.content.identifier, which pairs the movie with the still)
 * and every stream are kept. Returns null when there is nothing to remove.
 */
export async function scrubMovieLocation(input: Buffer): Promise<{ data: Buffer; removed: string[] } | null> {
  return withTemp(async (dir) => {
    const src = path.join(dir, "in.mov");
    await fs.writeFile(src, input);
    const keys = locationTags(await probe(src));
    if (!keys.length) return null;
    const out = path.join(dir, "out.mov");
    const clear = keys.flatMap((k) => ["-metadata", `${k}=`]);
    try {
      await ffmpeg(["-y", "-i", src, "-map", "0", "-c", "copy", "-copy_unknown", "-map_metadata", "0", ...clear, "-movflags", "use_metadata_tags", out]);
    } catch {
      // streams ffmpeg cannot copy (e.g. timed metadata tracks): keep video + audio only
      await ffmpeg(["-y", "-i", src, "-map", "0:v", "-map", "0:a?", "-c", "copy", "-map_metadata", "0", ...clear, "-movflags", "use_metadata_tags", out]);
    }
    const remaining = locationTags(await probe(out));
    if (remaining.length) {
      // last resort: drop all container metadata
      await ffmpeg(["-y", "-i", src, "-map", "0:v", "-map", "0:a?", "-c", "copy", "-map_metadata", "-1", out]);
    }
    return { data: await fs.readFile(out), removed: keys };
  });
}
