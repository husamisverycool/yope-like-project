// Title auto-fit, ported from Partiful's event title component (production JS, server-side branch):
// references/auto/partiful/js/partiful-web-js-excerpt-2026-10-15.txt block [A]. Every number comes
// from the invite.web.*.title tokens; see design/surfaces/invite.web.md "Title".
//
// Partiful measures text with a canvas in the browser and with a character-class estimate on the
// server. This page has no client script, so the server estimate is used, evaluated for every
// column width the page can have and emitted as CSS container-query steps.

import { layout, num } from "./design.js";

interface FitRule {
  widthWide: number;
  widthNormal: number;
  widthThin: number;
  thinCharacters: string;
  normalCharacters: string;
}

const rule = layout<FitRule>("invite.web.layout.title.fit");
const THIN = new Set(rule.thinCharacters.split(""));
const NORMAL = new Set(rule.normalCharacters.split(""));
const BASE = num("invite.web.fontSize.title.base");
const SINGLE_LINE_MAX = num("invite.web.fontSize.title.singleLineMax");
const MIN = num("invite.web.fontSize.title.min");
const MAX_LINES = num("invite.web.count.title.maxLines");

/** Estimated rendered width of `text` at font size `size` (Partiful's server-side estimate). */
export function estimateWidth(text: string, size: number): number {
  let thin = 0;
  let wide = 0;
  // String.prototype.split("") iterates UTF-16 code units, as the reference does.
  for (const ch of text.split("")) {
    if (THIN.has(ch)) thin++;
    else if (!NORMAL.has(ch)) wide++;
  }
  return size * (rule.widthWide * wide + (text.length - wide - thin) * rule.widthNormal + rule.widthThin * thin);
}

/** Greedy line count of `words` in `width` (reference: inner function of T). */
function lineCount(size: number, width: number, words: string[], spaceWidth: number): number {
  let lines = 0;
  let remaining = width;
  for (const word of words) {
    const w = estimateWidth(word, size);
    if (w + spaceWidth > remaining) {
      lines++;
      remaining = width - w;
    } else {
      remaining -= w + spaceWidth;
    }
  }
  return lines + (remaining < width ? 1 : 0);
}

/** Integer binary search returning the lower bound (reference: function O). */
function search(lo: number, hi: number, tooBig: (size: number) => boolean): number {
  for (;;) {
    const mid = Math.floor((hi + lo) / 2);
    if (mid - lo < 1) return lo;
    if (tooBig(mid)) hi = mid;
    else lo = mid;
  }
}

/** Title font size for a column `width` (reference: function T with the mobile flag set). */
export function titleSize(title: string, width: number): number {
  const words = title.trim().split(/\s+/).filter((w) => w.length > 0);
  if (words.length === 0) return MIN;
  const overflows = estimateWidth(title, BASE) > width;
  const maxLines = overflows ? MAX_LINES : 1;
  const upper = overflows ? BASE : SINGLE_LINE_MAX;
  const size = Math.floor(search(MIN, upper, (s) => lineCount(s, width, words, estimateWidth(" ", s)) > maxLines));
  if (size <= MIN) return MIN;
  let widest = 0;
  let widestIndex = 0;
  words.forEach((w, i) => {
    const ww = estimateWidth(w, size);
    if (ww > widest) {
      widest = ww;
      widestIndex = i;
    }
  });
  return widest <= width ? size : Math.floor(search(MIN, size, (s) => estimateWidth(words[widestIndex]!, s) > width));
}

export interface SizeStep {
  /** Smallest column width (CSS px) this size applies to. */
  minWidth: number;
  size: number;
}

/** Sizes for every integer column width in [fromWidth, toWidth], as steps where the size changes. */
export function titleSteps(title: string, fromWidth: number, toWidth: number): SizeStep[] {
  const steps: SizeStep[] = [];
  for (let w = fromWidth; w <= toWidth; w++) {
    const size = titleSize(title, w);
    if (steps.length === 0 || steps[steps.length - 1]!.size !== size) steps.push({ minWidth: w, size });
  }
  return steps;
}
