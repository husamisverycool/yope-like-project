# `chat.reactions` — any-emoji reactions on photos

Reference app: **Locket** (reactions) (`docs/SURFACES.md`). Shown inside Yope-referenced screens (`chat.thread`,
`photo.viewer`). Research: `design/research/locket.md` §7, §9, §11. Tokens: `design/tokens/social.json`
(`chat.reactions.*`) + `global.*`. Copy: `design/copy/social.json` (`chat.reactions.*`), Locket voice (Sentence case).
Tenet 2: **no number anywhere** — not on the cluster, not in the list, not in pushes, not in accessibility labels.

## References

| id | file | used for |
|---|---|---|
| AS-4 | `references/auto/locket/store/locket-store-04.png` (listing 2.68.0) | **cluster**: overlapping emoji stickers with a white outline at the photo's bottom-left; add-reaction circle bottom-right |
| AS-8 | `references/auto/locket/store/locket-store-08.png` | History (viewer): reply bar with quick reactions 🔥 💖 + add glyph |
| GP-7 | `references/auto/locket/play/locket-play-07.png` | Android reply bar (🔥 💛 + add) |
| TT-2025 | `references/auto/locket/frames/locket-tt-7460656081153445163-15.000s-emoji-picker-sheet-search-popular.jpg`, `…-16.534s-reaction-fly-to-cluster.jpg`, `…-16.734s-reaction-cluster-landed.jpg` | picker sheet (Search · Frequently Used · Popular · All), fly-to-cluster, landed cluster |
| TT-2022 | `references/auto/locket/frames/locket-tt-7147749171762908462-02.000s-emoji-picker-search.jpg`, `…-05.300s-emoji-rain-rising-behind-photo.jpg`, `…-05.667s-emoji-rain-exit-top.jpg` | **emoji rain measurement (2022 build)**, 2022 picker |
| OW | `references/owner/locket-reply-grid.jpg`, `references/owner/locket-emoji-rain.jpg`, `references/auto/locket/frames/locket-tt-7282839171952102686-16.600s-reply-sheet-emoji-rain-2023.jpg` | 2023 reply sheet (2 × 5 quick grid), rain drawn over the photo |
| APK | Locket Android 1.243.0 string table (locket.md §7) | "Activity", "{{name}} sent {{emoji}}", "No reactions yet", reaction lines |

## Structure

### 1. Cluster on a photo (thread photo messages and the viewer photo)

Bottom-left corner of the photo: `chat.reactions.dimension.clusterInsetLeading` (17) from the left,
`chat.reactions.dimension.clusterInsetBottom` (20) from the bottom. One **sticker per distinct emoji** anyone reacted with
(`chat.reactions.layout.cluster`): the emoji at `chat.reactions.dimension.clusterEmoji` (39, outline included) with a
`chat.reactions.dimension.clusterOutline` (2) outline in `chat.reactions.color.clusterOutline`, each next sticker
`chat.reactions.dimension.clusterStep` (27) further right, drawn over the previous one. No numbers, no avatars, no "+N".
Order: `chat.reactions.layout.clusterOrder` — newest distinct emoji first at the leading end, earlier ones shift one step
trailing (Locket 2025 video, Gap fill G-10); maximum visible: **BLOCKED** (`chat.reactions.count.clusterMaxVisible`).
Hidden when nobody reacted.

### 2. Picker (bottom sheet)

Opened by a long press on a photo message (`chat.thread`) or the add-reaction glyph in the viewer's reply field
(`photo.viewer`). `chat.reactions.layout.picker`: native sheet with a grabber (`radius.global.sheet`,
`easing.global.native.sheet`), top to bottom:

1. Search field (native), placeholder `chat.reactions.picker.search`.
2. Section label `chat.reactions.picker.frequent` (`chat.reactions.fontSize.pickerSection` /
   `.fontWeight.pickerSection`, `color.global.textSecondary`), then the person's recently used emoji.
3. Section label `chat.reactions.picker.popular`, then `chat.reactions.layout.pickerPopular` in its order.
4. Section label `chat.reactions.picker.all`, then every emoji (Unicode emoji list, system categories order).

Grid: `chat.reactions.count.pickerColumns` (6) equal columns across the sheet width, emoji at
`chat.reactions.dimension.pickerEmoji` (≈40, filmed). Tapping an emoji sends the reaction and closes the sheet. Search
filters by the emoji's system name. Any emoji is accepted (`react` validates server-side).

### 3. Quick reactions (viewer reply field)

`chat.reactions.layout.quickReactions`: 🔥 then 💖, then the add-reaction glyph (`chat.reactions.icon.add`), inside the right
end of the viewer's reply field (`photo.viewer.md`). Tapping 🔥 or 💖 reacts at once.

