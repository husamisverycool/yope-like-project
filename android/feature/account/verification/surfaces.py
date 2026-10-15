"""Per-surface inputs of checklists.py: what the surface is, which snapshot faces which reference image,
and the pixel measurements taken on our renders (dp; see measure.py). Expected values are read from the
token files, so a token change shows up here as a MISS until the screen follows it.
"""
import json
import os

import measure as M
from measure import bright, col_runs, color_at, corner_radius, extent, fill_box, near, row_runs, snap

_T = {}
for _n in ("global", "capture", "account", "social", "memory", "invite"):
    with open(os.path.join(M.ROOT, "design", "tokens", _n + ".json")) as _f:
        _T.update(json.load(_f)["tokens"])


def t(key, sub=None):
    v = _T[key]["value"]
    return v[sub] if sub is not None else v


# Roboto: cap height 0.711 em, ascender ('l', 'h', 'd') 0.750 em (backend/worker/fonts/Roboto-*.ttf, all weights).
ASCENDER_OVER_CAP_EM = 0.039
REF = "references/auto/yope/frames/"
LOCKET = "references/auto/locket/"


def first(runs):
    return runs[0] if runs else (None, None)


def span(r):
    return None if r[0] is None else r[1] - r[0]


def box_rows(label, img, x, y, bg, width_token=None, height_token=None, radius_token=None, color_token=None, left_token=None):
    """Rows for a flat rounded fill under (x, y): left inset, height, radius, colour."""
    b = fill_box(img, x, y)
    rows = []
    if left_token:
        rows.append((f"{label} left inset", left_token, t(left_token), b["left"]))
    if height_token:
        rows.append((f"{label} height", height_token, t(height_token), b["height"]))
    if width_token:
        rows.append((f"{label} width", width_token, t(width_token), b["width"]))
    if radius_token:
        rows.append((f"{label} corner radius", radius_token, t(radius_token), round(corner_radius(img, b, bg), 2), {"tol": 1.0}))
    if color_token:
        rows.append((f"{label} fill", color_token, t(color_token), b["color"]))
    return rows, b


def cap_top_row(label, img, region, font_size, token="groups.create.size.sheetTopToTitle"):
    ink = extent(img, bright(140), region)
    cap = None if ink is None else ink[1] + ASCENDER_OVER_CAP_EM * font_size
    return (f"{label} cap top below the safe area", token, t(token), cap, {"tol": 1.0, "note": "ascender ink top + 0.039 em (Roboto ascender − cap height)"})


# --- auth -----------------------------------------------------------------------------------------

def auth_phone():
    im = snap("auth.phone/filled")
    title_fs = t("fontSize.global.onboardingTitle")
    rows = [cap_top_row("title", im, (0, 40, 393, 105), title_fs), ("background", "color.global.backgroundDeep", t("color.global.backgroundDeep"), color_at(im, 5, 400))]
    sub = extent(im, bright(140), (0, 105, 393, 140))
    field_rows, field = box_rows("phone field", im, 100, 174, "#000000", None, "size.global.fieldHeight", "radius.global.field", "groups.create.color.field", "size.global.buttonMarginH")
    rows += [("subtitle bottom (descender) → field top", "groups.create.size.titleToContent", t("groups.create.size.titleToContent"), field["top"] - sub[3], {"tol": 1.0})]
    rows += field_rows
    rows.append(("field right inset", "size.global.buttonMarginH", t("size.global.buttonMarginH"), M.W - field["right"]))
    btn_rows, btn = box_rows("continue", im, 60, 248, "#000000", None, "size.global.buttonHeight", "radius.global.button", "color.global.accent")
    rows.append(("field bottom → button top", "groups.create.size.fieldToButton", t("groups.create.size.fieldToButton"), btn["top"] - field["bottom"]))
    rows += btn_rows
    text = extent(im, bright(140), (80, field["top"], field["right"] - 5, field["bottom"]))
    rows.append(("number centred on the field", "groups.create.fontSize.fieldText", (field["left"] + field["right"]) / 2, (text[0] + text[2]) / 2, {"tol": 1.0, "note": "centre x of the typed text"}))
    flag = extent(im, lambda p: abs(p[0] - p[2]) > 40, (19, field["top"], 80, field["bottom"]))
    slot_left = field["left"] + t("auth.phone.layout.countryCode", "flagLeading")
    rows.append(("flag slot: flag inside [leading 20, 20 wide]", "auth.phone.layout.countryCode", f"{slot_left:g}–{slot_left + 20:g}", f"{flag[0]:g}–{flag[2]:g} (visible {flag[2] - flag[0]:g} × {flag[3] - flag[1]:g})", {"status": "approx", "note": "the emoji is fitted into the 20 × 13 slot by its line box; the visible flag keeps the emoji's own margins"}))
    dis = snap("auth.phone/default")
    rows.append(("continue disabled fill", "groups.create.color.buttonDisabledFill", t("groups.create.color.buttonDisabledFill"), fill_box(dis, 60, 248)["color"]))
    foot = extent(im, bright(60), (0, 800, 393, 852))
    rows.append(("legal footer text colour", "color.global.textSecondary", t("color.global.textSecondary"), max((M.hexof(im.getpixel((x, int((foot[1] + foot[3]))))) for x in range(int(foot[0] * 2), int(foot[2] * 2))), key=lambda h: int(h[1:3], 16))))
    hud_img = snap("auth.phone/sending")
    hud = fill_box(hud_img, 160, 426)
    rows += [("Loading HUD side", "groups.create.size.hud", t("groups.create.size.hud"), hud["width"]),
             ("Loading HUD fill", "groups.create.color.hud", t("groups.create.color.hud"), hud["color"])]
    toast = snap("auth.code/resent-toast")
    tb = extent(toast, near(t("color.global.accent"), 3), (0, 0, 393, 120))
    rows += [("toast side margins", "size.global.screenMargin", t("size.global.screenMargin"), tb[0], {"tol": 1.0, "note": "auth.code resent-toast; capsule anti-aliasing at the ends"}),
             ("toast height", "camera.sendto.layout.toast", t("camera.sendto.layout.toast", "height"), tb[3] - tb[1]),
             ("toast fill", "color.global.accent", t("color.global.accent"), color_at(toast, 200, 10))]
    return [("Layout (auth.phone/filled, default, sending; toast on auth.code/resent-toast)", rows)]


