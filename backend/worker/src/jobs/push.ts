// Event notifications. Each is sent only for the real event it names, never implying something
// that does not exist (tenets, docs/CONVENTIONS.md §6):
//   push.new_post        new photo → members except the author (+ "reply" to the author of the
//                        photo it answers), with the widget fields so iOS updates the widget
//   push.new_message     only replies: the author of the replied message / photo ("reply to you")
//   push.reaction        the photo's author ("reaction to you")
//   push.birthday_request members except the honoree and anyone with a block with them
//   push.recap_ready     members, after recap.generate (worker-enqueued)
//   push.tribute         the honoree only, after the tribute is rendered and delivered (worker-enqueued)
//   push.year_story      members, once, the first time the group's year story is ready (worker-enqueued by
//                        year.compute; the 31 December refresh and other recomputes never notify)
//   push.selfie_reaction the photo's author, once per person per photo ("reaction" type, opens the photo)
//   push.plan_created    members except the plan's maker
//   push.plan_tomorrow   24 hours before a plan, members who answered Going or Maybe (the maker included)
//   push.plan_changed    a plan's day, time or place changed: Going and Maybe, except who changed it
//   push.plan_canceled   a plan was cancelled: Going and Maybe, except who cancelled it
//   push.photos_developed overnight photos revealed: once per group and reveal time, to members who can see one
//                        of them (their own included) and kept overnight alerts on (opens the first photo)
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
import { localTime, localWhen, unixSeconds } from "../time.js";
import { firstName, MEDIA_COLUMNS, PLAN_COLUMNS, POST_COLUMNS, type MediaRow, type MessageRow, type PlanRow, type PostRow, type RecapRow, type TributeRequestRow, type TributeRow, type YearStoryRow } from "../types.js";
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

