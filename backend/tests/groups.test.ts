// Groups, members, invites, profiles: RPC happy paths, permission failures and the
// table policies of profiles, profile_private, groups, group_members, group_invites.
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  anon,
  closeDb,
  createGroup,
  createUser,
  createUsers,
  expectRpcError,
  rpc,
  select,
  sql,
  upload,
  type TestUser,
} from './helpers';

let a: TestUser, b: TestUser, c: TestUser, stranger: TestUser;

beforeAll(async () => {
  [a, b, c, stranger] = await createUsers(4, 'Grp');
});

afterAll(closeDb);

describe('create_group', () => {
  it('creates the group with the caller as admin', async () => {
    const g = await rpc(a.client, 'create_group', {
      p_name: '  Roomies ',
      p_kind: 'roommates',
      p_time_zone: 'Europe/Berlin',
      p_waking_start: '08:00',
      p_waking_end: '22:30',
    });
    expect(g).toMatchObject({ name: 'Roomies', kind: 'roommates', time_zone: 'Europe/Berlin', created_by: a.id });
    expect(g.waking_start).toBe('08:00:00');
    expect(g.invitation_paused).toBe(false);
    const members = await select(a.client, 'group_members', (q) => q.eq('group_id', g.id));
    expect(members).toEqual([expect.objectContaining({ user_id: a.id, role: 'admin', muted: false })]);
  });

  it('accepts a cover uploaded under the caller prefix only', async () => {
    const cover = `u/${a.id}/covers/${randomUUID()}.jpg`;
    await upload(a, cover);
    const g = await rpc(a.client, 'create_group', { p_name: 'Fam', p_kind: 'family', p_time_zone: 'UTC', p_cover_path: cover });
    expect(g.cover_path).toBe(cover);
    await expectRpcError(
      rpc(b.client, 'create_group', { p_name: 'X', p_kind: 'family', p_time_zone: 'UTC', p_cover_path: cover }),
      'invalid_path',
      400,
    );
  });

  it('validates its arguments', async () => {
    await expectRpcError(rpc(a.client, 'create_group', { p_name: '  ', p_kind: 'friends', p_time_zone: 'UTC' }), 'invalid_name', 400);
    await expectRpcError(
      rpc(a.client, 'create_group', { p_name: 'x', p_kind: 'friends', p_time_zone: 'Mars/Olympus' }),
      'invalid_time_zone',
      400,
    );
    await expectRpcError(
      rpc(a.client, 'create_group', { p_name: 'x', p_kind: 'friends', p_time_zone: 'UTC', p_waking_start: '09:00' }),
      'invalid_waking_window',
      400,
    );
    const { error } = await a.client.rpc('create_group', { p_name: 'x', p_kind: 'band', p_time_zone: 'UTC' });
    expect(error).not.toBeNull();
  });

  it('is not callable without a session', async () => {
    const { error } = await anon.rpc('create_group', { p_name: 'x', p_kind: 'friends', p_time_zone: 'UTC' });
    expect(error).not.toBeNull();
  });
});

describe('update_group (admin only)', () => {
  it('renames, changes kind, cover and time zone; "" removes the cover', async () => {
    const g = await createGroup(a, [b]);
    const cover = `u/${a.id}/covers/${randomUUID()}.jpg`;
    await upload(a, cover);
    let r = await rpc(a.client, 'update_group', { p_group_id: g.id, p_name: 'New', p_kind: 'custom', p_cover_path: cover, p_time_zone: 'Asia/Tokyo' });
    expect(r).toMatchObject({ name: 'New', kind: 'custom', cover_path: cover, time_zone: 'Asia/Tokyo' });
    r = await rpc(a.client, 'update_group', { p_group_id: g.id, p_cover_path: '' });
    expect(r.cover_path).toBeNull();
    expect(r.name).toBe('New');
    await expectRpcError(rpc(b.client, 'update_group', { p_group_id: g.id, p_name: 'Nope' }), 'not_group_admin', 403);
    await expectRpcError(rpc(stranger.client, 'update_group', { p_group_id: g.id, p_name: 'Nope' }), 'not_group_member', 403);
    await expectRpcError(rpc(a.client, 'update_group', { p_group_id: g.id, p_time_zone: 'Nowhere/X' }), 'invalid_time_zone', 400);
  });
});

