// (e) Weekly recap: the fallback path without an API key, and the AI path with a mocked model
// (structured draft, copy-rule check, refusal, cost logged per job to ai_cost_log).
import { afterAll, afterEach, beforeAll, describe, expect, it } from "vitest";
import type { RecapInput, RecapModel, RecapModelResult } from "../../src/recap/ai.js";
import { closeDb, createGroup, createUsers, getConfig, parkQueuedJobs, postPhoto, rpc, setConfig, sql, type TestGroup, type TestUser } from "../helpers/db.js";
import { apnsDeviceSends, startWorld, type World } from "../helpers/world.js";
import { registerDevice } from "../helpers/db.js";

const WEEK_START = "2026-09-07"; // a Monday
let u: TestUser[];
let recapTimeBefore: unknown;

/** A group with a week of photos: a moment everyone answered, a reacted photo, an ordinary one. */
async function weekGroup(name: string): Promise<{ g: TestGroup; moment: string[]; reacted: string; plain: string }> {
  const g = await createGroup(u[0]!, u.slice(1), { name, tz: "Europe/Paris" });
  const [inv] = await sql(
    `insert into public.daily_invitations (group_id, local_date, fires_at, closes_at, status)
     values ($1, date '2026-09-09', timestamptz '2026-09-09 18:00:00+02', timestamptz '2026-09-09 18:02:00+02', 'closed') returning id`,
    [g.id],
  );
  const plain = (await postPhoto(u[0]!, [g.id], {}, { seed: 1 })).post.id;
  const reacted = (await postPhoto(u[1]!, [g.id], { p_caption: "the lake" }, { seed: 2 })).post.id;
  const moment: string[] = [];
  for (const [i, m] of u.entries()) moment.push((await postPhoto(m, [g.id], {}, { seed: 10 + i })).post.id);
  // backdate everything into the week of WEEK_START (group-local)
  await sql(`update public.posts set created_at = timestamptz '2026-09-08 09:00:00+02' where id = $1`, [plain]);
  await sql(`update public.posts set created_at = timestamptz '2026-09-12 12:00:00+02' where id = $1`, [reacted]);
  for (const [i, id] of moment.entries()) {
    await sql(`update public.posts set created_at = timestamptz '2026-09-09 18:00:30+02' + make_interval(secs => $2), in_window = true, invitation_id = $3 where id = $1`, [id, i, inv.id]);
  }
  await sql(`update public.group_members set joined_at = timestamptz '2026-09-01 00:00:00+02' where group_id = $1`, [g.id]);
  await rpc(u[2]!.client, "react", { p_post_id: reacted, p_emoji: "🔥" });
  await rpc(u[0]!.client, "react", { p_post_id: reacted, p_emoji: "😍" });
  return { g, moment, reacted, plain };
}

async function createRecap(groupId: string): Promise<string> {
  // the recap moment after that week: Sunday 2026-09-13 at the configured time
  await rpc(u[0]!.client, "set_group_muted", { p_group_id: groupId, p_muted: false });
  const rows = await rpc<any[]>(rpc.length ? (await import("../helpers/db.js")).admin : (null as any), "due_weekly_recaps", { p_now: "2026-09-13T20:00:00Z" });
  const mine = rows.find((r) => r.group_id === groupId);
  expect(mine, "recap created").toBeDefined();
  return mine.id;
}

beforeAll(async () => {
  await parkQueuedJobs();
  u = await createUsers(3, "Recap");
  recapTimeBefore = await getConfig("weekly_recap_local_time");
  await setConfig("weekly_recap_local_time", "18:00");
});
afterAll(async () => {
  await setConfig("weekly_recap_local_time", recapTimeBefore);
  await closeDb();
});

describe("without an API key", () => {
  let w: World;
  beforeAll(async () => {
    w = await startWorld({ recapModel: null });
  });
  afterAll(async () => w.close());

  it("orders deterministically (moment everyone shared, then most-reacted, then time), uses the template text, logs no AI cost, notifies members", async () => {
    const { g, moment, reacted, plain } = await weekGroup("Recap fallback");
    const ios = await registerDevice(u[1]!, "ios");
    const recapId = await createRecap(g.id);
    await w.runner.runUntilIdle({ kinds: ["recap.generate", "push.recap_ready"] });
    const [r] = await sql(`select * from public.weekly_recaps where id = $1`, [recapId]);
    expect(r.week_start.toISOString?.().slice(0, 10) ?? r.week_start).toBeDefined();
    expect(r.status).toBe("ready");
    expect(r.items).toEqual([...moment, reacted, plain]);
    expect(r.text).toBe("[week.recap.template] group=Recap fallback");
    expect(await sql(`select 1 from public.ai_cost_log where group_id = $1`, [g.id])).toHaveLength(0);
    // no number reaches a client-readable column
    expect(JSON.stringify(r)).not.toMatch(/"reactions"|"count"/);
    const push = apnsDeviceSends(w.apns).find((s) => s.token === ios.push_token)!;
    expect(push.payload).toMatchObject({ type: "recap_ready", recap_id: recapId, group_id: g.id });
  });
});

