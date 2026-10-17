# Private photo app for close friends and family

Groups of up to 30 people. No public feed, no followers, no likes or counts, no streaks, no ads.
Friends' photos come to you (home-screen and lock-screen widgets); once a day each group gets the
same invitation at the same moment, and every answer becomes one same-moment collage; the app
remembers for the group (weeks, on this day, birthdays, the year).

The build directive is the specification. Nothing visual or written in the app is our own
choice: every color, size, font, icon, motion value and word traces to a reference app and is
logged in `design/SOURCES.md` and `design/COPY.md`.

| Path | |
|---|---|
| `docs/` | Architecture, conventions, surfaces, API, platform constraints, owner setup, owner decisions |
| `design/` | Research per reference app, canonical `tokens.json` / `copy.json`, generated ledgers, verification images, collage options |
| `references/` | Owner-provided (`owner/`) and found (`auto/`) reference images with source indexes |
| `tools/` | `designgen.mjs` (tokens/copy → Swift, Kotlin, TS + ledgers), `provenance-check.mjs` (lint), fetchers |
| `backend/` | Supabase migrations (RLS everywhere), security tests, worker (jobs, collage, push, video, AI recaps) |
| `web/` | Invite preview page and universal / app link files |
| `ios/` | SwiftUI app, WidgetKit widgets + Live Activity, notification service extension, App Clip |
| `android/` | Compose app, Glance widgets, CameraX, FCM |

Start with `docs/OWNER_SETUP.md` for what the owner must provide, `docs/OWNER_DECISIONS.md` for what
the owner has decided, and `design/BLOCKED.md` for design values still waiting on a capture.

## Everyday commands

```sh
node tools/designgen.mjs          # regenerate tokens/copy for all platforms + ledgers
node tools/provenance-check.mjs   # fail on literal design values or unsourced strings
cd backend && npx supabase start && npm test    # database, RLS and security tests
cd android && ./gradlew assembleDebug testDebugUnitTest
cd ios && xcodegen generate && open App.xcodeproj   # macOS
```
