// Shared helpers for the integration tests. They run against the local stack
// started with `npm run db:start` (defaults below are the Supabase CLI's local
// development values; override with env vars to point elsewhere).
import { createHmac, randomUUID } from 'node:crypto';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import pg from 'pg';
import { expect } from 'vitest';

export const API_URL = process.env.SUPABASE_URL ?? 'http://127.0.0.1:54321';
export const ANON_KEY =
  process.env.SUPABASE_ANON_KEY ??
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';
export const SERVICE_ROLE_KEY =
  process.env.SUPABASE_SERVICE_ROLE_KEY ??
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';
export const JWT_SECRET = process.env.SUPABASE_JWT_SECRET ?? 'super-secret-jwt-token-with-at-least-32-characters-long';
export const DB_URL = process.env.SUPABASE_DB_URL ?? 'postgresql://postgres:postgres@127.0.0.1:54322/postgres';

const noSession = { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } };

export const admin: SupabaseClient = createClient(API_URL, SERVICE_ROLE_KEY, noSession);
export const anon: SupabaseClient = createClient(API_URL, ANON_KEY, noSession);

let pool: pg.Pool | undefined;
export function db(): pg.Pool {
  pool ??= new pg.Pool({ connectionString: DB_URL, max: 4 });
  return pool;
}
export async function sql<T = any>(text: string, params: unknown[] = []): Promise<T[]> {
  const res = await db().query(text, params);
  return res.rows as T[];
}
export async function closeDb() {
  if (pool) {
    await pool.end();
    pool = undefined;
  }
}

/** HS256 access token for a user, signed with the local JWT secret (like GoTrue's). */
export function mintJwt(sub: string, ttlSeconds = 3600): string {
  const enc = (o: unknown) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const header = enc({ alg: 'HS256', typ: 'JWT' });
  const payload = enc({
    sub,
    role: 'authenticated',
    aud: 'authenticated',
    iss: `${API_URL}/auth/v1`,
    iat: now,
    exp: now + ttlSeconds,
    aal: 'aal1',
    session_id: randomUUID(),
  });
  const sig = createHmac('sha256', JWT_SECRET).update(`${header}.${payload}`).digest('base64url');
  return `${header}.${payload}.${sig}`;
}

export interface TestUser {
  id: string;
  name: string;
  token: string;
  client: SupabaseClient;
}

let phoneCounter = Math.floor(Math.random() * 1_000_000);
function nextPhone(): string {
  phoneCounter = (phoneCounter + 1) % 10_000_000;
  // +1 555 01xx xxxx style test numbers; unique per run
  return `1555${String(Date.now() % 1000).padStart(3, '0')}${String(phoneCounter).padStart(7, '0')}`;
}

/** Creates an auth user with the admin API (phone, confirmed) and a client acting as them. */
export async function createUser(name = 'Test User'): Promise<TestUser> {
  const { data, error } = await admin.auth.admin.createUser({
    phone: nextPhone(),
    phone_confirm: true,
    user_metadata: { display_name: name },
  });
  if (error) throw error;
  const id = data.user!.id;
  const token = mintJwt(id);
  const client = createClient(API_URL, ANON_KEY, {
    ...noSession,
    accessToken: async () => token,
  });
  return { id, name, token, client };
}

export async function createUsers(n: number, prefix = 'User'): Promise<TestUser[]> {
  const out: TestUser[] = [];
  for (let i = 0; i < n; i++) out.push(await createUser(`${prefix}${i} Lastname`));
  return out;
}

export class RpcError extends Error {
  constructor(public code: string, public sqlstate: string, public status: number | undefined, public details?: string) {
    super(`${code} (${sqlstate})`);
  }
}

/** Calls an RPC and returns data, throwing RpcError(message, code) on error. */
export async function rpc<T = any>(client: SupabaseClient, fn: string, args: Record<string, unknown> = {}): Promise<T> {
  const { data, error, status } = await client.rpc(fn, args);
  if (error) throw new RpcError(error.message, error.code ?? '', status, error.details ?? undefined);
  return data as T;
}

/** Asserts the promise rejects with the given error code (message) and optional HTTP status. */
export async function expectRpcError(p: Promise<unknown>, code: string, status?: number) {
  let err: unknown;
  try {
    await p;
  } catch (e) {
    err = e;
  }
  expect(err, `expected error ${code}`).toBeInstanceOf(RpcError);
  expect((err as RpcError).code).toBe(code);
  if (status !== undefined) expect((err as RpcError).status).toBe(status);
  return err as RpcError;
}

export async function select<T = any>(client: SupabaseClient, table: string, filter?: (q: any) => any): Promise<T[]> {
  let q: any = client.from(table).select('*');
  if (filter) q = filter(q);
  const { data, error } = await q;
  if (error) throw new RpcError(error.message, error.code ?? '', undefined);
  return data as T[];
}

