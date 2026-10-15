// tribute.render / tribute.rerender {tribute_id, …}: renders the birthday video from the current
// contributions, uploads g/<group>/tributes/<tribute>/<version>/{tribute.mp4, poster.jpg}, then
// delivers it (delivered_at; the honoree can see it from then on) and queues push.tribute —
// only after rendering, and only the first time. No contribution left → the tribute is deleted
// (no empty tribute is ever delivered).

import { createHash } from "node:crypto";
import { maybe, must, selectIn } from "../db.js";
import { copyText } from "../copy.js";
import { loadGroup } from "../push/audience.js";
import { enqueue, str, type JobContext } from "../services.js";
import { renderTribute, tributeTokens, type TributeCardInput } from "../tribute/render.js";
import { firstName, MEDIA_COLUMNS, POST_COLUMNS, type ContributionRow, type MediaRow, type PostRow, type ProfileRow, type TributeRequestRow, type TributeRow } from "../types.js";
import { ensureImageRenditions } from "./media.js";

const TRIBUTE_COLUMNS = "id, request_id, group_id, honoree_id, video_path, poster_path, status, rendered_at, delivered_at";

export function tributeFolder(t: Pick<TributeRow, "group_id" | "id">): string {
  return `g/${t.group_id}/tributes/${t.id}`;
}

export async function tributeRender(ctx: JobContext): Promise<void> {
  const id = str(ctx.job.payload, "tribute_id");
  const t = maybe(await ctx.db.from("tributes").select(TRIBUTE_COLUMNS).eq("id", id).maybeSingle(), "tribute") as TributeRow | null;
  if (!t) return;
  const req = maybe(await ctx.db.from("tribute_requests").select("id, group_id, honoree_id, birthday_date, due_at, closed_at").eq("id", t.request_id).maybeSingle(), "request") as TributeRequestRow | null;
  const group = await loadGroup(ctx.db, t.group_id);
  if (!req || !group) return;

  const contributions = must(
    await ctx.db.from("tribute_contributions").select("id, request_id, contributor_id, post_id, line, created_at, updated_at").eq("request_id", t.request_id).order("created_at").order("id"),
    "contributions",
  ) as ContributionRow[];
  if (!contributions.length) {
    must(await ctx.db.from("tributes").delete().eq("id", t.id), "delete empty tribute");
    ctx.log.info("no contributions left; tribute deleted", { tribute_id: id });
    return;
  }

  // design values and texts first: a missing one fails the job before any rendering
  const tokens = tributeTokens();
  const honoree = maybe(await ctx.db.from("profiles").select("id, display_name, avatar_path").eq("id", t.honoree_id).maybeSingle(), "honoree") as ProfileRow | null;
  const texts = {
    title: copyText("birthday.tribute.titleCard", { name: firstName(honoree?.display_name) ?? "" }),
    end: copyText("birthday.tribute.endCard", { group: group.name }),
  };

  const version = createHash("sha256")
    .update(JSON.stringify({ c: contributions.map((c) => [c.id, c.post_id, c.line, c.updated_at]), tokens, texts }))
    .digest("hex")
    .slice(0, 16);
  const dir = `${tributeFolder(t)}/${version}`;
  if (t.status === "ready" && t.video_path === `${dir}/tribute.mp4`) {
    await deliver(ctx, t);
    return;
  }

  const posts = new Map((await selectIn<PostRow>(ctx.db, "posts", POST_COLUMNS, "id", contributions.map((c) => c.post_id))).map((p) => [p.id, p]));
  const media = new Map((await selectIn<MediaRow>(ctx.db, "media", MEDIA_COLUMNS, "id", [...posts.values()].map((p) => p.media_id))).map((m) => [m.id, m]));
  const people = new Map((await selectIn<ProfileRow>(ctx.db, "profiles", "id, display_name, avatar_path", "id", contributions.map((c) => c.contributor_id))).map((p) => [p.id, p]));
  const cards: TributeCardInput[] = [];
  for (const c of contributions) {
    const post = posts.get(c.post_id);
    const m = post ? media.get(post.media_id) : undefined;
    if (!m) continue;
    const ready = await ensureImageRenditions(ctx, m);
    cards.push({ image: await ctx.storage.download(ready.display_path as string), name: firstName(people.get(c.contributor_id)?.display_name) ?? "", line: c.line.trim() });
  }
  if (!cards.length) return;

  const video = await renderTribute(cards, texts, tokens, ctx.config.fontsDir);
  ctx.log.info("tribute rendered", { tribute_id: id, cards: cards.length, duration_ms: video.durationMs, ffmpeg_cpu_seconds: video.cpuSeconds, ffmpeg_wall_ms: video.wallMs, bytes: video.mp4.length });
  await ctx.storage.upload(`${dir}/tribute.mp4`, video.mp4, "video/mp4");
  await ctx.storage.upload(`${dir}/poster.jpg`, video.poster, "image/jpeg");

  const updated = must(
    await ctx.db
      .from("tributes")
      .update({ video_path: `${dir}/tribute.mp4`, poster_path: `${dir}/poster.jpg`, status: "ready", rendered_at: ctx.now().toISOString() })
      .eq("id", t.id)
      .select(TRIBUTE_COLUMNS),
    "tribute update",
  ) as TributeRow[];
  if (!updated.length) {
    await ctx.storage.remove([`${dir}/tribute.mp4`, `${dir}/poster.jpg`]);
    return;
  }
  const stale = (await ctx.storage.listAll(tributeFolder(t))).filter((p) => !p.startsWith(`${dir}/`));
  if (stale.length) await ctx.storage.remove(stale);
  await deliver(ctx, updated[0] as TributeRow, req);
}

/** Delivery = delivered_at (the honoree's read access) + the push, once, after rendering, at/after due_at. */
async function deliver(ctx: JobContext, t: TributeRow, req?: TributeRequestRow): Promise<void> {
  if (t.delivered_at) {
    // a run that set delivered_at but stopped before queueing the push: queue it now
    const queued = must(await ctx.db.from("jobs").select("id").eq("dedupe_key", `push.tribute:${t.id}`).limit(1), "jobs") as unknown[];
    if (!queued.length) await enqueue(ctx.db, "push.tribute", { tribute_id: t.id, group_id: t.group_id }, { dedupeKey: `push.tribute:${t.id}` });
    return;
  }
  if (req && new Date(req.due_at) > ctx.now()) return; // not due yet (a re-render before the birthday)
  const rows = must(
    await ctx.db.from("tributes").update({ delivered_at: ctx.now().toISOString() }).eq("id", t.id).is("delivered_at", null).eq("status", "ready").select("id"),
    "deliver",
  ) as Array<{ id: string }>;
  if (!rows.length) return;
  await enqueue(ctx.db, "push.tribute", { tribute_id: t.id, group_id: t.group_id }, { dedupeKey: `push.tribute:${t.id}` });
  ctx.log.info("tribute delivered", { tribute_id: t.id });
}
