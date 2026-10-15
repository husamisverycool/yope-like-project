// Tenet: no counts. Reactions reach clients as rows (user, emoji) only; no view,
// RPC or REST aggregate exposes a number of reactions (or of anything else).
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { closeDb, createGroup, createUsers, postPhoto, rpc, sql, type TestUser } from '../helpers';

let a: TestUser, b: TestUser;
let postId: string;

beforeAll(async () => {
  [a, b] = await createUsers(2, 'Cnt');
  const g = await createGroup(a, [b]);
  postId = (await postPhoto(a, [g.id])).posts[0].id;
  await rpc(b.client, 'react', { p_post_id: postId, p_emoji: '❤️' });
  await rpc(b.client, 'react', { p_post_id: postId, p_emoji: '🔥' });
});

afterAll(closeDb);

const COUNTISH = /count|total|tally|score|num_|_num|likes|streak/i;

describe('no counts anywhere in the API', () => {
  it('no client-visible table or view column looks like a count', async () => {
    const cols = await sql<{ table_name: string; column_name: string }>(
      `select c.table_name, c.column_name from information_schema.columns c
        where c.table_schema = 'public'
          and has_table_privilege('authenticated', format('%I.%I', c.table_schema, c.table_name), 'SELECT')`,
    );
    expect(cols.length).toBeGreaterThan(50);
    expect(cols.filter((c) => COUNTISH.test(c.column_name))).toEqual([]);
  });

  it('no client-callable RPC returns a count-like column or a number', async () => {
    const fns = await sql<{ proname: string; result: string; outs: string[] | null; ret: string }>(
      `select p.proname, pg_get_function_result(p.oid) as result,
              (select array_agg(n) from unnest(p.proargnames, p.proargmodes) as t(n, m) where m in ('o', 't')) as outs,
              p.prorettype::regtype::text as ret
         from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
        where ns.nspname = 'public' and has_function_privilege('authenticated', p.oid, 'EXECUTE')`,
    );
    expect(fns.length).toBeGreaterThan(30);
    for (const f of fns) {
      expect(COUNTISH.test(f.result), `${f.proname}: ${f.result}`).toBe(false);
      for (const o of f.outs ?? []) expect(COUNTISH.test(o), `${f.proname}.${o}`).toBe(false);
      expect(['integer', 'bigint', 'numeric', 'smallint'], `${f.proname} returns a bare number`).not.toContain(f.ret);
    }
  });

  it('no client-callable RPC aggregates reactions', async () => {
    const rows = await sql<{ proname: string }>(
      `select p.proname from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
        where ns.nspname = 'public' and has_function_privilege('authenticated', p.oid, 'EXECUTE')
          and p.prosrc ~* 'reactions' and p.prosrc ~* '(count|sum|avg)\\s*\\('`,
    );
    expect(rows).toEqual([]);
  });

  it('PostgREST aggregate functions are disabled', async () => {
    const r1 = await b.client.from('reactions').select('count()');
    expect(r1.error).not.toBeNull();
    const r2 = await b.client.from('reactions').select('emoji, count()').eq('post_id', postId);
    expect(r2.error).not.toBeNull();
    const r3 = await b.client.from('reactions').select('post_id, emoji.count()');
    expect(r3.error).not.toBeNull();
  });

  it('reactions are returned as (user, emoji) rows', async () => {
    const { data, error } = await a.client.from('reactions').select('user_id, emoji').eq('post_id', postId);
    expect(error).toBeNull();
    expect(data).toEqual(
      expect.arrayContaining([
        { user_id: b.id, emoji: '❤️' },
        { user_id: b.id, emoji: '🔥' },
      ]),
    );
    const row = await rpc(b.client, 'react', { p_post_id: postId, p_emoji: '❤️' });
    expect(Object.keys(row).sort()).toEqual(['created_at', 'emoji', 'group_id', 'post_id', 'user_id']);
  });
});
