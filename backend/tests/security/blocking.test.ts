// Security invariant 4: blocking hides each person's content from the other in
// shared groups (posts, messages, reactions, tags, walls, files, realtime).
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  closeDb,
  createGroup,
  createUsers,
  expectRpcError,
  postPhoto,
  rpc,
  select,
  sleep,
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
    expect((await rpc<any[]>(third.client, 'wall', { p_user_id: blocked.id })).length).toBe(1);
  });

  it('history and on-this-day skip the other person', async () => {
    const weeks = await rpc<any[]>(blocker.client, 'group_history_weeks', { p_group_id: group.id });
    const all = weeks.flatMap((w) => w.post_ids);
    expect(all).not.toContain(blockedPost.posts[0].id);
    expect(all).toContain(blockerPost.posts[0].id);
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
    expect((await rpc<any[]>(blocker.client, 'wall', { p_user_id: blocked.id })).length).toBe(1);
  });

  it('cannot block yourself', async () => {
    await expectRpcError(rpc(blocker.client, 'block_user', { p_user_id: blocker.id }), 'cannot_target_self', 400);
  });
});
