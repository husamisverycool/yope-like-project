// Collage parameters for production, read from the CANONICAL design tokens only
// (design/tokens/capture.json + global.json → src/generated/tokens.ts; MERGE_DECISIONS capture C-21,
// design/surfaces/collage.view.md "The image", design/surfaces/daily.dualimage.md):
//
//   daily.dualimage.layout.composition  each answer tile (BeReal dual image), mapped to DualTileParams
//   collage.view.layout.page            option B "wall pages", the production fallback, and its width
//   color.global.backgroundDeep         the matte (page corners and empty cells in the JPEGs) and the
//                                       inset border ("a solid border … in color.global.backgroundDeep")
//   collage.share.layout.export         the 9:16 share canvas (share-<n>.jpg)
//
// Options A and C exist only as proposals (design/proposals/collage.tokens.json) until the owner
// chooses (design/collage-options/README.md). Production never reads the proposal file: with
// app_config.collage_option = 'A' or 'C', or with a canonical token or field missing, it throws
// MissingTokenError naming the canonical token (the job fails and retries after the backoff).
// The proposal values are read only by scripts/render-collage-options.ts through
// scripts/collage-proposals.ts.

import { MissingTokenError } from "../errors.js";
import { canonicalToken } from "../tokens.js";
import type { DualTileParams, OptionParams } from "./layout.js";
import type { RenderColors } from "./render.js";

export type CollageOption = "A" | "B" | "C";

export const COLLAGE_TOKENS = {
  dualImage: "daily.dualimage.layout.composition",
  page: "collage.view.layout.page",
  matte: "color.global.backgroundDeep",
  insetBorder: "color.global.backgroundDeep",
  shareExport: "collage.share.layout.export",
} as const;

type Fields = Record<string, unknown>;

function object(name: string): Fields {
  const v = canonicalToken<unknown>(name);
  if (!v || typeof v !== "object" || Array.isArray(v)) throw new MissingTokenError(name, "not an object");
  return v as Fields;
}

function num(name: string, o: Fields, field: string): number {
  const v = o[field];
  if (typeof v !== "number" || !Number.isFinite(v)) throw new MissingTokenError(`${name}.${field}`, "field missing or not a number");
  return v;
}

function color(name: string): string {
  const v = canonicalToken<unknown>(name);
  if (typeof v !== "string" || !/^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/.test(v)) throw new MissingTokenError(name, "not a #RRGGBB[AA] color");
  return v;
}

/**
 * daily.dualimage.layout.composition → DualTileParams. mainRadiusRatio is not used here: inside a
 * collage the tiles touch and only the page has rounded corners (collage.view.md "The image").
 */
export function dualTileParams(): DualTileParams {
  const name = COLLAGE_TOKENS.dualImage;
  const t = object(name);
  return {
    tileAspect: num(name, t, "mainAspect"),
    insetAspect: num(name, t, "insetAspect"),
    insetWidthRatio: num(name, t, "insetWidthRatio"),
    insetMarginRatio: num(name, t, "insetMarginRatio"),
    insetBorderRatio: num(name, t, "insetBorderRatio"),
    insetOuterRadiusRatio: num(name, t, "insetOuterRadiusRatio"),
  };
}

/** The composed layout of `option`; only B has canonical tokens (collage.view.layout.page). */
export function optionParams(option: CollageOption): OptionParams {
  if (option !== "B") {
    throw new MissingTokenError(
      `collage.view.layout.page (option ${option})`,
      `collage option ${option} has no canonical token yet; its values exist only in design/proposals/collage.tokens.json, which production never reads (owner decision, design/collage-options/README.md)`,
    );
  }
  const name = COLLAGE_TOKENS.page;
  const t = object(name);
  return {
    kind: "B",
    columns: num(name, t, "columns"),
    rowsPerPage: num(name, t, "rowsPerPage"),
    gapRatio: num(name, t, "gapRatio"),
    outerRadiusRatio: num(name, t, "outerRadiusRatio"),
    canvasAspect: num(name, t, "canvasAspect"),
  };
}

export function collageColors(): RenderColors {
  return { matte: color(COLLAGE_TOKENS.matte), insetBorder: color(COLLAGE_TOKENS.insetBorder) };
}

/** Collage width in px: the page canvas width (1080, the Stories canvas), so B pages are the share images. */
export function collageWidth(): number {
  const name = COLLAGE_TOKENS.page;
  const w = num(name, object(name), "canvasWidthPx");
  if (!Number.isInteger(w) || w <= 0) throw new MissingTokenError(`${name}.canvasWidthPx`, "not a positive integer");
  return w;
}

/** The 9:16 share canvas in px (collage.share.layout.export). */
export function shareCanvas(): { width: number; height: number } {
  const name = COLLAGE_TOKENS.shareExport;
  const t = object(name);
  return { width: num(name, t, "widthPx"), height: num(name, t, "heightPx") };
}

export interface CollageParams {
  dual: DualTileParams;
  layout: OptionParams;
  colors: RenderColors;
}

/** Everything the compositor needs for `option`, or MissingTokenError (checked before any download). */
export function collageParams(option: CollageOption): CollageParams {
  return { dual: dualTileParams(), layout: optionParams(option), colors: collageColors() };
}
