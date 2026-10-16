import { describe, expect, it } from "vitest";
import { cardPairs, contrastRatio, desktopPairs, over, relativeLuminance, SPEC_BACKDROP_SAMPLE, statePairs, textKind } from "../../src/contrastReport.js";
import { parseHex } from "../../src/design.js";

const ratio = (pairs: ReturnType<typeof cardPairs>, start: string) => pairs.find((p) => p.element.startsWith(start))!;

describe("WCAG 2.2 arithmetic", () => {
  it("implements the formulas", () => {
    expect(relativeLuminance([255, 255, 255])).toBeCloseTo(1);
    expect(relativeLuminance([0, 0, 0])).toBe(0);
    expect(contrastRatio([0, 0, 0], [255, 255, 255])).toBeCloseTo(21);
    expect(contrastRatio([119, 119, 119], [255, 255, 255])).toBeCloseTo(4.48, 2);
    over([0, 0, 0], 0.8, [255, 255, 255]).forEach((c) => expect(c).toBeCloseTo(51));
  });

  it("classifies large text by WCAG's CSS-px definition", () => {
    expect(textKind(32, 400)).toBe("large");
    expect(textKind(20, 400)).toBe("text");
    expect(textKind(20, 700)).toBe("large");
    expect(textKind(16, 600)).toBe("text");
  });
});

describe("invite page pairs (design/surfaces/invite.web.md Accessibility)", () => {
  it("mobile card over Retro's sampled backdrop #4A1D17 reproduces the spec's table", () => {
    const p = cardPairs(SPEC_BACKDROP_SAMPLE);
    expect(ratio(p, "headline").ratio).toBeCloseTo(14.2, 1);
    expect(ratio(p, "headline").pass).toBe(true);
    expect(ratio(p, "line").ratio).toBeCloseTo(6.3, 1);
    expect(ratio(p, "line").pass).toBe(true);
    expect(ratio(p, "pill fill").pass).toBe(false); // 1.80:1 — reported, not adjusted (the label identifies it)
  });

  it("the line fails over a lighter backdrop (photo-dependent, reported)", () => {
    const line = ratio(cardPairs(parseHex("#8A4A3A").rgb), "line");
    expect(line.ratio).toBeCloseTo(3.67, 1);
    expect(line.pass).toBe(false);
  });

  it("desktop: every text pair passes (owner decision 20 raised Retro's black 50 % lines to 57 %)", () => {
    const p = desktopPairs();
    expect(ratio(p, "headline").ratio).toBeCloseTo(21);
    expect(ratio(p, "line").ratio).toBeCloseTo(5.1, 1);
    expect(ratio(p, "line").pass).toBe(true);
    expect(ratio(p, "footer").pass).toBe(true);
    expect(ratio(p, "'Download the app'").pass).toBe(true);
  });

  it("state card (color.global.backgroundDeep): every text pair passes", () => {
    const p = statePairs();
    for (const pair of p.filter((x) => x.kind !== "nontext")) expect(pair.pass, pair.element).toBe(true);
  });
});
