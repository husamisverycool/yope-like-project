// Groups hold at most max_group_members (30) people, enforced in the database
// and race-safe under concurrent joins.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { closeDb, createUsers, expectRpcError, getConfig, rpc, RpcError, sql, type TestUser } from '../helpers';

let owner: TestUser;
let joiners: TestUser[];
let racers: TestUser[];
let groupId: string;
let token: string;

beforeAll(async () => {
  expect(await getConfig('max_group_members')).toBe(30);
  const users = await createUsers(36, 'Cap');
  owner = users[0];
  joiners = users.slice(1, 28); // 27 joiners -> 28 members
  racers = users.slice(28); // 8 concurrent joiners for the last 2 seats
  const g = await rpc(owner.client, 'create_group', { p_name: 'Full house', p_kind: 'family', p_time_zone: 'UTC' });
  groupId = g.id;
  token = (await rpc(owner.client, 'create_invite', { p_group_id: groupId })).token;
  for (const u of joiners) await rpc(u.client, 'join_group', { p_token: token });
});

afterAll(closeDb);

describe('member cap', () => {
  it('concurrent joins never exceed 30 members', async () => {
    const results = await Promise.allSettled(racers.map((u) => rpc(u.client, 'join_group', { p_token: token })));
    const ok = results.filter((r) => r.status === 'fulfilled');
    const failed = results.filter((r) => r.status === 'rejected') as PromiseRejectedResult[];
    expect(ok).toHaveLength(2);
    expect(failed).toHaveLength(racers.length - 2);
    for (const f of failed) {
      expect(f.reason).toBeInstanceOf(RpcError);
      expect(f.reason.code).toBe('group_full');
      expect(f.reason.status).toBe(409);
    }
    const [{ n }] = await sql<{ n: number }>(`select count(*)::int as n from public.group_members where group_id = $1`, [groupId]);
    expect(n).toBe(30);
  });

  it('joining again as a member of a full group is idempotent', async () => {
    const g = await rpc(joiners[0].client, 'join_group', { p_token: token });
    expect(g.id).toBe(groupId);
  });

  it('direct inserts are refused too (service role, trigger-enforced)', async () => {
    const [extra] = await createUsers(1, 'Extra');
    await expect(
      sql(`insert into public.group_members (group_id, user_id) values ($1, $2)`, [groupId, extra.id]),
    ).rejects.toThrow(/group_full/);
  });

  it('a seat frees up when someone leaves', async () => {
    const late = racers.filter(() => true);
    const outside: TestUser[] = [];
    for (const u of late) {
      const rows = await sql(`select 1 from public.group_members where group_id = $1 and user_id = $2`, [groupId, u.id]);
      if (rows.length === 0) outside.push(u);
    }
    await expectRpcError(rpc(outside[0].client, 'join_group', { p_token: token }), 'group_full', 409);
    await rpc(joiners[1].client, 'leave_group', { p_group_id: groupId });
    const g = await rpc(outside[0].client, 'join_group', { p_token: token });
    expect(g.id).toBe(groupId);
  });
});