describe('invites', () => {
  it('any member creates an invite; it expires after invite_ttl_seconds', async () => {
    const g = await createGroup(a, [b]);
    const inv = await rpc(b.client, 'create_invite', { p_group_id: g.id });
    expect(inv.token).toMatch(/^[A-Za-z0-9_-]{24}$/);
    const ttl = (new Date(inv.expires_at).getTime() - Date.now()) / 1000;
    expect(ttl).toBeGreaterThan(604800 - 60);
    expect(ttl).toBeLessThan(604800 + 60);
    await expectRpcError(rpc(stranger.client, 'create_invite', { p_group_id: g.id }), 'not_group_member', 403);
    // members see the group's invites; others do not
    expect((await select(a.client, 'group_invites')).map((i: any) => i.token)).toContain(inv.token);
    expect((await select(stranger.client, 'group_invites')).map((i: any) => i.token)).not.toContain(inv.token);
  });

  it('invite_preview (anon) returns the limited projection', async () => {
    const g = await createGroup(a, [b], { name: 'Preview me' });
    await a.client.from('profiles').update({ display_name: 'Alice Wonder' }).eq('id', a.id);
    const inv = await rpc(a.client, 'create_invite', { p_group_id: g.id });
    const p = await rpc(anon, 'invite_preview', { p_token: inv.token });
    expect(p).toEqual({
      group_name: 'Preview me',
      group_kind: 'friends',
      cover_path: null,
      inviter_first_name: 'Alice',
      members: [
        { first_name: 'Alice', avatar_path: null },
        { first_name: b.name.split(' ')[0], avatar_path: null },
      ],
    });
  });

  it('revoked, expired and unknown tokens are refused', async () => {
    const g = await createGroup(a, [b]);
    const inv = await rpc(b.client, 'create_invite', { p_group_id: g.id });
    // another member who is neither the creator nor an admin cannot revoke
    await rpc(c.client, 'join_group', { p_token: inv.token });
    await expectRpcError(rpc(c.client, 'revoke_invite', { p_token: inv.token }), 'not_group_admin', 403);
    await expectRpcError(rpc(stranger.client, 'revoke_invite', { p_token: inv.token }), 'invite_not_found', 404);
    await rpc(a.client, 'revoke_invite', { p_token: inv.token }); // admin
    await expectRpcError(rpc(anon, 'invite_preview', { p_token: inv.token }), 'invite_revoked', 410);
    await expectRpcError(rpc(stranger.client, 'join_group', { p_token: inv.token }), 'invite_revoked', 410);

    const inv2 = await rpc(b.client, 'create_invite', { p_group_id: g.id });
    await rpc(b.client, 'revoke_invite', { p_token: inv2.token }); // creator

    const inv3 = await rpc(a.client, 'create_invite', { p_group_id: g.id });
    await sql(`update public.group_invites set expires_at = now() - interval '1 second' where token = $1`, [inv3.token]);
    await expectRpcError(rpc(anon, 'invite_preview', { p_token: inv3.token }), 'invite_expired', 410);
    await expectRpcError(rpc(stranger.client, 'join_group', { p_token: inv3.token }), 'invite_expired', 410);

    await expectRpcError(rpc(anon, 'invite_preview', { p_token: 'nope-nope-nope-nope-nope' }), 'invite_not_found', 404);
    await expectRpcError(rpc(stranger.client, 'join_group', { p_token: 'nope-nope-nope-nope-nope' }), 'invite_not_found', 404);
  });

  it('join_group adds a member and is idempotent', async () => {
    const g = await createGroup(a);
    const inv = await rpc(a.client, 'create_invite', { p_group_id: g.id });
    const j1 = await rpc(b.client, 'join_group', { p_token: inv.token });
    const j2 = await rpc(b.client, 'join_group', { p_token: inv.token });
    expect(j1.id).toBe(g.id);
    expect(j2.id).toBe(g.id);
    const members = await select(b.client, 'group_members', (q) => q.eq('group_id', g.id));
    expect(members.map((m: any) => [m.user_id, m.role]).sort()).toEqual([[a.id, 'admin'], [b.id, 'member']].sort());
    // even after the invite is revoked, re-joining as a member is a no-op
    await rpc(a.client, 'revoke_invite', { p_token: inv.token });
    expect((await rpc(b.client, 'join_group', { p_token: inv.token })).id).toBe(g.id);
  });
});

