// Realtime as the apps use it: postgres_changes for posts/messages/reactions
// (filtered by group_id), private broadcast topic group:<id> for deletions.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  closeDb,
  createGroup,
  createUsers,
  postPhoto,
  rpc,
  sleep,
  sql,
  type TestGroup,
  type TestUser,
  waitFor,
  waitForRealtimeSubscriptions,
} from './helpers';

let a: TestUser, b: TestUser;
let g: TestGroup, g2: TestGroup;

beforeAll(async () => {
  [a, b] = await createUsers(2, 'Rt');
  g = await createGroup(a, [b]);
  g2 = await createGroup(a, [b]);
});

afterAll(async () => {
  await b.client.removeAllChannels();
  await closeDb();
});

describe('realtime', () => {
  it('publishes inserts and updates of the chat, posts, reactions and plans only', async () => {
    const rows = await sql<{ tablename: string }>(
      `select tablename from pg_publication_tables where pubname = 'supabase_realtime' order by 1`,
    );
    // developing_posts is never published (clients read only group_developing); its changes are a broadcast
    expect(rows.map((r) => r.tablename)).toEqual([
      'messages',
      'plan_answers',
      'plans',
      'posts',
      'reactions',
      'selfie_reactions',
    ]);
    const [pub] = await sql(`select pubinsert, pubupdate, pubdelete from pg_publication where pubname = 'supabase_realtime'`);
    expect(pub).toEqual({ pubinsert: true, pubupdate: true, pubdelete: false });
  });

  it('a member receives group-filtered inserts and deletion broadcasts; leaving stops them', async () => {
    const events: string[] = [];
    const filter = `group_id=eq.${g.id}`;
    const changes = b.client
      .channel(`chat-${g.id}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages', filter }, (p: any) =>
        events.push(`message:${p.new.body ?? p.new.kind}`),
      )
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'posts', filter }, (p: any) => events.push(`post:${p.new.id}`))
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'reactions', filter }, (p: any) =>
        events.push(`reaction:${p.new.emoji}`),
      );
    const topic = b.client
      .channel(`group:${g.id}`, { config: { private: true } })
      .on('broadcast', { event: 'post_deleted' }, (p: any) => events.push(`deleted:${p.payload.post_id}`))
      .on('broadcast', { event: 'message_deleted' }, (p: any) => events.push(`message_deleted:${p.payload.message_id}`));
    await new Promise<void>((r) => changes.subscribe((s) => (s === 'SUBSCRIBED' ? r() : undefined)));
    await new Promise<void>((r) => topic.subscribe((s) => (s === 'SUBSCRIBED' ? r() : undefined)));
    await waitForRealtimeSubscriptions(b.id, 3);

    const { posts } = await postPhoto(a, [g.id]);
    await rpc(a.client, 'send_message', { p_group_id: g.id, p_kind: 'text', p_body: 'hello' });
    await rpc(a.client, 'send_message', { p_group_id: g2.id, p_kind: 'text', p_body: 'other group' });
    await rpc(a.client, 'react', { p_post_id: posts[0].id, p_emoji: '🌅' });
    expect(await waitFor(() => events.includes('reaction:🌅') && events.includes('message:hello'))).toBe(true);
    expect(events).toContain(`post:${posts[0].id}`);
    expect(events).not.toContain('message:other group');

    await rpc(a.client, 'delete_post', { p_post_id: posts[0].id });
    expect(await waitFor(() => events.includes(`deleted:${posts[0].id}`))).toBe(true);

    await rpc(b.client, 'leave_group', { p_group_id: g.id });
    const before = events.length;
    await rpc(a.client, 'send_message', { p_group_id: g.id, p_kind: 'text', p_body: 'after leaving' });
    await sleep(2500);
    expect(events.slice(before)).toEqual([]);
  });
});
