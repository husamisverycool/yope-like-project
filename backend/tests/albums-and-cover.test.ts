// Albums anyone in the group can add to (Apple Shared Albums: add any photo; remove your own, the owner removes any)
// and a photo of the group as its cover (Google Photos "Use as → Album cover"; admins, update_group's rule).
// Migration 0039. Group isolation, blocks and the deletion cascade.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  closeDb,
  createGroup,
  createUsers,
  expectRpcError,
  jobsWhere,
  postPhoto,
  rpc,
  select,
  sql,
  upload,
  type TestGroup,
  type TestUser,
} from './helpers';

let a: TestUser, b: TestUser, c: TestUser, stranger: TestUser;
let g: TestGroup, other: TestGroup;

beforeAll(async () => {
  [a, b, c, stranger] = await createUsers(4, 'AlbAdd');
  g = await createGroup(a, [b, c], { tz: 'UTC' }); // a is the admin
  other = await createGroup(stranger, [], { tz: 'UTC' });
});

afterAll(closeDb);

const items = async (u: TestUser, albumId: string) =>
  (await select(u.client, 'album_items', (q) => q.eq('album_id', albumId).order('position'))).map((r: any) => r.post_id);

describe('albums anyone can add to', () => {
  it('any member adds photos of the group (from any week), skipping ones already in; order is kept', async () => {
    const p = [];
    for (let i = 0; i < 4; i++) p.push((await postPhoto(i % 2 ? b : a, [g.id])).posts[0].id as string);
    // two of them from weeks long ago: an album takes photos from any weeks
    await sql(`update public.posts set created_at = '2025-01-06T12:00:00Z' where id = $1`, [p[0]]);
    await sql(`update public.posts set created_at = '2026-03-02T12:00:00Z' where id = $1`, [p[3]]);
    const album = await rpc(b.client, 'save_album', { p_group_id: g.id, p_name: 'Trips', p_post_ids: [p[3], p[0]] });
    expect(await items(c, album.id)).toEqual([p[3], p[0]]);

    const after = await rpc(c.client, 'add_to_album', { p_album_id: album.id, p_post_ids: [p[1], p[0], p[2]] });
    expect(after.id).toBe(album.id);
    expect(new Date(after.updated_at).getTime()).toBeGreaterThanOrEqual(new Date(album.updated_at).getTime());
    expect(await items(a, album.id)).toEqual([p[3], p[0], p[1], p[2]]);
    const rows = await select(a.client, 'album_items', (q) => q.eq('album_id', album.id));
    const by = Object.fromEntries(rows.map((r: any) => [r.post_id, r.added_by]));
    expect(by).toEqual({ [p[3]]: b.id, [p[0]]: b.id, [p[1]]: c.id, [p[2]]: c.id });

    // idempotent: adding again changes nothing
    await rpc(c.client, 'add_to_album', { p_album_id: album.id, p_post_ids: [p[1]] });
    expect(await items(a, album.id)).toEqual([p[3], p[0], p[1], p[2]]);
  });

  it('only photos of that group the caller can see; only members', async () => {
    const mine = (await postPhoto(a, [g.id])).posts[0].id;
    const album = await rpc(a.client, 'save_album', { p_group_id: g.id, p_name: 'Mix', p_post_ids: [mine] });
    const elsewhere = (await postPhoto(stranger, [other.id])).posts[0].id;
    await expectRpcError(rpc(b.client, 'add_to_album', { p_album_id: album.id, p_post_ids: [elsewhere] }), 'invalid_items', 400);
    await expectRpcError(rpc(b.client, 'add_to_album', { p_album_id: album.id, p_post_ids: [] }), 'invalid_items', 400);
    await expectRpcError(rpc(b.client, 'add_to_album', { p_album_id: album.id, p_post_ids: [mine, mine] }), 'invalid_items', 400);
    await expectRpcError(rpc(stranger.client, 'add_to_album', { p_album_id: album.id, p_post_ids: [elsewhere] }), 'album_not_found', 404);
    await expectRpcError(rpc(stranger.client, 'remove_from_album', { p_album_id: album.id, p_post_ids: [mine] }), 'album_not_found', 404);
    expect(await select(stranger.client, 'album_items', (q) => q.eq('album_id', album.id))).toEqual([]);

    // a photo by someone the caller blocked cannot be added by them
    const byC = (await postPhoto(c, [g.id])).posts[0].id;
    await rpc(b.client, 'block_user', { p_user_id: c.id });
    await expectRpcError(rpc(b.client, 'add_to_album', { p_album_id: album.id, p_post_ids: [byC] }), 'invalid_items', 400);
    await rpc(b.client, 'unblock_user', { p_user_id: c.id });
  });

  it('you remove what you added; the album creator and admins remove anything; the photo stays', async () => {
    const pa = (await postPhoto(a, [g.id])).posts[0].id;
    const pb = (await postPhoto(b, [g.id])).posts[0].id;
    const pc = (await postPhoto(c, [g.id])).posts[0].id;
    const album = await rpc(b.client, 'save_album', { p_group_id: g.id, p_name: 'Rules', p_post_ids: [pb] });
    await rpc(c.client, 'add_to_album', { p_album_id: album.id, p_post_ids: [pc, pa] });

    // c is neither the creator nor an admin: may not remove b's item (nothing is removed)
    await expectRpcError(rpc(c.client, 'remove_from_album', { p_album_id: album.id, p_post_ids: [pb, pc] }), 'not_allowed', 403);
    expect(await items(c, album.id)).toEqual([pb, pc, pa]);
    // c removes their own
    await rpc(c.client, 'remove_from_album', { p_album_id: album.id, p_post_ids: [pc] });
    expect(await items(c, album.id)).toEqual([pb, pa]);
    // b (the creator) removes what c added; a (admin) removes what b added
    await rpc(b.client, 'remove_from_album', { p_album_id: album.id, p_post_ids: [pa] });
    await rpc(a.client, 'remove_from_album', { p_album_id: album.id, p_post_ids: [pb] });
    expect(await items(a, album.id)).toEqual([]);
    // the photos are still in the group
    expect((await select(c.client, 'posts', (q) => q.in('id', [pa, pb, pc]))).length).toBe(3);
    await expectRpcError(rpc(b.client, 'remove_from_album', { p_album_id: album.id, p_post_ids: [] }), 'invalid_items', 400);
  });

  it('deleting a photo removes it from every album it was added to', async () => {
    const p = await postPhoto(c, [g.id]);
    const keep = (await postPhoto(a, [g.id])).posts[0].id;
    const one = await rpc(a.client, 'save_album', { p_group_id: g.id, p_name: 'One', p_post_ids: [keep] });
    const two = await rpc(b.client, 'save_album', { p_group_id: g.id, p_name: 'Two', p_post_ids: [keep] });
    await rpc(b.client, 'add_to_album', { p_album_id: one.id, p_post_ids: [p.posts[0].id] });
    await rpc(a.client, 'add_to_album', { p_album_id: two.id, p_post_ids: [p.posts[0].id] });
    await rpc(c.client, 'delete_media', { p_media_id: p.media.id });
    expect(await sql(`select 1 from public.album_items where post_id = $1`, [p.posts[0].id])).toEqual([]);
    expect(await items(a, one.id)).toEqual([keep]);
    expect(await items(a, two.id)).toEqual([keep]);
  });
});

