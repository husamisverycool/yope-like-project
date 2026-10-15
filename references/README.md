# References

- `owner/` — images the owner provided (Drive folder "INSPO"). Evidence level CAPTURED.
  **Owner drop zone:** put any new screenshots or screen recordings here (any file name); note in
  `owner/INDEX.md` what each one shows. They take priority over everything we find ourselves.
- `auto/<app>/` — material found by research (App Store / Google Play screenshots, web captures,
  frames from public videos). Evidence level SOURCED. Each folder's `INDEX.md` maps every file to
  its source URL, access date and app version.

The image files are not committed while the GitHub repository is public (internal reference
only; see `.gitignore`). `python3 tools/fetch_references.py` re-downloads every image whose
source URL is a direct image link and lists the frames that must be re-extracted from videos.