def auth_code():
    im = snap("auth.code/default")
    back = extent(im, near(t("color.global.controlOnDeep"), 2), (0, 0, 80, 60))
    rows = [("back circle diameter", "size.global.headerButton", t("size.global.headerButton"), back[2] - back[0]),
            ("back circle inset", "size.global.headerInset", t("size.global.headerInset"), back[0]),
            ("back circle fill", "color.global.controlOnDeep", t("color.global.controlOnDeep"), color_at(im, back[0] + 6, (back[1] + back[3]) / 2)),
            cap_top_row("title", im, (0, 50, 393, 105), t("fontSize.global.onboardingTitle"))]
    sub = extent(im, bright(140), (0, 105, 393, 140))
    frows, field = box_rows("code field", im, 100, 174, "#000000", None, "size.global.fieldHeight", "radius.global.field", "groups.create.color.field", "size.global.buttonMarginH")
    descender = 0.208 * t("auth.phone.fontSize.subtitle")
    rows.append(("subtitle → field", "groups.create.size.titleToContent", t("groups.create.size.titleToContent"), field["top"] - sub[3] - descender, {"tol": 1.0, "note": "this subtitle has no descender glyphs: ink bottom = baseline, so Roboto's descender (0.208 em) is added back"}))
    rows += frows
    brows, btn = box_rows("continue (disabled)", im, 60, field["bottom"] + 30, "#000000", None, "size.global.buttonHeight", None, "groups.create.color.buttonDisabledFill")
    rows.append(("field → button", "groups.create.size.fieldToButton", t("groups.create.size.fieldToButton"), btn["top"] - field["bottom"]))
    rows += brows
    link = extent(im, bright(60), (0, btn["bottom"] + 1, 393, btn["bottom"] + 40))
    rows.append(("button → 'send new code' (text box)", "groups.create.size.fieldToButton", t("groups.create.size.fieldToButton"), link[1] - btn["bottom"], {"status": "approx", "note": "measured to the ink top; the spec gap is to the text"}))
    rows.append(("'send new code' locked colour", "color.global.textSecondary", t("color.global.textSecondary"), max((M.hexof(im.getpixel((x, int(link[1] * 2 + 6)))) for x in range(int(link[0] * 2), int(link[2] * 2))), key=lambda h: int(h[1:3], 16))))
    on = snap("auth.code/filled-resendEnabled")
    lk = extent(on, near(t("color.global.accent"), 60), (0, btn["bottom"] + 1, 393, btn["bottom"] + 40))
    rows.append(("'send new code' enabled colour", "color.global.accent", t("color.global.accent"), color_at(on, lk[0] + 1, (lk[1] + lk[3]) / 2) if lk else "—", {"note": "sampled on a glyph stem"}))
    return [("Layout (auth.code/default, filled-resendEnabled)", rows)]


def auth_agegate():
    im = snap("auth.agegate/filled-optIn")
    rows = [cap_top_row("title", im, (0, 40, 393, 105), t("fontSize.global.onboardingTitle"))]
    sub = extent(im, bright(140), (0, 160, 393, 185))
    frows, field = box_rows("birthday field", im, 60, 237, "#000000", None, "size.global.fieldHeight", "radius.global.field", "groups.create.color.field", "size.global.buttonMarginH")
    rows.append(("subtitle → field", "groups.create.size.titleToContent", t("groups.create.size.titleToContent"), field["top"] - sub[3], {"tol": 1.0}))
    rows += frows
    check = extent(im, near(t("color.global.selection"), 30), (300, field["bottom"], 393, field["bottom"] + 60))
    rows.append(("check circle visible diameter", "size.global.checkCircle", t("size.global.checkCircle"), check[2] - check[0], {"note": "Material check_circle draws its circle at 20/24 of the 24 dp icon box; the box is size.global.checkCircle"}))
    rows.append(("check fill", "color.global.selection", t("color.global.selection"), color_at(im, check[0] + 3, (check[1] + check[3]) / 2 - 5)))
    rows.append(("check right inset", "size.global.buttonMarginH", t("size.global.buttonMarginH"), M.W - check[2] - 2, {"tol": 1.0, "note": "box edge = visible edge + 2 dp"}))
    btn = fill_box(im, 60, 351)
    row_ink = extent(im, bright(60), (0, field["bottom"] + 1, 340, btn["top"] - 1))
    rows.append(("field → opt-in row (text box)", "groups.create.size.fieldToButton", t("groups.create.size.fieldToButton"), row_ink[1] - field["bottom"], {"status": "approx", "note": "ink top of the 14 sp label sits ~3 dp under its text box"}))
    rows += box_rows("continue", im, 60, 351, "#000000", None, "size.global.buttonHeight", "radius.global.button", "color.global.accent")[0]
    return [("Layout (auth.agegate/filled-optIn)", rows)]


def auth_profile():
    im = snap("auth.profile/filled-photo")
    rows = [cap_top_row("title", im, (0, 40, 393, 105), t("fontSize.global.onboardingTitle"))]
    sub = extent(im, bright(140), (0, 105, 393, 140))
    av = extent(im, near(color_at(im, 196, 214), 6), (90, 140, 303, 290))
    rows += [("avatar diameter", "auth.profile.size.avatar", t("auth.profile.size.avatar"), av[2] - av[0]),
             ("subtitle → avatar", "groups.create.size.titleToContent", t("groups.create.size.titleToContent"), av[1] - sub[3], {"tol": 1.0}),
             ("avatar centred", "auth.profile.size.avatar", M.W / 2, (av[0] + av[2]) / 2)]
    frows, field = box_rows("name field", im, 60, 305, "#000000", None, "size.global.fieldHeight", "radius.global.field", "groups.create.color.field", "size.global.buttonMarginH")
    rows.append(("avatar → field", "groups.create.size.mediaToField", t("groups.create.size.mediaToField"), field["top"] - av[3]))
    rows += frows
    rows += box_rows("continue", im, 60, 382, "#000000", None, "size.global.buttonHeight", "radius.global.button", "color.global.accent")[0]
    empty = snap("auth.profile/default")
    rows.append(("empty avatar fill", "color.global.controlRaised", t("color.global.controlRaised"), color_at(empty, 170, 214)))
    return [("Layout (auth.profile/filled-photo, default)", rows)]


