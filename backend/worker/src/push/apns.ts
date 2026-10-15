// APNs provider API over HTTP/2 with token-based authentication.
//
// - Provider token: ES256 JWT {alg, kid} {iss: team id, iat}, from the .p8 key; reused for up to
//   50 minutes (Apple rejects tokens older than one hour and asks providers not to refresh more
//   often than every 20 minutes), refreshed early on 403 ExpiredProviderToken.
// - Device pushes: POST /3/device/<token> on api.push.apple.com / api.sandbox.push.apple.com.
// - Live Activity broadcast (iOS 18+): channels are created/deleted on the management API
//   (POST|DELETE /1/apps/<bundle>/channels on api-manage-broadcast[.sandbox].push.apple.com:2196/2195)
//   and messages are sent with POST /4/broadcasts/apps/<bundle> + apns-channel-id
//   (developer.apple.com/documentation/usernotifications/sending-channel-management-requests-to-apns,
//    .../sending-broadcast-push-notification-requests-to-apns).

import { randomUUID } from "node:crypto";
import type { ApnsConfig } from "../config.js";
import { H2Pool, type H2Response } from "./h2.js";
import { signEs256 } from "./jwt.js";

export type ApnsPushType = "alert" | "background" | "liveactivity" | "widgets";

export interface ApnsNotification {
  token: string;
  pushType: ApnsPushType;
  /** omitted header = APNs default (10) */
  priority?: 5 | 10;
  /** UNIX seconds; 0 = deliver once, no storage; undefined = header omitted (APNs default storage) */
  expiration?: number;
  /** ≤ 64 bytes */
  collapseId?: string;
  payload: Record<string, unknown>;
}

export interface ApnsResult {
  ok: boolean;
  status: number;
  reason?: string;
  apnsId?: string;
  /** the token is permanently invalid for this app: remove it */
  invalidToken: boolean;
  /** worth retrying later (429, 5xx, network) */
  retryable: boolean;
  startedAt: number;
  finishedAt: number;
}

/** "cached ≤ 50 min" */
export const PROVIDER_TOKEN_MAX_AGE_MS = 50 * 60 * 1000;

const INVALID_TOKEN_REASONS = new Set(["BadDeviceToken", "Unregistered", "ExpiredToken"]);

export class ApnsClient {
  private pool: H2Pool;
  private token: { jwt: string; issuedAt: number } | null = null;

  constructor(
    private readonly cfg: ApnsConfig,
    private readonly opts: { now?: () => number; timeoutMs?: number } = {},
  ) {
    this.pool = new H2Pool({ ca: cfg.ca, timeoutMs: opts.timeoutMs ?? 15_000 });
  }

  get bundleId(): string {
    return this.cfg.bundleId;
  }

  get environment(): "sandbox" | "production" {
    return this.cfg.env;
  }

