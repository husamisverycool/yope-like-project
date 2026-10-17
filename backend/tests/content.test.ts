// Posting, chat, reactions, self-tags, deletion RPCs and the policies of media,
// posts, messages, reactions and post_tags.
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  closeDb,
  createGroup,
  createMedia,
  createUsers,
  expectRpcError,
  grantPremium,
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
let g1: TestGroup, g2: TestGroup, other: TestGroup;

beforeAll(async () => {
  [a, b, c, stranger] = await createUsers(4, 'Cnt');
  g1 = await createGroup(a, [b, c], { name: 'one' });
  g2 = await createGroup(a, [b], { name: 'two' });
  other = await createGroup(stranger, [], { name: 'other' });
});

afterAll(closeDb);

describe('media table policies', () => {
  it('owner inserts media whose paths are under u/<owner>/<media id>/', async () => {
    const m = await createMedia(a, { dual: true });
    const rows = await select(a.client, 'media', (q) => q.eq('id', m.id));
    expect(rows[0]).toMatchObject({ owner_id: a.id, kind: 'photo', front_original_path: m.frontPath });
  });

  it('rejects paths outside the owner/media folder, other owners and worker columns', async () => {
    const id = randomUUID();
    const r1 = await a.client.from('media').insert({ id, kind: 'photo', original_path: `u/${b.id}/${id}/x.jpg` });
    expect(r1.error?.code).toBe('23514');
    const r2 = await a.client.from('media').insert({ id, kind: 'photo', original_path: `u/${a.id}/${randomUUID()}/x.jpg` });
    expect(r2.error?.code).toBe('23514');
    const r3 = await a.client.from('media').insert({ id, owner_id: b.id, kind: 'photo', original_path: `u/${b.id}/${id}/x.jpg` });
    expect(r3.error?.code).toBe('42501');
    const r4 = await a.client.from('media').insert({ id, kind: 'photo', original_path: `u/${a.id}/${id}/x.jpg`, display_path: `u/${a.id}/${id}/d.jpg` });
    expect(r4.error?.code).toBe('42501');
    const r5 = await a.client.from('media').insert({ id, kind: 'video', original_path: `u/${a.id}/${id}/x.mp4` });
    expect(r5.error?.code).toBe('23514'); // video needs duration_ms
    const r6 = await a.client.from('media').insert({ id, kind: 'photo', original_path: `u/${a.id}/${id}/../x.jpg` });
    expect(r6.error?.code).toBe('23514');
  });

  it('media is not updatable or deletable directly; unposted media is visible to its owner only', async () => {
    const m = await createMedia(a);
    const u = await a.client.from('media').update({ width: 5 }).eq('id', m.id);
    expect(u.error?.code).toBe('42501');
    const d = await a.client.from('media').delete().eq('id', m.id);
    expect(d.error?.code).toBe('42501');
    expect(await select(b.client, 'media', (q) => q.eq('id', m.id))).toEqual([]);
    await rpc(a.client, 'create_post', { p_media_id: m.id, p_group_ids: [g2.id] });
    expect(await select(b.client, 'media', (q) => q.eq('id', m.id))).toHaveLength(1);
    expect(await select(c.client, 'media', (q) => q.eq('id', m.id))).toEqual([]); // c is not in g2
  });
});

