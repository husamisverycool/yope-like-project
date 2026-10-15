// Security invariant 2: deleting a photo removes it everywhere (feed, chat, walls,
// collages, recaps, albums, tribute contributions, year stories, widgets, storage).
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  admin,
  closeDb,
  createGroup,
  createMedia,
  createUsers,
  rpc,
  select,
  sql,
  TINY_JPEG,
  upload,
  type TestGroup,
  type TestUser,
} from '../helpers';
import { allRowsJson, publicRelations } from './world';

let a: TestUser, b: TestUser, c: TestUser;
let g1: TestGroup, g2: TestGroup;
let mediaId: string;
let mediaPaths: string[];
let p1: string, p2: string;
let otherPost: string;
let replyPhotoPost: string;
let textReplyId: string;
let collage1: string, collage2: string;
let collagePaths: string[];
let recapId: string, albumId: string, requestId: string, tributeId: string, yearId: string;
let tributePath: string, yearAsset: string;
let firstJobId: number;

beforeAll(async () => {
  [a, b, c] = await createUsers(3, 'Del');
  g1 = await createGroup(a, [b, c], { name: 'G1' });
  g2 = await createGroup(a, [b], { name: 'G2' });

  // the photo: dual capture + live motion + voice note, posted to both groups
  const m = await createMedia(a, { kind: 'live_photo', dual: true });
  mediaId = m.id;
  const voice = `u/${a.id}/${m.id}/voice.m4a`;
  await upload(a, voice, 'audio/mp4');
  // pretend the worker already wrote renditions
  const rendition = (n: string) => `u/${a.id}/${m.id}/r/${n}.jpg`;
  for (const n of ['display', 'thumb', 'widget', 'front_display', 'front_thumb']) {
    const { error } = await admin.storage.from('media').upload(rendition(n), TINY_JPEG, { contentType: 'image/jpeg' });
    if (error) throw error;
  }
  await sql(
    `update public.media set display_path = $2, thumb_path = $3, widget_path = $4, front_display_path = $5,
            front_thumb_path = $6, renditions_ready_at = now() where id = $1`,
    [m.id, rendition('display'), rendition('thumb'), rendition('widget'), rendition('front_display'), rendition('front_thumb')],
  );
  mediaPaths = [
    m.originalPath,
    m.frontPath!,
    `u/${a.id}/${m.id}/motion.mov`,
    voice,
    ...['display', 'thumb', 'widget', 'front_display', 'front_thumb'].map(rendition),
  ];
  const posts = await rpc<any[]>(a.client, 'create_post', {
    p_media_id: m.id,
    p_group_ids: [g1.id, g2.id],
    p_caption: 'to be deleted',
    p_voice_path: voice,
    p_voice_duration_ms: 1000,
  });
  p1 = posts.find((p) => p.group_id === g1.id).id;
  p2 = posts.find((p) => p.group_id === g2.id).id;

  // another photo in G1 so composites survive with one item left
  const other = await createMedia(b);
  otherPost = (await rpc<any[]>(b.client, 'create_post', { p_media_id: other.id, p_group_ids: [g1.id] }))[0].id;

  // react, tag, reply (text + photo)
  await rpc(b.client, 'react', { p_post_id: p1, p_emoji: '❤️' });
  await rpc(c.client, 'react', { p_post_id: p1, p_emoji: '😮' });
  await rpc(b.client, 'react', { p_post_id: p2, p_emoji: '👍' });
  await rpc(b.client, 'tag_self', { p_post_id: p1 });
  textReplyId = (await rpc(c.client, 'send_message', {
    p_group_id: g1.id,
    p_kind: 'text',
    p_body: 'love this',
    p_reply_to_post_id: p1,
  })).id;
  const rm = await createMedia(c);
  replyPhotoPost = (await rpc<any[]>(c.client, 'create_post', {
    p_media_id: rm.id,
    p_group_ids: [g1.id],
    p_reply_to_post_id: p1,
  }))[0].id;

  // recap, album
  recapId = (await sql<{ id: string }>(
    `insert into public.weekly_recaps (group_id, week_start, items, text, status, generated_at)
     values ($1, '2026-10-12', $2::uuid[], 'week', 'ready', now()) returning id`,
    [g1.id, [p1, otherPost]],
  ))[0].id;
  albumId = (await rpc(b.client, 'save_album', { p_group_id: g1.id, p_name: 'Fav', p_post_ids: [p1, otherPost] })).id;

  // tribute for c: b contributes p1 (b is self-tagged in it); the tribute is rendered
  requestId = (await sql<{ id: string }>(
    `insert into public.tribute_requests (group_id, honoree_id, birthday_date, due_at)
     values ($1, $2, current_date + 3, now() + interval '3 days') returning id`,
    [g1.id, c.id],
  ))[0].id;
  await rpc(b.client, 'contribute_tribute', { p_request_id: requestId, p_post_id: p1, p_line: 'HBD' });
  tributeId = randomUUID();
  tributePath = `g/${g1.id}/tributes/${tributeId}/v1.mp4`;
  await sql(
    `insert into public.tributes (id, request_id, group_id, honoree_id, video_path, status, rendered_at)
     values ($1, $2, $3, $4, $5, 'ready', now())`,
    [tributeId, requestId, g1.id, c.id, tributePath],
  );

  // collages: G1 (p1 + other) survives; G2 (only p2) disappears
  collage1 = randomUUID();
  collage2 = randomUUID();
  collagePaths = [
    `g/${g1.id}/collages/${collage1}/v1.jpg`,
    `g/${g1.id}/collages/${collage1}/v1-widget.jpg`,
    `g/${g2.id}/collages/${collage2}/v1.jpg`,
  ];
  await sql(
    `insert into public.collages (id, group_id, option, post_ids, image_path, widget_path, status, composed_at) values
       ($1, $2, 'grid', $3::uuid[], $4, $5, 'ready', now()),
       ($6, $7, 'grid', $8::uuid[], $9, null, 'ready', now())`,
    [collage1, g1.id, [p1, otherPost], collagePaths[0], collagePaths[1], collage2, g2.id, [p2], collagePaths[2]],
  );

  // year story
  yearAsset = `g/${g1.id}/year/2026/cover.jpg`;
  yearId = (await sql<{ id: string }>(
    `insert into public.year_stories (group_id, year, status, data, post_ids, asset_paths, generated_at)
     values ($1, 2026, 'ready', jsonb_build_object('top', $2::text), $3::uuid[], $4::text[], now()) returning id`,
    [g1.id, p1, [p1, otherPost], [yearAsset]],
  ))[0].id;

  firstJobId = (await sql<{ id: number }>(`select coalesce(max(id), 0)::int as id from public.jobs`))[0].id;
  await rpc(a.client, 'delete_media', { p_media_id: mediaId });
});

