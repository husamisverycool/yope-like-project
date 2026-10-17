// The widgets' functions (migration 0036): widget_people (the friend widget's picker), newest_photos_of (one
// friend's newest photos, by author or "I'm in this" self-tag) and my_memories (your own photos from this day in
// earlier years). Group isolation and blocks in both directions.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { closeDb, createGroup, createUsers, expectRpcError, postPhoto, rpc, sql, type TestGroup, type TestUser } from './helpers';

let a: TestUser, b: TestUser, c: TestUser, d: TestUser, stranger: TestUser;
let ab: TestGroup, abc: TestGroup, cd: TestGroup;

const setCreatedAt = (postId: string, iso: string) =>
  sql(`update public.posts set created_at = $2::timestamptz where id = $1`, [postId, iso]);

beforeAll(async () => {
  [a, b, c, d, stranger] = await createUsers(5, 'Wdg');
  ab = await createGroup(a, [b], { name: 'A and B', tz: 'UTC' });
  abc = await createGroup(a, [b, c], { name: 'A B C', tz: 'UTC' });
  cd = await createGroup(c, [d], { name: 'C and D', tz: 'UTC' });
});

afterAll(closeDb);

describe('widget_people', () => {
  it('lists everyone who shares a group with the caller, never the caller, a stranger or a blocked person', async () => {
    const ids = (await rpc<any[]>(a.client, 'widget_people')).map((p) => p.user_id);
    expect(ids.sort()).toEqual([b.id, c.id].sort());
    // c shares groups with a, b and d
    expect((await rpc<any[]>(c.client, 'widget_people')).map((p) => p.user_id).sort()).toEqual([a.id, b.id, d.id].sort());
    expect(await rpc<any[]>(stranger.client, 'widget_people')).toEqual([]);
    const row = (await rpc<any[]>(a.client, 'widget_people')).find((p) => p.user_id === b.id);
    expect(row).toMatchObject({ display_name: b.name, avatar_path: null });
  });

  it('drops a person after a block in either direction', async () => {
    const [x, y] = await createUsers(2, 'WdgBlk');
    await createGroup(x, [y]);
    expect((await rpc<any[]>(x.client, 'widget_people')).map((p) => p.user_id)).toEqual([y.id]);
    await rpc(y.client, 'block_user', { p_user_id: x.id });
    expect(await rpc<any[]>(x.client, 'widget_people')).toEqual([]);
    expect(await rpc<any[]>(y.client, 'widget_people')).toEqual([]);
  });
});

