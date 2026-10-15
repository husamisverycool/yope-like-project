// collage.compose {invitation_id, group_id} at closes_at and collage.recompose {collage_id, group_id}
// after a deletion. Only on-time answers (posts.in_window) are composed; one tile per member (their
// first on-time post: docs/API.md §12.15 leaves this to the worker). Files:
//   g/<group>/collages/<collage>/<version>/{master-<n>.png, display-<n>.jpg, share-<n>.jpg, widget.jpg}
// where <version> hashes the option, width and posts, so a recompose writes new names.

import { createHash } from "node:crypto";
import { DbError, maybe, must, selectIn, type Db } from "../db.js";
import { PermanentError } from "../errors.js";
import { orderAnswers } from "../collage/layout.js";
import type { AnswerImages } from "../collage/render.js";
import { collageWidth, composeCollage, isCollageOption, type CollageOption } from "../collage/pipeline.js";
import { enqueue, str, type JobContext, type Services } from "../services.js";
import { MEDIA_COLUMNS, POST_COLUMNS, type CollageRow, type InvitationRow, type MediaRow, type PostRow } from "../types.js";
import { ensureImageRenditions } from "./media.js";

/**
 * create_post decides in_window with its transaction's now(); a transaction that started just
 * before closes_at can commit just after it. The collage waits this long past closes_at.
 */
export const COMMIT_ALLOWANCE_MS = 2000;

const COLLAGE_COLUMNS = "id, group_id, invitation_id, option, post_ids, image_path, widget_path, share_path, status, composed_at, created_at";

export async function configValue<T>(db: Db, key: string): Promise<T | null> {
  const row = maybe(await db.from("app_config").select("value").eq("key", key).maybeSingle(), "app_config") as { value: T | null } | null;
  return row?.value ?? null;
}

export async function collageOptionFromConfig(db: Db): Promise<CollageOption> {
  const v = await configValue<string>(db, "collage_option");
  if (!isCollageOption(v)) throw new PermanentError(`app_config.collage_option must be "A", "B" or "C" (is ${JSON.stringify(v)})`);
  return v;
}

export function collageVersion(option: string, width: number, postIds: string[]): string {
  return createHash("sha256").update(`${option}|${width}|${postIds.join(",")}`).digest("hex").slice(0, 16);
}

export function collageFolder(groupId: string, collageId: string): string {
  return `g/${groupId}/collages/${collageId}`;
}

interface Answer {
  post: PostRow;
  media: MediaRow;
  capturedAt: string;
  userId: string;
}

async function answersFor(svc: Services, posts: PostRow[]): Promise<Answer[]> {
  const media = await selectIn<MediaRow>(svc.db, "media", MEDIA_COLUMNS, "id", posts.map((p) => p.media_id));
  const byId = new Map(media.map((m) => [m.id, m]));
  const out: Answer[] = [];
  for (const post of posts) {
    const m = byId.get(post.media_id);
    if (m) out.push({ post, media: m, capturedAt: post.created_at, userId: post.author_id });
  }
  return orderAnswers(out);
}

/** Display renditions (deterministic from the originals) are the tile sources. */
async function imagesFor(svc: Services, answers: Answer[]): Promise<AnswerImages[]> {
  const out: AnswerImages[] = [];
  for (const a of answers) {
    const m = await ensureImageRenditions(svc, a.media);
    out.push({
      back: await svc.storage.download(m.display_path as string),
      front: m.front_display_path ? await svc.storage.download(m.front_display_path) : null,
    });
  }
  return out;
}

/** Composes, uploads, and points the row at the new files if its post set is still `postIds`. */
async function render(ctx: JobContext, collage: CollageRow, option: CollageOption, answers: Answer[]): Promise<boolean> {
  const postIds = answers.map((a) => a.post.id);
  const width = collageWidth();
  const version = collageVersion(option, width, postIds);
  const dir = `${collageFolder(collage.group_id, collage.id)}/${version}`;
  const files = await composeCollage(await imagesFor(ctx, answers), option, width);
  const written: string[] = [];
  const put = async (name: string, data: Buffer, type: string) => {
    await ctx.storage.upload(`${dir}/${name}`, data, type);
    written.push(`${dir}/${name}`);
  };
  for (const [i, b] of files.masters.entries()) await put(`master-${i + 1}.png`, b, "image/png");
  for (const [i, b] of files.displays.entries()) await put(`display-${i + 1}.jpg`, b, "image/jpeg");
  if (files.shares) for (const [i, b] of files.shares.entries()) await put(`share-${i + 1}.jpg`, b, "image/jpeg");
  await put("widget.jpg", files.widget, "image/jpeg");
  if (!files.shares) ctx.log.warn("no 9:16 share image for this collage option (owner decision pending, design/collage-options/README.md)", { option });

  const updated = must(
    await ctx.db
      .from("collages")
      .update({
        option,
        post_ids: postIds,
        image_path: `${dir}/display-1.jpg`,
        widget_path: `${dir}/widget.jpg`,
        share_path: files.shares ? `${dir}/share-1.jpg` : null,
        status: "ready",
        composed_at: ctx.now().toISOString(),
      })
      .eq("id", collage.id)
      .eq("post_ids", `{${collage.post_ids.join(",")}}`)
      .select("id"),
    "collage update",
  ) as Array<{ id: string }>;
  if (!updated.length) {
    // deleted, or its posts changed while composing: a newer collage.recompose does the work
    await ctx.storage.remove(written);
    ctx.log.info("collage changed while composing; discarded this version", { collage_id: collage.id });
    return false;
  }
  // older versions of this collage (the deletion trigger removes only the three stored paths)
  const stale = (await ctx.storage.listAll(collageFolder(collage.group_id, collage.id))).filter((p) => !p.startsWith(`${dir}/`));
  if (stale.length) await ctx.storage.remove(stale);
  ctx.log.info("collage composed", { collage_id: collage.id, option, answers: answers.length, pages: files.masters.length, version });
  return true;
}

