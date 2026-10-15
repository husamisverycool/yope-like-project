// Populates every table with rows that belong to one group, so the security
// tests can assert that nothing of it leaks (and that deletion removes it all).
import { randomUUID } from 'node:crypto';
import {
  admin,
  createGroup,
  createMedia,
  grantPremium,
  rpc,
  sql,
  TINY_JPEG,
  upload,
  type TestGroup,
  type TestUser,
} from '../helpers';

export interface SeededGroup {
  group: TestGroup;
  inviteToken: string;
  invitationId: string;
  mediaIds: string[];
  postIds: string[];
  messageIds: string[];
  collageId: string;
  recapId: string;
  albumId: string;
  requestId: string;
  tributeId: string;
  yearStoryId: string;
  objectPaths: string[];
}

/**
 * users[0] = admin, users[1] = poster, users[2] = birthday honoree, users[3] = blocked by users[1].
 * Every table in `public` gets at least one row tied to this group or its members.
 */
export async function seedFullGroup(users: TestUser[], name = 'Seeded'): Promise<SeededGroup> {
  const [a, b, c, d] = users;
  if (!d) throw new Error('seedFullGroup needs 4 users');
  const objectPaths: string[] = [];

  // avatar + cover (storage + profiles + groups)
  const avatarPath = `avatars/${a.id}/${randomUUID()}.jpg`;
  await upload(a, avatarPath);
  objectPaths.push(avatarPath);
  await a.client.from('profiles').update({ avatar_path: avatarPath }).eq('id', a.id).throwOnError();

  const group = await createGroup(a, users.slice(1), { name, start: '08:00', end: '22:00' });
  const coverPath = `u/${a.id}/covers/${randomUUID()}.jpg`;
  await upload(a, coverPath);
  objectPaths.push(coverPath);
  await rpc(a.client, 'update_group', { p_group_id: group.id, p_cover_path: coverPath });

  const invite = await rpc(a.client, 'create_invite', { p_group_id: group.id });

  // a fired, open daily invitation
  const [inv] = await sql<{ id: string }>(
    `insert into public.daily_invitations (group_id, local_date, fires_at, closes_at, status)
     values ($1, (now() at time zone 'Europe/Paris')::date, now() - interval '10 seconds', now() + interval '110 seconds', 'fired')
     returning id`,
    [group.id],
  );

  // photos: a posts in window (dual + voice note), b posts a live photo
  const m1 = await createMedia(a, { dual: true });
  objectPaths.push(m1.originalPath, m1.frontPath!);
  const voicePath = `u/${a.id}/${m1.id}/voice.m4a`;
  await upload(a, voicePath, 'audio/mp4');
  objectPaths.push(voicePath);
  const p1 = await rpc<any[]>(a.client, 'create_post', {
    p_media_id: m1.id,
    p_group_ids: [group.id],
    p_caption: 'seeded',
    p_voice_path: voicePath,
    p_voice_duration_ms: 1200,
    p_invitation_id: inv.id,
  });
  const m2 = await createMedia(b, { kind: 'live_photo' });
  objectPaths.push(m2.originalPath, `u/${b.id}/${m2.id}/motion.mov`);
  const p2 = await rpc<any[]>(b.client, 'create_post', { p_media_id: m2.id, p_group_ids: [group.id] });

  // chat: text + voice, replies
  const t1 = await rpc(b.client, 'send_message', {
    p_group_id: group.id,
    p_kind: 'text',
    p_body: 'hello',
    p_reply_to_post_id: p1[0].id,
  });
  const chatVoice = `u/${c.id}/voice/${randomUUID()}.m4a`;
  await upload(c, chatVoice, 'audio/mp4');
  objectPaths.push(chatVoice);
  const v1 = await rpc(c.client, 'send_message', {
    p_group_id: group.id,
    p_kind: 'voice',
    p_voice_path: chatVoice,
    p_voice_duration_ms: 900,
    p_reply_to_message_id: t1.id,
  });

  // reactions, self-tags
  await rpc(b.client, 'react', { p_post_id: p1[0].id, p_emoji: '🔥' });
  await rpc(c.client, 'react', { p_post_id: p1[0].id, p_emoji: '😂' });
  await rpc(c.client, 'tag_self', { p_post_id: p1[0].id });

  // collage (worker-made) + its object
  const collageId = randomUUID();
  const collagePath = `g/${group.id}/collages/${collageId}/v1.jpg`;
  await admin.storage.from('media').upload(collagePath, TINY_JPEG, { contentType: 'image/jpeg' }).then((r) => {
    if (r.error) throw r.error;
  });
  objectPaths.push(collagePath);
  await sql(
    `insert into public.collages (id, group_id, invitation_id, option, post_ids, image_path, status, composed_at)
     values ($1, $2, $3, 'grid', $4::uuid[], $5, 'ready', now())`,
    [collageId, group.id, inv.id, [p1[0].id, p2[0].id], collagePath],
  );

  // weekly recap (worker-made, ready)
  const [recap] = await sql<{ id: string }>(
    `insert into public.weekly_recaps (group_id, week_start, items, text, status, generated_at)
     values ($1, date_trunc('week', now() at time zone 'Europe/Paris')::date, $2::uuid[], 'our week', 'ready', now())
     returning id`,
    [group.id, [p1[0].id, p2[0].id]],
  );

  // album
  const album = await rpc(b.client, 'save_album', {
    p_group_id: group.id,
    p_name: 'Best of',
    p_post_ids: [p1[0].id, p2[0].id],
  });

  // birthday: request about c, contribution by a (own photo), tribute row + object
  const [req] = await sql<{ id: string }>(
    `insert into public.tribute_requests (group_id, honoree_id, birthday_date, due_at)
     values ($1, $2, current_date + 5, now() + interval '5 days') returning id`,
    [group.id, c.id],
  );
  await rpc(a.client, 'contribute_tribute', { p_request_id: req.id, p_post_id: p1[0].id, p_line: 'Happy birthday!' });
  const tributeId = randomUUID();
  const tributePath = `g/${group.id}/tributes/${tributeId}/video.mp4`;
  await admin.storage.from('media').upload(tributePath, TINY_JPEG, { contentType: 'video/mp4' }).then((r) => {
    if (r.error) throw r.error;
  });
  objectPaths.push(tributePath);
  await sql(
    `insert into public.tributes (id, request_id, group_id, honoree_id, video_path, status, rendered_at)
     values ($1, $2, $3, $4, $5, 'ready', now())`,
    [tributeId, req.id, group.id, c.id, tributePath],
  );

  // year story
  const yearAsset = `g/${group.id}/year/2026/card1.jpg`;
  await admin.storage.from('media').upload(yearAsset, TINY_JPEG, { contentType: 'image/jpeg' }).then((r) => {
    if (r.error) throw r.error;
  });
  objectPaths.push(yearAsset);
  const [ys] = await sql<{ id: string }>(
    `insert into public.year_stories (group_id, year, status, data, post_ids, asset_paths, generated_at)
     values ($1, 2026, 'ready', jsonb_build_object('pages', jsonb_build_array($2::text)), $3::uuid[], $4::text[], now())
     returning id`,
    [group.id, p1[0].id, [p1[0].id], [yearAsset]],
  );

  // account-scoped rows
  await rpc(a.client, 'register_device', {
    p_platform: 'ios',
    p_push_token: `tok-${randomUUID()}`,
    p_push_to_start_token: `pts-${randomUUID()}`,
    p_widget_push_token: `wid-${randomUUID()}`,
  });
  await rpc(a.client, 'set_quiet_hours', { p_start: '22:00', p_end: '07:00', p_time_zone: 'Europe/Paris' });
  await rpc(c.client, 'set_birthday', { p_birthday: '1990-05-01', p_opt_in: true });
  await rpc(b.client, 'block_user', { p_user_id: d.id });
  await rpc(b.client, 'report', { p_target_kind: 'post', p_target_id: p1[0].id, p_reason: 'test report' });
  await grantPremium(a.id);
  await sql(
    `insert into public.ai_cost_log (group_id, purpose, model, input_tokens, output_tokens, cost_usd)
     values ($1, 'recap.generate', 'test-model', 100, 50, 0.0014)`,
    [group.id],
  );

  return {
    group,
    inviteToken: invite.token,
    invitationId: inv.id,
    mediaIds: [m1.id, m2.id],
    postIds: [p1[0].id, p2[0].id],
    messageIds: [t1.id, v1.id],
    collageId,
    recapId: recap.id,
    albumId: album.id,
    requestId: req.id,
    tributeId,
    yearStoryId: ys.id,
    objectPaths,
  };
}

