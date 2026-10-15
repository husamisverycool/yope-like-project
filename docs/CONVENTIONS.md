# Conventions

Everyone (people and agents) working in this repo follows these rules. They implement
Part 2 of the build directive: no design decision is ours.

## 1. Directory layout

| Path | What lives there |
|---|---|
| `references/owner/` | Images the owner provided (their Drive "INSPO" folder). Evidence level **CAPTURED**. Index: `references/owner/INDEX.md`. |
| `references/auto/<app>/` | Images and video frames we found ourselves. Evidence level **SOURCED**. Each app folder has an `INDEX.md` (file → source URL, date accessed, what it shows, app version/date). `references/auto/INDEX.md` links them. |
| `design/research/<app>.md` | Per-reference-app findings: per surface, layout, measured values (with file, pixel coordinates and method), verbatim copy, motion. |
| `design/proposals/<app>.tokens.json`, `design/proposals/<app>.copy.json` | Machine-readable values found by each research pass, in the schemas below. Merged into the canonical files. |
| `design/tokens.json` | Canonical design tokens. Every token carries its source and evidence level. |
| `design/copy.json` | Canonical user-facing strings. Every string carries its source, or the documented pattern it follows. |
| `design/SOURCES.md` | Human-readable ledger of every design decision (generated from tokens.json + copy.json + the surface specs). |
| `design/COPY.md` | Human-readable copy ledger (generated) plus the documented voice patterns per surface. |
| `design/surfaces/<surface-id>.md` | The build spec for one surface: elements, the token and copy keys each uses, and the reference images. |
| `design/verification/` | Side-by-side images (our screen next to its reference) with a checklist of matched values. |
| `design/collage-options/` | The same-moment collage options shown to the owner. |
| `tools/` | Codegen (tokens/copy → Swift, Kotlin, TypeScript), provenance lint, color sampler, side-by-side composer. |
| `backend/` | Supabase project (migrations with RLS, storage policies, seed for tests), worker (job queue, media, push), tests. |
| `web/` | Invite preview page (Partiful-style), `apple-app-site-association`, `assetlinks.json`. |
| `ios/` | XcodeGen project: app, widgets + Live Activity extension, notification service extension, App Clip, `AppCore` Swift package. |
| `android/` | Gradle project: app (Compose), Glance widgets, core modules. |

## 2. Evidence levels

`SOURCED` · `CAPTURED` · `VERIFIED` · `PLATFORM` · `BLOCKED` exactly as defined in the directive.
`BLOCKED` values may exist in `design/` while research is open, but `tools/provenance-check`
fails the build if any value used by shipped code is `BLOCKED`.

## 3. Token schema (`design/tokens.json` and proposals)

```json
{
  "tokens": {
    "<dotted.name>": {
      "type": "color | dimension | radius | fontSize | fontWeight | lineHeight | letterSpacing | duration | easing | spring | opacity | blur | shadow | icon | haptic | font | layout",
      "value": "...",
      "unit": "pt | px | ms | ... (optional)",
      "source_app": "Yope | Locket | BeReal | Retro | Timehop | Spotify Wrapped | Tribute | VidDay | Partiful | Apple HIG | Material 3 | W3C WCAG 2.2 | Meta developer docs (standards: accessibility thresholds, share-image specs)",
      "surface": "<surface id from docs/SURFACES.md>",
      "element": "what exactly on the screen",
      "evidence": "file path + pixel coords, or URL (+ timestamp for video)",
      "method": "how the value was obtained (e.g. median of 5x5 px; width/screen_width * 393)",
      "level": "SOURCED | CAPTURED | VERIFIED | PLATFORM | BLOCKED",
      "precision": "e.g. ±1 pt, ±3/255 per channel, ±1 frame at 30 fps (optional)",
      "notes": "conflicts, alternatives, why (optional)"
    }
  }
}
```

Naming: `<category>.<surface-or-component>.<element>[.<state>]`, lowercase, dots. Examples:
`color.chat.background`, `radius.chat.bubble`, `font.size.chat.message`, `icon.composer.mic`,
`duration.widget.photoArrival`, `haptic.capture.shutter`.

Icons: `value` is an object `{ "ios": "<SF Symbol name>", "android": "<Material Symbols name>" }`.
SF Symbols / Material Symbols are PLATFORM assets; log which reference glyph each one matches.

Fonts: if the reference app's typeface is proprietary or unknown, the token is
`{ "ios": "system", "android": "system" }` with level `PLATFORM` (SF Pro / Roboto).

## 4. Copy schema (`design/copy.json` and proposals)

```json
{
  "strings": {
    "<dotted.key>": {
      "text": "exact string; placeholders as {name}",
      "infoPlistKey": "optional: iOS Info.plist key this string fills, e.g. NSCameraUsageDescription",
      "origin": "verbatim | adapted | new",
      "source_app": "...",
      "surface": "<surface id>",
      "evidence": "file/URL (+ timestamp) of the original string, or of the pattern examples",
      "pattern": "for adapted/new: the documented pattern it follows (see COPY.md patterns)",
      "level": "SOURCED | CAPTURED | VERIFIED | PLATFORM | BLOCKED",
      "notes": "optional"
    }
  }
}
```

- `verbatim`: the reference app's own string, unchanged (only allowed where it is not a
  trademark or the app's name).
- `adapted`: the reference string with only nouns swapped for our domain (e.g. "friends" → the
  group's member noun). The substitution is noted.
- `new`: a string that has no counterpart, written to follow a documented pattern. `pattern` must
  name the pattern id from `design/COPY.md` and its example strings.

Never include another company's name, logo, trademark or mascot in any string.
The app's display name is the token `{app_name}`; its value comes from the owner (BLOCKED until then).

## 5. In code

- UI code never contains a literal color, size, duration, font or user-facing string. It reads
  generated constants (`Tokens.*`, `Copy.*` in Swift; `Tokens.*`, `R.string.*` in Kotlin;
  `copy.*` in TypeScript). `tools/provenance-check` enforces this.
- Every screen file starts with a header comment naming its surface id and reference images.
- Forbidden reasoning in code, comments and messages: "looks clean", "modern", "feels nice",
  "I think", "a nice touch", "for polish", "a reasonable default".

## 6. The five tenets gate every feature

Closeness without effort · Real, not performed · The group, not the individual ·
Nothing gets lost · Invitations, never obligations. No streaks, likes, counts, "late" labels,
guilt, nagging or fake notifications anywhere — including copied reference UI (strip streak pills,
counts, "N min late", etc. when copying a layout).
