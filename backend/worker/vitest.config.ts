import { defineConfig } from "vitest/config";

// Unit tests run without services; handler and integration tests use the local Supabase stack
// (`cd backend && npm run db:start`) and local mock APNs / FCM servers. Files run one at a time:
// they share the database, the job queue and app_config.
export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],
    fileParallelism: false,
    testTimeout: 120_000,
    hookTimeout: 180_000,
    reporters: ["default"],
  },
});