export interface TestGroup {
  id: string;
  admin: TestUser;
  members: TestUser[]; // including admin
}

export async function createGroup(
  owner: TestUser,
  members: TestUser[] = [],
  opts: Partial<{ name: string; kind: string; tz: string; start: string; end: string }> = {},
): Promise<TestGroup> {
  const g = await rpc(owner.client, 'create_group', {
    p_name: opts.name ?? 'Test group',
    p_kind: opts.kind ?? 'friends',
    p_time_zone: opts.tz ?? 'Europe/Paris',
    p_waking_start: opts.start ?? null,
    p_waking_end: opts.end ?? null,
  });
  if (members.length) {
    const invite = await rpc(owner.client, 'create_invite', { p_group_id: g.id });
    for (const m of members) await rpc(m.client, 'join_group', { p_token: invite.token });
  }
  return { id: g.id, admin: owner, members: [owner, ...members] };
}

// 1x1 JPEG
export const TINY_JPEG = Buffer.from(
  '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAA//EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AN//Z',
  'base64',
);

export async function upload(user: TestUser, path: string, contentType = 'image/jpeg', body: Buffer = TINY_JPEG) {
  const { error } = await user.client.storage.from('media').upload(path, body, { contentType, upsert: false });
  if (error) throw error;
  return path;
}

export interface TestMedia {
  id: string;
  originalPath: string;
  frontPath?: string;
}

/** Uploads an original (and optional front image) and inserts the media row. */
export async function createMedia(
  user: TestUser,
  opts: Partial<{ kind: 'photo' | 'live_photo' | 'video'; dual: boolean; skipUpload: boolean }> = {},
): Promise<TestMedia> {
  const id = randomUUID();
  const kind = opts.kind ?? 'photo';
  const originalPath = `u/${user.id}/${id}/original.${kind === 'video' ? 'mp4' : 'jpg'}`;
  const frontPath = opts.dual ? `u/${user.id}/${id}/front.jpg` : undefined;
  const motionPath = kind === 'live_photo' ? `u/${user.id}/${id}/motion.mov` : undefined;
  if (!opts.skipUpload) {
    await upload(user, originalPath, kind === 'video' ? 'video/mp4' : 'image/jpeg');
    if (frontPath) await upload(user, frontPath);
    if (motionPath) await upload(user, motionPath, 'video/quicktime');
  }
  const { error } = await user.client.from('media').insert({
    id,
    kind,
    original_path: originalPath,
    front_original_path: frontPath ?? null,
    motion_path: motionPath ?? null,
    width: 1,
    height: 1,
    duration_ms: kind === 'photo' ? null : 1500,
  });
  if (error) throw new RpcError(error.message, error.code ?? '', undefined);
  return { id, originalPath, frontPath };
}

/** Uploads + posts a photo to the given groups; returns the created posts. */
export async function postPhoto(user: TestUser, groupIds: string[], extra: Record<string, unknown> = {}) {
  const media = await createMedia(user);
  const posts = await rpc<any[]>(user.client, 'create_post', { p_media_id: media.id, p_group_ids: groupIds, ...extra });
  return { media, posts };
}

export async function jobsWhere(kind: string, payloadMatch: Record<string, unknown>) {
  return sql<any>(`select * from public.jobs where kind = $1 and payload @> $2::jsonb order by id`, [
    kind,
    JSON.stringify(payloadMatch),
  ]);
}

export async function setConfig(key: string, value: unknown) {
  await sql(`update public.app_config set value = $2::jsonb where key = $1`, [
    key,
    value === null ? null : JSON.stringify(value),
  ]);
}

export async function getConfig(key: string) {
  const rows = await sql<{ value: unknown }>(`select value from public.app_config where key = $1`, [key]);
  return rows[0]?.value ?? null;
}

export async function grantPremium(userId: string, expiresAt: string | null = null) {
  const { error } = await admin
    .from('entitlements')
    .upsert({ user_id: userId, entitlement: 'premium', expires_at: expiresAt, source: 'test' });
  if (error) throw error;
}

export function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

export async function waitFor(pred: () => boolean | Promise<boolean>, timeoutMs = 10_000, stepMs = 100) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (await pred()) return true;
    await sleep(stepMs);
  }
  return false;
}

/** Waits until Realtime has registered `count` postgres_changes subscriptions for the user. */
export async function waitForRealtimeSubscriptions(userId: string, count: number, timeoutMs = 15_000) {
  const ok = await waitFor(async () => {
    const rows = await sql<{ n: number }>(
      `select count(*)::int as n from realtime.subscription where claims ->> 'sub' = $1`,
      [userId],
    );
    return rows[0].n >= count;
  }, timeoutMs, 200);
  if (!ok) throw new Error(`realtime subscriptions for ${userId} not active`);
  await sleep(500);
}
