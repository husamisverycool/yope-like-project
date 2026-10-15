// Event notifications. Each is sent only for the real event it names, never implying something
// that does not exist (tenets, docs/CONVENTIONS.md §6):
//   push.new_post        new photo → members except the author (+ "reply" to the author of the
//                        photo it answers), with the widget fields so iOS updates the widget
//   push.new_message     only replies: the author of the replied message / photo ("reply to you")
//   push.reaction        the photo's author ("reaction to you")
//   push.birthday_request members except the honoree and anyone with a block with them
//   push.recap_ready     members, after recap.generate (worker-enqueued)
//   push.tribute         the honoree only, after the tribute is rendered and delivered (worker-enqueued)
// Rules for every alert: no push to the actor, nobody with a block with the actor, nobody who muted
// the group (mute = no alerts from that group; widgets still update), silent in quiet hours.
// Alerts carry a collapse id, so a job that runs twice replaces the notification instead of
// showing it twice.

import { maybe, must } from "../db.js";
import { copyText } from "../copy.js";
import { alertSends, blockedWith, loadAudience, profileOf, type Audience, type Member } from "../push/audience.js";
import { apnsAlert, fitText, type AlertSpec } from "../push/payloads.js";
import type { DeviceSend } from "../push/service.js";
import { str, type JobContext } from "../services.js";
import { unixSeconds } from "../time.js";
import { firstName, MEDIA_COLUMNS, POST_COLUMNS, type MediaRow, type MessageRow, type PostRow, type RecapRow, type TributeRequestRow, type TributeRow } from "../types.js";
import { widgetFieldsForPost } from "./widget.js";

function recipientsExcept(audience: Audience, exclude: Set<string>, blocked: Set<string>): Member[] {
  return audience.members.filter((m) => !exclude.has(m.userId) && !blocked.has(m.userId) && !m.muted);
}

async function loadPost(ctx: JobContext, id: string): Promise<PostRow | null> {
  return maybe(await ctx.db.from("posts").select(POST_COLUMNS).eq("id", id).maybeSingle(), "post") as PostRow | null;
}

export async function pushNewPost(ctx: JobContext): Promise<void> {
  const post = await loadPost(ctx, str(ctx.job.payload, "post_id"));
  if (!post) return;
  const now = ctx.now();
  const audience = await loadAudience(ctx.db, post.group_id, now);
  if (!audience) return;
  const media = maybe(await ctx.db.from("media").select(MEDIA_COLUMNS).eq("id", post.media_id).maybeSingle(), "media") as MediaRow | null;
  if (!media) return;
  const author = await profileOf(ctx.db, post.author_id);
  const name = firstName(author?.display_name) ?? "";
  const group = audience.group.name;
  const blocked = await blockedWith(ctx.db, [post.author_id]);

  // a photo answering a photo: its author gets "reply" instead of "new post"
  let replyTo: string | null = null;
  if (post.reply_to_post_id) {
    const target = await loadPost(ctx, post.reply_to_post_id);
    if (target && target.author_id !== post.author_id) replyTo = target.author_id;
  }

  const recipients = recipientsExcept(audience, new Set([post.author_id]), blocked);
  if (!recipients.length) return;
  const newPostTitle = copyText("notifications.push.newPost.title", { name, group });
  const newPostBody = copyText("notifications.push.newPost.body", { name, group });
  const replyTitle = replyTo ? copyText("notifications.push.reply.title", { name, group }) : "";
  const replyBody = replyTo ? copyText("notifications.push.reply.body.photo", { name, group }) : "";
  const widget = await widgetFieldsForPost(ctx, post, media, group, author);

  const sends: DeviceSend[] = [];
  for (const m of recipients) {
    const isReply = m.userId === replyTo;
    const spec: Omit<AlertSpec, "quiet"> = {
      type: isReply ? "reply" : "new_post",
      groupId: post.group_id,
      ids: { post_id: post.id },
      title: isReply ? replyTitle : newPostTitle,
      body: isReply ? replyBody : newPostBody,
      collapseKey: `post:${post.id}`,
      widget,
    };
    sends.push(...alertSends(m, spec, now));
  }
  const report = await ctx.push.dispatch(sends, { label: "new_post", group_id: post.group_id, post_id: post.id });
  // iOS devices that received the alert get the photo through the Notification Service Extension:
  // widget.refresh need not send them a background push for it
  for (const o of report.outcomes) if (o.ok && o.send.platform === "ios") ctx.throttle.recordDelivered(o.send.token, post.group_id, `post:${post.id}`);
}

