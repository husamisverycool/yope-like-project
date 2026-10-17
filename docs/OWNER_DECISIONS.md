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

## 2026-10-16 — The lead decides every open question except the personal ones

> "do whatever you think is best for all the questions except for very personalized ones, just make sure it all works
> incredibly well … get the whole app done perfectly and lean on inspiration purely" — the owner.

Left with the owner (personal, paid or destructive): the app's **name**, its **icon**, **licensing Roslindale** (the
measured Roboto Serif instances ship until then), the **domain**, **purging reference images from the repository
history** (a force-push; keep the repository private meanwhile), accepting the **resemblance to Retro** (the name, icon
and typeface are what set the app apart) and **one capture session on an iPhone with Retro installed**.

Decided by the lead, each from reference evidence (the evidence rule above still applies to every value they produce):

| # | question | decision | evidence / reason |
|---|---|---|---|
| 6 | same-moment collage | **Option B** (9:16 pages, 3 columns, paged) stays | a page is a 9:16 Stories image as is (A and C need a share canvas no reference shows); 3 columns keep each answer's BeReal inset legible (Retro's 4-column recap card would shrink a 30-person inset to ≈ 24 pt); the pages already sit in Retro's recap preview chrome with Retro's corner ratio (collage.view) |
| 7 | premium | **$3.99 a month, $35.99 a year**; a **1-week free trial** on the annual plan on both stores; **T1: no history window** (`free_history_days` stays NULL, the history perk stays hidden); **Retro's purple** kept for premium-only accents | Retro PAY: annual $36.00, "Try %1$s free" CTA, "Premium" in purple, purple "FREE" pill; Retro's history perk is *adding* photos from any time ("Unlimited Profile History — Add photos from any time in your life"), not seeing old weeks, and a browsing window would break tenet 4 |
| 8 | spec flags T2–T7 | **T2** keep: reactions order recap / year-story picks server-side, no number ever reaches a client. **T3** keep: one group-level number on one year-story card (Wrapped), no per-person counts. **T4–T7** confirmed as built | docs/SPEC_FLAGS.md |
| 9 | template photos | four sample photos **with no identifiable people**, bundled as the "Ideas to Get Started" covers | Retro's template rows show cover photos (JED phone 3); Unsplash License allows bundling; people-free so no one appears to endorse the app (fixtures/photos/LICENSE.md) |
| 10 | the word for members | **"members"** for the people of a group; "friends" only where a sentence means the person's friends in general | Retro's journals (its groups): "7 members • 24 photos", "invited you to join the private journal" (retro.app /j/, APK strings) |
| 11 | default send-to audience | **every group preselected** (as built) | Locket's send-to opens with "All friends" selected |
| 12 | sharing memories outside the app | **your own photos only**; other members' memories have no share action | Retro's Rewind and Timehop resurface *your own* photos; BeReal has no way to share another person's post; tenet 1 (private) |
| 13 | first screen with no groups | **the groups list** on both platforms (Ideas to Get Started); with ≥ 1 group the app opens to the camera | Retro's empty home leads with templates; a camera with nobody to send to is a dead end |
| 14 | tabs | **Camera · Home · Walls · Me** stay | Retro's Rewind tab needs a year of history (On This Day stays a pushed page reached from memories); Retro's Activity tab was never captured and the product has no activity feed (tenets: no likes or counts) |
| 15 | haptics on send | **none** (as built) | Retro plays none; HIG: use haptics sparingly; a failed send shows the platform alert |
| 16 | voice-note waveform | **add**: levels sampled while recording, stored with the note, drawn as bars in Retro's colours | Messages, WhatsApp and Telegram all draw one; voice notes are a specialist mechanic |
| 17 | in-app QR invite card | **add**, in the group's invite sheet | Retro's app has a profile QR card ("Retro.app - Photos with Friends", "Member since 2023" — APK) and retro.app shows the QR on desktop |
| 18 | Android lock-screen widgets | **opt in** (keyguard category); shown only where the OS supports it | parity with the iOS lock-screen widget (Locket's core surface) |
| 20 | contrast | text under WCAG AA (4.5 : 1; 3 : 1 for large text) is raised to the nearest passing value of the same hue; non-text fills keep Retro's values | HIG and Material 3 both ask 4.5 : 1 (platform layer); the audience includes grandparents Applied 2026-10-16: secondary grey #999999 → #6E6E6E (light), Android black 50 % → 57 %, grey pill #767676, unselected tab glyph #949494 (light), one red #D0151A / #EF6265 (destructive, badge, M3 error), Android M3 blue #0066CE / #2592FF; media surfaces take the dark values. One exception kept for you: the faint empty-day tile date (design/CONTRAST.md "What still fails" 2). |
| 21 | Android dark background | Retro's **#1C1C1E** default stays; Retro's **True black** option is added to Settings | Retro APK: `colorScheme = isDark ? (trueBlack ? … : …)` (design/research/retro-package-copy-motion.md §3.1–3.2) |
| 22 | Locket values read from a decompiled bundle | **re-sourced** from public screenshots or platform documentation; the decompiled bundle no longer counts as evidence | legal caution: reading another app's code is not inspiration. What a public web page sends to every browser (retro.app's HTML, CSS and page script, read as View Source shows them) stays acceptable evidence, like the retro.app CSS used since Pass 1; decompiled app binaries do not. Retro's own Android package, read the same way in the research passes, is left to the owner (docs/OWNER_SETUP.md §0 item 9) |
| 23 | report categories | **Retro's lists** stay | Retro APK strings; they match the platforms' common report reasons |

