// Group admin powers (migration 0054): admin_delete_post, admin_delete_message, set_member_role.
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

// a: admin of G. b, c: members of G. h: admin of their own group H, which b also joined. outsider: in no group of a's.
let a: TestUser, b: TestUser, c: TestUser, h: TestUser, outsider: TestUser;
let g: TestGroup, hg: TestGroup;

beforeAll(async () => {
  [a, b, c, h, outsider] = await createUsers(5, 'Adm');
  g = await createGroup(a, [b, c]);
  hg = await createGroup(h, [b]);
});

afterAll(closeDb);

const roleOf = async (group: string, user: string) =>
  (await sql<{ role: string }>(`select role::text from public.group_members where group_id = $1 and user_id = $2`, [group, user]))[0]
    ?.role;

describe('admin_delete_post', () => {
  it("an admin removes someone else's photo from their group, with the delete_post cascade", async () => {
    const { media, posts } = await postPhoto(b, [g.id]);
    const post = posts[0];
    await rpc(c.client, 'react', { p_post_id: post.id, p_emoji: '🔥' });
    await rpc(c.client, 'tag_self', { p_post_id: post.id });
    const [photoMsg] = await sql(`select id from public.messages where post_id = $1`, [post.id]);

    await rpc(a.client, 'admin_delete_post', { p_post_id: post.id });

    expect(await select(c.client, 'posts', (q) => q.eq('id', post.id))).toEqual([]);
    expect(await sql(`select 1 from public.reactions where post_id = $1`, [post.id])).toEqual([]);
    expect(await sql(`select 1 from public.post_tags where post_id = $1`, [post.id])).toEqual([]);
    if (photoMsg) expect(await sql(`select 1 from public.messages where id = $1`, [photoMsg.id])).toEqual([]);
    // posted nowhere else: the media and its files go too
    expect(await sql(`select 1 from public.media where id = $1`, [media.id])).toEqual([]);
    const del = await sql(`select 1 from public.jobs where kind = 'storage.delete' and payload::text like $1`, [`%${media.id}%`]);
    expect(del.length).toBeGreaterThan(0);
  });

  it("removes only this group's copy: the same photo stays in the author's other group", async () => {
    const { media, posts } = await postPhoto(b, [g.id, hg.id]);
    const inG = posts.find((p: any) => p.group_id === g.id);
    const inH = posts.find((p: any) => p.group_id === hg.id);
    await rpc(a.client, 'admin_delete_post', { p_post_id: inG.id });
    expect(await select(b.client, 'posts', (q) => q.eq('id', inG.id))).toEqual([]);
    expect((await select(h.client, 'posts', (q) => q.eq('id', inH.id))).length).toBe(1);
    expect((await sql(`select 1 from public.media where id = $1`, [media.id])).length).toBe(1);
  });

  it('a member who is not an admin is refused; the photo stays', async () => {
    const { posts } = await postPhoto(b, [g.id]);
    await expectRpcError(rpc(c.client, 'admin_delete_post', { p_post_id: posts[0].id }), 'not_group_admin', 403);
    expect((await select(c.client, 'posts', (q) => q.eq('id', posts[0].id))).length).toBe(1);
  });

  it("cross-group: an admin of another group cannot reach G's photos", async () => {
    const { posts } = await postPhoto(b, [g.id]);
    // h is admin of H (b is in both) but not a member of G
    await expectRpcError(rpc(h.client, 'admin_delete_post', { p_post_id: posts[0].id }), 'post_not_found', 404);
    await expectRpcError(rpc(outsider.client, 'admin_delete_post', { p_post_id: posts[0].id }), 'post_not_found', 404);
    // a is admin of G, not a member of H
    const inH = (await postPhoto(b, [hg.id])).posts[0];
    await expectRpcError(rpc(a.client, 'admin_delete_post', { p_post_id: inH.id }), 'post_not_found', 404);
    expect((await sql(`select 1 from public.posts where id in ($1, $2)`, [posts[0].id, inH.id])).length).toBe(2);
  });
});

describe('admin_delete_message', () => {
  it("an admin removes someone else's message; members get message_deleted", async () => {
    const m = await rpc(b.client, 'send_message', { p_group_id: g.id, p_kind: 'text', p_body: 'off topic' });
    await rpc(c.client, 'react_to_message', { p_message_id: m.id, p_emoji: '😂' });
    await rpc(a.client, 'admin_delete_message', { p_message_id: m.id });
    expect(await select(c.client, 'messages', (q) => q.eq('id', m.id))).toEqual([]);
    expect(await sql(`select 1 from public.message_reactions where message_id = $1`, [m.id])).toEqual([]);
  });

  it('a photo message goes with admin_delete_post; joined / left lines stay', async () => {
    const { posts } = await postPhoto(b, [g.id]);
    const [photoMsg] = await sql(`select id from public.messages where post_id = $1`, [posts[0].id]);
    if (photoMsg) {
      await expectRpcError(rpc(a.client, 'admin_delete_message', { p_message_id: photoMsg.id }), 'invalid_kind', 400);
    }
    const [joined] = await sql(
      `select id from public.messages where group_id = $1 and kind = 'joined' and author_id = $2`,
      [g.id, b.id],
    );
    expect(joined).toBeDefined();
    await expectRpcError(rpc(a.client, 'admin_delete_message', { p_message_id: joined.id }), 'invalid_kind', 400);
  });

  it('a member who is not an admin is refused; another group cannot reach it', async () => {
    const m = await rpc(b.client, 'send_message', { p_group_id: g.id, p_kind: 'text', p_body: 'stays' });
    await expectRpcError(rpc(c.client, 'admin_delete_message', { p_message_id: m.id }), 'not_group_admin', 403);
    await expectRpcError(rpc(h.client, 'admin_delete_message', { p_message_id: m.id }), 'message_not_found', 404);
    await expectRpcError(rpc(outsider.client, 'admin_delete_message', { p_message_id: m.id }), 'message_not_found', 404);
    expect((await select(b.client, 'messages', (q) => q.eq('id', m.id))).length).toBe(1);
  });

  it('the author deletes still refuse someone else (unchanged)', async () => {
    const m = await rpc(b.client, 'send_message', { p_group_id: g.id, p_kind: 'text', p_body: 'mine' });
    await expectRpcError(rpc(a.client, 'delete_message', { p_message_id: m.id }), 'message_not_found', 404);
    const { posts } = await postPhoto(b, [g.id]);
    await expectRpcError(rpc(a.client, 'delete_post', { p_post_id: posts[0].id }), 'post_not_found', 404);
  });
});

