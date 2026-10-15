# Design direction: Retro as the single anchor

Decided 2026-10-15 after the owner judged the first build "super cheap and bad" and asked for the one
app to model everything on (docs/OWNER_DECISIONS.md).

## Why the first build looked cheap

1. Patchwork: each surface copied a different app (Yope, Locket's gold paywall and orange buttons,
   Tribute's web form, Timehop's orange banner, Partiful's invite card), so nothing read as one product.
2. Imprecise evidence: most Yope values were measured from compressed 30 fps TikTok frames.
3. Trend aesthetic: Yope's black-with-acid-lime look, small grey type.
4. No typographic identity: platform fonts only, no display face.
5. Snapshots used flat colour blocks instead of photos.

## Candidates compared

| | Retro | Apple Invites / Photos | Yope (old anchor) |
|---|---|---|---|
| Concept fit | Friends-only weekly photo journal, no likes, no algorithmic feed, shared group journals, Rewind (on this day), recaps — the closest existing product | Events + shared albums (Invites), memories (Photos): partial | Group photo sharing: close |
| Design standing | Built by ex-Instagram designers; covered by Fast Company Co.Design (2025-12); Google Photos' "My Week" test was reported as copying its design (TechCrunch 2024-07) | Highest polish in the industry | Young app, trend look |
| Scale | ~7.8 M downloads, ~1.7 M MAU (2026-08), premium tier ~$36/yr | Platform apps | small |
| Audience (friends **and** family) | Calm, editorial, readable; light and dark | Universal | Gen-Z |
| One identity on iOS and Android | Yes — Retro ships both | No — iOS only | Yes |
| Evidence quality | App Store + Play sets, press kits, raw device screenshots, Lazyweb captures, web CSS, Android app | Best (HIG, Design Resources) | TikTok frames |
| Distinctiveness | Strong (serif display, journal tone) | Looks like a system app | Trend |
| Covers our features | Home week strip, profile walls, journals (= groups), recaps, Rewind, story viewer, friends, notifications | Event pages, albums, memories, widget | most |

Retro wins on fit, identity, cross-platform consistency and audience; Apple's apps win only on raw
polish and spec precision, and Apple's design language is already the platform layer we keep
(system components, Dynamic Type, materials, haptics).

## How it is applied

- **Identity layer (Retro):** palette in light and dark, type roles (serif display for titles such as
  "Week 27", platform sans for UI text), spacing, tile/card/button shapes, icon style, motion, copy voice.
- **Mechanics layer (feature specialists, restyled):** camera and widget behaviour (Locket), daily dual
  capture (BeReal), chat behaviour (Messages), birthday video (Tribute/VidDay), year story pacing
  (Wrapped), paywall (StoreKit). Their screens are drawn only with the identity-layer tokens.
- **Platform layer (Apple HIG / Material 3):** native sheets, alerts, switches, pickers, share sheets.

## Risks the owner should know

- Retro is the closest direct competitor; modelling its design system closely invites comparison.
  We copy values and patterns, never its name, wordmark, icon, illustrations or font files. Owner's
  own name, icon and (ideally) a licensed display face keep the product distinct.
- Retro's display face is Roslindale (DJR). Until the owner licenses it (or picks another licensed
  face), the display role uses the platform serif (New York on iOS, Noto Serif on Android) — PLATFORM.