# --- onboarding -----------------------------------------------------------------------------------

def notifications():
    im = snap("onboarding.permission.notifications/default-android13")
    rows = [cap_top_row("title", im, (0, 40, 393, 105), t("fontSize.global.onboardingTitle"))]
    srows, skip = box_rows("'maybe later'", im, 60, 775, "#000000", None, "size.global.buttonHeightSheet", None, "onboarding.permission.notifications.color.secondaryButton", "size.global.buttonMarginHSheet")
    prow, prim = box_rows("'continue'", im, 60, 830, "#000000", None, "size.global.buttonHeightSheet", "radius.global.button", "color.global.accent", "size.global.buttonMarginHSheet")
    rows += srows + prow
    rows.append(("gap between the buttons", "onboarding.permission.notifications.size.buttonGap", t("onboarding.permission.notifications.size.buttonGap"), prim["top"] - skip["bottom"]))
    rows.append(("primary at the bottom of the safe area", "size.global.buttonHeightSheet", M.H, prim["bottom"], {"note": "snapshot has no navigation-bar inset"}))
    return [("Layout (default-android13)", rows)]


def permission_card(surface_note):
    im = snap("groups.invite/default-contactsCard")
    rows = []
    card_col = first(col_runs(im, 230, near(t("onboarding.permission.contacts.color.card"), 2), 250, 500))
    card_row = row_runs(im, card_col[0] + 20, near(t("onboarding.permission.contacts.color.card"), 2))
    left, right = card_row[0][0], card_row[-1][1]
    rows += [("card height", "onboarding.permission.contacts.size.cardHeight", t("onboarding.permission.contacts.size.cardHeight"), span(card_col), {"tol": 1.0}),
             ("card side margin", "onboarding.permission.contacts.size.cardMarginH", t("onboarding.permission.contacts.size.cardMarginH"), left, {"tol": 1.0}),
             ("card right margin", "onboarding.permission.contacts.size.cardMarginH", t("onboarding.permission.contacts.size.cardMarginH"), M.W - right, {"tol": 1.0}),
             ("card fill", "onboarding.permission.contacts.color.card", t("onboarding.permission.contacts.color.card"), color_at(im, 30, card_col[0] + 30))]
    en = extent(im, near(t("color.global.surfaceLight"), 3), (250, card_col[0] + 25, 380, card_col[1] - 1))
    rows += [("'enable' width", "onboarding.permission.contacts.size.cardButtonWidth", t("onboarding.permission.contacts.size.cardButtonWidth"), en[2] - en[0], {"tol": 1.0}),
             ("'enable' height", "onboarding.permission.contacts.size.cardButtonHeight", t("onboarding.permission.contacts.size.cardButtonHeight"), en[3] - en[1], {"tol": 1.0}),
             ("'enable' trailing inset (16)", "groups.list.size.avatarInset", t("groups.list.size.avatarInset"), right - en[2], {"tol": 1.0}),
             ("'enable' fill", "color.global.surfaceLight", t("color.global.surfaceLight"), color_at(im, en[0] + 10, (en[1] + en[3]) / 2))]
    title = extent(im, bright(200), (left + 2, card_col[0] + 25, 250, card_col[1] - 20))
    rows.append(("text leading inset (16)", "groups.list.size.avatarInset", t("groups.list.size.avatarInset"), title[0] - left, {"tol": 1.0, "note": "ink of the first glyph"}))
    return [(f"Inline permission card (groups.invite/default-contactsCard{surface_note})", rows)]


def widget():
    im = snap("onboarding.widget/default")
    rows = [("background top", "onboarding.widget.color.backgroundTop", t("onboarding.widget.color.backgroundTop"), color_at(im, 5, 1)),
            ("background bottom", "onboarding.widget.color.backgroundBottom", t("onboarding.widget.color.backgroundBottom"), color_at(im, 5, 851)),
            cap_top_row("title", im, (0, 40, 393, 105), t("onboarding.widget.fontSize.title"))]
    cta = extent(im, near(t("onboarding.widget.color.cta"), 3), (0, 700, 393, 852))
    mid = (cta[1] + cta[3]) / 2
    label = extent(im, lambda p: max(p[:3]) < 120, (cta[0] + 3, mid - 8, cta[0] + 95, mid + 8))
    dark_cols = [x / M.SCALE for x in range(int((cta[0] + 3) * M.SCALE), int((cta[2] - 3) * M.SCALE)) if any(max(im.getpixel((x, y))[:3]) < 120 for y in range(int((mid - 8) * M.SCALE), int((mid + 8) * M.SCALE)))]
    gaps = [(b - a, a) for a, b in zip(dark_cols, dark_cols[1:])]
    label_end = max(gaps)[1] + 1 / M.SCALE
    runs = row_runs(im, (cta[1] + cta[3]) / 2, near(t("onboarding.widget.color.cta"), 3), cta[0], cta[2])
    rows += [("CTA height", "onboarding.widget.size.ctaHeight", t("onboarding.widget.size.ctaHeight"), cta[3] - cta[1]),
             ("CTA fill", "onboarding.widget.color.cta", t("onboarding.widget.color.cta"), color_at(im, cta[0] + 8, (cta[1] + cta[3]) / 2)),
             ("CTA padding → label", "onboarding.widget.size.ctaPaddingH", t("onboarding.widget.size.ctaPaddingH"), label[0] - cta[0], {"tol": 1.0, "note": "to the label's first glyph"}),
             ("CTA centred", "onboarding.widget.size.ctaHeight", M.W / 2, (cta[0] + cta[2]) / 2, {"tol": 1.0}),
             ("label end → CTA end = arrow gap + arrow + padding", "onboarding.widget.size.ctaArrowGap", t("onboarding.widget.size.ctaArrowGap") + t("onboarding.widget.size.ctaArrow") + t("onboarding.widget.size.ctaPaddingH"), cta[2] - label_end, {"tol": 1.5, "note": "17 + 17 + 18; the Material arrow glyph is narrower than its 17 dp box"}),
             ("step colour", "onboarding.widget.color.step", t("onboarding.widget.color.step"), max((M.hexof(im.getpixel((x, 2 * 190))) for x in range(200, 600)), key=lambda h: int(h[1:3], 16)))]
    steps = [r for r in col_runs(im, 196, lambda p: max(p) > 120, 150, 520)]
    return [("Layout (onboarding.widget/default)", rows)]


