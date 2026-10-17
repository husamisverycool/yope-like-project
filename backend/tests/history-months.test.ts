// group_history_months (migration 0045): the months of a group's history (BeReal's Memories calendar: only days with
// something can be opened) and the week to jump to. Group isolation and blocks.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { closeDb, createGroup, createUsers, expectRpcError, postPhoto, rpc, sql, type TestUser } from './helpers';

let a: TestUser, b: TestUser, stranger: TestUser;

const setVisible = (postId: string, iso: string) =>
  sql(`update public.posts set created_at = $2::timestamptz where id = $1`, [postId, iso]);

beforeAll(async () => {
  [a, b, stranger] = await createUsers(3, 'HistMon');
});

afterAll(closeDb);

describe('group_history_months', () => {
  it('months with photos, newest first, their days, and the newest week touching each month', async () => {
    const g = await createGroup(a, [b], { tz: 'America/New_York' });
    const mk = async (who: TestUser, iso: string) => {
      const p = (await postPhoto(who, [g.id])).posts[0];
      await setVisible(p.id, iso);
      return p.id;
    };
    await mk(a, '2026-01-01T03:00:00Z'); // Dec 31, 2025 in New York
    await mk(b, '2026-03-02T15:00:00Z');
    await mk(a, '2026-03-30T15:00:00Z'); // Monday Mar 30: its week starts Mar 30
    const rows = await rpc<any[]>(a.client, 'group_history_months', { p_group_id: g.id });
    expect(rows).toEqual([
      { month: '2026-03-01', days: ['2026-03-02', '2026-03-30'], newest_week: '2026-03-30' },
      { month: '2025-12-01', days: ['2025-12-31'], newest_week: '2025-12-29' },
    ]);
    // jumping: the first week group_history_weeks returns before newest_week + 7 is that week
    const weeks = await rpc<any[]>(a.client, 'group_history_weeks', { p_group_id: g.id, p_before_week: '2026-04-06', p_limit: 1 });
    expect(weeks.map((w) => w.week_start)).toEqual(['2026-03-30']);

    // a block hides that member's photos from the months too
    await rpc(a.client, 'block_user', { p_user_id: b.id });
    expect((await rpc<any[]>(a.client, 'group_history_months', { p_group_id: g.id })).map((r) => [r.month, r.days])).toEqual([
      ['2026-03-01', ['2026-03-30']],
      ['2025-12-01', ['2025-12-31']],
    ]);
    await rpc(a.client, 'unblock_user', { p_user_id: b.id });

    await expectRpcError(rpc(stranger.client, 'group_history_months', { p_group_id: g.id }), 'not_group_member', 403);
  });

  it('an empty group has no months', async () => {
    const g = await createGroup(a, [], { tz: 'UTC' });
    expect(await rpc<any[]>(a.client, 'group_history_months', { p_group_id: g.id })).toEqual([]);
  });
});