describe('newest_photos_of', () => {
  it("returns a friend's newest photos by author or self-tag, newest first, with what the widget draws", async () => {
    const own = (await postPhoto(b, [ab.id], { p_caption: 'beach' })).posts[0];
    await setCreatedAt(own.id, '2026-05-01T10:00:00Z');
    // c posts a photo b is in (b tags themselves): it counts for b
    const tagged = (await postPhoto(c, [abc.id])).posts[0];
    await setCreatedAt(tagged.id, '2026-05-02T10:00:00Z');
    await rpc(b.client, 'tag_self', { p_post_id: tagged.id });
    // a's own photo with no tag of b: not b's
    const other = (await postPhoto(a, [ab.id])).posts[0];
    await setCreatedAt(other.id, '2026-05-03T10:00:00Z');

    const rows = await rpc<any[]>(a.client, 'newest_photos_of', { p_user_id: b.id });
    expect(rows.map((r) => [r.post_id, r.via])).toEqual([
      [tagged.id, 'tag'],
      [own.id, 'author'],
    ]);
    expect(rows[1]).toMatchObject({ group_id: ab.id, group_name: 'A and B', author_id: b.id, author_name: b.name, caption: 'beach' });
    expect(rows[0]).toMatchObject({ group_id: abc.id, author_id: c.id });
    expect(await rpc<any[]>(a.client, 'newest_photos_of', { p_user_id: b.id, p_limit: 1 })).toHaveLength(1);
  });

  it('only from groups both share: a photo of the friend in a group the caller is not in stays out', async () => {
    // c's photo in "C and D": a shares abc with c but is not in cd
    const hidden = (await postPhoto(c, [cd.id])).posts[0];
    await setCreatedAt(hidden.id, '2030-01-01T00:00:00Z');
    const rows = await rpc<any[]>(a.client, 'newest_photos_of', { p_user_id: c.id });
    expect(rows.map((r) => r.post_id)).not.toContain(hidden.id);
    expect(rows.every((r) => r.group_id === abc.id)).toBe(true);
    // d sees it (they share cd with c)
    expect((await rpc<any[]>(d.client, 'newest_photos_of', { p_user_id: c.id })).map((r) => r.post_id)).toContain(hidden.id);
  });

  it('returns nothing for a stranger, and nothing across a block in either direction', async () => {
    expect(await rpc<any[]>(stranger.client, 'newest_photos_of', { p_user_id: b.id })).toEqual([]);
    expect(await rpc<any[]>(a.client, 'newest_photos_of', { p_user_id: d.id })).toEqual([]);
    const [x, y, z] = await createUsers(3, 'WdgBlk2');
    const g = await createGroup(x, [y, z]);
    // z posts a photo y is in; y also posts one
    const byZ = (await postPhoto(z, [g.id])).posts[0];
    await rpc(y.client, 'tag_self', { p_post_id: byZ.id });
    const byY = (await postPhoto(y, [g.id])).posts[0];
    expect((await rpc<any[]>(x.client, 'newest_photos_of', { p_user_id: y.id })).map((r) => r.post_id).sort()).toEqual([byZ.id, byY.id].sort());
    // x blocks z: the photo z took of y leaves x's widget for y
    await rpc(x.client, 'block_user', { p_user_id: z.id });
    expect((await rpc<any[]>(x.client, 'newest_photos_of', { p_user_id: y.id })).map((r) => r.post_id)).toEqual([byY.id]);
    // y blocks x: nothing of y for x
    await rpc(y.client, 'block_user', { p_user_id: x.id });
    expect(await rpc<any[]>(x.client, 'newest_photos_of', { p_user_id: y.id })).toEqual([]);
  });

  it('a friend who leaves the shared group is no longer shown', async () => {
    const [x, y] = await createUsers(2, 'WdgLeave');
    const g = await createGroup(x, [y]);
    await postPhoto(y, [g.id]);
    expect(await rpc<any[]>(x.client, 'newest_photos_of', { p_user_id: y.id })).toHaveLength(1);
    await rpc(y.client, 'leave_group', { p_group_id: g.id });
    expect(await rpc<any[]>(x.client, 'newest_photos_of', { p_user_id: y.id })).toEqual([]);
  });

  it('rejects a missing person', async () => {
    await expectRpcError(rpc(a.client, 'newest_photos_of', { p_user_id: null }), 'invalid_argument', 400);
  });
});

