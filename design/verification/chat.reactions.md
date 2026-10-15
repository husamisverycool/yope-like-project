# Verification — `chat.reactions` (iOS)

Any-emoji reactions on photos (cluster, picker, quick reactions, rain, Activity) — `ios/App/Sources/Features/Social/UI/ReactionsUI.swift`; model logic in `Core/ChatThreadModel.swift` / `Core/PhotoViewerModel.swift` (`ReactionSummary` in `Core/SocialModels.swift`).

Checklist written from the spec (`design/surfaces/chat.reactions.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/social/<surface>-<state>.png` (`ios/AppTests/Social/SocialSnapshotTests.swift`), then `tools/sidebyside.py` makes `design/verification/chat.reactions.png` next to the reference image(s) below. Values in the third column are read from `design/tokens/*.json` / `design/copy/*.json` (value and evidence level).

Reference image(s): `references/auto/locket/store/locket-store-04.png`, `references/auto/locket/store/locket-store-08.png`, `references/auto/locket/frames/locket-tt-7460656081153445163-15.000s-emoji-picker-sheet-search-popular.jpg`, `references/auto/locket/frames/locket-tt-7147749171762908462-05.300s-emoji-rain-rising-behind-photo.jpg`

Snapshots (CI): `chat.reactions-cluster.png`, `chat.reactions-picker.png`, `chat.reactions-picker-mine.png`, `chat.reactions-activity.png`, `chat.reactions-activity-empty.png`

**Summary: 16 matched · 6 approximated · 0 not matched (BLOCKED or not buildable).**

## Cluster

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `chat.reactions.layout.cluster`<br>`chat.reactions.dimension.clusterEmoji`<br>`chat.reactions.dimension.clusterOutline`<br>`chat.reactions.color.clusterOutline`<br>`chat.reactions.dimension.clusterStep` | content: one sticker per distinct emoji that anyone reacted with; arrangement: horizontal row, each sticker overlapping the previous one by the step; numbers… (SOURCED)<br>39 pt (SOURCED)<br>2 pt (SOURCED)<br>#FFFFFF (SOURCED)<br>27 pt (SOURCED) | one sticker per distinct emoji, white outline, each step further right, drawn over the previous | ZStack + offset; outline as four zero-radius shadows of the outline width |
| matched | `chat.reactions.dimension.clusterInsetLeading`<br>`chat.reactions.dimension.clusterInsetBottom` | 17 pt (SOURCED)<br>20 pt (SOURCED) | bottom-left of the photo | overlay(alignment: .bottomLeading) + padding |
| matched | `chat.reactions.layout.clusterOrder` | order: newest distinct emoji first: a newly added emoji enters at the leading end of the cluster and the stickers already there shift one step (chat.reaction… (SOURCED) | newest distinct emoji first; earlier ones shift one step; a repeat keeps its place (G-10) | ReactionSummary.distinctEmoji (unit-tested) |
| approximated | `chat.reactions.count.clusterMaxVisible` | BLOCKED | maximum visible | BLOCKED: every distinct emoji, clipped by the photo |
| matched | `chat.reactions.a11y.cluster` | “Reactions: {emoji_names}” (SOURCED) | one element, names only, never a count | SocialEmoji names via CFStringTransform; unit tests assert no digits |

## Picker

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `chat.reactions.layout.picker`<br>`radius.global.sheet` | presentation: bottom sheet with a grabber over the photo; top: search field ('Search'); sections: Frequently Used, Popular, All; selection: any emoji; tappin… (SOURCED)<br>ios: system; android: 28 (PLATFORM) | native sheet with a grabber | .sheet + presentationDragIndicator(.visible) |
| matched | `chat.reactions.picker.search` | “Search” (SOURCED) | search field filtering by system name | .searchable(placement: .navigationBarDrawer(.always)) |
| matched | `chat.reactions.picker.frequent`<br>`chat.reactions.picker.popular`<br>`chat.reactions.picker.all`<br>`chat.reactions.fontSize.pickerSection`<br>`chat.reactions.fontWeight.pickerSection`<br>`color.global.textSecondary` | “Frequently Used” (SOURCED)<br>“Popular” (SOURCED)<br>“All” (SOURCED)<br>13 pt (SOURCED)<br>semibold (SOURCED)<br>#969696 (SOURCED) | section labels (headers) | SocialText.pickerSection, isHeader |
| approximated | `—` | — | Frequently Used | this device’s recent emoji, one row of the column count (per-device store) |
| matched | `chat.reactions.layout.pickerPopular` | row1: 💛 🫶 😍 🔥 🤣; row2: 😭 😋 🥹 🥰 🥲; row3: 😂 😱 😎 🤭 😯 🫠; row4: ❤️‍🔥 💕 💘 ❤️ 💖 💋; row5: 🤍 💚 💙 💜 🧡 🖤; hidden: row 1 and row 2 have a sixth cell hidden by a finger i… (SOURCED) | Popular in token order | rows 1–5 split into cells |
| approximated | `—` | — | All in system categories order | single-scalar emoji with emoji presentation in code point order (the categories order is not available to apps) |
| matched | `chat.reactions.count.pickerColumns`<br>`chat.reactions.dimension.pickerEmoji` | 6 (SOURCED)<br>40 pt (SOURCED) | 6 columns, emoji size | LazyVGrid flexible columns, glyph size token, 44-pt cells |

## Quick reactions, rain, Activity

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `chat.reactions.layout.quickReactions`<br>`chat.reactions.icon.add`<br>`chat.reactions.a11y.quick`<br>`chat.reactions.a11y.add` | emoji: 🔥 💖; then: add-reaction button (chat.reactions.icon.add); place: inside the right end of the reply field, after the text (SOURCED)<br>ios: face.smiling; android: Rounded.AddReaction (PLATFORM)<br>“React with {emoji_name}” (SOURCED)<br>“Add reaction” (SOURCED) | 🔥 💖 + add inside the viewer reply field | ViewerReplyRow (photo.viewer) |
| matched | `chat.reactions.count.rainCopies`<br>`chat.reactions.dimension.rainEmoji`<br>`chat.reactions.duration.rainSpawnInterval`<br>`chat.reactions.duration.rainTravel`<br>`chat.reactions.duration.rainTotal`<br>`chat.reactions.layout.rainPath` | 18 (SOURCED)<br>52 pt (SOURCED)<br>125 ms (SOURCED)<br>770 ms (SOURCED)<br>2940 ms (SOURCED)<br>direction: upward; start: just below the bottom screen edge; end: just above the top screen edge; x: random across the full screen width, one x per copy; emo… (SOURCED) | rain: copies, size, spawn, travel, total, path, behind the photo | EmojiRain (TimelineView), allowsHitTesting(false), hidden from accessibility |
| matched | `chat.reactions.easing.rain` | easeInOut (SOURCED) | speed curve easeInOut per copy (G-11) | DSEasing.unitCurve on each copy’s travel; plays in release builds |
| matched | `chat.reactions.layout.reduceMotion` | rain: not played (automatic, repeating, peripheral motion is dropped); cluster: the new sticker appears in place; haptics: unchanged (PLATFORM) | Reduce Motion: not played, sticker in place | accessibilityReduceMotion check |
| approximated | `chat.reactions.duration.flyToCluster`<br>`spring.global.platformDefault.ios` | 300 ms (SOURCED)<br>response: 0.55; dampingFraction: 1 (PLATFORM) | the chosen emoji flies to the cluster’s leading end in 300 ms, decelerating, shrinking to clusterEmoji (G-12) | it rises from below the photo edge and shrinks from the picker’s emoji size while the others shift; the pick point is not tracked; curve not fitted → critically damped spring with the measured response; Reduce Motion: no animation |
| approximated | `chat.reactions.activity.title`<br>`chat.reactions.activity.row`<br>`chat.reactions.activity.rowMine`<br>`chat.reactions.empty`<br>`chat.reactions.layout.activitySheet` | “Activity” (SOURCED)<br>“{name} sent {emoji}” (SOURCED)<br>“You reacted {emoji} to {name}’s pic” (SOURCED)<br>“No reactions yet” (SOURCED)<br>BLOCKED | Activity sheet | layout BLOCKED: native List rows in the data’s order; empty line; no counts |
| matched | `chat.reactions.layout.unreact`<br>`color.global.selection` | where: in the reaction picker (long press on the photo, or the add-reaction glyph): every emoji you already reacted with on this photo is highlighted; highli… (SOURCED)<br>#0091FF (PLATFORM) | my emoji highlighted in the picker (selected trait); tap removes it, the sheet stays (G-13) | optimistic unreact, restored on failure (unit-tested, thread and viewer); no haptic, no rain |

## States and haptics

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `chat.reactions.error`<br>`haptic.global.error` | “Couldn’t send your reaction” (SOURCED)<br>ios: notification.error; android: REJECT (PLATFORM) | react fails: optimistic sticker removed, line announced | unit-tested rollback |
| approximated | `haptic.global.reaction` | ios: system (context menu plays its own haptic; no custom generator); android: LONG_PRESS (PLATFORM) | long press on a photo opens the picker | onLongPressGesture (the long press is not a context menu here, so no system haptic plays; no custom generator) |
| matched | `—` | — | never a number | ReactionSummary exposes no count; Activity rows have no totals |
