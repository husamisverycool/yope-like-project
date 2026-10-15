// widget.refresh {group_id}: brings every member's widget for the group up to date
// (docs/WIDGET_REFRESH.md). Per member, the newest item they may see — the newest post whose
// author has no block with them, or the group's newest ready collage if it is newer — and per
// device:
//   iOS with a WidgetKit push token (iOS 26+): `widgets` push, ≤ 1 per device per 5 minutes;
//   iOS otherwise: background push with the widget fields, ≤ 2 per device per hour, unless the
//     device already has this item (the new-post alert carried it to the Notification Service
//     Extension);
//   Android: normal-priority data message with the widget fields, unless already delivered.
// Throttled devices get a follow-up widget.refresh when their window reopens. Nothing is sent
// for a member when there is no change to show.

import { must, selectIn, type Db } from "../db.js";
import { blockedPairs } from "./util.js";
import { loadAudience } from "../push/audience.js";
import { apnsWidgetBackground, apnsWidgetKit, fcmWidget, type WidgetFields } from "../push/payloads.js";
import type { DeviceSend } from "../push/service.js";
import { enqueue, str, type JobContext, type Services } from "../services.js";
import { MEDIA_COLUMNS, POST_COLUMNS, type CollageRow, type MediaRow, type PostRow, type ProfileRow } from "../types.js";
import { ensureImageRenditions } from "./media.js";

/** Newest posts looked at per refresh: enough to find one not hidden by a block for every member (30 max). */
const RECENT_POSTS = 64;

export interface WidgetItem {
  key: string;
  at: string;
  fields: WidgetFields;
}

export async function widgetFieldsForPost(
  svc: Services,
  post: PostRow,
  media: MediaRow,
  groupName: string,
  author: Pick<ProfileRow, "display_name" | "avatar_path"> | null,
): Promise<WidgetFields> {
  const m = await ensureImageRenditions(svc, media);
  const urls = await svc.storage.signedUrls([m.widget_path as string, ...(author?.avatar_path ? [author.avatar_path] : [])]);
  return {
    groupId: post.group_id,
    groupName,
    kind: "photo",
    postId: post.id,
    renditionUrl: urls.get(m.widget_path as string) as string,
    senderName: author?.display_name || null,
    senderAvatarUrl: author?.avatar_path ? urls.get(author.avatar_path) ?? null : null,
    caption: post.caption,
    postedAt: new Date(post.created_at).toISOString(),
  };
}

async function latestCollage(db: Db, groupId: string): Promise<CollageRow | null> {
  const rows = must(
    await db.from("collages").select("id, group_id, widget_path, composed_at, status").eq("group_id", groupId).eq("status", "ready").not("widget_path", "is", null).order("composed_at", { ascending: false }).limit(1),
    "collages",
  ) as CollageRow[];
  return rows[0] ?? null;
}

