# `settings.downloads` — Download My Photos / Download Album

Owner decisions 29 and 34 (docs/RESEARCH_FEATURES_2026-10-17.md #2): **"Download My Photos" is free** (tenet 4 — nothing
gets lost; also offered before account deletion), **an album in full quality is premium** (the paywall's "Full-Quality
Downloads" perk). Mechanics: Retro "Download your package" (retro.app `/downloads`: a signed package of what you shared),
Yope's group menu "download all photos" (design/research/yope-a.md §2.13), Apple Shared Albums saving shared items to your
own library (support.apple.com/108314). Nothing is packaged on the server: the apps page `download_items` (migration 0052)
and save each original to the photo library themselves, as Save to Camera Roll does (owner decision 28).

Visual: a Settings sub-page (settings.root's pushed pages: native back + centred title on iOS; the C-29 sheet header with
the C-02 back glyph on Android, as settings.hidden) composed of Retro components: C-27 block, the platform progress bar
(PLATFORM — Retro's own was never captured), C-05 primary capsule, C-06 outline capsule, C-29 alert. Copy:
`design/copy/account.json` (`settings.downloads.*`, `settings.root.downloads`); `design/copy/social.json`
(`albums.view.menu.download`).

## Entry points

| from | item | scope | notes |
|---|---|---|---|
| `settings.root` → Privacy | `settings.root.downloads` ("Download My Photos") | `download_items('mine')` | free; the page waits for Download |
| `settings.account` delete alert | `settings.account.delete.download` ("Download My Photos") | `download_items('mine')` | free; the alert closes and this page opens (Instagram's and Google's download-before-delete step) |
| `albums.view` "•••" | `albums.view.menu.download` ("Download Album") | `download_items('album', id)` | premium; with premium the page opens and starts at once; without, the item shows `icon.global.lock` and opens the paywall at the full-quality downloads perk (`paywall.layout.promptRule`: once per session; iOS presents it from the album sheet, Android `PaywallPerkRoute("export")`); a late `premium_required` does the same |

## Structure (top → bottom)

1. Title: `settings.downloads.title` ("Download My Photos") or `.albumTitle` ("Download Album").
2. C-27 block, `size.global.titleToContent` below the header: glyph `icon.global.download`, detail
   `settings.downloads.detail` / `.albumDetail` + `settings.downloads.detailLibrary` (text role `emptyDetail`, secondary).
3. State line `size.global.sectionGap` below (text role `body`, secondary, centred, inside `size.global.screenMargin`):
   - saving: the platform progress bar (`color.global.accent` on `color.global.control` on Android; tint `color.global.accent`
     on iOS) — **indeterminate for your photos** (the total is never asked for; iOS shows the platform activity indicator),
     **a bar without figures for an album** (its rows arrive at once) — and `settings.downloads.progress` ("Downloading…")
     `size.global.listGap` under it. Never "12 of 340" (tenet 2): the bar's accessibility value is the progress line.
   - done: `settings.downloads.done` ("Saved!"), `haptic.global.success`, announced.
   - nothing to save: `settings.downloads.empty` ("Nothing to see here yet").
   - failed: `settings.downloads.error`; offline: `settings.downloads.offline`; `haptic.global.error`.
4. Bottom, pinned `size.global.buttonMarginH` from the edges, `size.global.sectionGap` above the safe area: the C-05 capsule
   `settings.downloads.start` ("Download") — `settings.downloads.resume` ("Continue") when an earlier download stopped before
   the end — or, while saving, the C-06 outline capsule `settings.downloads.cancel` filling the row.

## Behaviour

- `'mine'`: pages of 100 (`p_limit`, the API's default), newest first, `p_before` = the last row's `posted_at`, until a short
  page. `'album'`: every row at once, in album order.
- Each row: signed URL of `original_path` → the photo library with add-only access (iOS `PHPhotoLibrary` add-only: a Live
  Photo as still + paired motion, a video as a video; Android MediaStore: the still of a Live Photo — Android has no Live
  Photo, PLATFORM_CONSTRAINTS §Summary — and a video into Movies). A photo deleted meanwhile (`storage` not found) is skipped.
- **Resumable**: after each saved photo its place (`posted_at`, post id) is kept on the device per account and scope
  (iOS `UserDefaults`, Android app-private SharedPreferences). Cancel, a failure, or leaving the page stops after the photo
  being saved; reopening shows Continue and goes on from there. Done forgets the place.
- Permission: iOS asks add-only access at the first save (`system.permissions.photosAdd.purpose`); Android API 26–28 asks
  WRITE_EXTERNAL_STORAGE before starting. Denied → the platform alert `settings.downloads.denied.title` / `.message` with
  `.denied.button` (the app's page in system Settings) and `settings.downloads.cancel`.
- Captions and dates are not written into the library (no public caption field); the copy promises only the photos.

## States

| state | what shows |
|---|---|
| idle | block + Download (or Continue) |
| saving | block + progress + Cancel |
| done | block + "Saved!" + Download |
| empty | block + "Nothing to see here yet" + Download |
| failed / offline | block + the error / offline line + Continue (when something was saved) or Download |
| permission denied | the alert over the page |

## Haptics

| moment | token |
|---|---|
| every photo saved | `haptic.global.success` |
| failed, denied | `haptic.global.error` |

## Data & actions

`download_items(p_scope, p_album_id, p_before, p_limit)` (docs/API.md); signed URLs (§7). Errors: `premium_required` (402,
album) → the paywall; `album_not_found` → the error line.
