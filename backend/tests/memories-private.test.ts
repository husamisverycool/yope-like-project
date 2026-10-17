// Your memories, for you only (migration 0038): hide a photo or a whole date from On This Day and the Memories widget,
// list and show them again; private favorites that nobody else can read. Group isolation and blocks.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  closeDb,
  createGroup,
  createUsers,
  expectRpcError,
  postPhoto,
  rpc,
  select,
  sql,
  type TestGroup,
  type TestUser,
} from './helpers';

let a: TestUser, b: TestUser, c: TestUser, stranger: TestUser;
let g: TestGroup;

const setCreatedAt = (postId: string, iso: string) =>
  sql(`update public.posts set created_at = $2::timestamptz where id = $1`, [postId, iso]);

beforeAll(async () => {
  [a, b, c, stranger] = await createUsers(4, 'MemPriv');
  g = await createGroup(a, [b, c], { tz: 'UTC' });
});

afterAll(closeDb);

describe('hide a memory', () => {
  it('a hidden photo or day leaves only my On This Day; the others still see it; unhide brings it back', async () => {
    const mk = async (who: TestUser, iso: string) => {
      const p = await postPhoto(who, [g.id]);
      await setCreatedAt(p.posts[0].id, iso);
      return { post: p.posts[0].id as string, media: p.media.id };
    };
    const p2024 = await mk(a, '2024-05-03T12:00:00Z');
    const p2023 = await mk(b, '2023-05-03T09:00:00Z');
    const p2022 = await mk(c, '2022-05-03T18:00:00Z');
    const day = { p_group_id: g.id, p_local_date: '2026-05-03' };
    const ids = async (u: TestUser) => (await rpc<any[]>(u.client, 'on_this_day', day)).map((r) => r.post_id);
    expect(await ids(b)).toEqual([p2024.post, p2023.post, p2022.post]);

    // b hides a's photo (someone else's) and the whole day of 2022
    const h1 = await rpc(b.client, 'hide_memory', { p_media_id: p2024.media });
    const h2 = await rpc(b.client, 'hide_memory', { p_day: '2022-05-03' });
    expect(h1.media_id).toBe(p2024.media);
    expect(h2.day).toBe('2022-05-03');
    // idempotent
    expect((await rpc(b.client, 'hide_memory', { p_media_id: p2024.media })).id).toBe(h1.id);
    expect((await rpc(b.client, 'hide_memory', { p_day: '2022-05-03' })).id).toBe(h2.id);

    expect(await ids(b)).toEqual([p2023.post]);
    expect(await ids(a)).toEqual([p2024.post, p2023.post, p2022.post]);
    expect(await ids(c)).toEqual([p2024.post, p2023.post, p2022.post]);

    // the list in Settings: newest hide first, with the photo's post and thumbnail
    const list = await rpc<any[]>(b.client, 'my_hidden_memories');
    expect(list.map((r) => r.id)).toEqual([h2.id, h1.id]);
    expect(list[1]).toMatchObject({ media_id: p2024.media, post_id: p2024.post, group_id: g.id, kind: 'photo' });
    expect(list[1].thumb_path).toMatch(new RegExp(`^u/${a.id}/${p2024.media}/`));
    expect(list[0]).toMatchObject({ day: '2022-05-03', media_id: null, post_id: null });

    // rows are b's own: nobody else reads them, and b cannot remove someone else's
    expect(await select(a.client, 'memory_hides')).toEqual([]);
    expect((await select(b.client, 'memory_hides')).length).toBe(2);
    const aHide = await rpc(a.client, 'hide_memory', { p_day: '2023-05-03' });
    await rpc(b.client, 'unhide_memory', { p_id: aHide.id });
    expect((await select(a.client, 'memory_hides')).map((r) => r.id)).toEqual([aHide.id]);
    await rpc(a.client, 'unhide_memory', { p_id: aHide.id });

    await rpc(b.client, 'unhide_memory', { p_id: h1.id });
    await rpc(b.client, 'unhide_memory', { p_id: h2.id });
    expect(await ids(b)).toEqual([p2024.post, p2023.post, p2022.post]);
    expect(await rpc<any[]>(b.client, 'my_hidden_memories')).toEqual([]);
  });

  it('the Memories widget (my_memories) leaves out hidden photos and days', async () => {
    const [me, friend] = await createUsers(2, 'MemPrivW');
    const wg = await createGroup(me, [friend], { tz: 'UTC' });
    const old = (await postPhoto(me, [wg.id])).posts[0];
    await setCreatedAt(old.id, '2024-10-17T12:00:00Z');
    const older = await postPhoto(me, [wg.id]);
    await setCreatedAt(older.posts[0].id, '2023-10-17T12:00:00Z');
    const args = { p_from: '2026-10-17', p_days: 1, p_time_zone: 'UTC' };
    const first = async () => (await rpc<any[]>(me.client, 'my_memories', args)).map((r) => r.post_id);
    expect(await first()).toEqual([old.id]);
    const h = await rpc(me.client, 'hide_memory', { p_media_id: old.media_id });
    expect(await first()).toEqual([older.posts[0].id]);
    await rpc(me.client, 'hide_memory', { p_day: '2023-10-17' });
    expect(await first()).toEqual([]);
    await rpc(me.client, 'unhide_memory', { p_id: h.id });
    expect(await first()).toEqual([old.id]);
  });

  it('only photos you can see; exactly one of photo or day; a deleted photo takes its hide with it', async () => {
    const outside = await createGroup(stranger, [], { tz: 'UTC' });
    const theirs = await postPhoto(stranger, [outside.id]);
    await expectRpcError(rpc(a.client, 'hide_memory', { p_media_id: theirs.media.id }), 'media_not_found', 404);
    await expectRpcError(rpc(a.client, 'hide_memory', {}), 'invalid_argument', 400);
    await expectRpcError(
      rpc(a.client, 'hide_memory', { p_media_id: theirs.media.id, p_day: '2020-01-01' }),
      'invalid_argument',
      400,
    );
    await expectRpcError(rpc(a.client, 'hide_memory', { p_day: '2999-01-01' }), 'invalid_argument', 400);

    const mine = await postPhoto(b, [g.id]);
    await rpc(a.client, 'hide_memory', { p_media_id: mine.media.id });
    await rpc(b.client, 'delete_media', { p_media_id: mine.media.id });
    expect(await sql(`select 1 from public.memory_hides where media_id = $1`, [mine.media.id])).toEqual([]);
  });

  it('a hidden photo whose author you blocked is no longer listed (it shows nowhere)', async () => {
    const [x, y] = await createUsers(2, 'MemPrivB');
    const bg = await createGroup(x, [y], { tz: 'UTC' });
    const p = await postPhoto(y, [bg.id]);
    await rpc(x.client, 'hide_memory', { p_media_id: p.media.id });
    expect((await rpc<any[]>(x.client, 'my_hidden_memories')).length).toBe(1);
    await rpc(x.client, 'block_user', { p_user_id: y.id });
    expect(await rpc<any[]>(x.client, 'my_hidden_memories')).toEqual([]);
  });
});

