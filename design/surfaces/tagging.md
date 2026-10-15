# `tagging` — "i'm in this" (self-tag)

Reference: **Yope voice** (docs/SURFACES.md); no face recognition. Yope has no tagging feature in any observed build
(yope-a, yope-b), so the control is assembled only from Yope foundation roles in `design/tokens/global.json`; this
surface adds no tokens. Voice: `yope.voice.button`, `yope.voice.coach`, `yope.voice.error`. Copy:
`design/copy/memory.json` (`tagging.*`).

What it does: on any photo in a group, a member can mark "i'm in this" — only for themselves (`tag_self` /
`untag_self`; nobody can tag someone else). Self-tags decide which photos a member may give to a birthday tribute
(`birthday.contribute`: photos you posted or are in). Tags are visible to the group's members (docs/API.md 5.11) but
this surface shows only your own state.

## References

| image | what it verifies |
|---|---|
| `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png` | white secondary pill ("enable") on black; toast style |
| `references/auto/yope/store/yope-store-04.png` | white pill with black label (`color.global.surfaceLight` / `onSurfaceLight`) |
| `references/auto/yope/frames/a-jacob-7691153057177931039-t3.73-camera-hold-to-record.png` | coach tooltip ("hold down to record"): lime, ≤ 6 words, ✕ |
| send-to rows in `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t6.73-sendto-voice-tooltip.png` | the selection check (empty ring / filled check in system blue) |

## Structure

The toggle is one control placed by the **`photo.viewer`** pass in the viewer's action area (that pass owns position
and size); `tagging` owns its content, states and behaviour:

- **Shape:** capsule (`radius.global.capsule`), fill `color.global.surfaceLight` (Yope's white secondary pill).
- **Content, left to right:** state glyph (`size.global.checkCircle`), gap `size.global.headerGap`, label
  `tagging.toggle` in text role `button` (`fontSize.global.button`, `fontWeight.global.button`),
  `color.global.onSurfaceLight`.
- **Off:** glyph `icon.global.uncheck` in `color.global.onSurfaceLight`.
- **On:** glyph `icon.global.check` in `color.global.selection` (the global "selected" role).
- **Coach** (first time a member opens a photo someone else posted, once per account): the foundations coach tooltip
  (lime, `color.global.accent` / `color.global.onAccent`, dismissible ✕) pointing at the toggle, text `tagging.coach`.

Shown on every photo the member can see, including their own (tagging yourself on your own photo is allowed but
changes nothing for tributes). Not shown on collages.

## Elements

| element | tokens | copy keys | behaviour |
|---|---|---|---|
| toggle (off) | `radius.global.capsule`, `color.global.surfaceLight`, `icon.global.uncheck`, `size.global.checkCircle`, `size.global.headerGap`, `fontSize/fontWeight.global.button`, `color.global.onSurfaceLight` | `tagging.toggle` | tap → on at once (optimistic) + `tag_self(post_id)` |
| toggle (on) | same, `icon.global.check`, `color.global.selection` | `tagging.toggle` | tap → off at once + `untag_self(post_id)` |
| toggle (pending) | same; taps ignored while the call runs | — | ≤ one call in flight per photo |
| coach | foundations coach tooltip (`color.global.accent`, `color.global.onAccent`, `icon.global.close`) | `tagging.coach` | ✕ or any tap on the toggle dismisses it for good |
| error toast | foundations toast | `tagging.error`, `tagging.notFound`, `tagging.offline` | the toggle returns to its previous state |

## States

| state | design | copy | source |
|---|---|---|---|
| off / on | above | `tagging.toggle` | — |
| error (call failed) | revert + toast | `tagging.error` | app voice |
| photo gone (`post_not_found`) | revert + toast; the viewer closes the photo (photo.viewer) | `tagging.notFound` | app voice |
| offline | toggle does not change; toast | `tagging.offline` | app voice |
| loading / empty / permission-denied | n/a (state comes with the photo's `post_tags` read) | — | — |

## Motion

Glyph swap without animation (no Yope toggle motion observed). Toast and coach: foundations motion. Reduce Motion:
`layout.global.reduceMotion`.

## Haptics

Toggle changed → `haptic.global.select` (the global "a recipient / group toggled" role). Error → `haptic.global.error`.

## Accessibility

- iOS: `Button` with label `tagging.toggle` and `.accessibilityAddTraits(.isSelected)` when on (VoiceOver reads
  "i'm in this, selected"). Android: `Modifier.toggleable(role = Role.Switch)` with the same label (TalkBack reads
  on / off). No extra strings.
- Dynamic Type: role `button` → `subheadline` (`layout.global.textStyleMap`); the capsule grows with the text.
- Touch target ≥ `size.global.minTouchTarget.ios` / `.android`.
- Contrast: `color.global.onSurfaceLight` on `color.global.surfaceLight` 21.00 pass; `color.global.selection` check on
  white 3.23 pass (non-text 3:1); white pill vs `color.global.backgroundDeep` 21.00 / vs `color.global.background`
  17.93 pass.

## Data & actions

- **Read:** `from("post_tags").select("user_id").eq("post_id", p).eq("user_id", uid)` (or the viewer's batch read of
  the post's tags) → on / off.
- **Writes:** `rpc("tag_self", p_post_id)` → `post_tags`; `rpc("untag_self", p_post_id)` → void. Both idempotent.
  Error `post_not_found`.
- **Used by:** `birthday.contribute` (eligible photos = posted by you ∪ tagged by you). `year.compute`
  (`backend/worker/src/jobs/year.ts`) does not read tags today — the year story cards are group-level.
- **Navigation:** none (inline control). No push.

## Platform notes

Same component on both platforms; no native switch is used (Yope has no switch on app surfaces; the toggle is the
white pill). Optimistic update with rollback on error.

## Do-not-copy

Face recognition or suggested tags; tagging other people; "{n} people in this" or any count of tags; notifying anyone
that you tagged yourself.

## Gaps

| item | status | owner capture |
|---|---|---|
| Yope tagging UI | none exists; built from foundation roles | — (owner may point to a reference app for tagging) |
| position / size in the viewer | owned by `photo.viewer` | — |
