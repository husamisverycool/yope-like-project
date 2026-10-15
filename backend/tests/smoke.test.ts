import { afterAll, describe, expect, it } from 'vitest';
import { closeDb, createGroup, createUser, postPhoto, rpc, select } from './helpers';

afterAll(closeDb);

describe('smoke', () => {
  it('creates a group, posts, reads', async () => {
    const a = await createUser('Ann Smith');
    const b = await createUser('Bob Jones');
    const g = await createGroup(a, [b]);
    const { posts } = await postPhoto(a, [g.id], { p_caption: 'hi' });
    expect(posts).toHaveLength(1);
    const seen = await select(b.client, 'posts');
    expect(seen.map((p: any) => p.id)).toContain(posts[0].id);
    const msgs = await select(b.client, 'messages');
    expect(msgs).toHaveLength(1);
    const r = await rpc(b.client, 'react', { p_post_id: posts[0].id, p_emoji: '❤️' });
    expect(r.emoji).toBe('❤️');
  });
});
