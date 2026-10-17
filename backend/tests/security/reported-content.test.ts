// Reported content is hidden from the person who reported it (migration 0057): a reported post or message
// leaves the reporter's tables, Realtime, browse RPCs and files, and a collage with a reported photo is
// withheld from them. Nobody else's view changes.
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

let author: TestUser, reporter: TestUser, other: TestUser;
let group: TestGroup;
let reported: { media: any; posts: any[] };
let kept: { media: any; posts: any[] };
let message: any;
let keptMessage: any;
let collageId: string;

const ids = (rows: any[], k = 'id') => rows.map((r) => r[k]);

beforeAll(async () => {
  [author, reporter, other] = await createUsers(3, 'Rpt');
  group = await createGroup(author, [reporter, other]);
  reported = await postPhoto(author, [group.id], { p_caption: 'reported sunset' });
  kept = await postPhoto(author, [group.id], { p_caption: 'kept sunset' });
  message = await rpc(author.client, 'send_message', { p_group_id: group.id, p_kind: 'text', p_body: 'reported words' });
  keptMessage = await rpc(author.client, 'send_message', { p_group_id: group.id, p_kind: 'text', p_body: 'kept words' });
  await rpc(other.client, 'react', { p_post_id: reported.posts[0].id, p_emoji: '🔥' });

  const [inv] = await sql<{ id: string }>(
    `insert into public.daily_invitations (group_id, local_date, fires_at, closes_at, status)
     values ($1, (now() at time zone 'Europe/Paris')::date, now() - interval '10 minutes', now() - interval '8 minutes', 'closed')
     returning id`,
    [group.id],
  );
  collageId = randomUUID();
  const collagePath = `g/${group.id}/collages/${collageId}/display-1.jpg`;
  const up = await admin.storage.from('media').upload(collagePath, TINY_JPEG, { contentType: 'image/jpeg' });
  if (up.error) throw up.error;
  await sql(
    `insert into public.collages (id, group_id, invitation_id, option, post_ids, image_path, status, composed_at)
     values ($1, $2, $3, 'grid', $4::uuid[], $5, 'ready', now())`,
    [collageId, group.id, inv.id, [reported.posts[0].id], collagePath],
  );

  await rpc(reporter.client, 'report', { p_target_kind: 'post', p_target_id: reported.posts[0].id, p_reason: 'Not ok' });
  await rpc(reporter.client, 'report', { p_target_kind: 'message', p_target_id: message.id, p_reason: 'Not ok' });
});

afterAll(closeDb);

describe('reported content', () => {
  it('the reporter no longer reads the post, its chat photo line, its reactions, its media or the message', async () => {
    const posts = ids(await select(reporter.client, 'posts', (q) => q.eq('group_id', group.id)));
    expect(posts).toEqual([kept.posts[0].id]);
    const messages = await select(reporter.client, 'messages', (q) => q.eq('group_id', group.id));
    expect(ids(messages)).toContain(keptMessage.id);
    expect(ids(messages)).not.toContain(message.id);
    expect(messages.map((m: any) => m.post_id)).not.toContain(reported.posts[0].id);
    expect(ids(await select(reporter.client, 'reactions'), 'post_id')).not.toContain(reported.posts[0].id);
    expect(ids(await select(reporter.client, 'media'))).not.toContain(reported.media.id);
    expect((await reporter.client.storage.from('media').createSignedUrl(reported.media.originalPath, 60)).error).not.toBeNull();
    expect((await reporter.client.storage.from('media').createSignedUrl(kept.media.originalPath, 60)).error).toBeNull();
  });

  it('browse RPCs skip it, and it cannot be reacted to or answered', async () => {
    const weeks = await rpc<any[]>(reporter.client, 'group_history_weeks', { p_group_id: group.id });
    expect(weeks.flatMap((w) => w.post_ids)).not.toContain(reported.posts[0].id);
    expect(weeks.flatMap((w) => w.post_ids)).toContain(kept.posts[0].id);
    const wall = await rpc<any[]>(reporter.client, 'wall', { p_user_id: author.id });
    expect(ids(wall, 'post_id')).not.toContain(reported.posts[0].id);
    expect(ids(wall, 'post_id')).toContain(kept.posts[0].id);
    const found = await rpc<any[]>(reporter.client, 'search_photos', { p_text: 'sunset' });
    expect(ids(found, 'post_id')).toEqual([kept.posts[0].id]);
    await expectRpcError(rpc(reporter.client, 'react', { p_post_id: reported.posts[0].id, p_emoji: '🙂' }), 'post_not_found');
    await expectRpcError(rpc(reporter.client, 'react_to_message', { p_message_id: message.id, p_emoji: '🙂' }), 'message_not_found');
  });

  it('a collage with the reported photo is withheld from the reporter', async () => {
    expect(await select(reporter.client, 'collages', (q) => q.eq('id', collageId))).toEqual([]);
    expect(ids(await rpc<any[]>(reporter.client, 'group_collages', { p_group_id: group.id }), 'collage_id')).not.toContain(collageId);
  });

  it('nothing changes for anyone else, and the reporter may report it again', async () => {
    for (const viewer of [author, other]) {
      expect(ids(await select(viewer.client, 'posts', (q) => q.eq('group_id', group.id)))).toContain(reported.posts[0].id);
      expect(ids(await select(viewer.client, 'messages', (q) => q.eq('group_id', group.id)))).toContain(message.id);
      expect(await select(viewer.client, 'collages', (q) => q.eq('id', collageId))).toHaveLength(1);
    }
    expect(await rpc(reporter.client, 'report', { p_target_kind: 'post', p_target_id: reported.posts[0].id, p_reason: 'Again' })).toBeTruthy();
  });
});
