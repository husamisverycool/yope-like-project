// tribute.render / tribute.rerender edge cases and year.compute.
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { setTokenOverrides } from "../../src/tokens.js";
import { closeDb, createGroup, createUsers, objectsUnder, postPhoto, registerDevice, rpc, sql, type TestGroup, type TestUser } from "../helpers/db.js";
import { TEST_TRIBUTE_TOKENS } from "../helpers/tokens.js";
import { apnsDeviceSends, startWorld, type World } from "../helpers/world.js";

let w: World;
let u: TestUser[];
let g: TestGroup;

beforeAll(async () => {
  w = await startWorld();
  u = await createUsers(3, "Trib");
  g = await createGroup(u[0]!, u.slice(1), { name: "Tribute group", tz: "UTC" });
});
afterAll(async () => {
  setTokenOverrides(null);
  await w.close();
  await closeDb();
});

/** A closed request for u2's birthday with one contribution, and its tribute + render job. */
async function tributeWithContribution(dueInPast = true) {
  const { post } = await postPhoto(u[0]!, [g.id]);
  const [req] = await sql(`insert into public.tribute_requests (group_id, honoree_id, birthday_date, due_at) values ($1, $2, current_date + (random() * 300)::int + 1, now() + interval '1 day') returning id`, [g.id, u[2]!.id]);
  const c = await rpc(u[0]!.client, "contribute_tribute", { p_request_id: req.id, p_post_id: post.id, p_line: "for the best roommate" });
  if (dueInPast) await sql(`update public.tribute_requests set due_at = now() - interval '1 second', closed_at = now() where id = $1`, [req.id]);
  const [t] = await sql(`insert into public.tributes (request_id, group_id, honoree_id) values ($1, $2, $3) returning id`, [req.id, g.id, u[2]!.id]);
  await sql(`select private.enqueue('tribute.render', jsonb_build_object('tribute_id', $1::uuid, 'request_id', $2::uuid, 'group_id', $3::uuid), 'tribute.render:' || $1, now())`, [t.id, req.id, g.id]);
  return { tributeId: t.id as string, requestId: req.id as string, contributionId: c.id as string };
}

describe("tribute.render", () => {
  it("fails (and is retried later) with a clear missing-design-token error when a design value is absent", async () => {
    setTokenOverrides({ "duration.birthday.tribute.photoHold": null });
    const { tributeId } = await tributeWithContribution();
    await w.runner.runUntilIdle({ kinds: ["tribute.render"] });
    const [job] = await sql(`select status, last_error from public.jobs where dedupe_key = $1 order by id desc limit 1`, [`tribute.render:${tributeId}`]);
    expect(job.status).toBe("queued"); // retried with backoff
    expect(job.last_error).toMatch(/MissingTokenError: missing design token (layout\.birthday\.tribute\.video|duration\.birthday\.tribute\.photoHold)/);
    const [t] = await sql(`select status, video_path, delivered_at from public.tributes where id = $1`, [tributeId]);
    expect(t).toEqual({ status: "pending", video_path: null, delivered_at: null }); // nothing delivered
    expect(await objectsUnder(`g/${g.id}/tributes/${tributeId}/`)).toEqual([]);
    await sql(`update public.jobs set status = 'cancelled' where dedupe_key = $1 and status = 'queued'`, [`tribute.render:${tributeId}`]);
  });

  it("renders but does not deliver before the birthday; a tribute whose contributions are all withdrawn is deleted", async () => {
    setTokenOverrides(TEST_TRIBUTE_TOKENS);
    const { tributeId, contributionId } = await tributeWithContribution(false);
    await w.runner.runUntilIdle({ kinds: ["tribute.render", "media.renditions"] });
    const [t] = await sql(`select status, video_path, delivered_at from public.tributes where id = $1`, [tributeId]);
    expect(t.status).toBe("ready");
    expect(t.delivered_at).toBeNull(); // the honoree cannot see it before due_at
    expect(await sql(`select 1 from public.jobs where dedupe_key = $1`, [`push.tribute:${tributeId}`])).toHaveLength(0);
    // the contributor withdraws (allowed before due_at) → tribute.rerender → no contribution left
    const { error } = await u[0]!.client.from("tribute_contributions").delete().eq("id", contributionId);
    expect(error).toBeNull();
    await w.runner.runUntilIdle({ kinds: ["tribute.rerender", "storage.delete"] });
    expect(await sql(`select 1 from public.tributes where id = $1`, [tributeId])).toHaveLength(0);
    expect(await objectsUnder(`g/${g.id}/tributes/${tributeId}/`)).toEqual([]);
  });
});

