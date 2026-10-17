// Local Supabase stack access for tests (same defaults as backend/tests/helpers.ts: the Supabase
// CLI's local development values; override with env vars).

import { createHmac, randomUUID } from "node:crypto";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import pg from "pg";
import sharp from "sharp";

export const API_URL = process.env.SUPABASE_URL ?? "http://127.0.0.1:54321";
export const ANON_KEY =
  process.env.SUPABASE_ANON_KEY ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0";
export const SERVICE_ROLE_KEY =
  process.env.SUPABASE_SERVICE_ROLE_KEY ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU";
export const JWT_SECRET = process.env.SUPABASE_JWT_SECRET ?? "super-secret-jwt-token-with-at-least-32-characters-long";
export const DB_URL = process.env.SUPABASE_DB_URL ?? "postgresql://postgres:postgres@127.0.0.1:54322/postgres";

const noSession = { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } };
export const admin: SupabaseClient = createClient(API_URL, SERVICE_ROLE_KEY, noSession);

let pool: pg.Pool | undefined;
export async function sql<T = any>(text: string, params: unknown[] = []): Promise<T[]> {
  pool ??= new pg.Pool({ connectionString: DB_URL, max: 4 });
  return (await pool.query(text, params)).rows as T[];
}
export async function closeDb(): Promise<void> {
  await pool?.end();
  pool = undefined;
}

export function mintJwt(sub: string, ttlSeconds = 3600): string {
  const enc = (o: unknown) => Buffer.from(JSON.stringify(o)).toString("base64url");
  const now = Math.floor(Date.now() / 1000);
  const header = enc({ alg: "HS256", typ: "JWT" });
  const payload = enc({ sub, role: "authenticated", aud: "authenticated", iss: `${API_URL}/auth/v1`, iat: now, exp: now + ttlSeconds, aal: "aal1", session_id: randomUUID() });
  const sig = createHmac("sha256", JWT_SECRET).update(`${header}.${payload}`).digest("base64url");
  return `${header}.${payload}.${sig}`;
}

/**
 * The local stack is shared with other agents' test suites: everything a worker test touches is
 * tracked here, test runners only claim jobs that belong to these ids (scopedClaim), and
 * cleanup deletes the accounts again through delete_account.
 */
export const tracked = { users: [] as TestUser[], groups: new Set<string>() };

export function trackedIds(): string[] {
  return [...tracked.users.map((u) => u.id), ...tracked.groups];
}

/** claim_jobs semantics (FOR UPDATE SKIP LOCKED, attempts + 1), limited to this test file's own data. */
export function scopedClaim(workerId: string) {
  return async (kinds: string[], limit: number): Promise<any[]> => {
    const ids = trackedIds();
    if (!ids.length) return [];
    const rows = await sql(
      `with c as (
         select j.id from public.jobs j
          where j.status = 'queued' and j.run_at <= now() and j.kind = any($2::text[])
            and (exists (select 1 from unnest($4::text[]) as t(id) where strpos(j.payload::text, t.id) > 0)
                 or exists (select 1 from public.media m where m.id::text = j.payload ->> 'media_id' and m.owner_id::text = any($4::text[]))
                 or exists (select 1 from public.reports r where r.id::text = j.payload ->> 'report_id' and r.reporter_id::text = any($4::text[])))
          order by j.run_at, j.id
          limit $3
          for update skip locked)
       update public.jobs j set status = 'running', locked_at = now(), locked_by = $1, attempts = j.attempts + 1
         from c where j.id = c.id
       returning j.*`,
      [workerId, kinds, limit, ids],
    );
    return rows.map((r) => ({ ...r, id: Number(r.id), run_at: new Date(r.run_at).toISOString() }));
  };
}

/** Cancels this file's own leftover queued jobs (never anyone else's). */
export async function cancelOwnQueuedJobs(): Promise<void> {
  const ids = trackedIds();
  if (!ids.length) return;
  await sql(
    `update public.jobs j set status = 'cancelled', finished_at = now(), last_error = 'worker test cleanup'
      where j.status = 'queued' and exists (select 1 from unnest($1::text[]) as t(id) where strpos(j.payload::text, t.id) > 0)`,
    [ids],
  );
}