# --- groups ---------------------------------------------------------------------------------------

def groups_list():
    im = snap("groups.list/default")
    cover = first(col_runs(im, 5, near("#434343", 4), 0, 400))
    rows = [("cover height", "groups.list.size.coverHeight", t("groups.list.size.coverHeight"), span(cover))]
    circle = fill_box(im, 345, 22)
    disc = extent(im, near(circle["color"], 3), (300, 0, 393, 60))
    rows += [("'+' circle fill over the cover", "groups.list.color.headerCircleOverPhoto", "#1C1C1C (#00000094 over the #434343 placeholder)", circle["color"], {"note": "composited over the test cover"}),
             ("'+' circle trailing inset", "size.global.headerInset", t("size.global.headerInset"), M.W - disc[2], {"tol": 1.0}),
             ("'+' circle diameter", "size.global.headerButton", t("size.global.headerButton"), disc[2] - disc[0], {"tol": 1.0})]
    cards = col_runs(im, 320, near(t("groups.list.color.card"), 2), 200, 852)
    side = row_runs(im, (cards[0][0] + cards[0][1]) / 2, near(t("groups.list.color.card"), 2))
    card = {"left": side[0][0], "top": cards[0][0], "color": t("groups.list.color.card")}
    rows += [("card height", "groups.list.size.cardHeight", t("groups.list.size.cardHeight"), span(cards[0])),
             ("card gap", "size.global.listGap", t("size.global.listGap"), cards[1][0] - cards[0][1]),
             ("card side margin", "size.global.screenMargin", t("size.global.screenMargin"), side[0][0]),
             ("card right margin", "size.global.screenMargin", t("size.global.screenMargin"), M.W - side[-1][1]),
             ("card radius", "radius.global.card", t("radius.global.card"), round(corner_radius(im, card, "#000000"), 2), {"tol": 1.0}),
             ("card fill", "groups.list.color.card", t("groups.list.color.card"), color_at(im, 320, cards[0][0] + 5))]
    av = row_runs(im, (cards[0][0] + cards[0][1]) / 2, near(t("color.global.controlRaised"), 3), 12, 120)
    avc = col_runs(im, (av[0][0] + av[0][1]) / 2, near(t("color.global.controlRaised"), 3), cards[0][0], cards[0][1])
    rows += [("avatar diameter", "size.global.avatarList", t("size.global.avatarList"), av[0][1] - av[0][0]),
             ("avatar inset in the card", "groups.list.size.avatarInset", t("groups.list.size.avatarInset"), av[0][0] - side[0][0]),
             ("avatar vertically centred", "groups.list.size.avatarInset", (cards[0][0] + cards[0][1]) / 2, (avc[0][0] + avc[-1][1]) / 2, {"tol": 1.0}),
             ("avatar fill", "color.global.controlRaised", t("color.global.controlRaised"), color_at(im, av[0][0] + 6, (cards[0][0] + cards[0][1]) / 2))]
    cam = extent(im, bright(200), (330, cards[0][0], 381, cards[0][1]))
    rows.append(("camera glyph (visible width)", "groups.list.size.cameraGlyph", t("groups.list.size.cameraGlyph"), cam[2] - cam[0], {"status": "approx", "note": "the token sizes the icon box (16); the Material glyph draws ~20/24 of it"}))
    empty = snap("groups.list/empty")
    brows, btn = box_rows("empty-state button", empty, 40, 458, "#000000", None, "size.global.buttonHeight", "radius.global.button", "color.global.accent", "size.global.buttonMarginH")
    rows += brows
    return [("Layout (groups.list/default, empty)", rows)]