describe('create_post', () => {
  it('posts to several groups: one post and one photo message per group, plus jobs', async () => {
    const m = await createMedia(a);
    const posts = await rpc<any[]>(a.client, 'create_post', {
      p_media_id: m.id,
      p_group_ids: [g1.id, g2.id, g1.id],
      p_caption: 'sunset',
    });
    expect(posts).toHaveLength(2);
    expect(new Set(posts.map((p) => p.group_id))).toEqual(new Set([g1.id, g2.id]));
    for (const p of posts) {
      expect(p).toMatchObject({ media_id: m.id, author_id: a.id, caption: 'sunset', in_window: false, invitation_id: null });
      const msgs = await select(b.client, 'messages', (q) => q.eq('post_id', p.id));
      expect(msgs).toEqual([expect.objectContaining({ kind: 'photo', group_id: p.group_id, author_id: a.id, body: null })]);
      expect(await jobsWhere('push.new_post', { post_id: p.id })).toHaveLength(1);
    }
    expect(await jobsWhere('media.renditions', { media_id: m.id })).toHaveLength(1);
    const refresh = await sql(`select payload ->> 'group_id' as g from public.jobs where kind = 'widget.refresh' and status = 'queued'`);
    expect(refresh.map((r: any) => r.g)).toEqual(expect.arrayContaining([g1.id, g2.id]));
  });

  it('refuses groups the caller is not in, media that is not theirs, empty targets and duplicates', async () => {
    const m = await createMedia(a);
    await expectRpcError(rpc(a.client, 'create_post', { p_media_id: m.id, p_group_ids: [g1.id, other.id] }), 'not_group_member', 403);
    expect(await sql(`select 1 from public.posts where media_id = $1`, [m.id])).toEqual([]); // all or nothing
    await expectRpcError(rpc(b.client, 'create_post', { p_media_id: m.id, p_group_ids: [g1.id] }), 'media_not_found', 404);
    await expectRpcError(rpc(a.client, 'create_post', { p_media_id: m.id, p_group_ids: [] }), 'no_groups', 400);
    await rpc(a.client, 'create_post', { p_media_id: m.id, p_group_ids: [g1.id] });
    await expectRpcError(rpc(a.client, 'create_post', { p_media_id: m.id, p_group_ids: [g1.id] }), 'already_posted', 409);
    await expectRpcError(
      rpc(a.client, 'create_post', { p_media_id: (await createMedia(a)).id, p_group_ids: [g1.id], p_caption: 'x'.repeat(1001) }),
      'invalid_caption',
      400,
    );
  });

  it('video needs an active premium entitlement; nothing else does', async () => {
    const [v] = await createUsers(1, 'Vid');
    const g = await createGroup(v);
    const video = await createMedia(v, { kind: 'video' });
    await expectRpcError(rpc(v.client, 'create_post', { p_media_id: video.id, p_group_ids: [g.id] }), 'premium_required', 402);
    await grantPremium(v.id, new Date(Date.now() - 1000).toISOString()); // expired
    await expectRpcError(rpc(v.client, 'create_post', { p_media_id: video.id, p_group_ids: [g.id] }), 'premium_required', 402);
    const live = await createMedia(v, { kind: 'live_photo' });
    expect(await rpc(v.client, 'create_post', { p_media_id: live.id, p_group_ids: [g.id] })).toHaveLength(1);
    await grantPremium(v.id, null);
    expect(await rpc(v.client, 'create_post', { p_media_id: video.id, p_group_ids: [g.id] })).toHaveLength(1);
  });

  it('short videos: create_post refuses a video longer than video_max_ms, in the whole seconds the apps show', async () => {
    const [v] = await createUsers(1, 'Short');
    const g = await createGroup(v);
    await grantPremium(v.id, null);
    const [{ value }] = await sql<{ value: number }>(`select value from public.public_app_config where key = 'video_max_ms'`);
    expect(value).toBe(10000); // camera.capture.duration.videoMax
    const video = async (durationMs: number) => {
      const id = randomUUID();
      const path = await upload(v, `u/${v.id}/${id}/original.mp4`, 'video/mp4');
      const { error } = await v.client.from('media').insert({ id, kind: 'video', original_path: path, width: 1, height: 1, duration_ms: durationMs });
      expect(error).toBeNull();
      return id;
    };
    // 10,999 ms reads "0:10" (a recording stopped at the limit overshoots by a few frames): accepted.
    for (const ms of [1, 10000, 10999]) {
      expect(await rpc(v.client, 'create_post', { p_media_id: await video(ms), p_group_ids: [g.id] })).toHaveLength(1);
    }
    for (const ms of [11000, 60000, 3_600_000]) {
      await expectRpcError(rpc(v.client, 'create_post', { p_media_id: await video(ms), p_group_ids: [g.id] }), 'video_too_long', 400);
    }
    // Clients cannot shorten the length after the fact (no update on media).
    const long = await video(60000);
    const upd = await v.client.from('media').update({ duration_ms: 5000 }).eq('id', long);
    expect(upd.error?.code).toBe('42501');
    await expectRpcError(rpc(v.client, 'create_post', { p_media_id: long, p_group_ids: [g.id] }), 'video_too_long', 400);
    // Live Photos are not videos: their motion length is not limited here.
    const live = await createMedia(v, { kind: 'live_photo' });
    expect(await rpc(v.client, 'create_post', { p_media_id: live.id, p_group_ids: [g.id] })).toHaveLength(1);
  });

  it('in_window only for an open invitation of that group; otherwise an ordinary post (no "late" flag)', async () => {
    const [inv] = await sql<{ id: string }>(
      `insert into public.daily_invitations (group_id, local_date, fires_at, closes_at, status)
       values ($1, current_date + 400, now() - interval '30 seconds', now() + interval '90 seconds', 'fired') returning id`,
      [g1.id],
    );
    const m1 = await createMedia(b);
    const posts = await rpc<any[]>(b.client, 'create_post', { p_media_id: m1.id, p_group_ids: [g1.id, g2.id], p_invitation_id: inv.id });
    const inG1 = posts.find((p) => p.group_id === g1.id);
    const inG2 = posts.find((p) => p.group_id === g2.id);
    expect(inG1).toMatchObject({ in_window: true, invitation_id: inv.id });
    expect(inG2).toMatchObject({ in_window: false, invitation_id: null });

    await sql(`update public.daily_invitations set closes_at = now() - interval '1 second', fires_at = now() - interval '121 seconds' where id = $1`, [inv.id]);
    const m2 = await createMedia(b);
    const [late] = await rpc<any[]>(b.client, 'create_post', { p_media_id: m2.id, p_group_ids: [g1.id], p_invitation_id: inv.id });
    expect(late).toMatchObject({ in_window: false, invitation_id: null });
    expect(Object.keys(late)).not.toContain('late');

    // an invitation id the caller cannot see is ignored, not an error
    const m3 = await createMedia(b);
    const [x] = await rpc<any[]>(b.client, 'create_post', { p_media_id: m3.id, p_group_ids: [g1.id], p_invitation_id: randomUUID() });
    expect(x.in_window).toBe(false);
  });

  it('in-app answers: open_invitations lists what is open now; p_invitation_ids answers each group\'s own (0035)', async () => {
    const open = async (g: TestGroup, opensAgo: number, closesIn: number) =>
      (
        await sql<{ id: string }>(
          `insert into public.daily_invitations (group_id, local_date, fires_at, closes_at, status)
           values ($1, current_date + 500 + $2::int, now() - make_interval(secs => $3), now() + make_interval(secs => $4), 'fired')
           returning id`,
          [g.id, Math.floor(Math.random() * 10_000), opensAgo, closesIn],
        )
      )[0].id;
    const inv1 = await open(g1, 20, 100);
    const inv2 = await open(g2, 60, 60);
    const scheduled = (
      await sql<{ id: string }>(
        `insert into public.daily_invitations (group_id, local_date, fires_at, closes_at, status)
         values ($1, current_date + 900, now() + interval '1 hour', now() + interval '1 hour 2 minutes', 'scheduled') returning id`,
        [g2.id],
      )
    )[0].id;
    const strangers = await open(other, 10, 110);

    // the caller's groups' open invitations, soonest to close first; not one before it fires, not another group's
    const mine = await rpc<any[]>(b.client, 'open_invitations', {});
    const ids = mine.map((i) => i.id);
    expect(ids).toContain(inv1);
    expect(ids).toContain(inv2);
    expect(ids).not.toContain(scheduled);
    expect(ids).not.toContain(strangers);
    expect(ids.indexOf(inv2)).toBeLessThan(ids.indexOf(inv1));
    expect((await rpc<any[]>(b.client, 'open_invitations', { p_group_ids: [g1.id] })).map((i) => i.id)).toEqual([inv1]);
    await expectRpcError(rpc(b.client, 'open_invitations', { p_group_ids: [other.id] }), 'not_group_member', 403);

    // one photo from the camera's send-to answers both groups' open invitations
    const m = await createMedia(b);
    const posts = await rpc<any[]>(b.client, 'create_post', { p_media_id: m.id, p_group_ids: [g1.id, g2.id], p_invitation_ids: [inv1, inv2] });
    expect(posts.find((p) => p.group_id === g1.id)).toMatchObject({ in_window: true, invitation_id: inv1 });
    expect(posts.find((p) => p.group_id === g2.id)).toMatchObject({ in_window: true, invitation_id: inv2 });

    // another group's invitation never marks a post (the stranger's group, or g1's id on g2's post)
    const m2 = await createMedia(b);
    const [crossed] = await rpc<any[]>(b.client, 'create_post', { p_media_id: m2.id, p_group_ids: [g2.id], p_invitation_ids: [inv1, strangers] });
    expect(crossed).toMatchObject({ in_window: false, invitation_id: null });

    // closed: an ordinary post, no error, no "late"
    await sql(`update public.daily_invitations set fires_at = now() - interval '200 seconds', closes_at = now() - interval '80 seconds' where id = $1`, [inv2]);
    expect((await rpc<any[]>(b.client, 'open_invitations', { p_group_ids: [g2.id] }))).toEqual([]);
    const m3 = await createMedia(b);
    const [after] = await rpc<any[]>(b.client, 'create_post', { p_media_id: m3.id, p_group_ids: [g2.id], p_invitation_ids: [inv2] });
    expect(after).toMatchObject({ in_window: false, invitation_id: null });
    expect(Object.keys(after)).not.toContain('late');
  });

  it('a photo can reply to a photo (same group only)', async () => {
    const target = (await postPhoto(b, [g1.id])).posts[0];
    const m = await createMedia(c);
    const [reply] = await rpc<any[]>(c.client, 'create_post', { p_media_id: m.id, p_group_ids: [g1.id], p_reply_to_post_id: target.id });
    expect(reply.reply_to_post_id).toBe(target.id);
    const [msg] = await select(a.client, 'messages', (q) => q.eq('post_id', reply.id));
    expect(msg.reply_to_post_id).toBe(target.id);
    const m2 = await createMedia(a);
    await expectRpcError(
      rpc(a.client, 'create_post', { p_media_id: m2.id, p_group_ids: [g2.id], p_reply_to_post_id: target.id }),
      'reply_group_mismatch',
      400,
    );
    await expectRpcError(
      rpc(stranger.client, 'create_post', { p_media_id: (await createMedia(stranger)).id, p_group_ids: [other.id], p_reply_to_post_id: target.id }),
      'post_not_found',
      404,
    );
  });

  it('a voice note must be the caller upload with a duration', async () => {
    const m = await createMedia(a);
    const voice = `u/${a.id}/${m.id}/voice.m4a`;
    await upload(a, voice, 'audio/mp4');
    await expectRpcError(rpc(a.client, 'create_post', { p_media_id: m.id, p_group_ids: [g1.id], p_voice_path: voice }), 'invalid_voice', 400);
    await expectRpcError(
      rpc(a.client, 'create_post', { p_media_id: m.id, p_group_ids: [g1.id], p_voice_path: `u/${b.id}/x.m4a`, p_voice_duration_ms: 5 }),
      'invalid_voice',
      400,
    );
    const [p] = await rpc<any[]>(a.client, 'create_post', { p_media_id: m.id, p_group_ids: [g1.id], p_voice_path: voice, p_voice_duration_ms: 2500 });
    expect(p).toMatchObject({ voice_path: voice, voice_duration_ms: 2500, voice_levels: null });
  });

  it('a voice note carries its 100 levels (0…31); levels need a voice note', async () => {
    const levels = Array.from({ length: 100 }, (_, i) => i % 32);
    const m = await createMedia(a);
    const voice = `u/${a.id}/${m.id}/voice.m4a`;
    await upload(a, voice, 'audio/mp4');
    for (const bad of [levels.slice(0, 99), [...levels, 0], levels.map((v, i) => (i === 7 ? 32 : v)), levels.map((v, i) => (i === 3 ? -1 : v))]) {
      await expectRpcError(
        rpc(a.client, 'create_post', { p_media_id: m.id, p_group_ids: [g1.id], p_voice_path: voice, p_voice_duration_ms: 2500, p_voice_levels: bad }),
        'invalid_voice',
        400,
      );
    }
    await expectRpcError(rpc(a.client, 'create_post', { p_media_id: m.id, p_group_ids: [g1.id], p_voice_levels: levels }), 'invalid_voice', 400);
    const [p] = await rpc<any[]>(a.client, 'create_post', {
      p_media_id: m.id,
      p_group_ids: [g1.id],
      p_voice_path: voice,
      p_voice_duration_ms: 2500,
      p_voice_levels: levels,
    });
    expect(p.voice_levels).toEqual(levels);
    // members read the levels with the post; outsiders see no row
    const [seen] = await select(b.client, 'posts', (q) => q.eq('id', p.id));
    expect(seen.voice_levels).toEqual(levels);
    expect(await select(stranger.client, 'posts', (q) => q.eq('id', p.id))).toEqual([]);
  });
});

