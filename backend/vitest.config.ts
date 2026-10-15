import { defineConfig } from 'vitest/config';

// Integration tests against the local Supabase stack (`npm run db:start`).
// Files run one at a time: some tests change shared app_config tunables.
export default defineConfig({
  test: {
    include: ['tests/**/*.test.ts'],
    fileParallelism: false,
    testTimeout: 60_000,
    hookTimeout: 120_000,
    reporters: ['default'],
  },
});