  get pushOrigin(): string {
    return this.cfg.origin ?? (this.cfg.env === "production" ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com");
  }

  get manageOrigin(): string {
    return (
      this.cfg.manageOrigin ??
      (this.cfg.env === "production" ? "https://api-manage-broadcast.push.apple.com:2196" : "https://api-manage-broadcast.sandbox.push.apple.com:2195")
    );
  }

  private now(): number {
    return this.opts.now?.() ?? Date.now();
  }

  /** The cached provider token, re-signed when older than 50 minutes or when forced. */
  providerToken(force = false): string {
    const now = this.now();
    if (!force && this.token && now - this.token.issuedAt < PROVIDER_TOKEN_MAX_AGE_MS) return this.token.jwt;
    const jwt = signEs256({ kid: this.cfg.keyId }, { iss: this.cfg.teamId, iat: Math.floor(now / 1000) }, this.cfg.keyP8);
    this.token = { jwt, issuedAt: now };
    return jwt;
  }

  topicFor(pushType: ApnsPushType): string {
    if (pushType === "liveactivity") return `${this.cfg.bundleId}.push-type.liveactivity`;
    if (pushType === "widgets") return `${this.cfg.bundleId}.push-type.widgets`;
    return this.cfg.bundleId;
  }

  async send(n: ApnsNotification): Promise<ApnsResult> {
    const headers = (): Record<string, string> => {
      const h: Record<string, string> = {
        ":method": "POST",
        ":path": `/3/device/${n.token}`,
        authorization: `bearer ${this.providerToken()}`,
        "apns-push-type": n.pushType,
        "apns-topic": this.topicFor(n.pushType),
        "apns-id": randomUUID(),
        "content-type": "application/json",
      };
      if (n.priority !== undefined) h["apns-priority"] = String(n.priority);
      if (n.expiration !== undefined) h["apns-expiration"] = String(n.expiration);
      if (n.collapseId) h["apns-collapse-id"] = n.collapseId;
      return h;
    };
    return this.call(this.pushOrigin, headers, JSON.stringify(n.payload));
  }

  /** One message to every activity subscribed to the channel (iOS 18+). */
  async broadcast(b: { channelId: string; priority: 5 | 10; expiration: number; payload: Record<string, unknown> }): Promise<ApnsResult> {
    const headers = (): Record<string, string> => ({
      ":method": "POST",
      ":path": `/4/broadcasts/apps/${this.cfg.bundleId}`,
      authorization: `bearer ${this.providerToken()}`,
      "apns-push-type": "liveactivity",
      "apns-channel-id": b.channelId,
      "apns-priority": String(b.priority),
      "apns-expiration": String(b.expiration),
      "apns-request-id": randomUUID(),
      "content-type": "application/json",
    });
    return this.call(this.pushOrigin, headers, JSON.stringify(b.payload));
  }

  /**
   * Creates a Live Activity broadcast channel. messageStoragePolicy 1 = "Most Recent Message
   * Stored" (for infrequent updates; stored up to 8 hours), 0 = none.
   */
  async createChannel(messageStoragePolicy: 0 | 1 = 1): Promise<string> {
    const res = await this.call(
      this.manageOrigin,
      () => ({
        ":method": "POST",
        ":path": `/1/apps/${this.cfg.bundleId}/channels`,
        authorization: `bearer ${this.providerToken()}`,
        "apns-request-id": randomUUID(),
        "content-type": "application/json",
      }),
      JSON.stringify({ "message-storage-policy": messageStoragePolicy, "push-type": "LiveActivity" }),
      (r) => r.headers["apns-channel-id"],
    );
    if (!res.ok || !res.channelId) throw new Error(`APNs channel create failed: ${res.status} ${res.reason ?? ""}`);
    return res.channelId;
  }

  async deleteChannel(channelId: string): Promise<ApnsResult> {
    return this.call(this.manageOrigin, () => ({
      ":method": "DELETE",
      ":path": `/1/apps/${this.cfg.bundleId}/channels`,
      authorization: `bearer ${this.providerToken()}`,
      "apns-channel-id": channelId,
      "apns-request-id": randomUUID(),
    }));
  }

  private async call(
    origin: string,
    headers: () => Record<string, string>,
    body?: string,
    extract?: (r: H2Response) => unknown,
  ): Promise<ApnsResult & { channelId?: string }> {
    const startedAt = this.now();
    let res: H2Response;
    try {
      res = await this.pool.request(origin, headers(), body);
      if (res.status === 403) {
        const reason = parseReason(res.body);
        if (reason === "ExpiredProviderToken" || reason === "InvalidProviderToken") {
          this.providerToken(true);
          res = await this.pool.request(origin, headers(), body);
        }
      }
    } catch (e) {
      return {
        ok: false,
        status: 0,
        reason: (e as Error).message,
        invalidToken: false,
        retryable: true,
        startedAt,
        finishedAt: this.now(),
      };
    }
    const reason = res.status >= 300 ? parseReason(res.body) : undefined;
    const extracted = extract?.(res);
    return {
      ok: res.status >= 200 && res.status < 300,
      status: res.status,
      reason,
      apnsId: (res.headers["apns-id"] as string | undefined) ?? (res.headers["apns-request-id"] as string | undefined),
      invalidToken: res.status === 410 || (reason !== undefined && INVALID_TOKEN_REASONS.has(reason)),
      retryable: res.status === 429 || res.status >= 500,
      startedAt,
      finishedAt: this.now(),
      channelId: typeof extracted === "string" ? extracted : undefined,
    };
  }

  close(): void {
    this.pool.close();
  }
}

function parseReason(body: string): string | undefined {
  try {
    return (JSON.parse(body) as { reason?: string }).reason;
  } catch {
    return body || undefined;
  }
}
