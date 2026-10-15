import { describe, expect, it } from "vitest";
import { layoutCollage, orderAnswers, type OptionParams, type DualTileParams, type Rect } from "../src/collage/layout.js";
import { dualTileParams } from "../src/collage/params.js";
import { reviewOptions } from "../scripts/collage-proposals.js";

// B = canonical collage.view.layout.page (production); A and C = owner-review proposals
const dual = dualTileParams();
const options = reviewOptions();
const W = 1080;

function overlaps(a: Rect, b: Rect) {
  return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
}
function inside(inner: Rect, outer: Rect) {
  return inner.x >= outer.x && inner.y >= outer.y && inner.x + inner.w <= outer.x + outer.w && inner.y + inner.h <= outer.y + outer.h;
}

describe.each(Object.entries(options))("option %s", (_name, option: OptionParams) => {
  for (let n = 1; n <= 30; n++) {
    it(`lays out ${n} answer(s) with every answer exactly once, inside the page, without overlap`, () => {
      const answers = Array.from({ length: n }, (_, i) => ({ hasFront: i % 4 !== 3 }));
      const pages = layoutCollage(answers, option, dual as DualTileParams, W);
      const seen = pages.flatMap((p) => p.tiles.map((t) => t.answer)).sort((a, b) => a - b);
      expect(seen).toEqual(Array.from({ length: n }, (_, i) => i));
      for (const page of pages) {
        expect(page.width).toBe(W);
        const pageRect = { x: 0, y: 0, w: page.width, h: page.height };
        for (const [i, t] of page.tiles.entries()) {
          expect(Number.isInteger(t.rect.x) && Number.isInteger(t.rect.y) && Number.isInteger(t.rect.w) && Number.isInteger(t.rect.h)).toBe(true);
          expect(inside(t.rect, pageRect)).toBe(true);
          for (const other of page.tiles.slice(i + 1)) expect(overlaps(t.rect, other.rect)).toBe(false);
          if (t.inset) {
            expect(answers[t.answer]!.hasFront).toBe(true);
            expect(inside(t.inset.outer, t.rect)).toBe(true);
            expect(t.inset.innerRadius).toBeLessThanOrEqual(t.inset.outerRadius);
          } else {
            expect(answers[t.answer]!.hasFront).toBe(false);
          }
        }
      }
      // deterministic
      expect(layoutCollage(answers, option, dual as DualTileParams, W)).toEqual(pages);
    });
  }
});

describe("geometry traced to the references", () => {
  it("dual tile inset follows BeReal's ratios (0.31 width, 0.03 margin, 3:4)", () => {
    const [page] = layoutCollage([{ hasFront: true }, { hasFront: true }, { hasFront: true }], options.A, dual as DualTileParams, W);
    const t = page!.tiles[0]!;
    expect(t.rect.w).toBe(360);
    expect(t.rect.h).toBe(480); // 3:4
    expect(t.inset!.outer.w).toBe(Math.round(360 * 0.31));
    expect(t.inset!.outer.x - t.rect.x).toBe(Math.round(360 * 0.03));
    expect(t.inset!.outer.y - t.rect.y).toBe(Math.round(360 * 0.03));
  });

  it("option A: tiles touch (0 gap) and fill the width; the short row goes first and spans the width", () => {
    const [page] = layoutCollage(Array.from({ length: 8 }, () => ({ hasFront: true })), options.A, dual as DualTileParams, W);
    const firstRow = page!.tiles.filter((t) => t.rect.y === 0);
    expect(firstRow).toHaveLength(2);
    expect(firstRow.reduce((a, t) => a + t.rect.w, 0)).toBe(W);
    expect(page!.height).toBe(3 * 480);
  });

  it("option B: 3 × 4 tiles of 3:4 fill a 9:16 page exactly; 13+ answers continue on a second page", () => {
    const pages = layoutCollage(Array.from({ length: 13 }, () => ({ hasFront: true })), options.B, dual as DualTileParams, W);
    expect(pages).toHaveLength(2);
    expect(pages[0]!.height).toBe(1920);
    expect(pages[0]!.tiles).toHaveLength(12);
    for (const t of pages[0]!.tiles) expect(t.rect.h / t.rect.w).toBeCloseTo(4 / 3, 2);
  });

  it("option C: three columns separated by the measured gap", () => {
    const [page] = layoutCollage(Array.from({ length: 3 }, () => ({ hasFront: true })), options.C, dual as DualTileParams, W);
    const [a, b] = page!.tiles;
    expect(b!.rect.x - (a!.rect.x + a!.rect.w)).toBe(Math.round(W * 0.01018));
    expect(a!.rect.x).toBe(Math.round(W * 0.06107));
  });

  it("orders answers by capture time, then member id", () => {
    const ordered = orderAnswers([
      { capturedAt: "2026-10-15T12:00:05Z", userId: "b" },
      { capturedAt: "2026-10-15T12:00:01Z", userId: "z" },
      { capturedAt: "2026-10-15T12:00:05Z", userId: "a" },
    ]);
    expect(ordered.map((a) => a.userId)).toEqual(["z", "a", "b"]);
  });
});
