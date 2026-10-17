// Security invariant 1: a user who is not a member of group G can read nothing
// belonging to G — no row in any table or view, no storage object, no RPC result,
// no Realtime event. Tables and functions are enumerated from the catalog, so a new
// table or RPC without coverage here fails this test.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  closeDb,
  createGroup,
  createMedia,
  createUsers,
  rpc,
  RpcError,
  sleep,
  sql,
  type TestUser,
  waitFor,
  waitForRealtimeSubscriptions,
} from '../helpers';
import { allRowsJson, anchorIds, publicRelations, seedFullGroup, type SeededGroup } from './world';

let gUsers: TestUser[];
let outsider: TestUser;
let hMate: TestUser;
let seeded: SeededGroup;
let anchors: Set<string>;

// Relations that hold no group data at all (global, non-personal configuration).
const NOT_GROUP_DATA = new Set(['app_config', 'public_app_config']);

beforeAll(async () => {
  gUsers = await createUsers(4, 'Gee');
  [outsider, hMate] = await createUsers(2, 'Aitch');
  seeded = await seedFullGroup(gUsers, 'Group G');
  // the outsider has a full life of their own in group H
  const h = await createGroup(outsider, [hMate], { name: 'Group H' });
  const m = await createMedia(outsider);
  await rpc(outsider.client, 'create_post', { p_media_id: m.id, p_group_ids: [h.id] });
  await rpc(hMate.client, 'send_message', { p_group_id: h.id, p_kind: 'text', p_body: 'hi H' });
  anchors = await anchorIds(
    [seeded.group.id, ...gUsers.map((u) => u.id)],
    [outsider.id, hMate.id, h.id],
  );
});

afterAll(closeDb);

function mentionsG(row: unknown): string | undefined {
  const j = JSON.stringify(row);
  return [...anchors].find((a) => j.includes(a));
}

describe('group isolation: tables and views', () => {
  it('every public table has RLS enabled', async () => {
    const rows = await sql<{ relname: string }>(
      `select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity`,
    );
    expect(rows.map((r) => r.relname)).toEqual([]);
  });

  it('every table holding group data is seeded for G (coverage guard)', async () => {
    const rels = await publicRelations();
    expect(rels.length).toBeGreaterThan(25);
    const uncovered: string[] = [];
    for (const r of rels) {
      if (NOT_GROUP_DATA.has(r.name)) continue;
      const rows = await allRowsJson(r.name);
      if (!rows.some((j) => [...anchors].some((a) => j.includes(a)))) uncovered.push(r.name);
    }
    // A new table must be seeded in tests/security/world.ts (or listed in NOT_GROUP_DATA with a reason).
    expect(uncovered).toEqual([]);
  });

  it('the outsider reads zero rows of G from every table and view', async () => {
    const rels = await publicRelations();
    const leaks: string[] = [];
    for (const r of rels) {
      const { data, error } = await outsider.client.from(r.name).select('*').limit(1000);
      if (error) {
        // no grant at all (service-role-only tables) is also "zero rows"
        expect(error.code, `${r.name}: ${error.message}`).toBe('42501');
        continue;
      }
      for (const row of data ?? []) {
        const hit = mentionsG(row);
        if (hit) leaks.push(`${r.name}: ${hit}`);
      }
    }
    expect(leaks).toEqual([]);
  });

  it('anon reads nothing from any table (only the public config view)', async () => {
    const { anon } = await import('../helpers');
    for (const r of await publicRelations()) {
      const { data, error } = await anon.from(r.name).select('*').limit(5);
      if (r.name === 'public_app_config') {
        expect(error).toBeNull();
        continue;
      }
      if (error) expect(error.code).toBe('42501');
      else expect(data, r.name).toEqual([]);
    }
  });
});

