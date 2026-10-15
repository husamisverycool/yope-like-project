import { defineConfig } from "vitest/config";

// Unit tests (test/unit) use an in-memory Supabase stand-in. Integration tests (test/integration)
// run against the local Supabase stack: cd backend && npm run db:start (set WEB_SKIP_INTEGRATION=1
// to leave them out where no stack exists).
export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],
    exclude: process.env.WEB_SKIP_INTEGRATION ? ["test/integration/**"] : [],
    testTimeout: 30_000,
    hookTimeout: 60_000,
    fileParallelism: false,
  },
});
