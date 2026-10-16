// Selfie reactions (0018), plans (0019), overnight photos and the weekly question (0020), and their
// storage reads (0021).
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  admin,
  closeDb,
  createGroup,
  createMedia,
  createUsers,
  expectRpcError,
  jobsWhere,
  postPhoto,
  rpc,
  select,
  setConfig,
  sql,
  upload,
  type TestGroup,
  type TestUser,
} from './helpers';

let a: TestUser, b: TestUser, c: TestUser, stranger: TestUser;
let g: TestGroup, other: TestGroup;

const days = (n: number) => new Date(Date.now() + n * 86_400_000).toISOString();

beforeAll(async () => {
  [a, b, c, stranger] = await createUsers(4, 'Feat');
  g = await createGroup(a, [b, c], { name: 'features' });
  other = await createGroup(stranger, [], { name: 'elsewhere' });
});

afterAll(closeDb);

async function canSign(user: TestUser, path: string) {
  const { error } = await user.client.storage.from('media').createSignedUrl(path, 60);
  return error === null;
}

describe('selfie reactions', () => {
  it('a member reacts with their own selfie; members see it; the author is told once', async () => {
    const { posts } = await postPhoto(a, [g.id]);
    const post = posts[0];
    const first = await upload(b, `u/${b.id}/selfies/${randomUUID()}.jpg`);
    const row = await rpc(b.client, 'react_with_selfie', { p_post_id: post.id, p_image_path: first });
    expect(row).toMatchObject({ post_id: post.id, user_id: b.id, group_id: g.id, image_path: first });

    const seen = await select(c.client, 'selfie_reactions', (q) => q.eq('post_id', post.id));
    expect(seen.map((r) => r.user_id)).toEqual([b.id]);
    expect(await canSign(c, first)).toBe(true);
    expect(await canSign(stranger, first)).toBe(false);
    expect(await select(stranger.client, 'selfie_reactions', (q) => q.eq('post_id', post.id))).toEqual([]);

    // a new selfie replaces the old one: the old file goes, no second push
    const second = await upload(b, `u/${b.id}/selfies/${randomUUID()}.jpg`);
    await rpc(b.client, 'react_with_selfie', { p_post_id: post.id, p_image_path: second });
    expect(await select(a.client, 'selfie_reactions', (q) => q.eq('post_id', post.id))).toMatchObject([
      { user_id: b.id, image_path: second },
    ]);
    expect(await jobsWhere('storage.delete', { paths: [first] })).toHaveLength(1);
    expect(await jobsWhere('push.selfie_reaction', { post_id: post.id, user_id: b.id })).toHaveLength(1);
  });

  it('refuses other people’s files, unsafe paths and posts the caller cannot see', async () => {
    const { posts } = await postPhoto(a, [g.id]);
    const theirs = await upload(c, `u/${c.id}/selfies/${randomUUID()}.jpg`);
    await expectRpcError(rpc(b.client, 'react_with_selfie', { p_post_id: posts[0].id, p_image_path: theirs }), 'invalid_image', 400);
    await expectRpcError(
      rpc(b.client, 'react_with_selfie', { p_post_id: posts[0].id, p_image_path: `u/${b.id}/../x.jpg` }),
      'invalid_image',
      400,
    );
    const mine = await upload(stranger, `u/${stranger.id}/selfies/${randomUUID()}.jpg`);
    await expectRpcError(rpc(stranger.client, 'react_with_selfie', { p_post_id: posts[0].id, p_image_path: mine }), 'post_not_found', 404);
    await expectRpcError(rpc(stranger.client, 'remove_selfie_reaction', { p_post_id: posts[0].id }), 'post_not_found', 404);
  });

  it('removing a selfie deletes its file, cancels the unsent push and announces the change', async () => {
    const { posts } = await postPhoto(a, [g.id]);
    const path = await upload(c, `u/${c.id}/selfies/${randomUUID()}.jpg`);
    await rpc(c.client, 'react_with_selfie', { p_post_id: posts[0].id, p_image_path: path });
    await rpc(c.client, 'remove_selfie_reaction', { p_post_id: posts[0].id });
    expect(await select(a.client, 'selfie_reactions', (q) => q.eq('post_id', posts[0].id))).toEqual([]);
    expect(await jobsWhere('storage.delete', { paths: [path] })).toHaveLength(1);
    const [push] = await jobsWhere('push.selfie_reaction', { post_id: posts[0].id, user_id: c.id });
    expect(push.status).toBe('cancelled');
    expect(await canSign(a, path)).toBe(false);
  });

  it('the photo\u2019s author removes someone\u2019s selfie and cannot react to their own photo; a selfie can be reported', async () => {
    const { posts } = await postPhoto(a, [g.id]);
    const path = await upload(b, `u/${b.id}/selfies/${randomUUID()}.jpg`);
    const row = await rpc(b.client, 'react_with_selfie', { p_post_id: posts[0].id, p_image_path: path });
    const own = await upload(a, `u/${a.id}/selfies/${randomUUID()}.jpg`);
    await expectRpcError(rpc(a.client, 'react_with_selfie', { p_post_id: posts[0].id, p_image_path: own }), 'own_post', 400);
    const reportId = await rpc(c.client, 'report', { p_target_kind: 'selfie', p_target_id: row.id, p_reason: 'not ok' });
    expect(reportId).toEqual(expect.any(String));
    await expectRpcError(rpc(b.client, 'report', { p_target_kind: 'selfie', p_target_id: row.id, p_reason: 'mine' }), 'target_not_found', 404);
    await expectRpcError(rpc(c.client, 'remove_selfie_reaction', { p_post_id: posts[0].id, p_user_id: b.id }), 'not_allowed', 403);
    await rpc(a.client, 'remove_selfie_reaction', { p_post_id: posts[0].id, p_user_id: b.id });
    expect(await select(a.client, 'selfie_reactions', (q) => q.eq('post_id', posts[0].id))).toEqual([]);
  });

  it('blocks hide selfies both ways', async () => {
    const [x, y, z] = await createUsers(3, 'Blk');
    const grp = await createGroup(x, [y, z]);
    const { posts } = await postPhoto(x, [grp.id]);
    const path = await upload(y, `u/${y.id}/selfies/${randomUUID()}.jpg`);
    await rpc(y.client, 'react_with_selfie', { p_post_id: posts[0].id, p_image_path: path });
    await rpc(z.client, 'block_user', { p_user_id: y.id });
    expect(await select(z.client, 'selfie_reactions', (q) => q.eq('post_id', posts[0].id))).toEqual([]);
    expect(await canSign(z, path)).toBe(false);
    expect((await select(x.client, 'selfie_reactions', (q) => q.eq('post_id', posts[0].id))).length).toBe(1);
  });
});

