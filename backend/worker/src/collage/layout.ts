// Same-moment collage layout (surface `collage.view`).
//
// Composed only from two references (directive Part 3):
//  - BeReal's dual image: each answer is the back photo at 3:4 with the front photo inset at the
//    top-left (canonical token `daily.dualimage.layout.composition`, design/research/bereal.md §3);
//  - Yope's collage composition, spacing and edges (option B: canonical `collage.view.layout.page`;
//    options A and C: proposals `layout.collage.option{A,C}`, owner review only; design/research/yope-b.md §8).
// The option in production is chosen by the owner (design/collage-options/README.md); the token
// reading is in params.ts.
//
// Pure and deterministic: the same answers and parameters always give the same integer layout.

export interface DualTileParams {
  /** width ÷ height of one answer's main (back) photo (dualimage mainAspect) */
  tileAspect: number;
  /** width ÷ height of the inset (front) photo, border included */
  insetAspect: number;
  /** inset outer width ÷ base tile width */
  insetWidthRatio: number;
  /** inset margin from the tile's top and left ÷ base tile width */
  insetMarginRatio: number;
  /** inset border width ÷ base tile width */
  insetBorderRatio: number;
  /** inset outer corner radius ÷ inset outer width */
  insetOuterRadiusRatio: number;
}

export type OptionParams =
  | { kind: "A"; columns: number; gapRatio: number; outerRadiusRatio: number }
  | { kind: "B"; columns: number; rowsPerPage: number; gapRatio: number; outerRadiusRatio: number; canvasAspect: number }
  | { kind: "C"; columns: number; gapRatio: number; sideInsetRatio: number; tileRadiusRatio: number };

export interface Answer {
  /** whether this answer has a front-camera photo (sequential/single-camera captures may not) */
  hasFront: boolean;
}

export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface InsetLayout {
  /** outer rectangle of the inset, border included */
  outer: Rect;
  border: number;
  outerRadius: number;
  innerRadius: number;
}

export interface TileLayout {
  /** index into the answers array */
  answer: number;
  rect: Rect;
  /** corner radius applied to this tile (0 = square) */
  radius: number;
  inset: InsetLayout | null;
}

export interface PageLayout {
  width: number;
  height: number;
  /** radius of the page's outer corners (0 = square) */
  outerRadius: number;
  tiles: TileLayout[];
}

const r = Math.round;

function inset(tile: Rect, baseWidth: number, dual: DualTileParams): InsetLayout {
  const outerW = r(baseWidth * dual.insetWidthRatio);
  const outerH = r(outerW / dual.insetAspect);
  const margin = r(baseWidth * dual.insetMarginRatio);
  const border = Math.max(1, r(baseWidth * dual.insetBorderRatio));
  const outerRadius = r(outerW * dual.insetOuterRadiusRatio);
  return {
    outer: { x: tile.x + margin, y: tile.y + margin, w: outerW, h: outerH },
    border,
    outerRadius,
    innerRadius: Math.max(0, outerRadius - border),
  };
}

/** Splits `total` px into `parts` integer widths that sum exactly to `total`. */
function split(total: number, parts: number): number[] {
  const out: number[] = [];
  let acc = 0;
  for (let i = 0; i < parts; i++) {
    const next = r(((i + 1) * total) / parts);
    out.push(next - acc);
    acc = next;
  }
  return out;
}

export function layoutCollage(answers: Answer[], option: OptionParams, dual: DualTileParams, width: number): PageLayout[] {
  if (!Number.isInteger(width) || width <= 0) throw new Error("width must be a positive integer");
  const n = answers.length;
  if (n === 0) return [];
  switch (option.kind) {
    case "A":
      return [layoutA(answers, option, dual, width)];
    case "B":
      return layoutB(answers, option, dual, width);
    case "C":
      return [layoutC(answers, option, dual, width)];
  }
}