describe('send_message / delete_message', () => {
  it('text and voice messages, with replies to a photo or a message', async () => {
    const post = (await postPhoto(a, [g1.id])).posts[0];
    const t = await rpc(b.client, 'send_message', { p_group_id: g1.id, p_kind: 'text', p_body: 'nice', p_reply_to_post_id: post.id });
    expect(t).toMatchObject({ kind: 'text', body: 'nice', reply_to_post_id: post.id, author_id: b.id });
    const voice = `u/${c.id}/voice/${randomUUID()}.m4a`;
    await upload(c, voice, 'audio/mp4');
    const v = await rpc(c.client, 'send_message', {
      p_group_id: g1.id,
      p_kind: 'voice',
      p_voice_path: voice,
      p_voice_duration_ms: 3000,
      p_reply_to_message_id: t.id,
    });
    expect(v).toMatchObject({ kind: 'voice', voice_path: voice, reply_to_message_id: t.id, voice_levels: null });
    expect(await jobsWhere('push.new_message', { message_id: v.id })).toHaveLength(1);
    // members can read the voice message file
    expect((await a.client.storage.from('media').createSignedUrl(voice, 60)).error).toBeNull();
  });

  it('a voice message carries its 100 levels; members read them, outsiders do not', async () => {
    const levels = Array.from({ length: 100 }, (_, i) => (i * 7) % 32);
    const voice = `u/${c.id}/voice/${randomUUID()}.m4a`;
    await upload(c, voice, 'audio/mp4');
    const send = (extra: Record<string, unknown>) =>
      rpc<any>(c.client, 'send_message', { p_group_id: g1.id, p_kind: 'voice', p_voice_path: voice, p_voice_duration_ms: 4100, ...extra });
    for (const bad of [[], levels.slice(1), levels.map((v, i) => (i === 99 ? 40 : v)), [[1, 2], [3, 4]]]) {
      await expectRpcError(send({ p_voice_levels: bad }), 'invalid_voice', 400);
    }
    await expectRpcError(
      rpc(c.client, 'send_message', { p_group_id: g1.id, p_kind: 'text', p_body: 'hi', p_voice_levels: levels }),
      'invalid_body',
      400,
    );
    const v = await send({ p_voice_levels: levels });
    expect(v.voice_levels).toEqual(levels);
    const [seen] = await select(a.client, 'messages', (q) => q.eq('id', v.id));
    expect(seen.voice_levels).toEqual(levels);
    expect(await select(stranger.client, 'messages', (q) => q.eq('id', v.id))).toEqual([]);
    // the author cannot rewrite the levels afterwards (no direct writes)
    const u = await c.client.from('messages').update({ voice_levels: levels.map(() => 0) }).eq('id', v.id);
    expect(u.error?.code).toBe('42501');
  });

  it('the table constraints refuse levels on non-voice rows and malformed levels', async () => {
    const t = await rpc<any>(b.client, 'send_message', { p_group_id: g1.id, p_kind: 'text', p_body: 'plain' });
    const levels = `array[${Array.from({ length: 100 }, () => 5).join(',')}]::smallint[]`;
    await expect(sql(`update public.messages set voice_levels = ${levels} where id = '${t.id}'`)).rejects.toThrow(/messages_voice_levels_need_voice/);
    const post = (await postPhoto(a, [g1.id])).posts[0];
    await expect(sql(`update public.posts set voice_levels = ${levels} where id = '${post.id}'`)).rejects.toThrow(/posts_voice_levels_need_voice/);
    const voice = `u/${b.id}/voice/${randomUUID()}.m4a`;
    await upload(b, voice, 'audio/mp4');
    const v = await rpc<any>(b.client, 'send_message', { p_group_id: g1.id, p_kind: 'voice', p_voice_path: voice, p_voice_duration_ms: 900 });
    await expect(sql(`update public.messages set voice_levels = array[1,2,3]::smallint[] where id = '${v.id}'`)).rejects.toThrow(/messages_voice_levels_valid/);
    await expect(sql(`update public.messages set voice_levels = ${levels.replace('5,', '99,')} where id = '${v.id}'`)).rejects.toThrow(/messages_voice_levels_valid/);
  });

  it('validates kind, body, voice and reply targets', async () => {
    await expectRpcError(rpc(b.client, 'send_message', { p_group_id: g1.id, p_kind: 'photo' }), 'invalid_kind', 400);
    await expectRpcError(rpc(b.client, 'send_message', { p_group_id: g1.id, p_kind: 'text', p_body: '   ' }), 'invalid_body', 400);
    await expectRpcError(rpc(b.client, 'send_message', { p_group_id: g1.id, p_kind: 'text', p_body: 'x'.repeat(4001) }), 'invalid_body', 400);
    await expectRpcError(
      rpc(b.client, 'send_message', { p_group_id: g1.id, p_kind: 'voice', p_voice_path: `u/${a.id}/v.m4a`, p_voice_duration_ms: 10 }),
      'invalid_voice',
      400,
    );
    await expectRpcError(rpc(stranger.client, 'send_message', { p_group_id: g1.id, p_kind: 'text', p_body: 'hi' }), 'not_group_member', 403);
    const p2 = (await postPhoto(a, [g2.id])).posts[0];
    await expectRpcError(
      rpc(b.client, 'send_message', { p_group_id: g1.id, p_kind: 'text', p_body: 'x', p_reply_to_post_id: p2.id }),
      'reply_group_mismatch',
      400,
    );
    await expectRpcError(
      rpc(b.client, 'send_message', { p_group_id: g1.id, p_kind: 'text', p_body: 'x', p_reply_to_message_id: randomUUID() }),
      'message_not_found',
      404,
    );
  });

  it('only the author deletes a message; photo messages go with delete_post', async () => {
    const t = await rpc(b.client, 'send_message', { p_group_id: g1.id, p_kind: 'text', p_body: 'oops' });
    await expectRpcError(rpc(a.client, 'delete_message', { p_message_id: t.id }), 'message_not_found', 404);
    await rpc(b.client, 'delete_message', { p_message_id: t.id });
    expect(await select(a.client, 'messages', (q) => q.eq('id', t.id))).toEqual([]);
    const post = (await postPhoto(b, [g1.id])).posts[0];
    const [pm] = await select(b.client, 'messages', (q) => q.eq('post_id', post.id));
    await expectRpcError(rpc(b.client, 'delete_message', { p_message_id: pm.id }), 'invalid_kind', 400);
  });

  it('clients cannot write posts or messages directly', async () => {
    const m = await createMedia(a);
    const r1 = await a.client.from('posts').insert({ media_id: m.id, group_id: g1.id, author_id: a.id });
    expect(r1.error?.code).toBe('42501');
    const r2 = await a.client.from('messages').insert({ group_id: g1.id, author_id: a.id, kind: 'text', body: 'x' });
    expect(r2.error?.code).toBe('42501');
    const post = (await postPhoto(a, [g1.id])).posts[0];
    const r3 = await a.client.from('posts').update({ caption: 'edited', in_window: true }).eq('id', post.id);
    expect(r3.error?.code).toBe('42501');
    const r4 = await a.client.from('posts').delete().eq('id', post.id);
    expect(r4.error?.code).toBe('42501');
  });
});