describe('group isolation: RPCs', () => {
  // Every function executable by `authenticated` must be listed here.
  type Call = { args: () => Record<string, unknown>; expect: 'error' | 'empty' | 'own-account' | 'capability' };
  const calls: Record<string, Call> = {
    create_group: { args: () => ({}), expect: 'own-account' }, // creates the caller's own group
    update_group: { args: () => ({ p_group_id: seeded.group.id, p_name: 'x' }), expect: 'error' },
    create_invite: { args: () => ({ p_group_id: seeded.group.id }), expect: 'error' },
    revoke_invite: { args: () => ({ p_token: seeded.inviteToken }), expect: 'error' },
    // the invite token is a capability: holders see the preview projection (checked below)
    invite_preview: { args: () => ({ p_token: seeded.inviteToken }), expect: 'capability' },
    join_group: { args: () => ({}), expect: 'capability' },
    remove_member: { args: () => ({ p_group_id: seeded.group.id, p_user_id: gUsers[1].id }), expect: 'error' },
    leave_group: { args: () => ({ p_group_id: seeded.group.id }), expect: 'error' },
    set_group_muted: { args: () => ({ p_group_id: seeded.group.id, p_muted: true }), expect: 'error' },
    set_group_invitation_hours: {
      args: () => ({ p_group_id: seeded.group.id, p_start: '09:00', p_end: '10:00' }),
      expect: 'error',
    },
    set_group_invitation_paused: { args: () => ({ p_group_id: seeded.group.id, p_paused: true }), expect: 'error' },
    create_post: { args: () => ({ p_media_id: seeded.mediaIds[0], p_group_ids: [seeded.group.id] }), expect: 'error' },
    send_message: { args: () => ({ p_group_id: seeded.group.id, p_kind: 'text', p_body: 'x' }), expect: 'error' },
    delete_message: { args: () => ({ p_message_id: seeded.messageIds[0] }), expect: 'error' },
    react: { args: () => ({ p_post_id: seeded.postIds[0], p_emoji: '🙂' }), expect: 'error' },
    unreact: { args: () => ({ p_post_id: seeded.postIds[0], p_emoji: '🔥' }), expect: 'error' },
    tag_self: { args: () => ({ p_post_id: seeded.postIds[0] }), expect: 'error' },
    untag_self: { args: () => ({ p_post_id: seeded.postIds[0] }), expect: 'empty' },
    delete_media: { args: () => ({ p_media_id: seeded.mediaIds[0] }), expect: 'error' },
    delete_post: { args: () => ({ p_post_id: seeded.postIds[0] }), expect: 'error' },
    delete_account: { args: () => ({}), expect: 'own-account' },
    block_user: { args: () => ({ p_user_id: gUsers[0].id }), expect: 'empty' },
    unblock_user: { args: () => ({ p_user_id: gUsers[0].id }), expect: 'empty' },
    report: { args: () => ({ p_target_kind: 'post', p_target_id: seeded.postIds[0], p_reason: 'x' }), expect: 'error' },
    register_device: { args: () => ({}), expect: 'own-account' },
    unregister_device: { args: () => ({}), expect: 'own-account' },
    set_quiet_hours: { args: () => ({}), expect: 'own-account' },
    set_birthday: { args: () => ({}), expect: 'own-account' },
    confirm_age: { args: () => ({}), expect: 'own-account' },
    wall: { args: () => ({ p_user_id: gUsers[0].id }), expect: 'empty' },
    group_history_weeks: { args: () => ({ p_group_id: seeded.group.id }), expect: 'error' },
    group_collages: { args: () => ({ p_group_id: seeded.group.id }), expect: 'error' },
    open_invitations: { args: () => ({ p_group_ids: [seeded.group.id] }), expect: 'error' },
    on_this_day: { args: () => ({ p_group_id: seeded.group.id, p_local_date: '2027-01-01' }), expect: 'error' },
    update_recap: { args: () => ({ p_recap_id: seeded.recapId, p_text: 'x' }), expect: 'error' },
    save_album: {
      args: () => ({ p_group_id: seeded.group.id, p_name: 'x', p_post_ids: [seeded.postIds[0]] }),
      expect: 'error',
    },
    rename_album: { args: () => ({ p_album_id: seeded.albumId, p_name: 'x' }), expect: 'error' },
    delete_album: { args: () => ({ p_album_id: seeded.albumId }), expect: 'error' },
    contribute_tribute: {
      args: () => ({ p_request_id: seeded.requestId, p_post_id: seeded.postIds[0], p_line: 'x' }),
      expect: 'error',
    },
    react_with_selfie: {
      args: () => ({ p_post_id: seeded.postIds[0], p_image_path: `u/${outsider.id}/selfies/x.jpg` }),
      expect: 'error',
    },
    remove_selfie_reaction: { args: () => ({ p_post_id: seeded.postIds[0] }), expect: 'error' },
    create_plan: {
      args: () => ({ p_group_id: seeded.group.id, p_title: 'x', p_starts_at: new Date(Date.now() + 86_400_000 * 3).toISOString() }),
      expect: 'error',
    },
    update_plan: {
      args: () => ({ p_plan_id: seeded.planId, p_title: 'x', p_starts_at: new Date(Date.now() + 86_400_000 * 3).toISOString() }),
      expect: 'error',
    },
    cancel_plan: { args: () => ({ p_plan_id: seeded.planId }), expect: 'error' },
    restore_plan: { args: () => ({ p_plan_id: seeded.planId }), expect: 'error' },
    answer_plan: { args: () => ({ p_plan_id: seeded.planId, p_answer: 'going' }), expect: 'error' },
    clear_answer: { args: () => ({ p_plan_id: seeded.planId }), expect: 'error' },
    plan_photos: { args: () => ({ p_plan_id: seeded.planId }), expect: 'error' },
    next_plans: { args: () => ({}), expect: 'empty' },
    group_plans: { args: () => ({ p_group_id: seeded.group.id }), expect: 'error' },
    group_tributes: { args: () => ({ p_group_id: seeded.group.id }), expect: 'error' },
    create_overnight_post: {
      args: () => ({ p_media_id: seeded.mediaIds[0], p_group_ids: [seeded.group.id] }),
      expect: 'error',
    },
    group_developing: { args: () => ({ p_group_id: seeded.group.id }), expect: 'error' },
    my_developing: { args: () => ({}), expect: 'own-account' },
    set_overnight_alerts: { args: () => ({}), expect: 'own-account' },
    set_group_weekly_question: { args: () => ({ p_group_id: seeded.group.id, p_on: true }), expect: 'error' },
    current_group_question: { args: () => ({ p_group_id: seeded.group.id }), expect: 'error' },
    hide_question: { args: () => ({ p_question_id: seeded.questionId }), expect: 'error' },
    answer_question: { args: () => ({ p_post_id: seeded.postIds[0], p_question_id: seeded.questionId }), expect: 'error' },
    // widgets (0036): the caller's own picker and memories; a G member's photos are not the outsider's to see
    widget_people: { args: () => ({}), expect: 'own-account' },
    newest_photos_of: { args: () => ({ p_user_id: gUsers[0].id }), expect: 'empty' },
    my_memories: { args: () => ({ p_from: '2027-01-01', p_days: 3, p_time_zone: 'UTC' }), expect: 'own-account' },
    // memories for you only (0038): a G photo is not the outsider's to hide or favorite; the lists are the caller's own
    hide_memory: { args: () => ({ p_media_id: seeded.mediaIds[0] }), expect: 'error' },
    unhide_memory: { args: () => ({ p_id: seeded.memoryHideId }), expect: 'empty' },
    my_hidden_memories: { args: () => ({}), expect: 'own-account' },
    set_favorite: { args: () => ({ p_media_id: seeded.mediaIds[0], p_on: true }), expect: 'error' },
    my_favorites: { args: () => ({}), expect: 'own-account' },
  };

  it('every RPC callable by authenticated users is covered here', async () => {
    const rows = await sql<{ proname: string }>(
      `select distinct p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and has_function_privilege('authenticated', p.oid, 'EXECUTE')
        order by 1`,
    );
    const missing = rows.map((r) => r.proname).filter((n) => !(n in calls));
    expect(missing).toEqual([]);
  });

  it('every RPC given G ids errors or returns nothing, and changes nothing', async () => {
    const before = await snapshotG();
    for (const [fn, c] of Object.entries(calls)) {
      if (c.expect === 'own-account' || c.expect === 'capability') continue;
      let data: unknown;
      let err: unknown;
      try {
        data = await rpc(outsider.client, fn, c.args());
      } catch (e) {
        err = e;
      }
      if (c.expect === 'error') {
        expect(err, fn).toBeInstanceOf(RpcError);
        expect(['PT403', 'PT404'], `${fn}: ${(err as RpcError).sqlstate}`).toContain((err as RpcError).sqlstate);
      } else {
        expect(err, fn).toBeUndefined();
        if (Array.isArray(data)) expect(data, fn).toEqual([]);
        else expect(data ?? null, fn).toBeNull();
      }
    }
    await rpc(outsider.client, 'unblock_user', { p_user_id: gUsers[0].id });
    expect(await snapshotG()).toEqual(before);
  });

  it('the outsider cannot post the G member media into their own group', async () => {
    const h = await rpc(outsider.client, 'create_group', { p_name: 'H2', p_kind: 'custom', p_time_zone: 'UTC' });
    const e = await rpc(outsider.client, 'create_post', { p_media_id: seeded.mediaIds[0], p_group_ids: [h.id] }).catch(
      (x) => x,
    );
    expect(e).toBeInstanceOf(RpcError);
    expect(e.code).toBe('media_not_found');
  });

  it('invite_preview exposes only the documented projection', async () => {
    const p = await rpc(outsider.client, 'invite_preview', { p_token: seeded.inviteToken });
    expect(Object.keys(p).sort()).toEqual(['cover_path', 'group_kind', 'group_name', 'inviter_avatar_path', 'inviter_first_name', 'members']);
    for (const m of p.members) expect(Object.keys(m).sort()).toEqual(['avatar_path', 'first_name']);
    // Storage paths embed their owner's user id (path convention); nothing else may.
    const withoutPaths = JSON.stringify({
      ...p,
      cover_path: null,
      inviter_avatar_path: null,
      members: p.members.map((m: any) => ({ ...m, avatar_path: null })),
    });
    for (const u of gUsers) expect(withoutPaths).not.toContain(u.id);
    expect(JSON.stringify(p)).not.toContain(seeded.group.id);
  });

  it('service-role-only functions are not callable by clients', async () => {
    const rows = await sql<{ proname: string }>(
      `select distinct p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and has_function_privilege('service_role', p.oid, 'EXECUTE')
          and not has_function_privilege('authenticated', p.oid, 'EXECUTE')`,
    );
    const names = rows.map((r) => r.proname);
    expect(names).toEqual(
      expect.arrayContaining([
        'claim_jobs',
        'complete_job',
        'fail_job',
        'enqueue_job',
        'schedule_daily_invitations',
        'due_weekly_recaps',
        'due_birthday_requests',
        'due_tributes',
        'due_year_stories',
        'due_developed_posts',
        'due_unlinked_uploads',
      ]),
    );
    for (const fn of names) {
      const { error } = await outsider.client.rpc(fn, {});
      expect(error, fn).not.toBeNull();
    }
  });

  async function snapshotG() {
    const out: Record<string, number> = {};
    for (const r of await publicRelations()) {
      if (r.type !== 'BASE TABLE' || r.name === 'jobs') continue;
      out[r.name] = (await allRowsJson(r.name)).filter((j) => [...anchors].some((a) => j.includes(a))).length;
    }
    return out;
  }
});

