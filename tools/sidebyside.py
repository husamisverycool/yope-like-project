#!/usr/bin/env python3
"""Side-by-side review image: our screen(s) next to the reference(s) (directive Part 8, redesign Pass 5).

Usage:
  sidebyside.py OUT.png OURS.png REF.png [--ref-crop x,y,w,h] [--ours-crop x,y,w,h]
                [--title TEXT] [--height H]
  sidebyside.py OUT.png --ours LIGHT.png DARK.png --ref REF1.png REF2.png [--title TEXT] [--height H]

Every image is scaled to the same height (default: the smallest of them, max 1600 px) and placed in one
row on a neutral grey background with a caption above each ("ours: <file>" / "reference: <file>"), ours
first. The output is a local review artifact: design/verification/ images are git-ignored while the repo
is public, because the reference half is third-party material.
"""
import argparse
import os
import sys

from PIL import Image, ImageDraw, ImageFont

FONT = os.path.join(os.path.dirname(__file__), "..", "backend", "worker", "fonts", "Inter-Regular.ttf")


def crop(img, spec):
    if not spec:
        return img
    x, y, w, h = (int(v) for v in spec.split(","))
    return img.crop((x, y, x + w, y + h))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("pos", nargs="*", help="OURS.png REF.png (two-image form)")
    ap.add_argument("--ours", nargs="+", default=[])
    ap.add_argument("--ref", nargs="+", default=[])
    ap.add_argument("--ref-crop")
    ap.add_argument("--ours-crop")
    ap.add_argument("--title", default="")
    ap.add_argument("--height", type=int)
    a = ap.parse_args()

    ours, refs = list(a.ours), list(a.ref)
    if a.pos:
        if len(a.pos) != 2:
            ap.error("positional form takes exactly OURS.png REF.png")
        ours.insert(0, a.pos[0])
        refs.insert(0, a.pos[1])
    if not ours or not refs:
        ap.error("need at least one of ours and one reference")

    panels = [("ours", p, crop(Image.open(p).convert("RGB"), a.ours_crop)) for p in ours]
    panels += [("reference", p, crop(Image.open(p).convert("RGB"), a.ref_crop)) for p in refs]
    h = a.height or min(min(img.height for _, _, img in panels), 1600)
    panels = [(k, p, img.resize((round(img.width * h / img.height), h), Image.LANCZOS)) for k, p, img in panels]

    pad, cap = 24, 40
    title_h = cap if a.title else 0
    W = pad * (len(panels) + 1) + sum(img.width for _, _, img in panels)
    H = pad * 2 + title_h + cap + h
    sheet = Image.new("RGB", (W, H), (128, 128, 128))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype(FONT, 22)
    except OSError:
        font = ImageFont.load_default()
    y0 = pad
    if a.title:
        d.text((pad, y0), a.title, fill=(255, 255, 255), font=font)
        y0 += title_h
    x = pad
    for kind, path, img in panels:
        d.text((x, y0), f"{kind}: {os.path.basename(path)}", fill=(255, 255, 255), font=font)
        sheet.paste(img, (x, y0 + cap))
        x += img.width + pad
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    sheet.save(a.out)
    print(a.out, sheet.size)


if __name__ == "__main__":
    sys.exit(main())
