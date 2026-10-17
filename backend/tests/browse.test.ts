// Walls, history weeks, on-this-day, recaps, albums, tribute contributions, and
// the policies of collages, weekly_recaps, albums, album_items, year_stories.
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  closeDb,
  createGroup,
  createUsers,
  expectRpcError,
  grantPremium,
  postPhoto,
  rpc,
  select,
  setConfig,
  sql,
  type TestGroup,
  type TestUser,
} from './helpers';

let a: TestUser, b: TestUser, c: TestUser, stranger: TestUser;
let g1: TestGroup, g2: TestGroup;

const setCreatedAt = (postId: string, iso: string) =>
  sql(`update public.posts set created_at = $2::timestamptz where id = $1`, [postId, iso]);

beforeAll(async () => {
  [a, b, c, stranger] = await createUsers(4, 'Brw');
  g1 = await createGroup(a, [b, c], { tz: 'America/Los_Angeles' });
  g2 = await createGroup(a, [b], { tz: 'America/Los_Angeles' });
});

afterAll(closeDb);

describe('wall', () => {
  it("shows a person's photos from shared groups only, one item per photo, plus collages", async () => {
    const both = await postPhoto(a, [g1.id, g2.id]);
    const onlyG2 = await postPhoto(a, [g2.id]);
    // c shares only g1 with a
    const seenByC = await rpc<any[]>(c.client, 'wall', { p_user_id: a.id });
    expect(seenByC.filter((i) => i.item_kind === 'post').map((i) => i.media_id)).toEqual([both.media.id]);
    expect(seenByC[0].group_ids).toEqual([g1.id]);
    // b shares both groups: the photo sent to both appears once with both groups
    const seenByB = await rpc<any[]>(b.client, 'wall', { p_user_id: a.id });
    const item = seenByB.find((i) => i.media_id === both.media.id);
    expect(new Set(item.group_ids)).toEqual(new Set([g1.id, g2.id]));
    expect(seenByB.map((i) => i.media_id)).toContain(onlyG2.media.id);
    // my wall: everything of mine
    const mine = await rpc<any[]>(a.client, 'wall', { p_user_id: a.id });
    expect(mine.map((i) => i.media_id)).toEqual(expect.arrayContaining([both.media.id, onlyG2.media.id]));
    // strangers see nothing
    expect(await rpc(stranger.client, 'wall', { p_user_id: a.id })).toEqual([]);

    // a collage containing one of a's photos shows on a's wall
    const collageId = randomUUID();
    await sql(
      `insert into public.collages (id, group_id, option, post_ids, status, composed_at) values ($1, $2, 'grid', $3::uuid[], 'ready', now() + interval '1 minute')`,
      [collageId, g1.id, [both.posts.find((p: any) => p.group_id === g1.id).id]],
    );
    const withCollage = await rpc<any[]>(c.client, 'wall', { p_user_id: a.id });
    expect(withCollage[0]).toMatchObject({ item_kind: 'collage', collage_id: collageId, group_ids: [g1.id], post_id: null });
  });

  it('paginates with p_before and p_limit', async () => {
    const [w] = await createUsers(1, 'Wall');
    const g = await createGroup(w, [b]);
    const ids: string[] = [];
    for (let i = 0; i < 5; i++) {
      const p = await postPhoto(w, [g.id]);
      await setCreatedAt(p.posts[0].id, `2026-0${i + 1}-15T12:00:00Z`);
      ids.push(p.media.id);
    }
    const page1 = await rpc<any[]>(b.client, 'wall', { p_user_id: w.id, p_limit: 2 });
    expect(page1.map((i) => i.media_id)).toEqual([ids[4], ids[3]]);
    const page2 = await rpc<any[]>(b.client, 'wall', { p_user_id: w.id, p_limit: 2, p_before: page1[1].created_at });
    expect(page2.map((i) => i.media_id)).toEqual([ids[2], ids[1]]);
  });
});