def groups_create():
    im = snap("groups.create/filled")
    x = extent(im, near(t("color.global.controlOnDeep"), 2), (0, 0, 80, 60))
    rows = [("✕ diameter", "size.global.headerButton", t("size.global.headerButton"), x[2] - x[0]),
            ("✕ inset", "size.global.headerInset", t("size.global.headerInset"), x[0])]
    cover = fill_box(snap("groups.create/default"), 100, 100)
    rows += [("cover width", "groups.create.size.cover.width", t("groups.create.size.cover.width"), cover["width"]),
             ("cover height", "groups.create.size.cover.height", t("groups.create.size.cover.height"), cover["height"]),
             ("cover radius", "groups.create.radius.cover", t("groups.create.radius.cover"), round(corner_radius(snap("groups.create/default"), cover, "#000000"), 2), {"tol": 1.0}),
             ("cover fill", "groups.create.color.cover", t("groups.create.color.cover"), cover["color"]),
             ("cover centred", "groups.create.size.cover.width", M.W / 2, (cover["left"] + cover["right"]) / 2)]
    frows, field = box_rows("name field", im, 60, 344, "#000000", None, "size.global.fieldHeight", "radius.global.field", "groups.create.color.field", "size.global.buttonMarginH")
    rows.append(("cover → field", "groups.create.size.mediaToField", t("groups.create.size.mediaToField"), field["top"] - cover["bottom"]))
    rows += frows
    tr = extent(im, near(t("groups.screen.color.segmentTrack"), 2), (0, 400, 393, 470))
    track = first(col_runs(im, 295, near(t("groups.screen.color.segmentTrack"), 2), 400, 470))
    pcol = first(col_runs(im, 156, near(t("color.global.surfaceLight"), 3), 400, 470))
    pill = (None, pcol[0])
    rows += [("segment track height", "groups.screen.size.segmentHeight", t("groups.screen.size.segmentHeight"), span(track), {"tol": 1.0, "note": "exact-colour rows (anti-aliased edges excluded)"}),
             ("selected pill inset", "groups.screen.size.segmentInset", t("groups.screen.size.segmentInset"), pill[1] - track[0], {"tol": 1.0}),
             ("segment track fill", "groups.screen.color.segmentTrack", t("groups.screen.color.segmentTrack"), color_at(im, tr[2] - 4, (track[0] + track[1]) / 2))]
    brows, btn = box_rows("create group", im, 40, 811, "#000000", None, "size.global.buttonHeight", "radius.global.button", "color.global.accent", "size.global.buttonMarginH")
    rows += brows
    rows.append(("button → bottom of the safe area", "groups.create.size.fieldToButton", t("groups.create.size.fieldToButton"), M.H - btn["bottom"]))
    hud_img = snap("groups.create/creating")
    hud = fill_box(hud_img, 160, 426)
    rows += [("Loading HUD side", "groups.create.size.hud", t("groups.create.size.hud"), hud["width"]),
             ("Loading HUD fill", "groups.create.color.hud", t("groups.create.color.hud"), hud["color"])]
    return [("Layout (groups.create/filled, default, creating)", rows)]


def groups_invite():
    im = snap("groups.invite/default-family")
    x = extent(im, near(t("color.global.controlOnDeep"), 2), (0, 0, 80, 60))
    rows = [("✕ diameter", "size.global.headerButton", t("size.global.headerButton"), x[2] - x[0]),
            ("✕ inset", "size.global.headerInset", t("size.global.headerInset"), x[0])]
    title = extent(im, bright(140), (0, 45, 393, 150))
    label = extent(im, bright(60), (0, title[3] + 1, 393, title[3] + 60))
    rows.append(("title bottom → link label (text)", "groups.create.size.titleToContent", t("groups.create.size.titleToContent"), label[1] - title[3], {"status": "approx", "note": "ink to ink: + ascender space of the 16 sp label (~3) + the label row centres its text on the taller link icon (~2.5) + 'y' descender vs text bottom (~1.5)"}))
    pill = extent(im, near(t("color.global.surfaceLight"), 3), (100, label[3], 300, label[3] + 80))
    rows += [("share pill height", "groups.screen.size.lightPillHeight", t("groups.screen.size.lightPillHeight"), pill[3] - pill[1]),
             ("share pill centred", "groups.screen.size.lightPillHeight", M.W / 2, (pill[0] + pill[2]) / 2, {"tol": 1.0}),
             ("title line 2 colour (lime)", "color.global.accent", t("color.global.accent"), M.hexof(max((im.getpixel((xx, int(2 * (title[3] - 12)))) for xx in range(100, 680)), key=lambda p: p[1])))]
    c = snap("groups.invite/contacts")
    pills = col_runs(c, 340, near(t("color.global.surfaceLight"), 3), 280, 340)
    av = row_runs(c, (pills[0][0] + pills[0][1]) / 2, near(t("color.global.controlRaised"), 3), 0, 100)
    rows += [("contact avatar diameter", "size.global.avatarPicker", t("size.global.avatarPicker"), av[-1][1] - av[0][0], {"tol": 1.0, "note": "person glyph splits the run; first to last edge (anti-aliased rim excluded)"}),
             ("contact row leading margin", "size.global.screenMargin", t("size.global.screenMargin"), av[0][0], {"tol": 1.0})]
    a1 = col_runs(c, (av[0][0] + av[-1][1]) / 2, near(t("color.global.controlRaised"), 3), 280, 500)
    tops = [r[0] for r in a1 if r[1] - r[0] > 5]
    rows.append(("contact row pitch", "groups.invite.size.pickerRowPitch", t("groups.invite.size.pickerRowPitch"), tops[2] - tops[0] if len(tops) > 2 else None, {"tol": 1.0, "note": "avatar top to the next avatar top"}))
    return [("Layout (groups.invite/default-family, contacts)", rows)] + permission_card("")


