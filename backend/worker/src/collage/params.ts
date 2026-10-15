// Collage parameters, read from the design tokens (never written here).
// Until design/tokens.json carries the collage tokens, they are read from
// design/proposals/collage.tokens.json, which holds the same traced values.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { DualTileParams, OptionParams } from "./layout.js";
import { tokens } from "../generated/tokens.js";

type TokenMap = Record<string, unknown>;

function proposalTokens(): TokenMap {
  const here = path.dirname(fileURLToPath(import.meta.url));
  const file = path.resolve(here, "../../../../design/proposals/collage.tokens.json");
  if (!fs.existsSync(file)) return {};
  const json = JSON.parse(fs.readFileSync(file, "utf8")) as { tokens: Record<string, { value: unknown }> };
  return Object.fromEntries(Object.entries(json.tokens).map(([k, v]) => [k, v.value]));
}

export interface CollageParams {
  dual: DualTileParams;
  options: { A: OptionParams; B: OptionParams; C: OptionParams };
  colors: { matte: string; insetBorder: string };
}

export function collageParams(): CollageParams {
  const t: TokenMap = { ...proposalTokens(), ...(tokens as TokenMap) };
  const need = <T>(name: string): T => {
    if (!(name in t)) throw new Error(`missing design token ${name}`);
    return t[name] as T;
  };
  const a = need<{ columns: number; gapRatio: number; outerRadiusRatio: number }>("layout.collage.optionA");
  const b = need<{ columns: number; rowsPerPage: number; gapRatio: number; outerRadiusRatio: number; canvasAspect: number }>("layout.collage.optionB");
  const c = need<{ columns: number; gapRatio: number; sideInsetRatio: number; tileRadiusRatio: number }>("layout.collage.optionC");
  return {
    dual: need<DualTileParams>("layout.collage.dualTile"),
    options: { A: { kind: "A", ...a }, B: { kind: "B", ...b }, C: { kind: "C", ...c } },
    colors: { matte: need<string>("color.collage.matte"), insetBorder: need<string>("color.collage.insetBorder") },
  };
}