export async function widgetRefresh(ctx: JobContext): Promise<void> {
  const groupId = str(ctx.job.payload, "group_id");
  const now = ctx.now();
  const audience = await loadAudience(ctx.db, groupId, now);
  if (!audience) return;
  const memberIds = audience.members.map((m) => m.userId);

  const posts = must(
    await ctx.db.from("posts").select(POST_COLUMNS).eq("group_id", groupId).order("created_at", { ascending: false }).limit(RECENT_POSTS),
    "posts",
  ) as PostRow[];
  const collage = await latestCollage(ctx.db, groupId);
  const blocks = await blockedPairs(ctx.db, [...new Set([...memberIds, ...posts.map((p) => p.author_id)])]);
  const mediaRows = await selectIn<MediaRow>(ctx.db, "media", MEDIA_COLUMNS, "id", posts.map((p) => p.media_id));
  const mediaById = new Map(mediaRows.map((m) => [m.id, m]));
  const authors = await selectIn<ProfileRow>(ctx.db, "profiles", "id, display_name, avatar_path", "id", posts.map((p) => p.author_id));
  const authorById = new Map(authors.map((a) => [a.id, a]));

  const itemCache = new Map<string, WidgetItem>();
  const postItem = async (p: PostRow): Promise<WidgetItem | null> => {
    const cached = itemCache.get(p.id);
    if (cached) return cached;
    const media = mediaById.get(p.media_id);
    if (!media) return null;
    const item = { key: `post:${p.id}`, at: p.created_at, fields: await widgetFieldsForPost(ctx, p, media, audience.group.name, authorById.get(p.author_id) ?? null) };
    itemCache.set(p.id, item);
    return item;
  };
  let collageItem: WidgetItem | null = null;
  if (collage?.widget_path && collage.composed_at) {
    collageItem = {
      key: `collage:${collage.id}`,
      at: collage.composed_at,
      fields: {
        groupId,
        groupName: audience.group.name,
        kind: "collage",
        collageId: collage.id,
        renditionUrl: await ctx.storage.signedUrl(collage.widget_path),
        postedAt: new Date(collage.composed_at).toISOString(),
      },
    };
  }

  // posts whose new-post alert (with the widget fields, for the Notification Service Extension)
  // is queued, running or sent: members who get that alert need no background push for it
  const recentIds = posts.slice(0, 8).map((p) => p.id);
  const alerted = new Set(
    !recentIds.length ? [] : (must(
      await ctx.db.from("jobs").select("payload").eq("kind", "push.new_post").in("status", ["queued", "running", "done"]).in("payload->>post_id", recentIds),
      "new-post jobs",
    ) as Array<{ payload: { post_id?: string } }>).map((j) => j.payload.post_id),
  );
  const coveredByAlert = (memberId: string, muted: boolean, item: WidgetItem | null) =>
    !!item && !muted && item.fields.kind === "photo" && alerted.has(item.fields.postId) && posts.find((p) => p.id === item.fields.postId)?.author_id !== memberId;

  const sends: DeviceSend[] = [];
  const deferred: number[] = [];
  const nowMs = now.getTime();
  for (const m of audience.members) {
    const visible = posts.find((p) => !blocks.has(`${m.userId}|${p.author_id}`));
    const pItem = visible ? await postItem(visible) : null;
    const item = collageItem && (!pItem || new Date(collageItem.at) > new Date(pItem.at)) ? collageItem : pItem;
    const stateKey = item?.key ?? "none";
    for (const d of m.devices) {
      if (d.platform === "ios") {
        if (d.widget_push_token) {
          // WidgetKit pushes carry no content: the widget reloads and fetches (also when nothing is left to show)
          if (ctx.throttle.alreadyDelivered(d.widget_push_token, groupId, stateKey)) continue;
          const next = ctx.throttle.widgetKitNextAt(d.widget_push_token, nowMs);
          if (next === null) {
            ctx.throttle.recordWidgetKit(d.widget_push_token, nowMs);
            ctx.throttle.recordDelivered(d.widget_push_token, groupId, stateKey);
            sends.push({ userId: m.userId, deviceId: d.id, platform: "ios", token: d.widget_push_token, tokenColumn: "widget_push_token", label: "widgetkit", apns: apnsWidgetKit(now) });
          } else deferred.push(next);
          continue;
        }
        if (!item || ctx.throttle.alreadyDelivered(d.push_token, groupId, item.key)) continue;
        if (coveredByAlert(m.userId, m.muted, item)) continue;
        const next = ctx.throttle.backgroundNextAt(d.push_token, nowMs);
        if (next === null) {
          ctx.throttle.recordBackground(d.push_token, nowMs);
          ctx.throttle.recordDelivered(d.push_token, groupId, item.key);
          sends.push({ userId: m.userId, deviceId: d.id, platform: "ios", token: d.push_token, tokenColumn: "push_token", label: "widget.background", apns: apnsWidgetBackground(item.fields, now) });
        } else deferred.push(next);
      } else {
        if (!item || ctx.throttle.alreadyDelivered(d.push_token, groupId, item.key)) continue;
        ctx.throttle.recordDelivered(d.push_token, groupId, item.key);
        sends.push({ userId: m.userId, deviceId: d.id, platform: "android", token: d.push_token, tokenColumn: "push_token", label: "widget.android", fcm: fcmWidget(item.fields) });
      }
    }
  }
  await ctx.push.dispatch(sends, { label: "widget.refresh", group_id: groupId, deferred: deferred.length });
  if (deferred.length) {
    await enqueue(ctx.db, "widget.refresh", { group_id: groupId }, { runAt: new Date(Math.min(...deferred)), dedupeKey: `widget.refresh:${groupId}` });
  }
}
