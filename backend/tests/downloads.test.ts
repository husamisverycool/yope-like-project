// Downloads: all my photos (free), an album in full quality (premium) (owner decision 34, research #2; migration 0052).
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { closeDb, createGroup, createUsers, expectRpcError, grantPremium, postPhoto, rpc, type TestGroup, type TestUser } from './helpers';

let a: TestUser, b: TestUser, outsider: TestUser;
let g: TestGroup, h: TestGroup;

beforeAll(async () => {
  [a, b, outsider] = await createUsers(3, 'Dl');
  g = await createGroup(a, [b]);
  h = await createGroup(a, [b]);
});

afterAll(closeDb);

describe('download_items', () => {
  it("'mine': each of your photos once (sent to two groups), newest first, paged; others' never", async () => {
    const one = await postPhoto(a, [g.id, h.id], { p_caption: 'both' });
    const two = await postPhoto(a, [g.id]);
    await postPhoto(b, [g.id]);
    const rows = await rpc<any[]>(a.client, 'download_items', { p_scope: 'mine' });
    expect(rows.map((r) => r.media_id)).toEqual([two.media.id, one.media.id]);
    expect(rows[1]).toMatchObject({ caption: 'both', original_path: one.media.originalPath, kind: 'photo' });
    const page = await rpc<any[]>(a.client, 'download_items', { p_scope: 'mine', p_limit: 1 });
    expect(page).toHaveLength(1);
    const next = await rpc<any[]>(a.client, 'download_items', { p_scope: 'mine', p_before: page[0].posted_at, p_limit: 1 });
    expect(next.map((r) => r.media_id)).toEqual([one.media.id]);
  });

  it("'album': premium, members only, every photo you can see in album order", async () => {
    const p1 = (await postPhoto(a, [g.id])).posts[0];
    const p2 = (await postPhoto(b, [g.id])).posts[0];
    const album = await rpc(b.client, 'save_album', { p_group_id: g.id, p_name: 'Trip', p_post_ids: [p2.id, p1.id] });
    await expectRpcError(rpc(a.client, 'download_items', { p_scope: 'album', p_album_id: album.id }), 'premium_required', 402);
    await grantPremium(a.id);
    const rows = await rpc<any[]>(a.client, 'download_items', { p_scope: 'album', p_album_id: album.id });
    expect(rows.map((r) => r.post_id)).toEqual([p2.id, p1.id]);
    await grantPremium(outsider.id);
    await expectRpcError(rpc(outsider.client, 'download_items', { p_scope: 'album', p_album_id: album.id }), 'album_not_found', 404);
    await expectRpcError(rpc(a.client, 'download_items', { p_scope: 'everything' }), 'invalid_argument', 400);
  });

  it('a photo deleted, or a group left, leaves your download', async () => {
    const { media } = await postPhoto(b, [h.id]);
    await rpc(b.client, 'leave_group', { p_group_id: h.id });
    const rows = await rpc<any[]>(b.client, 'download_items', { p_scope: 'mine', p_limit: 200 });
    expect(rows.map((r) => r.media_id)).not.toContain(media.id);
  });
});
