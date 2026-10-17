// Account-scoped RPCs and own-rows tables: blocks, reports, devices,
// notification_settings, profile_private (birthday, age gate), entitlements, config.
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  admin,
  anon,
  closeDb,
  createGroup,
  createUsers,
  expectRpcError,
  getConfig,
  grantPremium,
  jobsWhere,
  postPhoto,
  rpc,
  select,
  setConfig,
  sql,
  type TestGroup,
  type TestUser,
} from './helpers';

let a: TestUser, b: TestUser, stranger: TestUser;
let g: TestGroup;

beforeAll(async () => {
  [a, b, stranger] = await createUsers(3, 'Acc');
  g = await createGroup(a, [b]);
});

afterAll(closeDb);

describe('block_user / unblock_user', () => {
  it('blocks existing users only, idempotently', async () => {
    await rpc(a.client, 'block_user', { p_user_id: stranger.id });
    await rpc(a.client, 'block_user', { p_user_id: stranger.id });
    expect((await select(a.client, 'blocks')).map((r: any) => r.blocked_id)).toEqual([stranger.id]);
    await expectRpcError(rpc(a.client, 'block_user', { p_user_id: randomUUID() }), 'user_not_found', 404);
    await rpc(a.client, 'unblock_user', { p_user_id: stranger.id });
    expect(await select(a.client, 'blocks')).toEqual([]);
    const direct = await a.client.from('blocks').insert({ blocker_id: a.id, blocked_id: b.id });
    expect(direct.error?.code).toBe('42501');
  });
});

describe('report', () => {
  it('reports reachable targets; reports are insert-only', async () => {
    const post = (await postPhoto(b, [g.id])).posts[0];
    const id = await rpc<string>(a.client, 'report', { p_target_kind: 'post', p_target_id: post.id, p_reason: 'not ok' });
    expect(id).toMatch(/^[0-9a-f-]{36}$/);
    expect(await jobsWhere('moderation.report', { report_id: id })).toHaveLength(1);
    await rpc(a.client, 'report', { p_target_kind: 'user', p_target_id: b.id, p_reason: 'spam' });
    await rpc(a.client, 'report', { p_target_kind: 'group', p_target_id: g.id, p_reason: 'x' });
    const msg = await rpc(b.client, 'send_message', { p_group_id: g.id, p_kind: 'text', p_body: 'rude' });
    await rpc(a.client, 'report', { p_target_kind: 'message', p_target_id: msg.id, p_reason: 'rude' });

    const read = await a.client.from('reports').select('*');
    expect(read.error?.code).toBe('42501');
    const direct = await a.client.from('reports').insert({ target_kind: 'user', target_id: b.id, reason: 'direct' });
    expect(direct.error).toBeNull();
    const forged = await a.client.from('reports').insert({ reporter_id: b.id, target_kind: 'user', target_id: a.id, reason: 'forged' });
    expect(forged.error?.code).toBe('42501');

    await expectRpcError(rpc(stranger.client, 'report', { p_target_kind: 'post', p_target_id: post.id, p_reason: 'x' }), 'target_not_found', 404);
    await expectRpcError(rpc(stranger.client, 'report', { p_target_kind: 'user', p_target_id: a.id, p_reason: 'x' }), 'target_not_found', 404);
    await expectRpcError(rpc(a.client, 'report', { p_target_kind: 'user', p_target_id: a.id, p_reason: 'x' }), 'target_not_found', 404);
    await expectRpcError(rpc(a.client, 'report', { p_target_kind: 'post', p_target_id: post.id, p_reason: ' ' }), 'invalid_reason', 400);
  });
});