describe('group_history_weeks', () => {
  let g: TestGroup;
  const posts: Record<string, string> = {};

  beforeAll(async () => {
    g = await createGroup(a, [b], { tz: 'America/Los_Angeles' });
    const at: Record<string, string> = {
      // Los Angeles local times (PST, UTC-8, in January 2026)
      sunLate: '2026-01-12T07:30:00Z', // Sun 2026-01-11 23:30 local -> week of Mon 2026-01-05
      monEarly: '2026-01-12T08:30:00Z', // Mon 2026-01-12 00:30 local -> week of 2026-01-12
      wed: '2026-01-14T20:00:00Z', // Wed 2026-01-14 -> week of 2026-01-12
      old: '2025-06-03T18:00:00Z', // week of 2025-06-02
    };
    for (const [k, iso] of Object.entries(at)) {
      const p = await postPhoto(k === 'wed' ? b : a, [g.id]);
      posts[k] = p.posts[0].id;
      await setCreatedAt(posts[k], iso);
    }
  });

  it('buckets posts into Monday-start weeks in the group time zone', async () => {
    const weeks = await rpc<any[]>(b.client, 'group_history_weeks', { p_group_id: g.id, p_limit: 10 });
    expect(weeks).toEqual([
      { week_start: '2026-01-12', post_ids: [posts.monEarly, posts.wed], collages: [] },
      { week_start: '2026-01-05', post_ids: [posts.sunLate], collages: [] },
      { week_start: '2025-06-02', post_ids: [posts.old], collages: [] },
    ]);
    const older = await rpc<any[]>(b.client, 'group_history_weeks', { p_group_id: g.id, p_before_week: '2026-01-12', p_limit: 1 });
    expect(older).toEqual([{ week_start: '2026-01-05', post_ids: [posts.sunLate], collages: [] }]);
    await expectRpcError(rpc(stranger.client, 'group_history_weeks', { p_group_id: g.id }), 'not_group_member', 403);
  });

  it('follows week_start_isodow', async () => {
    try {
      await setConfig('week_start_isodow', 7); // Sunday
      const weeks = await rpc<any[]>(b.client, 'group_history_weeks', { p_group_id: g.id, p_limit: 1 });
      expect(weeks[0]).toEqual({ week_start: '2026-01-11', post_ids: [posts.sunLate, posts.monEarly, posts.wed], collages: [] });
    } finally {
      await setConfig('week_start_isodow', 1);
    }
  });

  it('free_history_days limits browsing for non-premium callers only', async () => {
    try {
      await setConfig('free_history_days', 30);
      // all seeded posts are older than 30 days
      const recent = await postPhoto(a, [g.id]);
      const free = await rpc<any[]>(b.client, 'group_history_weeks', { p_group_id: g.id });
      expect(free.flatMap((w) => w.post_ids)).toEqual([recent.posts[0].id]);
      await grantPremium(a.id);
      const premium = await rpc<any[]>(a.client, 'group_history_weeks', { p_group_id: g.id });
      expect(premium.flatMap((w) => w.post_ids)).toContain(posts.old);
      // on-this-day ignores the limit
      const otd = await rpc<any[]>(b.client, 'on_this_day', { p_group_id: g.id, p_local_date: '2026-06-03' });
      expect(otd.map((r) => r.post_id)).toEqual([posts.old]);
    } finally {
      await setConfig('free_history_days', null);
    }
  });
});

