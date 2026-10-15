#!/usr/bin/env python3
"""Download every App Store screenshot (original resolution) and the listing text for one app.

Usage: fetch_appstore.py <app-slug> <app-store-url> <out-dir>
Writes <out-dir>/store/<slug>-store-NN.png, <out-dir>/store/listing.html, and appends rows to
<out-dir>/INDEX.md (file | source URL | accessed | what it shows | version/date).
Screenshots are requested at /9999x0w.png, which mzstatic serves at the uploaded size.
"""
import html, json, os, re, subprocess, sys, datetime
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
slug, url, out = sys.argv[1:4]
store = os.path.join(out, "store"); os.makedirs(store, exist_ok=True)
page = subprocess.run(["curl", "-sL", "-A", UA, url], capture_output=True).stdout.decode("utf-8", "replace")
open(os.path.join(store, "listing.html"), "w").write(page)
norm = page.replace("\\u002F", "/").replace("\\/", "/")
bases = []
for m in re.finditer(r"https://is\d-ssl\.mzstatic\.com/image/thumb/[^\"', ]+?/([^/\"', ]+\.(?:jpg|jpeg|png|mill|webp))/[^\"', ]+", norm):
    base = m.group(0).rsplit("/", 1)[0]
    if "AppIcon" in base or "Features" in base or "Placeholder.mill" in base:
        continue
    if base not in bases:
        bases.append(base)
version = re.search(r'"versionDisplay"\s*:\s*"([^"]+)"', norm) or re.search(r"Version ([0-9][0-9.]+)", norm)
version = version.group(1) if version else "unknown"
today = datetime.date.today().isoformat()
idx = os.path.join(out, "INDEX.md")
new = not os.path.exists(idx)
with open(idx, "a") as f:
    if new:
        f.write(f"# {slug} references (SOURCED)\n\n| file | source URL | accessed | what it shows | version/date |\n|---|---|---|---|---|\n")
    for i, b in enumerate(bases, 1):
        name = f"{slug}-store-{i:02d}.png"
        src = b + "/9999x0w.png"
        r = subprocess.run(["curl", "-s", "-o", os.path.join(store, name), "-w", "%{http_code}", src], capture_output=True).stdout.decode()
        if r != "200":
            print("failed", src, r); continue
        f.write(f"| `store/{name}` | {src} | {today} | App Store screenshot {i} of {len(bases)} ({url}) | listing version {version} |\n")
        print(name, src)
print("version", version, "screenshots", len(bases))