def groups_screen():
    im = snap("groups.screen/default")
    rows = [("feed background", "color.global.background", t("color.global.background"), color_at(im, 3, 600))]
    back = extent(im, near(t("color.global.control"), 3), (0, 0, 59, 50))
    rows += [("back circle diameter", "size.global.headerButton", t("size.global.headerButton"), back[2] - back[0]),
             ("back circle inset", "size.global.headerInset", t("size.global.headerInset"), back[0]),
             ("header circle fill", "color.global.control", t("color.global.control"), color_at(im, back[0] + 5, 22))]
    cap = row_runs(im, (back[1] + back[3]) / 2, near(t("color.global.control"), 3), back[2], 300)
    rows.append(("back → capsule gap", "size.global.headerGap", t("size.global.headerGap"), cap[0][0] - back[2] if cap else None, {"tol": 1.0, "note": "on the centre row"}))
    card_col = col_runs(im, 30, near("#434343", 3), 40, 852)
    card = fill_box(im, 30, 100)
    rows += [("photo card side margin", "groups.screen.size.cardMarginH", t("groups.screen.size.cardMarginH"), card["left"]),
             ("photo card height", "groups.screen.size.cardHeight", t("groups.screen.size.cardHeight"), card_col[2][1] - card_col[0][0] if len(card_col) > 2 else None, {"note": "test photos are flat #434343; glyphs split the column"}),
             ("photo card radius", "groups.screen.radius.card", t("groups.screen.radius.card"), round(corner_radius(im, card, t("color.global.background")), 2), {"tol": 1.0})]
    chat = extent(im, near(t("groups.screen.color.chatPill"), 2), (100, 760, 300, 852))
    rows += [("chat pill width", "groups.screen.size.chatPillWidth", t("groups.screen.size.chatPillWidth"), chat[2] - chat[0]),
             ("chat pill height", "groups.screen.size.chatPillHeight", t("groups.screen.size.chatPillHeight"), chat[3] - chat[1], {"note": "bottom of the safe area; no inset in the snapshot"}),
             ("chat pill fill", "groups.screen.color.chatPill", t("groups.screen.color.chatPill"), color_at(im, chat[0] + 6, (chat[1] + chat[3]) / 2)),
             ("chat pill centred", "groups.screen.size.chatPillWidth", M.W / 2, (chat[0] + chat[2]) / 2)]
    p = snap("groups.screen/profile")
    avr = row_runs(p, 95, near("#434343", 3), 100, 300)
    rows += [("profile avatar diameter", "groups.screen.size.profileAvatar", t("groups.screen.size.profileAvatar"), avr[-1][1] - avr[0][0], {"tol": 1.0, "note": "test avatar is a flat #434343 disc; glyph splits the run"}),
             ("profile background", "color.global.backgroundDeep", t("color.global.backgroundDeep"), color_at(p, 3, 600))]
    tcol = first(col_runs(p, 370, near(t("groups.screen.color.segmentTrack"), 2), 150, 350))
    tex = extent(p, near(t("groups.screen.color.segmentTrack"), 2), (0, tcol[0], 393, tcol[1]))
    scol = first(col_runs(p, 30, near(t("color.global.surfaceLight"), 3), 150, 350))
    rows += [("segment track height", "groups.screen.size.segmentHeight", t("groups.screen.size.segmentHeight"), span(tcol), {"tol": 1.0, "note": "exact-colour rows (anti-aliased edges excluded)"}),
             ("segment side margin", "groups.screen.size.segmentMarginH", t("groups.screen.size.segmentMarginH"), tex[0], {"tol": 1.0}),
             ("selected pill inset", "groups.screen.size.segmentInset", t("groups.screen.size.segmentInset"), scol[0] - tcol[0], {"tol": 1.0})]
    e = snap("groups.screen/created")
    pcol = first(col_runs(e, 112, near(t("color.global.surfaceLight"), 3), 300, 760))
    prow = first(row_runs(e, (pcol[0] + pcol[1]) / 2, near(t("color.global.surfaceLight"), 3)))
    rows += [("'invite more' pill height", "groups.screen.size.lightPillHeight", t("groups.screen.size.lightPillHeight"), span(pcol), {"tol": 1.0}),
             ("'invite more' pill radius", "groups.screen.radius.lightPill", t("groups.screen.radius.lightPill"), round(corner_radius(e, {"left": prow[0], "top": pcol[0], "color": t("color.global.surfaceLight")}, t("color.global.background")), 2), {"tol": 1.0})]
    en = snap("groups.screen/entries")
    ecol = col_runs(en, 270, near(t("color.global.control"), 3), 40, 300)
    erow = first(row_runs(en, ecol[0][0] + 17, near(t("color.global.control"), 3)))
    erows = [("entry card side margin", "groups.screen.size.cardMarginH", t("groups.screen.size.cardMarginH"), erow[0], {"tol": 1.0}),
             ("entry card gap", "groups.screen.size.cardGap", t("groups.screen.size.cardGap"), ecol[1][0] - ecol[0][1] if len(ecol) > 1 else None, {"tol": 1.0}),
             ("entry card radius", "radius.global.card", t("radius.global.card"), round(corner_radius(en, {"left": erow[0], "top": ecol[0][0], "color": t("color.global.control")}, t("color.global.background")), 2), {"tol": 1.0}),
             ("entry card fill", "color.global.control", t("color.global.control"), color_at(en, 270, ecol[0][0] + 4), {"status": "approx", "note": "the fill choice is this pass's: Yope has no such row (see the note above the tables)"}),
             ("'Let's go' capsule height", "onboarding.permission.contacts.size.cardButtonHeight", t("onboarding.permission.contacts.size.cardButtonHeight"), span(first(col_runs(en, 330, near(t("color.global.surfaceLight"), 3), ecol[1][0], ecol[1][1]))), {"tol": 1.0})]
    return [("Layout (groups.screen/default, profile, created)", rows), ("Memory entries above the feed (groups.screen/entries)", erows)]


def system_rows(surface, state, row_label, y_hint):
    """M3 list metrics on a system surface: one-line row height and colours."""
    im = snap(f"{surface}/{state}")
    bg = color_at(im, 3, 840)
    rows = [("list background", "color.global.system.surface", t("color.global.system.surface"), bg)]
    return im, rows


def settings_root():
    im = snap("settings.root/default")
    rows = [("list background", "color.global.system.surface", t("color.global.system.surface"), color_at(im, 3, 840))]
    div = col_runs(im, 200, near(t("color.global.system.outline"), 6), 100, 852)
    rows += [("divider thickness", "settings.root.size.divider.android", t("settings.root.size.divider.android"), span(div[0]) if div else None, {"tol": 0.5}),
             ("divider colour", "color.global.system.outline", t("color.global.system.outline"), color_at(im, 200, div[0][0]) if div else "—"),
             ("one-line rows between dividers (3 × 56)", "settings.root.size.listItemOneLine.android", 3 * t("settings.root.size.listItemOneLine.android"), div[1][0] - div[0][1] if len(div) > 1 else None, {"tol": 1.0, "note": "Notifications · Account · Blocked People"})]
    text = extent(im, bright(120), (0, div[0][1] + 2, 393, div[0][1] + 54))
    rows.append(("row leading padding", "settings.root.size.listItemPaddingH.android", t("settings.root.size.listItemPaddingH.android"), text[0], {"tol": 1.5, "note": "ink of the first glyph"}))
    return [("M3 list (settings.root/default)", rows)]


def settings_simple(surface, state):
    im = snap(f"{surface}/{state}")
    return [(f"M3 list ({surface}/{state})", [("list background", "color.global.system.surface", t("color.global.system.surface"), color_at(im, 3, 840))])]


