// Security invariant 4: blocking hides each person's content from the other in
// shared groups (posts, messages, reactions, tags, walls, files, realtime), and withholds
// composited media made with their photos (collages, tribute videos: migration 0057).
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
  sleep,
  sql,
  TINY_JPEG,
  type TestGroup,
  type TestUser,
  waitFor,
  waitForRealtimeSubscriptions,
} from '../helpers';

let blocker: TestUser, blocked: TestUser, third: TestUser;
let group: TestGroup;
let blockerPost: { media: any; posts: any[] };
let blockedPost: { media: any; posts: any[] };
let thirdPost: { media: any; posts: any[] };
let collageId: string, collagePath: string;
let tributeId: string, tributePath: string;

beforeAll(async () => {
  [blocker, blocked, third] = await createUsers(3, 'Blk');
  group = await createGroup(third, [blocker, blocked]);
  blockerPost = await postPhoto(blocker, [group.id]);
  blockedPost = await postPhoto(blocked, [group.id]);
  thirdPost = await postPhoto(third, [group.id]);
  await rpc(blocked.client, 'send_message', { p_group_id: group.id, p_kind: 'text', p_body: 'from blocked' });
  await rpc(blocker.client, 'send_message', { p_group_id: group.id, p_kind: 'text', p_body: 'from blocker' });
  await rpc(blocked.client, 'react', { p_post_id: thirdPost.posts[0].id, p_emoji: '😀' });
  await rpc(blocker.client, 'react', { p_post_id: thirdPost.posts[0].id, p_emoji: '😎' });
  await rpc(blocked.client, 'tag_self', { p_post_id: thirdPost.posts[0].id });

  // a collage of the day with all three photos (worker-made, rendered once for the group)
  const [inv] = await sql<{ id: string }>(
    `insert into public.daily_invitations (group_id, local_date, fires_at, closes_at, status)
     values ($1, (now() at time zone 'Europe/Paris')::date, now() - interval '10 minutes', now() - interval '8 minutes', 'closed')
     returning id`,
    [group.id],
  );
  collageId = randomUUID();
  collagePath = `g/${group.id}/collages/${collageId}/display-1.jpg`;
  const collageUp = await admin.storage.from('media').upload(collagePath, TINY_JPEG, { contentType: 'image/jpeg' });
  if (collageUp.error) throw collageUp.error;
  await sql(
    `insert into public.collages (id, group_id, invitation_id, option, post_ids, image_path, status, composed_at)
     values ($1, $2, $3, 'grid', $4::uuid[], $5, 'ready', now())`,
    [collageId, group.id, inv.id, [blockerPost.posts[0].id, blockedPost.posts[0].id, thirdPost.posts[0].id], collagePath],
  );

  // a birthday video for the blocker, with photos of the blocked person and the third member (contributed
  // before the block), rendered and delivered
  const [req] = await sql<{ id: string }>(
    `insert into public.tribute_requests (group_id, honoree_id, birthday_date, due_at)
     values ($1, $2, current_date + 1, now() + interval '1 day') returning id`,
    [group.id, blocker.id],
  );
  await rpc(blocked.client, 'contribute_tribute', { p_request_id: req.id, p_post_id: blockedPost.posts[0].id, p_line: 'HB!' });
  await rpc(third.client, 'contribute_tribute', { p_request_id: req.id, p_post_id: thirdPost.posts[0].id, p_line: 'Happy day' });
  tributeId = randomUUID();
  tributePath = `g/${group.id}/tributes/${tributeId}/video.mp4`;
  const tributeUp = await admin.storage.from('media').upload(tributePath, TINY_JPEG, { contentType: 'video/mp4' });
  if (tributeUp.error) throw tributeUp.error;
  await sql(
    `insert into public.tributes (id, request_id, group_id, honoree_id, video_path, status, rendered_at, delivered_at)
     values ($1, $2, $3, $4, $5, 'ready', now(), now() - interval '1 minute')`,
    [tributeId, req.id, group.id, blocker.id, tributePath],
  );

  await rpc(blocker.client, 'block_user', { p_user_id: blocked.id });
});

afterAll(closeDb);

const ids = (rows: any[], k = 'id') => rows.map((r) => r[k]);

