# Screens brief (for every iOS / Android screens pass)

You build the screens of one feature group on one platform, exactly as specified. Read first:
`docs/CONVENTIONS.md` (the prime rule and §5), `docs/SURFACES.md`, every `design/surfaces/<id>.md`
of your group (your build specs — complete: elements, tokens, copy keys, states, motion, haptics,
accessibility, data, platform notes, gaps), `design/tokens/README.md` (foundation names),
`design/MERGE_DECISIONS.md` (sections for your group), `docs/API.md`, `docs/PLATFORM_CONSTRAINTS.md`,
`docs/SPEC_FLAGS.md`. Then the code you build on (below).

## The rules
1. **No design decision is yours.** Every color, size, radius, font, icon, motion value, haptic and
   word comes from generated constants: Swift `Tokens.*` / `Copy.*` (AppCore `DesignSystem`),
   Kotlin `Tokens.*` / `R.string.*` (`core:designsystem`). Never a literal. `node
   tools/provenance-check.mjs` fails the build otherwise. If a spec says a value is BLOCKED, follow
   the spec's "Gaps" section (usually: the element is omitted in release builds; DEBUG builds may use
   `BlockedTokens` / `BlockedCopy` / `strings_blocked.xml` inside `#if DEBUG` / debug source sets so
   the layout can be reviewed). Never substitute your own value. If something in a spec is
   impossible to build as written, stop on that element and report it.
2. **Tenets.** No counts of likes/reactions/views, no streaks, no "late" labels, no guilt or nagging,
   no fake notifications. Premium: at most one prompt per session (`SessionPromptGate`), never during
   capture or onboarding, never blocking the core.
3. **Every screen has its states** — loading, empty, error, offline (cached content + offline
   state from the data layer's reachability), permission-denied where a permission applies — exactly
   as its spec describes.
4. **Accessibility**: Dynamic Type / font scale through the design-system text helpers; VoiceOver /
   TalkBack labels from copy for every icon-only control; Reduce Motion through the design-system
   motion helpers; minimum touch targets (`size.global.minTouchTarget.*`).
5. **Data** only through the data layer (iOS `AppData` in `ios/Packages/AppCore`; Android
   `core:data`) — read its public API first. Platform services from the foundation layer (camera,
   voice, widget store, push, Live Activity, purchases, haptics). Don't change the data layer's or
   foundation's public APIs; if you need something they lack, add it in your own group folder as an
   extension, or report it.
6. **Ownership — edit only your files** (other groups work in parallel):
   - iOS: `ios/App/Sources/Features/<Group>/**` (your `…Routes.swift` enums + destinations live
     there), tests named `<Group>*Tests.swift` in `ios/AppTests/<Group>/`, UI tests in
     `ios/AppUITests/<Group>/`. Account group also owns the app shell (`RootView.swift`,
     `AppMain.swift`, `AppEnvironment.swift`, the existing `Screens/` containers it replaces), the App
     Clip (`ios/AppClip/**`) and shared components in `ios/App/Sources/Components/`. Capture group
     also owns `ios/Widgets/**` (widget + Live Activity views) and `ios/NotificationService/**`.
     Other groups may *use* `Components/` but not edit it; build what you need locally otherwise.
     Replace a `Screens/<X>Screen.swift` container only if its surface is yours.
   - Android: your own Gradle module `android/feature/<group>/` (package `app.feature.<group>`;
     `<Group>Navigation.kt` registers your destinations — replace each `emptyDestination<…>()` with
     `composable<AppRoute.X> { … }`), new routes in
     `android/core/model/src/main/kotlin/app/model/AppRoute<Group>.kt` (same package, joins the sealed
     `AppRoute`), tests in your module's `src/test` (Roborazzi baselines in its
     `src/test/snapshots`). Build only your module while you work
     (`./gradlew :feature:<group>:testDebugUnitTest`), so another group's unfinished code never
     blocks you; run the full build at the end. Account group also owns `:app` (`app.main`: App,
     MainActivity, theme, shell, AppNavHost) and shared components in `android/core/ui/`
     (`app.ui`). Capture group also owns the widget UI slots in `core:widget` and the notification
     UI in `core:push`. Other groups depend on `core:ui` read-only.
7. **Tests**: view-model unit tests; one snapshot test per screen **per state** (iOS:
   swift-snapshot-testing via the existing `SnapshotRecorder`, recorded into `ios/build/snapshots`
   on CI; Android: Roborazzi, baselines in `app/src/test/snapshots`); UI/flow tests for every flow
   in your group (iOS `AppUITests`, Android Robolectric Compose tests).
8. **Verification** (directive Part 8): for every screen, a side-by-side of your snapshot next to its
   reference image with `tools/sidebyside.py` → `design/verification/<surface-id>.png`, and
   `design/verification/<surface-id>.md`: the checklist of the spec's values (token → reference
   value → what your snapshot shows), matched / not matched / approximated. Android can do this
   locally. iOS snapshots only exist after macOS CI runs — write the checklist from the spec and
   leave the image step to the lead (who downloads the CI artifact).
9. **Build and check** before you finish:
   - Android: `export ANDROID_HOME=/opt/android-sdk; cd android && ./gradlew assembleDebug testDebugUnitTest` green
     (several screens passes share this machine: prefer module-scoped tasks while iterating; one full run at the end).
   - iOS: this machine cannot compile SwiftUI. `swift build`/`swift test` for `ios/Packages/AppCore`
     must stay green on Linux; parse-check your files with
     `/opt/swift/usr/bin/swiftc -frontend -parse <file>`; re-read every file for type errors against
     the real APIs (iOS 17.2 deployment target; use `if #available` for newer APIs). The lead runs
     macOS CI and will send you compiler errors.
   - Both: `node tools/designgen.mjs && node tools/provenance-check.mjs` from the repo root.
10. Do not commit (the lead commits). Do not run `db reset` on the shared local Supabase stack.

Reply with: screens built (per surface: states covered), tests added and their results, the
verification checklist summary (matched / not matched / approximated per surface), BLOCKED
elements omitted in release, and anything you could not build.