// Option A — Yope recap card (C1): equal columns, tiles touch, square inner corners, rounded
// outer corners; the row with fewer answers goes first and spans the full width.
function layoutA(answers: Answer[], o: Extract<OptionParams, { kind: "A" }>, dual: DualTileParams, W: number): PageLayout {
  const n = answers.length;
  const colWidths = split(W, o.columns);
  const baseW = W / o.columns;
  const rowH = r(baseW / dual.tileAspect);
  const remainder = n % o.columns;
  const rows: number[] = [];
  if (remainder) rows.push(remainder);
  for (let i = 0; i < Math.floor(n / o.columns); i++) rows.push(o.columns);
  const tiles: TileLayout[] = [];
  let y = 0;
  let k = 0;
  for (const count of rows) {
    const widths = count === o.columns ? colWidths : split(W, count);
    let x = 0;
    for (const w of widths) {
      const rect = { x, y, w, h: rowH };
      tiles.push({ answer: k, rect, radius: 0, inset: answers[k]!.hasFront ? inset(rect, baseW, dual) : null });
      x += w;
      k++;
    }
    y += rowH;
  }
  return { width: W, height: y, outerRadius: r(W * o.outerRadiusRatio), tiles };
}

// Option B — Yope wall pages (C5/C7 9:16 canvas, C1 paging): 3 × 4 tiles of 3:4 fill a 9:16 page.
function layoutB(answers: Answer[], o: Extract<OptionParams, { kind: "B" }>, dual: DualTileParams, W: number): PageLayout[] {
  const H = r(W / o.canvasAspect);
  const perPage = o.columns * o.rowsPerPage;
  const colWidths = split(W, o.columns);
  const rowHeights = split(H, o.rowsPerPage);
  const baseW = W / o.columns;
  const pages: PageLayout[] = [];
  for (let start = 0; start < answers.length; start += perPage) {
    const tiles: TileLayout[] = [];
    for (let i = 0; i < perPage && start + i < answers.length; i++) {
      const col = i % o.columns;
      const row = Math.floor(i / o.columns);
      const x = colWidths.slice(0, col).reduce((a, b) => a + b, 0);
      const y = rowHeights.slice(0, row).reduce((a, b) => a + b, 0);
      const rect = { x, y, w: colWidths[col]!, h: rowHeights[row]! };
      const k = start + i;
      tiles.push({ answer: k, rect, radius: 0, inset: answers[k]!.hasFront ? inset(rect, baseW, dual) : null });
    }
    pages.push({ width: W, height: H, outerRadius: r(W * o.outerRadiusRatio), tiles });
  }
  return pages;
}

// Option C — Yope profile "pics" grid (C3): columns with small gaps, rounded tiles, side insets.
// Top/bottom insets reuse the side inset and a short last row is left-aligned: neither is
// observed in Yope (listed in design/collage-options/README.md).
function layoutC(answers: Answer[], o: Extract<OptionParams, { kind: "C" }>, dual: DualTileParams, W: number): PageLayout {
  const n = answers.length;
  const side = r(W * o.sideInsetRatio);
  const gap = r(W * o.gapRatio);
  const inner = W - 2 * side - (o.columns - 1) * gap;
  const colWidths = split(inner, o.columns);
  const baseW = inner / o.columns;
  const tileH = r(baseW / dual.tileAspect);
  const rows = Math.ceil(n / o.columns);
  const tiles: TileLayout[] = [];
  for (let k = 0; k < n; k++) {
    const col = k % o.columns;
    const row = Math.floor(k / o.columns);
    const x = side + colWidths.slice(0, col).reduce((a, b) => a + b, 0) + col * gap;
    const y = side + row * (tileH + gap);
    const rect = { x, y, w: colWidths[col]!, h: tileH };
    tiles.push({ answer: k, rect, radius: r(rect.w * o.tileRadiusRatio), inset: answers[k]!.hasFront ? inset(rect, baseW, dual) : null });
  }
  const height = 2 * side + rows * tileH + (rows - 1) * gap;
  return { width: W, height, outerRadius: 0, tiles };
}

/** Stable answer order: capture time, then member id. */
export function orderAnswers<T extends { capturedAt: string; userId: string }>(answers: T[]): T[] {
  return [...answers].sort((a, b) => (a.capturedAt === b.capturedAt ? a.userId.localeCompare(b.userId) : a.capturedAt.localeCompare(b.capturedAt)));
}