export interface TestUser {
  id: string;
  name: string;
  client: SupabaseClient;
}

let phoneCounter = Math.floor(Math.random() * 1_000_000);
function nextPhone(): string {
  phoneCounter = (phoneCounter + 1) % 10_000_000;
  return `1556${String(Date.now() % 1000).padStart(3, "0")}${String(phoneCounter).padStart(7, "0")}`;
}

export async function createUser(name = "Test User"): Promise<TestUser> {
  const { data, error } = await admin.auth.admin.createUser({ phone: nextPhone(), phone_confirm: true, user_metadata: { display_name: name } });
  if (error) throw error;
  const id = data.user!.id;
  // past the age gate (create_group / join_group / create_post require it, migration 0055)
  await sql(`update public.profile_private set age_confirmed_at = now() where user_id = $1`, [id]);
  const token = mintJwt(id);
  const client = createClient(API_URL, ANON_KEY, { ...noSession, accessToken: async () => token });
  const user = { id, name, client };
  tracked.users.push(user);
  return user;
}

export async function createUsers(n: number, prefix = "Member"): Promise<TestUser[]> {
  return Promise.all(Array.from({ length: n }, (_, i) => createUser(`${prefix}${i} Lastname`)));
}

export async function rpc<T = any>(client: SupabaseClient, fn: string, args: Record<string, unknown> = {}): Promise<T> {
  const { data, error } = await client.rpc(fn, args);
  if (error) throw new Error(`${fn}: ${error.message} (${error.code})`);
  return data as T;
}

export interface TestGroup {
  id: string;
  name: string;
  members: TestUser[];
}

export async function createGroup(owner: TestUser, members: TestUser[] = [], opts: Partial<{ name: string; tz: string; start: string; end: string }> = {}): Promise<TestGroup> {
  const name = opts.name ?? `Group ${randomUUID().slice(0, 6)}`;
  const g = await rpc(owner.client, "create_group", {
    p_name: name,
    p_kind: "friends",
    p_time_zone: opts.tz ?? "Europe/Paris",
    p_waking_start: opts.start ?? null,
    p_waking_end: opts.end ?? null,
  });
  tracked.groups.add(g.id);
  if (members.length) {
    const invite = await rpc(owner.client, "create_invite", { p_group_id: g.id });
    for (const m of members) await rpc(m.client, "join_group", { p_token: invite.token });
  }
  return { id: g.id, name, members: [owner, ...members] };
}