describe('weeks follow when a photo became visible (overnight photos, migration 0027)', () => {
  // Los Angeles (PST in January 2026): taken Sun 2026-01-11 22:00 local, developed Mon 2026-01-12 09:00 local.
  const takenSunday = '2026-01-12T06:00:00Z';
  const developedMonday = '2026-01-12T17:00:00Z';
  const develop = (postId: string, takenIso: string, revealedIso: string) =>
    sql(`update public.posts set created_at = $2::timestamptz, revealed_at = $3::timestamptz where id = $1`, [postId, takenIso, revealedIso]);

  it('group_history_weeks files an overnight photo under the week it developed in', async () => {
    const g = await createGroup(a, [b], { tz: 'America/Los_Angeles' });
    const sunday = (await postPhoto(a, [g.id])).posts[0].id;
    await setCreatedAt(sunday, '2026-01-12T05:00:00Z'); // Sun 21:00 local, an ordinary post
    const overnight = (await postPhoto(b, [g.id])).posts[0].id;
    await develop(overnight, takenSunday, developedMonday);
    const [row] = await sql(`select visible_at from public.posts where id = $1`, [overnight]);
    expect(new Date(row.visible_at).toISOString()).toBe(new Date(developedMonday).toISOString());
    expect(await rpc<any[]>(b.client, 'group_history_weeks', { p_group_id: g.id })).toEqual([
      { week_start: '2026-01-12', post_ids: [overnight], collages: [] },
      { week_start: '2026-01-05', post_ids: [sunday], collages: [] },
    ]);
    await expectRpcError(rpc(stranger.client, 'group_history_weeks', { p_group_id: g.id }), 'not_group_member', 403);
  });

  it("update_recap takes an overnight photo into the week it developed in, not the week it was taken in", async () => {
    const g = await createGroup(a, [b], { tz: 'America/Los_Angeles' });
    const inWeek = (await postPhoto(a, [g.id])).posts[0].id;
    await develop(inWeek, takenSunday, developedMonday);
    const ordinary = (await postPhoto(a, [g.id])).posts[0].id;
    await setCreatedAt(ordinary, '2026-01-14T20:00:00Z');
    const [next] = await sql<{ id: string }>(
      `insert into public.weekly_recaps (group_id, week_start, items, status, generated_at)
       values ($1, '2026-01-12', $2::uuid[], 'ready', now()) returning id`, [g.id, [ordinary]]);
    const [prev] = await sql<{ id: string }>(
      `insert into public.weekly_recaps (group_id, week_start, items, status, generated_at)
       values ($1, '2026-01-05', '{}', 'ready', now()) returning id`, [g.id]);
    expect((await rpc(b.client, 'update_recap', { p_recap_id: next.id, p_items: [inWeek, ordinary] })).items).toEqual([inWeek, ordinary]);
    await expectRpcError(rpc(b.client, 'update_recap', { p_recap_id: prev.id, p_items: [inWeek] }), 'invalid_items', 400);
  });

  it("wall orders an overnight photo by when it developed", async () => {
    const [x, y] = await createUsers(2, 'WallNight');
    const g = await createGroup(x, [y], { tz: 'America/Los_Angeles' });
    const overnight = (await postPhoto(x, [g.id])).posts[0].id;
    await develop(overnight, takenSunday, developedMonday);
    const later = (await postPhoto(x, [g.id])).posts[0].id;
    await setCreatedAt(later, '2026-01-12T12:00:00Z'); // Mon 04:00 local: after it was taken, before it developed
    const wall = await rpc<any[]>(y.client, 'wall', { p_user_id: x.id, p_before: '2026-01-13T00:00:00Z', p_limit: 5 });
    expect(wall.map((x) => [x.post_id, new Date(x.created_at).toISOString()])).toEqual([
      [overnight, new Date(developedMonday).toISOString()],
      [later, new Date('2026-01-12T12:00:00Z').toISOString()],
    ]);
  });
});

