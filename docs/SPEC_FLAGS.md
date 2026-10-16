# Spec flags

Places where the directive's own requirements pull against its five tenets or against platform
rules (directive Part 5: "flag it instead of silently building it"). Each row says what we built
and what the owner should decide. Platform constraints are cited in `docs/PLATFORM_CONSTRAINTS.md`.

## Tenet tensions

| # | Spec item | Tension | What is built | Owner decision |
|---|---|---|---|---|
| T1 | Premium perk: "unlimited history beyond the free window" | Tenet 4 "Nothing gets lost: everything shared becomes the group's history". A history paywall makes the past partly unreachable. | Nothing is ever deleted or hidden from recaps, on-this-day, birthdays or the year story. `app_config.free_history_days` (NULL = unlimited) limits only *browsing* old weeks for free users, and is unlimited until you set it. | **Decided** (OWNER_DECISIONS #7, 2026-10-16): no window — `free_history_days` stays NULL and the paywall lists no history perk (both platforms, tested). |
| T2 | Weekly recap and year story feature "most-reacted photos" | Tenet 2 "no likes or counts". Ranking by reactions turns reactions into a popularity score, even with numbers hidden. | Reaction totals are computed server-side only for ordering; no number is ever sent to a client or shown; reaction displays are emoji clusters without counts. | Keep, or rank by "everyone reacted" / recency instead. |
| T3 | Year story card "moments shared" | Tenet 2 (counts). It is a group-level number, not a per-person vanity metric. | Built as a group-level card; no per-person counts anywhere. | Keep or drop the number. |
| T4 | Daily invitation with a short countdown (BeReal) | Tenet 5 "Invitations, never obligations". A ticking countdown and BeReal's ⚠️ urgency wording read as pressure. | The countdown shows only while the window is open; answering later posts normally with no label; no follow-up push; BeReal's warning emoji / "late" wording are not copied (adapted per copy rules). | Confirm. |
| T5 | Birthday contribution requests | Tribute/VidDay send reminder emails; reminders are nagging (tenet 5). | One private request per member, no reminders, no "you haven't contributed" state anywhere. | Confirm. |
| T6 | New-post notifications for every post in every group | Many groups × 30 members can become noise. | Per-group mute and quiet hours (spec); widgets still update silently for muted groups. | Confirm. |
| T7 | Invite page "who you're joining" | Partiful shows guest counts. | Member first names and avatars only, no count, no public listing; the page is reachable only with an unguessable token. | Confirm. |

## Platform constraints

Filled from `docs/PLATFORM_CONSTRAINTS.md` once the platform research lands:

| # | Spec item | Constraint | Closest compliant implementation |
|---|---|---|---|
| P1 | "New posts reach members' widgets as fast as platform limits allow" | iOS WidgetKit reload budget | see `docs/WIDGET_REFRESH.md` |
| P2 | Android lock-screen widget | Android phones have no lock-screen widgets | see PLATFORM_CONSTRAINTS |
| P3 | Android instant app | Google Play Instant status | web page fallback |
| P4 | "Every member receives the invitation at the same moment" | APNs/FCM delivery is best-effort | one simultaneous dispatch per group; measured spread in tests |
| P5 | Dual camera on all devices | Hardware support varies | sequential fallback (spec) |