def safety_block():
    im = snap("safety.block/confirm")
    box = fill_box(im, 196, 426)
    return [("M3 dialog (safety.block/confirm)", [("dialog container", "color.global.system.surfaceContainerHigh", t("color.global.system.surfaceContainerHigh"), box["color"]),
                                                   ("dialog shape / width", "settings.account.layout.alert", "M3 AlertDialog, corner 28", "platform AlertDialog (Robolectric draws the dialog window edge to edge)", {"status": "match (behaviour)"})])]


def paywall():
    im = snap("paywall/default")
    rows = [("background (top stop)", "paywall.color.backgroundTop", t("paywall.color.backgroundTop"), color_at(im, 20, 0.078 * M.H), {"note": "gradient stop at 0.078 of the height, x = 20"})]
    perk = col_runs(im, 330, near(t("paywall.color.perk"), 3), 80, 400)
    side = row_runs(im, perk[0][0] + 30, near(t("paywall.color.perk"), 3))
    rows += [("perk card height", "paywall.size.perkHeight", t("paywall.size.perkHeight"), span(perk[0]), {"tol": 1.0}),
             ("perk gap", "paywall.size.perkGap", t("paywall.size.perkGap"), perk[1][0] - perk[0][1] if len(perk) > 1 else None, {"tol": 1.0}),
             ("perk side margin", "paywall.size.perkMarginH", t("paywall.size.perkMarginH"), side[0][0], {"tol": 1.0}),
             ("perk fill", "paywall.color.perk", t("paywall.color.perk"), color_at(im, 30, perk[0][0] + 30))]
    text = extent(im, near(t("paywall.color.perkTitle"), 30), (60, perk[0][0], 360, perk[0][1]))
    rows.append(("perk text inset", "paywall.size.perkTextInset", t("paywall.size.perkTextInset"), text[0] - side[0][0], {"tol": 1.5, "note": "ink of the first glyph"}))
    cta = extent(im, near(t("paywall.color.cta"), 3), (0, 700, 393, 852))
    rows += [("CTA height", "paywall.size.ctaHeight", t("paywall.size.ctaHeight"), cta[3] - cta[1]),
             ("CTA side margin", "paywall.size.perkMarginH", t("paywall.size.perkMarginH"), cta[0], {"tol": 1.0}),
             ("CTA fill", "paywall.color.cta", t("paywall.color.cta"), color_at(im, cta[0] + 30, (cta[1] + cta[3]) / 2))]
    sheet = snap("paywall/planSheet-yearly")
    sel = extent(sheet, near(t("paywall.color.planBorder"), 3), (0, 450, 393, 852))
    unsel = col_runs(sheet, 100, near(t("paywall.color.plan"), 3), sel[3], 852)
    sub = extent(sheet, near(t("paywall.color.subscribe"), 3), (0, sel[3], 393, 852))
    rows += [("selected plan height", "paywall.size.planSelectedHeight", t("paywall.size.planSelectedHeight"), sel[3] - sel[1], {"note": "with the border; no detail line is shown (monthly equivalent not built)"}),
             ("plan side margin", "paywall.size.planMarginH", t("paywall.size.planMarginH"), sel[0]),
             ("selected border colour", "paywall.color.planBorder", t("paywall.color.planBorder"), color_at(sheet, sel[0] + 1, (sel[1] + sel[3]) / 2)),
             ("selected fill", "paywall.color.planSelected", t("paywall.color.planSelected"), color_at(sheet, sel[0] + 8, (sel[1] + sel[3]) / 2)),
             ("unselected plan height", "paywall.size.planHeight", t("paywall.size.planHeight"), span(unsel[0]) if unsel else None),
             ("unselected fill", "paywall.color.plan", t("paywall.color.plan"), color_at(sheet, 100, (unsel[0][0] + unsel[0][1]) / 2) if unsel else "—"),
             ("Subscribe height", "paywall.size.subscribeHeight", t("paywall.size.subscribeHeight"), sub[3] - sub[1]),
             ("Subscribe fill", "paywall.color.subscribe", t("paywall.color.subscribe"), color_at(sheet, sub[0] + 30, (sub[1] + sub[3]) / 2))]
    return [("Layout (paywall/default, planSheet-yearly)", rows)]


def _y(ref):
    return REF + ref


