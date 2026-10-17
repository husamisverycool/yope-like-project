#!/usr/bin/env bash
# Commits a run's real screens to the branch (ci.yml, workflow_dispatch with commit_screens): the PNGs under $1 are
# copied to $2 (replacing what was there), named by step. With $3 = xcresult, $1 is an `xcresulttool export attachments`
# folder and its manifest.json names each file ("<name>_<n>_<UUID>.png" → "<name>.png").
set -euo pipefail
src="$1"; dest="$2"; kind="${3:-plain}"
rm -rf "$dest"; mkdir -p "$dest"
if [ "$kind" = xcresult ]; then
  python3 - "$src" "$dest" <<'PY'
import json, os, re, shutil, sys
src, dest = sys.argv[1], sys.argv[2]
manifest = json.load(open(os.path.join(src, "manifest.json")))
for test in manifest:
    for a in test.get("attachments", []):
        name = a.get("suggestedHumanReadableName", "")
        file = a.get("exportedFileName", "")
        if not file.lower().endswith(".png"):
            continue
        clean = re.sub(r"_\d+_[0-9A-Fa-f-]{36}(?=\.png$)", "", name)
        if clean.startswith("Screenshot") or clean.startswith("UI Snapshot"):
            continue
        shutil.copy(os.path.join(src, file), os.path.join(dest, clean))
PY
else
  find "$src" -maxdepth 1 -name '*.png' -exec cp {} "$dest"/ \;
fi
ls "$dest" | head -100
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add -A "$dest"
if git diff --cached --quiet; then echo "no screen changed"; exit 0; fi
git commit -m "Screens from CI: $dest (at ${GITHUB_SHA::7})"
for i in 1 2 3 4; do
  git push origin "HEAD:${GITHUB_REF#refs/heads/}" && exit 0
  # The build leaves tracked files modified (generated project, copied fixtures); stash them around the rebase.
  git pull --rebase --autostash origin "${GITHUB_REF#refs/heads/}"
  sleep $((i * 5))
done
exit 1