describe('react / unreact', () => {
  it('any emoji, one row per user+post+emoji, idempotent', async () => {
    const post = (await postPhoto(a, [g1.id])).posts[0];
    for (const e of ['❤️', '👍🏽', '👨‍👩‍👧‍👦', '🇫🇷', '1️⃣', '🫠']) {
      const r = await rpc(b.client, 'react', { p_post_id: post.id, p_emoji: e });
      expect(r).toMatchObject({ post_id: post.id, user_id: b.id, emoji: e, group_id: g1.id });
    }
    await rpc(b.client, 'react', { p_post_id: post.id, p_emoji: '❤️' });
    const rows = await select(c.client, 'reactions', (q) => q.eq('post_id', post.id));
    expect(rows).toHaveLength(6);
    expect(await jobsWhere('push.reaction', { post_id: post.id, emoji: '❤️' })).toHaveLength(1);
  });

  it('accepts every emoji the reaction pickers offer (skin tones, ZWJ sequences, flags, keycaps, tags)', async () => {
    // The pickers' catalog (tools/emoji-catalog.mjs: Unicode's fully-qualified RGI set, groups and skin-tone variants).
    const catalog = readFileSync(new URL('../../ios/App/Resources/EmojiCatalog.txt', import.meta.url), 'utf8');
    const all = catalog
      .split('\n')
      .filter((l) => l && !l.startsWith('# ') && !l.startsWith('@')) // "#️⃣" is an emoji, "# " a comment
      .map((l) => l.replace(/^\+/, '').split('\t')[0]);
    expect(all.length).toBeGreaterThan(3900);
    expect(new Set(all).size).toBe(all.length);
    const rejected = await sql<{ e: string }>('select e from unnest($1::text[]) e where not coalesce(private.is_emoji(e), false)', [all]);
    expect(rejected.map((r) => r.e)).toEqual([]);
    // The longest sequences and each kind of sequence, end to end through `react`.
    const post = (await postPhoto(a, [g1.id])).posts[0];
    const longest = all.reduce((x, y) => ([...y].length > [...x].length ? y : x));
    for (const e of ['❤️', '☺️', '👋🏿', '🫱🏻‍🫲🏿', '🧑🏽‍🦯‍➡️', '🏴󠁧󠁢󠁳󠁣󠁴󠁿', '#️⃣', '🇺🇳', longest]) {
      const r = await rpc(b.client, 'react', { p_post_id: post.id, p_emoji: e });
      expect(r).toMatchObject({ post_id: post.id, emoji: e });
    }
  });

  it('rejects non-emoji and invisible posts', async () => {
    const post = (await postPhoto(a, [g1.id])).posts[0];
    for (const bad of ['abc', ' ', '', 'ok👍', '👍 👍']) {
      await expectRpcError(rpc(b.client, 'react', { p_post_id: post.id, p_emoji: bad }), 'invalid_emoji', 400);
    }
    await expectRpcError(rpc(stranger.client, 'react', { p_post_id: post.id, p_emoji: '👍' }), 'post_not_found', 404);
  });

  it('unreact removes only the caller row; clients cannot write reactions directly', async () => {
    const post = (await postPhoto(a, [g1.id])).posts[0];
    await rpc(b.client, 'react', { p_post_id: post.id, p_emoji: '🎉' });
    await rpc(c.client, 'react', { p_post_id: post.id, p_emoji: '🎉' });
    await rpc(b.client, 'unreact', { p_post_id: post.id, p_emoji: '🎉' });
    const rows = await select(a.client, 'reactions', (q) => q.eq('post_id', post.id));
    expect(rows.map((r: any) => r.user_id)).toEqual([c.id]);
    const ins = await b.client.from('reactions').insert({ post_id: post.id, user_id: b.id, emoji: '🎉', group_id: g1.id });
    expect(ins.error?.code).toBe('42501');
    const del = await b.client.from('reactions').delete().eq('post_id', post.id);
    expect(del.error?.code).toBe('42501');
    await expectRpcError(rpc(stranger.client, 'unreact', { p_post_id: post.id, p_emoji: '🎉' }), 'post_not_found', 404);
  });
});

