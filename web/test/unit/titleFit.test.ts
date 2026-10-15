import { describe, expect, it } from "vitest";
import { tokens } from "../../src/design.js";
import { estimateWidth, titleSize, titleSteps } from "../../src/titleFit.js";

describe("title auto-fit (Partiful's server-side rule)", () => {
  // Computed font-size of span.summary on the three captured pages, column 358 px:
  // P3 'Fun Times w/ the Ryans', P1 'Tompkins Square Dog Parade', P2 'Secret Saturday: Halloween' → 39 px.
  it.each(["Fun Times w/ the Ryans", "Tompkins Square Dog Parade", "Secret Saturday: Halloween"])("reproduces the reference size for %s", (title) => {
    expect(titleSize(title, 358)).toBe(39);
  });

  it("uses the character classes of the reference estimate", () => {
    expect(estimateWidth("i", 10)).toBeCloseTo(4); // thin
    expect(estimateWidth("a", 10)).toBeCloseTo(7); // normal
    expect(estimateWidth("W", 10)).toBeCloseTo(9); // wide
    expect(estimateWidth(" ", 10)).toBeCloseTo(4);
  });

  it("stays within the token bounds", () => {
    const min = tokens["invite.web.fontSize.title.min"];
    const max = tokens["invite.web.fontSize.title.singleLineMax"];
    for (const t of ["A", "Lima family", "The Very Long Group Name For The Whole Extended Family Reunion 2026 Edition", "Ünïcödé 家族 👨‍👩‍👧"]) {
      for (const w of [120, 288, 343, 358, 688]) {
        const s = titleSize(t, w);
        expect(s).toBeGreaterThanOrEqual(min);
        expect(s).toBeLessThan(max);
      }
    }
    expect(titleSize("The Very Long Group Name For The Whole Extended Family Reunion 2026 Edition", 358)).toBe(min);
  });

  it("emits ascending width steps that agree with titleSize", () => {
    const steps = titleSteps("Lima family", 0, 688);
    for (let i = 1; i < steps.length; i++) expect(steps[i]!.minWidth).toBeGreaterThan(steps[i - 1]!.minWidth);
    const at = (w: number) => [...steps].reverse().find((s) => s.minWidth <= w)!.size;
    for (const w of [0, 100, 288, 343, 358, 500, 688]) expect(at(w)).toBe(titleSize("Lima family", w));
  });
});
