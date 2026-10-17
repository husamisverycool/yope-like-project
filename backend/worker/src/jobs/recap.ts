// recap.generate {recap_id, group_id, week_start} (the SQL kind; the brief calls it recap.assemble):
// gathers the group's week (group time zone; a photo belongs to the week in which the group could
// first see it, posts.visible_at — an overnight photo taken on Sunday night joins Monday's week,
// migration 0027), orders it, drafts the text, writes the recap and queues push.recap_ready.
//
// Deterministic order (also the fallback when AI is off or fails):
//   1. moments everyone shared (their on-time photos, by moment time, then capture order),
//   2. the other same-moment answers, by moment,
//   3. the rest, most-reacted first (reaction totals are used only here, never written anywhere
//      a client can read), then by time.
// Text: the AI draft if it passes the copy rules (src/recap/validate.ts), else the template copy
// key week.recap.template.
// Collages: the week's ready same-moment collages, in day order (weekly_recaps.collage_ids,
// migration 0033); members can reorder or remove them with update_recap.

import { maybe, must, selectIn } from "../db.js";
import { copyText } from "../copy.js";
import { loadGroup } from "../push/audience.js";
import type { RecapCandidate, RecapInput, RecapModelResult } from "../recap/ai.js";
import { costUsd } from "../recap/pricing.js";
import { checkRecapText } from "../recap/validate.js";
import { enqueue, str, type JobContext } from "../services.js";
import { addDays, localMidnight, localParts } from "../time.js";
import { MEDIA_COLUMNS, POST_COLUMNS, type InvitationRow, type MediaRow, type PostRow, type RecapRow } from "../types.js";

const WEEKDAY = ["", "mon", "tue", "wed", "thu", "fri", "sat", "sun"];

function localLabel(iso: string, tz: string): string {
  const p = localParts(new Date(iso), tz);
  return `${WEEKDAY[p.isoDow]} ${String(p.hour).padStart(2, "0")}:${String(p.minute).padStart(2, "0")}`;
}

export interface WeekMaterial {
  posts: PostRow[];
  media: Map<string, MediaRow>;
  reactions: Map<string, number>;
  /** invitation id → moment info */
  moments: Array<{ invitation: InvitationRow; postIds: string[]; everyone: boolean }>;
  /** the week's ready same-moment collages, in the order of their invitations */
  collageIds: string[];
}

export function deterministicOrder(m: WeekMaterial): string[] {
  const time = (id: string) => m.posts.find((p) => p.id === id)?.created_at ?? "";
  const byMoment = [...m.moments].sort((a, b) => a.invitation.fires_at.localeCompare(b.invitation.fires_at));
  const out: string[] = [];
  const add = (id: string) => {
    if (!out.includes(id)) out.push(id);
  };
  for (const mo of byMoment) if (mo.everyone) [...mo.postIds].sort((a, b) => time(a).localeCompare(time(b)) || a.localeCompare(b)).forEach(add);
  for (const mo of byMoment) if (!mo.everyone) [...mo.postIds].sort((a, b) => time(a).localeCompare(time(b)) || a.localeCompare(b)).forEach(add);
  [...m.posts]
    .sort((a, b) => (m.reactions.get(b.id) ?? 0) - (m.reactions.get(a.id) ?? 0) || a.created_at.localeCompare(b.created_at) || a.id.localeCompare(b.id))
    .forEach((p) => add(p.id));
  return out;
}

export async function gatherWeek(ctx: JobContext, groupId: string, weekStart: string, tz: string): Promise<WeekMaterial> {
  const from = localMidnight(weekStart, tz).toISOString();
  const to = localMidnight(addDays(weekStart, 7), tz).toISOString();
  const posts = must(
    await ctx.db.from("posts").select(POST_COLUMNS).eq("group_id", groupId).gte("visible_at", from).lt("visible_at", to).order("visible_at").order("id"),
    "week posts",
  ) as PostRow[];
  const media = new Map((await selectIn<MediaRow>(ctx.db, "media", MEDIA_COLUMNS, "id", posts.map((p) => p.media_id))).map((x) => [x.id, x]));
  const reactions = new Map<string, number>();
  for (const r of await selectIn<{ post_id: string }>(ctx.db, "reactions", "post_id", "post_id", posts.map((p) => p.id))) {
    reactions.set(r.post_id, (reactions.get(r.post_id) ?? 0) + 1);
  }
  const invitations = must(
    await ctx.db.from("daily_invitations").select("id, group_id, local_date, fires_at, closes_at, status").eq("group_id", groupId).gte("fires_at", from).lt("fires_at", to).order("fires_at"),
    "week invitations",
  ) as InvitationRow[];
  const members = must(await ctx.db.from("group_members").select("user_id, joined_at").eq("group_id", groupId), "members") as Array<{ user_id: string; joined_at: string }>;
  const moments = invitations
    .map((inv) => {
      const answers = posts.filter((p) => p.in_window && p.invitation_id === inv.id);
      const expected = members.filter((m) => m.joined_at <= inv.fires_at).map((m) => m.user_id);
      const answered = new Set(answers.map((p) => p.author_id));
      return { invitation: inv, postIds: answers.map((p) => p.id), everyone: expected.length > 0 && expected.every((u) => answered.has(u)) };
    })
    .filter((m) => m.postIds.length > 0);
  const collages = (await selectIn<{ id: string; invitation_id: string | null; status: string }>(ctx.db, "collages", "id, invitation_id, status", "invitation_id", invitations.map((i) => i.id)))
    .filter((c) => c.status === "ready" && c.invitation_id);
  const order = new Map(invitations.map((inv, i) => [inv.id, i]));
  const collageIds = collages.sort((a, b) => (order.get(a.invitation_id as string) ?? 0) - (order.get(b.invitation_id as string) ?? 0)).map((c) => c.id);
  return { posts, media, reactions, moments, collageIds };
}

