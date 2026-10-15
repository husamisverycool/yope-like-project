"""Pixel measurements on the account snapshots (393 x 852 dp rendered at 2 px/dp, no system-bar insets).

Every helper takes and returns dp. A colour predicate is `near("#RRGGBB", tol)`; `bright(t)` matches
any pixel whose brightest channel exceeds t (text ink on black).
"""
import os

from PIL import Image

SCALE = 2.0
W, H = 393.0, 852.0
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
SNAP = os.path.join(ROOT, "android", "feature", "account", "src", "test", "snapshots")

_cache = {}


def snap(name):
    if name not in _cache:
        _cache[name] = Image.open(os.path.join(SNAP, name + ".png")).convert("RGB")
    return _cache[name]


def rgb(hexs):
    h = hexs.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hexof(p):
    return "#%02X%02X%02X" % p[:3]


def near(hexs, tol=6):
    c = rgb(hexs)
    return lambda p: max(abs(p[0] - c[0]), abs(p[1] - c[1]), abs(p[2] - c[2])) <= tol


def bright(t=128):
    return lambda p: max(p[:3]) > t


def not_(pred):
    return lambda p: not pred(p)


def color_at(img, x, y):
    return hexof(img.getpixel((min(int(x * SCALE), img.width - 1), min(int(y * SCALE), img.height - 1))))


def _runs(values):
    runs, start = [], None
    for i, v in enumerate(values):
        if v and start is None:
            start = i
        elif not v and start is not None:
            runs.append((start, i))
            start = None
    if start is not None:
        runs.append((start, len(values)))
    return runs


def col_runs(img, x, pred, y0=0, y1=H, min_len=1.0):
    """Vertical runs of pixels matching pred in column x, as (top, bottom) dp."""
    px = int(x * SCALE)
    a, b = int(y0 * SCALE), min(int(y1 * SCALE), img.height)
    vals = [pred(img.getpixel((px, y))) for y in range(a, b)]
    return [((s + a) / SCALE, (e + a) / SCALE) for s, e in _runs(vals) if (e - s) / SCALE >= min_len]


def row_runs(img, y, pred, x0=0, x1=W, min_len=1.0):
    """Horizontal runs of pixels matching pred in row y, as (left, right) dp."""
    py = int(y * SCALE)
    a, b = int(x0 * SCALE), min(int(x1 * SCALE), img.width)
    vals = [pred(img.getpixel((x, py))) for x in range(a, b)]
    return [((s + a) / SCALE, (e + a) / SCALE) for s, e in _runs(vals) if (e - s) / SCALE >= min_len]


def extent(img, pred, box=(0, 0, W, H)):
    """Bounding box (left, top, right, bottom) dp of the pixels matching pred inside box; None if none."""
    x0, y0, x1, y1 = (int(v * SCALE) for v in box)
    x1, y1 = min(x1, img.width), min(y1, img.height)
    l = t = 10 ** 9
    r = b = -1
    for y in range(y0, y1):
        for x in range(x0, x1):
            if pred(img.getpixel((x, y))):
                l, t, r, b = min(l, x), min(t, y), max(r, x), max(b, y)
    if r < 0:
        return None
    return (l / SCALE, t / SCALE, (r + 1) / SCALE, (b + 1) / SCALE)


def fill_box(img, x, y, tol=4):
    """The rectangle of the flat fill under (x, y): left/right along row y, top/bottom along column x."""
    c = img.getpixel((int(x * SCALE), int(y * SCALE)))
    pred = near(hexof(c), tol)
    rows = [r for r in row_runs(img, y, pred) if r[0] <= x <= r[1]]
    cols = [r for r in col_runs(img, x, pred) if r[0] <= y <= r[1]]
    (l, r), (t, b) = rows[0], cols[0]
    return {"left": l, "top": t, "right": r, "bottom": b, "width": r - l, "height": b - t, "color": hexof(c)}


def corner_radius(img, box, bg_hex):
    """Corner radius of a rounded fill: where its edge crosses the 45-degree line from the top-left corner.

    For a circular corner of radius r that crossing sits r * (1 - 1/sqrt 2) in from both edges; the
    crossing is found to sub-pixel precision from the anti-aliased coverage along the diagonal.
    """
    fill, bg = rgb(box["color"]), rgb(bg_hex)
    d = [f - g for f, g in zip(fill, bg)]
    dd = sum(v * v for v in d) or 1
    L, T = int(round(box["left"] * SCALE)), int(round(box["top"] * SCALE))

    def cov(i):
        p = img.getpixel((L + i, T + i))
        return sum((p[k] - bg[k]) * d[k] for k in range(3)) / dd

    prev = cov(0)
    if prev >= 0.5:
        return 0.0
    for i in range(1, 200):
        c = cov(i)
        if c >= 0.5:
            t = (i - 1 + 0.5) + (0.5 - prev) / ((c - prev) or 1)
            return t / (1 - 2 ** -0.5) / SCALE
        prev = c
    return None