describe('set_member_role', () => {
  it('an admin makes a member an admin, who then has admin powers; and removes them as admin', async () => {
    const grp = await createGroup(a, [b, c]);
    await rpc(a.client, 'set_member_role', { p_group_id: grp.id, p_user_id: b.id, p_role: 'admin' });
    expect(await roleOf(grp.id, b.id)).toBe('admin');
    // idempotent
    await rpc(a.client, 'set_member_role', { p_group_id: grp.id, p_user_id: b.id, p_role: 'admin' });
    const m = await rpc(c.client, 'send_message', { p_group_id: grp.id, p_kind: 'text', p_body: 'x' });
    await rpc(b.client, 'admin_delete_message', { p_message_id: m.id });
    await rpc(b.client, 'set_member_role', { p_group_id: grp.id, p_user_id: a.id, p_role: 'member' });
    expect(await roleOf(grp.id, a.id)).toBe('member');
    await expectRpcError(
      rpc(a.client, 'set_member_role', { p_group_id: grp.id, p_user_id: c.id, p_role: 'admin' }),
      'not_group_admin',
      403,
    );
  });

  it('a member who is not an admin is refused', async () => {
    const grp = await createGroup(a, [b, c]);
    await expectRpcError(
      rpc(b.client, 'set_member_role', { p_group_id: grp.id, p_user_id: b.id, p_role: 'admin' }),
      'not_group_admin',
      403,
    );
    await expectRpcError(
      rpc(b.client, 'set_member_role', { p_group_id: grp.id, p_user_id: a.id, p_role: 'member' }),
      'not_group_admin',
      403,
    );
    expect(await roleOf(grp.id, b.id)).toBe('member');
    expect(await roleOf(grp.id, a.id)).toBe('admin');
  });

  it('never leaves the group without an admin', async () => {
    const grp = await createGroup(a, [b]);
    const e = await expectRpcError(
      rpc(a.client, 'set_member_role', { p_group_id: grp.id, p_user_id: a.id, p_role: 'member' }),
      'last_admin',
      409,
    );
    expect(e.sqlstate).toBe('PT409');
    expect(await roleOf(grp.id, a.id)).toBe('admin');
    // with a second admin, stepping down is allowed; the other one is then the last admin
    await rpc(a.client, 'set_member_role', { p_group_id: grp.id, p_user_id: b.id, p_role: 'admin' });
    await rpc(a.client, 'set_member_role', { p_group_id: grp.id, p_user_id: a.id, p_role: 'member' });
    await expectRpcError(
      rpc(b.client, 'set_member_role', { p_group_id: grp.id, p_user_id: b.id, p_role: 'member' }),
      'last_admin',
      409,
    );
    const admins = await sql(`select user_id from public.group_members where group_id = $1 and role = 'admin'`, [grp.id]);
    expect(admins.map((r: any) => r.user_id)).toEqual([b.id]);
  });

  it('two admins stepping down at the same time leave one admin', async () => {
    const grp = await createGroup(a, [b]);
    await rpc(a.client, 'set_member_role', { p_group_id: grp.id, p_user_id: b.id, p_role: 'admin' });
    const results = await Promise.allSettled([
      rpc(a.client, 'set_member_role', { p_group_id: grp.id, p_user_id: a.id, p_role: 'member' }),
      rpc(b.client, 'set_member_role', { p_group_id: grp.id, p_user_id: b.id, p_role: 'member' }),
    ]);
    expect(results.filter((r) => r.status === 'fulfilled').length).toBe(1);
    const admins = await sql(`select 1 from public.group_members where group_id = $1 and role = 'admin'`, [grp.id]);
    expect(admins.length).toBe(1);
  });

  it('cross-group: target and caller must be in this group', async () => {
    // b is in G and H; h is admin of H only
    await expectRpcError(
      rpc(h.client, 'set_member_role', { p_group_id: g.id, p_user_id: b.id, p_role: 'admin' }),
      'not_group_member',
      403,
    );
    await expectRpcError(
      rpc(a.client, 'set_member_role', { p_group_id: g.id, p_user_id: h.id, p_role: 'admin' }),
      'member_not_found',
      404,
    );
    await expectRpcError(
      rpc(a.client, 'set_member_role', { p_group_id: hg.id, p_user_id: b.id, p_role: 'admin' }),
      'not_group_member',
      403,
    );
    expect(await roleOf(hg.id, b.id)).toBe('member');
    expect(await roleOf(g.id, b.id)).toBe('member');
  });

  it('rejects a missing or unknown role', async () => {
    await expectRpcError(
      rpc(a.client, 'set_member_role', { p_group_id: g.id, p_user_id: b.id, p_role: null }),
      'invalid_argument',
      400,
    );
    const { error } = await a.client.rpc('set_member_role', { p_group_id: g.id, p_user_id: b.id, p_role: 'owner' });
    expect(error?.code).toBe('22P02');
  });
});