/** A real JPEG (distinct per seed) so renditions and collages have something to work on. */
export async function testJpeg(seed: number, opts: { width?: number; height?: number; gps?: boolean } = {}): Promise<Buffer> {
  const w = opts.width ?? 600;
  const h = opts.height ?? 800;
  const hue = (seed * 47) % 360;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><rect width="100%" height="100%" fill="hsl(${hue},70%,50%)"/><circle cx="${(seed * 97) % w}" cy="${(seed * 61) % h}" r="${Math.min(w, h) / 4}" fill="hsl(${(hue + 180) % 360},70%,40%)"/></svg>`;
  let img = sharp(Buffer.from(svg)).jpeg({ quality: 90 });
  if (opts.gps) {
    img = img.withExif({ IFD0: { Make: "TestCam", Orientation: "1" }, IFD3: { GPSLatitudeRef: "N", GPSLatitude: "48/1 51/1 24/1", GPSLongitudeRef: "E", GPSLongitude: "2/1 21/1 3/1" } });
  }
  return img.toBuffer();
}

export async function uploadAs(user: TestUser, path: string, body: Buffer, contentType = "image/jpeg"): Promise<string> {
  const { error } = await user.client.storage.from("media").upload(path, body, { contentType, upsert: false });
  if (error) throw error;
  return path;
}

export interface TestMedia {
  id: string;
  originalPath: string;
}

export async function createMedia(user: TestUser, opts: Partial<{ kind: "photo" | "live_photo" | "video"; dual: boolean; seed: number; gps: boolean; body: Buffer; motion: Buffer }> = {}): Promise<TestMedia> {
  const id = randomUUID();
  const kind = opts.kind ?? "photo";
  const ext = kind === "video" ? "mp4" : "jpg";
  const originalPath = `u/${user.id}/${id}/original.${ext}`;
  const seed = opts.seed ?? Math.floor(Math.random() * 1000);
  const body = opts.body ?? (await testJpeg(seed, { gps: opts.gps }));
  await uploadAs(user, originalPath, body, kind === "video" ? "video/mp4" : "image/jpeg");
  let frontPath: string | null = null;
  if (opts.dual) frontPath = await uploadAs(user, `u/${user.id}/${id}/front.jpg`, await testJpeg(seed + 500, { width: 300, height: 400 }));
  let motionPath: string | null = null;
  if (kind === "live_photo") motionPath = await uploadAs(user, `u/${user.id}/${id}/motion.mov`, opts.motion ?? Buffer.from("not-a-movie"), "video/quicktime");
  const { error } = await user.client.from("media").insert({
    id,
    kind,
    original_path: originalPath,
    front_original_path: frontPath,
    motion_path: motionPath,
    width: 600,
    height: 800,
    duration_ms: kind === "photo" ? null : 1500,
  });
  if (error) throw new Error(error.message);
  return { id, originalPath };
}

export async function postPhoto(user: TestUser, groupIds: string[], extra: Record<string, unknown> = {}, mediaOpts: Parameters<typeof createMedia>[1] = {}) {
  const media = await createMedia(user, mediaOpts);
  const posts = await rpc<any[]>(user.client, "create_post", { p_media_id: media.id, p_group_ids: groupIds, ...extra });
  return { media, posts, post: posts[0] };
}

let tokenCounter = 0;
export async function registerDevice(user: TestUser, platform: "ios" | "android", opts: Partial<{ token: string; pushToStart: string | null; liveActivities: boolean | null }> = {}) {
  tokenCounter++;
  const token = opts.token ?? (platform === "ios" ? `a${String(tokenCounter).padStart(7, "0")}${randomUUID().replace(/-/g, "")}` : `fcm-${tokenCounter}-${randomUUID()}`);
  return rpc(user.client, "register_device", {
    p_platform: platform,
    p_push_token: token,
    p_push_to_start_token: platform === "ios" ? opts.pushToStart ?? null : null,
    p_live_activities_enabled: platform === "ios" ? opts.liveActivities ?? null : null,
  });
}

export async function setConfig(key: string, value: unknown): Promise<void> {
  await sql(`update public.app_config set value = $2::jsonb where key = $1`, [key, value === null ? null : JSON.stringify(value)]);
}

export async function getConfig(key: string): Promise<unknown> {
  const rows = await sql<{ value: unknown }>(`select value from public.app_config where key = $1`, [key]);
  return rows[0]?.value ?? null;
}

export async function jobs(kind: string, match: Record<string, unknown> = {}): Promise<any[]> {
  return sql(`select * from public.jobs where kind = $1 and payload @> $2::jsonb order by id`, [kind, JSON.stringify(match)]);
}

export async function objectExists(path: string): Promise<boolean> {
  const rows = await sql(`select 1 from storage.objects where bucket_id = 'media' and name = $1`, [path]);
  return rows.length > 0;
}

export async function objectsUnder(prefix: string): Promise<string[]> {
  const rows = await sql<{ name: string }>(`select name from storage.objects where bucket_id = 'media' and name like $1 order by name`, [`${prefix}%`]);
  return rows.map((r) => r.name);
}

export function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

export async function waitFor(pred: () => boolean | Promise<boolean>, timeoutMs = 20_000, stepMs = 100): Promise<boolean> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (await pred()) return true;
    await sleep(stepMs);
  }
  return false;
}