describe('unlinked upload sweep', () => {
  it('deletes selfie and plan-cover uploads linked to nothing after 7 days, never a linked or recent one', async () => {
    const { posts } = await postPhoto(a, [g.id]);
    const linked = await upload(b, `u/${b.id}/selfies/${randomUUID()}.jpg`);
    await rpc(b.client, 'react_with_selfie', { p_post_id: posts[0].id, p_image_path: linked });
    const strayedSelfie = await upload(b, `u/${b.id}/selfies/${randomUUID()}.jpg`);
    const strayedCover = await upload(c, `u/${c.id}/plans/${randomUUID()}.jpg`);
    const recent = await upload(c, `u/${c.id}/plans/${randomUUID()}.jpg`);
    const avatar = await upload(c, `avatars/${c.id}/${randomUUID()}.jpg`);
    await sql(`update storage.objects set created_at = now() - interval '8 days' where name = any($1::text[])`, [
      [linked, strayedSelfie, strayedCover, avatar],
    ]);

    const swept = await admin.rpc('due_unlinked_uploads', {});
    expect(swept.error).toBeNull();
    const queued = (await sql(`select payload from public.jobs where kind = 'storage.delete' and status = 'queued'`)).flatMap(
      (j: any) => j.payload.paths as string[],
    );
    expect(queued).toEqual(expect.arrayContaining([strayedSelfie, strayedCover]));
    for (const kept of [linked, recent, avatar]) expect(queued, kept).not.toContain(kept);

    // a second run does not queue the same files again
    await admin.rpc('due_unlinked_uploads', {});
    const again = (await sql(`select payload from public.jobs where kind = 'storage.delete' and status = 'queued'`)).flatMap(
      (j: any) => j.payload.paths as string[],
    );
    expect(again.filter((p) => p === strayedSelfie)).toHaveLength(1);
    const { error } = await b.client.rpc('due_unlinked_uploads', {});
    expect(error).not.toBeNull();
  });
});

