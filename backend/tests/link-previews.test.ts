// Link previews built on the sender's device (owner decision 34, research #16; migration 0053).
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { closeDb, createGroup, createUsers, expectRpcError, rpc, select, sql, upload, type TestGroup, type TestUser } from './helpers';

let a: TestUser, b: TestUser, c: TestUser, outsider: TestUser;
let g: TestGroup;

beforeAll(async () => {
  [a, b, c, outsider] = await createUsers(4, 'Link');
  g = await createGroup(a, [b, c]);
});

afterAll(closeDb);

const say = (body: string) => rpc(a.client, 'send_message', { p_group_id: g.id, p_kind: 'text', p_body: body });
const canRead = async (user: TestUser, path: string) => {
  const { data } = await user.client.storage.from('media').download(path);
  return data !== null;
};

describe('set_link_preview', () => {
  it('the sender attaches the preview; members see it and its image, a block and an outsider do not', async () => {
    const url = 'https://example.com/trip';
    const m = await say(`look ${url} !`);
    const image = `u/${a.id}/links/${randomUUID()}.jpg`;
    await upload(a, image);
    const set = await rpc(a.client, 'set_link_preview', { p_message_id: m.id, p_url: url, p_title: 'Our trip', p_site: 'example.com', p_image_path: image });
    expect(set.link_preview).toEqual({ url, title: 'Our trip', site: 'example.com', image_path: image });
    const [seen] = await select(b.client, 'messages', (q) => q.eq('id', m.id));
    expect(seen.link_preview.title).toBe('Our trip');
    expect(await canRead(b, image)).toBe(true);
    expect(await canRead(outsider, image)).toBe(false);
    await rpc(c.client, 'block_user', { p_user_id: a.id });
    try {
      expect(await canRead(c, image)).toBe(false);
    } finally {
      await rpc(c.client, 'unblock_user', { p_user_id: a.id });
    }
  });

  it('only your own text message, a url that is in it, your own image', async () => {
    const m = await say('see https://example.org');
    await expectRpcError(rpc(b.client, 'set_link_preview', { p_message_id: m.id, p_url: 'https://example.org' }), 'message_not_found', 404);
    await expectRpcError(rpc(a.client, 'set_link_preview', { p_message_id: m.id, p_url: 'https://elsewhere.net' }), 'invalid_argument', 400);
    await expectRpcError(rpc(a.client, 'set_link_preview', { p_message_id: m.id, p_url: 'javascript:alert(1)' }), 'invalid_argument', 400);
    await expectRpcError(
      rpc(a.client, 'set_link_preview', { p_message_id: m.id, p_url: 'https://example.org', p_image_path: `u/${b.id}/links/x.jpg` }),
      'invalid_path', 400,
    );
    const cleared = await rpc(a.client, 'set_link_preview', { p_message_id: m.id, p_url: null });
    expect(cleared.link_preview).toBeNull();
  });

  it('editing the link out drops the preview and deletes its image', async () => {
    const url = 'https://example.com/a';
    const m = await say(url);
    const image = `u/${a.id}/links/${randomUUID()}.jpg`;
    await upload(a, image);
    await rpc(a.client, 'set_link_preview', { p_message_id: m.id, p_url: url, p_image_path: image });
    const kept = await rpc(a.client, 'edit_message', { p_message_id: m.id, p_body: `${url} (fixed)` });
    expect(kept.link_preview?.url).toBe(url);
    const dropped = await rpc(a.client, 'edit_message', { p_message_id: m.id, p_body: 'never mind' });
    expect(dropped.link_preview).toBeNull();
    const jobs = await sql(`select payload from public.jobs where kind = 'storage.delete' and payload::text like $1`, [`%${image}%`]);
    expect(jobs.length).toBeGreaterThan(0);
  });
});
