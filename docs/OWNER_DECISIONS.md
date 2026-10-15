# Owner decisions

Decisions the owner made during the build, with the date. They override the build directive where
they conflict.

## 2026-10-15 — Any successful app may be a design reference

> "take from ANY inspiration you need, not just what I told you" — the owner, after asking that the
> design be "extremely good and modeled off of the successful players" and work "very slickly".

What changes:
- Directive Part 3's list (Yope, Locket, BeReal, Retro, Spotify Wrapped, Timehop, Tribute/VidDay,
  Partiful, Apple HIG / Material 3) is no longer exhaustive. Any well-made, widely used app may be a
  reference (e.g. Instagram, Snapchat, iMessage, WhatsApp, Telegram, Lapse, Dispo, Apple Photos,
  Google Photos, Apple Invites, Gas).
- Each surface keeps its assigned primary reference from `docs/SURFACES.md`; other apps fill what the
  primary reference doesn't show (BLOCKED values) or show better-sourced evidence for the same pattern.

What does not change:
- No value comes from our own taste: every color, size, motion value, haptic and word is still traced
  to a specific app screen/image/video with evidence and an evidence level in the canonical files.
- The five tenets still filter everything (no counts, streaks, guilt, fake notifications…).
- Never copy another company's logo, name, trademark, mascot, proprietary illustration or font.

## 2026-10-15 — One design anchor for everything: Retro

> "I feel like the design looks super cheap and bad" … "think deeply about which app would be a better
> look for the designs to be much much better in every conceivable way, and then model everything
> based on that inspiration" — the owner.

The owner asked the lead to choose the single best app to model the whole design on. The lead chose
**Retro** (Lone Palm Labs; iOS `id6443709020`, Android `io.lonepalm.retro`). Reasoning and the
comparison against Apple Invites / Apple Photos and Yope: `docs/DESIGN_DIRECTION.md`.

What changes:
- Every visual value (color in light and dark, type, spacing, shape, iconography style, motion) and
  the copy voice now come from Retro's design system. Yope stops being the primary reference for
  visuals; directive Part 3's per-surface reference list is superseded for visuals.
- Surfaces Retro does not have (camera, daily dual capture, widgets, Live Activity, chat, birthday
  video, paywall) keep their *mechanics* from the apps that define them (Locket, BeReal, Messages,
  Tribute/VidDay, StoreKit) but are drawn entirely with Retro's tokens. No second visual language.
- Platform components (system sheets, alerts, switches, pickers, share sheet) stay native (Apple HIG,
  Material 3), as Retro's own app does.
- The app follows the system light / dark setting, as Retro does (supersedes MERGE F-1 "dark only").

What does not change: the evidence rule, the tenets, the legal boundary. Retro's name, wordmark, app
icon, illustrations and its licensed display typeface (Roslindale, by David Jonathan Ross) are not
copied; the typeface role is sourced, the font itself needs an owner licence (OWNER_SETUP §0).