describe("with a (mocked) model", () => {
  let calls: RecapInput[] = [];
  let next: (input: RecapInput) => RecapModelResult;
  const model: RecapModel = {
    model: "claude-opus-5-5",
    async draft(input) {
      calls.push(input);
      return next(input);
    },
  };
  let w: World;
  beforeAll(async () => {
    w = await startWorld({ recapModel: model });
  });
  afterAll(async () => w.close());
  afterEach(() => {
    calls = [];
  });
  const usage = [{ model: "claude-opus-5-5", inputTokens: 1800, outputTokens: 240, cacheReadTokens: 0, cacheWriteTokens: 0 }];

  it("uses the AI order and text when the text passes the copy rules; logs tokens and cost", async () => {
    const { g, reacted, plain } = await weekGroup("Recap ai");
    next = (input) => ({ draft: { items: [input.photos.find((p) => p.caption === "the lake")!.ref, input.photos[0]!.ref], text: "you found the lake together." }, refused: false, stopReason: "end_turn", model: "claude-opus-5-5", usage });
    const recapId = await createRecap(g.id);
    await w.runner.runUntilIdle({ kinds: ["recap.generate"] });
    expect(calls).toHaveLength(1);
    // only this group's week: references, local times, captions, reaction totals
    expect(calls[0]!.photos.map((p) => p.caption)).toContain("the lake");
    expect(JSON.stringify(calls[0])).not.toContain(g.id);
    expect(JSON.stringify(calls[0])).not.toContain(u[0]!.id);
    expect(calls[0]!.moments).toEqual([{ ref: "m1", local_time: "wed 18:00", answered_by_everyone: true }]);
    const [r] = await sql(`select * from public.weekly_recaps where id = $1`, [recapId]);
    expect(r.items).toEqual([reacted, plain]);
    expect(r.text).toBe("you found the lake together.");
    const [cost] = await sql(`select * from public.ai_cost_log where group_id = $1`, [g.id]);
    expect(cost).toMatchObject({ purpose: "recap", model: "claude-opus-5-5", input_tokens: 1800, output_tokens: 240 });
    expect(Number(cost.cost_usd)).toBeCloseTo(1800 * 4e-6 + 240 * 20e-6, 6);
    expect(Number(cost.job_id)).toBeGreaterThan(0);
  });

  it("falls back to the template text when the AI text breaks the copy rules", async () => {
    const { g } = await weekGroup("Recap counts");
    next = (input) => ({ draft: { items: input.photos.map((p) => p.ref), text: "You posted 5 photos this week!" }, refused: false, stopReason: "end_turn", model: "claude-opus-5-5", usage });
    const recapId = await createRecap(g.id);
    await w.runner.runUntilIdle({ kinds: ["recap.generate"] });
    const [r] = await sql(`select text from public.weekly_recaps where id = $1`, [recapId]);
    expect(r.text).toBe("[week.recap.template] group=Recap counts");
  });

  it("falls back to the deterministic recap on a refusal (cost still logged)", async () => {
    const { g, moment, reacted, plain } = await weekGroup("Recap refused");
    next = () => ({ draft: null, refused: true, stopReason: "refusal", model: "claude-opus-5-5", usage: [{ ...usage[0]!, outputTokens: 0 }] });
    const recapId = await createRecap(g.id);
    await w.runner.runUntilIdle({ kinds: ["recap.generate"] });
    const [r] = await sql(`select items, text from public.weekly_recaps where id = $1`, [recapId]);
    expect(r.items).toEqual([...moment, reacted, plain]);
    expect(r.text).toBe("[week.recap.template] group=Recap refused");
    expect(await sql(`select 1 from public.ai_cost_log where group_id = $1`, [g.id])).toHaveLength(1);
  });
});
