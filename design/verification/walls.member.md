# Verification — `walls.member` (iOS)

A member's wall (Retro's profile of a friend: back chevron + name, avatar, "•••" capsule, week sections) — `ios/App/Sources/Features/Social/UI/WallsViews.swift` (`WallMemberScreen`, shared `WallProfileHeader` / `WallWeekList`), `Core/WallModels.swift`.

Pass 4 (Retro redesign). Checklist written from the spec (`design/surfaces/walls.member.md`, MERGE "Redesign — Social (RS-*)", lead L-3 / L-4) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>-<light|dark>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/walls.member.png` next to the Retro reference(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level). Components are the Pass 3 library (`ios/App/Sources/Components`, C-01…C-35).

Retro reference(s): `references/auto/retro/store/retro-store-02.png (ST-02)`, `references/auto/retro/press/tc-2023-07-retro-1b.webp ("•••" capsule)`

Snapshots (CI): `walls.member-ready-light.png`, `walls.member-ready-dark.png`, `walls.member-loading-light.png`, `walls.member-empty-light.png`, `walls.member-blocked-light.png`, `walls.member-error-light.png`, `walls.member-offline-light.png`

**Summary: 11 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Elements

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `icon.global.back`<br>`size.global.backInset`<br>`size.global.headerGap`<br>`chat.thread.a11y.back` | ios: chevron.left; android: AutoMirrored.Rounded.ArrowBackIos (PLATFORM)<br>21.1 pt (SOURCED)<br>14.6 pt (SOURCED)<br>“Back” (SOURCED) | back | back chevron (`icon.global.back` at the `icon` symbol size, ink at `backInset`, ≥ 44 hit area) leading the name line, `headerGap` before the name |
| matched | `font.global.display`<br>`walls.member.a11y.wall` | ios: system-serif; android: serif (PLATFORM)<br>“{name}'s profile” (SOURCED) | name | name in `headerTitle` (display serif), one line, tail truncation; VoiceOver reads `walls.member.a11y.wall` |
| matched | `size.global.iconPillWidth`<br>`size.global.pillHeight`<br>`icon.global.more`<br>`size.global.iconSmall`<br>`walls.member.a11y.more`<br>`walls.member.menu.report`<br>`walls.member.menu.block` | 49 pt (SOURCED)<br>37 pt (SOURCED)<br>ios: ellipsis; android: Rounded.MoreHoriz (PLATFORM)<br>14.7 pt (SOURCED)<br>“More Options” (SOURCED)<br>“Report Profile” (SOURCED)<br>“Block Profile” (SOURCED) | more capsule | C-06 `CapsuleLabel(icon: more)` as a native `Menu`: Report Profile (account's `safety.report`, kind user) and Block Profile (account's `blockConfirmation`), both destructive |
| matched | `week.history.a11y.tile` | “{weekday}, {date}, {name}'s photo” (SOURCED) | photo tile | C-17 tile labelled `week.history.a11y.tile`; tap → viewer with this wall's photos |
| matched | `walls.browse.a11y.collage` | “Collage, {date}” (SOURCED) | collage tile | collage tile → `collage.view` full screen via the shell |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `week.history.a11y.loading` | “Loading” (SOURCED) | loading | header from `profiles`; one placeholder section |
| matched | `walls.member.empty.title`<br>`walls.member.empty.detail` | “Nothing to see here” (SOURCED)<br>“{name} hasn't shared anything in a group you're both in.” (SOURCED) | empty | C-27: calendar glyph, "Nothing to see here", detail with the first name; no action |
| matched | `walls.mine.error.title` | “Error loading your weeks. Tap here to try again.” (SOURCED) | error | `SocialErrorLine` (`walls.mine.error.title`) |
| matched | `—` | — | offline | cached wall, else the error line |
| matched | `—` | — | blocked (after Block from the menu) | `model.blocked()` after a confirmed block → empty state (unit-tested) |
| matched | `—` | — | permission-denied | n/a |
