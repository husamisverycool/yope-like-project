// Several photos in one post (owner decision 34, research #1; migration 0051).
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { closeDb, createGroup, createMedia, createUsers, expectRpcError, rpc, setConfig, sql, type TestGroup, type TestUser } from './helpers';

let a: TestUser, b: TestUser;
let g: TestGroup, h: TestGroup;

beforeAll(async () => {
  [a, b] = await createUsers(2, 'Batch');
  g = await createGroup(a, [b]);
  h = await createGroup(a, [b]);
});

afterAll(closeDb);

async function postIn(user: TestUser, groups: string[], batchId?: string) {
  const media = await createMedia(user, batchId ? { batchId } : {});
  return rpc<any[]>(user.client, 'create_post', { p_media_id: media.id, p_group_ids: groups });
}

const pushJobs = (groupId: string, authorId: string) =>
  sql(`select payload, run_at, dedupe_key from public.jobs where kind = 'push.new_post' and status = 'queued'
        and payload ->> 'group_id' = $1 and payload ->> 'author_id' = $2 order by id`, [groupId, authorId]);

describe('photo batches', () => {
  it('photos sent together share batch_id and make one push per group, a few seconds later', async () => {
    const batch = randomUUID();
    const before = Date.now();
    const posts = [];
    for (let i = 0; i < 3; i++) posts.push(...(await postIn(a, [g.id, h.id], batch)));
    expect(new Set(posts.map((p) => p.batch_id))).toEqual(new Set([batch]));
    for (const group of [g.id, h.id]) {
      const jobs = (await pushJobs(group, a.id)).filter((j: any) => j.dedupe_key?.includes(batch));
      expect(jobs).toHaveLength(1);
      expect(new Date(jobs[0].run_at).getTime()).toBeGreaterThan(before + 5_000);
      // the newest photo of the batch in that group
      expect(jobs[0].payload.post_id).toBe(posts.filter((p) => p.group_id === group).at(-1).id);
    }
  });

  it('a single photo is pushed at once, as before', async () => {
    const [p] = await postIn(b, [g.id]);
    expect(p.batch_id).toBeNull();
    const jobs = (await pushJobs(g.id, b.id)).filter((j: any) => j.payload.post_id === p.id);
    expect(jobs).toHaveLength(1);
    expect(jobs[0].dedupe_key).toBeNull();
  });

  it('at most batch_max_photos per batch and group', async () => {
    await setConfig('batch_max_photos', 2);
    try {
      const batch = randomUUID();
      await postIn(a, [g.id], batch);
      await postIn(a, [g.id], batch);
      const third = await createMedia(a, { batchId: batch });
      await expectRpcError(rpc(a.client, 'create_post', { p_media_id: third.id, p_group_ids: [g.id] }), 'invalid_items', 400);
      // another author's photos never count toward someone's batch
      await postIn(b, [g.id], batch);
    } finally {
      await setConfig('batch_max_photos', 20);
    }
  });
});