export async function pushYearStory(ctx: JobContext): Promise<void> {
  const story = maybe(
    await ctx.db.from("year_stories").select("id, group_id, year, status, data, post_ids, asset_paths").eq("id", str(ctx.job.payload, "year_story_id")).maybeSingle(),
    "year story",
  ) as YearStoryRow | null;
  // only for a story that exists and can be opened (a recompute may have it pending: try again later)
  if (!story) return;
  if (story.status !== "ready") throw new Error(`year story ${story.id} is not ready yet`);
  const now = ctx.now();
  const audience = await loadAudience(ctx.db, story.group_id, now);
  if (!audience) return;
  const params = { group: audience.group.name, year: story.year };
  const spec: Omit<AlertSpec, "quiet"> = {
    type: "year_story",
    groupId: story.group_id,
    ids: { year: String(story.year) },
    title: copyText("notifications.push.yearStory.title", params),
    body: copyText("notifications.push.yearStory.body", params),
    collapseKey: `year:${story.id}`,
  };
  const sends = audience.members.filter((m) => !m.muted).flatMap((m) => alertSends(m, spec, now));
  await ctx.push.dispatch(sends, { label: "year_story", group_id: story.group_id, year_story_id: story.id });
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

export async function pushSelfieReaction(ctx: JobContext): Promise<void> {
  const postId = str(ctx.job.payload, "post_id");
  const reactor = str(ctx.job.payload, "user_id");
  const still = must(await ctx.db.from("selfie_reactions").select("post_id").eq("post_id", postId).eq("user_id", reactor), "selfie reaction") as unknown[];
  if (!still.length) return; // removed before we got here
  const post = await loadPost(ctx, postId);
  if (!post || post.author_id === reactor) return;
  const now = ctx.now();
  const audience = await loadAudience(ctx.db, post.group_id, now);
  const member = audience?.byId.get(post.author_id);
  if (!audience || !member || member.muted) return;
  if ((await blockedWith(ctx.db, [reactor])).has(post.author_id)) return;
  const name = firstName((await profileOf(ctx.db, reactor))?.display_name) ?? "";
  const params = { name, group: audience.group.name };
  const sends = alertSends(member, {
    type: "reaction",
    groupId: post.group_id,
    ids: { post_id: post.id },
    title: copyText("notifications.push.selfieReaction.title", params),
    body: copyText("notifications.push.selfieReaction.body", params),
    // selfies and emoji reactions to one photo replace each other (push.reaction)
    collapseKey: `reaction:${post.id}`,
  }, now);
  await ctx.push.dispatch(sends, { label: "selfie_reaction", group_id: post.group_id, post_id: post.id });
}

async function loadPlan(ctx: JobContext, id: string): Promise<PlanRow | null> {
  return maybe(await ctx.db.from("plans").select(PLAN_COLUMNS).eq("id", id).maybeSingle(), "plan") as PlanRow | null;
}

/** Members who answered Going or Maybe, minus muted and anyone with a block with the plan's maker. */
async function comingMembers(ctx: JobContext, plan: PlanRow, audience: Audience, except: string | null): Promise<Member[]> {
  const answers = must(
    await ctx.db.from("plan_answers").select("user_id").eq("plan_id", plan.id).in("answer", ["going", "maybe"]),
    "plan answers",
  ) as Array<{ user_id: string }>;
  const coming = new Set(answers.map((a) => a.user_id));
  const blocked = plan.created_by ? await blockedWith(ctx.db, [plan.created_by]) : new Set<string>();
  return audience.members.filter((m) => coming.has(m.userId) && m.userId !== except && !m.muted && !blocked.has(m.userId));
}

function planAlert(plan: PlanRow, title: string, body: string): Omit<AlertSpec, "quiet"> {
  return {
    type: "plan",
    groupId: plan.group_id,
    ids: { plan_id: plan.id },
    title,
    body,
    // a plan's alerts replace each other on the device
    collapseKey: `plan:${plan.id}`,
    expiresAt: unixSeconds(plan.starts_at),
  };
}

export async function pushPlanCreated(ctx: JobContext): Promise<void> {
  const plan = await loadPlan(ctx, str(ctx.job.payload, "plan_id"));
  const now = ctx.now();
  if (!plan || plan.canceled_at || new Date(plan.starts_at) <= now || !plan.created_by) return;
  const audience = await loadAudience(ctx.db, plan.group_id, now);
  if (!audience) return;
  const recipients = recipientsExcept(audience, new Set([plan.created_by]), await blockedWith(ctx.db, [plan.created_by]));
  if (!recipients.length) return;
  const name = firstName((await profileOf(ctx.db, plan.created_by))?.display_name) ?? "";
  const params = { name, group: audience.group.name, title: plan.title };
  const spec = planAlert(plan, copyText("notifications.push.planNew.title", params), copyText("notifications.push.planNew.body", params));
  await ctx.push.dispatch(recipients.flatMap((m) => alertSends(m, spec, now)), { label: "plan_created", group_id: plan.group_id, plan_id: plan.id });
}

export async function pushPlanTomorrow(ctx: JobContext): Promise<void> {
  const plan = await loadPlan(ctx, str(ctx.job.payload, "plan_id"));
  const now = ctx.now();
  if (!plan || plan.canceled_at || new Date(plan.starts_at) <= now) return;
  const audience = await loadAudience(ctx.db, plan.group_id, now);
  if (!audience) return;
  const recipients = await comingMembers(ctx, plan, audience, null);
  if (!recipients.length) return;
  const params = { group: audience.group.name, title: plan.title };
  const body = plan.all_day
    ? copyText("notifications.push.planTomorrow.body.allDay", params)
    : copyText("notifications.push.planTomorrow.body.timed", { ...params, time: localTime(plan.starts_at, audience.group.time_zone) });
  const spec = planAlert(plan, copyText("notifications.push.planTomorrow.title", params), body);
  await ctx.push.dispatch(recipients.flatMap((m) => alertSends(m, spec, now)), { label: "plan_tomorrow", group_id: plan.group_id, plan_id: plan.id });
}

export async function pushPlanChanged(ctx: JobContext): Promise<void> {
  const plan = await loadPlan(ctx, str(ctx.job.payload, "plan_id"));
  const now = ctx.now();
  // a later edit queues its own job: only the latest version is announced
  if (!plan || plan.canceled_at || new Date(plan.starts_at) <= now || plan.updated_at !== str(ctx.job.payload, "updated_at")) return;
  const audience = await loadAudience(ctx.db, plan.group_id, now);
  if (!audience) return;
  const editor = str(ctx.job.payload, "author_id");
  const recipients = await comingMembers(ctx, plan, audience, editor);
  if (!recipients.length) return;
  const name = firstName((await profileOf(ctx.db, editor))?.display_name) ?? "";
  const params = { name, group: audience.group.name, title: plan.title };
  const timeChanged = ctx.job.payload.time_changed === true;
  const body = timeChanged || !plan.place
    ? copyText("notifications.push.planChanged.body.time", { ...params, when: localWhen(plan, audience.group.time_zone) })
    : copyText("notifications.push.planChanged.body.place", { ...params, place: plan.place });
  const spec = planAlert(plan, copyText("notifications.push.planChanged.title", params), body);
  await ctx.push.dispatch(recipients.flatMap((m) => alertSends(m, spec, now)), { label: "plan_changed", group_id: plan.group_id, plan_id: plan.id });
}

export async function pushPlanCanceled(ctx: JobContext): Promise<void> {
  const plan = await loadPlan(ctx, str(ctx.job.payload, "plan_id"));
  const now = ctx.now();
  // restored since: nothing to announce
  if (!plan || !plan.canceled_at) return;
  const audience = await loadAudience(ctx.db, plan.group_id, now);
  if (!audience) return;
  const canceler = str(ctx.job.payload, "author_id");
  const recipients = await comingMembers(ctx, plan, audience, canceler);
  if (!recipients.length) return;
  const name = firstName((await profileOf(ctx.db, canceler))?.display_name) ?? "";
  const params = { name, group: audience.group.name, title: plan.title };
  const spec = planAlert(plan, copyText("notifications.push.planCanceled.title", params), copyText("notifications.push.planCanceled.body", params));
  await ctx.push.dispatch(recipients.flatMap((m) => alertSends(m, spec, now)), { label: "plan_canceled", group_id: plan.group_id, plan_id: plan.id });
}

export async function pushPhotosDeveloped(ctx: JobContext): Promise<void> {
  const groupId = str(ctx.job.payload, "group_id");
  const developsAt = str(ctx.job.payload, "develops_at");
  const now = ctx.now();
  const audience = await loadAudience(ctx.db, groupId, now);
  if (!audience) return;
  // the photos that revealed at this time (ordinary posts now)
  const posts = must(
    await ctx.db.from("posts").select("id, author_id, created_at").eq("group_id", groupId).eq("revealed_at", developsAt).order("created_at").order("id"),
    "revealed posts",
  ) as Array<{ id: string; author_id: string }>;
  if (!posts.length) return; // deleted since
  // a member hears when at least one of the photos is theirs or from someone they have no block with
  const authors = [...new Set(posts.map((p) => p.author_id))];
  const blockedBy = new Map<string, Set<string>>();
  for (const a of authors) blockedBy.set(a, await blockedWith(ctx.db, [a]));
  const sees = (userId: string, authorId: string) => authorId === userId || !blockedBy.get(authorId)!.has(userId);
  const seesOne = (userId: string) => authors.some((a) => sees(userId, a));
  const off = must(
    await ctx.db.from("notification_settings").select("user_id").eq("overnight", false).in("user_id", audience.members.map((m) => m.userId)),
    "overnight settings",
  ) as Array<{ user_id: string }>;
  const silenced = new Set(off.map((r) => r.user_id));
  const recipients = audience.members.filter(
    (m) => !m.muted && !silenced.has(m.userId) && seesOne(m.userId),
  );
  if (!recipients.length) return;
  const params = { group: audience.group.name };
  // Each member's alert names the first revealed photo they can read: the apps open the viewer on it and the photos
  // revealed with it (a photo from someone they have a block with would open on nothing).
  const spec = (userId: string): Omit<AlertSpec, "quiet"> => ({
    type: "new_post",
    groupId,
    // revealed_at marks the alert as a reveal: the apps file it under Developed Photos and open every photo revealed with it
    ids: { post_id: posts.find((p) => sees(userId, p.author_id))!.id, revealed_at: developsAt },
    title: copyText("camera.overnight.push.title", params),
    body: copyText("camera.overnight.push.body", params),
    collapseKey: `developed:${groupId}:${developsAt}`,
  });
  await ctx.push.dispatch(recipients.flatMap((m) => alertSends(m, spec(m.userId), now)), { label: "photos_developed", group_id: groupId, post_id: posts[0]!.id });
}
