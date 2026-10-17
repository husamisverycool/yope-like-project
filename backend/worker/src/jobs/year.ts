// year.compute / year.recompute {year_story_id, …}: the December year story's data (format owned by
// the worker, docs/API.md §5.19). All of it is the group's, in the group's time zone:
//   moments_shared  how many photos the group shared that year (a group-level number,
//                   docs/SPEC_FLAGS.md T3 — no per-person counts anywhere)
//   busiest_month   the month with the most photos (1–12; no number of photos)
//   most_reacted    photos with reactions, most-reacted first — post ids only, no numbers
//   everyone_days   days on which every member answered the daily moment on time, with the collage
// post_ids lists every photo of the year, so deleting any of them recomputes the story (counts change).

import { maybe, must, selectIn } from "../db.js";
import { loadGroup } from "../push/audience.js";
import { str, type JobContext } from "../services.js";
import { localMidnight, localParts } from "../time.js";
import { POST_COLUMNS, type CollageRow, type InvitationRow, type PostRow, type YearStoryRow } from "../types.js";

export interface YearStoryData {
  version: 1;
  year: number;
  time_zone: string;
  moments_shared: number;
  busiest_month: { month: number } | null;
  most_reacted: string[];
  everyone_days: Array<{ local_date: string; invitation_id: string; collage_id: string; post_ids: string[] }>;
}

export async function yearCompute(ctx: JobContext): Promise<void> {
  const id = str(ctx.job.payload, "year_story_id");
  const story = maybe(await ctx.db.from("year_stories").select("id, group_id, year, status, data, post_ids, asset_paths").eq("id", id).maybeSingle(), "year story") as YearStoryRow | null;
  if (!story) return;
  const group = await loadGroup(ctx.db, story.group_id);
  if (!group) return;
  const tz = group.time_zone;
  const from = localMidnight(`${story.year}-01-01`, tz).toISOString();
  const to = localMidnight(`${story.year + 1}-01-01`, tz).toISOString();

  const posts: PostRow[] = [];
  for (let offset = 0; ; offset += 1000) {
    const page = must(
      await ctx.db.from("posts").select(POST_COLUMNS).eq("group_id", story.group_id).gte("visible_at", from).lt("visible_at", to).order("visible_at").order("id").range(offset, offset + 999),
      "year posts",
    ) as PostRow[];
    posts.push(...page);
    if (page.length < 1000) break;
  }

  const perMonth = new Map<number, number>();
  for (const p of posts) {
    const m = localParts(new Date(p.visible_at), tz).month;
    perMonth.set(m, (perMonth.get(m) ?? 0) + 1);
  }
  let busiest: number | null = null;
  for (const [m, n] of [...perMonth.entries()].sort((a, b) => a[0] - b[0])) if (busiest === null || n > (perMonth.get(busiest) ?? 0)) busiest = m;

  const totals = new Map<string, number>();
  for (const r of await selectIn<{ post_id: string }>(ctx.db, "reactions", "post_id", "post_id", posts.map((p) => p.id))) totals.set(r.post_id, (totals.get(r.post_id) ?? 0) + 1);
  const mostReacted = posts
    .filter((p) => (totals.get(p.id) ?? 0) > 0)
    .sort((a, b) => (totals.get(b.id) ?? 0) - (totals.get(a.id) ?? 0) || a.created_at.localeCompare(b.created_at) || a.id.localeCompare(b.id))
    .map((p) => p.id);

  const invitations = must(
    await ctx.db.from("daily_invitations").select("id, group_id, local_date, fires_at, closes_at, status").eq("group_id", story.group_id).gte("fires_at", from).lt("fires_at", to).order("fires_at"),
    "year invitations",
  ) as InvitationRow[];
  const collages = must(await ctx.db.from("collages").select("id, invitation_id, post_ids, status").eq("group_id", story.group_id).eq("status", "ready"), "collages") as CollageRow[];
  const collageByInvitation = new Map(collages.filter((c) => c.invitation_id).map((c) => [c.invitation_id as string, c]));
  const members = must(await ctx.db.from("group_members").select("user_id, joined_at").eq("group_id", story.group_id), "members") as Array<{ user_id: string; joined_at: string }>;
  const everyoneDays: YearStoryData["everyone_days"] = [];
  for (const inv of invitations) {
    const collage = collageByInvitation.get(inv.id);
    if (!collage) continue;
    const answered = new Set(posts.filter((p) => p.in_window && p.invitation_id === inv.id).map((p) => p.author_id));
    const expected = members.filter((m) => m.joined_at <= inv.fires_at);
    if (expected.length && expected.every((m) => answered.has(m.user_id))) {
      everyoneDays.push({ local_date: inv.local_date, invitation_id: inv.id, collage_id: collage.id, post_ids: collage.post_ids });
    }
  }

  const data: YearStoryData = {
    version: 1,
    year: story.year,
    time_zone: tz,
    moments_shared: posts.length,
    busiest_month: busiest === null ? null : { month: busiest },
    most_reacted: mostReacted,
    everyone_days: everyoneDays,
  };
  must(
    await ctx.db
      .from("year_stories")
      .update({ data, post_ids: posts.map((p) => p.id), asset_paths: [], status: "ready", generated_at: ctx.now().toISOString() })
      .eq("id", id),
    "year story update",
  );
  ctx.log.info("year story computed", { year_story_id: id, year: story.year, posts: posts.length, everyone_days: everyoneDays.length });
}