describe('collages in the group history (migration 0033)', () => {
  /** A closed invitation on a group-local day with a ready collage of the given posts. */
  async function moment(groupId: string, localDate: string, firesAt: string, postIds: string[], status = 'ready') {
    const [inv] = await sql(
      `insert into public.daily_invitations (group_id, local_date, fires_at, closes_at, status)
       values ($1, $2::date, $3::timestamptz, $3::timestamptz + interval '2 minutes', 'closed') returning id`,
      [groupId, localDate, firesAt],
    );
    const [c] = await sql(
      `insert into public.collages (group_id, invitation_id, option, post_ids, image_path, widget_path, status, composed_at)
       values ($1::uuid, $2::uuid, 'B', $3::uuid[], 'g/' || $1::text || '/collages/' || $2::text || '/v1/display-1.jpg', 'g/' || $1::text || '/collages/' || $2::text || '/v1/widget.jpg', $4::public.render_status, now())
       returning id`,
      [groupId, inv.id, postIds, status],
    );
    return { invitationId: inv.id as string, collageId: c.id as string };
  }

  it('group_collages lists the ready collages by their day, members only; group_history_weeks carries each week\'s', async () => {
    const g = await createGroup(a, [b], { tz: 'America/Los_Angeles' });
    const tue = (await postPhoto(a, [g.id])).posts[0].id;
    await setCreatedAt(tue, '2026-01-13T20:00:00Z');
    const sat = (await postPhoto(b, [g.id])).posts[0].id;
    await setCreatedAt(sat, '2026-01-17T20:00:00Z');
    const m1 = await moment(g.id, '2026-01-13', '2026-01-13T19:59:00Z', [tue]);
    const m2 = await moment(g.id, '2026-01-17', '2026-01-17T19:59:00Z', [sat]);
    await moment(g.id, '2026-01-15', '2026-01-15T19:59:00Z', [tue], 'pending'); // not ready: not shown
    const elsewhere = await createGroup(stranger, [], { tz: 'UTC' });
    await moment(elsewhere.id, '2026-01-14', '2026-01-14T12:00:00Z', []);

    const rows = await rpc<any[]>(b.client, 'group_collages', { p_group_id: g.id, p_from: '2026-01-12', p_to: '2026-01-18' });
    expect(rows.map((r) => [r.collage_id, r.local_date])).toEqual([[m2.collageId, '2026-01-17'], [m1.collageId, '2026-01-13']]);
    expect(rows[0].widget_path).toContain(`g/${g.id}/collages/`);
    expect(await rpc<any[]>(b.client, 'group_collages', { p_group_id: g.id, p_from: '2026-01-14', p_to: '2026-01-16' })).toEqual([]);
    await expectRpcError(rpc(stranger.client, 'group_collages', { p_group_id: g.id }), 'not_group_member', 403);

    const [week] = await rpc<any[]>(b.client, 'group_history_weeks', { p_group_id: g.id, p_limit: 1 });
    expect(week.week_start).toBe('2026-01-12');
    expect(week.post_ids).toEqual([tue, sat]);
    expect(week.collages.map((c: any) => [c.collage_id, c.local_date])).toEqual([[m1.collageId, '2026-01-13'], [m2.collageId, '2026-01-17']]);
    await expectRpcError(rpc(stranger.client, 'group_history_weeks', { p_group_id: g.id }), 'not_group_member', 403);
  });

  it("update_recap reorders and removes the recap's collages (only the week's ready ones); a deleted collage leaves the recap", async () => {
    const g = await createGroup(a, [b], { tz: 'UTC' });
    const mon = (await postPhoto(a, [g.id])).posts[0].id;
    await setCreatedAt(mon, '2026-09-14T12:00:00Z');
    const wed = (await postPhoto(b, [g.id])).posts[0].id;
    await setCreatedAt(wed, '2026-09-16T12:00:00Z');
    const m1 = await moment(g.id, '2026-09-14', '2026-09-14T11:59:00Z', [mon]);
    const m2 = await moment(g.id, '2026-09-16', '2026-09-16T11:59:00Z', [wed]);
    const later = await moment(g.id, '2026-09-21', '2026-09-21T11:59:00Z', [wed]);
    const [recap] = await sql<{ id: string }>(
      `insert into public.weekly_recaps (group_id, week_start, items, collage_ids, status, generated_at)
       values ($1, '2026-09-14', $2::uuid[], $3::uuid[], 'ready', now()) returning id`,
      [g.id, [mon, wed], [m1.collageId, m2.collageId]],
    );
    let r = await rpc(b.client, 'update_recap', { p_recap_id: recap.id, p_collage_ids: [m2.collageId] });
    expect(r.collage_ids).toEqual([m2.collageId]);
    expect(r.items).toEqual([mon, wed]); // untouched
    r = await rpc(b.client, 'update_recap', { p_recap_id: recap.id, p_collage_ids: [m2.collageId, m1.collageId] });
    expect(r.collage_ids).toEqual([m2.collageId, m1.collageId]);
    await expectRpcError(rpc(b.client, 'update_recap', { p_recap_id: recap.id, p_collage_ids: [later.collageId] }), 'invalid_items', 400);
    await expectRpcError(rpc(b.client, 'update_recap', { p_recap_id: recap.id, p_collage_ids: [m1.collageId, m1.collageId] }), 'invalid_items', 400);
    await expectRpcError(rpc(stranger.client, 'update_recap', { p_recap_id: recap.id, p_collage_ids: [] }), 'recap_not_found', 404);

    // its only photo deleted → the collage goes → it leaves the recap
    await rpc(a.client, 'delete_post', { p_post_id: mon });
    const [after] = await sql(`select collage_ids from public.weekly_recaps where id = $1`, [recap.id]);
    expect(after.collage_ids).toEqual([m2.collageId]);
  });
});

