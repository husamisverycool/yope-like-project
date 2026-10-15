# `settings.root` — Settings

Reference: **Apple HIG / Material 3** (system surface). Research: `design/research/platform.md` §settings;
`docs/PLATFORM_CONSTRAINTS.md` §8 (sign-up opportunity in settings; Play Subscription Center), §9 (privacy policy,
contact information). Premium row: **Locket** profile row ("Locket Gold / Unlock the best of Locket ›").
Tokens: `settings.root.*`, `settings.account.layout.manageSubscription`, global system tokens. Copy: `settings.root.*`.

## References

| id | file / URL | used for |
|---|---|---|
| HIG-L | https://developer.apple.com/design/human-interface-guidelines/lists-and-tables | inset-grouped list, sections, disclosure |
| HIG-S | https://developer.apple.com/design/human-interface-guidelines/settings | "general, infrequently changed settings"; no redundant system settings |
| M3-L | https://m3.material.io/components/lists/specs | list item sizes and roles |
| LZ21 | `references/auto/locket/lazyweb/locket-lazyweb-20260803-autocap-21.png` | premium entry row wording |

## Structure (`settings.root.layout.list`; navigation title `settings.root.title`, large on iOS)

1. Section (no header): premium row — title `settings.root.premium.title`, subtitle `settings.root.premium.subtitle`,
   disclosure → `paywall` (never counted as a prompt, `paywall.layout.promptRule`). While premium is active the row is
   `settings.root.manageSubscription` → `settings.account.layout.manageSubscription`.
2. Section: `settings.root.notifications` → `settings.notifications`; `settings.root.account` → `settings.account`;
   `settings.root.blocked` → `settings.blocked`.
3. Section: `settings.root.privacy`, `settings.root.terms` (open `config/app.json` `legal.*Url` in an in-app browser);
   `settings.root.contact` (mailto: the owner's support address).
4. Section: `settings.root.signOut` (plain row, system tint).

No in-app Dynamic Type, appearance or language switches (HIG: respect system settings).

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| list | `settings.root.layout.list`; iOS `color.global.system.ios`; Android `color.global.system.surface` / `.onSurface` / `.onSurfaceVariant` / `.outline`, `settings.root.size.listItemOneLine.android`, `.listItemTwoLine.android` (premium row), `.listItemPaddingH.android`, `.listItemPaddingV.android`, `.divider.android`; type `layout.global.system.typography` | — | — |
| rows | system (disclosure indicator on iOS) | as Structure | — |
| entry circle (on `walls.mine`, social pass) | `size.global.headerButton`, `color.global.controlOnDeep`, `icon.global.settings` | `walls.mine.a11y.settings` | → this screen |

## States

| state | design | copy |
|---|---|---|
| default | as Structure | — |
| premium active | row 1 = Manage Subscription | `settings.root.manageSubscription` |
| loading (entitlement unknown) | premium row shown as the not-subscribed row until `entitlements` loads | — |
| offline / error | the list works; links and sign-out need a connection (sign-out clears local state regardless) | — |
| empty / permission-denied | not applicable | — |

## Motion · Haptics

Native push/pop. No haptics.

## Accessibility

System list semantics; iOS large title; rows read their labels; the premium row reads title then subtitle. Dynamic Type
by the system styles. Focus order = list order.

## Data & actions

- `entitlements` (own rows, docs/API.md §5.22) for the premium row.
- Sign out: `unregister_device(p_push_token)` then `auth.signOut()` → `auth.phone`.
- In: `walls.mine` header settings circle (the 'me' tab; Yope's own settings entry was not captured). Out: `paywall`,
  `settings.notifications`, `settings.account`, `settings.blocked`, browser, mail.

## Platform notes

iOS `NavigationStack` + `List(.insetGrouped)`; Android `Scaffold` + `LargeTopAppBar` + `LazyColumn` of `ListItem`.

## Do-not-copy

Badges with counts on rows (HIG badge = unread counts; tenets forbid counts).

## Gaps

| item | status | owner input |
|---|---|---|
| where the settings entry sits | `walls.mine` header circle (placed by the social pass, `walls.mine.md`) | — |
| support e-mail for "Contact Us" | not in `config/app.json` | owner (App Review 1.2 requires published contact information) |
| legal URLs | `config/app.json` `legal.privacyUrl` / `legal.termsUrl` are null | owner |
