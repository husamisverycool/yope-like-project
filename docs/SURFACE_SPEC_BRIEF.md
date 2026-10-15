# Surface spec brief (for each surface-group consolidation pass)

You turn research into the build specs, tokens and copy for one group of surfaces. The iOS and
Android screens will be written from your specs alone, so they must be complete and exact. Read
first: `docs/CONVENTIONS.md`, `docs/SURFACES.md`, `docs/SPEC_FLAGS.md` (tenet tensions),
`docs/PLATFORM_CONSTRAINTS.md`, `docs/API.md` (the data each screen shows and the RPCs it calls),
`design/tokens/README.md` + `design/tokens/global.json` (foundations — reuse them by name, never
duplicate a foundation value), `design/copy-patterns.md` (voice patterns and which governs which
surface), `design/MERGE_DECISIONS.md`, and the research files and proposals for your surfaces.

## The rule
No design decision is yours. Every color, size, radius, font, icon, motion value, haptic and word
traces to research evidence with an evidence level. If two references conflict, the reference
assigned to the surface in SURFACES.md wins; log the conflict in `design/MERGE_DECISIONS.md` under
a section for your group. Never adjust a sourced value; if something fails (e.g. contrast), report
it and look for a sourced alternative. Where nothing is found:
- a native component may be used only if the reference app itself uses it on that surface, or the
  surface is a system surface (settings, permissions, accessibility) per HIG/M3 → PLATFORM;
- otherwise the value is BLOCKED (with the smallest owner capture that would settle it in `notes`).

## Outputs (only these files; prefix every token and copy key with your surface ids)
1. `design/tokens/<group>.json` — tokens specific to your surfaces (canonical schema). Reuse
   `global.*` tokens by reference in the spec instead of copying values.
2. `design/copy/<group>.json` — every user-facing string your surfaces need, canonical schema:
   `origin` verbatim/adapted/new, `pattern` = pattern id from copy-patterns.md, evidence. This
   includes: titles, buttons, placeholders, labels, accessibility labels (VoiceOver/TalkBack) for
   every icon-only control, empty / loading / error / offline / permission-denied texts, confirmation
   dialogs, toasts, push texts for your surfaces, widget gallery names/descriptions, Info.plist
   purpose strings (`infoPlistKey`). Use `{placeholder}` names for runtime values. Never a count of
   likes/reactions/views, a streak, a "late" label, guilt or nagging. `{app_name}` for the app name.
3. `design/surfaces/<surface-id>.md` — one per surface:
   - **References**: the images (paths from references/…/INDEX.md and research tables) the screen is
     verified against;
   - **Structure**: top-to-bottom layout, every element in order, with alignment;
   - **Elements table**: element | token names (size, color, radius, font role, icon, spacing) | copy
     keys | behavior;
   - **States**: loading, empty, error, offline, permission-denied (where applicable) — each with its
     tokens/copy and source, or BLOCKED;
   - **Motion**: transitions and their tokens (+ Reduce Motion substitute);
   - **Haptics**: interaction → `haptic.*` token;
   - **Accessibility**: labels, traits, Dynamic Type role per text, focus order, contrast pairs
     (run `node tools/contrast.mjs` and list results);
   - **Data & actions**: which `docs/API.md` reads/RPCs/realtime channels it uses, and navigation in
     and out (deep links from `ios/Packages/AppCore/Sources/AppModels/DeepLink*.swift` /
     `android/core/model/.../DeepLink.kt`);
   - **Platform notes**: iOS vs Android differences (native components, limits);
   - **Do-not-copy** and **Gaps** (BLOCKED items, approximations, owner captures).
4. Validate: `node tools/designgen.mjs --check` (no key may collide with another group's file), then
   `node tools/designgen.mjs` and `node tools/provenance-check.mjs` must pass. Do not commit.
   Other groups are written in parallel; touch only your own files (and append your own section to
   `design/MERGE_DECISIONS.md`).

Reply with: surfaces covered, counts of tokens/strings by evidence level, BLOCKED items with the
owner capture that would close each, contrast failures, and conflicts resolved.
