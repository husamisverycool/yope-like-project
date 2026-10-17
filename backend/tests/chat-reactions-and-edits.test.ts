// Reactions on chat messages and editing (owner decision 34, docs/RESEARCH_FEATURES_2026-10-17.md #7 and #8;
// migration 0047).
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  closeDb,
  createGroup,
  createUsers,
  expectRpcError,
  postPhoto,
  rpc,
  select,
  setConfig,
  sql,
  type TestGroup,
  type TestUser,
} from './helpers';

let a: TestUser, b: TestUser, c: TestUser, stranger: TestUser;
let g: TestGroup;

beforeAll(async () => {
  [a, b, c, stranger] = await createUsers(4, 'React');
  g = await createGroup(a, [b, c]);
});

afterAll(closeDb);

const text = (user: TestUser, body: string) =>
  rpc(user.client, 'send_message', { p_group_id: g.id, p_kind: 'text', p_body: body });

const reactionsOn = async (viewer: TestUser, messageId: string) =>
  (await select(viewer.client, 'message_reactions', (q) => q.eq('message_id', messageId).order('created_at')))
    .map((r: any) => `${r.user_id === a.id ? 'a' : r.user_id === b.id ? 'b' : 'c'}:${r.emoji}`);

describe('reactions on messages', () => {
  it('one per person per message: a new emoji replaces yours; rows only, no push', async () => {
    const m = await text(a, 'pizza tonight?');
    await rpc(b.client, 'react_to_message', { p_message_id: m.id, p_emoji: '👍' });
    await rpc(c.client, 'react_to_message', { p_message_id: m.id, p_emoji: '😂' });
    const row = await rpc(b.client, 'react_to_message', { p_message_id: m.id, p_emoji: '🍕' });
    expect(row).toMatchObject({ message_id: m.id, user_id: b.id, emoji: '🍕', group_id: g.id });
    expect((await reactionsOn(a, m.id)).sort()).toEqual(['b:🍕', 'c:😂']);
    const jobs = await sql(`select 1 from public.jobs where kind <> 'push.new_message' and payload ->> 'message_id' = $1`, [m.id]);
    expect(jobs).toEqual([]);
    await rpc(b.client, 'unreact_to_message', { p_message_id: m.id });
    expect(await reactionsOn(a, m.id)).toEqual(['c:😂']);
  });

  it('text and voice only; any emoji, never text; members only', async () => {
    const m = await text(a, 'hi');
    await expectRpcError(rpc(b.client, 'react_to_message', { p_message_id: m.id, p_emoji: 'lol' }), 'invalid_emoji', 400);
    await expectRpcError(rpc(stranger.client, 'react_to_message', { p_message_id: m.id, p_emoji: '🔥' }), 'message_not_found', 404);
    const photo = (await postPhoto(a, [g.id])).posts[0];
    const [photoMessage] = await select(a.client, 'messages', (q) => q.eq('post_id', photo.id));
    await expectRpcError(rpc(b.client, 'react_to_message', { p_message_id: photoMessage.id, p_emoji: '🔥' }), 'invalid_kind', 400);
    const [joined] = await select(a.client, 'messages', (q) => q.eq('group_id', g.id).eq('kind', 'joined').limit(1));
    await expectRpcError(rpc(b.client, 'react_to_message', { p_message_id: joined.id, p_emoji: '👋' }), 'invalid_kind', 400);
  });

  it('a block hides reactions both ways and refuses reacting to the blocked person', async () => {
    const m = await text(a, 'look');
    await rpc(c.client, 'react_to_message', { p_message_id: m.id, p_emoji: '👀' });
    await rpc(b.client, 'block_user', { p_user_id: c.id });
    try {
      expect(await reactionsOn(b, m.id)).toEqual([]);
      expect(await reactionsOn(a, m.id)).toEqual(['c:👀']);
      const cs = await text(c, 'from c');
      await expectRpcError(rpc(b.client, 'react_to_message', { p_message_id: cs.id, p_emoji: '🔥' }), 'message_not_found', 404);
    } finally {
      await rpc(b.client, 'unblock_user', { p_user_id: c.id });
    }
  });

  it('a deleted message takes its reactions with it', async () => {
    const m = await text(a, 'oops');
    await rpc(b.client, 'react_to_message', { p_message_id: m.id, p_emoji: '😬' });
    await rpc(a.client, 'delete_message', { p_message_id: m.id });
    expect(await sql(`select 1 from public.message_reactions where message_id = $1`, [m.id])).toEqual([]);
  });
});