describe('plans', () => {
  it('create: the maker is Going, the group is told, and a reminder waits for the day before', async () => {
    const starts = days(5);
    const plan = await rpc(a.client, 'create_plan', {
      p_group_id: g.id,
      p_title: '  Dinner at ours  ',
      p_starts_at: starts,
      p_place: 'Kitchen',
    });
    expect(plan).toMatchObject({ group_id: g.id, created_by: a.id, title: 'Dinner at ours', place: 'Kitchen', all_day: false, canceled_at: null });
    const [{ day }] = await sql(`select ($1::timestamptz at time zone 'Europe/Paris')::date::text as day`, [starts]);
    expect(String(plan.local_date)).toBe(day);
    expect(await select(b.client, 'plan_answers', (q) => q.eq('plan_id', plan.id))).toMatchObject([{ user_id: a.id, answer: 'going' }]);
    expect(await jobsWhere('push.plan_created', { plan_id: plan.id })).toHaveLength(1);
    const [reminder] = await jobsWhere('push.plan_tomorrow', { plan_id: plan.id });
    expect(reminder.status).toBe('queued');
    expect(new Date(reminder.run_at).getTime()).toBe(new Date(starts).getTime() - 86_400_000);
    expect(await select(stranger.client, 'plans', (q) => q.eq('id', plan.id))).toEqual([]);
  });

  it('an all-day plan starts at 00:00 of its day in the group time zone; a plan under a day away gets no reminder', async () => {
    const plan = await rpc(a.client, 'create_plan', { p_group_id: g.id, p_title: 'Beach day', p_starts_at: days(3), p_all_day: true });
    const [{ local }] = await sql(`select to_char($1::timestamptz at time zone 'Europe/Paris', 'HH24:MI') as local`, [plan.starts_at]);
    expect(local).toBe('00:00');
    const soon = await rpc(a.client, 'create_plan', { p_group_id: g.id, p_title: 'Tonight', p_starts_at: new Date(Date.now() + 3_600_000).toISOString() });
    expect(await jobsWhere('push.plan_tomorrow', { plan_id: soon.id })).toEqual([]);
  });

  it('answers: one tap each, replaceable, clearable; Can\u2019t go is seen only by its author and the maker', async () => {
    const plan = await rpc(a.client, 'create_plan', { p_group_id: g.id, p_title: 'Hike', p_starts_at: days(4) });
    await rpc(b.client, 'answer_plan', { p_plan_id: plan.id, p_answer: 'maybe' });
    await rpc(b.client, 'answer_plan', { p_plan_id: plan.id, p_answer: 'cant_go' });
    await rpc(c.client, 'answer_plan', { p_plan_id: plan.id, p_answer: 'going' });
    const answers = async (u: TestUser) =>
      Object.fromEntries((await select(u.client, 'plan_answers', (q) => q.eq('plan_id', plan.id))).map((r) => [r.user_id, r.answer]));
    expect(await answers(a)).toEqual({ [a.id]: 'going', [b.id]: 'cant_go', [c.id]: 'going' }); // the maker
    expect(await answers(b)).toEqual({ [a.id]: 'going', [b.id]: 'cant_go', [c.id]: 'going' }); // their own
    expect(await answers(c)).toEqual({ [a.id]: 'going', [c.id]: 'going' }); // not b's Can't go
    await rpc(c.client, 'clear_answer', { p_plan_id: plan.id });
    expect(await answers(a)).toEqual({ [a.id]: 'going', [b.id]: 'cant_go' });
    await expectRpcError(rpc(b.client, 'answer_plan', { p_plan_id: plan.id, p_answer: 'yes' }), 'invalid_answer', 400);
    await expectRpcError(rpc(stranger.client, 'answer_plan', { p_plan_id: plan.id, p_answer: 'going' }), 'plan_not_found', 404);
  });

  it('validates the fields, the day and the cover', async () => {
    const base = { p_group_id: g.id, p_starts_at: days(2) };
    await expectRpcError(rpc(a.client, 'create_plan', { ...base, p_title: ' ' }), 'invalid_name', 400);
    await expectRpcError(rpc(a.client, 'create_plan', { ...base, p_title: 'x'.repeat(81) }), 'invalid_name', 400);
    await expectRpcError(rpc(a.client, 'create_plan', { ...base, p_title: 'x', p_ends_at: days(1) }), 'invalid_date', 400);
    await expectRpcError(rpc(a.client, 'create_plan', { ...base, p_title: 'x', p_starts_at: days(-2) }), 'invalid_date', 400);
    await expectRpcError(rpc(a.client, 'create_plan', { ...base, p_title: 'x', p_place: 'p'.repeat(201) }), 'invalid_place', 400);
    await expectRpcError(rpc(a.client, 'create_plan', { ...base, p_title: 'x', p_note: 'n'.repeat(2049) }), 'invalid_note', 400);
    const bCover = await upload(b, `u/${b.id}/plans/${randomUUID()}.jpg`);
    await expectRpcError(rpc(a.client, 'create_plan', { ...base, p_title: 'x', p_cover_path: bCover }), 'invalid_cover', 400);
    await expectRpcError(rpc(stranger.client, 'create_plan', { ...base, p_title: 'x' }), 'not_group_member', 403);
  });

  it('the maker or an admin edits, cancels and restores; a change of time or place tells people once', async () => {
    const cover = await upload(b, `u/${b.id}/plans/${randomUUID()}.jpg`);
    const plan = await rpc(b.client, 'create_plan', { p_group_id: g.id, p_title: 'Trip', p_starts_at: days(6), p_cover_path: cover });
    expect(await canSign(c, cover)).toBe(true);
    expect(await canSign(stranger, cover)).toBe(false);

    const edit = { p_plan_id: plan.id, p_title: 'Trip!', p_starts_at: days(8), p_cover_path: cover };
    await expectRpcError(rpc(c.client, 'update_plan', edit), 'not_allowed', 403);
    // the admin (a) keeps b's cover
    const edited = await rpc(a.client, 'update_plan', edit);
    expect(edited).toMatchObject({ title: 'Trip!', cover_path: cover });
    expect(await jobsWhere('push.plan_changed', { plan_id: plan.id })).toMatchObject([{ payload: { time_changed: true, place_changed: false } }]);
    const reminders = await jobsWhere('push.plan_tomorrow', { plan_id: plan.id });
    expect(reminders.map((j) => j.status)).toEqual(['cancelled', 'queued']);
    expect(new Date(reminders[1].run_at).getTime()).toBe(new Date(edit.p_starts_at).getTime() - 86_400_000);

    // a title-only edit tells nobody; removing the cover deletes its file
    await rpc(b.client, 'update_plan', { ...edit, p_title: 'Trip!!', p_starts_at: edited.starts_at, p_cover_path: null });
    expect(await jobsWhere('push.plan_changed', { plan_id: plan.id })).toHaveLength(1);
    expect(await jobsWhere('storage.delete', { paths: [cover] })).toHaveLength(1);

    await expectRpcError(rpc(c.client, 'cancel_plan', { p_plan_id: plan.id }), 'not_allowed', 403);
    const canceled = await rpc(b.client, 'cancel_plan', { p_plan_id: plan.id });
    expect(canceled).toMatchObject({ canceled_by: b.id });
    expect(await jobsWhere('push.plan_canceled', { plan_id: plan.id })).toHaveLength(1);
    expect((await jobsWhere('push.plan_tomorrow', { plan_id: plan.id })).every((j) => j.status === 'cancelled')).toBe(true);
    await expectRpcError(rpc(c.client, 'answer_plan', { p_plan_id: plan.id, p_answer: 'going' }), 'plan_canceled', 409);
    await expectRpcError(rpc(b.client, 'update_plan', edit), 'plan_canceled', 409);
    expect((await rpc<any[]>(c.client, 'next_plans', { p_group_id: g.id })).map((p) => p.id)).not.toContain(plan.id);

    const restored = await rpc(a.client, 'restore_plan', { p_plan_id: plan.id });
    expect(restored).toMatchObject({ canceled_at: null, canceled_by: null });
    expect((await jobsWhere('push.plan_tomorrow', { plan_id: plan.id })).map((j) => j.status)).toContain('queued');
    await rpc(c.client, 'answer_plan', { p_plan_id: plan.id, p_answer: 'going' });
  });

  it('answers and edits lock once the plan is over', async () => {
    const plan = await rpc(a.client, 'create_plan', { p_group_id: g.id, p_title: 'Done', p_starts_at: days(2) });
    await sql(`update public.plans set starts_at = now() - interval '3 days', local_date = local_date - 5 where id = $1`, [plan.id]);
    await expectRpcError(rpc(b.client, 'answer_plan', { p_plan_id: plan.id, p_answer: 'going' }), 'plan_past', 409);
    await expectRpcError(rpc(a.client, 'update_plan', { p_plan_id: plan.id, p_title: 'x', p_starts_at: days(2) }), 'plan_past', 409);
    await expectRpcError(rpc(a.client, 'cancel_plan', { p_plan_id: plan.id }), 'plan_past', 409);
    expect((await rpc<any[]>(b.client, 'next_plans', {})).map((p) => p.id)).not.toContain(plan.id);
  });

  it('next_plans: upcoming plans of my groups, soonest first, with my own answer', async () => {
    const later = await rpc(a.client, 'create_plan', { p_group_id: g.id, p_title: 'Later', p_starts_at: days(20) });
    const sooner = await rpc(a.client, 'create_plan', { p_group_id: g.id, p_title: 'Sooner', p_starts_at: days(1.5) });
    await rpc(c.client, 'answer_plan', { p_plan_id: sooner.id, p_answer: 'maybe' });
    const mine = await rpc<any[]>(c.client, 'next_plans', {});
    const ids = mine.map((p) => p.id);
    expect(ids.indexOf(sooner.id)).toBeLessThan(ids.indexOf(later.id));
    expect(mine.find((p) => p.id === sooner.id).my_answer).toBe('maybe');
    expect(mine.find((p) => p.id === later.id).my_answer).toBeNull();
    expect(await rpc<any[]>(stranger.client, 'next_plans', {})).toEqual([]);
    await expectRpcError(rpc(stranger.client, 'next_plans', { p_group_id: g.id }), 'not_group_member', 403);
  });

  it('plan_photos: the group\u2019s photos of the plan\u2019s days, minus blocked authors', async () => {
    const [x, y, z] = await createUsers(3, 'Pln');
    const grp = await createGroup(x, [y, z], { tz: 'UTC' });
    const plan = await rpc(x.client, 'create_plan', {
      p_group_id: grp.id,
      p_title: 'Today',
      p_starts_at: new Date().toISOString(),
    });
    const { posts: px } = await postPhoto(x, [grp.id]);
    const { posts: py } = await postPhoto(y, [grp.id]);
    // a photo from two days before is outside the plan
    const { posts: old } = await postPhoto(z, [grp.id]);
    await sql(`update public.posts set created_at = now() - interval '2 days' where id = $1`, [old[0].id]);

    const photos = await rpc<any[]>(z.client, 'plan_photos', { p_plan_id: plan.id });
    expect(photos.map((p) => p.id).sort()).toEqual([px[0].id, py[0].id].sort());
    await rpc(z.client, 'block_user', { p_user_id: y.id });
    expect((await rpc<any[]>(z.client, 'plan_photos', { p_plan_id: plan.id })).map((p) => p.id)).toEqual([px[0].id]);
    await expectRpcError(rpc(stranger.client, 'plan_photos', { p_plan_id: plan.id }), 'plan_not_found', 404);
  });

  it('a deleted account leaves its plans, without its cover', async () => {
    const [x, y] = await createUsers(2, 'Gone');
    const grp = await createGroup(x, [y]);
    const cover = await upload(y, `u/${y.id}/plans/${randomUUID()}.jpg`);
    const plan = await rpc(y.client, 'create_plan', { p_group_id: grp.id, p_title: 'Still on', p_starts_at: days(3), p_cover_path: cover });
    await rpc(y.client, 'delete_account', {});
    const [row] = await sql(`select created_by, cover_path from public.plans where id = $1`, [plan.id]);
    expect(row).toEqual({ created_by: null, cover_path: null });
    expect((await rpc<any[]>(x.client, 'next_plans', { p_group_id: grp.id })).map((p) => p.id)).toEqual([plan.id]);
  });

  it('deleting a plan\u2019s group drops its pushes', async () => {
    const [x] = await createUsers(1, 'Solo');
    const grp = await createGroup(x, []);
    const plan = await rpc(x.client, 'create_plan', { p_group_id: grp.id, p_title: 'Soon', p_starts_at: days(3) });
    await rpc(x.client, 'leave_group', { p_group_id: grp.id });
    expect(await sql(`select 1 from public.plans where id = $1`, [plan.id])).toEqual([]);
    expect((await jobsWhere('push.plan_tomorrow', { plan_id: plan.id })).map((j) => j.status)).toEqual(['cancelled']);
  });
});