describe('group isolation: storage', () => {
  it('the outsider can neither sign, download nor list any object of G', async () => {
    const bucket = outsider.client.storage.from('media');
    expect(seeded.objectPaths.length).toBeGreaterThan(8);
    for (const path of seeded.objectPaths) {
      const signed = await bucket.createSignedUrl(path, 60);
      expect(signed.error, `sign ${path}`).not.toBeNull();
      const dl = await bucket.download(path);
      expect(dl.error, `download ${path}`).not.toBeNull();
    }
    for (const prefix of [`g/${seeded.group.id}`, `u/${gUsers[0].id}`, `avatars/${gUsers[0].id}`]) {
      const { data } = await bucket.list(prefix);
      expect(data ?? []).toEqual([]);
    }
  });

  it('(positive control) a member can sign the same objects', async () => {
    // the birthday video is its honoree's and its contributors' once delivered (migration 0034): a contributed
    await sql(`update public.tributes set delivered_at = now() - interval '1 minute' where id = $1`, [seeded.tributeId]);
    for (const path of seeded.objectPaths) {
      const member = path.includes('/tributes/') ? gUsers[0] : gUsers[1];
      const signed = await member.client.storage.from('media').createSignedUrl(path, 60);
      expect(signed.error, path).toBeNull();
    }
  });
});

