// media.renditions {media_id}: renditions + location scrubbing + video transcode.
// Paths (docs/API.md §7): u/<owner>/<media_id>/r/… written with the service role.

import path from "node:path";
import { maybe, must, type Db } from "../db.js";
import {
  imageHasLocation,
  renderAll,
  renderRendition,
  renditionSpecs,
  scrubImage,
  scrubMovieLocation,
  transcodeVideo,
  videoPoster,
} from "../media/renditions.js";
import type { JobContext, Services } from "../services.js";
import { str } from "../services.js";
import { MEDIA_COLUMNS, type MediaRow } from "../types.js";

export function renditionPath(media: Pick<MediaRow, "owner_id" | "id">, file: string): string {
  return `u/${media.owner_id}/${media.id}/r/${file}`;
}

export async function loadMedia(db: Db, id: string): Promise<MediaRow | null> {
  return maybe(await db.from("media").select(MEDIA_COLUMNS).eq("id", id).maybeSingle(), "media") as MediaRow | null;
}

function imageReady(m: MediaRow): boolean {
  return !!m.display_path && !!m.thumb_path && !!m.widget_path && (!m.front_original_path || (!!m.front_display_path && !!m.front_thumb_path));
}

/** Upload paths written by this worker for a media row that was deleted meanwhile are removed again. */
async function cleanupIfGone(svc: Services, media: MediaRow, written: string[]): Promise<boolean> {
  if (await loadMedia(svc.db, media.id)) return false;
  await svc.storage.remove(written);
  svc.log.info("media deleted during rendition; removed written files", { media_id: media.id, files: written.length });
  return true;
}

/**
 * thumb / widget / display (+ front thumb / display) JPEGs, written once and reused. Fast
 * enough for the realtime lane (a video only needs its first frame here; the transcode runs in
 * media.renditions). Returns the updated row (or the input row when nothing was missing).
 */
export async function ensureImageRenditions(svc: Services, media: MediaRow, originalBytes?: Buffer): Promise<MediaRow> {
  if (imageReady(media)) return media;
  const written: string[] = [];
  const update: Partial<MediaRow> = {};
  if (!media.display_path || !media.thumb_path || !media.widget_path) {
    const source = originalBytes ?? (await svc.storage.download(media.original_path));
    const still = media.kind === "video" ? await videoPoster(source, media.original_path) : source;
    const r = await renderAll(still);
    for (const name of ["thumb", "widget", "display"] as const) {
      const p = renditionPath(media, `${name}.jpg`);
      await svc.storage.upload(p, r[name], "image/jpeg");
      written.push(p);
      update[`${name}_path`] = p;
    }
  }
  if (media.front_original_path && (!media.front_display_path || !media.front_thumb_path)) {
    const front = await svc.storage.download(media.front_original_path);
    const specs = renditionSpecs();
    const thumb = await renderRendition(front, specs.thumb);
    const display = await renderRendition(front, specs.display);
    const tp = renditionPath(media, "front_thumb.jpg");
    const dp = renditionPath(media, "front_display.jpg");
    await svc.storage.upload(tp, thumb, "image/jpeg");
    await svc.storage.upload(dp, display, "image/jpeg");
    written.push(tp, dp);
    update.front_thumb_path = tp;
    update.front_display_path = dp;
  }
  const rows = must(await svc.db.from("media").update(update).eq("id", media.id).select(MEDIA_COLUMNS), "media update") as MediaRow[];
  if (!rows.length) {
    await cleanupIfGone(svc, media, written);
    return { ...media, ...update };
  }
  return rows[0] as MediaRow;
}

/** Replaces an uploaded file by a scrubbed copy under r/ and deletes the upload. */
async function swapFile(
  svc: Services,
  media: MediaRow,
  column: "original_path" | "front_original_path" | "motion_path",
  newPath: string,
  data: Buffer,
  contentType: string,
): Promise<MediaRow | null> {
  const old = media[column];
  await svc.storage.upload(newPath, data, contentType);
  const rows = must(
    await svc.db.from("media").update({ [column]: newPath }).eq("id", media.id).eq(column, old as string).select(MEDIA_COLUMNS),
    "media update",
  ) as MediaRow[];
  if (!rows.length) {
    if (await cleanupIfGone(svc, media, [newPath])) return null;
    return loadMedia(svc.db, media.id);
  }
  if (old && old !== newPath) await svc.storage.remove([old]);
  return rows[0] as MediaRow;
}

export async function mediaRenditions(ctx: JobContext): Promise<void> {
  const id = str(ctx.job.payload, "media_id");
  let media = await loadMedia(ctx.db, id);
  if (!media) {
    ctx.log.info("media gone; nothing to do", { media_id: id });
    return;
  }
  if (media.renditions_ready_at) return;

  const original = await ctx.storage.download(media.original_path);
  media = await ensureImageRenditions(ctx, media, original);

  // No location ever: uploads with location metadata are replaced by scrubbed copies.
  if (media.kind !== "video" && !media.original_path.endsWith("/r/original.jpg") && (await imageHasLocation(original))) {
    const next = await swapFile(ctx, media, "original_path", renditionPath(media, "original.jpg"), await scrubImage(original), "image/jpeg");
    if (!next) return;
    media = next;
    ctx.log.info("original had location metadata; replaced by a scrubbed copy", { media_id: id });
  }
  if (media.front_original_path && !media.front_original_path.endsWith("/r/front.jpg")) {
    const front = await ctx.storage.download(media.front_original_path);
    if (await imageHasLocation(front)) {
      const next = await swapFile(ctx, media, "front_original_path", renditionPath(media, "front.jpg"), await scrubImage(front), "image/jpeg");
      if (!next) return;
      media = next;
    }
  }
  if (media.kind === "live_photo" && media.motion_path && !media.motion_path.endsWith("/r/motion.mov")) {
    // Live Photo: the paired movie is kept as uploaded (no transcode) unless it carries a location.
    const scrubbed = await scrubMovieLocation(await ctx.storage.download(media.motion_path));
    if (scrubbed) {
      const next = await swapFile(ctx, media, "motion_path", renditionPath(media, "motion.mov"), scrubbed.data, "video/quicktime");
      if (!next) return;
      media = next;
      ctx.log.info("live photo movie had location metadata; replaced by a scrubbed remux", { media_id: id, removed: scrubbed.removed });
    }
  }
  if (media.kind === "video" && !media.original_path.endsWith("/r/video.mp4")) {
    // Premium video: one H.264/AAC MP4 that plays on both platforms, without metadata, replaces the upload.
    const v = await transcodeVideo(original, path.basename(media.original_path));
    ctx.log.info("video transcoded", { media_id: id, cpu_seconds: v.cpuSeconds, bytes: v.mp4.length });
    const next = await swapFile(ctx, media, "original_path", renditionPath(media, "video.mp4"), v.mp4, "video/mp4");
    if (!next) return;
    media = next;
  }

  must(await ctx.db.from("media").update({ renditions_ready_at: ctx.now().toISOString() }).eq("id", id).is("renditions_ready_at", null), "media ready");
}
