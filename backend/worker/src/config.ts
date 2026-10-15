// Worker configuration from environment variables (documented in docs/DEPLOY.md).

import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { LogLevel } from "./log.js";

export interface ApnsConfig {
  /** contents of the .p8 key file (PEM, PKCS#8 EC P-256) */
  keyP8: string;
  keyId: string;
  teamId: string;
  /** the app's bundle id (apns-topic); Live Activity / widget pushes add a suffix */
  bundleId: string;
  env: "sandbox" | "production";
  /** overrides for tests / staging: https://host:port of the device push API and the channel management API */
  origin?: string;
  manageOrigin?: string;
  /** extra trusted CA (tests with a self-signed mock server) */
  ca?: string | Buffer;
}

export interface FcmServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri: string;
}

export interface FcmConfig {
  serviceAccount: FcmServiceAccount;
  /** override of https://fcm.googleapis.com for tests */
  origin?: string;
  ca?: string | Buffer;
}

export interface LaneConfig {
  concurrency: number;
  pollMs: number;
}

export interface WorkerConfig {
  supabaseUrl: string;
  serviceRoleKey: string;
  workerId: string;
  port: number;
  logLevel: LogLevel;
  lanes: { realtime: LaneConfig; heavy: LaneConfig };
  schedulerIntervalMs: number;
  shutdownGraceMs: number;
  apns: ApnsConfig | null;
  fcm: FcmConfig | null;
  anthropicApiKey: string | null;
  recapModel: string;
  revenuecatWebhookAuth: string | null;
  moderationWebhookUrl: string | null;
  fontsDir: string;
}

const here = path.dirname(fileURLToPath(import.meta.url));
export const WORKER_ROOT = path.resolve(here, "..");
export const REPO_ROOT = path.resolve(WORKER_ROOT, "../..");

export const DEFAULT_RECAP_MODEL = "claude-opus-5-5";

function int(env: NodeJS.ProcessEnv, key: string, fallback: number): number {
  const v = env[key];
  if (v === undefined || v === "") return fallback;
  const n = Number(v);
  if (!Number.isFinite(n) || n < 0) throw new Error(`${key} must be a non-negative number`);
  return Math.floor(n);
}

function nonEmpty(v: string | undefined): string | null {
  return v !== undefined && v.trim() !== "" ? v : null;
}

/** .p8 contents may be given with literal "\n" sequences (single-line secret stores). */
function pem(v: string): string {
  return v.includes("\\n") && !v.includes("\n") ? v.replace(/\\n/g, "\n") : v;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): WorkerConfig {
  const supabaseUrl = nonEmpty(env.SUPABASE_URL);
  const serviceRoleKey = nonEmpty(env.SUPABASE_SERVICE_ROLE_KEY);
  if (!supabaseUrl || !serviceRoleKey) throw new Error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required");

  let apns: ApnsConfig | null = null;
  const p8 = nonEmpty(env.APNS_KEY_P8);
  if (p8) {
    const keyId = nonEmpty(env.APNS_KEY_ID);
    const teamId = nonEmpty(env.APNS_TEAM_ID);
    const bundleId = nonEmpty(env.APNS_BUNDLE_ID);
    if (!keyId || !teamId || !bundleId) throw new Error("APNS_KEY_P8 needs APNS_KEY_ID, APNS_TEAM_ID and APNS_BUNDLE_ID");
    const apnsEnv = env.APNS_ENV ?? "production";
    if (apnsEnv !== "sandbox" && apnsEnv !== "production") throw new Error("APNS_ENV must be sandbox or production");
    apns = {
      keyP8: pem(p8),
      keyId,
      teamId,
      bundleId,
      env: apnsEnv,
      origin: nonEmpty(env.APNS_ORIGIN) ?? undefined,
      manageOrigin: nonEmpty(env.APNS_MANAGE_ORIGIN) ?? undefined,
    };
  }

  let fcm: FcmConfig | null = null;
  const sa = nonEmpty(env.FCM_SERVICE_ACCOUNT_JSON);
  if (sa) {
    const parsed = JSON.parse(sa) as Partial<FcmServiceAccount>;
    if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
      throw new Error("FCM_SERVICE_ACCOUNT_JSON needs project_id, client_email and private_key");
    }
    fcm = {
      serviceAccount: {
        project_id: parsed.project_id,
        client_email: parsed.client_email,
        private_key: pem(parsed.private_key),
        token_uri: parsed.token_uri ?? "https://oauth2.googleapis.com/token",
      },
      origin: nonEmpty(env.FCM_ORIGIN) ?? undefined,
    };
  }

  const level = (env.LOG_LEVEL ?? "info") as LogLevel;
  return {
    supabaseUrl,
    serviceRoleKey,
    workerId: nonEmpty(env.WORKER_ID) ?? `${os.hostname()}-${process.pid}`,
    port: int(env, "PORT", 8080),
    logLevel: ["debug", "info", "warn", "error"].includes(level) ? level : "info",
    lanes: {
      // time-critical: invitation dispatch, pushes, widget refreshes
      realtime: { concurrency: int(env, "WORKER_REALTIME_CONCURRENCY", 8), pollMs: int(env, "WORKER_REALTIME_POLL_MS", 1000) },
      // CPU-bound: renditions, collages, tribute videos, recaps, year stories, deletions
      heavy: { concurrency: int(env, "WORKER_HEAVY_CONCURRENCY", 2), pollMs: int(env, "WORKER_HEAVY_POLL_MS", 2000) },
    },
    schedulerIntervalMs: int(env, "SCHEDULER_INTERVAL_MS", 60_000),
    shutdownGraceMs: int(env, "SHUTDOWN_GRACE_MS", 25_000),
    apns,
    fcm,
    anthropicApiKey: nonEmpty(env.ANTHROPIC_API_KEY),
    recapModel: nonEmpty(env.RECAP_MODEL) ?? DEFAULT_RECAP_MODEL,
    revenuecatWebhookAuth: nonEmpty(env.REVENUECAT_WEBHOOK_AUTH),
    moderationWebhookUrl: nonEmpty(env.MODERATION_WEBHOOK_URL),
    fontsDir: nonEmpty(env.FONTS_DIR) ?? path.join(WORKER_ROOT, "fonts"),
  };
}