export function recapInput(m: WeekMaterial, groupKind: string, weekStart: string, tz: string): { input: RecapInput; refToPost: Map<string, string> } {
  const refToPost = new Map<string, string>();
  const postRef = new Map<string, string>();
  m.posts.forEach((p, i) => {
    refToPost.set(`p${i + 1}`, p.id);
    postRef.set(p.id, `p${i + 1}`);
  });
  const momentRef = new Map(m.moments.map((mo, i) => [mo.invitation.id, `m${i + 1}`]));
  const photos: RecapCandidate[] = m.posts.map((p) => ({
    ref: postRef.get(p.id) as string,
    local_time: localLabel(p.created_at, tz),
    kind: m.media.get(p.media_id)?.kind ?? "photo",
    caption: p.caption,
    reactions: m.reactions.get(p.id) ?? 0,
    moment: p.in_window && p.invitation_id ? momentRef.get(p.invitation_id) ?? null : null,
  }));
  return {
    input: {
      group_kind: groupKind,
      week: { from: weekStart, to: addDays(weekStart, 6) },
      photos,
      moments: m.moments.map((mo) => ({ ref: momentRef.get(mo.invitation.id) as string, local_time: localLabel(mo.invitation.fires_at, tz), answered_by_everyone: mo.everyone })),
    },
    refToPost,
  };
}

async function logCost(ctx: JobContext, groupId: string, result: RecapModelResult): Promise<void> {
  for (const u of result.usage) {
    const cost = costUsd(u);
    if (cost === null) ctx.log.warn("no price known for model; cost logged as 0", { model: u.model });
    must(
      await ctx.db.from("ai_cost_log").insert({
        job_id: ctx.job.id,
        group_id: groupId,
        purpose: "recap",
        model: u.model,
        input_tokens: u.inputTokens + u.cacheWriteTokens + u.cacheReadTokens,
        output_tokens: u.outputTokens,
        cost_usd: cost ?? 0,
      }),
      "ai_cost_log",
    );
    ctx.log.info("ai cost", { model: u.model, input_tokens: u.inputTokens, cache_write_tokens: u.cacheWriteTokens, cache_read_tokens: u.cacheReadTokens, output_tokens: u.outputTokens, cost_usd: cost });
  }
}

export async function recapGenerate(ctx: JobContext): Promise<void> {
  const id = str(ctx.job.payload, "recap_id");
  const recap = maybe(await ctx.db.from("weekly_recaps").select("id, group_id, week_start, items, text, status").eq("id", id).maybeSingle(), "recap") as RecapRow | null;
  if (!recap || recap.status === "ready") return;
  const group = await loadGroup(ctx.db, recap.group_id);
  if (!group) return;
  const week = await gatherWeek(ctx, recap.group_id, recap.week_start, group.time_zone);
  const fallbackItems = deterministicOrder(week);
  // resolved first: a missing template key fails the job before any model call is paid for
  const templateText = week.posts.length ? copyText("week.recap.template", { group: group.name }) : null;

  let items = fallbackItems;
  let text: string | null = null;
  let source = "template";
  if (ctx.recapModel && week.posts.length) {
    const { input, refToPost } = recapInput(week, group.kind, recap.week_start, group.time_zone);
    try {
      const result = await ctx.recapModel.draft(input);
      await logCost(ctx, recap.group_id, result);
      if (result.refused) {
        ctx.log.warn("recap draft refused; deterministic recap used", { stop_reason: result.stopReason });
      } else if (result.draft) {
        const chosen = result.draft.items.map((r) => refToPost.get(r)).filter((x): x is string => !!x);
        if (chosen.length) items = chosen;
        const check = checkRecapText(result.draft.text);
        if (check.ok) {
          text = result.draft.text.trim();
          source = "ai";
        } else {
          ctx.log.info("recap text fails the copy rules; template used", { problems: check.problems });
        }
      }
    } catch (e) {
      ctx.log.warn("recap model call failed; deterministic recap used", { error: e });
    }
  }
  if (text === null) text = templateText;

  // drop anything deleted meanwhile
  const existing = new Set((await selectIn<{ id: string }>(ctx.db, "posts", "id", "id", items)).map((p) => p.id));
  items = items.filter((p) => existing.has(p));
  const liveCollages = new Set((await selectIn<{ id: string }>(ctx.db, "collages", "id", "id", week.collageIds)).map((c) => c.id));
  const collageIds = week.collageIds.filter((c) => liveCollages.has(c));
  const done = must(
    await ctx.db
      .from("weekly_recaps")
      .update({ items, collage_ids: collageIds, text, status: "ready", generated_at: ctx.now().toISOString() })
      .eq("id", id)
      .eq("status", "pending")
      .select("id"),
    "recap update",
  ) as Array<{ id: string }>;
  if (!done.length) return;
  ctx.log.info("recap ready", { recap_id: id, items: items.length, text_source: source });
  if (items.length) await enqueue(ctx.db, "push.recap_ready", { recap_id: id, group_id: recap.group_id }, { dedupeKey: `push.recap_ready:${id}` });
}
