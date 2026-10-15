// Wires configuration into services, runner, scheduler and HTTP server.

import Anthropic from "@anthropic-ai/sdk";
import type { WorkerConfig } from "./config.js";
import { createDb, type Db } from "./db.js";
import { HANDLERS, lanes } from "./jobs/index.js";
import { createLogger, type Logger } from "./log.js";
import { ApnsClient } from "./push/apns.js";
import { FcmClient } from "./push/fcm.js";
import { PushService } from "./push/service.js";
import { WidgetThrottle } from "./push/throttle.js";
import { AnthropicRecapModel, type RecapModel } from "./recap/ai.js";
import { Runner, type ClaimFn } from "./runner.js";
import { Scheduler } from "./scheduler.js";
import type { Services } from "./services.js";
import { Storage } from "./storage.js";

export interface BuildOptions {
  log?: Logger;
  db?: Db;
  recapModel?: RecapModel | null;
  now?: () => Date;
}

export function buildServices(config: WorkerConfig, opts: BuildOptions = {}): Services {
  const log = opts.log ?? createLogger({ level: config.logLevel, base: { service: "worker", worker_id: config.workerId } });
  const db = opts.db ?? createDb(config.supabaseUrl, config.serviceRoleKey);
  const apns = config.apns ? new ApnsClient(config.apns) : null;
  const fcm = config.fcm ? new FcmClient(config.fcm) : null;
  if (!apns) log.warn("APNs not configured (APNS_KEY_P8 unset): iOS pushes are skipped");
  if (!fcm) log.warn("FCM not configured (FCM_SERVICE_ACCOUNT_JSON unset): Android pushes are skipped");
  let recapModel: RecapModel | null = null;
  if (opts.recapModel !== undefined) recapModel = opts.recapModel;
  else if (config.anthropicApiKey) recapModel = new AnthropicRecapModel(new Anthropic({ apiKey: config.anthropicApiKey }), config.recapModel);
  else log.info("ANTHROPIC_API_KEY unset: recaps use the deterministic order and the template text");
  return {
    config,
    db,
    storage: new Storage(db),
    log,
    push: new PushService(apns, fcm, db, log),
    throttle: new WidgetThrottle(),
    recapModel,
    now: opts.now ?? (() => new Date()),
  };
}

export function buildRunner(svc: Services, opts: { claim?: ClaimFn } = {}): Runner {
  return new Runner(svc, HANDLERS, lanes(svc.config), opts);
}

export function buildScheduler(svc: Services, runner: Runner | null): Scheduler {
  return new Scheduler(svc, runner, svc.config.schedulerIntervalMs);
}
