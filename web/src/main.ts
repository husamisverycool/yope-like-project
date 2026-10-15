// Entry point. Production refuses to start while any copy string or config value the pages need is
// BLOCKED; development starts anyway, lists what is missing, and renders visible markers.

import { serve } from "@hono/node-server";
import type { Context } from "hono";
import { createApp } from "./app.js";
import { loadConfig } from "./config.js";
import { InviteService } from "./inviteService.js";
import { startupProblems } from "./startup.js";
import { supabaseUpstream } from "./supabase.js";

// The Supabase CLI's fixed local-development values (also in backend/tests/helpers.ts); used only
// in development when no environment is given, so `npm run dev` works against `npm run db:start`.
const LOCAL_STACK = {
  url: "http://127.0.0.1:54321",
  anonKey:
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0",
  serviceRoleKey:
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU",
};

function main() {
  const config = loadConfig();
  if (!config.supabase && config.mode === "development") {
    config.supabase = LOCAL_STACK;
    console.warn(`development: no SUPABASE_* environment; using the local stack at ${LOCAL_STACK.url}`);
  }
  const problems = startupProblems(config);
  if (problems.length && config.mode === "production") {
    console.error(`refusing to start in production; missing:\n  - ${problems.join("\n  - ")}`);
    process.exit(1);
  }
  if (problems.length) console.warn(`BLOCKED (shown as markers / omitted in ${config.mode}):\n  - ${problems.join("\n  - ")}`);

  const invites = config.supabase
    ? new InviteService(supabaseUpstream({ ...config.supabase, timeoutMs: config.upstreamTimeoutMs }), {
        ttlSeconds: config.inviteCacheSeconds,
        signedUrlSeconds: config.signedUrlSeconds,
        log: (m) => console.warn(m),
      })
    : null;
  const app = createApp({
    config,
    invites,
    peer: (c: Context) => (c.env as { incoming?: { socket?: { remoteAddress?: string } } } | undefined)?.incoming?.socket?.remoteAddress,
  });
  const server = serve({ fetch: app.fetch, port: config.port }, (info) => console.log(`web listening on :${info.port} (${config.mode})`));
  const stop = () => server.close(() => process.exit(0));
  process.on("SIGTERM", stop);
  process.on("SIGINT", stop);
}

main();