### 4. Emoji rain (after you react)

`chat.reactions.layout.rainPath`: on the reacting person's screen, when the reaction is sent:
`chat.reactions.count.rainCopies` (18) copies of the chosen emoji, each `chat.reactions.dimension.rainEmoji` (52) wide, enter
from just below the bottom edge at random x positions across the full width, one every
`chat.reactions.duration.rainSpawnInterval` (125 ms); each rises to just past the top edge in
`chat.reactions.duration.rainTravel` (770 ms); the whole effect lasts `chat.reactions.duration.rainTotal` (2940 ms). The copies
pass **behind the photo** and in front of the background (2022 History screen, the viewer's counterpart; S-9). Speed curve:
`chat.reactions.easing.rain` = easeInOut (slow–fast–slow measured on 28 copies, G-11). **Measured on Locket's 2022 build**; the current build was not recordable.
In the thread (photo message long press) the rain plays over the whole thread screen behind the photo message.

### 5. Reactions list ("Activity" sheet)

Tap on a cluster → native sheet titled `chat.reactions.activity.title`; one row per reaction:
`chat.reactions.activity.row` ("{name} sent {emoji}") or, for yours, `chat.reactions.activity.rowMine`. No counts, no totals.
Row layout and order: **BLOCKED** (`chat.reactions.layout.activitySheet`). Empty: `chat.reactions.empty`.
Taking back a reaction (`chat.reactions.layout.unreact`, Apple Messages + WhatsApp help, G-13): in the picker every emoji
you already reacted with on this photo sits on a filled `color.global.selection` circle (selected trait); tapping it calls
`unreact` and the sticker leaves the cluster when nobody else used that emoji.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| cluster sticker | `chat.reactions.dimension.clusterEmoji`, `.clusterOutline`, `.clusterStep`, `.clusterInsetLeading`, `.clusterInsetBottom`, `chat.reactions.color.clusterOutline`, `chat.reactions.layout.cluster` | `chat.reactions.a11y.cluster` (whole cluster) | tap → Activity sheet |
| picker sheet | `chat.reactions.layout.picker`, `radius.global.sheet`, `easing.global.native.sheet` | — | swipe down / tap outside closes |
| search field | native search field | `chat.reactions.picker.search` | filters by emoji name |
| section labels | `chat.reactions.fontSize.pickerSection`, `.fontWeight.pickerSection`, `color.global.textSecondary`, `chat.reactions.layout.textStyleMap.pickerSection` | `chat.reactions.picker.frequent`, `.popular`, `.all` | — |
| emoji cell | `chat.reactions.count.pickerColumns`, `chat.reactions.dimension.pickerEmoji` | emoji system name (platform) | tap → `react(post, emoji)`, sheet closes, rain plays |
| quick reaction | `chat.reactions.layout.quickReactions` | `chat.reactions.a11y.quick` | tap → `react` |
| add-reaction glyph | `chat.reactions.icon.add` in `color.global.textSecondary` | `chat.reactions.a11y.add` | opens the picker |
| emoji rain | `chat.reactions.count.rainCopies`, `.duration.rainSpawnInterval`, `.duration.rainTravel`, `.duration.rainTotal`, `.dimension.rainEmoji`, `.layout.rainPath`, `.easing.rain` | — (decorative, hidden from accessibility) | not interactive; does not block touches |
| Activity sheet | layout **BLOCKED** | `chat.reactions.activity.title`, `.row`, `.rowMine`, `chat.reactions.empty` | — |

## States

| state | what shows | tokens / copy | source |
|---|---|---|---|
| no reactions | no cluster on the photo; Activity sheet shows the empty line | `chat.reactions.empty` ("No reactions yet") | APK (`locket.widget.empty`) |
| loading (Activity sheet) | platform activity indicator | `easing.global.native.activityIndicator` | PLATFORM |
| error / offline (react fails) | the optimistic sticker is removed; line announced | `chat.reactions.error`; `haptic.global.error` | `locket.voice.sentence-case` |
| permission-denied | not applicable | — | — |

## Motion

| motion | tokens | Reduce Motion |
|---|---|---|
| picker sheet in / out | `easing.global.native.sheet` | system |
| emoji rain | `chat.reactions.duration.rainSpawnInterval`, `.rainTravel`, `.rainTotal`, `.layout.rainPath`, `chat.reactions.easing.rain` (easeInOut) | `chat.reactions.layout.reduceMotion`: rain not played; the sticker appears in place |
| new sticker joining the cluster | the chosen emoji flies from where it was picked to the cluster's leading end in `chat.reactions.duration.flyToCluster` (300 ms, decelerating; Locket 2025, G-12), shrinking to `chat.reactions.dimension.clusterEmoji` | inserted without animation |

## Haptics

| interaction | token |
|---|---|
| long press on a photo opens the picker | `haptic.global.reaction` |
| reaction sent | none (no reaction haptic in the research; HIG "Avoid overusing haptics" — `haptic.global.reaction` notes) |
| react failed | `haptic.global.error` |

## Accessibility

- Cluster: one element, label `chat.reactions.a11y.cluster` with the emoji's system names (e.g. "Reactions: fire, sparkling
  heart") — never a count; trait button (opens the list).
- Picker: search field; section labels as headers; each emoji cell labelled with its system name; quick reactions
  `chat.reactions.a11y.quick`; add glyph `chat.reactions.a11y.add`.
- Emoji rain hidden from accessibility; it never moves focus.
- Dynamic Type: section labels → `chat.reactions.layout.textStyleMap.pickerSection` (footnote); emoji cells keep their size.
- Contrast: sticker outline `chat.reactions.color.clusterOutline` (#FFFFFF) sits on photo content (no fixed backdrop);
  against `color.global.background` it is 17.93:1 (pass). Section labels use `color.global.textSecondary` on the native
  sheet material (system colour, not a token: not computed).

## Data & actions

- **Reads**: `reactions` (docs/API.md §5.10) for the post — rows `(user_id, emoji)`, never a count; distinct emoji for the
  cluster; `profiles` for names in the Activity sheet.
- **RPCs**: `react(p_post_id, p_emoji)` (idempotent; a person may add several emoji); `unreact(p_post_id, p_emoji)` (from the
  picker's highlighted emoji, `chat.reactions.layout.unreact`). Errors `post_not_found`, `invalid_emoji`. Job `push.reaction` → push text `notifications.push.reaction.title` /
  `.body` (design/copy/capture.json).
- **Realtime**: `reactions` INSERT on the group channel; `reactions_changed` broadcast → refetch that post's reactions
  (§8.1–8.2).
- **Never** request `Prefer: count=…` (§13).
- Navigation: lives inside `chat.thread` and `photo.viewer`; a reaction push opens `DeepLink.post(groupID:postID:)` →
  `photo.viewer`.

## Platform notes

- iOS has no public emoji-picker component: the picker is a custom grid in a `.sheet` with `.presentationDragIndicator(.visible)`;
  emoji names from `CFStringTransform(kCFStringTransformToUnicodeName)`; "Frequently Used" kept per device.
- Android: `ModalBottomSheet`; `androidx.emoji2` for emoji support and names (the `EmojiPickerView` widget is not
  used, to keep Locket's sections).
- Emoji glyphs differ by platform font; sizes are glyph sizes.
- Rain drawn in a non-interactive overlay layer (iOS `allowsHitTesting(false)`, Compose `Modifier.pointerInput` none).

## Do-not-copy

- "{{friendsCount}} friends sent {{emojis}}" (count), "Locket views / See who's opened your Lockets" (view list).
- Unread count badge on the chat button.
- Yope's reaction capsule with reactor avatars under chat photos (S-4).
- The word "Locket" in any string (trademark → "pic").

## Gaps

| item | status | smallest owner capture |
|---|---|---|
| emoji rain on the current build (count, timing, curve) | values from 2022; `chat.reactions.easing.rain` **SOURCED (gap fill)**: easeInOut from the same 2022 recording (G-11) | one 8-s iPhone screen recording of tapping a quick reaction in Locket's History |
| `chat.reactions.duration.flyToCluster` | **SOURCED (gap fill)**: 300 ms ±33, Locket 2025 video (G-12) | a screen recording (not filmed) would tighten it |
| `chat.reactions.layout.clusterOrder` | **SOURCED (gap fill)**: newest first, Locket 2025 video (one observation, G-10) | — |
| `chat.reactions.count.clusterMaxVisible` | BLOCKED (no app documents a cap; counts seen elsewhere are do-not-copy) | one screenshot of a Locket photo with six or more reactions |
| `chat.reactions.layout.activitySheet` | BLOCKED (Messages groups senders per Tapback, which does not fit Locket's per-person strings; WhatsApp's sheet not reachable as an image) | one screenshot of Locket's reaction list for one of your photos |
| `chat.reactions.layout.unreact` | **SOURCED (gap fill)**: highlighted in the picker, tap to remove — Apple Messages + WhatsApp help (G-13) | one Locket recording would supersede |
| picker metrics (`pickerEmoji`, `pickerSection`) | approximate (phone filmed at an angle) | one screenshot of Locket's emoji sheet |
| two Popular cells hidden by a finger | left out | same screenshot |