/** Every relation (table or view) clients could address in the `public` schema. */
export async function publicRelations(): Promise<{ name: string; type: string }[]> {
  return sql(
    `select table_name as name, table_type as type
       from information_schema.tables
      where table_schema = 'public'
      order by table_name`,
  );
}

/** All rows of a relation, as JSON text, read with the database owner (no RLS, no row cap). */
export async function allRowsJson(rel: string): Promise<string[]> {
  const rows = await sql<{ j: string }>(`select to_jsonb(t)::text as j from public."${rel}" t`);
  return rows.map((r) => r.j);
}

/**
 * Ids "belonging" to a group: the group id and its members, then (to a fixpoint)
 * the `id`s of every row that mentions an anchor. Excludes `exclude` ids.
 */
export async function anchorIds(seed: string[], exclude: string[] = []): Promise<Set<string>> {
  const anchors = new Set(seed);
  const skip = new Set(exclude);
  const rels = (await publicRelations()).filter((r) => r.type === 'BASE TABLE');
  let grew = true;
  while (grew) {
    grew = false;
    for (const r of rels) {
      for (const j of await allRowsJson(r.name)) {
        if (![...anchors].some((a) => j.includes(a))) continue;
        const row = JSON.parse(j);
        for (const k of ['id', 'token']) {
          const v = row[k];
          if (typeof v === 'string' && v.length >= 20 && !anchors.has(v) && !skip.has(v)) {
            anchors.add(v);
            grew = true;
          }
        }
      }
    }
  }
  return anchors;
}
