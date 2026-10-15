// Sends a batch of device pushes (APNs + FCM) concurrently, removes invalid tokens and logs the
// dispatch spread (how far apart the first and last send of the batch started and finished).

import type { Db } from "../db.js";
import type { Logger } from "../log.js";
import type { ApnsClient, ApnsResult } from "./apns.js";
import type { FcmClient, FcmResult } from "./fcm.js";
import type { ApnsDraft, FcmDraft } from "./payloads.js";

export type TokenColumn = "push_token" | "push_to_start_token" | "widget_push_token";

export interface DeviceSend {
  userId: string;
  deviceId: string;
  platform: "ios" | "android";
  token: string;
  tokenColumn: TokenColumn;
  /** what this send is, for logs and tests (e.g. "liveactivity.start", "alert", "widgetkit") */
  label: string;
  apns?: ApnsDraft;
  fcm?: FcmDraft;
}

export interface SendOutcome {
  send: DeviceSend;
  ok: boolean;
  status: number;
  reason?: string;
  invalidToken: boolean;
  retryable: boolean;
  startedAt: number;
  finishedAt: number;
  skipped?: "apns_not_configured" | "fcm_not_configured";
}

export interface BatchReport {
  label: string;
  total: number;
  ok: number;
  failed: number;
  skipped: number;
  invalidTokens: number;
  /** last send start − first send start (ms) */
  dispatchSpreadMs: number;
  /** last response − first response (ms) */
  completionSpreadMs: number;
  durationMs: number;
  outcomes: SendOutcome[];
}

export class PushService {
  constructor(
    public readonly apns: ApnsClient | null,
    public readonly fcm: FcmClient | null,
    private readonly db: Db,
    private readonly log: Logger,
  ) {}

  private async one(s: DeviceSend): Promise<SendOutcome> {
    const now = Date.now();
    if (s.platform === "ios") {
      if (!this.apns || !s.apns) return { send: s, ok: false, status: 0, invalidToken: false, retryable: false, startedAt: now, finishedAt: now, skipped: "apns_not_configured" };
      const r: ApnsResult = await this.apns.send({ ...s.apns, token: s.token });
      return { send: s, ok: r.ok, status: r.status, reason: r.reason, invalidToken: r.invalidToken, retryable: r.retryable, startedAt: r.startedAt, finishedAt: r.finishedAt };
    }
    if (!this.fcm || !s.fcm) return { send: s, ok: false, status: 0, invalidToken: false, retryable: false, startedAt: now, finishedAt: now, skipped: "fcm_not_configured" };
    const r: FcmResult = await this.fcm.send({ ...s.fcm, token: s.token });
    return { send: s, ok: r.ok, status: r.status, reason: r.errorCode ?? r.message, invalidToken: r.invalidToken, retryable: r.retryable, startedAt: r.startedAt, finishedAt: r.finishedAt };
  }

  /**
   * Sends every push of the batch at once (one concurrent batch: APNs requests are multiplexed
   * on one HTTP/2 connection, FCM requests likewise). Sends that failed transiently are retried
   * once right after the batch; invalid tokens are removed from `devices`.
   */
  async dispatch(sends: DeviceSend[], meta: { label: string } & Record<string, unknown>): Promise<BatchReport> {
    const started = Date.now();
    let outcomes = await Promise.all(sends.map((s) => this.one(s)));
    const retry = outcomes.filter((o) => !o.ok && o.retryable && !o.skipped);
    if (retry.length) {
      const again = await Promise.all(retry.map((o) => this.one(o.send)));
      outcomes = outcomes.map((o) => again.find((a) => a.send === o.send) ?? o);
    }
    const invalid = outcomes.filter((o) => o.invalidToken);
    for (const o of invalid) await this.removeToken(o.send);

    const real = outcomes.filter((o) => !o.skipped);
    const starts = real.map((o) => o.startedAt);
    const ends = real.map((o) => o.finishedAt);
    const report: BatchReport = {
      label: meta.label,
      total: sends.length,
      ok: outcomes.filter((o) => o.ok).length,
      failed: real.filter((o) => !o.ok).length,
      skipped: outcomes.length - real.length,
      invalidTokens: invalid.length,
      dispatchSpreadMs: starts.length ? Math.max(...starts) - Math.min(...starts) : 0,
      completionSpreadMs: ends.length ? Math.max(...ends) - Math.min(...ends) : 0,
      durationMs: Date.now() - started,
      outcomes,
    };
    if (sends.length) {
      const { label, ...rest } = meta;
      this.log.info("push batch", {
        batch: label,
        ...rest,
        total: report.total,
        ok: report.ok,
        failed: report.failed,
        skipped: report.skipped,
        invalid_tokens: report.invalidTokens,
        dispatch_spread_ms: report.dispatchSpreadMs,
        completion_spread_ms: report.completionSpreadMs,
        duration_ms: report.durationMs,
        failures: real.filter((o) => !o.ok).slice(0, 10).map((o) => ({ label: o.send.label, status: o.status, reason: o.reason })),
      });
    }
    return report;
  }

  /** 410 / BadDeviceToken / UNREGISTERED: the device row goes; a dead Live Activity or widget token is cleared. */
  private async removeToken(s: DeviceSend): Promise<void> {
    if (s.tokenColumn === "push_token") {
      const { error } = await this.db.from("devices").delete().eq("id", s.deviceId).eq("push_token", s.token);
      if (error) this.log.warn("device delete failed", { device_id: s.deviceId, error: error.message });
      else this.log.info("device removed (invalid push token)", { device_id: s.deviceId, user_id: s.userId, platform: s.platform });
    } else {
      const { error } = await this.db.from("devices").update({ [s.tokenColumn]: null }).eq("id", s.deviceId).eq(s.tokenColumn, s.token);
      if (error) this.log.warn("device token clear failed", { device_id: s.deviceId, column: s.tokenColumn, error: error.message });
      else this.log.info("device token cleared (invalid)", { device_id: s.deviceId, column: s.tokenColumn });
    }
  }

  close(): void {
    this.apns?.close();
    this.fcm?.close();
  }
}