describe('devices', () => {
  it('register_device upserts by push token and moves it between accounts', async () => {
    const token = `apns-${randomUUID()}`;
    const d = await rpc(a.client, 'register_device', {
      p_platform: 'ios',
      p_push_token: token,
      p_push_to_start_token: 'pts',
      p_live_activities_enabled: true,
    });
    expect(d).toMatchObject({ user_id: a.id, platform: 'ios', push_token: token, push_to_start_token: 'pts', live_activities_enabled: true });
    expect(d).not.toHaveProperty('widget_push_token'); // migration 0040: no WidgetKit push token
    // Live Activities turned off in Settings: reported, the token kept (the worker sends the alert instead)
    const off = await rpc(a.client, 'register_device', { p_platform: 'ios', p_push_token: token, p_push_to_start_token: 'pts', p_live_activities_enabled: false });
    expect(off).toMatchObject({ id: d.id, push_to_start_token: 'pts', live_activities_enabled: false });
    const d2 = await rpc(a.client, 'register_device', { p_platform: 'ios', p_push_token: token, p_push_to_start_token: 'pts2' });
    expect(d2.id).toBe(d.id);
    expect(d2.live_activities_enabled).toBeNull(); // not reported
    // same physical device, other account signs in
    const moved = await rpc(b.client, 'register_device', { p_platform: 'ios', p_push_token: token });
    expect(moved.user_id).toBe(b.id);
    expect((await select(a.client, 'devices')).map((x: any) => x.push_token)).not.toContain(token);
    expect((await select(b.client, 'devices')).map((x: any) => x.push_token)).toContain(token);
  });

  it('validates tokens and platform; unregister and direct delete remove own rows only', async () => {
    await expectRpcError(rpc(a.client, 'register_device', { p_platform: 'android', p_push_token: 'fcm', p_push_to_start_token: 'x' }), 'invalid_token', 400);
    await expectRpcError(rpc(a.client, 'register_device', { p_platform: 'android', p_push_token: 'fcm', p_live_activities_enabled: true }), 'invalid_token', 400);
    await expectRpcError(rpc(a.client, 'register_device', { p_platform: 'ios', p_push_token: '' }), 'invalid_token', 400);
    const fcm = `fcm-${randomUUID()}`;
    await rpc(a.client, 'register_device', { p_platform: 'android', p_push_token: fcm });
    const other = await b.client.from('devices').delete().eq('push_token', fcm).select();
    expect(other.data).toEqual([]);
    await rpc(b.client, 'unregister_device', { p_push_token: fcm }); // not theirs: no effect
    expect((await select(a.client, 'devices')).map((x: any) => x.push_token)).toContain(fcm);
    await rpc(a.client, 'unregister_device', { p_push_token: fcm });
    expect((await select(a.client, 'devices')).map((x: any) => x.push_token)).not.toContain(fcm);
    const ins = await a.client.from('devices').insert({ user_id: a.id, platform: 'ios', push_token: 'direct' });
    expect(ins.error?.code).toBe('42501');
  });
});

describe('set_quiet_hours', () => {
  it('sets, replaces and clears; own row only', async () => {
    const r = await rpc(a.client, 'set_quiet_hours', { p_start: '22:00', p_end: '07:00', p_time_zone: 'America/Chicago' });
    expect(r).toMatchObject({ user_id: a.id, quiet_start: '22:00:00', quiet_end: '07:00:00', time_zone: 'America/Chicago' });
    const cleared = await rpc(a.client, 'set_quiet_hours', { p_start: null, p_end: null, p_time_zone: null });
    expect(cleared.quiet_start).toBeNull();
    await expectRpcError(rpc(a.client, 'set_quiet_hours', { p_start: '22:00', p_end: null, p_time_zone: 'UTC' }), 'invalid_quiet_hours', 400);
    await expectRpcError(rpc(a.client, 'set_quiet_hours', { p_start: '22:00', p_end: '06:00', p_time_zone: 'Nope/Nope' }), 'invalid_time_zone', 400);
    expect((await select(b.client, 'notification_settings')).map((x: any) => x.user_id)).not.toContain(a.id);
    const w = await a.client.from('notification_settings').update({ quiet_start: '01:00' }).eq('user_id', a.id);
    expect(w.error?.code).toBe('42501');
  });
});

describe('set_birthday', () => {
  it('opt-in needs a date; opting out cancels pending requests', async () => {
    await expectRpcError(rpc(b.client, 'set_birthday', { p_birthday: null, p_opt_in: true }), 'invalid_birthday', 400);
    await expectRpcError(rpc(b.client, 'set_birthday', { p_birthday: '2999-01-01', p_opt_in: true }), 'invalid_birthday', 400);
    const r = await rpc(b.client, 'set_birthday', { p_birthday: '1990-07-04', p_opt_in: true });
    expect(r).toMatchObject({ user_id: b.id, birthday: '1990-07-04', birthday_opt_in: true });
    await sql(
      `insert into public.tribute_requests (group_id, honoree_id, birthday_date, due_at) values ($1, $2, current_date + 3, now() + interval '3 days')`,
      [g.id, b.id],
    );
    const off = await rpc(b.client, 'set_birthday', { p_birthday: '1990-07-04', p_opt_in: false });
    expect(off.birthday_opt_in).toBe(false);
    expect(await sql(`select 1 from public.tribute_requests where honoree_id = $1`, [b.id])).toEqual([]);
    // nobody else can read it
    expect((await select(a.client, 'profile_private')).map((x: any) => x.user_id)).toEqual([a.id]);
  });
});

