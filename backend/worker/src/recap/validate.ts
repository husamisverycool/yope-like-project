// Copy rules for AI-drafted recap text. The voice pattern for recap text belongs in
// design/copy-patterns.md; when that file contains a fenced block tagged `recap-text-rules`
// (JSON, keys below), those rules apply. Until then the minimum rules of the brief apply:
// lowercase, second person, short (one sentence), no counts, streak or guilt language.

import fs from "node:fs";
import path from "node:path";
import { REPO_ROOT } from "../config.js";

export interface RecapTextRules {
  lowercase: boolean;
  secondPerson: boolean;
  maxSentences: number;
  /** integrity bound of weekly_recaps.text */
  maxChars: number;
  /** words/phrases that may not appear (case-insensitive, whole words) */
  banned: string[];
  noDigits: boolean;
}

export const MINIMUM_RULES: RecapTextRules = {
  lowercase: true,
  secondPerson: true,
  maxSentences: 1,
  maxChars: 2000,
  noDigits: true,
  banned: [
    // counts
    "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
    "twenty", "thirty", "hundred", "thousand", "dozen", "dozens", "once", "twice", "times", "number", "count", "most", "least",
    // streaks
    "streak", "streaks", "in a row", "every day", "everyday", "daily", "straight",
    // guilt / obligation / lateness
    "late", "missed", "miss", "forgot", "forget", "behind", "catch up", "should", "didn't", "did not", "haven't", "have not",
    "hurry", "last chance", "only", "don't", "lazy",
  ],
};

let cached: { rules: RecapTextRules; source: string } | null = null;

export function recapTextRules(): { rules: RecapTextRules; source: string } {
  if (cached) return cached;
  const file = path.join(process.env.DESIGN_DIR ?? path.join(REPO_ROOT, "design"), "copy-patterns.md");
  if (fs.existsSync(file)) {
    const m = /```(?:json)?\s*recap-text-rules\s*\n([\s\S]*?)```/.exec(fs.readFileSync(file, "utf8"));
    if (m?.[1]) {
      const parsed = JSON.parse(m[1]) as Partial<RecapTextRules>;
      cached = { rules: { ...MINIMUM_RULES, ...parsed }, source: "design/copy-patterns.md" };
      return cached;
    }
  }
  cached = { rules: MINIMUM_RULES, source: "minimum rules (design/copy-patterns.md has no recap-text-rules block)" };
  return cached;
}

export function resetRecapRulesCache(): void {
  cached = null;
}

const escape = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

export function checkRecapText(text: string, rules: RecapTextRules = recapTextRules().rules): { ok: boolean; problems: string[] } {
  const problems: string[] = [];
  const t = text.trim();
  if (!t) problems.push("empty");
  if (t.length > rules.maxChars) problems.push("too long");
  if (/[\r\n]/.test(t)) problems.push("line break");
  if (rules.lowercase && t !== t.toLocaleLowerCase()) problems.push("not lowercase");
  if (rules.secondPerson && !/\b(you|your|yours|yourselves|you're|you’re|y'all|y’all)\b/i.test(t)) problems.push("not second person");
  const sentences = t.split(/[.!?…]+(?:\s+|$)/).filter((s) => s.trim() !== "");
  if (sentences.length > rules.maxSentences) problems.push(`more than ${rules.maxSentences} sentence(s)`);
  if (rules.noDigits && /\p{Nd}/u.test(t)) problems.push("contains a number");
  const normalized = t.toLocaleLowerCase().replace(/’/g, "'");
  for (const w of rules.banned) {
    if (new RegExp(`(^|[^\\p{L}'])${escape(w.toLocaleLowerCase())}($|[^\\p{L}'])`, "u").test(normalized)) problems.push(`uses "${w}"`);
  }
  return { ok: problems.length === 0, problems };
}