describe('on_this_day', () => {
  it('returns posts from the same local month/day in previous years', async () => {
    const g = await createGroup(a, [b], { tz: 'Asia/Tokyo' });
    const mk = async (iso: string) => {
      const p = await postPhoto(a, [g.id]);
      await setCreatedAt(p.posts[0].id, iso);
      return p.posts[0].id;
    };
    const y1 = await mk('2025-03-09T16:00:00Z'); // 2025-03-10 01:00 Tokyo
    const y2 = await mk('2023-03-10T03:00:00Z'); // 2023-03-10 12:00 Tokyo
    await mk('2025-03-09T10:00:00Z'); // 2025-03-09 19:00 Tokyo: other day
    await mk('2026-03-10T03:00:00Z'); // same year: not a memory
    const rows = await rpc<any[]>(b.client, 'on_this_day', { p_group_id: g.id, p_local_date: '2026-03-10' });
    expect(rows.map((r) => [r.post_id, r.years_ago])).toEqual([
      [y1, 1],
      [y2, 3],
    ]);
    await expectRpcError(rpc(stranger.client, 'on_this_day', { p_group_id: g.id, p_local_date: '2026-03-10' }), 'not_group_member', 403);
  });
});

describe('update_recap', () => {
  it('any member reorders, removes, re-adds within the week and edits the text', async () => {
    const g = await createGroup(a, [b, c], { tz: 'UTC' });
    const ids: string[] = [];
    for (let i = 0; i < 3; i++) {
      const p = await postPhoto(i === 1 ? b : a, [g.id]);
      await setCreatedAt(p.posts[0].id, `2026-09-1${4 + i}T12:00:00Z`); // Mon 14 .. Wed 16
      ids.push(p.posts[0].id);
    }
    const outside = await postPhoto(a, [g.id]);
    await setCreatedAt(outside.posts[0].id, '2026-09-21T12:00:00Z');
    const [recap] = await sql<{ id: string }>(
      `insert into public.weekly_recaps (group_id, week_start, items, text, status, generated_at)
       values ($1, '2026-09-14', $2::uuid[], 'Our week', 'ready', now()) returning id`,
      [g.id, ids],
    );
    let r = await rpc(c.client, 'update_recap', { p_recap_id: recap.id, p_items: [ids[2], ids[0]], p_text: 'Edited' });
    expect(r).toMatchObject({ items: [ids[2], ids[0]], text: 'Edited', edited_by: c.id });
    r = await rpc(b.client, 'update_recap', { p_recap_id: recap.id, p_items: [ids[1], ids[2], ids[0]] });
    expect(r.items).toEqual([ids[1], ids[2], ids[0]]);
    expect(r.text).toBe('Edited');
    r = await rpc(b.client, 'update_recap', { p_recap_id: recap.id, p_text: '' });
    expect(r.text).toBeNull();

    await expectRpcError(rpc(b.client, 'update_recap', { p_recap_id: recap.id, p_items: [outside.posts[0].id] }), 'invalid_items', 400);
    await expectRpcError(rpc(b.client, 'update_recap', { p_recap_id: recap.id, p_items: [ids[0], ids[0]] }), 'invalid_items', 400);
    await expectRpcError(rpc(b.client, 'update_recap', { p_recap_id: recap.id, p_text: 'x'.repeat(2001) }), 'invalid_text', 400);
    await expectRpcError(rpc(stranger.client, 'update_recap', { p_recap_id: recap.id, p_text: 'x' }), 'recap_not_found', 404);
    const direct = await b.client.from('weekly_recaps').update({ text: 'direct' }).eq('id', recap.id);
    expect(direct.error?.code).toBe('42501');

    // items hidden from the editor by a block are kept
    await rpc(c.client, 'block_user', { p_user_id: b.id });
    r = await rpc(c.client, 'update_recap', { p_recap_id: recap.id, p_items: [ids[0], ids[2]] });
    expect(r.items).toEqual([ids[0], ids[2], ids[1]]);
    await rpc(c.client, 'unblock_user', { p_user_id: b.id });

    await sql(`update public.weekly_recaps set status = 'pending' where id = $1`, [recap.id]);
    await expectRpcError(rpc(b.client, 'update_recap', { p_recap_id: recap.id, p_text: 'x' }), 'recap_not_ready', 409);
  });
});

