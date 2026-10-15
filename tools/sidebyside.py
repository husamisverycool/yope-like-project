#!/usr/bin/env python3
"""Side-by-side verification image: our screen next to its reference (directive Part 8).

Usage:
  sidebyside.py OUT.png OURS.png REF.png [--ref-crop x,y,w,h] [--ours-crop x,y,w,h]
                [--title TEXT] [--height H]

Both images are scaled to the same height (default: the smaller of the two, max 1600 px) and placed
next to each other on a neutral background with a caption above each ("ours" / the reference file
name). The output is a local review artifact (design/verification/ is git-ignored while the repo is
public, because the reference half is third-party material).
"""
import argparse
import os
import sys

from PIL import Image, ImageDraw, ImageFont


def crop(img, spec):
    if not spec:
        return img
    x, y, w, h = (int(v) for v in spec.split(","))
    return img.crop((x, y, x + w, y + h))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("ours")
    ap.add_argument("ref")
    ap.add_argument("--ref-crop")
    ap.add_argument("--ours-crop")
    ap.add_argument("--title", default="")
    ap.add_argument("--height", type=int)
    a = ap.parse_args()

    ours = crop(Image.open(a.ours).convert("RGB"), a.ours_crop)
    ref = crop(Image.open(a.ref).convert("RGB"), a.ref_crop)
    h = a.height or min(ours.height, ref.height, 1600)
    ours = ours.resize((round(ours.width * h / ours.height), h), Image.LANCZOS)
    ref = ref.resize((round(ref.width * h / ref.height), h), Image.LANCZOS)

    pad, cap = 24, 40
    title_h = cap if a.title else 0
    W = pad * 3 + ours.width + ref.width
    H = pad * 2 + title_h + cap + h
    sheet = Image.new("RGB", (W, H), (128, 128, 128))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype(os.path.join(os.path.dirname(__file__), "..", "backend", "worker", "fonts", "Roboto-Regular.ttf"), 22)
    except OSError:
        font = ImageFont.load_default()
    y0 = pad
    if a.title:
        d.text((pad, y0), a.title, fill=(255, 255, 255), font=font)
        y0 += title_h
    d.text((pad, y0), "ours: " + os.path.basename(a.ours), fill=(255, 255, 255), font=font)
    d.text((pad * 2 + ours.width, y0), "reference: " + os.path.basename(a.ref), fill=(255, 255, 255), font=font)
    sheet.paste(ours, (pad, y0 + cap))
    sheet.paste(ref, (pad * 2 + ours.width, y0 + cap))
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    sheet.save(a.out)
    print(a.out, sheet.size)


if __name__ == "__main__":
    sys.exit(main())