async function refreshWidgets(db: Db, groupId: string): Promise<void> {
  await enqueue(db, "widget.refresh", { group_id: groupId }, { dedupeKey: `widget.refresh:${groupId}` });
}

export async function collageCompose(ctx: JobContext): Promise<void> {
  const invitationId = str(ctx.job.payload, "invitation_id");
  const inv = maybe(await ctx.db.from("daily_invitations").select("id, group_id, local_date, fires_at, closes_at, status").eq("id", invitationId).maybeSingle(), "invitation") as InvitationRow | null;
  if (!inv) {
    ctx.log.info("invitation gone; nothing to compose", { invitation_id: invitationId });
    return;
  }
  const wait = new Date(inv.closes_at).getTime() + COMMIT_ALLOWANCE_MS - ctx.now().getTime();
  if (wait > 60_000) {
    // run early (e.g. re-enqueued by hand): the window is still open, come back at closes_at
    await enqueue(ctx.db, "collage.compose", { invitation_id: inv.id, group_id: inv.group_id }, { runAt: new Date(inv.closes_at), dedupeKey: `collage.compose:${inv.id}` });
    return;
  }
  if (wait > 0) await new Promise((r) => setTimeout(r, wait));

  const closeInvitation = async () => {
    must(await ctx.db.from("daily_invitations").update({ status: "closed" }).eq("id", inv.id).in("status", ["scheduled", "fired"]), "close invitation");
  };

  let collage = maybe(await ctx.db.from("collages").select(COLLAGE_COLUMNS).eq("invitation_id", inv.id).maybeSingle(), "collage") as CollageRow | null;
  if (collage?.status === "ready") {
    await closeInvitation();
    return; // composed by an earlier run
  }

  let answers: Answer[];
  let option: CollageOption;
  if (collage) {
    // an earlier run created the row; compose what it recorded
    option = isCollageOption(collage.option) ? collage.option : await collageOptionFromConfig(ctx.db);
    const posts = await selectIn<PostRow>(ctx.db, "posts", POST_COLUMNS, "id", collage.post_ids);
    answers = await answersFor(ctx, posts);
  } else {
    const inWindow = must(
      await ctx.db.from("posts").select(POST_COLUMNS).eq("invitation_id", inv.id).eq("group_id", inv.group_id).eq("in_window", true).order("created_at").order("id"),
      "in-window posts",
    ) as PostRow[];
    const firstPerMember = new Map<string, PostRow>();
    for (const p of inWindow) if (!firstPerMember.has(p.author_id)) firstPerMember.set(p.author_id, p);
    answers = await answersFor(ctx, [...firstPerMember.values()]);
    if (!answers.length) {
      await closeInvitation();
      ctx.log.info("no on-time answers; no collage", { invitation_id: inv.id });
      return;
    }
    option = await collageOptionFromConfig(ctx.db);
    const ins = await ctx.db
      .from("collages")
      .insert({ group_id: inv.group_id, invitation_id: inv.id, option, post_ids: answers.map((a) => a.post.id), status: "pending" })
      .select(COLLAGE_COLUMNS)
      .maybeSingle();
    if (ins.error?.code === "23505") {
      collage = maybe(await ctx.db.from("collages").select(COLLAGE_COLUMNS).eq("invitation_id", inv.id).maybeSingle(), "collage") as CollageRow | null;
      if (!collage || collage.status === "ready") return;
    } else if (ins.error) {
      if (ins.error.code === "23503") return; // group or invitation deleted meanwhile
      throw new DbError(`insert collage: ${ins.error.message}`, ins.error.code);
    } else {
      collage = ins.data as CollageRow;
    }
  }
  if (!answers.length) {
    must(await ctx.db.from("collages").delete().eq("id", collage!.id), "delete empty collage");
    await closeInvitation();
    return;
  }
  if (await render(ctx, collage!, option, answers)) {
    await closeInvitation();
    await refreshWidgets(ctx.db, inv.group_id);
  }
}

export async function collageRecompose(ctx: JobContext): Promise<void> {
  const id = str(ctx.job.payload, "collage_id");
  const collage = maybe(await ctx.db.from("collages").select(COLLAGE_COLUMNS).eq("id", id).maybeSingle(), "collage") as CollageRow | null;
  if (!collage) {
    ctx.log.info("collage gone; nothing to recompose", { collage_id: id });
    return;
  }
  if (collage.status === "ready" && collage.image_path) return; // already recomposed
  const posts = await selectIn<PostRow>(ctx.db, "posts", POST_COLUMNS, "id", collage.post_ids);
  const answers = await answersFor(ctx, posts.filter((p) => p.in_window));
  if (!answers.length) {
    // zero answers left: the collage and (through the delete triggers) its objects go
    must(await ctx.db.from("collages").delete().eq("id", collage.id), "delete collage");
    ctx.log.info("collage has no answers left; deleted", { collage_id: id });
    await refreshWidgets(ctx.db, collage.group_id);
    return;
  }
  const option = isCollageOption(collage.option) ? collage.option : await collageOptionFromConfig(ctx.db);
  if (await render(ctx, collage, option, answers)) await refreshWidgets(ctx.db, collage.group_id);
}
