# `safety.report` — report flow

Reference: **Apple HIG / Material 3** (Yope voice for titles and explanations; F-21). Research:
`design/research/platform.md` §safety (App Review 1.2: reporting with timely responses is mandatory);
API `docs/API.md` §5.23, §6.3 `report`. Tokens: `safety.report.layout.flow`, `safety.report.layout.reasons` (BLOCKED),
`safety.block.layout.menu`, `safety.block.layout.toast`. Copy: `safety.report.*`.

## Where Report is exposed

| surface | entry | target |
|---|---|---|
| `groups.screen` feed | photo card ••• → `groups.screen.photo.menu.report` | post |
| `groups.screen` profile | ••• → `groups.screen.menu.report` ("report", Yope verbatim) | group |
| `groups.settings` | actions row `groups.settings.report`; member ••• → `groups.settings.members.menu.report` | group; user |
| `photo.viewer`, `chat.thread` (message long-press), `walls.member` header ••• | `safety.report.menuItem` ("Report…") — placed by those passes | post; message; user |
| after reporting a person or their content | `safety.report.sent.block` | → `safety.block` |

## References

| id | URL | used for |
|---|---|---|
| HIG-M | https://developer.apple.com/design/human-interface-guidelines/menus | "Report…" (ellipsis: more input follows) |
| HIG-AS / HIG-SH | …/action-sheets ; …/sheets | sheet with detents and grabber; destructive actions |
| M3-BS | https://m3.material.io/components/bottom-sheets/specs | modal bottom sheet values |
| RG 1.2 | https://developer.apple.com/app-store/review/guidelines/ | report + block mandatory |

## Structure (`safety.report.layout.flow`)

Sheet (iOS `.presentationDetents([.medium, .large])` + visible grabber; Android `ModalBottomSheet`):
1. Navigation bar: leading `safety.report.cancel`; trailing `safety.report.submit` (destructive, enabled at once).
2. Title (Yope voice): `safety.report.title.post` / `.message` / `.user` / `.group`.
3. Explanation `safety.report.explanation`.
4. Reason list `safety.report.layout.reasons` — **BLOCKED** (not shown in release builds).
5. Details: multi-line text field, placeholder `safety.report.details.placeholder`, ≤ 1000 characters.

After submit, the same sheet shows: title `safety.report.sent.title`; message `safety.report.sent.message` ({first_name})
or `safety.report.sent.messageGroup`; buttons `safety.report.sent.block` (destructive; person or their content only) and
`safety.report.sent.done`.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| sheet | `safety.report.layout.flow`; Android container `color.global.system.surfaceContainerLow`, `radius.global.sheet` (android 28), drag handle on-surface-variant @0.4 | — | swipe down = cancel (iOS: `interactiveDismissDisabled` only while sending) |
| title / explanation | iOS `.headline` / `.subheadline` text styles; Android `titleLarge` / `bodyMedium` (`layout.global.system.typography`) | as above | static |
| details field | system `TextField(axis: .vertical)` / M3 `OutlinedTextField` | `safety.report.details.placeholder` | optional |
| Report | iOS toolbar button role .destructive; Android TextButton in `color.global.system.error` | `safety.report.submit` | `report(p_target_kind, p_target_id, p_reason)`; empty details → `p_reason` = the target kind |
| Done / Block | system buttons | `safety.report.sent.done`, `safety.report.sent.block` | Done closes; Block opens `safety.block` confirmation |

## States

| state | design | copy |
|---|---|---|
| default | as Structure | — |
| sending | Report replaced by a native progress indicator; fields disabled | — |
| sent | result content in the same sheet | `safety.report.sent.*` |
| error / offline | inline footer under the field; details kept | `safety.report.error.title`, `safety.report.error.detail` |
| target gone | `target_not_found` | `safety.report.error.notFound` + Done |
| loading / empty / permission-denied | not applicable | — |

## Motion · Haptics

Native sheet. Sent → `haptic.global.success`; failed → `haptic.global.error`.

## Accessibility

Sheet title is the accessibility heading; the field has the placeholder as label; Report announced as destructive by
role. Dynamic Type: system styles. Focus order: Cancel → title → explanation → field → Report.

## Data & actions

- `report(p_target_kind: post | message | user | group, p_target_id, p_reason)` → report id; job `moderation.report`.
- A block does not stop reporting (API). Reports are not readable by clients.
- In: the entries above. Out: back to the caller, or `safety.block`.

## Platform notes

iOS uses a sheet (the reason list is a longer flow, HIG); Android uses the modal bottom sheet (M3: alternative to menus
or dialogs for longer content).

## Do-not-copy

None observed (Yope's report content was not captured).

## Gaps

| item | status | owner input |
|---|---|---|
| report reasons (`safety.report.layout.reasons`) | BLOCKED: no platform taxonomy; Yope's not captured | the moderation categories (docs/API.md §12 item 19) |
| moderation destination and response time | backend/owner (`moderation.report` jobs need a destination) | owner |
| toast after block from here | `safety.block.duration.toast` BLOCKED | one 10-s recording of a Yope toast lifetime |