## 2026-10-17 — Finish the whole vision: every promised feature, plus what the best apps have

> "I want you to continuously develop all of these features, work at developing all of the other things that should be
> apparent and enabled within all of this, and draw purely from inspiration … incorporated in a very clean, professional
> way in order for all of this to befit the overall vision" — the owner. Earlier (2026-10-16): "I want you to make it so
> that you have a ton of all the cool features that are from all the different apps … combining all these features".

A four-part audit (spec sections, release readiness, reference-app features) produced the work list. Decided by the lead
under the 2026-10-16 mandate; the evidence rule still applies to every value and word these produce.

| # | question | decision | evidence / reason |
|---|---|---|---|
| 24 | plans (Partiful / Apple Invites) vs. the directive's "Explicitly do NOT build: events" | **kept**, flagged to the owner: built on the owner's 2026-10-16 request for features from other apps; stays light (no tickets, payments, public pages, guest counts). The owner can ask for it to be removed | directive Part 5 ("flag it instead of silently building it") |
| 25 | iPad | **iPhone only** (`TARGETED_DEVICE_FAMILY = 1`; iPads run it in compatibility mode) | Retro, Locket and BeReal are iPhone-only in their App Store compatibility sections; an iPad build needs its own layouts and screenshots |
| 26 | minimum age | **13** (`app_config.min_age_years`) | the age every reference app's terms set for sign-up (cited in the migration that sets it); COPPA's threshold |
| 27 | invite links | **no expiry**: a link works until an admin resets it or turns link sharing off (`invite_ttl_seconds` NULL) | WhatsApp group invite links stay valid until reset; Partiful links do not expire |
| 28 | saving other members' photos | **any member may save any photo they can see to their own photo library**; sharing to other apps stays your own photos only (decision 12 still holds for sharing) | Apple Shared Albums: subscribers can save shared items to their own library (support.apple.com/108314); WhatsApp saves group media |
| 29 | downloads | **album export in full quality is premium** (the directive's perk, already on the paywall); **"download all my photos" is free** (tenet 4; also offered before account deletion) | directive Part 6 Subscription; Yope "download all photos"; Retro's downloads page |
| 30 | weekly question | **on**: the catalogue is asked in order, a new question each week; **on by default for new groups**, an admin can turn it off | owner mandate to decide open questions; tenet 5 holds (no push, no tally, hideable) |
| 31 | year story | **refreshed on 31 December** so December counts, then **kept in the group's memories for good** (no second push) | tenet 4 "Nothing gets lost"; Wrapped's story stays reachable through the season |
| 32 | app icon | **made by the lead from the app's own identity** (the title serif's "J" on the media black), with a dark and a tinted variant; the owner can replace it at any time | decision 0.2 left the icon to the owner, but both stores refuse an app without one and Android shows no notification without a small icon |
| 33 | domain | **`jolt-husamisverycool.fly.dev`** (the invite page's Fly address) until the owner buys one | universal links, the App Clip and invite links need a host; `services.yml` deploys the page there |
| 34 | new features | built: posting several photos at once; downloads (29); more widgets and the premium widget styles the paywall sells; "Share to Jolt" from other apps; library photos land on the day they were taken; search; reactions on chat messages; editing a message or caption; reply and react from a notification; albums anyone can add to; quick ways to open the camera (Control Center, Shortcuts, Quick Settings, app shortcuts); hide a memory; reply to a memory in the group; use a photo as the group cover; an opt-in memory notification; tappable links in chat; pause all notifications for today; "{name} joined" in the chat; private favorites; a typing line with names; jump to a date | `docs/RESEARCH_FEATURES_2026-10-17.md` (evidence URL per feature) |
| 35 | not built | voice-message transcripts (the directive limits AI to recaps), an activity inbox (decision 14), printing (payments), read receipts / online dots (tenet 5), on-demand video recaps (later) | tenets and the do-not-build list |