describe("year.compute", () => {
  it("writes the story data: group-level moments, busiest month, most-reacted list without numbers, everyone days", async () => {
    const year = 2025;
    const p1 = (await postPhoto(u[0]!, [g.id])).post;
    const p2 = (await postPhoto(u[1]!, [g.id])).post;
    const p3 = (await postPhoto(u[2]!, [g.id])).post;
    await sql(`update public.posts set created_at = timestamptz '2025-03-03 10:00:00Z' where id = $1`, [p1.id]);
    await sql(`update public.posts set created_at = timestamptz '2025-07-01 10:00:00Z' where id = any($1)`, [[p2.id, p3.id]]);
    await rpc(u[1]!.client, "react", { p_post_id: p1.id, p_emoji: "🔥" });
    await rpc(u[2]!.client, "react", { p_post_id: p1.id, p_emoji: "😂" });
    await rpc(u[0]!.client, "react", { p_post_id: p3.id, p_emoji: "❤️" });
    const [story] = await sql(`insert into public.year_stories (group_id, year) values ($1, $2) returning id`, [g.id, year]);
    await sql(`select private.enqueue('year.compute', jsonb_build_object('year_story_id', $1::uuid, 'group_id', $2::uuid, 'year', $3::int), null, now())`, [story.id, g.id, year]);
    await w.runner.runUntilIdle({ kinds: ["year.compute"] });
    const [s] = await sql(`select * from public.year_stories where id = $1`, [story.id]);
    expect(s.status).toBe("ready");
    expect(s.data).toEqual({ version: 1, year, time_zone: "UTC", moments_shared: 3, busiest_month: { month: 7 }, most_reacted: [p1.id, p3.id], everyone_days: [], self_tagged: [] });
    expect([...s.post_ids].sort()).toEqual([p1.id, p2.id, p3.id].sort());
  });

  it("lists the photos members tagged themselves in (ids only), tells the group once, and stays silent on recomputes", async () => {
    const [a, b, c] = await createUsers(3, "YearTag");
    const grp = await createGroup(a!, [b!, c!], { name: "Year tags", tz: "UTC" });
    const ios = await registerDevice(b!, "ios");
    const year = 2024;
    const q1 = (await postPhoto(a!, [grp.id])).post;
    const q2 = (await postPhoto(b!, [grp.id])).post;
    const q3 = (await postPhoto(c!, [grp.id])).post;
    await sql(`update public.posts set created_at = timestamptz '2024-02-01 10:00:00Z' where id = $1`, [q1.id]);
    await sql(`update public.posts set created_at = timestamptz '2024-05-01 10:00:00Z' where id = $1`, [q2.id]);
    await sql(`update public.posts set created_at = timestamptz '2024-09-01 10:00:00Z' where id = $1`, [q3.id]);
    // b is in a's photo and in c's photo; c too in c's photo: still listed once, in time order, with no names or counts
    for (const [user, post] of [[b, q3], [b, q1], [c, q3]] as const) {
      const { error } = await user!.client.from("post_tags").insert({ post_id: post.id, user_id: user!.id });
      expect(error).toBeNull();
    }
    const [story] = await sql(`insert into public.year_stories (group_id, year) values ($1, $2) returning id`, [grp.id, year]);
    await sql(`select private.enqueue('year.compute', jsonb_build_object('year_story_id', $1::uuid, 'group_id', $2::uuid, 'year', $3::int), 'year.compute:' || $1, now())`, [story.id, grp.id, year]);
    await w.runner.runUntilIdle({ kinds: ["year.compute", "push.year_story"] });
    const [s] = await sql(`select status, data, announced_at from public.year_stories where id = $1`, [story.id]);
    expect(s.status).toBe("ready");
    expect(s.data.self_tagged).toEqual([q1.id, q3.id]);
    expect(JSON.stringify(s.data)).not.toContain(b!.id);
    expect(s.announced_at).not.toBeNull();
    const sent = () => apnsDeviceSends(w.apns).filter((x) => x.token === ios.push_token && x.payload?.type === "year_story");
    expect(sent()).toHaveLength(1);
    expect(sent()[0]!.payload).toMatchObject({ type: "year_story", group_id: grp.id, year: "2024" });
    expect(sent()[0]!.payload.aps.alert).toEqual({ title: "[notifications.push.yearStory.title] group=Year tags year=2024", body: "[notifications.push.yearStory.body] group=Year tags year=2024" });

    // untagging recomputes (trigger) without a second push
    const { error } = await c!.client.from("post_tags").delete().eq("post_id", q3.id).eq("user_id", c!.id);
    expect(error).toBeNull();
    await sql(`update public.jobs set run_at = now() where dedupe_key = $1 and status = 'queued'`, [`year.recompute:${story.id}`]);
    await w.runner.runUntilIdle({ kinds: ["year.recompute", "push.year_story"] });
    const [after] = await sql(`select data from public.year_stories where id = $1`, [story.id]);
    expect(after.data.self_tagged).toEqual([q1.id, q3.id]); // b is still in q3
    await b!.client.from("post_tags").delete().eq("post_id", q3.id).eq("user_id", b!.id);
    await sql(`update public.jobs set run_at = now() where dedupe_key = $1 and status = 'queued'`, [`year.recompute:${story.id}`]);
    await w.runner.runUntilIdle({ kinds: ["year.recompute", "push.year_story"] });
    const [last] = await sql(`select data from public.year_stories where id = $1`, [story.id]);
    expect(last.data.self_tagged).toEqual([q1.id]);
    expect(sent()).toHaveLength(1);
  });
});