describe('private favorites', () => {
  it('a heart only you see; listed newest first with its group; removable', async () => {
    const p1 = await postPhoto(a, [g.id]);
    const p2 = await postPhoto(c, [g.id]);
    await rpc(b.client, 'set_favorite', { p_media_id: p1.media.id, p_on: true });
    await rpc(b.client, 'set_favorite', { p_media_id: p2.media.id, p_on: true });
    await rpc(b.client, 'set_favorite', { p_media_id: p2.media.id, p_on: true }); // idempotent

    const favs = await rpc<any[]>(b.client, 'my_favorites');
    expect(favs.map((f) => f.media_id)).toEqual([p2.media.id, p1.media.id]);
    expect(favs[0]).toMatchObject({ post_id: p2.posts[0].id, group_id: g.id, group_name: 'Test group', author_id: c.id, kind: 'photo' });
    expect(favs[0].thumb_path).toMatch(new RegExp(`^u/${c.id}/`));

    // never readable by anyone else — not the author, not another member
    for (const other of [a, c, stranger]) {
      expect(await select(other.client, 'favorites')).toEqual([]);
      expect(await rpc<any[]>(other.client, 'my_favorites')).toEqual([]);
    }
    expect((await select(b.client, 'favorites')).length).toBe(2);

    // paging by favorited_at
    const page2 = await rpc<any[]>(b.client, 'my_favorites', { p_before: favs[0].favorited_at, p_limit: 1 });
    expect(page2.map((f) => f.media_id)).toEqual([p1.media.id]);

    await rpc(b.client, 'set_favorite', { p_media_id: p1.media.id, p_on: false });
    expect((await rpc<any[]>(b.client, 'my_favorites')).map((f) => f.media_id)).toEqual([p2.media.id]);
    await rpc(b.client, 'set_favorite', { p_media_id: p2.media.id, p_on: false });
  });

  it('only photos you can see; leaving the group or a block hides them; deleting the photo removes the heart', async () => {
    const [x, y, z] = await createUsers(3, 'MemPrivF');
    const fg = await createGroup(x, [y, z], { tz: 'UTC' });
    const outsiderGroup = await createGroup(stranger, [], { tz: 'UTC' });
    const notMine = await postPhoto(stranger, [outsiderGroup.id]);
    await expectRpcError(rpc(x.client, 'set_favorite', { p_media_id: notMine.media.id, p_on: true }), 'media_not_found', 404);
    await expectRpcError(rpc(x.client, 'set_favorite', { p_media_id: null, p_on: true }), 'invalid_argument', 400);

    const byY = await postPhoto(y, [fg.id]);
    const byZ = await postPhoto(z, [fg.id]);
    await rpc(x.client, 'set_favorite', { p_media_id: byY.media.id, p_on: true });
    await rpc(x.client, 'set_favorite', { p_media_id: byZ.media.id, p_on: true });
    await rpc(x.client, 'block_user', { p_user_id: y.id });
    expect((await rpc<any[]>(x.client, 'my_favorites')).map((f) => f.media_id)).toEqual([byZ.media.id]);
    await rpc(x.client, 'unblock_user', { p_user_id: y.id });

    await rpc(z.client, 'delete_media', { p_media_id: byZ.media.id });
    expect(await sql(`select 1 from public.favorites where media_id = $1`, [byZ.media.id])).toEqual([]);

    await rpc(x.client, 'leave_group', { p_group_id: fg.id });
    expect(await rpc<any[]>(x.client, 'my_favorites')).toEqual([]);
  });

  it('nothing outside the database functions reads favorites (never used for ranking)', async () => {
    const fns = await sql<{ proname: string }>(
      `select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname in ('public', 'private') and p.prosrc ~ 'public\\.favorites'`,
    );
    expect(fns.map((f) => f.proname).sort()).toEqual(['my_favorites', 'set_favorite']);
  });
});
