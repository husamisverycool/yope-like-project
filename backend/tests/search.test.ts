// search_photos (migration 0040): the group's photos by caption, by chat about the photo, by member (author or "I'm in
// this" tag) and by date. Group isolation and blocks: nothing from groups you are not in, nothing by people you have a
// block with (their photos, their comments, their tags).
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  closeDb,
  createGroup,
  createUsers,
  expectRpcError,
  postPhoto,
  rpc,
  sql,
  type TestGroup,
  type TestUser,
} from './helpers';

let a: TestUser, b: TestUser, c: TestUser, outsider: TestUser;
let g: TestGroup, g2: TestGroup, h: TestGroup;
const ids: Record<string, string> = {};
const media: Record<string, string> = {};

const setCreatedAt = (postId: string, iso: string) =>
  sql(`update public.posts set created_at = $2::timestamptz where id = $1`, [postId, iso]);

async function photo(name: string, who: TestUser, groupId: string, caption: string | null, iso: string) {
  const p = await postPhoto(who, [groupId], caption ? { p_caption: caption } : {});
  await setCreatedAt(p.posts[0].id, iso);
  ids[name] = p.posts[0].id;
  media[name] = p.media.id;
}

const search = async (u: TestUser, args: Record<string, unknown>) =>
  (await rpc<any[]>(u.client, 'search_photos', args)).map((r) => r.post_id);

beforeAll(async () => {
  [a, b, c, outsider] = await createUsers(4, 'Srch');
  g = await createGroup(a, [b, c], { tz: 'America/New_York' });
  g2 = await createGroup(a, [b], { tz: 'UTC' });
  h = await createGroup(outsider, [], { tz: 'UTC' });
  await photo('beach', a, g.id, 'Beach day in Lisbon', '2026-07-04T15:00:00Z');
  await photo('cake', b, g.id, 'Birthday cake!', '2026-03-10T23:30:00Z'); // March 10, 19:30 in New York
  await photo('plain', c, g.id, null, '2026-08-01T12:00:00Z');
  await photo('other', a, g2.id, 'Lisbon again', '2026-09-01T12:00:00Z');
  await photo('hidden', outsider, h.id, 'Lisbon secrets', '2026-09-02T12:00:00Z');
  // chat about the plain photo
  await rpc(b.client, 'send_message', { p_group_id: g.id, p_kind: 'text', p_body: 'That sunset in Lisbon!', p_reply_to_post_id: ids.plain });
  await rpc(outsider.client, 'send_message', { p_group_id: h.id, p_kind: 'text', p_body: 'birthday plans', p_reply_to_post_id: ids.hidden });
  await rpc(c.client, 'tag_self', { p_post_id: ids.beach });
});

afterAll(closeDb);

describe('search_photos', () => {
  it('finds captions and chat about a photo, by word prefix, case-insensitively, newest first', async () => {
    expect(await search(b, { p_text: 'lisbon', p_group_id: g.id })).toEqual([ids.plain, ids.beach]);
    expect(await search(b, { p_text: 'LISB' })).toEqual([ids.other, ids.plain, ids.beach]);
    expect(await search(b, { p_text: 'birth' })).toEqual([ids.cake]);
    expect(await search(b, { p_text: 'beach lisbon' })).toEqual([ids.beach]);
    expect(await search(b, { p_text: 'beach paris' })).toEqual([]);
    const rows = await rpc<any[]>(b.client, 'search_photos', { p_text: 'lisbon', p_group_id: g.id });
    expect(rows.map((r) => r.matched)).toEqual([['chat'], ['caption']]);
    expect(rows[0]).toMatchObject({ post_id: ids.plain, media_id: media.plain, group_id: g.id, author_id: c.id });
  });

  it('by member: who posted it or who tagged themselves in it', async () => {
    const rows = await rpc<any[]>(a.client, 'search_photos', { p_member_id: c.id, p_group_id: g.id });
    expect(rows.map((r) => [r.post_id, r.matched])).toEqual([
      [ids.plain, ['author']],
      [ids.beach, ['tag']],
    ]);
    expect(await search(a, { p_member_id: c.id, p_text: 'lisbon' })).toEqual([ids.plain, ids.beach]);
    expect(await search(a, { p_member_id: b.id, p_text: 'lisbon' })).toEqual([]);
  });

  it("by date, in the group's time zone (the day the photo was taken), with paging", async () => {
    expect(await search(a, { p_from: '2026-03-10', p_to: '2026-03-10' })).toEqual([ids.cake]);
    expect(await search(a, { p_from: '2026-03-11', p_to: '2026-03-11' })).toEqual([]);
    expect(await search(a, { p_from: '2026-07-01' })).toEqual([ids.other, ids.plain, ids.beach]);
    const first = await rpc<any[]>(a.client, 'search_photos', { p_from: '2026-01-01', p_limit: 2 });
    expect(first.map((r) => r.post_id)).toEqual([ids.other, ids.plain]);
    expect(await search(a, { p_from: '2026-01-01', p_before: first[1].created_at })).toEqual([ids.beach, ids.cake]);
    await expectRpcError(rpc(a.client, 'search_photos', { p_from: '2026-03-02', p_to: '2026-03-01' }), 'invalid_argument', 400);
  });

  it('needs something to search for', async () => {
    await expectRpcError(rpc(a.client, 'search_photos', {}), 'invalid_argument', 400);
    await expectRpcError(rpc(a.client, 'search_photos', { p_text: ' !!! ' }), 'invalid_argument', 400);
  });

  it('group isolation: nothing from groups you are not in', async () => {
    expect(await search(outsider, { p_text: 'lisbon' })).toEqual([ids.hidden]);
    expect(await search(outsider, { p_text: 'birthday' })).toEqual([ids.hidden]); // its own chat, not g's caption
    expect(await search(outsider, { p_member_id: a.id })).toEqual([]);
    await expectRpcError(rpc(outsider.client, 'search_photos', { p_text: 'lisbon', p_group_id: g.id }), 'not_group_member', 403);
    expect(await search(a, { p_text: 'secrets' })).toEqual([]);
  });

  it('blocks: no photos, comments or tags of someone you have a block with', async () => {
    await rpc(a.client, 'block_user', { p_user_id: b.id });
    try {
      // b's comment no longer makes the plain photo match for a; b's own photo is gone
      expect(await search(a, { p_text: 'sunset' })).toEqual([]);
      expect(await search(a, { p_text: 'birthday' })).toEqual([]);
      expect(await search(a, { p_member_id: b.id })).toEqual([]);
      // and the other way round
      expect(await search(b, { p_text: 'beach' })).toEqual([]);
      expect(await search(b, { p_member_id: a.id })).toEqual([]);
      // c is unaffected
      expect(await search(c, { p_text: 'sunset' })).toEqual([ids.plain]);
    } finally {
      await rpc(a.client, 'unblock_user', { p_user_id: b.id });
    }
  });

  it('one result per photo when it was sent to several of your groups', async () => {
    const both = await postPhoto(a, [g.id, g2.id], { p_caption: 'Twice posted' });
    const rows = await rpc<any[]>(b.client, 'search_photos', { p_text: 'twice' });
    expect(rows.length).toBe(1);
    expect(rows[0].media_id).toBe(both.media.id);
    const inG2 = await rpc<any[]>(b.client, 'search_photos', { p_text: 'twice', p_group_id: g2.id });
    expect(inG2.map((r) => r.group_id)).toEqual([g2.id]);
  });
});
