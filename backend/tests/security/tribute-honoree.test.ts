// Security invariant 5: a birthday honoree cannot see their own tribute request or
// the contributions before the tribute is delivered; once delivered, the video is the
// honoree's and its contributors' (migration 0034), nobody else's.
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  admin,
  closeDb,
  createGroup,
  createUsers,
  expectRpcError,
  postPhoto,
  rpc,
  select,
  sql,
  TINY_JPEG,
  type TestGroup,
  type TestUser,
} from '../helpers';

let honoree: TestUser, m1: TestUser, m2: TestUser;
let group: TestGroup;
let requestId: string;
let m1Post: string;

beforeAll(async () => {
  [honoree, m1, m2] = await createUsers(3, 'Bday');
  group = await createGroup(m1, [honoree, m2], { tz: 'America/New_York' });
  // birthday 5 days from today in the group's time zone (year 1995)
  const [{ d }] = await sql<{ d: string }>(
    `select to_char((now() at time zone 'America/New_York')::date + 5, '1995-MM-DD') as d`,
  );
  await rpc(honoree.client, 'set_birthday', { p_birthday: d, p_opt_in: true });
  const created = await rpc<any[]>(admin, 'due_birthday_requests', {});
  const mine = created.filter((r) => r.group_id === group.id);
  expect(mine).toHaveLength(1);
  requestId = mine[0].id;
  m1Post = (await postPhoto(m1, [group.id])).posts[0].id;
});

afterAll(closeDb);

describe('tribute privacy', () => {
  it('the request exists for the other members only', async () => {
    expect((await select(m1.client, 'tribute_requests')).map((r: any) => r.id)).toContain(requestId);
    expect((await select(m2.client, 'tribute_requests')).map((r: any) => r.id)).toContain(requestId);
    expect(await select(honoree.client, 'tribute_requests')).toEqual([]);
  });

  it('a push job targets the request (audience excludes the honoree)', async () => {
    const jobs = await sql(`select payload from public.jobs where kind = 'push.birthday_request' and payload ->> 'request_id' = $1`, [requestId]);
    expect(jobs).toHaveLength(1);
    expect(jobs[0].payload.honoree_id).toBe(honoree.id);
  });

  it('contributions are visible to their contributor only', async () => {
    await rpc(m1.client, 'contribute_tribute', { p_request_id: requestId, p_post_id: m1Post, p_line: 'Happy day' });
    expect(await select(m1.client, 'tribute_contributions')).toHaveLength(1);
    expect(await select(m2.client, 'tribute_contributions')).toEqual([]);
    expect(await select(honoree.client, 'tribute_contributions')).toEqual([]);
  });

  it('the honoree cannot contribute to or probe their own request', async () => {
    const hp = (await postPhoto(honoree, [group.id])).posts[0].id;
    await expectRpcError(
      rpc(honoree.client, 'contribute_tribute', { p_request_id: requestId, p_post_id: hp, p_line: 'me' }),
      'request_not_found',
      404,
    );
  });

  it('the tribute and its video stay hidden from the honoree until delivered', async () => {
    // due time passes -> tribute created
    await sql(`update public.tribute_requests set due_at = now() - interval '1 second' where id = $1`, [requestId]);
    const tributes = await rpc<any[]>(admin, 'due_tributes', {});
    const t = tributes.find((x) => x.request_id === requestId);
    expect(t).toBeTruthy();
    const video = `g/${group.id}/tributes/${t.id}/final.mp4`;
    const up = await admin.storage.from('media').upload(video, TINY_JPEG, { contentType: 'video/mp4' });
    expect(up.error).toBeNull();
    await sql(`update public.tributes set video_path = $2, status = 'ready', rendered_at = now() where id = $1`, [t.id, video]);

    expect(await select(honoree.client, 'tributes')).toEqual([]);
    expect((await honoree.client.storage.from('media').createSignedUrl(video, 60)).error).not.toBeNull();
    // VidDay: "The final video is private right from the start!" — nobody reads it before delivery (0034)
    expect(await select(m1.client, 'tributes')).toEqual([]);
    expect((await m1.client.storage.from('media').createSignedUrl(video, 60)).error).not.toBeNull();
    expect((await m2.client.storage.from('media').createSignedUrl(video, 60)).error).not.toBeNull();

    // contributions are closed now
    await expectRpcError(
      rpc(m1.client, 'contribute_tribute', { p_request_id: requestId, p_post_id: m1Post, p_line: 'edit' }),
      'tribute_closed',
      409,
    );

    // delivered
    await sql(`update public.tributes set delivered_at = now() where id = $1`, [t.id]);
    const visible = await select(honoree.client, 'tributes');
    expect(visible.map((x: any) => x.id)).toEqual([t.id]);
    expect((await honoree.client.storage.from('media').createSignedUrl(video, 60)).error).toBeNull();
    // the request and the contributions themselves stay hidden
    expect(await select(honoree.client, 'tribute_requests')).toEqual([]);
    expect(await select(honoree.client, 'tribute_contributions')).toEqual([]);
    // VidDay's "Share with Friends" goes to the contributors: m1 (contributed) watches it now; m2 (did not) never does
    expect((await select(m1.client, 'tributes')).map((x: any) => x.id)).toEqual([t.id]);
    expect((await m1.client.storage.from('media').createSignedUrl(video, 60)).error).toBeNull();
    expect(await select(m2.client, 'tributes')).toEqual([]);
    expect((await m2.client.storage.from('media').createSignedUrl(video, 60)).error).not.toBeNull();
    // group_tributes: the group screen's cards — the honoree's own video, and the contributor's
    const forHonoree = await rpc<any[]>(honoree.client, 'group_tributes', { p_group_id: group.id });
    expect(forHonoree.map((x) => [x.id, x.for_me, x.honoree_id])).toEqual([[t.id, true, honoree.id]]);
    expect(forHonoree[0].birthday_date).toBeTruthy();
    const forContributor = await rpc<any[]>(m1.client, 'group_tributes', { p_group_id: group.id });
    expect(forContributor.map((x) => [x.id, x.for_me])).toEqual([[t.id, false]]);
    expect(await rpc<any[]>(m2.client, 'group_tributes', { p_group_id: group.id })).toEqual([]);
    // a block with the honoree hides it from the contributor
    await rpc(m1.client, 'block_user', { p_user_id: honoree.id });
    expect(await rpc<any[]>(m1.client, 'group_tributes', { p_group_id: group.id })).toEqual([]);
    await rpc(m1.client, 'unblock_user', { p_user_id: honoree.id });
  });

  it('group_tributes is for members only', async () => {
    const [outsider] = await createUsers(1, 'BdayOut');
    await expectRpcError(rpc(outsider.client, 'group_tributes', { p_group_id: group.id }), 'not_group_member', 403);
  });

  it('a tribute stored under a different tribute id stays hidden', async () => {
    const stray = `g/${group.id}/tributes/${randomUUID()}/x.mp4`;
    const up = await admin.storage.from('media').upload(stray, TINY_JPEG, { contentType: 'video/mp4' });
    expect(up.error).toBeNull();
    expect((await m1.client.storage.from('media').createSignedUrl(stray, 60)).error).not.toBeNull();
  });
});