export async function pushNewMessage(ctx: JobContext): Promise<void> {
  const msg = maybe(
    await ctx.db.from("messages").select("id, group_id, author_id, kind, body, post_id, reply_to_post_id, reply_to_message_id, created_at").eq("id", str(ctx.job.payload, "message_id")).maybeSingle(),
    "message",
  ) as MessageRow | null;
  if (!msg) return;
  // There is no notification for ordinary chat messages in the shared push contract; only replies.
  let target: string | null = null;
  if (msg.reply_to_message_id) {
    const m = maybe(await ctx.db.from("messages").select("author_id").eq("id", msg.reply_to_message_id).maybeSingle(), "replied message") as { author_id: string } | null;
    target = m?.author_id ?? null;
  } else if (msg.reply_to_post_id) {
    target = (await loadPost(ctx, msg.reply_to_post_id))?.author_id ?? null;
  }
  if (!target || target === msg.author_id) return;
  const now = ctx.now();
  const audience = await loadAudience(ctx.db, msg.group_id, now);
  const member = audience?.byId.get(target);
  if (!audience || !member || member.muted) return;
  if ((await blockedWith(ctx.db, [msg.author_id])).has(target)) return;
  const name = firstName((await profileOf(ctx.db, msg.author_id))?.display_name) ?? "";
  const group = audience.group.name;
  const title = copyText("notifications.push.reply.title", { name, group });
  const base: Omit<AlertSpec, "quiet" | "body"> = { type: "reply", groupId: msg.group_id, ids: { message_id: msg.id }, title, collapseKey: `reply:${msg.id}` };

  const sends: DeviceSend[] = [];
  for (const d of member.devices) {
    let body: string;
    if (msg.kind === "text") {
      // the reply text itself, shortened only when the APNs payload would exceed 4 KB
      const build = (text: string) => apnsAlert({ ...base, quiet: member.quiet, body: copyText("notifications.push.reply.body.text", { name, group, message: text }) });
      body = copyText("notifications.push.reply.body.text", { name, group, message: fitText(msg.body ?? "", build).text });
    } else {
      body = copyText("notifications.push.reply.body.voice", { name, group });
    }
    sends.push(...alertSends({ ...member, devices: [d] }, { ...base, body }, now));
  }
  await ctx.push.dispatch(sends, { label: "reply", group_id: msg.group_id, message_id: msg.id });
}

export async function pushReaction(ctx: JobContext): Promise<void> {
  const postId = str(ctx.job.payload, "post_id");
  const reactor = str(ctx.job.payload, "user_id");
  const emoji = str(ctx.job.payload, "emoji");
  const still = must(await ctx.db.from("reactions").select("post_id").eq("post_id", postId).eq("user_id", reactor).eq("emoji", emoji), "reaction") as unknown[];
  if (!still.length) return; // un-reacted before we got here
  const post = await loadPost(ctx, postId);
  if (!post || post.author_id === reactor) return;
  const now = ctx.now();
  const audience = await loadAudience(ctx.db, post.group_id, now);
  const member = audience?.byId.get(post.author_id);
  if (!audience || !member || member.muted) return;
  if ((await blockedWith(ctx.db, [reactor])).has(post.author_id)) return;
  const name = firstName((await profileOf(ctx.db, reactor))?.display_name) ?? "";
  const params = { name, emoji, group: audience.group.name };
  const sends = alertSends(member, {
    type: "reaction",
    groupId: post.group_id,
    ids: { post_id: post.id },
    title: copyText("notifications.push.reaction.title", params),
    body: copyText("notifications.push.reaction.body", params),
    // several reactions to one photo replace each other (PushMessage.Alert.collapseKey)
    collapseKey: `reaction:${post.id}`,
  }, now);
  await ctx.push.dispatch(sends, { label: "reaction", group_id: post.group_id, post_id: post.id });
}

