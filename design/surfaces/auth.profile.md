# `auth.profile` — name, then profile photo

Visual reference: Retro sign-up steps FULL_NAME (form) and PROFILE_PHOTO (onboarding page) in Retro's order
(RP §6.3, APK-S `onboarding_form_input_hint_full_name`, `onboarding_v3_page_title_profile_photo`, `onboarding_v3_profile_photo_cta_*`).
Neither step was captured as an image: step 1 is the onboarding form composition of `auth.phone` B; step 2 composes
C-23 (avatar), C-05 and C-08 under a display title (`level: SOURCED`, `method: "composition of Retro components C-02,
C-12, C-23, C-05, C-08 in Retro's sign-up order (FULL_NAME → … → PROFILE_PHOTO)"`). Retro asks for a username first; this
app has no usernames (docs/API.md §5.1). Tokens: `auth.profile.*`. Copy: `auth.profile.*`.

## References

| id | file | used for |
|---|---|---|
| APK-S | `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | hints, titles, "Choose photo" / "Edit photo" / "Maybe Later", "Name too long" (`error_full_name_too_long`) |
| WEB | `references/auto/retro/web/retro.app-5bff8a0be69f7ec7.css`, design/research/retro-package-copy-motion.md §7 | 112-pt centred avatar (`auth.profile.size.avatar`), placeholder fill #EDEDED |
| LAND | `references/auto/retro/lazyweb/retro-lazyweb-20251119-social.png` | capsule and secondary link (C-05, C-08) |

## Structure

### Step 1 — name (onboarding form)
1. C-02 header row, no back (age is confirmed; the account exists).
2. Title `auth.profile.title` (`font.global.display`, `displayMedium`), baseline `size.global.titleTop`.
3. Explanation `auth.profile.subtitle` (`body`, `color.global.textSecondary`).
4. `size.global.titleToContent`: name field C-12, placeholder `auth.profile.field.placeholder`.
5. `size.global.sectionHeaderToContent` below: note `auth.profile.field.note` (`caption`, `color.global.textSecondary`).
6. C-05 `auth.profile.continue`, pinned `size.global.buttonMarginH` above the keyboard.

### Step 2 — profile photo (onboarding page, keyboard down)
1. C-02 header row with back → step 1.
2. Title `auth.profile.photo.title` (`displayMedium`), baseline `size.global.titleTop`; explanation
   `auth.profile.photo.subtitle` under it.
3. Avatar circle `auth.profile.size.avatar` (112), centred in the space between the explanation and the capsule;
   empty = `auth.profile.layout.avatarPicker.empty` (C-23 fallback: `color.global.control` + `icon.global.person`
   in `color.global.textSecondary`); chosen photo aspect-fills the circle.
4. C-05 primary capsule at the bottom margin: `auth.profile.avatar.add` ("Choose photo") while empty;
   `auth.profile.continue` ("Next") once a photo is chosen.
5. `auth.phone.size.capsuleToLink` below: C-08 secondary link — `auth.profile.photo.skip` ("Maybe Later") while empty;
   `auth.profile.avatar.edit` ("Edit photo") once chosen.

## Elements

| element | tokens / component | copy | behaviour |
|---|---|---|---|
| title / explanation | `displayMedium`; `body` + `textSecondary` | `auth.profile.title`, `.subtitle`; `.photo.title`, `.photo.subtitle` | static |
| name field | C-12 | `auth.profile.field.placeholder`, `auth.profile.field.accessibilityLabel` | 1–80 characters after trimming; return = Next |
| note | `caption`, `textSecondary` | `auth.profile.field.note` | static |
| too long | inline under the field: text role `meta`, `color.global.destructive` (C-12 error) | `auth.profile.error.tooLong` | shown past 80 characters; Next disabled |
| avatar | `auth.profile.size.avatar`, circle (`radius.global.capsule`), `auth.profile.layout.avatarPicker` | `auth.profile.avatar.accessibilityLabel`, `auth.profile.avatar.changeAccessibilityLabel` | tap = same as Choose photo / Edit photo |
| Choose photo / Next | C-05 | `auth.profile.avatar.add` / `auth.profile.continue` | Choose photo → system picker (no permission); Next → upload and continue |
| Maybe Later / Edit photo | C-08 | `auth.profile.photo.skip` / `auth.profile.avatar.edit` | Maybe Later → continue without a photo (no follow-up nudge); Edit photo → picker again |

## States

| state | when | design | copy |
|---|---|---|---|
| step 1 default | `display_name` empty | as Structure | — |
| saving name | `update profiles set display_name` | Next busy (C-05 / C-28) | — |
| name failed | write failed | message-only alert (`auth.phone.layout.inlineError`) | `auth.profile.error.save` + `auth.phone.error.dismiss` |
| step 2 empty / chosen | — | as Structure | — |
| uploading photo | Storage upload + `avatar_path` update | Next busy | — |
| upload failed | Storage error | message-only alert; the circle returns to empty | `auth.profile.error.upload` |
| offline | no connection | C-27 block replaces field / avatar and capsules (as `auth.phone`) | `auth.phone.offline.*` |
| empty list / permission-denied | — | not applicable (the picker needs no permission) | — |

## Motion

Step 1 → 2 and back: onboarding page transition `duration.global.pageTransition` (500 ms) fade + expand / fade + shrink,
`easing.global.standard` (C-33). Picker: system sheet. The chosen photo fades in `duration.global.fade` (150 ms).
Reduce Motion: cross-fades.

## Haptics

Presses → `haptic.global.tap` (Android). Saved → `haptic.global.success`; failed → `haptic.global.error`.

## Accessibility

- Avatar: image button labelled `auth.profile.avatar.accessibilityLabel` (empty) / `.changeAccessibilityLabel` (chosen).
- Dynamic Type: titles `largeTitle`; explanation `subheadline`; note `subheadline`; field `body`; capsule `headline`;
  link `subheadline`.
- Focus order: step 1 title → explanation → field → note → Next; step 2 back → title → explanation → avatar → capsule → link.
- Contrast: as `auth.phone` (rows 1, 3, 9, 11, 13, 17); error text `destructive` on the light page **4.18:1 FAIL** for
  13 pt (row 31; dark 5.03:1 pass); avatar fill vs page 1.13:1 / 1.39:1 (non-text; the glyph identifies it, row 13).

## Data & actions

- Name: `update profiles set display_name` (docs/API.md §5.0).
- Photo: upload JPEG to `avatars/<uid>/<uuid>.jpg`, then `update profiles set avatar_path` (docs/API.md §2, §7).
- In: `auth.agegate`; any launch where `display_name` is "". Out: `onboarding.permission.notifications` → `onboarding.widget`
  → the pending invite's `join_group` or `groups.list`.

## Platform notes

- iOS `PhotosPicker(selection:matching: .images)`; Android `PickVisualMedia(ImageOnly)`; neither asks for library access.

## Do-not-copy

- Retro's skip-attempt nudge ("Let your friends know it's you by setting a profile photo!") — no nagging (tenet 5).
- Retro's username step and its Rive empty-state animation.

## Gaps

| item | status | smallest capture |
|---|---|---|
| Retro's FULL_NAME and PROFILE_PHOTO pages | composition; avatar size from Retro's web invite page | raw screenshots of the sign-up steps on a fresh install (RV §6) |
