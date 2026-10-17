// The job runner against the real queue (claim_jobs / complete_job / fail_job).
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { buildServices } from "../../src/app.js";
import { MissingCopyError, PermanentError } from "../../src/errors.js";
import { memoryLogger } from "../../src/log.js";
import { Runner } from "../../src/runner.js";
import type { Handler } from "../../src/services.js";
import { admin, closeDb, rpc, sql, sleep, waitFor } from "../helpers/db.js";
import { startWorld, type World } from "../helpers/world.js";

let w: World;
const k = (s: string) => `wtest.${s}_${Math.random().toString(36).slice(2, 7)}`;

beforeAll(async () => {
  w = await startWorld();
});
afterAll(async () => {
  await w.close();
  await closeDb();
});

function runnerWith(handlers: Record<string, Handler>, concurrency = 2) {
  const { log, lines } = memoryLogger();
  const svc = { ...buildServices(w.config, { log, db: admin, recapModel: null }) };
  const runner = new Runner(svc, handlers, [{ name: "test", kinds: Object.keys(handlers), concurrency, pollMs: 50 }]);
  return { runner, lines };
}

async function job(id: number) {
  return (await sql(`select * from public.jobs where id = $1`, [id]))[0];
}

describe("runner", () => {
  it("completes successful jobs; retries failures with backoff; never retries a permanent failure", async () => {
    const ok = k("ok");
    const flaky = k("flaky");
    const perm = k("perm");
    const copy = k("copy");
    const { runner, lines } = runnerWith({
      [ok]: async () => undefined,
      [flaky]: async () => {
        throw new Error("network blip");
      },
      [perm]: async () => {
        throw new PermanentError("bad payload");
      },
      [copy]: async () => {
        throw new MissingCopyError("notifications.push.newPost.title");
      },
    });
    const ids = await Promise.all([ok, flaky, perm, copy].map((kind) => rpc<number>(admin, "enqueue_job", { p_kind: kind })));
    runner.start();
    await waitFor(async () => (await Promise.all(ids.map(job))).every((j) => j.status !== "queued" || j.attempts > 0) && runner.stats().completed + runner.stats().failed >= 4);
    await runner.stop(1000);
    const [a, b, c, d] = await Promise.all(ids.map(job));
    expect(a.status).toBe("done");
    expect(b.status).toBe("queued");
    expect(b.attempts).toBe(1);
    expect(b.last_error).toContain("network blip");
    const delay = (new Date(b.run_at).getTime() - Date.now()) / 1000;
    expect(delay).toBeGreaterThan(20);
    expect(delay).toBeLessThanOrEqual(31);
    expect(c.status).toBe("failed");
    expect(d.status).toBe("queued");
    expect(d.last_error).toContain("missing copy key notifications.push.newPost.title");
    expect(lines.some((l) => l.msg === "job done" && l.kind === ok && typeof l.duration_ms === "number")).toBe(true);
    await sql(`update public.jobs set status = 'cancelled' where id = any($1)`, [ids]);
  });

  it("runs at most `concurrency` jobs of a lane at once", async () => {
    const slow = k("slow");
    let running = 0;
    let peak = 0;
    const { runner } = runnerWith({
      [slow]: async () => {
        running++;
        peak = Math.max(peak, running);
        await sleep(150);
        running--;
      },
    }, 2);
    const ids = await Promise.all(Array.from({ length: 6 }, () => rpc<number>(admin, "enqueue_job", { p_kind: slow })));
    runner.start();
    await waitFor(async () => (await Promise.all(ids.map(job))).every((j) => j.status === "done"), 15_000);
    await runner.stop(1000);
    expect(peak).toBe(2);
  });

  it("graceful shutdown hands an unfinished job back to the queue", async () => {
    const stuck = k("stuck");
    const { runner, lines } = runnerWith({ [stuck]: () => new Promise(() => undefined) });
    const id = await rpc<number>(admin, "enqueue_job", { p_kind: stuck });
    runner.start();
    await waitFor(async () => (await job(id)).status === "running");
    await runner.stop(300);
    const j = await job(id);
    expect(j.status).toBe("queued");
    expect(j.attempts).toBe(0); // release_job spends no attempt
    expect(j.last_error).toBe("released: worker shutdown");
    expect(new Date(j.run_at).getTime()).toBeLessThanOrEqual(Date.now() + 1000);
    expect(lines.some((l) => l.msg === "job handed back on shutdown")).toBe(true);
    await sql(`update public.jobs set status = 'cancelled' where id = $1`, [id]);
  });

  it("wakeAt runs a due job at its time instead of the next poll", async () => {
    const timed = k("timed");
    let ranAt = 0;
    const svc = buildServices(w.config, { db: admin, log: memoryLogger().log, recapModel: null });
    const runner = new Runner(svc, { [timed]: async () => void (ranAt = Date.now()) }, [{ name: "rt", kinds: [timed], concurrency: 1, pollMs: 30_000 }]);
    const at = new Date(Date.now() + 1500);
    await rpc(admin, "enqueue_job", { p_kind: timed, p_run_at: at.toISOString() });
    runner.start();
    runner.wakeAt(at, timed);
    await waitFor(() => ranAt > 0, 10_000);
    await runner.stop(500);
    expect(ranAt - at.getTime()).toBeGreaterThanOrEqual(-50);
    expect(ranAt - at.getTime()).toBeLessThan(1500);
  });

  it("wakeAt still runs the job on time when the first claim at `at` finds it not yet due (database clock a little behind)", async () => {
    const timed = k("skewed");
    let ranAt = 0;
    const svc = buildServices(w.config, { db: admin, log: memoryLogger().log, recapModel: null });
    const at = new Date(Date.now() + 1500);
    const real = (kinds: string[], limit: number) => rpc<any[]>(admin, "claim_jobs", { p_worker_id: w.config.workerId, p_kinds: kinds, p_limit: limit });
    // the database sees the job as due only 30 ms after the worker's clock says `at`
    const claim = async (kinds: string[], limit: number) => (Date.now() < at.getTime() + 30 ? [] : real(kinds, limit));
    const runner = new Runner(svc, { [timed]: async () => void (ranAt = Date.now()) }, [{ name: "rt", kinds: [timed], concurrency: 1, pollMs: 30_000 }], { claim });
    await rpc(admin, "enqueue_job", { p_kind: timed, p_run_at: at.toISOString() });
    runner.start();
    runner.wakeAt(at, timed);
    await waitFor(() => ranAt > 0, 10_000);
    await runner.stop(500);
    expect(ranAt).toBeGreaterThan(0);
    expect(ranAt - at.getTime()).toBeLessThan(1500);
  });
});