describe('my_memories', () => {
  it('one memory per day: your own or self-tagged photo from that month and day in an earlier year, newest year first', async () => {
    const [me, friend, outsider] = await createUsers(3, 'WdgMem');
    const g = await createGroup(me, [friend], { tz: 'UTC' });
    const other = await createGroup(friend, [outsider], { tz: 'UTC' });
    const mk = async (who: TestUser, groupId: string, iso: string) => {
      const p = (await postPhoto(who, [groupId])).posts[0];
      await setCreatedAt(p.id, iso);
      return p.id;
    };
    const mine2024 = await mk(me, g.id, '2024-10-17T12:00:00Z');
    const mine2023 = await mk(me, g.id, '2023-10-17T12:00:00Z');
    const taggedIn2025 = await mk(friend, g.id, '2025-10-18T09:00:00Z');
    await rpc(me.client, 'tag_self', { p_post_id: taggedIn2025 });
    await mk(friend, g.id, '2025-10-19T09:00:00Z'); // friend's own, me not in it
    await mk(friend, other.id, '2025-10-20T09:00:00Z'); // a group I'm not in
    await mk(me, g.id, '2026-10-17T08:00:00Z'); // this year: not a memory yet

    const rows = await rpc<any[]>(me.client, 'my_memories', { p_from: '2026-10-17', p_days: 4, p_time_zone: 'UTC' });
    expect(rows.map((r) => [r.day, r.post_id, r.years_ago])).toEqual([
      ['2026-10-17', mine2024, 2],
      ['2026-10-18', taggedIn2025, 1],
    ]);
    expect(rows[0]).toMatchObject({ group_id: g.id, author_id: me.id, author_name: me.name });
    expect(rows[1]).toMatchObject({ author_id: friend.id });
    expect(rows.map((r) => r.post_id)).not.toContain(mine2023); // one per day: the newest year
    expect(await rpc<any[]>(outsider.client, 'my_memories', { p_from: '2026-10-17', p_days: 4, p_time_zone: 'UTC' })).toEqual([]);
  });

  it('reads the day in the given time zone', async () => {
    const [me] = await createUsers(1, 'WdgMemTz');
    const g = await createGroup(me, [], { tz: 'UTC' });
    const p = (await postPhoto(me, [g.id])).posts[0];
    await setCreatedAt(p.id, '2025-03-09T16:00:00Z'); // 2025-03-10 01:00 in Tokyo, 2025-03-09 in UTC
    expect((await rpc<any[]>(me.client, 'my_memories', { p_from: '2026-03-10', p_days: 1, p_time_zone: 'Asia/Tokyo' })).map((r) => r.post_id)).toEqual([p.id]);
    expect(await rpc<any[]>(me.client, 'my_memories', { p_from: '2026-03-10', p_days: 1, p_time_zone: 'UTC' })).toEqual([]);
  });

  it('a block hides the photos its other side took of you; a group you left no longer counts', async () => {
    const [me, friend] = await createUsers(2, 'WdgMemBlk');
    const g = await createGroup(friend, [me], { tz: 'UTC' });
    const byFriend = (await postPhoto(friend, [g.id])).posts[0];
    await setCreatedAt(byFriend.id, '2025-06-01T12:00:00Z');
    await rpc(me.client, 'tag_self', { p_post_id: byFriend.id });
    const args = { p_from: '2026-06-01', p_days: 1, p_time_zone: 'UTC' };
    expect((await rpc<any[]>(me.client, 'my_memories', args)).map((r) => r.post_id)).toEqual([byFriend.id]);
    await rpc(friend.client, 'block_user', { p_user_id: me.id });
    expect(await rpc<any[]>(me.client, 'my_memories', args)).toEqual([]);
    await rpc(friend.client, 'unblock_user', { p_user_id: me.id });
    const mine = (await postPhoto(me, [g.id])).posts[0];
    await setCreatedAt(mine.id, '2024-06-01T12:00:00Z');
    await rpc(me.client, 'leave_group', { p_group_id: g.id });
    expect(await rpc<any[]>(me.client, 'my_memories', args)).toEqual([]);
  });

  it('validates its arguments', async () => {
    await expectRpcError(rpc(a.client, 'my_memories', { p_from: '2026-10-17', p_days: 0, p_time_zone: 'UTC' }), 'invalid_argument', 400);
    await expectRpcError(rpc(a.client, 'my_memories', { p_from: '2026-10-17', p_days: 15, p_time_zone: 'UTC' }), 'invalid_argument', 400);
    await expectRpcError(rpc(a.client, 'my_memories', { p_from: '2026-10-17', p_days: 3, p_time_zone: 'Nowhere/City' }), 'invalid_argument', 400);
    await expectRpcError(rpc(a.client, 'my_memories', { p_from: null, p_days: 3, p_time_zone: 'UTC' }), 'invalid_argument', 400);
  });
});
