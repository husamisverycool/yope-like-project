import { describe, expect, it } from "vitest";
import { invitePairs, statePairs, textKind } from "../../src/contrastReport.js";
import { contrastRatio, defaultTheme, over, relativeLuminance, schemeFor, themeFromColour } from "../../src/theme.js";

describe("theme", () => {
  it("implements the WCAG 2.2 formulas", () => {
    expect(relativeLuminance([255, 255, 255])).toBeCloseTo(1);
    expect(relativeLuminance([0, 0, 0])).toBe(0);
    expect(contrastRatio([0, 0, 0], [255, 255, 255])).toBeCloseTo(21);
    expect(contrastRatio([119, 119, 119], [255, 255, 255])).toBeCloseTo(4.48, 2);
    over([0, 0, 0], 0.8, [255, 255, 255]).forEach((c) => expect(c).toBeCloseTo(51));
  });

  it("picks the text colour with the higher contrast", () => {
    // Partiful theme colours observed with their class: #FBEBE4 light, #A7C8FF light, #1C0606 dark (research §5.2).
    expect(schemeFor([0xfb, 0xeb, 0xe4])).toBe("light");
    expect(schemeFor([0xa7, 0xc8, 0xff])).toBe("light");
    expect(schemeFor([0x1c, 0x06, 0x06])).toBe("dark");
    expect(themeFromColour([10, 20, 30])).toEqual({ background: "#0A141E", scheme: "dark" });
  });

  it("defaults to Partiful's default theme (#111111, white text)", () => {
    expect(defaultTheme()).toEqual({ background: "#111111", scheme: "dark" });
  });

  it("classifies large text the WCAG way", () => {
    expect(textKind(39, 700)).toBe("large");
    expect(textKind(18, 700)).toBe("text");
    expect(textKind(24, 400)).toBe("large");
  });

  it("computes every pair of the page; the default theme passes them all", () => {
    for (const p of [...invitePairs(defaultTheme()), ...statePairs()]) expect(p.pass, `${p.element}: ${p.ratio.toFixed(2)}`).toBe(true);
  });

  it("reports (does not fix) failures on mid-tone themes", () => {
    const mid = invitePairs(themeFromColour([0x77, 0x77, 0x77]));
    expect(mid.some((p) => !p.pass)).toBe(true);
  });
});
