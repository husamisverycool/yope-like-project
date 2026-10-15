// Runtime configuration: environment variables + config/app.json (the single source of app
// identity). Values the owner has not provided yet are BLOCKED (docs/OWNER_SETUP.md).
//
// Environment
//   NODE_ENV                   production | development | test (default development)
//   PORT                       listen port (default 8080)
//   SUPABASE_URL               project URL (required in production)
//   SUPABASE_ANON_KEY          anon key: invite_preview is called with it (required in production)
//   SUPABASE_SERVICE_ROLE_KEY  service role: signs storage paths only (required in production)
//   APP_CONFIG_PATH            path to config/app.json (default: ../config/app.json from web/)
//   TRUST_PROXY_HOPS           reverse proxies in front of the service whose X-Forwarded-For
//                              entries are trusted for per-address rate limiting (default 0)
//   INVITE_CACHE_SECONDS       how long an invite lookup (and its images) is reused, and the
//                              Cache-Control max-age of every /i/ response; bounds how long a
//                              revoked invite can still be seen (default 60)
//   SIGNED_URL_SECONDS         expiry of the storage URLs this service signs (default 120)
//   RATE_LIMIT_REQUESTS        requests per address per minute on /i/ routes (default 300)
//   RATE_LIMIT_LOOKUPS         invite lookups (cache misses) per address per minute (default 30)
//   UPSTREAM_TIMEOUT_MS        timeout of each Supabase call (default 5000)

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export type Mode = "production" | "development" | "test";

export interface AppIdentity {
  /** App name; null while BLOCKED (owner decision 0.1). */
  displayName: string | null;
  /** Invite-link host, e.g. "example.com"; null while BLOCKED. */
  domain: string | null;
  ios: {
    bundleId: string;
    /** Apple Team ID; null while BLOCKED. */
    teamId: string | null;
    /** Numeric App Store id for the Smart App Banner and store link; null while BLOCKED. */
    appStoreId: string | null;
  };
  android: {
    applicationId: string;
    sha256CertFingerprints: string[];
  };
  legal: { privacyUrl: string | null; termsUrl: string | null };
}

export interface Config {
  mode: Mode;
  port: number;
  supabase: { url: string; anonKey: string; serviceRoleKey: string } | null;
  app: AppIdentity;
  trustProxyHops: number;
  inviteCacheSeconds: number;
  signedUrlSeconds: number;
  rateLimitRequests: number;
  rateLimitLookups: number;
  upstreamTimeoutMs: number;
}

const WEB_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function str(v: unknown): string | null {
  return typeof v === "string" && v.trim() !== "" ? v.trim() : null;
}

function int(name: string, env: NodeJS.ProcessEnv, fallback: number, min: number): number {
  const raw = env[name];
  if (raw === undefined || raw === "") return fallback;
  const n = Number(raw);
  if (!Number.isInteger(n) || n < min) throw new Error(`${name} must be an integer ≥ ${min} (got ${JSON.stringify(raw)})`);
  return n;
}

