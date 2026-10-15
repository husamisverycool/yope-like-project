// Test-only design tokens.
import { TRIBUTE_TOKEN_NAMES } from "../../src/tribute/render.js";

/** Test-only tribute tokens (the real ones come from design research; several are missing). */
export const TEST_TRIBUTE_TOKENS = {
  [TRIBUTE_TOKEN_NAMES.video]: { width: 360, height: 640, fps: 30 },
  [TRIBUTE_TOKEN_NAMES.titleHoldMs]: 1000,
  [TRIBUTE_TOKEN_NAMES.titleCrossfadeMs]: 500,
  [TRIBUTE_TOKEN_NAMES.photoHoldMs]: 1000,
  [TRIBUTE_TOKEN_NAMES.clipTransitionMs]: 0,
  [TRIBUTE_TOKEN_NAMES.endTransitionMs]: 0,
  [TRIBUTE_TOKEN_NAMES.endHoldMs]: 1000,
  [TRIBUTE_TOKEN_NAMES.pillarbox]: "#000000",
  [TRIBUTE_TOKEN_NAMES.titleCard]: { background: "#000000", textColor: "#FFFFFF", fontWeight: 700, fontSizeRatio: 0.05, maxWidthRatio: 0.8, centerYRatio: 0.5 },
  [TRIBUTE_TOKEN_NAMES.endCard]: { background: "#000000", textColor: "#FFFFFF", fontWeight: 400, fontSizeRatio: 0.04, maxWidthRatio: 0.8, centerYRatio: 0.5 },
  [TRIBUTE_TOKEN_NAMES.caption]: { textColor: "#FFFFFF", nameFontWeight: 700, nameFontSizeRatio: 0.035, lineFontWeight: 400, lineFontSizeRatio: 0.03, leftRatio: 0.06, bottomRatio: 0.06, maxWidthRatio: 0.88, gapRatio: 0.01 },
};
