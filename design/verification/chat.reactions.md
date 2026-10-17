# Verification — `chat.reactions` (iOS)

Reactions on photos: the chip, the quick row of the context menu, the picker and the Reactions sheet — `ios/App/Sources/Features/Social/UI/ReactionsUI.swift` (`ReactionChip`, `QuickReactionsPalette`, `ReactionPicker`, `ReactionsSheet`, `SocialPersonRow`); `ReactionSummary` in `Core/SocialModels.swift`.

Pass 4 (Retro redesign). Checklist written from the spec (`design/surfaces/chat.reactions.md`, MERGE "Redesign — Social (RS-*)", lead L-3 / L-4) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>-<light|dark>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`: every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/chat.reactions.png` next to the Retro reference(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level). Components are the Pass 3 library (`ios/App/Sources/Components`, C-01…C-35).

Retro reference(s): `references/auto/whatsapp/store/whatsapp-store-04.png`, `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt ("Reactions", "Search", "All")`

Snapshots (CI): `chat.reactions-cluster-light.png`, `chat.reactions-cluster-dark.png`, `chat.reactions-picker-light.png`, `chat.reactions-picker-mine-light.png`, `chat.reactions-sheet-light.png`, `chat.reactions-sheet-empty-light.png`

**Summary: 14 matched · 2 approximated · 0 not matched (BLOCKED or not buildable).**