describe('overnight photos', () => {
  it('a developing photo is nobody\u2019s, the sender\u2019s included, until 9 AM; then it is an ordinary post', async () => {
    const media = await createMedia(b);
    const rows = await rpc<any[]>(b.client, 'create_overnight_post', { p_media_id: media.id, p_group_ids: [g.id] });
    expect(rows).toHaveLength(1);
    const [{ expected }] = await sql(`select private.next_reveal_at(now(), 'Europe/Paris') as expected`);
    expect(new Date(rows[0].develops_at).getTime()).toBe(new Date(expected).getTime());
    expect(new Date(rows[0].develops_at).toLocaleString('en-GB', { timeZone: 'Europe/Paris', hour: '2-digit', minute: '2-digit' })).toBe('09:00');

    // members learn only that the group has photos developing and when: no number, no name, no photo
    expect(await rpc<any[]>(c.client, 'group_developing', { p_group_id: g.id })).toEqual([{ developing: true, reveal_at: expect.any(String) }]);
    expect(await rpc<any[]>(b.client, 'my_developing', {})).toEqual([{ developing: true, reveal_at: expect.any(String) }]);
    expect(await rpc<any[]>(c.client, 'my_developing', {})).toEqual([{ developing: false, reveal_at: null }]);
    const direct = await c.client.from('developing_posts').select('id');
    expect(direct.error?.code).toBe('42501');
    expect(await sql(`select 1 from public.posts where media_id = $1`, [media.id])).toEqual([]);
    expect(await canSign(c, media.originalPath)).toBe(false);
    expect(await canSign(b, media.originalPath)).toBe(false); // the sender too
    await expectRpcError(rpc(stranger.client, 'group_developing', { p_group_id: g.id }), 'not_group_member', 403);

    // the scheduler develops it
    const developed = await admin.rpc('due_developed_posts', { p_now: rows[0].develops_at });
    expect(developed.error).toBeNull();
    const post = (developed.data as any[]).find((p) => p.media_id === media.id);
    expect(post).toMatchObject({ group_id: g.id, author_id: b.id });
    expect(await sql(`select kind from public.messages where post_id = $1`, [post.id])).toEqual([{ kind: 'photo' }]);
    expect(await jobsWhere('push.photos_developed', { group_id: g.id, develops_at: rows[0].develops_at })).toHaveLength(1);
    expect(await sql(`select 1 from public.developing_posts where media_id = $1`, [media.id])).toEqual([]);
    expect(await canSign(c, media.originalPath)).toBe(true);
    expect(await canSign(b, media.originalPath)).toBe(true);
  });

  it('photos only, the caller\u2019s own media, their groups, once per group', async () => {
    const video = await createMedia(b, { kind: 'video', skipUpload: true }).catch(() => null);
    if (video) {
      await expectRpcError(rpc(b.client, 'create_overnight_post', { p_media_id: video.id, p_group_ids: [g.id] }), 'develop_photo_only', 400);
    }
    const media = await createMedia(b);
    await expectRpcError(rpc(c.client, 'create_overnight_post', { p_media_id: media.id, p_group_ids: [g.id] }), 'media_not_found', 404);
    await expectRpcError(rpc(b.client, 'create_overnight_post', { p_media_id: media.id, p_group_ids: [other.id] }), 'not_group_member', 403);
    await expectRpcError(rpc(b.client, 'create_overnight_post', { p_media_id: media.id, p_group_ids: [] }), 'no_groups', 400);
    await rpc(b.client, 'create_overnight_post', { p_media_id: media.id, p_group_ids: [g.id] });
    await expectRpcError(rpc(b.client, 'create_overnight_post', { p_media_id: media.id, p_group_ids: [g.id] }), 'already_posted', 409);
    const { media: posted } = await postPhoto(b, [g.id]);
    await expectRpcError(rpc(b.client, 'create_overnight_post', { p_media_id: posted.id, p_group_ids: [g.id] }), 'already_posted', 409);
  });

  it('a photo whose author left before it developed is dropped', async () => {
    const [x, y] = await createUsers(2, 'Ovn');
    const grp = await createGroup(x, [y]);
    const media = await createMedia(y);
    const [row] = await rpc<any[]>(y.client, 'create_overnight_post', { p_media_id: media.id, p_group_ids: [grp.id] });
    await rpc(y.client, 'leave_group', { p_group_id: grp.id });
    const res = await admin.rpc('due_developed_posts', { p_now: row.develops_at });
    expect(res.error).toBeNull();
    expect((res.data as any[]).filter((p) => p.media_id === media.id)).toEqual([]);
    expect(await sql(`select 1 from public.posts where media_id = $1`, [media.id])).toEqual([]);
  });

  it('overnight alerts can be turned off; clients cannot develop photos themselves', async () => {
    expect(await rpc(c.client, 'set_overnight_alerts', { p_on: false })).toMatchObject({ user_id: c.id, overnight: false });
    expect(await rpc(c.client, 'set_overnight_alerts', { p_on: true })).toMatchObject({ overnight: true });
    const { error } = await b.client.rpc('due_developed_posts', {});
    expect(error).not.toBeNull();
  });
});

