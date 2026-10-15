// HTTP: GET /healthz (liveness + readiness) and POST /webhooks/revenuecat.

import http from "node:http";
import type { Db } from "./db.js";
import type { Logger } from "./log.js";
import { handleRevenueCat } from "./revenuecat.js";
import type { Runner } from "./runner.js";
import type { Scheduler } from "./scheduler.js";

const MAX_BODY = 1024 * 1024;

export interface HttpDeps {
  db: Db;
  log: Logger;
  workerId: string;
  revenuecatAuth: string | null;
  runner?: Runner | null;
  scheduler?: Scheduler | null;
  schedulerIntervalMs?: number;
}

function send(res: http.ServerResponse, status: number, body: unknown): void {
  const s = JSON.stringify(body);
  res.writeHead(status, { "content-type": "application/json", "content-length": Buffer.byteLength(s) });
  res.end(s);
}

function readBody(req: http.IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    const parts: Buffer[] = [];
    let size = 0;
    req.on("data", (c: Buffer) => {
      size += c.length;
      if (size > MAX_BODY) {
        reject(new Error("body too large"));
        req.destroy();
        return;
      }
      parts.push(c);
    });
    req.on("end", () => resolve(Buffer.concat(parts).toString("utf8")));
    req.on("error", reject);
  });
}

export function health(deps: HttpDeps): { ok: boolean; body: Record<string, unknown> } {
  const stats = deps.runner?.stats();
  const interval = deps.schedulerIntervalMs ?? 60_000;
  const lastTick = deps.scheduler?.lastTickAt ?? null;
  const schedulerOk = !deps.scheduler || (lastTick !== null && Date.now() - lastTick < 3 * interval) || (lastTick === null && process.uptime() * 1000 < 3 * interval);
  const runnerOk = !deps.runner || !!stats?.running;
  return {
    ok: schedulerOk && runnerOk,
    body: {
      status: schedulerOk && runnerOk ? "ok" : "degraded",
      worker_id: deps.workerId,
      uptime_s: Math.round(process.uptime()),
      runner: stats ?? null,
      scheduler: deps.scheduler ? { last_tick_at: lastTick ? new Date(lastTick).toISOString() : null, last_tick: deps.scheduler.lastTick } : null,
    },
  };
}

export function createHttpServer(deps: HttpDeps): http.Server {
  return http.createServer(async (req, res) => {
    const url = new URL(req.url ?? "/", "http://localhost");
    try {
      if (req.method === "GET" && (url.pathname === "/healthz" || url.pathname === "/health")) {
        const h = health(deps);
        send(res, h.ok ? 200 : 503, h.body);
        return;
      }
      if (url.pathname === "/webhooks/revenuecat") {
        if (req.method !== "POST") {
          send(res, 405, { error: "method not allowed" });
          return;
        }
        const body = await readBody(req);
        const out = await handleRevenueCat(deps.db, deps.log, req.headers.authorization, deps.revenuecatAuth, body);
        send(res, out.status, out.body);
        return;
      }
      send(res, 404, { error: "not found" });
    } catch (e) {
      deps.log.error("http request failed", { path: url.pathname, error: e });
      if (!res.headersSent) send(res, 500, { error: "internal" });
    }
  });
}
