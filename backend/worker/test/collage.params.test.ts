// Production collage parameters come from the canonical tokens only (MERGE_DECISIONS capture C-21):
// daily.dualimage.layout.composition, collage.view.layout.page, color.global.backgroundDeep,
// collage.share.layout.export. The proposal file is never a fallback.
import fs from "node:fs";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { tokens } from "../src/generated/tokens.js";
import { MissingTokenError } from "../src/errors.js";
import { canonicalToken, designToken, setTokenOverrides } from "../src/tokens.js";
import { COLLAGE_TOKENS, collageColors, collageParams, collageWidth, dualTileParams, optionParams, shareCanvas } from "../src/collage/params.js";
import { composeCollage } from "../src/collage/pipeline.js";
import { WORKER_ROOT } from "../src/config.js";
import { sampleAnswers } from "./fixtures/answers.js";

const T = tokens as Record<string, any>;

afterEach(() => setTokenOverrides(null));

describe("collage params (production)", () => {
  it("map the canonical tokens: dual image, option B page, matte and inset border, share canvas", () => {
    const d = T["daily.dualimage.layout.composition"];
    expect(dualTileParams()).toEqual({
      tileAspect: d.mainAspect,
      insetAspect: d.insetAspect,
      insetWidthRatio: d.insetWidthRatio,
      insetMarginRatio: d.insetMarginRatio,
      insetBorderRatio: d.insetBorderRatio,
      insetOuterRadiusRatio: d.insetOuterRadiusRatio,
    });
    const p = T["collage.view.layout.page"];
    expect(optionParams("B")).toEqual({ kind: "B", columns: p.columns, rowsPerPage: p.rowsPerPage, gapRatio: p.gapRatio, outerRadiusRatio: p.outerRadiusRatio, canvasAspect: p.canvasAspect });
    expect(collageWidth()).toBe(p.canvasWidthPx);
    expect(collageColors()).toEqual({ matte: T["color.global.backgroundDeep"], insetBorder: T["color.global.backgroundDeep"] });
    const e = T["collage.share.layout.export"];
    expect(shareCanvas()).toEqual({ width: e.widthPx, height: e.heightPx });
    // the page is the 9:16 share canvas, so option B pages are the share images
    expect(Math.round(collageWidth() / optionParams("B").kind.length / p.canvasAspect)).toBe(e.heightPx);
  });

  it.each(["daily.dualimage.layout.composition", "collage.view.layout.page", "color.global.backgroundDeep"])(
    "fails with MissingTokenError(%s) when the canonical token is missing, although the proposal file has a value",
    (name) => {
      expect(designToken("layout.collage.optionB")).toBeTruthy(); // the proposal exists …
      setTokenOverrides({ [name]: null });
      expect(() => collageParams("B")).toThrow(MissingTokenError);
      expect(() => collageParams("B")).toThrow(`missing design token ${name}`); // … and is not used
    },
  );

  it("names a missing field of a canonical token", () => {
    const { insetAspect: _drop, ...rest } = T["daily.dualimage.layout.composition"];
    setTokenOverrides({ "daily.dualimage.layout.composition": rest });
    expect(() => dualTileParams()).toThrow("missing design token daily.dualimage.layout.composition.insetAspect");
  });

  it.each(["A", "C"] as const)("option %s has no canonical token: MissingTokenError, the proposal is not read", async (option) => {
    expect(() => collageParams(option)).toThrow(MissingTokenError);
    expect(() => collageParams(option)).toThrow(`collage option ${option} has no canonical token yet`);
    await expect(composeCollage(await sampleAnswers(2), option, 360)).rejects.toThrow(MissingTokenError);
  });

  it("canonicalToken never falls back to design/proposals (designToken does)", () => {
    expect(designToken("layout.collage.dualTile")).toBeTruthy();
    expect(() => canonicalToken("layout.collage.dualTile")).toThrow(/design\/proposals is not read/);
    expect(canonicalToken(COLLAGE_TOKENS.page)).toEqual(T["collage.view.layout.page"]);
  });

  it("no production source reads the collage proposal names or file", () => {
    const dir = path.join(WORKER_ROOT, "src");
    const files = fs.readdirSync(dir, { recursive: true, encoding: "utf8" }).filter((f) => f.endsWith(".ts") && !f.startsWith("generated"));
    expect(files.length).toBeGreaterThan(20);
    for (const f of files) {
      const code = fs.readFileSync(path.join(dir, f), "utf8");
      expect(code, f).not.toMatch(/["'`](layout\.collage\.|color\.collage\.|dimension\.collage\.)/);
      expect(code, f).not.toMatch(/collage\.tokens\.json|collage-proposals/);
    }
  });
});