describe('albums', () => {
  it('save, rename (any member), delete (creator or admin)', async () => {
    const g = await createGroup(a, [b, c]);
    const p1 = (await postPhoto(a, [g.id])).posts[0].id;
    const p2 = (await postPhoto(b, [g.id])).posts[0].id;
    const album = await rpc(b.client, 'save_album', { p_group_id: g.id, p_name: ' Summer ', p_post_ids: [p2, p1] });
    expect(album).toMatchObject({ name: 'Summer', group_id: g.id, created_by: b.id });
    const items = await select(c.client, 'album_items', (q) => q.eq('album_id', album.id).order('position'));
    expect(items.map((i: any) => [i.post_id, i.position])).toEqual([
      [p2, 0],
      [p1, 1],
    ]);
    expect((await select(c.client, 'albums')).map((x: any) => x.id)).toContain(album.id);
    expect(await select(stranger.client, 'albums', (q) => q.eq('id', album.id))).toEqual([]);
    expect(await select(stranger.client, 'album_items', (q) => q.eq('album_id', album.id))).toEqual([]);

    const renamed = await rpc(c.client, 'rename_album', { p_album_id: album.id, p_name: 'Summer 26' });
    expect(renamed.name).toBe('Summer 26');
    await expectRpcError(rpc(stranger.client, 'rename_album', { p_album_id: album.id, p_name: 'x' }), 'album_not_found', 404);
    await expectRpcError(rpc(c.client, 'delete_album', { p_album_id: album.id }), 'not_album_owner', 403);

    const other = (await postPhoto(stranger, [(await createGroup(stranger)).id])).posts[0].id;
    await expectRpcError(rpc(b.client, 'save_album', { p_group_id: g.id, p_name: 'x', p_post_ids: [other] }), 'invalid_items', 400);
    await expectRpcError(rpc(b.client, 'save_album', { p_group_id: g.id, p_name: 'x', p_post_ids: [] }), 'invalid_items', 400);
    await expectRpcError(rpc(b.client, 'save_album', { p_group_id: g.id, p_name: '', p_post_ids: [p1] }), 'invalid_name', 400);
    await expectRpcError(rpc(stranger.client, 'save_album', { p_group_id: g.id, p_name: 'x', p_post_ids: [p1] }), 'not_group_member', 403);

    await rpc(a.client, 'delete_album', { p_album_id: album.id }); // admin
    expect(await select(b.client, 'albums', (q) => q.eq('id', album.id))).toEqual([]);
    const mine = await rpc(c.client, 'save_album', { p_group_id: g.id, p_name: 'Mine', p_post_ids: [p1] });
    await rpc(c.client, 'delete_album', { p_album_id: mine.id }); // creator
    const direct = await c.client.from('albums').insert({ group_id: g.id, name: 'direct' });
    expect(direct.error?.code).toBe('42501');
  });
});

