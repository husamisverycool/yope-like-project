// report() reaches every surface with user- or group-made content (migration 0032): a plan, a birthday
// video, a year story, a collage and a weekly recap — for members of their group only.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { closeDb, createUsers, expectRpcError, jobsWhere, rpc, sql, type TestUser } from './helpers';
import { seedFullGroup, type SeededGroup } from './security/world';

let users: TestUser[];
let outsider: TestUser;
let seeded: SeededGroup;

beforeAll(async () => {
  users = await createUsers(5, 'Rep');
  outsider = users[4];
  seeded = await seedFullGroup(users.slice(0, 4), 'Reported');
  // the birthday video is delivered (c is its honoree, a contributed)
  await sql(`update public.tributes set delivered_at = now() - interval '1 minute' where id = $1`, [seeded.tributeId]);
});
afterAll(closeDb);

describe('report: plans, birthday videos, year stories, collages, recaps', () => {
  it('a member reports each kind; the report reaches moderation', async () => {
    const [, b, c] = users;
    const targets: Array<[string, string, TestUser]> = [
      ['plan', seeded.planId, b], // a's plan
      ['tribute', seeded.tributeId, c], // the honoree
      ['year_story', seeded.yearStoryId, b],
      ['collage', seeded.collageId, b],
      ['recap', seeded.recapId, c],
    ];
    for (const [kind, id, reporter] of targets) {
      const report = await rpc<string>(reporter.client, 'report', { p_target_kind: kind, p_target_id: id, p_reason: 'Other' });
      const [row] = await sql(`select target_kind::text as kind, target_id from public.reports where id = $1`, [report]);
      expect(row, kind).toEqual({ kind, target_id: id });
      expect(await jobsWhere('moderation.report', { report_id: report }), kind).toHaveLength(1);
    }
  });

  it('nobody outside the group can report them, and a maker cannot report their own plan', async () => {
    for (const [kind, id] of [
      ['plan', seeded.planId],
      ['tribute', seeded.tributeId],
      ['year_story', seeded.yearStoryId],
      ['collage', seeded.collageId],
      ['recap', seeded.recapId],
    ]) {
      await expectRpcError(rpc(outsider.client, 'report', { p_target_kind: kind, p_target_id: id, p_reason: 'x' }), 'target_not_found', 404);
    }
    await expectRpcError(rpc(users[0].client, 'report', { p_target_kind: 'plan', p_target_id: seeded.planId, p_reason: 'x' }), 'target_not_found', 404);
  });
});
