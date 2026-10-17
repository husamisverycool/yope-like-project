// Test data in the local Supabase stack, created with the service role (admin API, PostgREST,
// Storage). Defaults are the Supabase CLI's fixed local values (backend/tests/helpers.ts).

import { createHmac, randomUUID } from "node:crypto";
import sharp from "sharp";

export const SUPABASE_URL = process.env.SUPABASE_URL ?? "http://127.0.0.1:54321";
export const ANON_KEY =
  process.env.SUPABASE_ANON_KEY ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0";
export const SERVICE_ROLE_KEY =
  process.env.SUPABASE_SERVICE_ROLE_KEY ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU";

export const JWT_SECRET = process.env.SUPABASE_JWT_SECRET ?? "super-secret-jwt-token-with-at-least-32-characters-long";

const admin = { apikey: SERVICE_ROLE_KEY, Authorization: `Bearer ${SERVICE_ROLE_KEY}` };

/** HS256 access token for a user, signed with the local JWT secret (as backend/tests/helpers.ts). */
export function userJwt(sub: string): string {
  const enc = (o: unknown) => Buffer.from(JSON.stringify(o)).toString("base64url");
  const now = Math.floor(Date.now() / 1000);
  const header = enc({ alg: "HS256", typ: "JWT" });
  const payload = enc({ sub, role: "authenticated", aud: "authenticated", iss: `${SUPABASE_URL}/auth/v1`, iat: now, exp: now + 3600, aal: "aal1", session_id: randomUUID() });
  const sig = createHmac("sha256", JWT_SECRET).update(`${header}.${payload}`).digest("base64url");
  return `${header}.${payload}.${sig}`;
}
const asUser = (id: string) => ({ apikey: ANON_KEY, Authorization: `Bearer ${userJwt(id)}` });

