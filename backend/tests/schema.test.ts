// Catalog-level guarantees: every function is hardened, grants are explicit,
// anon can reach nothing but invite_preview and the public config view.
import { afterAll, describe, expect, it } from 'vitest';
import { closeDb, sql } from './helpers';

afterAll(closeDb);

describe('schema hardening', () => {
  it('every function in public and private pins search_path to empty', async () => {
    const rows = await sql<{ fn: string }>(
      `select n.nspname || '.' || p.proname as fn
         from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname in ('public', 'private')
          and not coalesce(p.proconfig @> array['search_path=""'], false)`,
    );
    expect(rows.map((r) => r.fn)).toEqual([]);
  });

  it('every client RPC is SECURITY DEFINER', async () => {
    const rows = await sql<{ proname: string }>(
      `select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and has_function_privilege('authenticated', p.oid, 'EXECUTE') and not p.prosecdef`,
    );
    expect(rows).toEqual([]);
  });

  it('anon can execute only invite_preview', async () => {
    const rows = await sql<{ proname: string }>(
      `select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'public' and has_function_privilege('anon', p.oid, 'EXECUTE')`,
    );
    expect(rows.map((r) => r.proname)).toEqual(['invite_preview']);
  });

  it('anon has no table privileges except the public config view', async () => {
    const rows = await sql<{ table_name: string; privilege_type: string }>(
      `select table_name, privilege_type from information_schema.role_table_grants
        where table_schema = 'public' and grantee = 'anon'`,
    );
    expect(rows).toEqual([{ table_name: 'public_app_config', privilege_type: 'SELECT' }]);
  });

  it('clients have no INSERT/UPDATE/DELETE beyond the documented ones', async () => {
    const rows = await sql<{ t: string; p: string }>(
      `select table_name as t, privilege_type as p from information_schema.role_table_grants
        where table_schema = 'public' and grantee = 'authenticated' and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
       union
       select distinct table_name, privilege_type from information_schema.column_privileges
        where table_schema = 'public' and grantee = 'authenticated' and privilege_type in ('INSERT', 'UPDATE')
       order by 1, 2`,
    );
    expect(rows.map((r) => `${r.t}:${r.p}`)).toEqual([
      'devices:DELETE',
      'media:INSERT',
      'post_tags:DELETE',
      'post_tags:INSERT',
      'profiles:UPDATE',
      'reports:INSERT',
      'tribute_contributions:DELETE',
    ]);
  });

  it('the media bucket exists and is private', async () => {
    const rows = await sql(`select id, public from storage.buckets`);
    expect(rows).toContainEqual({ id: 'media', public: false });
  });
});
