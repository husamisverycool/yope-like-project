"""Per-surface inputs of checklists.py (Pass 4, Retro redesign): what the surface is, which of our renders face which
Retro reference, and the pixel measurements taken on our renders (dp; see measure.py). Expected values are read from
the token files, so a token change shows up here as a MISS until the screen follows it.

Renders: `android/feature/account/src/test/snapshots/<surface>/<state>-<light|dark>.png` (393 x 852 dp at 2 px/dp, no
system-bar insets: the safe-area top is the render's top edge).
"""
import json
import os

import measure as M
from measure import color_at, corner_radius, fill_box, near, snap

_T = {}
for _n in ("global", "capture", "account", "social", "memory", "invite"):
    with open(os.path.join(M.ROOT, "design", "tokens", _n + ".json")) as _f:
        _T.update(json.load(_f)["tokens"])


def t(key, sub=None):
    v = _T[key]["value"]
    return v[sub] if sub is not None else v


RETRO = "references/auto/retro/"
LAND = RETRO + "lazyweb/retro-lazyweb-20251119-social.png"
H43 = RETRO + "lazyweb/retro-lazyweb-20251020-week43-dark.png"
VIDSET = RETRO + "video/ig-DJXvmqRv2_N-referrals-sheet-f042-059.png"
W34 = RETRO + "apk/widget_preview_friends.webp"
EDW3 = RETRO + "store/editorial/retro-appstore-story-1854931006-week3-albums.png"
TCJ1 = RETRO + "press/tc-2024-04-journals-1.webp"
JED = RETRO + "press/jeddacp-2024-05-home-profile-journals.png"
TCJ5 = RETRO + "press/tc-2024-04-retro-journals-5.png"
TC1B = RETRO + "press/tc-2023-07-retro-1b.webp"
TCRWP = RETRO + "press/tc-2025-12-rewind-panels.png"
PAY = RETRO + "lazyweb/retro-lazyweb-20260529-paywall.png"
WEBU = RETRO + "web/retro.app-u-nathan-iphone.png"
ST01 = RETRO + "store/retro-store-01.png"

LIGHT_PAGE = t("color.global.background.android")["light"]
DARK_PAGE = t("color.global.background.android")["dark"]


def dark_ink(p):
    return max(p[:3]) < 110


def light_ink(p):
    return min(p[:3]) > 150


def line_box(img, box, ink):
    """(left, top, right, baseline) of the first text line inside box: baseline = the last row of the line whose ink
    count is at least a quarter of the line's densest row (descender rows fall under that)."""
    x0, y0, x1, y1 = (int(v * M.SCALE) for v in box)
    x1, y1 = min(x1, img.width), min(y1, img.height)
    counts = []
    for y in range(y0, y1):
        counts.append(sum(1 for x in range(x0, x1) if ink(img.getpixel((x, y)))))
    start = next((i for i, c in enumerate(counts) if c), None)
    if start is None:
        return None
    end = start
    while end < len(counts) and counts[end]:
        end += 1
    peak = max(counts[start:end])
    base = max(i for i in range(start, end) if counts[i] >= peak / 4)
    xs = [x for y in range(y0 + start, y0 + end) for x in range(x0, x1) if ink(img.getpixel((x, y)))]
    return (min(xs) / M.SCALE, (y0 + start) / M.SCALE, (max(xs) + 1) / M.SCALE, (y0 + base + 1) / M.SCALE)


