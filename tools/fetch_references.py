#!/usr/bin/env python3
"""Re-download reference images listed in references/**/INDEX.md.

Reference images are not committed while the GitHub repo is public (see .gitignore). Every
INDEX.md row is `| file | source URL | accessed | what it shows | version/date |`. This script
downloads each row whose source URL points directly at an image (App Store / Google Play /
web images) to its file path. Rows whose source is a video (frames) are listed so they can be
re-extracted with the timestamps recorded in the row.

Usage: python3 tools/fetch_references.py [--dry-run]
"""
import os, re, subprocess, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
dry = "--dry-run" in sys.argv
missing_frames = []
for base, _, files in os.walk(os.path.join(ROOT, "references")):
    if "INDEX.md" not in files:
        continue
    for line in open(os.path.join(base, "INDEX.md")):
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 2 or not cells[0].startswith("`"):
            continue
        rel = cells[0].strip("`")
        url = re.search(r"https?://\S+", cells[1])
        dest = os.path.join(base, rel)
        if os.path.exists(dest):
            continue
        if url and re.search(r"(mzstatic\.com|googleusercontent\.com|\.(png|jpe?g|webp)(\?|$))", url.group(0)):
            print("fetch", rel)
            if not dry:
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                subprocess.run(["curl", "-sL", "-A", UA, "-o", dest, url.group(0).rstrip(")")])
        else:
            missing_frames.append(f"{os.path.relpath(dest, ROOT)} <- {cells[1]}")
if missing_frames:
    print("\nNot directly downloadable (video frames, page captures, owner files); re-create from the source noted:")
    print("\n".join("  " + m for m in missing_frames))
