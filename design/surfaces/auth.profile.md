# `auth.profile` — name and avatar

Reference: **Yope onboarding**. Research: `design/research/yope-a.md` §2.4 (in-app step not found; website demo only);
API: `docs/API.md` §2, §5.0, §5.1, §7 (avatars). Tokens: `auth.profile.*` + shared sign-up/form tokens. Copy: `auth.profile.*`.

**Yope's name/avatar step was not found** (after Apple sign-in, Yope goes straight to the camera permission). Built from
the same documented Yope parts as `auth.phone`, plus Yope's large profile avatar and default-avatar look.

## References

As `auth.phone`, plus:

| id | file | used for |
|---|---|---|
| GP | `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t51.73-group-profile-add-20-pics.png` | large avatar circle size (92 pt) |
| ML | `references/auto/yope/frames/a-yrrah-7434441926000037121-t43.23-members-list-2024.png` | default avatar = gray circle + person silhouette |

## Structure (black, centred)

1. Status bar. 2. No header circles. 3. Title `auth.profile.title`. 4. Subtitle `auth.profile.subtitle`.
5. Gap `groups.create.size.titleToContent`. 6. Avatar circle `auth.profile.size.avatar`, centred.
7. Caption `auth.profile.avatar.add` under it (hidden once a photo is chosen), `groups.create.size.fieldToButton` below
   the circle. 8. Gap `groups.create.size.mediaToField`. 9. Name field. 10. Field note `auth.profile.field.note` under
   the field. 11. Gap `groups.create.size.fieldToButton`. 12. Primary button `auth.profile.continue`. 13. Keyboard.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| title / subtitle | onboarding title; `auth.phone.fontSize.subtitle`, `auth.phone.layout.subtitle` | `auth.profile.title`, `auth.profile.subtitle` | static |
| avatar circle | `auth.profile.size.avatar`; empty look `auth.profile.layout.avatarPicker` (`color.global.controlRaised` + `icon.global.person` in `color.global.textSecondary`); picker per `auth.profile.layout.avatarPicker` | `auth.profile.avatar.accessibilityLabel` / `auth.profile.avatar.changeAccessibilityLabel` | tap → system photo picker (one image); the chosen image is shown cropped to the circle |
| avatar caption | `fontSize.global.listSubtitle`, `color.global.textSecondary` | `auth.profile.avatar.add` | taps open the picker too |
| name field | Yope form field tokens (`groups.create.color.field`, `size.global.fieldHeight`, `radius.global.field`, `groups.create.fontSize.fieldText`); `textContentType(.givenName)` / `ContentType.PersonFirstName` autofill | `auth.profile.field.placeholder`, `auth.profile.field.accessibilityLabel` | max 80 characters (docs/API.md §5.1), trimmed |
| field note | `fontSize.global.caption`, `color.global.textSecondary`, centred | `auth.profile.field.note` | static privacy note |
| continue | lime primary + disabled tokens | `auth.profile.continue` | enabled when the trimmed name is non-empty; uploads the avatar (if any) then updates `profiles` |
| HUD | as `auth.phone` | `groups.create.hud.loading` | while uploading / saving |

## States

| state | when | design | copy |
|---|---|---|---|
| default | after `auth.agegate` | as Structure | — |
| saving | upload / update in flight | HUD | `groups.create.hud.loading` |
| upload failed | Storage error | presentation **BLOCKED** (`auth.phone.layout.inlineError`); the avatar returns to empty; continue stays enabled | `auth.profile.error.upload` |
| save failed | `profiles` update error | presentation **BLOCKED** | `auth.profile.error.save` |
| offline | no connection | Yope empty-state layout + retry pill | `auth.phone.offline.title`, `auth.profile.offline.detail`, `auth.phone.offline.retry` |
| permission-denied | — | none: the system photo picker needs no permission | — |

## Motion

Native push in/out; the picker is a system sheet. Reduce Motion: platform behaviour.

## Haptics

Saved → `haptic.global.success`; failed → `haptic.global.error`.

## Accessibility

- Avatar circle: button, label `auth.profile.avatar.accessibilityLabel` (empty) / `auth.profile.avatar.changeAccessibilityLabel`
  (photo chosen); the image itself is not described.
- Dynamic Type: title `largeTitle`; subtitle, caption 14 → `subheadline`; field `subheadline`; note `caption`.
- Focus order: title → subtitle → avatar → name field → note → continue.
- Contrast: as `auth.phone`; person glyph #969696 on #434343 — not computed as a pair (decorative inside a labelled button).

## Data & actions

- Avatar: upload JPEG to `avatars/<uid>/<uuid>.jpg`, then `update profiles set avatar_path` (docs/API.md §2, §5.0).
- Name: `update profiles set display_name` (or `data.display_name` at OTP sign-in).
- In: `auth.agegate`; any launch where `display_name` is `""`. Out: `onboarding.permission.notifications` (then
  `onboarding.widget`, then the pending invite's `join_group` or `groups.list`). The camera and photos steps have no
  screen (`onboarding.permission.camera.md`, `onboarding.permission.photos.md`).

## Platform notes

- iOS `PhotosPicker(selection:matching: .images)`; Android `PickVisualMedia(ImageOnly)`. Neither asks for library access.

## Do-not-copy

- Yope website demo items ("pick your face", "vibe color", "wallpaper", "randomize", cut-out face stickers).

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| Yope name/avatar step | not found → composed | one ~40 s English screen recording of a fresh Yope install up to the first camera screen, tapping "try other options" |
| avatar size | approximation (group-profile avatar, 92 pt) | same recording |
| default-avatar gray | approximation (`color.global.controlRaised`) | lossless screenshot of a Yope member list with a default avatar |
| error presentation | BLOCKED (`auth.phone.layout.inlineError`) | same recording |