describe('weekly question', () => {
  it('nothing is asked while the group has it off or no questions are configured', async () => {
    expect(await rpc<any[]>(b.client, 'current_group_question', { p_group_id: g.id })).toEqual([]);
    await expectRpcError(rpc(b.client, 'set_group_weekly_question', { p_group_id: g.id, p_on: true }), 'not_group_admin', 403);
    await rpc(a.client, 'set_group_weekly_question', { p_group_id: g.id, p_on: true });
    try {
      expect(await rpc<any[]>(b.client, 'current_group_question', { p_group_id: g.id })).toEqual([]); // no keys yet
    } finally {
      await rpc(a.client, 'set_group_weekly_question', { p_group_id: g.id, p_on: false });
    }
    await expectRpcError(rpc(stranger.client, 'current_group_question', { p_group_id: g.id }), 'not_group_member', 403);
  });

  it('once on: one question per group week, asked in order; a member removes it for themself; answers are posts', async () => {
    const [x, y, z] = await createUsers(3, 'Qst');
    const grp = await createGroup(x, [y, z]);
    await rpc(x.client, 'set_group_weekly_question', { p_group_id: grp.id, p_on: true });
    await setConfig('weekly_question_keys', ['question.weekly.q01', 'question.weekly.q02']);
    try {
      const [q] = await rpc<any[]>(y.client, 'current_group_question', { p_group_id: grp.id });
      expect(q).toMatchObject({ question_key: 'question.weekly.q01', hidden_by_me: false });
      expect((await rpc<any[]>(z.client, 'current_group_question', { p_group_id: grp.id }))[0].id).toBe(q.id);

      await rpc(z.client, 'hide_question', { p_question_id: q.id });
      expect((await rpc<any[]>(z.client, 'current_group_question', { p_group_id: grp.id }))[0].hidden_by_me).toBe(true);
      expect((await rpc<any[]>(y.client, 'current_group_question', { p_group_id: grp.id }))[0].hidden_by_me).toBe(false);
      await expectRpcError(rpc(stranger.client, 'hide_question', { p_question_id: q.id }), 'question_not_found', 404);

      const { posts } = await postPhoto(y, [grp.id]);
      const linked = await rpc(y.client, 'answer_question', { p_post_id: posts[0].id, p_question_id: q.id });
      expect(linked.question_id).toBe(q.id);
      await expectRpcError(rpc(z.client, 'answer_question', { p_post_id: posts[0].id, p_question_id: q.id }), 'post_not_found', 404);
      const { posts: elsewhere } = await postPhoto(stranger, [other.id]);
      await expectRpcError(rpc(stranger.client, 'answer_question', { p_post_id: elsewhere[0].id, p_question_id: q.id }), 'invalid_question', 404);

      // next week: the next key; last week's question is closed to new answers
      await sql(`update public.group_questions set week_start = week_start - 7 where id = $1`, [q.id]);
      const [next] = await rpc<any[]>(y.client, 'current_group_question', { p_group_id: grp.id });
      expect(next.question_key).toBe('question.weekly.q02');
      const { posts: late } = await postPhoto(y, [grp.id]);
      await expectRpcError(rpc(y.client, 'answer_question', { p_post_id: late[0].id, p_question_id: q.id }), 'question_closed', 409);
      expect((await rpc(y.client, 'answer_question', { p_post_id: posts[0].id, p_question_id: null })).question_id).toBeNull();
    } finally {
      await setConfig('weekly_question_keys', null);
    }
  });
});
