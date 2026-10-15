// Looks up invites and prepares everything a page needs, with a short-lived cache.
//
// One lookup = invite_preview (anon) + one signing call (service role) + the cover download. The
// result, the processed cover, avatars and link-preview image are reused for INVITE_CACHE_SECONDS
// and then dropped, so a revoked or expired invite stops showing within that time. Upstream
// failures are never cached.

import { composeOgImage, processAvatar, processCover, type ProcessedCover } from "./images.js";
import type { InvitePreview, Upstream } from "./supabase.js";
import { defaultTheme, themeFromColour, type Theme } from "./theme.js";

export interface LoadedInvite {
  status: "ok";
  preview: InvitePreview;
  theme: Theme;
  cover: ProcessedCover | null;
  /** Indexes into preview.members whose avatar was signed and can be served. */
  avatarIndexes: Set<number>;
}

export type InviteResult = LoadedInvite | { status: "not_found" } | { status: "unavailable"; reason: "expired" | "revoked" };

interface Entry {
  token: string;
  expires: number;
  result: Promise<InviteResult>;
  signed: Map<string, string>;
  avatars: Map<number, Promise<Buffer | null>>;
  og?: Promise<Buffer | null>;
  bytes: number;
}

export interface InviteServiceOptions {
  ttlSeconds: number;
  signedUrlSeconds: number;
  /** Upper bound on cached image bytes; oldest entries are dropped beyond it. */
  maxBytes?: number;
  maxEntries?: number;
  now?: () => number;
  log?: (msg: string) => void;
}

export class InviteService {
  private cache = new Map<string, Entry>();
  private totalBytes = 0;
  private readonly ttlMs: number;
  private readonly maxBytes: number;
  private readonly maxEntries: number;
  private readonly now: () => number;
  private readonly log: (msg: string) => void;

  constructor(
    private readonly upstream: Upstream,
    private readonly opts: InviteServiceOptions,
  ) {
    if (opts.signedUrlSeconds < opts.ttlSeconds) throw new Error("SIGNED_URL_SECONDS must be ≥ INVITE_CACHE_SECONDS (cached signed URLs are reused)");
    this.ttlMs = opts.ttlSeconds * 1000;
    this.maxBytes = opts.maxBytes ?? 128 * 1024 * 1024;
    this.maxEntries = opts.maxEntries ?? 5000;
    this.now = opts.now ?? Date.now;
    this.log = opts.log ?? (() => {});
  }

  /** True when a lookup for this token would be answered from the cache (no database call). */
  isCached(token: string): boolean {
    const e = this.cache.get(token);
    return !!e && e.expires > this.now();
  }

  lookup(token: string): Promise<InviteResult> {
    return this.entry(token).result;
  }

  /** Processed avatar for member `index`, or null when that member has no servable avatar. */
  async avatar(token: string, index: number): Promise<Buffer | null> {
    const entry = this.entry(token);
    const result = await entry.result;
    if (result.status !== "ok" || !result.avatarIndexes.has(index)) return null;
    let p = entry.avatars.get(index);
    if (!p) {
      const url = entry.signed.get(result.preview.members[index]!.avatar_path!)!;
      p = this.upstream
        .fetchObject(url)
        .then(processAvatar)
        .then((buf) => {
          this.account(entry, buf.length);
          return buf;
        })
        .catch((e) => {
          entry.avatars.delete(index);
          throw e;
        });
      entry.avatars.set(index, p);
    }
    return p;
  }

  /** Link-preview image, or null when the group has no cover. */
  async ogImage(token: string): Promise<Buffer | null> {
    const entry = this.entry(token);
    const result = await entry.result;
    if (result.status !== "ok" || !result.cover) return null;
    if (!entry.og) {
      entry.og = composeOgImage(result.cover.jpeg).then((buf) => {
        this.account(entry, buf.length);
        return buf;
      });
      entry.og.catch(() => (entry.og = undefined));
    }
    return entry.og;
  }

  private entry(token: string): Entry {
    const now = this.now();
    const existing = this.cache.get(token);
    if (existing && existing.expires > now) return existing;
    if (existing) this.drop(token, existing);
    const entry: Entry = { token, expires: now + this.ttlMs, result: Promise.resolve({ status: "not_found" }), signed: new Map(), avatars: new Map(), bytes: 0 };
    entry.result = this.load(token, entry).catch((e) => {
      // Never cache failures: the next request tries again.
      if (this.cache.get(token) === entry) this.drop(token, entry);
      throw e;
    });
    this.cache.set(token, entry);
    this.evict();
    return entry;
  }

  private async load(token: string, entry: Entry): Promise<InviteResult> {
    const found = await this.upstream.invitePreview(token);
    if (found.status !== "ok") return found;
    const preview = found.preview;
    const paths = [preview.cover_path, ...preview.members.map((m) => m.avatar_path)].filter((p): p is string => p !== null);
    const signed = await this.upstream.signPaths(paths, this.opts.signedUrlSeconds);
    for (const [k, v] of signed) entry.signed.set(k, v);
    let cover: ProcessedCover | null = null;
    const coverUrl = preview.cover_path ? signed.get(preview.cover_path) : undefined;
    if (coverUrl) {
      const raw = await this.upstream.fetchObject(coverUrl);
      try {
        cover = await processCover(raw);
        this.account(entry, cover.jpeg.length);
      } catch (e) {
        this.log(`cover could not be decoded; showing the page without it (${(e as Error).message})`);
      }
    }
    const avatarIndexes = new Set<number>();
    preview.members.forEach((m, i) => {
      if (m.avatar_path && signed.has(m.avatar_path)) avatarIndexes.add(i);
    });
    const theme = cover ? themeFromColour(cover.mean) : defaultTheme();
    return { status: "ok", preview, theme, cover, avatarIndexes };
  }

  private account(entry: Entry, bytes: number) {
    if (this.cache.get(entry.token) !== entry) return; // already dropped
    entry.bytes += bytes;
    this.totalBytes += bytes;
    this.evict();
  }

  private drop(token: string, entry: Entry) {
    this.cache.delete(token);
    this.totalBytes -= entry.bytes;
  }

  private evict() {
    for (const [token, e] of this.cache) {
      if (this.totalBytes <= this.maxBytes && this.cache.size <= this.maxEntries) break;
      this.drop(token, e);
    }
  }
}