SURFACES = [
    dict(id="auth.phone", what="Phone number entry (sign up or log in) — `android/feature/account/.../auth/PhoneScreen.kt`, `CountryCode.kt`.",
         ours="auth.phone/filled", ref=_y("a-yrrah-7454430216123862280-t6.73-signup-2024.png"), measure=auth_phone),
    dict(id="auth.code", what="SMS code entry with SMS User Consent — `auth/CodeScreen.kt`, `SmsUserConsent.kt`.",
         ours="auth.code/default", ref=_y("a-virgi-7686278541255642390-t31.23-signup-es.png"), ref_note="Yope's code screen was never filmed; the reference is the sign-in screen it is assembled from.", measure=auth_code),
    dict(id="auth.agegate", what="Birthday (neutral age screen) with the opt-in row — `auth/AgeGateScreen.kt`.",
         ours="auth.agegate/filled-optIn", ref=_y("a-itsmthuyope-7644974799302823175-t49.23-new-group-selected-create.png"), ref_note="NG: the form field and check circles the screen is assembled from.", measure=auth_agegate),
    dict(id="auth.profile", what="Name and photo — `auth/ProfileScreen.kt`.",
         ours="auth.profile/filled-photo", ref=_y("a-itsmthuyope-7644974799302823175-t51.73-group-profile-add-20-pics.png"), ref_note="the large avatar of the group profile (92 pt).", measure=auth_profile),
    dict(id="onboarding.permission.camera", what="Camera permission: request by camera.capture, M3 rationale dialog (core:ui `PermissionRationale`), denied card (core:ui `PermissionCard`).",
         ours="onboarding.permission.camera/denied", ref=_y("a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png"), ref_note="the inline permission card reused for the camera.", snapdir="onboarding.permission.camera", measure=lambda: permission_card(" — the same component")),
    dict(id="onboarding.permission.notifications", what="Notifications pre-prompt (API 33+) then POST_NOTIFICATIONS — `onboarding/NotificationsPermissionScreen.kt`.",
         ours="onboarding.permission.notifications/default-android13", ref=_y("a-virgi-7686278541255642390-t7.23-notif-preprompt-es.png"), measure=notifications),
    dict(id="onboarding.permission.photos", what="Photos: no screen (Photo Picker); denied-save card = core:ui `PermissionCard`.",
         ours="onboarding.permission.photos/denied", ref=_y("a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png"), measure=lambda: permission_card(" — the same component")),
    dict(id="onboarding.permission.contacts", what="Contacts: the inline card in groups.invite, then READ_CONTACTS — `groups/GroupInviteScreen.kt`, core:ui `PermissionCard`.",
         ours="groups.invite/default-contactsCard", ref=_y("a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png"), snapdir="groups.invite", measure=lambda: permission_card("")),
    dict(id="onboarding.widget", what="Add-the-widget steps — `onboarding/WidgetScreen.kt`.",
         ours="onboarding.widget/default", ref=LOCKET + "lazyweb/locket-lazyweb-20260821-cap-welcome.png", measure=widget),
    dict(id="groups.list", what="Home: cover, group cards, empty state, tab bar (shell) — `groups/GroupsListScreen.kt`, core:ui `FloatingTabBar`.",
         ours="groups.list/default", ref=_y("a-savannahclooney-7683341732695592206-t6.73-home-list.png"), measure=groups_list),
    dict(id="groups.create", what="New group / edit group sheet — `groups/GroupCreateScreen.kt`.",
         ours="groups.create/filled", ref=_y("a-itsmthuyope-7644974799302823175-t49.23-new-group-selected-create.png"), measure=groups_create),
    dict(id="groups.invite", what="Invite: share link, contacts — `groups/GroupInviteScreen.kt`.",
         ours="groups.invite/default-family", ref=_y("a-yrrah-7452976839846382855-t10.73-add-friends-share-link-2024.png"), measure=groups_invite),
    dict(id="groups.screen", what="Group feed, profile page, created / empty states — `groups/GroupScreen.kt`, `GroupProfileScreen.kt`.",
         ours="groups.screen/default", ref=_y("a-itsmthuyope-7644974799302823175-t43.73-group-screen-hourly.png"), measure=groups_screen,
         extra="Memory entries (onthisday.md, year.story.md, birthday.request.md → A: \"the row component, its position and tokens belong to the groups.screen pass\"): the memory pass's `OnThisDayEntry`, `YearStoryEntry` and `BirthdayRequestEntries` supply copy and action; this screen places them above the feed in `GroupEntryCard`. **Approximated**: Yope draws no such row and groups.screen names no tokens for it, so the card is Yope's inline-card pattern (`onboarding.permission.contacts.layout.card`: 16 insets, title 17 bold, detail 14 secondary, white capsule button) filled with the screen's control colour (`color.global.control`), photo-card margins and gap (`groups.screen.size.cardMarginH` / `.cardGap`), corners `radius.global.card`."),
    dict(id="groups.settings", what="Group settings (M3 list) — `groups/GroupSettingsScreen.kt`.",
         ours="groups.settings/default-admin", ref=_y("a-yrrah-7434441926000037121-t43.23-members-list-2024.png"), ref_note="Yope's members list; ours is the platform list the spec prescribes.", measure=lambda: settings_simple("groups.settings", "default-admin")),
    dict(id="settings.root", what="Settings (M3 list) — `settings/SettingsRootScreen.kt`.",
         ours="settings.root/default", ref=LOCKET + "lazyweb/locket-lazyweb-20260803-autocap-21.png", measure=settings_root),
    dict(id="settings.notifications", what="Notification settings (M3 list) — `settings/SettingsNotificationsScreen.kt`.",
         no_ref="system surface; the spec's references are the HIG / M3 list guidelines (no image).", measure=lambda: settings_simple("settings.notifications", "default")),
    dict(id="settings.account", what="Account settings, delete account — `settings/SettingsAccountScreen.kt`.",
         no_ref="system surface; the spec's references are Apple / Google account-deletion guidance (no image).", measure=lambda: settings_simple("settings.account", "default")),
    dict(id="settings.blocked", what="Blocked people — `settings/SettingsBlockedScreen.kt`.",
         no_ref="system surface; the spec's references are the HIG / M3 list guidelines (no image).", measure=lambda: settings_simple("settings.blocked", "default")),
    dict(id="safety.report", what="Report sheet (M3 modal bottom sheet) — `safety/ReportSheet.kt`.",
         no_ref="system surface; the spec's references are HIG / M3 sheet guidelines (no image)."),
    dict(id="safety.block", what="Block confirmation (M3 dialog) and toast — `safety/BlockDialog.kt`.",
         no_ref="system surface; the spec's references are HIG / M3 dialog and menu guidelines (no image).", measure=safety_block),
    dict(id="system.permissions", what="Runtime permission rationale (M3 dialog) and permanently-denied path — core:ui `PermissionRationale`, `rememberPermissionRequest`.",
         ours="system.permissions/rationale-contacts", ref=_y("a-virgi-7686278541255642390-t35.23-camera-permission-alert.png"), ref_note="Yope's iOS camera alert (the benefit wording); Android shows the M3 rationale dialog."),
    dict(id="paywall", what="Paywall, plan sheet, welcome — `paywall/PaywallScreen.kt`, `PremiumGateway.kt`.",
         ours="paywall/default", ref=LOCKET + "mobbin/locket-mobbin-paywall-screen.png", measure=paywall,
         extra="Release builds omit the paywall while `{app_name}` is BLOCKED (its title and CTA copy need the name): an entry that reaches it closes it at once; the debug render above shows the blocked copy with the literal `{app_name}`."),
]