describe('tag_self / untag_self ("I\'m in this")', () => {
  it('tags only yourself, idempotently', async () => {
    const post = (await postPhoto(a, [g1.id])).posts[0];
    const t = await rpc(b.client, 'tag_self', { p_post_id: post.id });
    expect(t).toMatchObject({ post_id: post.id, user_id: b.id, group_id: g1.id });
    await rpc(b.client, 'tag_self', { p_post_id: post.id });
    expect(await select(a.client, 'post_tags', (q) => q.eq('post_id', post.id))).toHaveLength(1);
    await rpc(b.client, 'untag_self', { p_post_id: post.id });
    expect(await select(a.client, 'post_tags', (q) => q.eq('post_id', post.id))).toEqual([]);
    await expectRpcError(rpc(stranger.client, 'tag_self', { p_post_id: post.id }), 'post_not_found', 404);
  });

  it('direct inserts: self only, members only', async () => {
    const post = (await postPhoto(a, [g1.id])).posts[0];
    const someoneElse = await b.client.from('post_tags').insert({ post_id: post.id, user_id: c.id });
    expect(someoneElse.error?.code).toBe('42501');
    const outsider = await stranger.client.from('post_tags').insert({ post_id: post.id, user_id: stranger.id });
    expect(outsider.error?.code).toBe('42501');
    const self = await b.client.from('post_tags').insert({ post_id: post.id, user_id: b.id });
    expect(self.error).toBeNull();
    const delOther = await a.client.from('post_tags').delete().eq('post_id', post.id).eq('user_id', b.id).select();
    expect(delOther.data).toEqual([]);
    const delSelf = await b.client.from('post_tags').delete().eq('post_id', post.id).eq('user_id', b.id).select();
    expect(delSelf.data).toHaveLength(1);
  });
});

describe('delete_media / delete_post permissions', () => {
  it('only the owner / author can delete', async () => {
    const { media, posts } = await postPhoto(a, [g1.id]);
    await expectRpcError(rpc(b.client, 'delete_media', { p_media_id: media.id }), 'media_not_found', 404);
    await expectRpcError(rpc(b.client, 'delete_post', { p_post_id: posts[0].id }), 'post_not_found', 404);
    await rpc(a.client, 'delete_post', { p_post_id: posts[0].id });
    expect(await sql(`select 1 from public.media where id = $1`, [media.id])).toEqual([]);
  });
});
