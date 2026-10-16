// Supabase calls made by the invite page (docs/API.md):
//   invite_preview(p_token)  — anon key; the only data a non-member may see.
//   storage sign (media)     — service role; signs exactly the cover/avatar paths the preview
//                              returned, with a short expiry. Nothing else uses the service role.
// Responses are validated and reduced to the documented preview fields, so a field added to the
// RPC later can never reach the page without a change here.

export interface PreviewMember {
  first_name: string | null;
  avatar_path: string | null;
}

export interface InvitePreview {
  group_name: string;
  group_kind: string;
  cover_path: string | null;
  inviter_first_name: string | null;
  /** Avatar of the invite's creator while they are a member (migration 0016); null otherwise or from an older RPC. */
  inviter_avatar_path: string | null;
  members: PreviewMember[];
}

export type PreviewLookup =
  | { status: "ok"; preview: InvitePreview }
  | { status: "not_found" }
  | { status: "unavailable"; reason: "expired" | "revoked" };

/** Supabase unreachable, timed out, or answered with something unexpected. */
export class UpstreamError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "UpstreamError";
  }
}

export interface Upstream {
  invitePreview(token: string): Promise<PreviewLookup>;
  /** Signs storage paths; returns path → absolute URL for the ones that could be signed. */
  signPaths(paths: string[], expiresInSeconds: number): Promise<Map<string, string>>;
  /** Downloads a signed object (bounded size). */
  fetchObject(url: string): Promise<Buffer>;
}

const UUID = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}";
const SEG = "[A-Za-z0-9_.-]+";
/** Covers live under the uploader's prefix (docs/API.md §7), avatars under avatars/<uid>/. */
export const COVER_PATH = new RegExp(`^u/${UUID}/(?:${SEG}/)*${SEG}$`);
export const AVATAR_PATH = new RegExp(`^avatars/${UUID}/(?:${SEG}/)*${SEG}$`);
const safe = (p: string) => !p.split("/").some((s) => s === "." || s === "..");

/** Largest object this service will download (covers are photos; the bucket allows 100 MiB). */
export const MAX_OBJECT_BYTES = 25 * 1024 * 1024;

const nullableString = (v: unknown): string | null => (typeof v === "string" ? v : v === null || v === undefined ? null : invalid());
function invalid(): never {
  throw new UpstreamError("invite_preview returned an unexpected shape");
}

/** Validates the RPC result and keeps only the documented fields. */
export function parsePreview(body: unknown): InvitePreview {
  if (typeof body !== "object" || body === null || Array.isArray(body)) invalid();
  const b = body as Record<string, unknown>;
  if (typeof b.group_name !== "string" || typeof b.group_kind !== "string" || !Array.isArray(b.members)) invalid();
  const cover = nullableString(b.cover_path);
  const inviterAvatar = nullableString(b.inviter_avatar_path);
  return {
    group_name: b.group_name,
    group_kind: b.group_kind,
    cover_path: cover !== null && COVER_PATH.test(cover) && safe(cover) ? cover : null,
    inviter_first_name: nullableString(b.inviter_first_name),
    inviter_avatar_path: inviterAvatar !== null && AVATAR_PATH.test(inviterAvatar) && safe(inviterAvatar) ? inviterAvatar : null,
    members: b.members.map((m: unknown) => {
      if (typeof m !== "object" || m === null) invalid();
      const r = m as Record<string, unknown>;
      const avatar = nullableString(r.avatar_path);
      return {
        first_name: nullableString(r.first_name),
        avatar_path: avatar !== null && AVATAR_PATH.test(avatar) && safe(avatar) ? avatar : null,
      };
    }),
  };
}

export function supabaseUpstream(opts: { url: string; anonKey: string; serviceRoleKey: string; timeoutMs: number }): Upstream {
  const { url, anonKey, serviceRoleKey, timeoutMs } = opts;

  async function call(input: string, init: RequestInit): Promise<Response> {
    try {
      return await fetch(input, { ...init, redirect: "error", signal: AbortSignal.timeout(timeoutMs) });
    } catch (e) {
      throw new UpstreamError(`request failed: ${(e as Error).name}`);
    }
  }

  return {
    async invitePreview(token) {
      const res = await call(`${url}/rest/v1/rpc/invite_preview`, {
        method: "POST",
        headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}`, "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({ p_token: token }),
      });
      let body: unknown;
      try {
        body = await res.json();
      } catch {
        throw new UpstreamError(`invite_preview: HTTP ${res.status}, body is not JSON`);
      }
      if (res.ok) return { status: "ok", preview: parsePreview(body) };
      const message = typeof body === "object" && body !== null ? (body as Record<string, unknown>).message : undefined;
      if (res.status === 404 && message === "invite_not_found") return { status: "not_found" };
      if (res.status === 410 && message === "invite_expired") return { status: "unavailable", reason: "expired" };
      if (res.status === 410 && message === "invite_revoked") return { status: "unavailable", reason: "revoked" };
      throw new UpstreamError(`invite_preview: HTTP ${res.status}`);
    },

    async signPaths(paths, expiresInSeconds) {
      const out = new Map<string, string>();
      const unique = [...new Set(paths)].filter((p) => (COVER_PATH.test(p) || AVATAR_PATH.test(p)) && safe(p));
      if (unique.length === 0) return out;
      const res = await call(`${url}/storage/v1/object/sign/media`, {
        method: "POST",
        headers: { apikey: serviceRoleKey, Authorization: `Bearer ${serviceRoleKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({ expiresIn: expiresInSeconds, paths: unique }),
      });
      if (!res.ok) throw new UpstreamError(`storage sign: HTTP ${res.status}`);
      const body = (await res.json().catch(() => null)) as unknown;
      if (!Array.isArray(body)) throw new UpstreamError("storage sign: unexpected body");
      for (const item of body) {
        const r = item as Record<string, unknown>;
        if (typeof r.path === "string" && typeof r.signedURL === "string" && !r.error && unique.includes(r.path)) {
          out.set(r.path, `${url}/storage/v1${r.signedURL.startsWith("/") ? "" : "/"}${r.signedURL}`);
        }
      }
      return out;
    },

    async fetchObject(objectUrl) {
      const res = await call(objectUrl, { method: "GET" });
      if (!res.ok) throw new UpstreamError(`object: HTTP ${res.status}`);
      const declared = Number(res.headers.get("content-length") ?? "0");
      if (declared > MAX_OBJECT_BYTES) throw new UpstreamError("object too large");
      const buf = Buffer.from(await res.arrayBuffer());
      if (buf.length > MAX_OBJECT_BYTES) throw new UpstreamError("object too large");
      return buf;
    },
  };
}
