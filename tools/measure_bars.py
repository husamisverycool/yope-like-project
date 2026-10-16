#!/usr/bin/env python3
"""Measure the bars of a voice-note waveform in a reference image (owner decision 16, C-36).

Usage: python3 -I tools/measure_bars.py IMAGE x0 y0 x1 y1 --bg r,g,b --ink r,g,b [--thr N]

A column belongs to a bar when one of its pixels differs from the background (--bg) by more than
--thr on the channel where background and ink (--ink, a bar's core colour) differ most. Runs of such
columns are bars. For each bar the script reports
  - width by coverage: the sum over its columns (±1 px margin) of (bg − pixel) / (bg − ink), averaged
    over the bar's middle third (anti-aliased edges count by their coverage);
  - height by coverage on the bar's centre column;
then the median width, the pitch (first to last coverage centroid / (n − 1)), the span and the
height range. Divide by the image's px/pt (stated with each measurement) to get points.
"""
import sys
from PIL import Image


def main(argv):
    path = argv[0]
    x0, y0, x1, y1 = map(int, argv[1:5])
    opt = lambda name, default=None: argv[argv.index(name) + 1] if name in argv else default
    bg = tuple(int(v) for v in opt('--bg').split(','))
    ink = tuple(int(v) for v in opt('--ink').split(','))
    thr = int(opt('--thr', '25'))
    im = Image.open(path).convert('RGB')
    px = im.load()
    ch = max(range(3), key=lambda k: abs(bg[k] - ink[k]))
    cov = lambda c: max(0.0, min(1.0, (bg[ch] - c[ch]) / (bg[ch] - ink[ch])))
    hit = lambda c: abs(c[ch] - bg[ch]) > thr
    cols = [any(hit(px[x, y]) for y in range(y0, y1)) for x in range(x0, x1)]
    bars, x = [], 0
    while x < len(cols):
        if cols[x]:
            s = x
            while x < len(cols) and cols[x]:
                x += 1
            bars.append((x0 + s, x0 + x - 1))
        else:
            x += 1
    rows = []
    for l, r in bars:
        ys = [y for y in range(y0, y1) if any(hit(px[xx, y]) for xx in range(l, r + 1))]
        t, b = min(ys), max(ys)
        mid = range(t + (b - t) // 3, b - (b - t) // 3 + 1)
        w = sum(sum(cov(px[xx, y]) for xx in range(l - 1, r + 2)) for y in mid) / len(mid)
        c = sum(sum(cov(px[xx, y]) * xx for xx in range(l - 1, r + 2)) for y in mid) / len(mid) / max(w, 1e-6)
        h = sum(cov(px[int(round(c)), y]) for y in range(t - 1, b + 2))
        rows.append((l, r, w, c, h))
    for l, r, w, c, h in rows:
        print('bar x %4d-%4d  width %.2f  centre %.1f  height %.1f' % (l, r, w, c, h))
    n = len(rows)
    if n:
        ws = sorted(row[2] for row in rows)
        hs = sorted(row[4] for row in rows)
        print('bars %d  width median %.2f  height min %.1f max %.1f' % (n, ws[n // 2], hs[0], hs[-1]))
    if n > 1:
        print('pitch %.3f  span %d px' % ((rows[-1][3] - rows[0][3]) / (n - 1), rows[-1][1] - rows[0][0] + 1))


if __name__ == '__main__':
    main(sys.argv[1:])
