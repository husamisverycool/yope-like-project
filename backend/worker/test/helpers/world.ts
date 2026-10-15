// A worker wired to the local Supabase stack and to mock APNs / FCM servers, with a test copy
// table (the real one is generated from design/copy.json and may not have the keys yet).

import { buildRunner, buildScheduler, buildServices } from "../../src/app.js";
import type { WorkerConfig } from "../../src/config.js";
import { setCopyTable, WORKER_COPY_KEYS } from "../../src/copy.js";
import { memoryLogger, type LogFields } from "../../src/log.js";
import type { RecapModel } from "../../src/recap/ai.js";
import type { Runner } from "../../src/runner.js";
import type { Scheduler } from "../../src/scheduler.js";
import type { Services } from "../../src/services.js";
import { WORKER_ROOT } from "../../src/config.js";
import path from "node:path";
import { API_URL, SERVICE_ROLE_KEY, admin } from "./db.js";
import { pushKeys, selfSignedCert, startMockApns, startMockFcm, type MockApns, type MockFcm } from "./mockPush.js";

export const BUNDLE_ID = "com.example.groupphotos";

/** Test-only strings: every placeholder each key allows, so payload tests can see them. */
export function testCopyTable(): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [key, spec] of Object.entries(WORKER_COPY_KEYS)) out[key] = `[${key}]` + spec.params.map((p) => ` ${p}={${p}}`).join("");
  return out;
}

export interface World {
  svc: Services;
  runner: Runner;
  scheduler: Scheduler;
  apns: MockApns;
  fcm: MockFcm;
  logs: LogFields[];
  config: WorkerConfig;
  close(): Promise<void>;
}

export async function startWorld(opts: { recapModel?: RecapModel | null; lanes?: Partial<WorkerConfig["lanes"]> } = {}): Promise<World> {
  const keys = pushKeys();
  const apns = await startMockApns({ publicKey: keys.apnsPublic, teamId: "TEAMID1234", keyId: "KEYID12345", bundleId: BUNDLE_ID });
  const fcm = await startMockFcm({ publicKey: keys.fcmPublic, projectId: "test-project", clientEmail: "worker@test-project.iam.gserviceaccount.com" });
  const { cert } = selfSignedCert();
  const config: WorkerConfig = {
    supabaseUrl: API_URL,
    serviceRoleKey: SERVICE_ROLE_KEY,
    workerId: `test-${process.pid}-${Math.random().toString(36).slice(2, 6)}`,
    port: 0,
    logLevel: "debug",
    lanes: {
      realtime: { concurrency: 8, pollMs: 200, ...(opts.lanes?.realtime ?? {}) },
      heavy: { concurrency: 3, pollMs: 200, ...(opts.lanes?.heavy ?? {}) },
    },
    schedulerIntervalMs: 60_000,
    shutdownGraceMs: 5_000,
    apns: { keyP8: keys.apnsP8, keyId: "KEYID12345", teamId: "TEAMID1234", bundleId: BUNDLE_ID, env: "sandbox", origin: apns.origin, manageOrigin: apns.origin, ca: cert },
    fcm: {
      serviceAccount: { project_id: "test-project", client_email: "worker@test-project.iam.gserviceaccount.com", private_key: keys.fcmPrivate, token_uri: fcm.tokenUri },
      origin: fcm.origin,
      ca: cert,
    },
    anthropicApiKey: null,
    recapModel: "claude-opus-5-5",
    revenuecatWebhookAuth: "Bearer test-webhook-secret",
    moderationWebhookUrl: null,
    fontsDir: path.join(WORKER_ROOT, "fonts"),
  };
  setCopyTable(testCopyTable());
  const { log, lines } = memoryLogger("debug");
  const svc = buildServices(config, { log, db: admin, recapModel: opts.recapModel ?? null });
  const runner = buildRunner(svc);
  const scheduler = buildScheduler(svc, runner);
  return {
    svc,
    runner,
    scheduler,
    apns,
    fcm,
    logs: lines,
    config,
    close: async () => {
      await scheduler.stop();
      await runner.stop(2000);
      svc.push.close();
      await apns.close();
      await fcm.close();
      setCopyTable(null);
    },
  };
}

/** APNs requests to device tokens, decoded. */
export function apnsDeviceSends(apns: MockApns) {
  return apns.requests
    .filter((r) => r.path.startsWith("/3/device/"))
    .map((r) => ({
      token: r.path.slice("/3/device/".length),
      pushType: r.headers["apns-push-type"] as string,
      topic: r.headers["apns-topic"] as string,
      priority: r.headers["apns-priority"] as string | undefined,
      expiration: r.headers["apns-expiration"] as string | undefined,
      collapseId: r.headers["apns-collapse-id"] as string | undefined,
      payload: r.json,
      receivedAt: r.receivedAt,
    }));
}