## Elements

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `chat.reactions.layout.chip`<br>`chat.reactions.dimension.chipTop`<br>`chat.reactions.count.clusterMaxVisible`<br>`chat.reactions.layout.clusterOrder`<br>`fontSize.global.pill`<br>`radius.global.capsule`<br>`chat.reactions.a11y.cluster` | component: C-06 fill capsule holding the distinct emoji (no number); fill: page: color.global.control (iOS) / color.global.surfaceSecondary.… (SOURCED)<br>12 pt (SOURCED)<br>3 (SOURCED)<br>order: newest distinct emoji first (leading); earlier ones follow; tie: an emoji used again moves to the front (SOURCED)<br>15 pt (SOURCED)<br>shape: capsule; radius: height / 2 (SOURCED)<br>“Reactions: {emoji_names}” (SOURCED) | chip | `ReactionChip`: C-06 fill capsule, distinct emoji newest-by-last-use (`ReactionSummary.distinctEmoji`, unit-tested), first `clusterMaxVisible`, emoji at `fontSize.global.pill`, padding 12 / 8 read from `layout.chip.padding`, capsule, `chipTop` below the card; never a number (unit + UI tested) |
| matched | `chat.reactions.layout.quickReactions`<br>`chat.reactions.a11y.quick`<br>`chat.reactions.a11y.add` | emoji: 🔥 then 💖, then the add-reaction glyph (chat.reactions.icon.add); where: a palette row at the top of the photo's native context menu (… (SOURCED)<br>“React with {emoji_name}” (SOURCED)<br>“Add reaction” (SOURCED) | quick row | `QuickReactionsPalette`: `ControlGroup` `.palette` at the top of the photo's native context menu — 🔥, 💖 (from the token), add glyph; a used emoji shows selected and takes it back (`toggleReaction`, unit-tested) |
| matched | `chat.reactions.icon.add`<br>`size.global.icon`<br>`color.global.textSecondary`<br>`size.global.headerButton`<br>`chat.reactions.a11y.add` | ios: face.smiling; android: Rounded.AddReaction (PLATFORM)<br>24 pt (SOURCED)<br>#999999 (SOURCED)<br>44 pt (PLATFORM)<br>“Add reaction” (SOURCED) | add-reaction glyph (viewer footer) | viewer footer: `chat.reactions.icon.add` in the `icon` box (`textSecondary`), ≥ 44 hit area → picker |
| approximated | `chat.reactions.layout.picker`<br>`chat.reactions.count.pickerColumns`<br>`fontSize.global.headerTitle`<br>`chat.reactions.picker.search`<br>`chat.reactions.picker.frequent`<br>`chat.reactions.picker.group.*` | presentation: native sheet (C-29) with grabber; search by Unicode name; Frequently Used, then Unicode's nine standard groups (SOURCED)<br>6 (SOURCED)<br>40 pt (SOURCED)<br>“Search” (SOURCED)<br>“Frequently Used” (SOURCED)<br>“Smileys & Emotion” … “Flags” (VERIFIED, Unicode) | picker | native sheet: C-12 search (CLDR names), "Frequently Used" (device's recent emoji, `SocialFlags`), then Unicode's standard groups from the generated catalog (tools/emoji-catalog.mjs: every fully-qualified RGI emoji — ❤️, flags, keycaps, ZWJ sequences — the device font draws), skin tones on touch and hold (popover / menu, custom actions for VoiceOver / TalkBack), `pickerColumns` columns, emoji at `fontSize.global.headerTitle`, mine on a `circleButton` `control` circle (tap removes). Android snapshot: `ChatSnapshotTest.reactionsPicker` (2026-10-17) |
| matched | `chat.reactions.layout.list`<br>`chat.reactions.layout.listOrder`<br>`size.global.avatarPicker`<br>`size.global.icon`<br>`chat.reactions.activity.title`<br>`chat.reactions.activity.row`<br>`chat.reactions.activity.rowMine`<br>`chat.reactions.list.removeHint`<br>`chat.reactions.empty` | presentation: native sheet (C-29) titled chat.reactions.activity.title; row: C-16 people row: avatar size.global.avatarPicker, name text rol… (SOURCED)<br>order: newest first by reactions.created_at (SOURCED)<br>37 pt (SOURCED)<br>24 pt (SOURCED)<br>“Reactions” (SOURCED)<br>“{name} reacted {emoji}” (SOURCED)<br>“You reacted {emoji}” (SOURCED)<br>“Tap to remove” (SOURCED)<br>“Nothing to see here yet” (SOURCED) | Reactions sheet | native sheet: `SheetHeader` "Reactions", one C-16-style row per person and emoji (`SocialPersonRow`: `avatarPicker`, `rowAvatarToText`), your row "Tap to remove" → unreact; empty → C-27 title. rows newest first by `created_at` (`ReactionSummary.listRows`, unit-tested; Stream Chat's reaction list) |

## States

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `—` | — | no reactions | no chip (zero size) |
| matched | `—` | — | reacting | optimistic insert / removal (unit-tested) |
| approximated | `—` | — | loading (sheet) | the sheet opens on the reactions already loaded with the thread / viewer, so it has no loading state of its own |
| matched | `chat.reactions.empty` | “Nothing to see here yet” (SOURCED) | empty (sheet) | C-27 title `chat.reactions.empty` |
| matched | `chat.reactions.error`<br>`haptic.global.error` | “Couldn't send reaction” (SOURCED)<br>ios: notification.error; android: REJECT (PLATFORM) | error / offline (react fails) | rolled back + announcement `chat.reactions.error` + `haptic.global.error` (unit-tested) |
| matched | `—` | — | permission-denied | n/a |

## Motion

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `duration.global.crossfade` | 100 ms (SOURCED) | chip appears / changes | `.dsAnimation(ComponentMotion.crossfade, value: shown)` |
| matched | `spring.global.sheetPresent` | response: 0.347; dampingFraction: 1 (SOURCED) | context menu, sheets | system menu / sheet presentation |

## Haptics

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `haptic.global.reaction` | ios: system (context menu plays its own haptic; no custom generator); android: LONG_PRESS (PLATFORM) | long press opens the menu with the quick row | system context-menu haptic |
| matched | `haptic.global.tap` | ios: none; android: VIRTUAL_KEY (PLATFORM) | tap an emoji (Android) | none on iOS |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | reaction failed | `.failed` → `haptic.global.error` |
