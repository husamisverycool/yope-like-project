// Storage (bucket `media`) with the service role: the worker writes renditions, collages,
// tributes and year assets, signs short-lived URLs for pushes, and deletes objects.

import type { Db } from "./db.js";
import { chunks } from "./db.js";

export const MEDIA_BUCKET = "media";
/** docs/API.md §7: "Use 1 h for the app and widgets." */
export const SIGNED_URL_SECONDS = 3600;

export class StorageError extends Error {
  override name = "StorageError";
  constructor(message: string, public readonly status?: number) {
    super(message);
  }
}

function statusOf(err: unknown): number | undefined {
  const e = err as { statusCode?: string | number; status?: number; originalError?: { status?: number } };
  const s = e?.status ?? e?.originalError?.status ?? (e?.statusCode !== undefined ? Number(e.statusCode) : undefined);
  return Number.isFinite(s) ? s : undefined;
}

export class Storage {
  constructor(private readonly db: Db, private readonly bucket = MEDIA_BUCKET) {}

  private get api() {
    return this.db.storage.from(this.bucket);
  }

  /** Retries server errors (an object being replaced at that moment can answer 5xx). */
  async download(path: string): Promise<Buffer> {
    for (let attempt = 1; ; attempt++) {
      const { data, error } = await this.api.download(path);
      if (!error && data) return Buffer.from(await data.arrayBuffer());
      const status = statusOf(error);
      const transient = status === undefined || status >= 500;
      if (!transient || attempt >= 3) throw new StorageError(`download ${path}: ${error?.message ?? "no data"}`, status);
      await new Promise((r) => setTimeout(r, 250 * attempt));
    }
  }

  /** Writes (or overwrites) an object. Worker paths are deterministic, so a re-run writes the same bytes. */
  async upload(path: string, body: Buffer, contentType: string): Promise<void> {
    const { error } = await this.api.upload(path, body, { contentType, upsert: true, cacheControl: "3600" });
    if (error) throw new StorageError(`upload ${path}: ${error.message}`, statusOf(error));
  }

  async exists(path: string): Promise<boolean> {
    const slash = path.lastIndexOf("/");
    const dir = path.slice(0, slash);
    const name = path.slice(slash + 1);
    const { data, error } = await this.api.list(dir, { search: name, limit: 100 });
    if (error) throw new StorageError(`list ${dir}: ${error.message}`, statusOf(error));
    return (data ?? []).some((o) => o.name === name && o.id !== null);
  }

  /** Every object name under `prefix` (recursive). */
  async listAll(prefix: string): Promise<string[]> {
    const root = prefix.replace(/\/+$/, "");
    const out: string[] = [];
    const queue = [root];
    while (queue.length) {
      const dir = queue.shift() as string;
      for (let offset = 0; ; offset += 1000) {
        const { data, error } = await this.api.list(dir, { limit: 1000, offset, sortBy: { column: "name", order: "asc" } });
        if (error) throw new StorageError(`list ${dir}: ${error.message}`, statusOf(error));
        const rows = data ?? [];
        for (const o of rows) {
          const full = dir ? `${dir}/${o.name}` : o.name;
          if (o.id === null) queue.push(full); // folder placeholder
          else out.push(full);
        }
        if (rows.length < 1000) break;
      }
    }
    return out;
  }

  /** Deletes exact object names (missing ones are ignored). */
  async remove(paths: string[]): Promise<number> {
    let n = 0;
    for (const part of chunks([...new Set(paths.filter(Boolean))], 1000)) {
      const { data, error } = await this.api.remove(part);
      if (error) throw new StorageError(`remove: ${error.message}`, statusOf(error));
      n += data?.length ?? 0;
    }
    return n;
  }

  async removePrefix(prefix: string): Promise<number> {
    return this.remove(await this.listAll(prefix));
  }

  async signedUrl(path: string, expiresIn = SIGNED_URL_SECONDS): Promise<string> {
    const { data, error } = await this.api.createSignedUrl(path, expiresIn);
    if (error || !data) throw new StorageError(`sign ${path}: ${error?.message ?? "no data"}`, statusOf(error));
    return data.signedUrl;
  }

  async signedUrls(paths: string[], expiresIn = SIGNED_URL_SECONDS): Promise<Map<string, string>> {
    const out = new Map<string, string>();
    const unique = [...new Set(paths.filter(Boolean))];
    for (const part of chunks(unique, 100)) {
      const { data, error } = await this.api.createSignedUrls(part, expiresIn);
      if (error) throw new StorageError(`sign: ${error.message}`, statusOf(error));
      for (const row of data ?? []) if (row.path && row.signedUrl && !row.error) out.set(row.path, row.signedUrl);
    }
    return out;
  }
}