describe('membership changes', () => {
  it('remove_member: admin only, not self, revokes the removed member invites', async () => {
    const g = await createGroup(a, [b, c]);
    const binv = await rpc(b.client, 'create_invite', { p_group_id: g.id });
    await expectRpcError(rpc(b.client, 'remove_member', { p_group_id: g.id, p_user_id: c.id }), 'not_group_admin', 403);
    await expectRpcError(rpc(a.client, 'remove_member', { p_group_id: g.id, p_user_id: a.id }), 'cannot_target_self', 400);
    await expectRpcError(rpc(a.client, 'remove_member', { p_group_id: g.id, p_user_id: stranger.id }), 'member_not_found', 404);
    await expectRpcError(rpc(stranger.client, 'remove_member', { p_group_id: g.id, p_user_id: b.id }), 'not_group_member', 403);
    await rpc(a.client, 'remove_member', { p_group_id: g.id, p_user_id: b.id });
    expect(await select(b.client, 'groups', (q) => q.eq('id', g.id))).toEqual([]);
    await expectRpcError(rpc(anon, 'invite_preview', { p_token: binv.token }), 'invite_revoked', 410);
  });

  it('leave_group: last admin hands off to the longest-standing member; last member deletes the group', async () => {
    const g = await createGroup(a, [b, c]); // b joined before c
    const { posts } = await (await import('./helpers')).postPhoto(b, [g.id]);
    await rpc(a.client, 'leave_group', { p_group_id: g.id });
    const roles = await select(b.client, 'group_members', (q) => q.eq('group_id', g.id));
    expect(roles.find((m: any) => m.user_id === b.id).role).toBe('admin');
    expect(roles.find((m: any) => m.user_id === c.id).role).toBe('member');
    // content stays with the group
    expect((await select(c.client, 'posts', (q) => q.eq('id', posts[0].id))).length).toBe(1);

    await rpc(b.client, 'leave_group', { p_group_id: g.id });
    await rpc(c.client, 'leave_group', { p_group_id: g.id });
    expect(await sql(`select 1 from public.groups where id = $1`, [g.id])).toEqual([]);
    expect(await sql(`select 1 from public.posts where group_id = $1`, [g.id])).toEqual([]);
    const jobs = await sql(
      `select 1 from public.jobs where kind = 'storage.delete' and payload -> 'prefixes' ? $1`,
      [`g/${g.id}/`],
    );
    expect(jobs).toHaveLength(1);
    await expectRpcError(rpc(c.client, 'leave_group', { p_group_id: g.id }), 'not_group_member', 403);
  });

  it('set_group_muted affects only the caller row', async () => {
    const g = await createGroup(a, [b]);
    await rpc(b.client, 'set_group_muted', { p_group_id: g.id, p_muted: true });
    const rows = await select(a.client, 'group_members', (q) => q.eq('group_id', g.id));
    expect(rows.find((m: any) => m.user_id === b.id).muted).toBe(true);
    expect(rows.find((m: any) => m.user_id === a.id).muted).toBe(false);
    await expectRpcError(rpc(stranger.client, 'set_group_muted', { p_group_id: g.id, p_muted: true }), 'not_group_member', 403);
  });

  it('set_group_invitation_hours / set_group_invitation_paused are admin only', async () => {
    const g = await createGroup(a, [b]);
    const r = await rpc(a.client, 'set_group_invitation_hours', { p_group_id: g.id, p_start: '10:00', p_end: '20:00' });
    expect([r.waking_start, r.waking_end]).toEqual(['10:00:00', '20:00:00']);
    const cleared = await rpc(a.client, 'set_group_invitation_hours', { p_group_id: g.id, p_start: null, p_end: null });
    expect(cleared.waking_start).toBeNull();
    await expectRpcError(
      rpc(a.client, 'set_group_invitation_hours', { p_group_id: g.id, p_start: '10:00', p_end: '10:00' }),
      'invalid_waking_window',
      400,
    );
    await expectRpcError(
      rpc(b.client, 'set_group_invitation_hours', { p_group_id: g.id, p_start: '10:00', p_end: '20:00' }),
      'not_group_admin',
      403,
    );
    const p = await rpc(a.client, 'set_group_invitation_paused', { p_group_id: g.id, p_paused: true });
    expect(p.invitation_paused).toBe(true);
    await expectRpcError(rpc(b.client, 'set_group_invitation_paused', { p_group_id: g.id, p_paused: false }), 'not_group_admin', 403);
    await expectRpcError(rpc(stranger.client, 'set_group_invitation_paused', { p_group_id: g.id, p_paused: false }), 'not_group_member', 403);
  });
});

