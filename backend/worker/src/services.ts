// What every job handler can use.

import type { WorkerConfig } from "./config.js";
import { rpc, type Db } from "./db.js";
import type { Logger } from "./log.js";
import type { PushService } from "./push/service.js";
import type { WidgetThrottle } from "./push/throttle.js";
import type { RecapModel } from "./recap/ai.js";
import type { Storage } from "./storage.js";
import type { JobRow } from "./types.js";
import { PermanentError } from "./errors.js";

export interface Services {
  config: WorkerConfig;
  db: Db;
  storage: Storage;
  log: Logger;
  push: PushService;
  throttle: WidgetThrottle;
  /** null when ANTHROPIC_API_KEY is not set: recaps use the deterministic order and template text */
  recapModel: RecapModel | null;
  now(): Date;
}

export interface JobContext extends Services {
  job: JobRow;
}

export type Handler = (ctx: JobContext) => Promise<void>;

export interface EnqueueOptions {
  runAt?: Date;
  dedupeKey?: string;
  maxAttempts?: number;
}

export async function enqueue(db: Db, kind: string, payload: Record<string, unknown>, opts: EnqueueOptions = {}): Promise<number> {
  return rpc<number>(db, "enqueue_job", {
    p_kind: kind,
    p_payload: payload,
    p_run_at: opts.runAt?.toISOString() ?? null,
    p_max_attempts: opts.maxAttempts ?? 5,
    p_dedupe_key: opts.dedupeKey ?? null,
  });
}

export function str(payload: Record<string, unknown>, key: string): string {
  const v = payload[key];
  if (typeof v !== "string" || v === "") throw new PermanentError(`payload.${key} missing`);
  return v;
}

export function optStr(payload: Record<string, unknown>, key: string): string | null {
  const v = payload[key];
  return typeof v === "string" && v !== "" ? v : null;
}
