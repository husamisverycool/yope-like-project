// Security invariant 3: account deletion deletes all of the user's data and
// (through the auth.delete_user job, run by the worker with the service role)
// the auth user.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  admin,
  closeDb,
  createGroup,
  createMedia,
  createUsers,
  expectRpcError,
  rpc,
  sql,
  type TestUser,
} from '../helpers';
import { allRowsJson, publicRelations, seedFullGroup, type SeededGroup } from './world';

let users: TestUser[];
let doomed: TestUser;
let seeded: SeededGroup;
let soloGroupId: string;
let otherGroupId: string;
let firstJobId: number;

beforeAll(async () => {
  users = await createUsers(5, 'Acct');
  doomed = users[0];
  seeded = await seedFullGroup(users.slice(0, 4), 'Doomed admin group');
  // a group where the doomed user is the only member -> deleted with the account
  const solo = await createGroup(doomed, [], { name: 'Solo' });
  soloGroupId = solo.id;
  const m = await createMedia(doomed);
  await rpc(doomed.client, 'create_post', { p_media_id: m.id, p_group_ids: [soloGroupId] });
  // a group where the doomed user is a plain member and the birthday honoree
  const other = await createGroup(users[4], [doomed, users[1]], { name: 'Other' });
  otherGroupId = other.id;
  await rpc(doomed.client, 'set_birthday', { p_birthday: '1991-02-03', p_opt_in: true });
  await sql(
    `insert into public.tribute_requests (group_id, honoree_id, birthday_date, due_at)
     values ($1, $2, current_date + 2, now() + interval '2 days')`,
    [otherGroupId, doomed.id],
  );
  await rpc(users[4].client, 'block_user', { p_user_id: doomed.id });

  firstJobId = (await sql<{ id: number }>(`select coalesce(max(id), 0)::int as id from public.jobs`))[0].id;
  await rpc(doomed.client, 'delete_account');
});

afterAll(closeDb);

describe('delete_account', () => {
  it('no row anywhere references the user', async () => {
    const hits: string[] = [];
    for (const r of await publicRelations()) {
      if (r.type !== 'BASE TABLE' || r.name === 'jobs') continue;
      for (const j of await allRowsJson(r.name)) if (j.includes(doomed.id)) hits.push(r.name);
    }
    expect(hits).toEqual([]);
  });

  it("removes the user's photos and posts everywhere", async () => {
    for (const id of seeded.mediaIds.slice(0, 1)) {
      expect(await sql(`select 1 from public.media where id = $1`, [id])).toEqual([]);
    }
    expect(await sql(`select 1 from public.posts where id = $1`, [seeded.postIds[0]])).toEqual([]);
    // other members' content stays
    expect(await sql(`select 1 from public.posts where id = $1`, [seeded.postIds[1]])).toHaveLength(1);
  });

  it('hands the admin role to the longest-standing member and deletes groups left empty', async () => {
    const admins = await sql<{ user_id: string }>(
      `select user_id from public.group_members where group_id = $1 and role = 'admin'`,
      [seeded.group.id],
    );
    expect(admins.map((x) => x.user_id)).toEqual([users[1].id]);
    expect(await sql(`select 1 from public.groups where id = $1`, [soloGroupId])).toEqual([]);
    expect(await sql(`select 1 from public.groups where id = $1`, [otherGroupId])).toHaveLength(1);
    expect(
      await sql(`select 1 from public.tribute_requests where group_id = $1`, [otherGroupId]),
    ).toEqual([]);
  });

  it('enqueues storage deletion of every prefix and the auth user deletion', async () => {
    const jobs = await sql<{ kind: string; payload: any }>(
      `select kind, payload from public.jobs where id > $1`,
      [firstJobId],
    );
    const prefixes = new Set(jobs.filter((j) => j.kind === 'storage.delete').flatMap((j) => j.payload.prefixes));
    expect(prefixes.has(`u/${doomed.id}/`)).toBe(true);
    expect(prefixes.has(`avatars/${doomed.id}/`)).toBe(true);
    expect(prefixes.has(`g/${soloGroupId}/`)).toBe(true);
    const del = jobs.filter((j) => j.kind === 'auth.delete_user');
    expect(del.map((j) => j.payload.user_id)).toEqual([doomed.id]);
    // nothing is queued for the deleted group except storage deletion
    const forSolo = await sql(
      `select kind from public.jobs where status = 'queued' and kind <> 'storage.delete' and payload ->> 'group_id' = $1`,
      [soloGroupId],
    );
    expect(forSolo).toEqual([]);
  });

  it('the old session can no longer do anything', async () => {
    await expectRpcError(rpc(doomed.client, 'create_group', { p_name: 'x', p_kind: 'friends', p_time_zone: 'UTC' }), 'not_authenticated', 401);
    const { data } = await doomed.client.from('groups').select('*');
    expect(data).toEqual([]);
  });

  it('the worker can then delete the auth user', async () => {
    const { error } = await admin.auth.admin.deleteUser(doomed.id);
    expect(error).toBeNull();
    expect(await sql(`select 1 from auth.users where id = $1`, [doomed.id])).toEqual([]);
  });
});
