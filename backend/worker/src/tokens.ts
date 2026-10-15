// Design tokens for the worker, read by name at runtime.
//
// Order: the generated canonical tokens (src/generated/tokens.ts ← design/tokens.json; BLOCKED
// values are never generated), then — until a value is merged — the research proposals in
// design/proposals/*.tokens.json, skipping BLOCKED or null values (the same policy as
// src/collage/params.ts). A value proposed differently by two research passes counts as missing.
// A missing token throws MissingTokenError("missing design token <name>"): the job fails and is
// retried later. Nothing here invents a value.
// canonicalToken() reads the generated canonical tokens only (no proposal fallback); the collage
// compositor uses it (MERGE_DECISIONS capture C-21).

import fs from "node:fs";
import path from "node:path";
import { tokens as generatedTokens } from "./generated/tokens.js";
import { MissingTokenError } from "./errors.js";
import { REPO_ROOT } from "./config.js";

type TokenMap = Record<string, unknown>;

let overrides: TokenMap | null = null;
let proposals: Map<string, { value: unknown; files: string[]; conflict: boolean }> | null = null;

/**
 * Tests layer values over the real sources (a name mapped to null reads as missing);
 * null removes the layer.
 */
export function setTokenOverrides(t: TokenMap | null): void {
  overrides = t;
}

function loadProposals(): Map<string, { value: unknown; files: string[]; conflict: boolean }> {
  if (proposals) return proposals;
  const out = new Map<string, { value: unknown; files: string[]; conflict: boolean }>();
  const dir = path.join(process.env.DESIGN_DIR ?? path.join(REPO_ROOT, "design"), "proposals");
  if (fs.existsSync(dir)) {
    for (const f of fs.readdirSync(dir).sort()) {
      if (!f.endsWith(".tokens.json")) continue;
      const json = JSON.parse(fs.readFileSync(path.join(dir, f), "utf8")) as {
        tokens?: Record<string, { value?: unknown; level?: string }>;
      };
      for (const [name, t] of Object.entries(json.tokens ?? {})) {
        if (t.level === "BLOCKED" || t.value === null || t.value === undefined) continue;
        const prev = out.get(name);
        if (!prev) out.set(name, { value: t.value, files: [f], conflict: false });
        else {
          prev.files.push(f);
          if (JSON.stringify(prev.value) !== JSON.stringify(t.value)) prev.conflict = true;
        }
      }
    }
  }
  proposals = out;
  return out;
}

export function tokenSource(name: string): "override" | "canonical" | "proposal" | null {
  if (overrides && name in overrides) return overrides[name] === null ? null : "override";
  if (name in (generatedTokens as TokenMap)) return "canonical";
  const p = loadProposals().get(name);
  return p && !p.conflict ? "proposal" : null;
}

/** The value of design token `name`, or MissingTokenError. */
export function designToken<T>(name: string): T {
  if (overrides && name in overrides) {
    if (overrides[name] === null || overrides[name] === undefined) throw new MissingTokenError(name);
    return overrides[name] as T;
  }
  const canonical = generatedTokens as TokenMap;
  if (name in canonical) return canonical[name] as T;
  const p = loadProposals().get(name);
  if (!p) throw new MissingTokenError(name);
  if (p.conflict) throw new MissingTokenError(name, `proposals disagree: ${p.files.join(", ")}`);
  return p.value as T;
}

/**
 * The value of canonical design token `name` (src/generated/tokens.ts ← design/tokens/*.json),
 * never a proposal value: MissingTokenError when the canonical tokens do not carry it.
 */
export function canonicalToken<T>(name: string): T {
  if (overrides && name in overrides) {
    if (overrides[name] === null || overrides[name] === undefined) throw new MissingTokenError(name);
    return overrides[name] as T;
  }
  const canonical = generatedTokens as TokenMap;
  if (!(name in canonical)) {
    throw new MissingTokenError(name, "not in the canonical tokens design/tokens/*.json → src/generated/tokens.ts; design/proposals is not read here");
  }
  return canonical[name] as T;
}

export function hasToken(name: string): boolean {
  try {
    designToken(name);
    return true;
  } catch {
    return false;
  }
}