afterAll(closeDb);

describe('delete_media cascade', () => {
  it('no row anywhere references the photo, its posts or its files', async () => {
    const needles = [mediaId, p1, p2, ...mediaPaths];
    const hits: string[] = [];
    for (const r of await publicRelations()) {
      if (r.type !== 'BASE TABLE' || r.name === 'jobs') continue;
      for (const j of await allRowsJson(r.name)) {
        const n = needles.find((x) => j.includes(x));
        if (n) hits.push(`${r.name}: ${n}`);
      }
    }
    expect(hits).toEqual([]);
  });

  it('no queued job other than storage.delete still points at it', async () => {
    const rows = await sql<{ kind: string }>(
      `select kind from public.jobs
        where status = 'queued' and kind <> 'storage.delete'
          and (payload::text like '%' || $1 || '%' or payload::text like '%' || $2 || '%' or payload::text like '%' || $3 || '%')`,
      [mediaId, p1, p2],
    );
    expect(rows).toEqual([]);
  });

  it('replies survive, detached from the deleted photo', async () => {
    const [msg] = await sql(`select * from public.messages where id = $1`, [textReplyId]);
    expect(msg.reply_to_post_id).toBeNull();
    const [rp] = await sql(`select * from public.posts where id = $1`, [replyPhotoPost]);
    expect(rp.reply_to_post_id).toBeNull();
    const [rpMsg] = await sql(`select * from public.messages where post_id = $1`, [replyPhotoPost]);
    expect(rpMsg.reply_to_post_id).toBeNull();
  });

  it('composites are updated and marked for recomposition', async () => {
    const [c1] = await sql(`select * from public.collages where id = $1`, [collage1]);
    expect(c1.post_ids).toEqual([otherPost]);
    expect(c1.status).toBe('pending');
    expect(c1.image_path).toBeNull();
    expect(c1.widget_path).toBeNull();
    expect(await sql(`select 1 from public.collages where id = $1`, [collage2])).toEqual([]);

    const [recap] = await sql(`select * from public.weekly_recaps where id = $1`, [recapId]);
    expect(recap.items).toEqual([otherPost]);
    const items = await sql(`select post_id from public.album_items where album_id = $1`, [albumId]);
    expect(items.map((i: any) => i.post_id)).toEqual([otherPost]);

    expect(await sql(`select 1 from public.tribute_contributions where request_id = $1`, [requestId])).toEqual([]);
    const [t] = await sql(`select * from public.tributes where id = $1`, [tributeId]);
    expect(t.video_path).toBeNull();
    expect(t.status).toBe('pending');

    const [y] = await sql(`select * from public.year_stories where id = $1`, [yearId]);
    expect(y.post_ids).toEqual([otherPost]);
    expect(y.data).toBeNull();
    expect(y.asset_paths).toEqual([]);
    expect(y.status).toBe('pending');
  });

  it('enqueues recomposition, widget refresh and storage deletion jobs', async () => {
    const jobs = await sql<{ kind: string; payload: any; status: string }>(
      `select kind, payload, status from public.jobs where id > $1 order by id`,
      [firstJobId],
    );
    const kinds = (k: string) => jobs.filter((j) => j.kind === k);
    expect(kinds('collage.recompose').map((j) => j.payload.collage_id)).toEqual([collage1]);
    expect(kinds('tribute.rerender').map((j) => j.payload.tribute_id)).toEqual([tributeId]);
    expect(kinds('year.recompute').map((j) => j.payload.year_story_id)).toEqual([yearId]);
    const refreshed = new Set(kinds('widget.refresh').map((j) => j.payload.group_id));
    // widget.refresh is deduplicated per group, so an earlier queued one may be reused
    const queuedRefresh = await sql<{ g: string }>(
      `select payload ->> 'group_id' as g from public.jobs where kind = 'widget.refresh' and status = 'queued'`,
    );
    for (const q of queuedRefresh) refreshed.add(q.g);
    expect(refreshed.has(g1.id) && refreshed.has(g2.id)).toBe(true);

    const del = kinds('storage.delete');
    const paths = new Set(del.flatMap((j) => j.payload.paths));
    const prefixes = new Set(del.flatMap((j) => j.payload.prefixes));
    for (const p of [...mediaPaths, ...collagePaths, tributePath, yearAsset]) {
      expect(paths.has(p), p).toBe(true);
    }
    expect(prefixes.has(`u/${a.id}/${mediaId}/`)).toBe(true);
    for (const j of del) expect(j.payload.bucket).toBe('media');
  });

  it('the photo is gone from feeds, chat and walls', async () => {
    for (const u of [a, b, c]) {
      const posts = await select(u.client, 'posts');
      expect(posts.map((p: any) => p.id)).not.toContain(p1);
      expect(posts.map((p: any) => p.id)).not.toContain(p2);
      const msgs = await select(u.client, 'messages');
      expect(msgs.map((m: any) => m.post_id)).not.toContain(p1);
    }
    const wall = await rpc<any[]>(b.client, 'wall', { p_user_id: a.id });
    expect(wall.map((w) => w.media_id)).not.toContain(mediaId);
  });
});

describe('delete_post', () => {
  it('removes one group only; the media goes with its last post', async () => {
    const m = await createMedia(a);
    const posts = await rpc<any[]>(a.client, 'create_post', { p_media_id: m.id, p_group_ids: [g1.id, g2.id] });
    const [q1, q2] = posts;
    await rpc(a.client, 'delete_post', { p_post_id: q1.id });
    expect(await sql(`select id from public.media where id = $1`, [m.id])).toHaveLength(1);
    expect(await sql(`select id from public.posts where id = $1`, [q2.id])).toHaveLength(1);
    const noFileDeletion = await sql(
      `select 1 from public.jobs where kind = 'storage.delete' and payload::text like '%' || $1 || '%'`,
      [m.originalPath],
    );
    expect(noFileDeletion).toEqual([]);

    await rpc(a.client, 'delete_post', { p_post_id: q2.id });
    expect(await sql(`select id from public.media where id = $1`, [m.id])).toEqual([]);
    const fileDeletion = await sql(
      `select 1 from public.jobs where kind = 'storage.delete' and payload -> 'paths' ? $1`,
      [m.originalPath],
    );
    expect(fileDeletion).toHaveLength(1);
  });
});
