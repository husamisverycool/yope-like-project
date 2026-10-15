// Supabase access with the service role (PostgREST, Storage, Auth admin). RLS is bypassed:
// every query below filters explicitly by group / user.

import { createClient, type SupabaseClient } from "@supabase/supabase-js";

export type Db = SupabaseClient;

export function createDb(url: string, serviceRoleKey: string): Db {
  return createClient(url, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    db: { schema: "public" },
  });
}

export class DbError extends Error {
  override name = "DbError";
  constructor(
    message: string,
    public readonly code: string | undefined,
    public readonly details?: string | null,
  ) {
    super(code ? `${message} (${code})` : message);
  }
}

interface PgResult<T> {
  data: T | null;
  error: { message: string; code?: string; details?: string | null } | null;
}

/** Unwraps a PostgREST result; throws DbError on error. */
export function must<T>(res: PgResult<T>, what: string): T {
  if (res.error) throw new DbError(`${what}: ${res.error.message}`, res.error.code, res.error.details);
  return res.data as T;
}

/** Unwraps a result whose data may be null (maybeSingle). */
export function maybe<T>(res: PgResult<T>, what: string): T | null {
  if (res.error) throw new DbError(`${what}: ${res.error.message}`, res.error.code, res.error.details);
  return res.data ?? null;
}

export async function rpc<T>(db: Db, fn: string, args: Record<string, unknown> = {}): Promise<T> {
  const res = await db.rpc(fn, args);
  return must(res as PgResult<T>, `rpc ${fn}`);
}

/** Splits a list for `in (...)` filters so URLs stay short. */
export function chunks<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

/** select ... where column in (ids), in chunks. */
export async function selectIn<T>(db: Db, table: string, columns: string, column: string, ids: string[]): Promise<T[]> {
  const out: T[] = [];
  for (const part of chunks([...new Set(ids)], 100)) {
    if (!part.length) continue;
    out.push(...must(await db.from(table).select(columns).in(column, part), `select ${table}`) as T[]);
  }
  return out;
}
