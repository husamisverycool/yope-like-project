// Group chat features of owner decision 34 (docs/RESEARCH_FEATURES_2026-10-17.md): the "{name} joined" / "{name} left
// the group" lines (#18).
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  closeDb,
  createGroup,
  createUsers,
  expectRpcError,
  jobsWhere,
  rpc,
  select,
  sql,
  type TestGroup,
  type TestUser,
} from './helpers';

let a: TestUser, b: TestUser, c: TestUser, d: TestUser;
let g: TestGroup;

beforeAll(async () => {
  [a, b, c, d] = await createUsers(4, 'Chat');
  g = await createGroup(a, [b, c]);
});

afterAll(closeDb);

const lines = async (viewer: TestUser, groupId: string) =>
  (await select(viewer.client, 'messages', (q) => q.eq('group_id', groupId).in('kind', ['joined', 'left']).order('created_at')))
    .map((m: any) => `${m.kind}:${m.body}`);

describe('joined and left lines (migrations 0041-0042)', () => {
  it('a join writes "{name} joined" (the creator\'s own membership does not), with no push', async () => {
    expect(await lines(c, g.id)).toEqual(['joined:Chat1 Lastname', 'joined:Chat2 Lastname']);
    const [row] = await select(a.client, 'messages', (q) => q.eq('group_id', g.id).eq('author_id', b.id).eq('kind', 'joined'));
    expect(row).toMatchObject({ post_id: null, voice_path: null, reply_to_post_id: null, reply_to_message_id: null });
    expect(await jobsWhere('push.new_message', { group_id: g.id })).toEqual([]);
    // a fresh group has no line at all
    const solo = await createGroup(d);
    expect(await lines(d, solo.id)).toEqual([]);
  });

  it('joining again (already a member) writes nothing more', async () => {
    const invite = await rpc(a.client, 'create_invite', { p_group_id: g.id });
    await rpc(b.client, 'join_group', { p_token: invite.token });
    expect(await lines(a, g.id)).toEqual(['joined:Chat1 Lastname', 'joined:Chat2 Lastname']);
  });

  it('leaving writes "{name} left the group" with the name kept; removal by an admin writes nothing', async () => {
    const h = await createGroup(a, [b, c, d]);
    await rpc(c.client, 'leave_group', { p_group_id: h.id });
    await rpc(a.client, 'remove_member', { p_group_id: h.id, p_user_id: d.id });
    const after = await lines(b, h.id);
    expect(after.filter((l) => l.startsWith('left:'))).toEqual(['left:Chat2 Lastname']);
    // c and d share another group with b? c does (g); the line names c from body either way
    expect(after.filter((l) => l.startsWith('joined:'))).toHaveLength(3);
    // the last member leaving deletes the group: no line is written into a group that no longer exists
    const k = await createGroup(d);
    await rpc(d.client, 'leave_group', { p_group_id: k.id });
    expect(await sql(`select 1 from public.messages where group_id = $1`, [k.id])).toEqual([]);
  });

  it('lines follow the messages RLS: non-members see none, a block hides the person\'s lines', async () => {
    expect(await lines(d, g.id)).toEqual([]);
    await rpc(a.client, 'block_user', { p_user_id: b.id });
    try {
      expect(await lines(a, g.id)).toEqual(['joined:Chat2 Lastname']);
    } finally {
      await rpc(a.client, 'unblock_user', { p_user_id: b.id });
    }
  });

  it('a line cannot be unsent, sent or forged', async () => {
    const [mine] = await select(b.client, 'messages', (q) => q.eq('group_id', g.id).eq('author_id', b.id).eq('kind', 'joined'));
    await expectRpcError(rpc(b.client, 'delete_message', { p_message_id: mine.id }), 'invalid_kind', 400);
    await expect(rpc(b.client, 'send_message', { p_group_id: g.id, p_kind: 'joined', p_body: 'x' })).rejects.toThrow();
    const forged = await b.client.from('messages').insert({ group_id: g.id, author_id: b.id, kind: 'left', body: 'x' });
    expect(forged.error).not.toBeNull();
    expect(await lines(a, g.id)).toEqual(['joined:Chat1 Lastname', 'joined:Chat2 Lastname']);
  });

  it('deleting the account deletes the person\'s lines', async () => {
    const [e] = await createUsers(1, 'Gone');
    const invite = await rpc(a.client, 'create_invite', { p_group_id: g.id });
    await rpc(e.client, 'join_group', { p_token: invite.token });
    expect(await lines(a, g.id)).toContain('joined:Gone0 Lastname');
    await rpc(e.client, 'delete_account');
    expect(await lines(a, g.id)).not.toContain('joined:Gone0 Lastname');
  });
});
