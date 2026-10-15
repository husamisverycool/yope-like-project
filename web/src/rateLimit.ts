// Per-address request limits (fixed one-minute windows). Two limiters are used on /i/ routes:
// every request, and invite lookups that reach the database (cache misses), which is what a
// token-guessing client would need. Limits come from RATE_LIMIT_REQUESTS / RATE_LIMIT_LOOKUPS.

export class RateLimiter {
  private windows = new Map<string, { start: number; count: number }>();

  constructor(
    private readonly limit: number,
    private readonly windowMs = 60_000,
    private readonly now: () => number = Date.now,
  ) {}

  /** Counts one event for `key`; ok=false once the window's limit is used up. */
  take(key: string): { ok: boolean; retryAfterSeconds: number } {
    const t = this.now();
    if (this.windows.size > 50_000) this.sweep(t);
    let w = this.windows.get(key);
    if (!w || t - w.start >= this.windowMs) {
      w = { start: t, count: 0 };
      this.windows.set(key, w);
    }
    w.count++;
    const retryAfterSeconds = Math.max(1, Math.ceil((w.start + this.windowMs - t) / 1000));
    return { ok: w.count <= this.limit, retryAfterSeconds };
  }

  private sweep(t: number) {
    for (const [k, w] of this.windows) if (t - w.start >= this.windowMs) this.windows.delete(k);
  }
}

/**
 * The client address: the socket peer, or — behind `trustedHops` reverse proxies — the
 * X-Forwarded-For entry appended by the outermost trusted proxy.
 */
export function clientAddress(peer: string | undefined, forwardedFor: string | undefined, trustedHops: number): string {
  if (trustedHops > 0 && forwardedFor) {
    const hops = forwardedFor.split(",").map((s) => s.trim()).filter(Boolean);
    const pick = hops[hops.length - trustedHops];
    if (pick) return pick;
  }
  return peer ?? "unknown";
}
