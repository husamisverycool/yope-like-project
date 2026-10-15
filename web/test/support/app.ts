// Builds the app with a fake upstream and a test configuration.

import { createApp } from "../../src/app.js";
import { parseAppIdentity, type Config } from "../../src/config.js";
import { InviteService } from "../../src/inviteService.js";
import type { Upstream } from "../../src/supabase.js";

export const FULL_APP_JSON = {
  displayName: { value: null, level: "BLOCKED" },
  domain: { value: "invite.example.com" },
  ios: { bundleId: "com.example.groupphotos", teamId: "ABCDE12345", appStoreId: "1234567890", deploymentTarget: "17.2" },
  android: { applicationId: "com.example.groupphotos", minSdk: 26, targetSdk: 36, sha256CertFingerprints: ["14:6D:E9:83:C5:73:06:50:D8:EE:B9:95:2F:34:FC:64:16:A0:83:42:E6:1D:BE:A8:8A:04:96:B2:3F:CF:44:E5"] },
  legal: { privacyUrl: "https://legal.example.com/privacy", termsUrl: "https://legal.example.com/terms" },
};

export function testConfig(overrides: Partial<Config> = {}, appJson: unknown = FULL_APP_JSON): Config {
  return {
    mode: "test",
    port: 0,
    supabase: { url: "https://supabase.test", anonKey: "anon", serviceRoleKey: "service" },
    app: parseAppIdentity(appJson),
    trustProxyHops: 0,
    inviteCacheSeconds: 60,
    signedUrlSeconds: 120,
    rateLimitRequests: 1000,
    rateLimitLookups: 1000,
    upstreamTimeoutMs: 1000,
    ...overrides,
  };
}

export function testApp(upstream: Upstream | null, overrides: Partial<Config> = {}, appJson?: unknown, opts: { now?: () => number } = {}) {
  const config = testConfig(overrides, appJson);
  const invites = upstream
    ? new InviteService(upstream, { ttlSeconds: config.inviteCacheSeconds, signedUrlSeconds: config.signedUrlSeconds, now: opts.now })
    : null;
  const logs: string[] = [];
  const app = createApp({ config, invites, log: (l) => logs.push(l), peer: () => "203.0.113.7" });
  return { app, config, invites, logs };
}

export const IPHONE = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1";
export const ANDROID = "Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36";
export const DESKTOP = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36";