describe('group isolation: realtime', () => {
  it('the outsider receives no postgres_changes or broadcast event of G', async () => {
    const [a, b] = gUsers;
    const outsiderEvents: string[] = [];
    const memberEvents: string[] = [];

    const subscribe = async (u: TestUser, sink: string[], tag: string) => {
      const ch = u.client
        .channel(`${tag}-changes-${Math.random()}`)
        .on('postgres_changes', { event: '*', schema: 'public', table: 'messages' }, (p) =>
          sink.push(`messages:${p.eventType}`),
        )
        .on('postgres_changes', { event: '*', schema: 'public', table: 'posts' }, (p) =>
          sink.push(`posts:${p.eventType}`),
        )
        .on('postgres_changes', { event: '*', schema: 'public', table: 'reactions' }, (p) =>
          sink.push(`reactions:${p.eventType}`),
        );
      const topic = u.client
        .channel(`group:${seeded.group.id}`, { config: { private: true } })
        .on('broadcast', { event: '*' }, (p) => sink.push(`broadcast:${p.event}`));
      const states: string[] = [];
      await new Promise<void>((resolve) => ch.subscribe((s) => (s === 'SUBSCRIBED' ? resolve() : undefined)));
      await new Promise<void>((resolve) => {
        topic.subscribe((s) => {
          states.push(s);
          if (s === 'SUBSCRIBED' || s === 'CHANNEL_ERROR' || s === 'CLOSED') resolve();
        });
        setTimeout(resolve, 5000);
      });
      return { ch, topic, states };
    };

    const o = await subscribe(outsider, outsiderEvents, 'o');
    const m = await subscribe(b, memberEvents, 'm');
    expect(m.states).toContain('SUBSCRIBED');
    expect(o.states).not.toContain('SUBSCRIBED');
    await waitForRealtimeSubscriptions(outsider.id, 3);
    await waitForRealtimeSubscriptions(b.id, 3);

    const media = await createMedia(a);
    const posts = await rpc<any[]>(a.client, 'create_post', { p_media_id: media.id, p_group_ids: [seeded.group.id] });
    const msg = await rpc(a.client, 'send_message', { p_group_id: seeded.group.id, p_kind: 'text', p_body: 'rt' });
    await rpc(a.client, 'react', { p_post_id: posts[0].id, p_emoji: '🎉' });
    // Realtime re-reads an inserted row to apply RLS: wait for the inserts before deleting
    await waitFor(() => ['posts:INSERT', 'messages:INSERT', 'reactions:INSERT'].every((e) => memberEvents.includes(e)));
    await rpc(a.client, 'unreact', { p_post_id: posts[0].id, p_emoji: '🎉' });
    await rpc(a.client, 'delete_message', { p_message_id: msg.id });
    await rpc(a.client, 'delete_media', { p_media_id: media.id });
    await waitFor(() => memberEvents.includes('broadcast:post_deleted'));
    await sleep(1500);

    // positive control: the member got inserts and the deletion broadcasts
    expect(memberEvents).toEqual(
      expect.arrayContaining([
        'posts:INSERT',
        'messages:INSERT',
        'reactions:INSERT',
        'broadcast:reactions_changed',
        'broadcast:message_deleted',
        'broadcast:post_deleted',
      ]),
    );
    // DELETE events are never published through postgres_changes
    expect(memberEvents.filter((e) => e.endsWith(':DELETE'))).toEqual([]);
    expect(outsiderEvents).toEqual([]);

    await outsider.client.removeAllChannels();
    await b.client.removeAllChannels();
  });
});
