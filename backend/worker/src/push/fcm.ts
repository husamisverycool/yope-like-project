// Firebase Cloud Messaging HTTP v1 with a service-account OAuth 2.0 access token
// (JWT bearer grant, RFC 7523: RS256 assertion {iss: client_email, scope, aud: token_uri}).
// Data messages only: the Android app renders every notification itself
// (android/core/push: PushHandler / AlertNotifier / DailyInvitationNotifier).

import type { FcmConfig } from "../config.js";
import { H2Pool } from "./h2.js";
import { signRs256 } from "./jwt.js";

export const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

export interface FcmMessage {
  token: string;
  /** string-to-string map (FCM data payload) */
  data: Record<string, string>;
  /**
   * "high" only when the app posts a visible notification for this message; widget-only and
   * silent messages go "normal" (docs/PLATFORM_CONSTRAINTS.md §4.4: FCM deprioritizes high
   * priority messages that don't result in user-facing notifications).
   */
  priority: "high" | "normal";
  ttlSeconds?: number;
  /** transport collapse key (only the newest undelivered message with this key is kept) */
  collapseKey?: string;
}

export interface FcmResult {
  ok: boolean;
  status: number;
  errorCode?: string;
  message?: string;
  name?: string;
  invalidToken: boolean;
  retryable: boolean;
  startedAt: number;
  finishedAt: number;
}

export class FcmClient {
  private pool: H2Pool;
  private access: { token: string; expiresAt: number } | null = null;
  private pending: Promise<string> | null = null;

  constructor(
    private readonly cfg: FcmConfig,
    private readonly opts: { now?: () => number; timeoutMs?: number } = {},
  ) {
    this.pool = new H2Pool({ ca: cfg.ca, timeoutMs: opts.timeoutMs ?? 15_000 });
  }

  private now(): number {
    return this.opts.now?.() ?? Date.now();
  }

  get origin(): string {
    return this.cfg.origin ?? "https://fcm.googleapis.com";
  }

  /** OAuth access token, cached until 5 minutes before expiry; concurrent callers share one fetch. */
  async accessToken(force = false): Promise<string> {
    if (!force && this.access && this.now() < this.access.expiresAt - 5 * 60_000) return this.access.token;
    if (this.pending) return this.pending;
    this.pending = this.fetchToken().finally(() => {
      this.pending = null;
    });
    return this.pending;
  }

  private async fetchToken(): Promise<string> {
    const sa = this.cfg.serviceAccount;
    const iat = Math.floor(this.now() / 1000);
    const assertion = signRs256({}, { iss: sa.client_email, scope: FCM_SCOPE, aud: sa.token_uri, iat, exp: iat + 3600 }, sa.private_key);
    const url = new URL(sa.token_uri);
    const body = new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }).toString();
    const res = await this.pool.request(
      url.origin,
      { ":method": "POST", ":path": url.pathname + url.search, "content-type": "application/x-www-form-urlencoded" },
      body,
    );
    if (res.status !== 200) throw new Error(`FCM OAuth token request failed: ${res.status} ${res.body.slice(0, 200)}`);
    const json = JSON.parse(res.body) as { access_token?: string; expires_in?: number };
    if (!json.access_token) throw new Error("FCM OAuth token response has no access_token");
    this.access = { token: json.access_token, expiresAt: this.now() + (json.expires_in ?? 3600) * 1000 };
    return json.access_token;
  }

  static body(m: FcmMessage): Record<string, unknown> {
    const android: Record<string, unknown> = { priority: m.priority === "high" ? "HIGH" : "NORMAL" };
    if (m.ttlSeconds !== undefined) android.ttl = `${Math.max(0, Math.floor(m.ttlSeconds))}s`;
    if (m.collapseKey) android.collapse_key = m.collapseKey;
    return { message: { token: m.token, data: m.data, android } };
  }

  async send(m: FcmMessage): Promise<FcmResult> {
    const startedAt = this.now();
    const path = `/v1/projects/${this.cfg.serviceAccount.project_id}/messages:send`;
    const body = JSON.stringify(FcmClient.body(m));
    const attempt = async (force: boolean) =>
      this.pool.request(
        this.origin,
        { ":method": "POST", ":path": path, authorization: `Bearer ${await this.accessToken(force)}`, "content-type": "application/json" },
        body,
      );
    try {
      let res = await attempt(false);
      if (res.status === 401) res = await attempt(true);
      if (res.status === 200) {
        return { ok: true, status: 200, name: (JSON.parse(res.body) as { name?: string }).name, invalidToken: false, retryable: false, startedAt, finishedAt: this.now() };
      }
      const err = parseError(res.body);
      return {
        ok: false,
        status: res.status,
        errorCode: err.code,
        message: err.message,
        invalidToken: err.code === "UNREGISTERED",
        retryable: res.status === 429 || res.status >= 500 || err.code === "QUOTA_EXCEEDED" || err.code === "UNAVAILABLE" || err.code === "INTERNAL",
        startedAt,
        finishedAt: this.now(),
      };
    } catch (e) {
      return { ok: false, status: 0, message: (e as Error).message, invalidToken: false, retryable: true, startedAt, finishedAt: this.now() };
    }
  }

  close(): void {
    this.pool.close();
  }
}

function parseError(body: string): { code?: string; message?: string } {
  try {
    const e = (JSON.parse(body) as { error?: { status?: string; message?: string; details?: Array<{ errorCode?: string }> } }).error;
    const detail = e?.details?.find((d) => d.errorCode)?.errorCode;
    return { code: detail ?? e?.status, message: e?.message };
  } catch {
    return { message: body.slice(0, 200) };
  }
}
