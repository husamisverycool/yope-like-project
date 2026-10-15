# Redesign brief: every surface on Retro's design system

The owner judged the first build "super cheap and bad" and asked for one app to model everything on.
The lead chose **Retro** (`docs/DESIGN_DIRECTION.md`, `docs/OWNER_DECISIONS.md` last entry). This brief
governs the redesign passes. `docs/CONVENTIONS.md` (the prime rule) and `docs/SURFACE_SPEC_BRIEF.md`
(output format of tokens, copy and surface specs) still apply; where they conflict, this brief wins.

## Inputs
- `design/research/retro-visual.md` — Retro's measured visual system (light and dark), components,
  surface mapping.
- `design/research/retro-package-copy-motion.md` — fonts and licences, package constants, copy voice,
  motion, widgets / onboarding / notifications.
- Evidence files under `references/auto/retro/` (INDEX.md). Mechanics references stay where they were
  (`references/auto/{locket,bereal,imessage,whatsapp,tribute,vidday,wrapped,…}`).

## The three layers
1. **Identity (Retro)** — every colour (light AND dark), type role, spacing, radius, border, icon style,
   photo treatment, motion curve, and the copy voice. Nothing visual comes from another app.
2. **Mechanics (feature specialists)** — what a control does and the flow, where Retro has no such
   feature: camera and widgets (Locket), daily dual capture (BeReal), chat behaviour (Messages /
   WhatsApp), birthday video (Tribute / VidDay), year-story pacing (Wrapped), paywall (StoreKit /
   Play Billing). Their screens are drawn only with identity-layer tokens and components.
3. **Platform (Apple HIG / Material 3)** — native sheets, alerts, menus, switches, pickers, share sheet,
   Dynamic Type / font scale, haptics. Level PLATFORM.

A surface with a Retro analog (home week strip, friend cards, story viewer, profile walls by week,
journals = our groups, recaps, Rewind = On This Day, notifications, settings, onboarding) follows that
analog's layout and components. A surface without one is **composed only from Retro components** (see
`design/components.md`) arranged by the mechanics reference's flow; each such composition is recorded
in the surface spec as `level: SOURCED` with `method: "composition of Retro components <list> in
<mechanics ref>'s order"` — no new visual values.

## Appearance
The app follows the system Light / Dark setting (Retro supports both). Every colour token carries
`{"light": "#…", "dark": "#…"}` (`tools/designgen.mjs` emits dynamic colours on iOS and
`LocalDsDarkTheme`-backed getters plus `Tokens.ColorsLight` / `Tokens.ColorsDark` on Android). A
colour that is identical in both appearances may stay a plain hex. Photos, the camera and full-screen
viewers stay dark in both appearances only if Retro's own equivalent does (record the evidence).

## Type
Retro uses a serif display face for titles ("Week 27", profile names) and a sans for UI text. The
display role's family token is `{"ios": "system-serif", "android": "serif"}` (PLATFORM: New York /
Noto Serif) with `notes` naming Retro's face (Roslindale, David Jonathan Ross — commercial licence;
OWNER_SETUP lists the purchase). Sizes, weights, tracking and line heights are Retro's measured values.
UI text uses the platform sans (`"system"`) unless the research proves another face.

## Pass 1 — Foundations (one agent, before any surface)
Outputs:
1. `design/tokens/global.json` rebuilt on Retro: colours (light/dark), text roles (display serif,
   titles, body, captions, labels, buttons), spacing scale and screen margins, radii, borders/hairlines,
   component sizes, icon tokens (SF Symbol / Material Symbol names + weight/size matching Retro's style),
   motion (durations, curves, springs from Retro's recordings; platform defaults where Retro shows
   none), haptics (PLATFORM). Keep an existing global token **name** when its role is unchanged so
   code keeps compiling; remove Yope-only tokens nothing will need; list every rename/removal in
   `design/tokens/README.md` → "Redesign renames".
2. `design/components.md` (new): the Retro component catalogue every screen is built from — header
   (large serif title + trailing icon buttons), tab bar, primary / secondary / outline pill buttons,
   icon buttons, text fields, list rows and grouped sections, week strip day tile (photo / empty / add),
   photo card (friend card), story viewer chrome (progress, header, reply bar), avatar sizes and stacks,
   badges ("new"), menus / sheets (native), toasts, empty states, loading states (skeletons or
   spinners as Retro shows), section headers ("Week 26 · Jun 26 – Jul 2"). Each: anatomy, tokens for
   every value in both appearances, states (pressed / disabled / selected), accessibility, evidence.
3. `design/copy-patterns.md` rewritten for Retro's voice (casing, tone, punctuation, emoji, empty
   states, errors, prompts, buttons, notifications) with verbatim Retro examples per pattern id.
4. `tools/contrast.mjs` checks both appearances for `{light, dark}` colours; `design/CONTRAST.md`
   regenerated (report failures; don't change sourced values).
5. `docs/SURFACES.md`: every surface's visual reference → Retro (screen named), mechanics reference
   kept where Retro has no analog.
6. `design/MERGE_DECISIONS.md` → new section "Redesign — Foundations (R-*)".

## Pass 2 — Surface groups (four agents in parallel, after Pass 1)
Same outputs as `docs/SURFACE_SPEC_BRIEF.md` for the group's surfaces (account, capture, social,
memory — the split in that brief's predecessor passes, see `design/MERGE_DECISIONS.md` sections):
rewrite `design/tokens/<group>.json`, `design/copy/<group>.json` and every `design/surfaces/<id>.md`
of the group on Retro. Rules:
- Reuse `global.*` tokens and `design/components.md` components by name. A surface token exists only
  when Retro measured something specific for that surface.
- **Copy**: rewrite every string in Retro's voice (`design/copy-patterns.md`). Keep a copy **key** when
  its meaning is unchanged (code references it) and change its text; add keys for new elements;
  delete keys nothing needs. Tenets still filter everything (no counts, streaks, guilt, "late").
- **Structure** follows the Retro analog named in SURFACES.md; mechanics from the mechanics reference.
- Every state (loading, empty, error, offline, permission-denied) drawn with Retro components.
- Both appearances: list the light and dark contrast pairs per surface.
- Log conflicts and compositions in `design/MERGE_DECISIONS.md` → "Redesign — <Group> (R<G>-*)".
- `node tools/designgen.mjs --check && node tools/designgen.mjs && node tools/provenance-check.mjs`
  must pass. Do not commit. Touch only your group's files and your MERGE section.

## Pass 3 — Component library (two agents: iOS, Android; can start right after Pass 1)
Implement every component in `design/components.md` once, from tokens only: iOS in
`ios/App/Sources/Components/` (SwiftUI), Android in `android/core/ui/` (Compose), each with a snapshot
per component state in light and dark, and the app-level theme (Android: wrap the app and every test
host in `DsTheme`; iOS: remove the forced dark appearance — `ios/Config/App.xcconfig` /
`preferredColorScheme(.dark)` — so the system setting applies). Replace the old Yope-era components
they supersede; keep the public names other groups already call where the role is the same.

## Pass 4 — Screens (eight agents: four groups × iOS / Android, after Pass 2 and 3)
`docs/SCREENS_BRIEF.md` applies, plus: build every screen from the Pass 3 components and the Pass 2
specs; wrap snapshots in the appearance under test (iOS `.environment(\.colorScheme, …)`, Android
`DsTheme(dark = …)`); record every state in light and the primary state of each surface also in dark;
snapshots use the real sample photos in `fixtures/photos/`; view models, data access and tests of
behaviour stay unless the new spec changes the behaviour.