def fill_extent(img, hexc, y, tol=3, x0=0, x1=M.W, min_w=200):
    """The flat fill of hexc crossing row y: height = the tallest clean column run between 10 % and 90 % of its width
    (text on the fill breaks some columns, not all); left / right = the outermost matching pixels on the row through the
    middle of that run (so rounded corners do not narrow it)."""
    pred = near(hexc, tol)

    def row_span(py, coverage=0.6):
        xs = [x for x in range(int(x0 * M.SCALE), min(int(x1 * M.SCALE), img.width)) if pred(img.getpixel((x, py)))]
        if not xs or (xs[-1] - xs[0]) / M.SCALE < min_w:
            return None
        # A fill covers most of its span (text on it is a small part); scattered matches (a photo's highlights) do not.
        return (xs[0], xs[-1] + 1) if len(xs) >= coverage * (xs[-1] + 1 - xs[0]) else None

    py = int(y * M.SCALE)
    span = row_span(py)
    if not span:
        return None
    l, r = span
    best = None
    for x in range(l + (r - l) // 10, r - (r - l) // 10, max(1, (r - l) // 80)):
        if not pred(img.getpixel((x, py))):
            continue
        a = b = py
        while a > 0 and pred(img.getpixel((x, a - 1))):
            a -= 1
        while b < img.height - 1 and pred(img.getpixel((x, b + 1))):
            b += 1
        if best is None or b - a > best[1] - best[0]:
            best = (a, b)
    if best is None:
        return None
    t, bt = best
    # The edges on the middle row (its text may cover much of it: no coverage test there).
    mid = row_span((t + bt) // 2, coverage=0) or span
    l, r = mid
    return {"left": l / M.SCALE, "right": r / M.SCALE, "top": t / M.SCALE, "bottom": (bt + 1) / M.SCALE,
            "width": (r - l) / M.SCALE, "height": (bt + 1 - t) / M.SCALE, "color": M.hexof(img.getpixel((l + 6, (t + bt) // 2)))}


def wide_fill(img, hexc, y0=0, y1=M.H, min_w=200, tol=3, x0=0, x1=M.W):
    """The first fill of hexc (scanning down from y0) at least min_w dp wide."""
    y = y0
    while y < y1:
        b = fill_extent(img, hexc, y, tol, x0, x1, min_w)
        if b:
            return fill_extent(img, hexc, min(y + 2, (y + y1) / 2), tol, x0, x1, min_w) or b
        y += 0.5
    return None


def wide_fill_up(img, hexc, y1=M.H, y0=0, min_w=200, tol=3):
    """As wide_fill, scanning up from y1 (the fill nearest the bottom)."""
    y = y1 - 0.5
    while y > y0:
        b = fill_extent(img, hexc, y, tol, min_w=min_w)
        if b:
            return fill_extent(img, hexc, y - 2, tol, min_w=min_w) or b
        y -= 0.5
    return None


def capsule_rows(label, img, fill_hex, page_hex, bottom=None, y1=M.H):
    """C-05 capsule rows: height, side insets, corner radius, fill (+ the gap to the bottom when asked)."""
    b = wide_fill_up(img, fill_hex, y1=y1, min_w=250)
    if b is None:
        return [(f"{label}: capsule found", "size.global.buttonHeight", t("size.global.buttonHeight"), None)]
    rows = [
        (f"{label} height", "size.global.buttonHeight", t("size.global.buttonHeight"), b["height"]),
        (f"{label} side inset", "size.global.buttonMarginH", t("size.global.buttonMarginH"), b["left"]),
        (f"{label} corner radius", "radius.global.button", t("radius.global.button"), corner_radius(img, b, page_hex), {"tol": 1.5}),
        (f"{label} fill", "color.global.accent", fill_hex, b["color"]),
    ]
    if bottom:
        rows.append((f"{label} bottom gap", bottom, t(bottom), M.H - b["bottom"]))
    return rows


def form_title_rows(img, page_hex, ink):
    """Onboarding form title (C-33 form): leading inset and baseline below the safe-area top."""
    line = line_box(img, (0, 34, 393, 120), ink)
    return [
        ("title baseline below the safe-area top", "size.global.titleTop", t("size.global.titleTop"), line[3] if line else None, {"tol": 1.5}),
        ("title leading inset (ink)", "size.global.screenMargin", t("size.global.screenMargin"), line[0] if line else None, {"tol": 2.0, "note": "the first glyph's side bearing (≈ 1 dp) is inside the measure"}),
        ("page", "color.global.background.android", page_hex, color_at(img, 2, 430)),
    ]


def field_rows(img, y0, y1=600):
    b = wide_fill(img, t("color.global.control")["light"], y0, y1, min_w=300)
    if b is None:
        return [("field found", "size.global.fieldHeight", t("size.global.fieldHeight"), None)]
    return [
        ("field height", "size.global.fieldHeight", t("size.global.fieldHeight"), b["height"]),
        ("field side inset", "size.global.screenMargin", t("size.global.screenMargin"), b["left"]),
        ("field corner radius", "radius.global.field", t("radius.global.field"), corner_radius(img, b, LIGHT_PAGE), {"tol": 1.5}),
        ("field fill", "color.global.control", t("color.global.control")["light"], b["color"]),
    ]


def grouped_rows(img, page_hex, fill_hex, y0=60, label="grouped row"):
    """The first C-14 group under y0: side inset, single-row height, radius, fill."""
    b = wide_fill(img, fill_hex, y0, 800, min_w=300, tol=2)
    if b is None:
        return [(f"{label} found", "settings.root.size.rowHeight", t("settings.root.size.rowHeight"), None)]
    return [
        (f"{label} side inset", "size.global.screenMargin", t("size.global.screenMargin"), b["left"]),
        (f"{label} corner radius", "radius.global.groupedRow", t("radius.global.groupedRow"), corner_radius(img, b, page_hex), {"tol": 1.5}),
        (f"{label} fill", "color.global.surfaceSecondary.android", fill_hex, b["color"]),
    ], b


def sheet_title_rows(img, ink):
    """C-29 page sheet: the centred title's cap middle on the close / back circle's centre line."""
    line = line_box(img, (60, 0, 333, 60), ink)
    if line is None:
        return []
    centre = (line[0] + line[2]) / 2
    return [("sheet title centred", "layout.global.sheetHeader", M.W / 2, centre, {"tol": 2.0, "note": "centre x of the title ink"})]


# --- auth -----------------------------------------------------------------------------------------

def auth_phone():
    land = snap("auth.phone/landing-light")
    rows = capsule_rows("Get started", land, t("color.global.accent")["light"], LIGHT_PAGE)
    cap = wide_fill_up(land, t("color.global.accent")["light"], min_w=250)
    link = line_box(land, (0, cap["bottom"] + 1, 393, cap["bottom"] + 60), lambda p: 100 < max(p[:3]) < 210)
    if link:
        rows.append(("capsule → link (cap top)", "auth.phone.size.capsuleToLink", t("auth.phone.size.capsuleToLink"), link[1] - cap["bottom"], {"tol": 2.0, "note": "ink top of the lower-case link ≈ x-height; the token is to the cap top"}))
    legal = M.extent(land, lambda p: max(p[:3]) < 200, (0, 760, 393, 852))
    rows.append(("legal last line → screen bottom", "auth.phone.size.legalToBottom", t("auth.phone.size.legalToBottom"), M.H - legal[3] if legal else None, {"tol": 2.0}))
    rows.append(("page (landing)", "color.global.background.android", LIGHT_PAGE, color_at(land, 2, 300)))
    form = snap("auth.phone/form-filled-light")
    frows = form_title_rows(form, LIGHT_PAGE, dark_ink)
    frows += field_rows(form, 100)
    frows += capsule_rows("Next", form, t("color.global.accent")["light"], LIGHT_PAGE, bottom="size.global.buttonMarginH")
    dark = snap("auth.phone/form-filled-dark")
    drows = [("page (dark)", "color.global.background.android", DARK_PAGE, color_at(dark, 2, 430))]
    drows += capsule_rows("Next (dark)", dark, t("color.global.accent")["dark"], DARK_PAGE)
    return [("A. Landing (auth.phone/landing-light)", rows), ("B. Form (auth.phone/form-filled-light)", frows), ("Dark (auth.phone/form-filled-dark)", drows)]


def auth_simple(surface, state, field=True):
    def run():
        im = snap(f"{surface}/{state}-light")
        rows = form_title_rows(im, LIGHT_PAGE, dark_ink)
        if field:
            rows += field_rows(im, 100)
        rows += capsule_rows("Next", im, t("color.global.accent")["light"], LIGHT_PAGE, bottom="size.global.buttonMarginH")
        return [(f"Form ({surface}/{state}-light)", rows)]
    return run


def auth_agegate():
    sections = auth_simple("auth.agegate", "filled-optIn")()
    im = snap("auth.agegate/filled-optIn-light")
    field = wide_fill(im, t("color.global.control")["light"], 100, 600, min_w=300)
    g, b = grouped_rows(im, LIGHT_PAGE, t("color.global.surfaceSecondary.android")["light"], y0=field["bottom"] + 1 if field else 200, label="opt-in row")
    h = t("settings.root.size.rowHeight")
    g.append(("opt-in row height (minimum)", "settings.root.size.rowHeight", f"≥ {h}", b["height"], {"status": "match" if b["height"] >= h - 1 else "MISS", "note": "the row's minimum; the two-line subtitle makes it taller"}))
    sections.append(("Opt-in row (C-14 with a switch)", g))
    return sections


def auth_profile():
    sections = auth_simple("auth.profile", "name-filled")()
    im = snap("auth.profile/photo-chosen-light")
    face = M.extent(im, lambda p: abs(p[0] - p[2]) > 25, (60, 120, 333, 700))
    rows = []
    if face:
        rows += [("avatar diameter", "auth.profile.size.avatar", t("auth.profile.size.avatar"), face[2] - face[0], {"tol": 2.0}),
                 ("avatar centred", "auth.profile.size.avatar", M.W / 2, (face[0] + face[2]) / 2, {"tol": 1.5})]
    rows += capsule_rows("Next", im, t("color.global.accent")["light"], LIGHT_PAGE)
    sections.append(("Step 2 (auth.profile/photo-chosen-light)", rows))
    return sections


# --- onboarding -----------------------------------------------------------------------------------

def notifications():
    im = snap("onboarding.permission.notifications/default-light")
    rows = form_title_rows(im, LIGHT_PAGE, dark_ink)
    rows += capsule_rows("Enable notifications", im, t("color.global.accent")["light"], LIGHT_PAGE)
    cap = wide_fill_up(im, t("color.global.accent")["light"], min_w=250)
    link = line_box(im, (0, cap["bottom"] + 1, 393, cap["bottom"] + 60), lambda p: max(p[:3]) < 200)
    if link:
        rows.append(("capsule → link (ink top)", "auth.phone.size.capsuleToLink", t("auth.phone.size.capsuleToLink"), link[1] - cap["bottom"], {"tol": 2.5, "note": "ink top of 'Maybe later' (cap M); the token is to the cap top"}))
    return [("Page (default-light)", rows)]


def ink_blocks(img, ink, box=(0, 0, M.W, M.H)):
    """Vertical groups of rows holding ink inside box: [(top, bottom, left, right)] in dp (rows 1 px apart join)."""
    x0, y0, x1, y1 = (int(v * M.SCALE) for v in box)
    groups, cur = [], None
    for y in range(y0, min(y1, img.height)):
        xs = [x for x in range(x0, min(x1, img.width)) if ink(img.getpixel((x, y)))]
        if not xs:
            continue
        if cur and y - cur[1] <= 1:
            cur = [cur[0], y, min(cur[2], xs[0]), max(cur[3], xs[-1])]
        else:
            if cur:
                groups.append(cur)
            cur = [y, y, xs[0], xs[-1]]
    if cur:
        groups.append(cur)
    return [(a / M.SCALE, (b + 1) / M.SCALE, l / M.SCALE, (r + 1) / M.SCALE) for a, b, l, r in groups]


def empty_block_rows(img, ink, box, label):
    """C-27: glyph (box `size.global.emptyIcon` centred on its ink) → title cap top `size.global.emptyIconToTitle`."""
    blocks = ink_blocks(img, ink, box)
    if len(blocks) < 2:
        return [(f"{label}: block found", "size.global.emptyIcon", t("size.global.emptyIcon"), None)]
    # A glyph can be drawn in parts (the download arrow and its base): join blocks while they fit the glyph box.
    while len(blocks) > 2 and blocks[1][1] - blocks[0][0] <= t("size.global.emptyIcon") + 1:
        a, b = blocks[0], blocks[1]
        blocks = [(a[0], b[1], min(a[2], b[2]), max(a[3], b[3]))] + blocks[2:]
    glyph, title = blocks[0], blocks[1]
    size = max(glyph[1] - glyph[0], glyph[3] - glyph[2])
    box_bottom = (glyph[0] + glyph[1]) / 2 + t("size.global.emptyIcon") / 2
    return [
        (f"{label} glyph ink", "size.global.emptyIcon", t("size.global.emptyIcon"), size, {"status": "approx", "note": "Material glyph ink ≈ 80 % of its 22 dp box"}),
        (f"{label} glyph box → title cap top", "size.global.emptyIconToTitle", t("size.global.emptyIconToTitle"), title[0] - box_bottom, {"tol": 2.0, "note": "glyph box = its ink centre ± 11; title ink top of a capital = cap top"}),
        (f"{label} centred", "size.global.emptyIcon", M.W / 2, (glyph[2] + glyph[3]) / 2, {"tol": 1.5}),
    ]


def denied_block(surface):
    def run():
        im = snap(f"{surface}/denied-light")
        rows = [("media surface (both appearances)", "color.global.backgroundDeep", t("color.global.backgroundDeep"), color_at(im, 2, 100))]
        rows += empty_block_rows(im, light_ink, (0, 200, 393, 650), "denied block")
        return [(f"Denied block ({surface}/denied-light)", rows)]
    return run


def widget():
    im = snap("onboarding.widget/default-light")
    rows = form_title_rows(im, LIGHT_PAGE, dark_ink)
    notpage = lambda p: max(p[:3]) < 245
    cols = [c for x in range(140, 254, 4) for c in M.col_runs(im, x, notpage, 150, 420, min_len=60)]
    col = [max(cols, key=lambda c: c[1] - c[0])] if cols else []
    if col:
        mid = (col[0][0] + col[0][1]) / 2
        ext = M.extent(im, notpage, (100, mid - 0.5, 293, mid + 0.5))
        row = [(ext[0], ext[2])] if ext else []
        rows += [("preview tile height (tallest clean column)", "onboarding.widget.size.preview", t("onboarding.widget.size.preview"), col[0][1] - col[0][0], {"tol": 2.0}),
                 ("preview tile width", "onboarding.widget.size.preview", t("onboarding.widget.size.preview"), row[0][1] - row[0][0] if row else None, {"tol": 2.0}),
                 ("preview centred", "onboarding.widget.size.preview", M.W / 2, (row[0][0] + row[0][1]) / 2 if row else None, {"tol": 1.5})]
    rows += capsule_rows("Add Widget", im, t("color.global.accent")["light"], LIGHT_PAGE)
    return [("Page (default-light)", rows)]


# --- groups ---------------------------------------------------------------------------------------

def groups_list():
    im = snap("groups.list/default-light")
    title = line_box(im, (0, 20, 300, 120), dark_ink)
    rows = [("title baseline below the safe-area top", "size.global.titleTop", t("size.global.titleTop"), title[3] if title else None, {"tol": 1.5}),
            ("title leading inset (ink)", "size.global.screenMargin", t("size.global.screenMargin"), title[0] if title else None, {"tol": 3.0, "note": "the serif capital's side bearing at 40 sp (≈ 2.5 dp) is inside the measure"})]
    # Cover thumbnails: runs down a column through them (anything that is not the white page).
    thumbs = M.col_runs(im, 80, lambda p: max(p[:3]) < 250, 90, 560, min_len=40)
    if thumbs:
        th = thumbs[0]
        ext = M.extent(im, lambda p: max(p[:3]) < 250, (0, th[0] + 2, 100, th[1] - 2))
        rows.append(("cover thumbnail height", "size.global.rowThumbHeight", t("size.global.rowThumbHeight"), th[1] - th[0], {"tol": 1.0}))
        if ext:
            rows += [("cover thumbnail width", "size.global.rowThumbWidth", t("size.global.rowThumbWidth"), ext[2] - ext[0], {"tol": 1.0}),
                     ("thumbnail leading inset", "size.global.screenMargin", t("size.global.screenMargin"), ext[0], {"tol": 1.0})]
    if len(thumbs) > 1:
        rows.append(("gap between rows (thumbnail to thumbnail)", "size.global.listGap", t("size.global.listGap"), thumbs[1][0] - thumbs[0][1], {"tol": 1.5}))
    return [("List (groups.list/default-light)", rows)]


def groups_create():
    im = snap("groups.create/stepB-filled-light")
    rows = sheet_title_rows(im, dark_ink)
    cover = M.extent(im, lambda p: abs(p[0] - p[2]) > 25, (60, 60, 333, 400))
    if cover:
        rows += [("cover width", "groups.screen.size.coverWidth", t("groups.screen.size.coverWidth"), cover[2] - cover[0], {"tol": 2.0}),
                 ("cover height", "groups.screen.size.coverHeight", t("groups.screen.size.coverHeight"), cover[3] - cover[1], {"tol": 2.0}),
                 ("cover centred", "groups.screen.size.coverWidth", M.W / 2, (cover[0] + cover[2]) / 2, {"tol": 1.5})]
    rows += field_rows(im, cover[3] + 1 if cover else 300, 700)
    rows += capsule_rows("Create Group", im, t("color.global.accent")["light"], LIGHT_PAGE, bottom="size.global.buttonMarginH")
    return [("Step B (groups.create/stepB-filled-light)", rows)]


def groups_invite():
    im = snap("groups.invite/linkOff-light")
    rows = sheet_title_rows(im, dark_ink)
    cover = M.extent(im, lambda p: abs(p[0] - p[2]) > 25, (40, 50, 353, 520))
    if cover:
        rows += [("cover width", "groups.invite.size.coverWidth", t("groups.invite.size.coverWidth"), cover[2] - cover[0], {"tol": 2.5}),
                 ("cover height", "groups.invite.size.coverHeight", t("groups.invite.size.coverHeight"), cover[3] - cover[1], {"tol": 2.5})]
        note = line_box(im, (0, cover[3] + 1, 393, cover[3] + 60), lambda p: max(p[:3]) < 160)
        if note:
            rows.append(("cover → note (ink top)", "groups.invite.size.coverToNote", t("groups.invite.size.coverToNote"), note[1] - cover[3], {"tol": 3.0, "note": "the shadow below the cover is excluded from the cover box"}))
        cap = wide_fill(im, t("color.global.accent")["light"], cover[3] + 20, 800, min_w=250)
        if cap:
            rows += [("Turn on link sharing height", "size.global.buttonHeight", t("size.global.buttonHeight"), cap["height"]),
                     ("Turn on link sharing side inset", "size.global.buttonMarginH", t("size.global.buttonMarginH"), cap["left"])]
    return [("Link off (groups.invite/linkOff-light)", rows)]


def groups_screen():
    im = snap("groups.screen/default-light")
    rows = []
    cover = M.extent(im, lambda p: abs(p[0] - p[2]) > 25, (100, 60, 293, 380))
    if cover:
        rows += [("cover width", "groups.screen.size.coverWidth", t("groups.screen.size.coverWidth"), cover[2] - cover[0], {"tol": 2.0}),
                 ("cover height", "groups.screen.size.coverHeight", t("groups.screen.size.coverHeight"), cover[3] - cover[1], {"tol": 2.0}),
                 ("cover centred", "groups.screen.size.coverWidth", M.W / 2, (cover[0] + cover[2]) / 2, {"tol": 1.5})]
        name = line_box(im, (0, cover[3] + 8, 393, cover[3] + 90), dark_ink)
        if name:
            rows.append(("cover → name (ink top)", "groups.screen.size.coverToTitle", t("groups.screen.size.coverToTitle"), name[1] - cover[3], {"tol": 3.0, "note": "ink top of the serif capital ≈ cap top; the shadow is outside the cover box"}))
    glyphs = M.extent(im, dark_ink, (300, 20, 393, 80))
    if glyphs:
        rows.append(("trailing glyph pair: right edge inset", "size.global.headerInset", t("size.global.headerInset"), M.W - glyphs[2], {"status": "approx", "note": "glyph ink edge (the 24 dp box has ≈ 2 dp padding)"}))
    # The week strip: the first row (below the cover) crossing three or more tile-wide runs.
    notpage = lambda p: max(p[:3]) < 250
    for y in [(cover[3] if cover else 380) + 120 + i * 0.5 for i in range(500)]:
        runs = [r for r in M.row_runs(im, y, notpage, 0, 393, min_len=3) if abs((r[1] - r[0]) - t("size.global.stripTileWidth")) <= 2]
        if len(runs) >= 3:
            # Below the strip's rounded top corners: measure on a row 40 dp further down.
            y += 40
            runs = [r for r in M.row_runs(im, y, notpage, 0, 393, min_len=3) if abs((r[1] - r[0]) - t("size.global.stripTileWidth")) <= 2] or runs
            heights = []
            for r in runs:
                for x in range(int(r[0]) + 4, int(r[1]) - 4, 4):
                    col = M.col_runs(im, x, notpage, y - 140, y + 140, min_len=20)
                    heights += [c[1] - c[0] for c in col if c[0] <= y <= c[1]]
            rows += [("strip tile leading inset", "size.global.screenMargin", t("size.global.screenMargin"), runs[0][0], {"tol": 1.0}),
                     ("strip tile width", "size.global.stripTileWidth", t("size.global.stripTileWidth"), runs[0][1] - runs[0][0], {"tol": 1.0}),
                     ("strip gap", "size.global.stripGap", t("size.global.stripGap"), runs[1][0] - runs[0][1], {"tol": 0.6}),
                     ("strip tile height (tallest clean column)", "size.global.stripTileHeight", t("size.global.stripTileHeight"), max(heights) if heights else None, {"tol": 1.0})]
            break
    rows.append(("page", "color.global.background.android", LIGHT_PAGE, color_at(im, 2, 300)))
    return [("Default (groups.screen/default-light)", rows)]


def settings_list(surface, state, label):
    def run():
        im = snap(f"{surface}/{state}-light")
        rows = sheet_title_rows(im, dark_ink)
        g, b = grouped_rows(im, LIGHT_PAGE, t("color.global.surfaceSecondary.android")["light"], y0=50)
        rows += g
        dark = snap(f"{surface}/{state}-dark")
        dg, db = grouped_rows(dark, DARK_PAGE, t("color.global.surfaceSecondary.android")["dark"], y0=50, label="grouped row (dark)")
        rows += [r for r in dg if "fill" in r[0]]
        rows.append(("page (dark)", "color.global.background.android", DARK_PAGE, color_at(dark, 2, 840)))
        return [(f"{label} ({surface}/{state})", rows)]
    return run


def settings_rows_height(surface, state):
    """Single-row height: the smallest C-14 group on the page (a one-line row; taller groups hold several rows, an avatar
    or a two-line row)."""
    def run():
        sections = settings_list(surface, state, "List")()
        im = snap(f"{surface}/{state}-light")
        fill = t("color.global.surfaceSecondary.android")["light"]
        heights, y = [], 50
        while y < 840:
            b = wide_fill(im, fill, y, 845, min_w=300, tol=2)
            if not b:
                break
            if b["bottom"] < 850:  # a group cut by the screen edge is not a whole group
                heights.append(b["height"])
            y = b["bottom"] + 2
        if heights:
            sections[0][1].append(("single-row group height (smallest group)", "settings.root.size.rowHeight", t("settings.root.size.rowHeight"), min(heights), {"tol": 1.5}))
        return sections
    return run


def safety_report():
    im = snap("safety.report/reasons-post-light")
    fill = t("color.global.system.surfaceContainerLow")["light"]
    sheet = wide_fill_up(im, fill, min_w=380, tol=3)
    rows = []
    if sheet:
        rows.append(("sheet container", "color.global.system.surfaceContainerLow", fill, sheet["color"]))
        rows.append(("sheet full width", "layout.global.materials", M.W, sheet["width"], {"tol": 1.0, "note": "M3 ModalBottomSheet at full width on a phone"}))
        texts = [b for b in ink_blocks(im, dark_ink, (0, sheet["top"] + 1, 393, M.H)) if b[2] < 60]
        if texts:
            rows.append(("reason text inset (first left-aligned row)", "size.global.screenMargin", t("size.global.screenMargin"), texts[0][2], {"tol": 2.0}))
    return [("Reasons sheet (safety.report/reasons-post-light)", rows)]


def paywall():
    rows = []
    for mode in ("light", "dark"):
        im = snap(f"paywall/default-{mode}")
        plan = wide_fill(im, t("color.global.surfaceLight"), 300, 800, min_w=300, tol=2)
        if not plan:
            rows.append((f"plan card ({mode})", "paywall.layout.planCard", t("color.global.surfaceLight"), None))
            continue
        rows += [(f"plan card leading inset ({mode})", "size.global.buttonMarginH", t("size.global.buttonMarginH"), plan["left"], {"tol": 1.0}),
                 (f"plan card fill ({mode}; light in both appearances)", "paywall.layout.planCard", t("color.global.surfaceLight"), plan["color"])]
        cap = wide_fill(im, t("color.global.onSurfaceLight"), plan["top"] + 40, plan["bottom"] + 1, min_w=250)
        if cap:
            rows += [(f"Continue height ({mode})", "size.global.buttonHeight", t("size.global.buttonHeight"), cap["height"]),
                     (f"Continue fill ({mode})", "color.global.onSurfaceLight", t("color.global.onSurfaceLight"), cap["color"])]
        # The FREE pill (annual plan with the 1-week trial): its trailing edge against the card's.
        purple = lambda c: c[0] > 140 and c[2] > 140 and c[1] < 110
        pill = M.extent(im, purple, (plan["left"], plan["top"], plan["left"] + plan["width"], plan["top"] + 60))
        if pill:
            rows.append((f"FREE pill trailing inset ({mode})", "paywall.size.planPillInset", t("paywall.size.planPillInset"),
                         round(plan["left"] + plan["width"] - pill[2], 1), {"tol": 1.0}))
    return [("Default (paywall/default-light, -dark)", rows)]


def invite_web():
    rows = []
    for mode in ("light", "dark"):
        im = snap(f"invite.web/android-valid-{mode}")
        rows.append((f"page around the card ({mode}; Retro's white web page in both)", "color.global.background", t("color.global.background")["light"], color_at(im, 1, 400)))
        edge = M.row_runs(im, 400, lambda p: max(p[:3]) < 250)
        if edge:
            rows.append((f"card inset ({mode})", "invite.web.size.cardInset", t("invite.web.size.cardInset"), edge[0][0], {"tol": 1.0}))
        top = M.col_runs(im, 196, lambda p: max(p[:3]) < 250, 0, 60)
        if top:
            rows.append((f"card top inset ({mode})", "invite.web.size.cardInset", t("invite.web.size.cardInset"), top[0][0], {"tol": 1.0}))
    return [("Valid (invite.web/android-valid-light, -dark)", rows)]


SURFACES = [
    dict(id="auth.phone", what="Landing (A) and phone form (B) — `auth/PhoneScreen.kt`, `CountryCode.kt`, `common/AccountUi.kt` (`OnboardingForm`).",
         ours="auth.phone/landing", dark="auth.phone/landing", refs=[LAND], measure=auth_phone),
    dict(id="auth.code", what="SMS code — `auth/CodeScreen.kt` (+ SMS User Consent).",
         ours="auth.code/default", dark="auth.code/default", refs=[LAND], ref_note="LAND: Retro's capsule and page; Retro's code page was not captured (APK strings only).", measure=auth_simple("auth.code", "filled-resendEnabled")),
    dict(id="auth.agegate", what="Birthday (neutral age screen) with the birthday-video opt-in row — `auth/AgeGateScreen.kt`.",
         ours="auth.agegate/filled-optIn", dark="auth.agegate/default", refs=[LAND, VIDSET], measure=auth_agegate),
    dict(id="auth.profile", what="Full name (step 1) and profile photo (step 2) — `auth/ProfileScreen.kt`.",
         ours="auth.profile/photo-chosen", dark="auth.profile/photo-chosen", refs=[LAND], measure=auth_profile),
    dict(id="onboarding.permission.notifications", what="Notifications pre-alert page (API 33+) then POST_NOTIFICATIONS — `onboarding/NotificationsPermissionScreen.kt`.",
         ours="onboarding.permission.notifications/default", dark="onboarding.permission.notifications/default", refs=[LAND], measure=notifications),
    dict(id="onboarding.permission.camera", what="Camera: request by camera.capture; the M3 rationale dialog (core:ui `rememberPermissionRequest`); the denied C-27 block on media is drawn in place by camera.capture (capture pass) — rendered here as the same composition.",
         ours="onboarding.permission.camera/denied", dark="onboarding.permission.camera/denied", refs=[H43], measure=denied_block("onboarding.permission.camera")),
    dict(id="onboarding.permission.photos", what="Photos: Photo Picker (no permission); the denied-save C-27 block is photo.viewer's (social pass) — rendered here as the same composition. Android API 29+ saves need no permission.",
         ours="onboarding.permission.photos/denied", dark="onboarding.permission.photos/denied", refs=[H43], measure=denied_block("onboarding.permission.photos")),
    dict(id="onboarding.permission.contacts", what="Contacts: the C-27 block in groups.invite's Contacts section, then READ_CONTACTS — `groups/GroupInviteScreen.kt`.",
         ours="onboarding.permission.contacts/notAsked", dark="onboarding.permission.contacts/notAsked", refs=[TC1B]),
    dict(id="onboarding.widget", what="Add the \"Group Updates\" widget (pin request + steps) — `onboarding/WidgetScreen.kt`.",
         ours="onboarding.widget/default", dark="onboarding.widget/default", refs=[W34, VIDSET], measure=widget),
    dict(id="groups.list", what="Home: serif title + new-group glyph, C-15 rows, ideas section, tab bar (shell `ShellTabBar` → C-04) — `groups/GroupsListScreen.kt`.",
         ours="groups.list/default", dark="groups.list/default", refs=[EDW3, JED, TCJ1], measure=groups_list),
    dict(id="groups.create", what="New group sheet: A. kind (template rows), B. cover + name; edit mode — `groups/GroupCreateScreen.kt`.",
         ours="groups.create/stepB-filled", dark="groups.create/stepB-filled", refs=[TCJ1, JED], measure=groups_create),
    dict(id="groups.invite", what="Invite sheet: cover, note, link sharing (off / on menu + share targets), contacts — `groups/GroupInviteScreen.kt`.",
         ours="groups.invite/linkOn", dark="groups.invite/linkOn", refs=[TCJ5, TC1B], measure=groups_invite),
    dict(id="groups.screen", what="The group: cover, serif name, members, actions, this week's strip, members' weeks + memory cards pager, earlier grid — `groups/GroupScreen.kt`.",
         ours="groups.screen/default", dark="groups.screen/default", refs=[TCJ1, ST01, H43], measure=groups_screen,
         extra="Memory entries (memory pass APIs `OnThisDayEntry`, `YearStoryEntry`, `BirthdayRequestEntries`): this screen draws the birthday request row (C-14 + C-16) above this week and the feed cards (C-18 frame, Rewind / Recap glyph) in the members' pager; `groups.screen/default-memoryEntries` renders them with the memory copy. The entry APIs pass no photo or avatar, so the cards show `color.global.backgroundDeep` under the scrim (approximated)."),
    dict(id="groups.settings", what="Group settings sheet: members, notifications, daily invitation, admin, report / leave — `groups/GroupSettingsScreen.kt`.",
         ours="groups.settings/default-admin", dark="groups.settings/default-admin", refs=[VIDSET, TCJ5, TC1B], measure=settings_list("groups.settings", "default-admin", "List")),
    dict(id="settings.root", what="Settings sheet — `settings/SettingsRootScreen.kt`, `settings/SettingsUi.kt`.",
         ours="settings.root/default", dark="settings.root/default", refs=[VIDSET, TCJ5], measure=settings_rows_height("settings.root", "default")),
    dict(id="settings.notifications", what="Notification settings — `settings/SettingsNotificationsScreen.kt`.",
         ours="settings.notifications/default", dark="settings.notifications/default", refs=[VIDSET], measure=settings_list("settings.notifications", "default", "List")),
    dict(id="settings.account", what="Account: photo, full name, phone, birthday, delete — `settings/SettingsAccountScreen.kt`.",
         ours="settings.account/default", dark="settings.account/default", refs=[VIDSET, TCJ5], measure=settings_rows_height("settings.account", "default")),
    dict(id="settings.blocked", what="Blocked people — `settings/SettingsBlockedScreen.kt`.",
         ours="settings.blocked/default", dark="settings.blocked/default", refs=[TC1B], measure=settings_list("settings.blocked", "default", "List")),
    dict(id="safety.report", what="Report flow: M3 ModalBottomSheet (reasons, next steps), alerts — `safety/ReportSheet.kt`.",
         ours="safety.report/reasons-post", dark="safety.report/reasons-post", refs=[TCRWP], measure=safety_report),
    dict(id="safety.block", what="Block confirmation (M3 AlertDialog) — `safety/BlockDialog.kt`.",
         ours="safety.block/confirming", dark="safety.block/confirming", refs=[TCRWP]),
    dict(id="system.permissions", what="Rationale and permanent-denial dialogs (core:ui `rememberPermissionRequest`, M3 AlertDialog); purpose strings in the manifest / system prompts.",
         ours="system.permissions/rationale-microphone", dark="system.permissions/rationale-microphone", refs=[],
         no_ref="the operating system draws the prompts; the spec names no image (HIG / M3 guidance)."),
    dict(id="paywall", what="Paywall: blurred backdrop, benefit pager, plan card pager, footer, welcome — `paywall/PaywallScreen.kt`.",
         ours="paywall/default", dark="paywall/default", refs=[PAY], measure=paywall),
    dict(id="invite.web", what="Android join path: App Link / install referrer → the invite card (invite.web's card, natively) → \"Let's go\" — `invite/InviteJoinScreen.kt`, `invite/InviteInstall.kt`.",
         ours="invite.web/android-valid", dark="invite.web/android-valid", refs=[WEBU], measure=invite_web),
]