describe('contribute_tribute', () => {
  it('own or self-tagged photos of the group, one editable contribution until due', async () => {
    const [h] = await createUsers(1, 'Hon');
    const g = await createGroup(a, [b, c, h]);
    const [req] = await sql<{ id: string }>(
      `insert into public.tribute_requests (group_id, honoree_id, birthday_date, due_at)
       values ($1, $2, current_date + 4, now() + interval '4 days') returning id`,
      [g.id, h.id],
    );
    const mine = (await postPhoto(b, [g.id])).posts[0].id;
    const tagged = (await postPhoto(a, [g.id])).posts[0].id;
    const untagged = (await postPhoto(a, [g.id])).posts[0].id;
    const elsewhere = (await postPhoto(b, [g1.id])).posts[0].id;
    await rpc(b.client, 'tag_self', { p_post_id: tagged });

    const c1 = await rpc(b.client, 'contribute_tribute', { p_request_id: req.id, p_post_id: mine, p_line: ' You rock ' });
    expect(c1).toMatchObject({ request_id: req.id, contributor_id: b.id, post_id: mine, line: 'You rock' });
    const c2 = await rpc(b.client, 'contribute_tribute', { p_request_id: req.id, p_post_id: tagged, p_line: 'Edited' });
    expect(c2.id).toBe(c1.id);
    expect(await sql(`select 1 from public.tribute_contributions where request_id = $1`, [req.id])).toHaveLength(1);

    await expectRpcError(rpc(b.client, 'contribute_tribute', { p_request_id: req.id, p_post_id: untagged, p_line: 'x' }), 'post_not_eligible', 403);
    await expectRpcError(rpc(b.client, 'contribute_tribute', { p_request_id: req.id, p_post_id: elsewhere, p_line: 'x' }), 'post_not_found', 404);
    await expectRpcError(rpc(b.client, 'contribute_tribute', { p_request_id: req.id, p_post_id: mine, p_line: 'x'.repeat(281) }), 'invalid_line', 400);
    await expectRpcError(rpc(stranger.client, 'contribute_tribute', { p_request_id: req.id, p_post_id: mine, p_line: 'x' }), 'request_not_found', 404);

    // withdraw before the due time (RLS delete policy), then closed after it
    const del = await b.client.from('tribute_contributions').delete().eq('id', c1.id).select();
    expect(del.data).toHaveLength(1);
    await sql(`update public.tribute_requests set due_at = now() - interval '1 second' where id = $1`, [req.id]);
    await expectRpcError(rpc(b.client, 'contribute_tribute', { p_request_id: req.id, p_post_id: mine, p_line: 'x' }), 'tribute_closed', 409);
    const direct = await b.client.from('tribute_contributions').insert({ request_id: req.id, contributor_id: b.id, post_id: mine, line: 'x' });
    expect(direct.error?.code).toBe('42501');
  });
});

describe('group-only tables: collages, weekly_recaps, year_stories', () => {
  it('members read; non-members and clients writing get nothing', async () => {
    const g = await createGroup(a, [b]);
    const col = randomUUID();
    await sql(`insert into public.collages (id, group_id, option, status) values ($1, $2, 'grid', 'pending')`, [col, g.id]);
    await sql(`insert into public.weekly_recaps (group_id, week_start) values ($1, '2026-01-05')`, [g.id]);
    await sql(`insert into public.year_stories (group_id, year) values ($1, 2026)`, [g.id]);
    for (const t of ['collages', 'weekly_recaps', 'year_stories']) {
      expect((await select(b.client, t, (q) => q.eq('group_id', g.id))).length, t).toBe(1);
      expect(await select(stranger.client, t, (q) => q.eq('group_id', g.id)), t).toEqual([]);
      const w = await b.client.from(t).insert({ group_id: g.id });
      expect(w.error?.code, t).toBe('42501');
    }
  });
});