describe('editing a sent text message', () => {
  it('your own text, marked edited; the new text for everyone; no push', async () => {
    const m = await text(a, 'see you at 7');
    expect(m.edited_at).toBeNull();
    const edited = await rpc(a.client, 'edit_message', { p_message_id: m.id, p_body: 'see you at 8' });
    expect(edited.body).toBe('see you at 8');
    expect(edited.edited_at).not.toBeNull();
    const [seen] = await select(b.client, 'messages', (q) => q.eq('id', m.id));
    expect(seen).toMatchObject({ body: 'see you at 8' });
    expect(await sql(`select 1 from public.jobs where kind <> 'push.new_message' and payload ->> 'message_id' = $1`, [m.id])).toEqual([]);
    // the same text again changes nothing and uses no edit
    const same = await rpc(a.client, 'edit_message', { p_message_id: m.id, p_body: 'see you at 8' });
    expect(same.edited_at).toBe(edited.edited_at);
  });

  it("only your own, only text, a body that is not empty", async () => {
    const m = await text(a, 'mine');
    await expectRpcError(rpc(b.client, 'edit_message', { p_message_id: m.id, p_body: 'hijack' }), 'message_not_found', 404);
    await expectRpcError(rpc(a.client, 'edit_message', { p_message_id: m.id, p_body: '   ' }), 'invalid_body', 400);
    const photo = (await postPhoto(a, [g.id])).posts[0];
    const [photoMessage] = await select(a.client, 'messages', (q) => q.eq('post_id', photo.id));
    await expectRpcError(rpc(a.client, 'edit_message', { p_message_id: photoMessage.id, p_body: 'x' }), 'invalid_kind', 400);
  });

  it('at most message_edit_max times, within message_edit_window_s', async () => {
    const m = await text(a, 'v0');
    for (let i = 1; i <= 5; i++) await rpc(a.client, 'edit_message', { p_message_id: m.id, p_body: `v${i}` });
    await expectRpcError(rpc(a.client, 'edit_message', { p_message_id: m.id, p_body: 'v6' }), 'edit_window_closed', 409);

    const old = await text(a, 'old');
    await sql(`update public.messages set created_at = now() - interval '16 minutes' where id = $1`, [old.id]);
    await expectRpcError(rpc(a.client, 'edit_message', { p_message_id: old.id, p_body: 'new' }), 'edit_window_closed', 409);

    // fails closed without the setting
    const fresh = await text(a, 'fresh');
    await setConfig('message_edit_window_s', null);
    try {
      await expectRpcError(rpc(a.client, 'edit_message', { p_message_id: fresh.id, p_body: 'x' }), 'edit_window_closed', 409);
    } finally {
      await setConfig('message_edit_window_s', 900);
    }
  });

  it('the window and the limit are public settings the apps read', async () => {
    const rows = await select(b.client, 'public_app_config', (q) => q.in('key', ['message_edit_window_s', 'message_edit_max']));
    expect(Object.fromEntries(rows.map((r: any) => [r.key, r.value]))).toEqual({ message_edit_window_s: 900, message_edit_max: 5 });
  });
});

describe('editing a caption', () => {
  it('your own photo, any time; empty removes it; marked edited', async () => {
    const post = (await postPhoto(a, [g.id], { p_caption: 'beach' })).posts[0];
    await sql(`update public.posts set created_at = now() - interval '30 days' where id = $1`, [post.id]);
    const edited = await rpc(a.client, 'edit_caption', { p_post_id: post.id, p_caption: 'beach day' });
    expect(edited).toMatchObject({ caption: 'beach day' });
    expect(edited.caption_edited_at).not.toBeNull();
    const removed = await rpc(a.client, 'edit_caption', { p_post_id: post.id, p_caption: '  ' });
    expect(removed.caption).toBeNull();
    await expectRpcError(rpc(b.client, 'edit_caption', { p_post_id: post.id, p_caption: 'mine now' }), 'post_not_found', 404);
    await expectRpcError(rpc(a.client, 'edit_caption', { p_post_id: post.id, p_caption: 'x'.repeat(1001) }), 'invalid_caption', 400);
  });

  it('search finds the new caption, not the old one', async () => {
    const post = (await postPhoto(a, [g.id], { p_caption: 'zebracrossing' })).posts[0];
    await rpc(a.client, 'edit_caption', { p_post_id: post.id, p_caption: 'okapisighting' });
    const hits = async (q: string) => (await rpc<any[]>(b.client, 'search_photos', { p_text: q, p_group_id: g.id })).map((r) => r.post_id);
    expect(await hits('okapi')).toContain(post.id);
    expect(await hits('zebra')).not.toContain(post.id);
  });
});