describe('table policies: groups, group_members, group_invites', () => {
  it('clients cannot write these tables directly', async () => {
    const g = await createGroup(a, [b]);
    const r1 = await a.client.from('groups').insert({ name: 'x', kind: 'friends', time_zone: 'UTC' });
    expect(r1.error?.code).toBe('42501');
    const r2 = await a.client.from('groups').update({ name: 'hijack' }).eq('id', g.id);
    expect(r2.error?.code).toBe('42501');
    const r3 = await stranger.client.from('group_members').insert({ group_id: g.id, user_id: stranger.id });
    expect(r3.error?.code).toBe('42501');
    const r4 = await b.client.from('group_members').update({ role: 'admin' }).eq('group_id', g.id).eq('user_id', b.id);
    expect(r4.error?.code).toBe('42501');
    const r5 = await a.client.from('group_members').delete().eq('group_id', g.id).eq('user_id', b.id);
    expect(r5.error?.code).toBe('42501');
    const r6 = await a.client.from('group_invites').insert({ group_id: g.id, created_by: a.id, expires_at: '2030-01-01' });
    expect(r6.error?.code).toBe('42501');
  });

  it('members read their groups; others do not', async () => {
    const g = await createGroup(a, [b]);
    expect((await select(b.client, 'groups')).map((x: any) => x.id)).toContain(g.id);
    expect((await select(stranger.client, 'groups')).map((x: any) => x.id)).not.toContain(g.id);
    expect(await select(stranger.client, 'group_members', (q) => q.eq('group_id', g.id))).toEqual([]);
  });
});

describe('table policies: profiles, profile_private', () => {
  it('profiles: readable by self and co-members only; updatable by self only', async () => {
    const [p, q, outsider] = await createUsers(3, 'Prof');
    await createGroup(p, [q]);
    expect((await select(q.client, 'profiles')).map((x: any) => x.id).sort()).toEqual([p.id, q.id].sort());
    expect((await select(outsider.client, 'profiles')).map((x: any) => x.id)).toEqual([outsider.id]);

    const own = await p.client.from('profiles').update({ display_name: 'Pat Q' }).eq('id', p.id).select();
    expect(own.data?.[0].display_name).toBe('Pat Q');
    const other = await q.client.from('profiles').update({ display_name: 'Hacked' }).eq('id', p.id).select();
    expect(other.data).toEqual([]);
    const [row] = await sql(`select display_name from public.profiles where id = $1`, [p.id]);
    expect(row.display_name).toBe('Pat Q');

    // avatar must live under avatars/<own id>/
    const bad = await p.client.from('profiles').update({ avatar_path: `avatars/${q.id}/x.jpg` }).eq('id', p.id);
    expect(bad.error?.code).toBe('23514');
    const ok = await p.client.from('profiles').update({ avatar_path: `avatars/${p.id}/x.jpg` }).eq('id', p.id);
    expect(ok.error).toBeNull();
    // id / created_at are not client-writable
    const idw = await p.client.from('profiles').update({ created_at: '2000-01-01' }).eq('id', p.id);
    expect(idw.error?.code).toBe('42501');
  });

  it('profile_private: own row only, written through RPCs', async () => {
    const u = await createUser('Priv Ate');
    const rows = await select(u.client, 'profile_private');
    expect(rows).toEqual([expect.objectContaining({ user_id: u.id, birthday: null, birthday_opt_in: false, age_confirmed_at: null })]);
    expect((await select(a.client, 'profile_private')).map((r: any) => r.user_id)).toEqual([a.id]);
    const w = await u.client.from('profile_private').update({ age_confirmed_at: new Date().toISOString() }).eq('user_id', u.id);
    expect(w.error?.code).toBe('42501');
  });
});
