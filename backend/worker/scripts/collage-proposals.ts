// Owner review only (scripts/render-collage-options.ts and the layout/render tests): the three
// collage options side by side. Option B is the production layout from the canonical tokens
// (src/collage/params.ts); options A and C exist only in design/proposals/collage.tokens.json
// until the owner chooses (design/collage-options/README.md, MERGE_DECISIONS capture C-21).
// Nothing under src/ imports this file (asserted in test/collage.params.test.ts).

import fs from "node:fs";
import path from "node:path";
import { REPO_ROOT } from "../src/config.js";
import { optionParams } from "../src/collage/params.js";
import type { OptionParams } from "../src/collage/layout.js";

export const PROPOSAL_FILE = path.join(REPO_ROOT, "design/proposals/collage.tokens.json");

type Proposal = { value: unknown; level?: string };

function proposal<T>(name: string): T {
  const json = JSON.parse(fs.readFileSync(PROPOSAL_FILE, "utf8")) as { tokens: Record<string, Proposal> };
  const t = json.tokens[name];
  if (!t || t.level === "BLOCKED" || t.value === null || t.value === undefined) throw new Error(`proposal token ${name} missing in ${PROPOSAL_FILE}`);
  return t.value as T;
}

/** A and C from the proposal file, B from the canonical tokens (as production composes it). */
export function reviewOptions(): { A: OptionParams; B: OptionParams; C: OptionParams } {
  const a = proposal<{ columns: number; gapRatio: number; outerRadiusRatio: number }>("layout.collage.optionA");
  const c = proposal<{ columns: number; gapRatio: number; sideInsetRatio: number; tileRadiusRatio: number }>("layout.collage.optionC");
  return {
    A: { kind: "A", columns: a.columns, gapRatio: a.gapRatio, outerRadiusRatio: a.outerRadiusRatio },
    B: optionParams("B"),
    C: { kind: "C", columns: c.columns, gapRatio: c.gapRatio, sideInsetRatio: c.sideInsetRatio, tileRadiusRatio: c.tileRadiusRatio },
  };
}
