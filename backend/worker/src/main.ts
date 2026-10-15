// Worker entry point: job runner + scheduler + HTTP (health, RevenueCat webhook).
// SIGTERM / SIGINT: stop accepting work, finish or hand back in-flight jobs, then exit.

import { buildRunner, buildScheduler, buildServices } from "./app.js";
import { loadConfig } from "./config.js";
import { createHttpServer } from "./http.js";

async function main(): Promise<void> {
  const config = loadConfig();
  const svc = buildServices(config);
  const runner = buildRunner(svc);
  const scheduler = buildScheduler(svc, runner);
  const server = createHttpServer({
    db: svc.db,
    log: svc.log,
    workerId: config.workerId,
    revenuecatAuth: config.revenuecatWebhookAuth,
    runner,
    scheduler,
    schedulerIntervalMs: config.schedulerIntervalMs,
  });
  await new Promise<void>((resolve) => server.listen(config.port, resolve));
  svc.log.info("http listening", { port: config.port });
  runner.start();
  scheduler.start();

  let stopping = false;
  const shutdown = async (signal: string) => {
    if (stopping) return;
    stopping = true;
    svc.log.info("shutting down", { signal });
    await scheduler.stop();
    await runner.stop(config.shutdownGraceMs);
    await new Promise<void>((resolve) => server.close(() => resolve()));
    svc.push.close();
    process.exit(0);
  };
  process.on("SIGTERM", () => void shutdown("SIGTERM"));
  process.on("SIGINT", () => void shutdown("SIGINT"));
  process.on("unhandledRejection", (e) => svc.log.error("unhandled rejection", { error: e }));
}

main().catch((e) => {
  process.stderr.write(`worker failed to start: ${(e as Error).stack ?? e}\n`);
  process.exit(1);
});
