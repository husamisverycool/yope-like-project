// Job runner: polls claim_jobs (FOR UPDATE SKIP LOCKED) per lane, runs handlers by kind with
// bounded concurrency, then complete_job / fail_job (exponential backoff in SQL, docs/API.md §10).
//
// Two lanes keep slow work from delaying time-critical work:
//   realtime — invitation dispatch, pushes, widget refreshes
//   heavy    — renditions, collages, tribute videos, recaps, year stories, storage/auth deletion
// Handlers are idempotent: a job may run twice (lock expiry, crash before complete_job).

import { errorMessage, isRetryable } from "./errors.js";
import { rpc } from "./db.js";
import type { Handler, Services } from "./services.js";
import type { JobRow } from "./types.js";

export interface LaneSpec {
  name: string;
  kinds: string[];
  concurrency: number;
  pollMs: number;
}

interface LaneState {
  spec: LaneSpec;
  inflight: Set<Promise<unknown>>;
  wake: (() => void) | null;
  timers: Set<NodeJS.Timeout>;
  loop: Promise<void> | null;
  lastClaimAt: number | null;
  lastError: string | null;
}

export interface RunnerStats {
  running: boolean;
  lanes: Record<string, { inflight: number; lastClaimAt: string | null; lastError: string | null }>;
  completed: number;
  failed: number;
}

export class Runner {
  private lanes: LaneState[];
  private running = false;
  private completed = 0;
  private failed = 0;
  private active = new Map<number, { kind: string; startedAt: number }>();

  constructor(
    private readonly svc: Services,
    private readonly handlers: Record<string, Handler>,
    lanes: LaneSpec[],
  ) {
    const covered = new Set(lanes.flatMap((l) => l.kinds));
    for (const k of Object.keys(handlers)) if (!covered.has(k)) throw new Error(`handler ${k} is in no lane`);
    for (const k of covered) if (!handlers[k]) throw new Error(`lane kind ${k} has no handler`);
    this.lanes = lanes.map((spec) => ({ spec, inflight: new Set(), wake: null, timers: new Set(), loop: null, lastClaimAt: null, lastError: null }));
  }

  get kinds(): string[] {
    return this.lanes.flatMap((l) => l.spec.kinds);
  }

  start(): void {
    if (this.running) return;
    this.running = true;
    for (const lane of this.lanes) lane.loop = this.laneLoop(lane);
    this.svc.log.info("runner started", { worker_id: this.svc.config.workerId, lanes: this.lanes.map((l) => ({ name: l.spec.name, concurrency: l.spec.concurrency, kinds: l.spec.kinds.length })) });
  }

  /** Wake a lane (or all) now, e.g. after enqueueing work. */
  wake(laneName?: string): void {
    for (const l of this.lanes) if (!laneName || l.spec.name === laneName) l.wake?.();
  }

  /** Wake the lane that runs `kind` at `at` (scheduler: invitation dispatch exactly at fires_at). */
  wakeAt(at: Date, kind: string): void {
    const lane = this.lanes.find((l) => l.spec.kinds.includes(kind));
    if (!lane || !this.running) return;
    const delay = Math.max(0, at.getTime() - Date.now());
    if (delay > 10 * 60_000) return;
    const t = setTimeout(() => {
      lane.timers.delete(t);
      lane.wake?.();
    }, delay);
    lane.timers.add(t);
  }

  private async laneLoop(lane: LaneState): Promise<void> {
    while (this.running) {
      const free = lane.spec.concurrency - lane.inflight.size;
      let claimed = 0;
      if (free > 0) {
        try {
          const jobs = await this.claim(lane.spec.kinds, free);
          lane.lastClaimAt = Date.now();
          lane.lastError = null;
          claimed = jobs.length;
          for (const job of jobs) {
            const p = this.execute(job).finally(() => {
              lane.inflight.delete(p);
              lane.wake?.();
            });
            lane.inflight.add(p);
          }
        } catch (e) {
          lane.lastError = errorMessage(e);
          this.svc.log.error("claim_jobs failed", { lane: lane.spec.name, error: e });
        }
      }
      if (claimed > 0 && claimed === free) continue; // more may be due
      await new Promise<void>((resolve) => {
        const t = setTimeout(done, lane.spec.pollMs);
        function done() {
          clearTimeout(t);
          lane.wake = null;
          resolve();
        }
        lane.wake = done;
      });
    }
  }