async function req(method: string, path: string, body?: unknown, headers: Record<string, string> = {}, auth: Record<string, string> = admin): Promise<any> {
  const res = await fetch(`${SUPABASE_URL}${path}`, {
    method,
    headers: { ...auth, ...(body !== undefined && !(body instanceof Blob) ? { "Content-Type": "application/json" } : {}), ...headers },
    body: body === undefined ? undefined : body instanceof Blob ? body : JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${path}: HTTP ${res.status} ${text}`);
  return text ? JSON.parse(text) : null;
}

/** True when the local stack answers. */
export async function stackAvailable(): Promise<boolean> {
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/invite_preview`, {
      method: "POST",
      headers: { apikey: ANON_KEY, Authorization: `Bearer ${ANON_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ p_token: "x".repeat(24) }),
      signal: AbortSignal.timeout(3000),
    });
    return res.status === 404;
  } catch {
    return false;
  }
}

let phone = Math.floor(Math.random() * 1_000_000);
export async function createUser(displayName: string): Promise<string> {
  phone = (phone + 1) % 10_000_000;
  const u = await req("POST", "/auth/v1/admin/users", {
    phone: `1555${String(Date.now() % 1000).padStart(3, "0")}${String(phone).padStart(7, "0")}`,
    phone_confirm: true,
    user_metadata: { display_name: displayName },
  });
  // past the age gate: create_group / join_group / create_post require it (backend migration 0055)
  await req("PATCH", `/rest/v1/profile_private?user_id=eq.${u.id}`, { age_confirmed_at: new Date().toISOString() }, { Prefer: "return=minimal" });
  return u.id as string;
}

export async function deleteUser(id: string) {
  await req("DELETE", `/auth/v1/admin/users/${id}`).catch(() => {});
}

export async function upload(path: string, bytes: Buffer, contentType = "image/jpeg") {
  await req("POST", `/storage/v1/object/media/${path}`, new Blob([Uint8Array.from(bytes)]), { "Content-Type": contentType, "x-upsert": "false" });
}

export async function removeObjects(paths: string[]) {
  if (paths.length) await req("DELETE", "/storage/v1/object/media", { prefixes: paths }).catch(() => {});
}

/** The user sets their own avatar (a direct write the API allows, docs/API.md §5.0). */
export async function setAvatar(userId: string, path: string) {
  await req("PATCH", `/rest/v1/profiles?id=eq.${userId}`, { avatar_path: path }, { Prefer: "return=minimal" }, asUser(userId));
}

/** create_group as the creator (RPC; the creator becomes admin). */
export async function createGroup(opts: { name: string; kind?: string; coverPath?: string | null; createdBy: string }): Promise<string> {
  const g = await req("POST", "/rest/v1/rpc/create_group", { p_name: opts.name, p_kind: opts.kind ?? "family", p_time_zone: "Europe/Paris", p_cover_path: opts.coverPath ?? null }, {}, asUser(opts.createdBy));
  return g.id as string;
}

/** create_invite as a member. */
export async function createInvite(groupId: string, createdBy: string): Promise<string> {
  const inv = await req("POST", "/rest/v1/rpc/create_invite", { p_group_id: groupId }, {}, asUser(createdBy));
  return inv.token as string;
}

export async function joinGroup(token: string, userId: string) {
  await req("POST", "/rest/v1/rpc/join_group", { p_token: token }, {}, asUser(userId));
}

/** Service role: the invite's expires_at (null = never expires, owner decision 27). */
export async function inviteExpiry(token: string): Promise<string | null> {
  const rows = await req("GET", `/rest/v1/group_invites?token=eq.${token}&select=expires_at`);
  return (rows as Array<{ expires_at: string | null }>)[0]!.expires_at;
}

/** Service role: give an invite an expiry in the past (links have none unless invite_ttl_seconds is set). */
export async function expireInvite(token: string) {
  await req("PATCH", `/rest/v1/group_invites?token=eq.${token}`, { expires_at: new Date(Date.now() - 60_000).toISOString() }, { Prefer: "return=minimal" });
}

/** revoke_invite as its creator. */
export async function revokeInvite(token: string, creator: string) {
  await req("POST", "/rest/v1/rpc/revoke_invite", { p_token: token }, {}, asUser(creator));
}

export async function deleteGroup(id: string) {
  await req("DELETE", `/rest/v1/groups?id=eq.${id}`).catch(() => {});
}

/** Marker text written into test images' EXIF; it must never appear in served images. */
export const EXIF_MARKER = "secret-exif-marker";

/** A JPEG with a two-colour pattern and EXIF metadata. */
export async function testJpeg(width: number, height: number, top: [number, number, number], bottom: [number, number, number]): Promise<Buffer> {
  const half = Math.round(height / 2);
  const a = await sharp({ create: { width, height: half, channels: 3, background: { r: top[0], g: top[1], b: top[2] } } }).png().toBuffer();
  const b = await sharp({ create: { width, height: height - half, channels: 3, background: { r: bottom[0], g: bottom[1], b: bottom[2] } } }).png().toBuffer();
  return sharp({ create: { width, height, channels: 3, background: { r: 0, g: 0, b: 0 } } })
    .composite([
      { input: a, top: 0, left: 0 },
      { input: b, top: half, left: 0 },
    ])
    .withExif({ IFD0: { ImageDescription: EXIF_MARKER, Copyright: EXIF_MARKER } })
    .jpeg()
    .toBuffer();
}

export interface SeededGroup {
  groupId: string;
  token: string;
  users: string[];
  paths: string[];
  memberIds: { ana: string; rui: string; anon: string };
}

/**
 * Group "Lima family" with a cover, inviter Ana (avatar), Rui (no avatar), and a member with an
 * empty display name. Returns a valid invite token.
 */
export async function seedGroup(opts: { name?: string; cover?: Buffer | null } = {}): Promise<SeededGroup> {
  const ana = await createUser("Ana Lima");
  const rui = await createUser("Rui Costa");
  const anon = await createUser("");
  const avatarPath = `avatars/${ana}/${randomUUID()}.jpg`;
  await upload(avatarPath, await testJpeg(400, 400, [200, 120, 90], [40, 60, 90]));
  await setAvatar(ana, avatarPath);
  const paths = [avatarPath];
  let coverPath: string | null = null;
  const cover = opts.cover === undefined ? await testJpeg(1200, 900, [167, 200, 255], [251, 235, 228]) : opts.cover;
  if (cover) {
    coverPath = `u/${ana}/covers/${randomUUID()}.jpg`;
    await upload(coverPath, cover);
    paths.push(coverPath);
  }
  const groupId = await createGroup({ name: opts.name ?? "Lima family", coverPath, createdBy: ana });
  const token = await createInvite(groupId, ana);
  await joinGroup(token, rui);
  await joinGroup(token, anon);
  return { groupId, token, users: [ana, rui, anon], paths, memberIds: { ana, rui, anon } };
}

export async function cleanup(g: SeededGroup) {
  await deleteGroup(g.groupId);
  await removeObjects(g.paths);
  for (const u of g.users) await deleteUser(u);
}
