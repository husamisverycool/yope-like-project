import fs from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { REPO_ROOT } from "../../src/config.js";
import { HANDLERS, WORKER_ENQUEUED_KINDS, lanes } from "../../src/jobs/index.js";
import { isQuietAt, localMidnight, localParts } from "../../src/time.js";
import { checkRecapText, MINIMUM_RULES } from "../../src/recap/validate.js";
import { costUsd } from "../../src/recap/pricing.js";
import { WidgetThrottle } from "../../src/push/throttle.js";
import { DERIVED_RENDITIONS } from "../../src/media/renditions.js";

describe("job registry", () => {
  it("handles every job kind the migrations enqueue", () => {
    const dir = path.join(REPO_ROOT, "backend/supabase/migrations");
    const kinds = new Set<string>();
    for (const f of fs.readdirSync(dir)) {
      const sqlText = fs.readFileSync(path.join(dir, f), "utf8");
      for (const m of sqlText.matchAll(/private\.enqueue\(\s*'([a-z_]+\.[a-z_.]+)'/g)) kinds.add(m[1] as string);
      if (/private\.enqueue_storage_delete\(/.test(sqlText)) kinds.add("storage.delete");
    }
    expect(kinds.size).toBeGreaterThanOrEqual(16);
    for (const k of kinds) expect(HANDLERS[k], k).toBeTypeOf("function");
    for (const k of WORKER_ENQUEUED_KINDS) expect(HANDLERS[k], k).toBeTypeOf("function");
  });

  it("puts every handler in exactly one lane", () => {
    const l = lanes({ lanes: { realtime: { concurrency: 1, pollMs: 1 }, heavy: { concurrency: 1, pollMs: 1 } } });
    const all = l.flatMap((x) => x.kinds);
    expect(new Set(all).size).toBe(all.length);
    expect(all.sort()).toEqual(Object.keys(HANDLERS).sort());
    expect(l.find((x) => x.name === "realtime")!.kinds).toContain("invitation.fire");
  });
});

describe("time zones and quiet hours", () => {
  it("quiet hours are [start, end) in the person's zone and wrap past midnight", () => {
    const at = (iso: string) => new Date(iso);
    // 22:00–07:00 Paris (UTC+2 in October)
    expect(isQuietAt("22:00:00", "07:00:00", "Europe/Paris", at("2026-10-15T20:30:00Z"))).toBe(true);
    expect(isQuietAt("22:00", "07:00", "Europe/Paris", at("2026-10-15T04:59:00Z"))).toBe(true);
    expect(isQuietAt("22:00", "07:00", "Europe/Paris", at("2026-10-15T05:00:00Z"))).toBe(false);
    expect(isQuietAt("13:00", "14:00", "UTC", at("2026-10-15T13:00:00Z"))).toBe(true);
    expect(isQuietAt("13:00", "14:00", "UTC", at("2026-10-15T14:00:00Z"))).toBe(false);
    expect(isQuietAt(null, null, null, at("2026-10-15T14:00:00Z"))).toBe(false);
    expect(isQuietAt("10:00", "10:00", "UTC", at("2026-10-15T10:00:00Z"))).toBe(false);
  });

  it("local midnight across a DST change", () => {
    expect(localMidnight("2026-10-25", "Europe/Paris").toISOString()).toBe("2026-10-24T22:00:00.000Z");
    expect(localMidnight("2026-10-26", "Europe/Paris").toISOString()).toBe("2026-10-25T23:00:00.000Z");
    expect(localParts(new Date("2026-10-15T23:30:00Z"), "Asia/Tokyo")).toMatchObject({ day: 16, hour: 8, isoDow: 5 });
  });
});

describe("recap text copy rules (minimum rules until design/copy-patterns.md has a recap pattern)", () => {
  it("accepts a short lowercase second-person line", () => {
    expect(checkRecapText("you made a quiet week feel close.", MINIMUM_RULES)).toEqual({ ok: true, problems: [] });
  });
  it.each([
    ["You made a week.", "not lowercase"],
    ["the group had a week.", "not second person"],
    ["you posted 12 photos.", "contains a number"],
    ["you kept your streak alive.", 'uses "streak"'],
    ["you missed a few, but still.", 'uses "missed"'],
    ["you were close. you were real.", "more than 1 sentence(s)"],
    ["you shared twice as much.", 'uses "twice"'],
  ])("rejects %s", (text, problem) => {
    expect(checkRecapText(text, MINIMUM_RULES).problems).toContain(problem);
  });
});

describe("AI pricing", () => {
  it("prices Claude Opus 5.5 at $4 / $20 per MTok, cache reads $0.20, writes $5", () => {
    expect(costUsd({ model: "claude-opus-5-5", inputTokens: 1_000_000, outputTokens: 0, cacheReadTokens: 0, cacheWriteTokens: 0 })).toBe(4);
    expect(costUsd({ model: "claude-opus-5-5", inputTokens: 0, outputTokens: 1_000_000, cacheReadTokens: 0, cacheWriteTokens: 0 })).toBe(20);
    expect(costUsd({ model: "claude-opus-5-5", inputTokens: 2000, outputTokens: 300, cacheReadTokens: 1000, cacheWriteTokens: 1000 })).toBe(0.0192);
    expect(costUsd({ model: "claude-opus-5", inputTokens: 1_000_000, outputTokens: 1_000_000, cacheReadTokens: 0, cacheWriteTokens: 0 })).toBe(30);
    expect(costUsd({ model: "unknown-model", inputTokens: 1, outputTokens: 1, cacheReadTokens: 0, cacheWriteTokens: 0 })).toBeNull();
  });
});

describe("widget throttle", () => {
  it("background: two per rolling hour", () => {
    const t = new WidgetThrottle();
    const t0 = 1_000_000;
    t.recordBackground("b", t0);
    expect(t.backgroundNextAt("b", t0 + 1)).toBeNull();
    t.recordBackground("b", t0 + 1);
    expect(t.backgroundNextAt("b", t0 + 2)).toBe(t0 + 3_600_000);
    expect(t.backgroundNextAt("b", t0 + 3_600_001)).toBeNull();
  });
});

describe("rendition sizes", () => {
  it("are derived from the iOS widget sizes at @3x (documented in src/media/renditions.ts)", () => {
    expect(DERIVED_RENDITIONS.widget).toEqual({ width: 1092, height: 1146, fit: "outside" });
    expect(DERIVED_RENDITIONS.thumb).toEqual({ width: 510, height: 510, fit: "outside" });
    expect(DERIVED_RENDITIONS.display).toEqual({ width: 1290, height: 2796, fit: "inside" });
  });
});