  private async claim(kinds: string[], limit: number): Promise<JobRow[]> {
    return rpc<JobRow[]>(this.svc.db, "claim_jobs", { p_worker_id: this.svc.config.workerId, p_kinds: kinds, p_limit: limit });
  }

  /** Runs one claimed job and records its outcome. Never throws. */
  async execute(job: JobRow): Promise<"done" | "retry" | "failed"> {
    const log = this.svc.log.child({ job_id: job.id, kind: job.kind, attempt: job.attempts });
    const handler = this.handlers[job.kind];
    const started = Date.now();
    this.active.set(job.id, { kind: job.kind, startedAt: started });
    try {
      if (!handler) throw new Error(`no handler for ${job.kind}`);
      await handler({ ...this.svc, log, job });
      const ok = await rpc<boolean>(this.svc.db, "complete_job", { p_job_id: job.id, p_worker_id: this.svc.config.workerId });
      if (!ok) log.warn("job completed but its lock was lost (another worker may re-run it)");
      log.info("job done", { duration_ms: Date.now() - started });
      this.completed++;
      return "done";
    } catch (e) {
      const retry = isRetryable(e);
      this.failed++;
      try {
        const row = await rpc<JobRow & { run_at: string }>(this.svc.db, "fail_job", {
          p_job_id: job.id,
          p_worker_id: this.svc.config.workerId,
          p_error: errorMessage(e).slice(0, 2000),
          p_retry: retry,
        });
        log[row.status === "failed" ? "error" : "warn"]("job failed", {
          duration_ms: Date.now() - started,
          error: e,
          status: row.status,
          retry_at: row.status === "queued" ? row.run_at : undefined,
        });
        return row.status === "queued" ? "retry" : "failed";
      } catch (e2) {
        log.error("fail_job failed", { error: e2, original_error: e });
        return "failed";
      }
    } finally {
      this.active.delete(job.id);
    }
  }

  /**
   * Claims and runs due jobs until none is left (tests and one-off runs). Lanes run their
   * claimed batches concurrently.
   */
  async runUntilIdle(opts: { maxRounds?: number; kinds?: string[] } = {}): Promise<number> {
    let total = 0;
    for (let round = 0; round < (opts.maxRounds ?? 200); round++) {
      const batches = await Promise.all(
        this.lanes.map(async (lane) => {
          const kinds = opts.kinds ? lane.spec.kinds.filter((k) => opts.kinds!.includes(k)) : lane.spec.kinds;
          if (!kinds.length) return 0;
          const jobs = await this.claim(kinds, Math.max(1, lane.spec.concurrency));
          await Promise.all(jobs.map((j) => this.execute(j)));
          return jobs.length;
        }),
      );
      const n = batches.reduce((a, b) => a + b, 0);
      total += n;
      if (n === 0) break;
    }
    return total;
  }

  stats(): RunnerStats {
    return {
      running: this.running,
      lanes: Object.fromEntries(
        this.lanes.map((l) => [l.spec.name, { inflight: l.inflight.size, lastClaimAt: l.lastClaimAt ? new Date(l.lastClaimAt).toISOString() : null, lastError: l.lastError }]),
      ),
      completed: this.completed,
      failed: this.failed,
    };
  }

  /**
   * Graceful shutdown: stop claiming, let in-flight jobs finish for up to `graceMs`, then hand
   * the unfinished ones back to the queue (fail_job with retry) so another worker can take them.
   */
  async stop(graceMs: number): Promise<void> {
    if (!this.running) return;
    this.running = false;
    for (const l of this.lanes) {
      for (const t of l.timers) clearTimeout(t);
      l.timers.clear();
      l.wake?.();
    }
    await Promise.all(this.lanes.map((l) => l.loop));
    const inflight = this.lanes.flatMap((l) => [...l.inflight]);
    const finished = await Promise.race([
      Promise.all(inflight).then(() => true),
      new Promise<boolean>((r) => setTimeout(() => r(false), graceMs).unref()),
    ]);
    if (!finished) {
      for (const [id, a] of this.active) {
        try {
          await rpc(this.svc.db, "fail_job", { p_job_id: id, p_worker_id: this.svc.config.workerId, p_error: "worker shutdown", p_retry: true });
          this.svc.log.warn("job handed back on shutdown", { job_id: id, kind: a.kind });
        } catch (e) {
          this.svc.log.error("could not hand back job on shutdown", { job_id: id, error: e });
        }
      }
    }
    this.svc.log.info("runner stopped", { finished_in_grace: finished });
  }
}
