# `settings.blocked` — blocked people

Reference: **Apple HIG / Material 3** (system surface). Research: `design/research/platform.md` §settings, §safety;
API `docs/API.md` §5.6 (blocks), §6.3 `unblock_user`, §9.7. Tokens: `settings.root.layout.list`,
`settings.root.size.listItemAvatar.android`, `settings.blocked.layout.empty`. Copy: `settings.blocked.*`.

## References

HIG Lists and tables; M3 Lists specs (leading avatar 40 dp); SwiftUI `ContentUnavailableView`.

## Structure (`settings.root.layout.list`; title `settings.blocked.title`)

One row per block, newest first: avatar (iOS `size.global.avatarPicker`, Android `settings.root.size.listItemAvatar.android`;
fallback gray `color.global.controlRaised` + `icon.global.person`) · name (`display_name`, or `settings.blocked.unknown`
when the profile is no longer readable) · trailing borderless button `settings.blocked.unblock`.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| row | system list row | name / `settings.blocked.unknown` | not tappable (no profile to open) |
| unblock | system borderless button (iOS tint; Android `color.global.system.primary` TextButton) | `settings.blocked.unblock` | `unblock_user(p_user_id)`; row removed; no confirmation (not destructive) |
| empty | `settings.blocked.layout.empty` | `settings.blocked.empty.title`, `settings.blocked.empty.message` | — |

## States

| state | design | copy |
|---|---|---|
| loading | native progress | — |
| empty | `ContentUnavailableView` / centred column | `settings.blocked.empty.*` |
| error | section footer + retry button | `settings.blocked.error`, `settings.blocked.retry` |
| offline | cached list; unblock disabled | — |
| permission-denied | — | — |

## Motion · Haptics

Row removal: list default animation (native). Unblock → `haptic.global.success`.

## Accessibility

Each row: name; the unblock button labelled "Unblock" with the name as context (`accessibilityLabel` "Unblock, {name}" is
composed by the system from row + button grouping; no extra string). Dynamic Type: system.

## Data & actions

- Reads: `blocks` (own rows as blocker), `profiles` where still readable (shared group).
- Writes: `unblock_user`.
- In: `settings.root`. Out: none.

## Platform notes

iOS `List`; Android `LazyColumn` of `ListItem` (two-line height when a fallback label is shown is not needed: one line).

## Do-not-copy

Counts of blocked people.

## Gaps

None.
