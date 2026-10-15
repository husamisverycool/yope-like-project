# `groups.create` — create group: name, cover, type

Reference: **Yope** ("new group" sheet 2026; "create new group" / "create your first group" cover step 2024–2025).
Research: `design/research/yope-a.md` §1.3–1.4, §2.10; API `docs/API.md` §6.1 `create_group` / `update_group`, §9.2.
Tokens: `groups.create.*` (+ `groups.screen.*` segmented control). Copy: `groups.create.*`.

Yope 2026 has a name field and a friend picker but **no cover and no type**; the 2024–2025 builds had a cover step.
Group types (friends / family / roommates / custom) were **not found in any Yope build**: the type is chosen with Yope's
own segmented control (group profile, 2026-05). There is no friend picker here (members join by invite link,
`groups.invite`).

## References

| id | file | used for |
|---|---|---|
| NG1 | `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t45.23-new-group-empty.png` | sheet header: ✕ circle + "new group" |
| NG2 | `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t49.23-new-group-selected-create.png` | field (#141414, 44 pt, r 12, 19 pt margins, centred bold 15 pt text), section label, lime "create group" 45 pt |
| C24 | `references/auto/yope/frames/a-yrrah-7452976839846382855-t3.73-create-new-group-empty-2024.png` | cover placeholder (330 × 221, r 7, camera glyph), gaps, disabled button |
| BI | `references/auto/yope/web/a-bi-2025-create-group-composite.jpg` | cover photo with camera glyph, field, lime "continue" above the keyboard |
| GP | `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t51.73-group-profile-add-20-pics.png` | segmented control (track, white selected pill, bold labels) |
| HUD | `references/auto/yope/frames/a-itsmthuyope-7644974799302823175-t50.60-loading-hud.png` | Loading HUD after "create group" |

## Structure (sheet on black `color.global.backgroundDeep`)

1. Header row at the sheet top: ✕ circle leading (`size.global.headerButton`, fill `color.global.controlOnDeep`,
   `icon.global.close`, inset `size.global.headerInset`); title `groups.create.title` centred on the circle's row.
2. Gap `groups.create.size.titleToContent`.
3. Cover placeholder `groups.create.size.cover.width` × `.cover.height`, centred; camera glyph centred.
4. Gap `groups.create.size.mediaToField`.
5. Name field, full width minus `size.global.buttonMarginH`.
6. Gap `groups.create.size.mediaToField`.
7. Section label `groups.create.type.label`, leading-aligned at `size.global.buttonMarginH` (as "who would you like to add?").
8. Type segmented control directly under the label (the label → control gap was not measured; the label's platform line
   height is the only space): 4 segments in `groups.create.type.*` order friends · family · roommates · custom; default
   selection friends (first segment; enum order of `group_kind`).
9. Flexible space.
10. Primary button `groups.create.cta` (edit mode `groups.create.save`), full width minus `size.global.buttonMarginH`,
    `groups.create.size.fieldToButton` above the keyboard or the bottom safe area.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| ✕ | `size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.close`, `color.global.textPrimary` | `groups.create.close.accessibilityLabel` | dismisses; discards the form |
| title | `groups.create.fontSize.title`, `groups.create.fontWeight.title`, `color.global.textPrimary` | `groups.create.title` / `groups.create.titleEdit` | static |
| cover placeholder | `groups.create.size.cover.width` / `.height`, `groups.create.radius.cover`, fill `groups.create.color.cover`; glyph `icon.global.camera` height `groups.create.size.coverGlyph` in `color.global.textPrimary` | `groups.create.cover.accessibilityLabel` / `.changeAccessibilityLabel` | tap → system photo picker (`auth.profile.layout.avatarPicker` mechanism); the chosen photo fills the rectangle (`scaledToFill`), glyph hidden |
| name field | `groups.create.color.field`, `size.global.fieldHeight`, `radius.global.field`, text `groups.create.fontSize.fieldText` + `.fontWeight.fieldText` centred, placeholder `color.global.textSecondary` | `groups.create.name.placeholder`, `groups.create.name.accessibilityLabel` | 1–80 characters (trimmed); return key = done |
| section label | `fontSize.global.sectionLabel`, `fontWeight.global.sectionLabel`, `color.global.textSecondary` | `groups.create.type.label` | static |
| type control | track `groups.screen.color.segmentTrack`, height `groups.screen.size.segmentHeight`, side margin `size.global.buttonMarginH` (form column; the profile's 6 pt margin belongs to that page), capsule; selected pill `color.global.surfaceLight`, inset `groups.screen.size.segmentInset`, label `color.global.onSurfaceLight`; labels `groups.screen.fontSize.segmentLabel` / `.fontWeight.segmentLabel`, unselected `color.global.textPrimary` | `groups.create.type.friends` / `.family` / `.roommates` / `.custom` | single choice; changes only copy and defaults elsewhere (per-type strings in `groups.invite`, `groups.screen`, `groups.settings`, `onboarding.permission.contacts`) |
| create | `color.global.accent` / `color.global.onAccent`, `size.global.buttonHeight`, `radius.global.button`, text role `button`; disabled `groups.create.color.buttonDisabledFill` / `.buttonDisabledLabel` | `groups.create.cta` / `groups.create.save` | disabled while the trimmed name is empty; tap → upload cover (if any) → `create_group` → HUD → push to `groups.screen` (new group) |
| HUD | `groups.create.color.hud`, `.size.hud`, `.fontSize.hudLabel`, system spinner | `groups.create.hud.loading` | while working |

## States

| state | when | design | copy |
|---|---|---|---|
| default | opened from `groups.list` (+ / empty state) | as Structure | — |
| edit | opened from `groups.settings` (admin) | prefilled; cover shows the current cover; button `groups.create.save` | `groups.create.titleEdit`, `groups.create.save` |
| creating / saving | upload + RPC | HUD (V-mthu t50.60) | `groups.create.hud.loading` |
| error | RPC failed | presentation **BLOCKED** (`auth.phone.layout.inlineError`) | `groups.create.error.failed` / `.saveFailed` |
| cover upload failed | Storage error | **BLOCKED** presentation; cover returns to the placeholder | `groups.create.error.cover` |
| offline | no connection | **BLOCKED** presentation | `groups.create.offline` |
| empty / permission-denied | — | none (system picker needs no permission) | — |

## Motion

- Presentation: native sheet (`easing.global.native` sheet); Yope's sheet spring is BLOCKED (`spring.global.sheetPresent`, F-15).
- After create: native push to the new group (Yope's measured 100 ms horizontal push, `duration.global.navigationPush`,
  cannot be applied to a native push, F-11) and the sheet closes.
- Segment change: the selected pill moves with `spring.global.platformDefault.ios` / `.android` (Yope's curve not
  measured); Reduce Motion → cross-fade (`layout.global.reduceMotion`).

## Haptics

Segment changed → `haptic.global.select`. Group created / saved → `haptic.global.success`. Failed → `haptic.global.error`.

## Accessibility

- Segmented control: iOS `Picker(.segmented)`-equivalent semantics (each segment a button with the selected trait) /
  Android `Role.Tab` + `selected`. Cover: button with the cover label.
- Dynamic Type: title 14.5 → `subheadline`; field `subheadline`; section label `callout`; segment labels `subheadline`
  (the control grows and labels wrap; no scale factor is sourced); button `subheadline`.
- Focus order: ✕ → title → cover → name → label → segments → create.
- Contrast: field text 18.42:1, placeholder 6.23:1, segment label on track 18.88:1, selected pill vs track 18.88:1,
  camera glyph on cover 9.00:1 pass; field vs black 1.14:1, track vs black 1.11:1, cover vs black 2.33:1 **FAIL**
  (non-text; labels/glyphs identify each control); disabled button exempt.

## Data & actions

- Cover: upload to `u/<uid>/covers/<uuid>.jpg` (docs/API.md §9.2, §12 item 17).
- `create_group(p_name, p_kind, p_time_zone: device IANA zone, p_cover_path?)` → `groups` (caller = admin).
  Waking hours omitted (default window, `app_config.default_waking_*`, NULL until set).
- Edit: `update_group(p_group_id, p_name?, p_kind?, p_cover_path?)` (admins; `""` removes the cover).
- Errors: `invalid_name`, `invalid_kind`, `invalid_time_zone`, `invalid_path`, `not_group_admin` (edit).
- In: `groups.list` (+, empty state), `groups.settings` (edit). Out: `groups.screen` (new group, created empty state).

## Platform notes

- iOS `.sheet` with the large detent (Yope's "new group" is full height); Android `ModalBottomSheet` expanded, or a
  full-screen destination. Keyboard: system; return key "done".

## Do-not-copy

- Yope's 2024 "group suggestions" presets ("school squad", "birthday blitz", …) and "hide"; forced friend selection.

## Gaps

| item | status | smallest capture / owner input |
|---|---|---|
| group type step in Yope | not found → Yope segmented control (approximation) | none possible (Yope has no types); owner to confirm |
| per-type defaults | none defined in the API (types change only copy here) | owner decision on any default (e.g. invitation hours) |
| cover placeholder in a 2026 build | 2024 values (older than 12 months) | one screenshot of a 2026 Yope group-cover editor, if one exists |
| label → control gap, error presentation | not measured / BLOCKED (`auth.phone.layout.inlineError`) | one ~40 s English recording of a fresh Yope install via "try other options" (errors); none for the gap |
| HUD corner radius | not measured | lossless screenshot of the Yope Loading HUD |
