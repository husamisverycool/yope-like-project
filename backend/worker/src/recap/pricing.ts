// Anthropic per-token prices (USD per million tokens), from the claude-api skill
// (shared/model-migration.md "Migrating to Claude Opus 5.5": $4 / $20 per MTok, 5-minute cache
// writes $5, cache reads $0.20; shared/models.md: Claude Opus 5 and Opus 4.8 at $5 / $25).
// Claude Opus 5 / 4.8 cache prices follow the documented multipliers (writes ≈ 1.25× input,
// reads ≈ 0.1× input; typescript/claude-api/README.md "Verifying Cache Hits").
// They are the possible server-side fallback targets of claude-opus-5-5 ("expect Claude Opus 5 /
// claude-opus-4-8"), so a fallback attempt is priced at its own model's rates.

export interface ModelPrice {
  input: number;
  output: number;
  cacheWrite: number;
  cacheRead: number;
}

export const PRICES: Record<string, ModelPrice> = {
  "claude-opus-5-5": { input: 4, output: 20, cacheWrite: 5, cacheRead: 0.2 },
  "claude-opus-5": { input: 5, output: 25, cacheWrite: 6.25, cacheRead: 0.5 },
  "claude-opus-4-8": { input: 5, output: 25, cacheWrite: 6.25, cacheRead: 0.5 },
};

export interface UsageLine {
  model: string;
  inputTokens: number;
  outputTokens: number;
  cacheWriteTokens: number;
  cacheReadTokens: number;
}

/** USD for one usage line; null when the model's price is unknown. */
export function costUsd(u: UsageLine): number | null {
  const p = PRICES[u.model] ?? PRICES[u.model.replace(/-\d{8}$/, "")];
  if (!p) return null;
  const usd = (u.inputTokens * p.input + u.outputTokens * p.output + u.cacheWriteTokens * p.cacheWrite + u.cacheReadTokens * p.cacheRead) / 1_000_000;
  return Math.round(usd * 1_000_000) / 1_000_000;
}
