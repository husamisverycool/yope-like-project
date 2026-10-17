// group_plans (migration 0028): every plan of a group for the plans list — upcoming soonest first,
// then past latest first, then cancelled latest first — with the caller's own answer; members only,
// plans by someone with a block hidden.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { closeDb, createGroup, createUsers, expectRpcError, rpc, sql, type TestGroup, type TestUser } from './helpers';

let a: TestUser, b: TestUser, c: TestUser, stranger: TestUser;
let g: TestGroup;
const days = (n: number) => new Date(Date.now() + n * 86_400_000).toISOString();

beforeAll(async () => {
  [a, b, c, stranger] = await createUsers(4, 'PlanList');
  g = await createGroup(a, [b, c], { tz: 'UTC' });
});
afterAll(closeDb);

async function pastPlan(user: TestUser, title: string, daysAgo: number) {
  const plan = await rpc(user.client, 'create_plan', { p_group_id: g.id, p_title: title, p_starts_at: days(2) });
  await sql(
    `update public.plans set starts_at = now() - make_interval(days => $2), local_date = current_date - $2 where id = $1`,
    [plan.id, daysAgo],
  );
  return plan;
}

describe('group_plans', () => {
  it('lists upcoming (soonest first), then past (latest first), then cancelled, each with its state', async () => {
    const later = await rpc(a.client, 'create_plan', { p_group_id: g.id, p_title: 'Later', p_starts_at: days(20) });
    const sooner = await rpc(b.client, 'create_plan', { p_group_id: g.id, p_title: 'Sooner', p_starts_at: days(2) });
    const longAgo = await pastPlan(a, 'Long ago', 40);
    const lastWeek = await pastPlan(b, 'Last week', 7);
    const canceledSoon = await rpc(a.client, 'create_plan', { p_group_id: g.id, p_title: 'Off soon', p_starts_at: days(3) });
    await rpc(a.client, 'cancel_plan', { p_plan_id: canceledSoon.id });
    const canceledLater = await rpc(a.client, 'create_plan', { p_group_id: g.id, p_title: 'Off later', p_starts_at: days(9) });
    await rpc(a.client, 'cancel_plan', { p_plan_id: canceledLater.id });
    await rpc(c.client, 'answer_plan', { p_plan_id: sooner.id, p_answer: 'maybe' });

    const rows = await rpc<any[]>(c.client, 'group_plans', { p_group_id: g.id });
    expect(rows.map((r) => [r.title, r.state])).toEqual([
      ['Sooner', 'upcoming'],
      ['Later', 'upcoming'],
      ['Last week', 'past'],
      ['Long ago', 'past'],
      ['Off later', 'canceled'],
      ['Off soon', 'canceled'],
    ]);
    expect(rows.find((r) => r.id === sooner.id).my_answer).toBe('maybe');
    expect(rows.find((r) => r.id === later.id).my_answer).toBeNull();
    expect(rows.find((r) => r.id === canceledSoon.id).canceled_at).not.toBeNull();
    // the maker's own answer comes with their plans
    expect((await rpc<any[]>(a.client, 'group_plans', { p_group_id: g.id })).find((r) => r.id === later.id).my_answer).toBe('going');
    expect([longAgo.id, lastWeek.id].every((id) => rows.some((r) => r.id === id))).toBe(true);
  });

  it('is for members only, and hides plans made by someone with a block', async () => {
    await expectRpcError(rpc(stranger.client, 'group_plans', { p_group_id: g.id }), 'not_group_member', 403);
    const blocked = await rpc(b.client, 'create_plan', { p_group_id: g.id, p_title: 'From b', p_starts_at: days(5) });
    await rpc(c.client, 'block_user', { p_user_id: b.id });
    const seen = (await rpc<any[]>(c.client, 'group_plans', { p_group_id: g.id })).map((r) => r.id);
    expect(seen).not.toContain(blocked.id);
    expect((await rpc<any[]>(a.client, 'group_plans', { p_group_id: g.id })).map((r) => r.id)).toContain(blocked.id);
    await rpc(c.client, 'unblock_user', { p_user_id: b.id });
  });
});