describe('blocking', () => {
  it('hides posts, messages, reactions and tags in both directions', async () => {
    for (const [viewer, other] of [
      [blocker, blocked],
      [blocked, blocker],
    ] as const) {
      expect(ids(await select(viewer.client, 'posts'), 'author_id')).not.toContain(other.id);
      expect(ids(await select(viewer.client, 'messages'), 'author_id')).not.toContain(other.id);
      expect(ids(await select(viewer.client, 'reactions'), 'user_id')).not.toContain(other.id);
      expect(ids(await select(viewer.client, 'post_tags'), 'user_id')).not.toContain(other.id);
      expect(ids(await select(viewer.client, 'media'), 'owner_id')).not.toContain(other.id);
    }
  });

  it('third members still see both', async () => {
    const authors = ids(await select(third.client, 'posts'), 'author_id');
    expect(authors).toEqual(expect.arrayContaining([blocker.id, blocked.id]));
    const reactors = ids(await select(third.client, 'reactions'), 'user_id');
    expect(reactors).toEqual(expect.arrayContaining([blocker.id, blocked.id]));
  });

  it('walls are empty both ways', async () => {
    expect(await rpc(blocker.client, 'wall', { p_user_id: blocked.id })).toEqual([]);
    expect(await rpc(blocked.client, 'wall', { p_user_id: blocker.id })).toEqual([]);
    const thirdView = await rpc<any[]>(third.client, 'wall', { p_user_id: blocked.id });
    expect(thirdView.map((w) => w.item_kind).sort()).toEqual(['collage', 'post']);
  });

  it('history and on-this-day skip the other person', async () => {
    const weeks = await rpc<any[]>(blocker.client, 'group_history_weeks', { p_group_id: group.id });
    const all = weeks.flatMap((w) => w.post_ids);
    expect(all).not.toContain(blockedPost.posts[0].id);
    expect(all).toContain(blockerPost.posts[0].id);
  });

  it('a collage with a photo of the other person is withheld from both, with its files (0057)', async () => {
    for (const viewer of [blocker, blocked]) {
      expect(await select(viewer.client, 'collages', (q) => q.eq('id', collageId))).toEqual([]);
      expect(ids(await rpc<any[]>(viewer.client, 'group_collages', { p_group_id: group.id }), 'collage_id')).not.toContain(collageId);
      const weeks = await rpc<any[]>(viewer.client, 'group_history_weeks', { p_group_id: group.id });
      expect(weeks.flatMap((w) => w.collages.map((c: any) => c.collage_id))).not.toContain(collageId);
      expect((await rpc<any[]>(viewer.client, 'wall', { p_user_id: third.id })).map((w) => w.collage_id)).not.toContain(collageId);
      const signed = await viewer.client.storage.from('media').createSignedUrl(collagePath, 60);
      expect(signed.error, 'collage file').not.toBeNull();
    }
    // the third member still has it
    expect(await select(third.client, 'collages', (q) => q.eq('id', collageId))).toHaveLength(1);
    expect(ids(await rpc<any[]>(third.client, 'group_collages', { p_group_id: group.id }), 'collage_id')).toContain(collageId);
    expect((await third.client.storage.from('media').createSignedUrl(collagePath, 60)).error).toBeNull();
  });

  it("a tribute video with the other person's photo is withheld, even from its honoree (0057)", async () => {
    // the honoree (blocker) blocked a contributor after the video was made
    expect(await select(blocker.client, 'tributes', (q) => q.eq('id', tributeId))).toEqual([]);
    expect((await blocker.client.storage.from('media').createSignedUrl(tributePath, 60)).error).not.toBeNull();
    // the blocked contributor never sees a video for someone they have a block with
    expect(await select(blocked.client, 'tributes', (q) => q.eq('id', tributeId))).toEqual([]);
    // another contributor without any block sees it
    expect(await select(third.client, 'tributes', (q) => q.eq('id', tributeId))).toHaveLength(1);
    expect((await third.client.storage.from('media').createSignedUrl(tributePath, 60)).error).toBeNull();
  });

  it("cannot react to, tag in, or reply to the other's photo", async () => {
    await expectRpcError(rpc(blocker.client, 'react', { p_post_id: blockedPost.posts[0].id, p_emoji: '🙂' }), 'post_not_found');
    await expectRpcError(rpc(blocked.client, 'tag_self', { p_post_id: blockerPost.posts[0].id }), 'post_not_found');
    await expectRpcError(
      rpc(blocked.client, 'send_message', {
        p_group_id: group.id,
        p_kind: 'text',
        p_body: 'x',
        p_reply_to_post_id: blockerPost.posts[0].id,
      }),
      'post_not_found',
    );
  });

  it("cannot read the other's files", async () => {
    const s1 = await blocker.client.storage.from('media').createSignedUrl(blockedPost.media.originalPath, 60);
    expect(s1.error).not.toBeNull();
    const s2 = await blocked.client.storage.from('media').createSignedUrl(blockerPost.media.originalPath, 60);
    expect(s2.error).not.toBeNull();
    const s3 = await third.client.storage.from('media').createSignedUrl(blockedPost.media.originalPath, 60);
    expect(s3.error).toBeNull();
  });

  it('the block row is visible to the blocker only', async () => {
    expect(ids(await select(blocker.client, 'blocks'), 'blocked_id')).toEqual([blocked.id]);
    expect(await select(blocked.client, 'blocks')).toEqual([]);
  });

  it('realtime does not deliver the blocked person messages', async () => {
    const got: string[] = [];
    const ch = blocker.client
      .channel(`blk-${Math.random()}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages' }, (p: any) => got.push(p.new.author_id));
    await new Promise<void>((r) => ch.subscribe((s) => (s === 'SUBSCRIBED' ? r() : undefined)));
    await waitForRealtimeSubscriptions(blocker.id, 1);
    await rpc(blocked.client, 'send_message', { p_group_id: group.id, p_kind: 'text', p_body: 'hidden' });
    await rpc(third.client, 'send_message', { p_group_id: group.id, p_kind: 'text', p_body: 'visible' });
    await waitFor(() => got.includes(third.id));
    await sleep(1000);
    expect(got).toContain(third.id);
    expect(got).not.toContain(blocked.id);
    await blocker.client.removeAllChannels();
  });

  it('unblocking shows everything again', async () => {
    await rpc(blocker.client, 'unblock_user', { p_user_id: blocked.id });
    expect(ids(await select(blocker.client, 'posts'), 'author_id')).toContain(blocked.id);
    expect((await rpc<any[]>(blocker.client, 'wall', { p_user_id: blocked.id })).map((w) => w.item_kind).sort()).toEqual([
      'collage',
      'post',
    ]);
    expect(await select(blocker.client, 'collages', (q) => q.eq('id', collageId))).toHaveLength(1);
    expect(await select(blocker.client, 'tributes', (q) => q.eq('id', tributeId))).toHaveLength(1);
  });

  it('cannot block yourself', async () => {
    await expectRpcError(rpc(blocker.client, 'block_user', { p_user_id: blocker.id }), 'cannot_target_self', 400);
  });
});