const DOMAIN_RE = /^(?=.{1,253}$)([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/i;
const TEAM_RE = /^[A-Z0-9]{10}$/;
const BUNDLE_RE = /^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$/;
const FINGERPRINT_RE = /^([0-9A-F]{2}:){31}[0-9A-F]{2}$/;
const APP_STORE_ID_RE = /^[0-9]{6,12}$/;

/** Parses config/app.json. Malformed values are errors in every mode; missing ones are BLOCKED. */
export function parseAppIdentity(json: any): AppIdentity {
  const displayName = str(json?.displayName?.value);
  const domain = str(json?.domain?.value);
  const bundleId = str(json?.ios?.bundleId);
  const teamId = str(json?.ios?.teamId);
  const appStoreId = json?.ios?.appStoreId == null ? null : String(json.ios.appStoreId).trim() || null;
  const applicationId = str(json?.android?.applicationId);
  const fingerprints: unknown = json?.android?.sha256CertFingerprints ?? [];
  if (!bundleId || !BUNDLE_RE.test(bundleId)) throw new Error("config/app.json ios.bundleId is missing or malformed");
  if (!applicationId || !BUNDLE_RE.test(applicationId)) throw new Error("config/app.json android.applicationId is missing or malformed");
  if (domain && !DOMAIN_RE.test(domain)) throw new Error(`config/app.json domain ${JSON.stringify(domain)} is not a host name`);
  if (teamId && !TEAM_RE.test(teamId)) throw new Error(`config/app.json ios.teamId ${JSON.stringify(teamId)} is not a 10-character Team ID`);
  if (appStoreId && !APP_STORE_ID_RE.test(appStoreId)) throw new Error(`config/app.json ios.appStoreId ${JSON.stringify(appStoreId)} is not a numeric App Store id`);
  if (!Array.isArray(fingerprints) || !fingerprints.every((f) => typeof f === "string" && FINGERPRINT_RE.test(f.toUpperCase()))) {
    throw new Error("config/app.json android.sha256CertFingerprints must be SHA-256 fingerprints (AA:BB:…)");
  }
  const url = (v: unknown, name: string): string | null => {
    const s = str(v);
    if (!s) return null;
    let u: URL;
    try {
      u = new URL(s);
    } catch {
      throw new Error(`config/app.json ${name} is not a URL`);
    }
    if (u.protocol !== "https:") throw new Error(`config/app.json ${name} must be https`);
    return u.toString();
  };
  return {
    displayName,
    domain: domain ? domain.toLowerCase() : null,
    ios: { bundleId, teamId, appStoreId },
    android: { applicationId, sha256CertFingerprints: (fingerprints as string[]).map((f) => f.toUpperCase()) },
    legal: { privacyUrl: url(json?.legal?.privacyUrl, "legal.privacyUrl"), termsUrl: url(json?.legal?.termsUrl, "legal.termsUrl") },
  };
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const mode: Mode = env.NODE_ENV === "production" ? "production" : env.NODE_ENV === "test" ? "test" : "development";
  const appPath = env.APP_CONFIG_PATH ?? path.join(WEB_ROOT, "..", "config", "app.json");
  const app = parseAppIdentity(JSON.parse(fs.readFileSync(appPath, "utf8")));
  const url = str(env.SUPABASE_URL);
  const anonKey = str(env.SUPABASE_ANON_KEY);
  const serviceRoleKey = str(env.SUPABASE_SERVICE_ROLE_KEY);
  let supabase: Config["supabase"] = null;
  if (url && anonKey && serviceRoleKey) {
    const u = new URL(url);
    if (mode === "production" && u.protocol !== "https:") throw new Error("SUPABASE_URL must be https in production");
    supabase = { url: url.replace(/\/+$/, ""), anonKey, serviceRoleKey };
  }
  return {
    mode,
    port: int("PORT", env, 8080, 1),
    supabase,
    app,
    trustProxyHops: int("TRUST_PROXY_HOPS", env, 0, 0),
    inviteCacheSeconds: int("INVITE_CACHE_SECONDS", env, 60, 1),
    signedUrlSeconds: int("SIGNED_URL_SECONDS", env, 120, 10),
    rateLimitRequests: int("RATE_LIMIT_REQUESTS", env, 300, 1),
    rateLimitLookups: int("RATE_LIMIT_LOOKUPS", env, 30, 1),
    upstreamTimeoutMs: int("UPSTREAM_TIMEOUT_MS", env, 5000, 100),
  };
}

/** Every value the service needs that is still missing. Production refuses to start with any. */
export function blockedConfig(config: Config): string[] {
  const out: string[] = [];
  if (!config.supabase) out.push("SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY (environment)");
  if (!config.app.domain) out.push("config/app.json domain (owner step 4.1)");
  if (!config.app.ios.teamId) out.push("config/app.json ios.teamId (owner step 1.1)");
  if (!config.app.ios.appStoreId) out.push("config/app.json ios.appStoreId (App Store Connect → App Information → Apple ID)");
  if (config.app.android.sha256CertFingerprints.length === 0) out.push("config/app.json android.sha256CertFingerprints (owner step 2.2)");
  return out;
}

export const appClipBundleId = (app: AppIdentity): string => `${app.ios.bundleId}.Clip`;