describe('confirm_age', () => {
  it('fails closed while min_age_years is not configured', async () => {
    try {
      await setConfig('min_age_years', null);
      await expectRpcError(rpc(a.client, 'confirm_age', { p_birthdate: '1990-01-01' }), 'age_gate_not_configured', 503);
    } finally {
      await setConfig('min_age_years', 13);
    }
  });

  it('is 13 (decision 26): rejects under-age birthdates and records the confirmation otherwise', async () => {
    expect(await getConfig('min_age_years')).toBe(13);
    const [{ d12 }] = await sql<{ d12: string }>(`select to_char(current_date - interval '13 years' + interval '1 day', 'YYYY-MM-DD') as d12`);
    await expectRpcError(rpc(a.client, 'confirm_age', { p_birthdate: d12 }), 'under_minimum_age', 403);
    await expectRpcError(rpc(a.client, 'confirm_age', { p_birthdate: '2999-01-01' }), 'invalid_birthdate', 400);
    const [{ d13 }] = await sql<{ d13: string }>(`select to_char(current_date - interval '13 years' - interval '1 day', 'YYYY-MM-DD') as d13`);
    const r = await rpc(a.client, 'confirm_age', { p_birthdate: d13 });
    expect(r.age_confirmed_at).not.toBeNull();
    expect(r.birthday).toBeNull(); // the age-gate birthdate is not stored
  });
});

describe('entitlements', () => {
  it('readable by their owner only, written by the service role only', async () => {
    await grantPremium(a.id, '2030-01-01T00:00:00Z');
    expect(await select(a.client, 'entitlements')).toEqual([
      expect.objectContaining({ user_id: a.id, entitlement: 'premium', source: 'test' }),
    ]);
    expect(await select(b.client, 'entitlements')).toEqual([]);
    const w = await b.client.from('entitlements').insert({ user_id: b.id, entitlement: 'premium', source: 'self' });
    expect(w.error?.code).toBe('42501');
  });
});

describe('app_config / public_app_config', () => {
  it('clients read only the public keys; app_config itself is service-role only', async () => {
    const { data, error } = await anon.from('public_app_config').select('*');
    expect(error).toBeNull();
    const keys = (data ?? []).map((r: any) => r.key).sort();
    expect(keys).toEqual([
      'free_history_days',
      'invitation_window_seconds',
      'max_group_members',
      'min_age_years',
      'overnight_reveal_local_time',
      'week_start_isodow',
      'weekly_question_keys',
    ]);
    const direct = await a.client.from('app_config').select('*');
    expect(direct.error?.code).toBe('42501');
    const svc = await admin.from('app_config').select('key');
    expect(svc.error).toBeNull();
    expect((svc.data ?? []).length).toBeGreaterThan(10);
  });

  it('documents the sourced defaults and leaves the unsourced tunables NULL', async () => {
    // migration 0012: default waking window (BeReal sample, design/research/bereal.md §1) and the
    // fallback collage option pending the owner's choice (design/collage-options/README.md)
    expect(await getConfig('default_waking_start')).toBe('09:48');
    expect(await getConfig('default_waking_end')).toBe('21:12');
    expect(await getConfig('collage_option')).toBe('B');
    expect(await getConfig('free_history_days')).toBeNull();
    expect(await getConfig('min_age_years')).toBe(13); // decision 26, migration 0026
    expect(await getConfig('invite_ttl_seconds')).toBeNull(); // decision 27: links do not expire
    // an optional owner override; NULL = the end of each group's waking window (migration 0014)
    expect(await getConfig('weekly_recap_local_time')).toBeNull();
    expect(await getConfig('invitation_window_seconds')).toBe(120);
    expect(await getConfig('max_group_members')).toBe(30);
    expect(await getConfig('week_start_isodow')).toBe(1);
  });
});