describe('a photo as the group cover', () => {
  async function withRendition(user: TestUser, groupId: string) {
    const p = await postPhoto(user, [groupId]);
    const display = `u/${user.id}/${p.media.id}/r/display.jpg`;
    await upload(user, display);
    await sql(`update public.media set display_path = $2, renditions_ready_at = now() where id = $1`, [p.media.id, display]);
    return { post: p.posts[0].id as string, media: p.media.id, display };
  }

  it('admins set any visible photo of the group as its cover; members may not', async () => {
    const photo = await withRendition(b, g.id);
    await expectRpcError(rpc(b.client, 'set_group_cover_from_post', { p_group_id: g.id, p_post_id: photo.post }), 'not_group_admin', 403);
    await expectRpcError(rpc(stranger.client, 'set_group_cover_from_post', { p_group_id: g.id, p_post_id: photo.post }), 'not_group_member', 403);
    const elsewhere = await withRendition(stranger, other.id);
    await expectRpcError(rpc(a.client, 'set_group_cover_from_post', { p_group_id: g.id, p_post_id: elsewhere.post }), 'post_not_found', 404);
    const noRendition = (await postPhoto(c, [g.id])).posts[0].id;
    await expectRpcError(rpc(a.client, 'set_group_cover_from_post', { p_group_id: g.id, p_post_id: noRendition }), 'media_not_ready', 409);

    const grp = await rpc(a.client, 'set_group_cover_from_post', { p_group_id: g.id, p_post_id: photo.post });
    expect(grp).toMatchObject({ cover_path: photo.display, cover_post_id: photo.post });
    // every member can read the cover image (they can see the photo)
    const signed = await c.client.storage.from('media').createSignedUrl(photo.display, 60);
    expect(signed.error).toBeNull();
    // and the outsider cannot
    expect((await stranger.client.storage.from('media').createSignedUrl(photo.display, 60)).error).not.toBeNull();
  });

  it('replacing it never deletes the photo; an uploaded cover replaced by a photo is deleted; a new upload forgets the photo', async () => {
    const [x, y] = await createUsers(2, 'AlbCov');
    const cg = await createGroup(x, [y], { tz: 'UTC' });
    const uploaded = `u/${x.id}/covers/${crypto.randomUUID()}.jpg`;
    await upload(x, uploaded);
    await rpc(x.client, 'update_group', { p_group_id: cg.id, p_cover_path: uploaded });

    const photo = await withRendition(y, cg.id);
    await rpc(x.client, 'set_group_cover_from_post', { p_group_id: cg.id, p_post_id: photo.post });
    expect((await jobsWhere('storage.delete', { paths: [uploaded] })).length).toBe(1);

    const second = await withRendition(x, cg.id);
    await rpc(x.client, 'set_group_cover_from_post', { p_group_id: cg.id, p_post_id: second.post });
    expect(await jobsWhere('storage.delete', { paths: [photo.display] })).toEqual([]);

    const fresh = `u/${x.id}/covers/${crypto.randomUUID()}.jpg`;
    await upload(x, fresh);
    const after = await rpc(x.client, 'update_group', { p_group_id: cg.id, p_cover_path: fresh });
    expect(after).toMatchObject({ cover_path: fresh, cover_post_id: null });
    expect(await jobsWhere('storage.delete', { paths: [second.display] })).toEqual([]);
  });

  it('deleting the cover photo removes it as the cover; deleting the group never deletes the photo file', async () => {
    const [x, y, z] = await createUsers(3, 'AlbCovDel');
    const cg = await createGroup(x, [y], { tz: 'UTC' });
    const photo = await withRendition(y, cg.id);
    await rpc(x.client, 'set_group_cover_from_post', { p_group_id: cg.id, p_post_id: photo.post });
    await rpc(y.client, 'delete_post', { p_post_id: photo.post });
    const [row] = await select(x.client, 'groups', (q) => q.eq('id', cg.id));
    expect(row).toMatchObject({ cover_path: null, cover_post_id: null });

    // a photo in two groups, cover of one: that group goes, the photo (and its rendition) stays in the other
    const two = await createGroup(z, [], { tz: 'UTC' });
    const shared = await postPhoto(z, [two.id]);
    const display = `u/${z.id}/${shared.media.id}/r/display.jpg`;
    await upload(z, display);
    await sql(`update public.media set display_path = $2, renditions_ready_at = now() where id = $1`, [shared.media.id, display]);
    const solo = await createGroup(z, [], { tz: 'UTC' });
    const [post2] = await rpc<any[]>(z.client, 'create_post', { p_media_id: shared.media.id, p_group_ids: [solo.id] });
    await rpc(z.client, 'set_group_cover_from_post', { p_group_id: solo.id, p_post_id: post2.id });
    await rpc(z.client, 'leave_group', { p_group_id: solo.id }); // last member: the group is deleted
    expect(await jobsWhere('storage.delete', { paths: [display] })).toEqual([]);
    expect((await select(z.client, 'posts', (q) => q.eq('media_id', shared.media.id))).length).toBe(1);
  });
});