export async function pushBirthdayRequest(ctx: JobContext): Promise<void> {
  const req = maybe(
    await ctx.db.from("tribute_requests").select("id, group_id, honoree_id, birthday_date, due_at, closed_at").eq("id", str(ctx.job.payload, "request_id")).maybeSingle(),
    "tribute request",
  ) as TributeRequestRow | null;
  const now = ctx.now();
  if (!req || req.closed_at || new Date(req.due_at) <= now) return;
  const audience = await loadAudience(ctx.db, req.group_id, now);
  if (!audience) return;
  // private: never the honoree, nor anyone with a block with them
  const recipients = recipientsExcept(audience, new Set([req.honoree_id]), await blockedWith(ctx.db, [req.honoree_id]));
  if (!recipients.length) return;
  const name = firstName((await profileOf(ctx.db, req.honoree_id))?.display_name) ?? "";
  const params = { name, group: audience.group.name };
  const spec: Omit<AlertSpec, "quiet"> = {
    type: "birthday_request",
    groupId: req.group_id,
    ids: { request_id: req.id },
    title: copyText("notifications.push.birthdayRequest.title", params),
    body: copyText("notifications.push.birthdayRequest.body", params),
    collapseKey: `birthday:${req.id}`,
    expiresAt: unixSeconds(req.due_at),
  };
  const sends = recipients.flatMap((m) => alertSends(m, spec, now));
  if (sends.some((s) => s.userId === req.honoree_id)) throw new Error("birthday request addressed to the honoree");
  await ctx.push.dispatch(sends, { label: "birthday_request", group_id: req.group_id, request_id: req.id });
}

export async function pushRecapReady(ctx: JobContext): Promise<void> {
  const recap = maybe(await ctx.db.from("weekly_recaps").select("id, group_id, week_start, items, text, status").eq("id", str(ctx.job.payload, "recap_id")).maybeSingle(), "recap") as RecapRow | null;
  if (!recap || recap.status !== "ready" || !recap.items.length) return;
  const now = ctx.now();
  const audience = await loadAudience(ctx.db, recap.group_id, now);
  if (!audience) return;
  const params = { group: audience.group.name };
  const spec: Omit<AlertSpec, "quiet"> = {
    type: "recap_ready",
    groupId: recap.group_id,
    ids: { recap_id: recap.id },
    title: copyText("notifications.push.recapReady.title", params),
    body: copyText("notifications.push.recapReady.body", params),
    collapseKey: `recap:${recap.id}`,
  };
  const sends = audience.members.filter((m) => !m.muted).flatMap((m) => alertSends(m, spec, now));
  await ctx.push.dispatch(sends, { label: "recap_ready", group_id: recap.group_id, recap_id: recap.id });
}

export async function pushTribute(ctx: JobContext): Promise<void> {
  const t = maybe(
    await ctx.db.from("tributes").select("id, request_id, group_id, honoree_id, video_path, poster_path, status, rendered_at, delivered_at").eq("id", str(ctx.job.payload, "tribute_id")).maybeSingle(),
    "tribute",
  ) as TributeRow | null;
  const now = ctx.now();
  // only for a tribute that exists, is rendered and is delivered (visible to the honoree)
  if (!t || t.status !== "ready" || !t.video_path || !t.delivered_at || new Date(t.delivered_at) > now) return;
  const audience = await loadAudience(ctx.db, t.group_id, now);
  const member = audience?.byId.get(t.honoree_id);
  if (!audience || !member || member.muted) return;
  const params = { group: audience.group.name };
  const sends = alertSends(member, {
    type: "tribute",
    groupId: t.group_id,
    ids: { tribute_id: t.id },
    title: copyText("notifications.push.tribute.title", params),
    body: copyText("notifications.push.tribute.body", params),
    collapseKey: `tribute:${t.id}`,
  }, now);
  await ctx.push.dispatch(sends, { label: "tribute", group_id: t.group_id, tribute_id: t.id });
}
