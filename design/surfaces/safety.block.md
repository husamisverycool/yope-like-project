# `safety.block` — block flow

Reference: **Apple HIG / Material 3** (Yope voice for the title and explanation; F-21). Research:
`design/research/platform.md` §safety; API `docs/API.md` §5.6, §6.3 `block_user` / `unblock_user`. Tokens:
`safety.block.layout.menu`, `safety.block.layout.confirm`, `safety.block.layout.toast`, `safety.block.duration.toast`
(2000 ms, gap fill), `settings.account.layout.alert`. Copy: `safety.block.*`.

## Where Block is exposed

| surface | entry | copy |
|---|---|---|
| `groups.screen` feed | photo card ••• (others' photos) | `groups.screen.photo.menu.block` ("Block {first_name}") |
| `groups.settings` | member ••• | `groups.settings.members.menu.block` ("Block") |
| `safety.report` result | after reporting a person or their content | `safety.report.sent.block` |
| `photo.viewer`, `chat.thread` (message long-press), `walls.member` | menus placed by those passes | `safety.block.menuItemNamed` / `safety.block.menuItem` |
| `settings.blocked` | Unblock | `settings.blocked.unblock` |

## References

HIG Action sheets ("Use an action sheet — not an alert — to offer choices related to an intentional action";
destructive at the top, Cancel at the bottom); HIG Menus; M3 menus and dialogs; App Review 1.2.

## Structure

1. Menu item (`safety.block.layout.menu`, destructive role).
2. Confirmation (`safety.block.layout.confirm`): iOS `confirmationDialog` with visible title `safety.block.title`
   ({first_name}), message `safety.block.message`, destructive `safety.block.confirm`, `safety.block.cancel` at the bottom;
   Android M3 `AlertDialog` (`settings.account.layout.alert`) with the same strings, confirm trailing.
3. On success: Yope lime toast (`safety.block.layout.toast`) `safety.block.done`; the person's content disappears from
   every shared group (RLS) — the current screen refetches.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| menu item | `safety.block.layout.menu` | `safety.block.menuItem` / `safety.block.menuItemNamed` | opens the confirmation |
| confirmation | `safety.block.layout.confirm` / `settings.account.layout.alert` | `safety.block.title`, `safety.block.message`, `safety.block.confirm`, `safety.block.cancel` | `block_user(p_user_id)` |
| toast | `safety.block.layout.toast` (`color.global.accent`, `icon.global.checkmark`, `color.global.onAccent`, `radius.global.capsule`, `size.global.screenMargin`), dwell `safety.block.duration.toast` (2000 ms) | `safety.block.done`, `safety.block.undone` (from `settings.blocked`) | release builds skip the toast until the dwell time is captured |

## States

| state | design | copy |
|---|---|---|
| default / confirming | as Structure | — |
| blocking | the dialog's confirm shows native progress | — |
| done | toast; content hidden | `safety.block.done` |
| error / offline | the dialog stays; message replaced | `safety.block.error` |
| self | never offered on own content (`cannot_target_self`) | — |
| loading / empty / permission-denied | not applicable | — |

## Motion · Haptics

Native dialog motion; toast enters with `spring.global.platformDefault.*` (Reduce Motion: cross-fade). Block confirmed →
`haptic.global.warning`; error → `haptic.global.error`.

## Accessibility

Dialog title read first; destructive button announced by role. Toast posted as an announcement
(`UIAccessibility.post(.announcement)` / `announceForAccessibility`). Dynamic Type: system styles in dialogs; toast text
role `button` → `subheadline`. Contrast: black on lime 17.65:1 pass.

## Data & actions

- `block_user(p_user_id)` (idempotent; `user_not_found`, `cannot_target_self`); `unblock_user`.
- Effects (API §5.6): both people stop seeing each other's posts, media, messages, reactions, tags, walls, files and
  birthday requests in every shared group; profiles stay visible in member lists.
- In / out: back to the calling surface.

## Platform notes

iOS `confirmationDialog(titleVisibility: .visible)`; Android `AlertDialog`.

## Do-not-copy

Notifying the blocked person; showing who blocked whom.

## Gaps

| item | status | smallest capture |
|---|---|---|
| toast dwell time | SOURCED by gap fill: 2000 ms (`safety.block.duration.toast`) — Locket's confirmation after a report is `ToastAndroid.SHORT`, AOSP `SHORT_DELAY = 2000`; Yope's own dwell is cut by the only video's edit (≥ 0.57 s visible), entrance ≈117 ms (60 fps) | one 10-s English recording of Yope sending a photo until the "posted in the wall" toast disappears |
