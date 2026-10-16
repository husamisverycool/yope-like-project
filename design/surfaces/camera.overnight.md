# camera.overnight — photos that develop at 9 AM (DRAFT)

> **Draft, 2026-10-16.** Proposed tokens and copy live **only in this file** until a consolidation pass moves them into
> `design/tokens/capture.json` and `design/copy/capture.json`. Research: `design/research/overnight-and-questions.md`
> (OQ). Backend: `design/research/overnight-and-questions-data.md`.

**Visual reference: Retro**, by composition only — C-01 header, **C-30 native segmented control on a black page**
(Retro's "Create Recap": system control, full width, between the header and the content — TC-REC), C-17 / C-18 photo
container, C-11 circles, C-09 pill on media, C-17 placeholder tile, C-29 native sheet. **Mechanics: Dispo** (a
`DEVELOP 9AM · NOW` switch on the camera; photos develop at 9 AM; shoot straight into chosen shared rolls; one
"developing" banner) and **Lapse** (normal viewfinder, no preview after the shutter, a developing stack in the leading
slot, one "developed" alert, a sequential review of what developed). No Dispo or Lapse colour, type, illustration,
glyph or word mark is used. Composition record: `camera.overnight.layout.*` (level SOURCED, method "composition of Retro
components C-01, C-30, C-17, C-11, C-09, C-29 in Dispo's / Lapse's order").

This surface has three parts: **A** the mode on the camera (an addition to `camera.capture`), **B** the developing tile
in group views, **C** the reveal (push, in-place reveal, sequence).

## References

| image | what it verifies |
|---|---|
| `references/auto/dispo/store/dispo-store-X-1.png` (DX1) | mechanics: a 2-segment `DEVELOP 9AM · NOW` control on the camera's top row, above the camera; 9AM default (conflict: ours is Now) |
| `references/auto/dispo/help/help-4410178185492_userguide-nov21.png` (DUG, phone 2) | mechanics: chosen rolls shown on the camera's top bar ("Planet plant-it · Private") |
| `references/auto/dispo/help/help-360097208771_library.png` (DLIB) | mechanics: **one** "developing" banner for all developing photos (its number is not copied) |
| `references/auto/lapse/store/lapse-store-01.png` (L01), `-05.png` (L05) | mechanics: full viewfinder kept; developing stack in the leading slot of the control row (number not copied); flash circle 64 pt |
| `references/auto/lapse/store/lapse-store-se-3.png` (LSE3) | mechanics: developing tiles with a centred marker; one aggregated "developed" banner (structure only) |
| `references/auto/lapse/store/lapse-store-03.png` (L03) | mechanics: developed photos reviewed one at a time with a position "2 of 9" |
| `references/auto/retro/press/tc-2023-12-recaps.png` (TC-REC phone 1) | Retro's native segmented control on black, full width under the header, above the content |
| `references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png` (H43) | C-01 header on black, C-17 tiles incl. placeholder fill `color.global.control` |
| `references/auto/retro/store/retro-store-03.png` (ST-03) | C-09 pill on a photo (destination pill) |
| Dispo help "Taking Photos on Dispo" (DH-TP) | "decide whether you'd like your photos developed traditionally at 9 AM, or immediately"; shoot to rolls, chosen before shooting |
| Dispo App Store text (DAS) | "Photos develop every day at 9am" |

## A. The mode on the camera

### Structure (393 × 852 pt; changes to `camera.capture` only)

`camera.capture` keeps its header, viewfinder, control row and tab bar. Added:

1. **Mode control** (`camera.overnight.layout.modeControl`): C-30 native segmented control, two segments in Dispo's
   order **`camera.overnight.mode.later`** ("9 AM") · **`camera.overnight.mode.now`** ("Now"); **Now** selected by default
   and on every app launch (the choice is kept while the camera stays in memory, as Dispo keeps it per shot). Full width
   inside `size.global.screenMargin`; top `size.global.titleToContent` (30) below the header title baseline; the
   viewfinder starts `size.global.sectionHeaderToContent` (11.7) below it. Height: the platform control's (iOS
   `Picker(.segmented)`, Android M3 `SingleChoiceSegmentedButtonRow`) — PLATFORM. Colours: drawn by the system in the
   dark appearance (the camera is a media surface); Android selection `color.global.system.secondaryContainer` dark
   value. The viewfinder shrinks to fit, 3:4 kept (rule already in `camera.capture` § Structure 3). The control is
   shown in both modes so the layout does not jump.
2. In **9 AM** mode:
   - **Destination pill** (`camera.overnight.layout.destinationPill`): C-09 on media — fill `color.global.controlOnDeep`,
     `icon.global.group` at `size.global.iconSmall`, label (`camera.overnight.destination.*`) text role `pill`,
     `color.global.textOnMedia`, height `size.global.pillHeight`, paddings `size.global.pillPaddingLeading` /
     `.pillPaddingTrailing`, icon gap `size.global.pillIconGap`, width hugs the label (max: viewfinder width − 2 ×
     `size.global.screenMargin`, label truncates at the end); centred; bottom 20.5 pt above the viewfinder bottom
     (`camera.sendto.layout.messageField`, the coach pill's slot — the video coach is never shown in 9 AM mode).
   - **Developing stack** (Lapse's leading-slot stack, L01 — without its number): **BLOCKED**. Lapse's stack is
     measurable only as a whole (L01 bbox incl. glow), so its card size and fan inside Jolt's 64-pt slot
     (`size.global.circleButtonLarge`) cannot be traced. Until a capture closes it, the leading slot stays **empty** in
     9 AM mode (the library circle is hidden — a picked photo was already seen, and neither reference imports in
     delayed mode). The status is carried by the destination pill and the capture announcement.
   - Flash and flip unchanged. Hold-to-record is off (photos only — Dispo "dispos", Lapse "snaps").

### Destination sheet (`camera.overnight.layout.destinationSheet`)

Opens the first time 9 AM is chosen in an app session, and from the destination pill. Native sheet (C-29, follows the
appearance), Dispo's "roll drawer" mechanic drawn with `camera.sendto`'s group rows:

| part | component · tokens | copy |
|---|---|---|
| title | sheet title, text role `sheetTitle` | `camera.overnight.destination.title` |
| explanation | text role `body`, `color.global.textSecondary`, ≤ 2 lines, `size.global.screenMargin` margins | `camera.overnight.destination.detail` ({reveal}) |
| group rows | exactly `camera.sendto.layout.recipientRow` (C-16 row, cover circle, name, check circle), in the sheet's appearance colours | group names (data) |
| done | C-08 text button in the toolbar | `camera.overnight.destination.done` |
| default selection | every group selected (owner decision 11, as `camera.sendto`) | — |
| no groups | `camera.sendto` empty state (C-27) | `camera.sendto.empty.*` (existing) |

Selection is kept for the app session (Dispo: "the selected roll(s) will be ready for you to shoot to"). Done with
nothing selected switches the mode back to Now.

### Elements

| element | component · tokens | copy | behaviour |
|---|---|---|---|
| mode control | C-30 · `camera.overnight.layout.modeControl` | segments `camera.overnight.mode.later` ({time}), `camera.overnight.mode.now`; a11y label `camera.overnight.a11y.mode`, hint `camera.overnight.a11y.modeHint` | Now = `camera.capture` as specified. 9 AM = the next photos develop at the reveal (part C). First switch to 9 AM in a session opens the destination sheet |
| destination pill | C-09 on media · `camera.overnight.layout.destinationPill` | `camera.overnight.destination.one` / `.all` / `.some`; a11y hint `camera.overnight.a11y.destinationHint` | tap → destination sheet |
| shutter (9 AM) | `camera.capture.size.shutter*` unchanged | a11y `camera.capture.a11y.shutter` | **tap** = photo; **no preview, no `camera.sendto`**: the photo uploads and is posted to the chosen groups as developing (`create_post` with `p_develop = true` and the capture time, data note §1); the camera stays ready for the next photo. Live Photo motion is not captured in 9 AM mode (photo only). Hold = nothing |
| developing stack | BLOCKED (slot empty meanwhile) | a11y `camera.overnight.a11y.stack` ({reveal}) once built | status, not a button |
| flash, flip | unchanged | unchanged | unchanged |
| library | hidden in 9 AM mode | — | a picked photo was already seen; neither reference imports in delayed mode |

### States (9 AM mode)

| state | design | copy | source |
|---|---|---|---|
| offline | capture works; the photo is stored on the device and queued (`camera.overnight.layout.uploadQueue`); nothing extra is drawn on the camera | — | Dispo offline help (capture works; uploads when reconnected) |
| upload failed after retries | C-26 toast (Android) / announcement (iOS) | `camera.sendto.error.sendFailed` (existing) | `camera.sendto` |
| no groups | destination sheet shows the `camera.sendto` empty state | `camera.sendto.empty.*` | `camera.sendto` |
| permission denied / camera unavailable | as `camera.capture`; the mode control stays | `camera.capture.denied.*`, `.unavailable.*` | `camera.capture` |

## B. The developing tile in group views

### Structure (`camera.overnight.layout.developingTile`)

In `groups.screen` → **This week** strip (C-17): while the group has at least one developing photo, **one** placeholder
tile — whatever the number of photos or photographers — sits just before the add tile (the newest position):
`size.global.stripTileWidth` × `.stripTileHeight` (84 × 112), fill `color.global.control`, no photo, no scrim; the word
`camera.overnight.tile.label` centred horizontally and vertically (Lapse centres its marker in the tile, LSE3), text
role `tileLabel`, `color.global.textSecondary`. Same tile in `week.history` (current week) and the home-screen group
row thumbnails show nothing new. Not shown in widgets, the chat or `photo.viewer`.

If the week ends while photos develop (taken Sunday night, reveal Monday 09:00), the tile stays in the week the photos
were **taken** (photos are placed by capture time once revealed).

| element | tokens | copy | behaviour |
|---|---|---|---|
| developing tile | C-17 placeholder · `color.global.control`, `tileLabel`, `color.global.textSecondary` | `camera.overnight.tile.label`; a11y `camera.overnight.tile.a11y` ({reveal}) | not a button; long press: none |

## C. The reveal

### Rules (`camera.overnight.layout.reveal`)

- Reveal time: the **first 09:00 after capture in the group's time zone** (`groups.time_zone`) — Dispo (DAS, DH-W). A
  photo sent to two groups in different zones reveals at each group's own 09:00. Daylight-saving: wall-clock 09:00.
- Before the reveal nobody can read the photo, the author included (server rule, data note §2).
- A photo whose upload completes after its reveal time reveals on arrival.

### Push (`camera.overnight.layout.push`)

One notification per group per reveal, to every member who has not muted the group, only if the group had developing
photos: title `camera.overnight.push.title` ({group}), body `camera.overnight.push.body`; iOS interruption level
**active** (passive in quiet hours), thread = group; Android channel `developed_photos` (name
`camera.overnight.push.channel.name`, description `.channel.description`, default importance). The member's switch is a
row in `settings.notifications` (`camera.overnight.settings.row` / `.settings.rowDetail`, default on). Payload
`type = overnight_revealed`, `group_id`, `reveal_at`. Tap → `groups.screen` of that group, then `photo.viewer` opens on
the photos revealed at that time, oldest first (Lapse's sequential review, L03), with the viewer's existing position
badge ("%1$d of %2$d").

### In place

If `groups.screen` is open at the reveal, the developing tile is replaced by the revealed photos at their capture-time
positions with the C-17 insert motion. Otherwise nothing animates: the photos are simply there.

## Motion

| motion | tokens | Reduce Motion |
|---|---|---|
| mode change | native segmented control animation (PLATFORM); destination pill in / out and library circle out / in `duration.global.fade` + `easing.global.standard` | same (fades) |
| destination sheet | native sheet (`spring.global.sheetPresent` for custom presentations) | platform |
| capture in 9 AM mode | platform shutter (system sound where the device plays it). **BLOCKED:** a hand-off motion from viewfinder to stack (not observed) | — |
| developing tile in / out | C-17: in with `duration.global.stripInsert` (250), fade from scale ≤ 0.875 (`duration.global.fade`) | cross-fade |
| reveal in place | each revealed photo tile inserts with the C-17 insert motion; the developing tile fades out `duration.global.fade`. **BLOCKED:** a dedicated reveal animation (no Dispo / Lapse recording) | cross-fade |

## Haptics

Mode change: `haptic.global.select` (C-30). Pill, sheet rows, Done: `haptic.global.tap` (Android). Shutter in 9 AM
mode: `haptic.global.shutter` (none — camera rule) — **flag:** with no preview the shutter sound is the only feedback;
a capture haptic has no reference (BLOCKED, Gaps). Reveal: none (system notification haptic only).

## Accessibility

- Mode control: label `camera.overnight.a11y.mode`, segments read their text, hint `camera.overnight.a11y.modeHint`;
  selection announced by the platform. Focus order: title → flash → **mode control** → (destination pill) → library
  (Now mode only) → shutter → flip → tab bar.
- After each 9 AM capture post the announcement `camera.overnight.a11y.captured` ({reveal}).
- Developing stack (once built): static element, label `camera.overnight.a11y.stack`. Developing tile: static element, label
  `camera.overnight.tile.a11y` — the label carries the reveal time the tile does not show.
- Dynamic Type: segment labels follow the platform control; pill `pill` → subheadline; tile `tileLabel` → footnote
  (fixed tile: the a11y label carries the text).
- Contrast (`node tools/contrast.mjs`):

| pair | light | dark |
|---|---|---|
| tile label `textSecondary` on `color.global.control` | 4.51:1 pass | 5.31:1 pass |
| tile fill `color.global.control` vs page (non-text) | 1.13:1 **FAIL** (known C-17 failure) | 1.39:1 **FAIL** |
| pill label `textOnMedia` on `controlOnDeep` | 15.13:1 pass | 15.13:1 pass |
| segmented control | system-drawn (PLATFORM) | — |

## Data & actions

- Writes: `create_post(p_media_id, p_group_ids, p_develop => true, p_captured_at)` per photo (data note §1); upload
  queue as `camera.sendto`. No caption, voice note or invitation id in 9 AM mode.
- Reads: `my_developing()` (boolean + earliest reveal, for the stack); `group_developing(group_id)` (boolean +
  `reveal_at`, for the tile) — never a number (data note §3).
- Realtime: broadcast `overnight_revealed` on `group:<id>` → refetch posts (data note §4).
- In: `camera.capture` (the control), push tap (`app://group/<id>?revealed=<reveal_at>` → `DeepLink.group`, then the
  viewer). Out: destination sheet, `groups.screen`, `photo.viewer`.

## Platform notes

- iOS: `Picker(.segmented)` on the black camera page with the dark appearance forced (media rule); no Live Photo in 9 AM
  mode (`isLivePhotoCaptureEnabled = false` for these shots).
- Android: M3 `SingleChoiceSegmentedButtonRow`; channel `developed_photos` created once.
- The camera must not write 9 AM photos to the system photo library before the reveal (Dispo since 3.0.0 saves to the
  camera roll — after developing); local files live in app storage until uploaded, then are deleted.

## Proposed tokens (not yet in `design/tokens/*.json`)

| key | type | value | level | evidence / method |
|---|---|---|---|---|
| `camera.overnight.layout.modeControl` | layout | `{component: "C-30", width: "screen − 2 × size.global.screenMargin", top: "size.global.titleToContent below the title baseline", toViewfinder: "size.global.sectionHeaderToContent", segments: ["later", "now"], default: "now", haptic: "haptic.global.select"}` | SOURCED | composition of Retro C-30 (TC-REC) in Dispo's order (DX1: control row above the camera); default from `camera.capture` (OQ §8) |
| `camera.overnight.layout.destinationPill` | layout | `{component: "C-09 on media", icon: "icon.global.group", bottomInset: "camera.sendto.layout.messageField", centred: true}` | SOURCED | composition (ST-03 pill on photo) of Dispo's roll chips on the camera (DUG phone 2) |
| `camera.overnight.layout.destinationSheet` | layout | `{component: "C-29 sheet", rows: "camera.sendto.layout.recipientRow", default: "all groups", keep: "app session"}` | SOURCED | Dispo roll drawer (DH-TP); owner decision 11 |
| `camera.overnight.layout.developingTile` | layout | `{component: "C-17 placeholder", fill: "color.global.control", label: "tileLabel / color.global.textSecondary, centred", perGroup: 1, position: "before the add tile"}` | SOURCED | Retro C-17 (H43); one banner (DLIB); centring (LSE3) |
| `camera.overnight.layout.reveal` | layout | `{time: "09:00", zone: "groups.time_zone", rule: "first 09:00 after capture", lateUpload: "reveal on arrival"}` | SOURCED | Dispo DAS, DH-W, DN |
| `camera.overnight.layout.push` | layout | `{perGroupPerReveal: 1, ios: "active (passive in quiet hours)", androidChannel: "developed_photos", tap: "groups.screen → photo.viewer (revealed, oldest first)"}` | SOURCED | Lapse LSE3 (one aggregated alert), L03 (sequence); `daily.notification` levels |
| `camera.overnight.layout.uploadQueue` | layout | `{offline: "store in app storage, retry on reconnect", photoLibrary: "never before reveal"}` | SOURCED | Dispo offline help 360062068852 |
| `camera.overnight.layout.stackCards` | layout | — | **BLOCKED** | Lapse stack card geometry not measurable (Gaps) |

## Proposed copy (not yet in `design/copy/*.json`)

| key | text | origin | pattern | evidence | level |
|---|---|---|---|---|---|
| `camera.overnight.mode.later` | `{time}` (locale short time of 09:00: "9 AM", "09:00") | adapted | `retro.voice.formats` | Dispo segment "9AM" (DX1); casing / format by the locale formatter | SOURCED |
| `camera.overnight.mode.now` | Now | adapted | `retro.voice.sentence-case` | Dispo segment "NOW" (DX1), caps → sentence case | SOURCED |
| `camera.overnight.a11y.mode` | Develop | adapted | `retro.voice.sentence-case` | Dispo header "DEVELOP" (DX1) | SOURCED |
| `camera.overnight.a11y.modeHint` | Photos taken for {time} stay hidden from everyone, you too, until they develop. | new | `retro.voice.explanation` | Dispo "wait for them to develop at 9 AM the next morning" (DH-W); Lapse "a mystery …until later" (LSE3) | SOURCED |
| `camera.overnight.destination.title` | Choose Groups | adapted | `retro.voice.title-case` | Retro "Choose friends" (`home_invite_feed_card_*` CTA, RP §4.2), friends → groups; Dispo "choose which rolls you want to shoot to" (DN) | SOURCED |
| `camera.overnight.destination.detail` | Photos you take now develop for these groups {reveal}. | new | `retro.voice.explanation` | Dispo "Select the roll(s) you'd like to shoot to" + "develop at 9 AM" (DH-TP, DH-W); {reveal} = platform relative date + time ("tomorrow at 9 AM") | SOURCED |
| `camera.overnight.destination.done` | Done | verbatim | `retro.voice.button` | Retro "Done" (`camera.sendto.message.done`) | SOURCED |
| `camera.overnight.destination.one` | {group} | new | `retro.voice.terse-numbers` | Dispo roll chip shows the roll's name (DUG phone 2) | SOURCED |
| `camera.overnight.destination.all` | All groups | adapted | `retro.voice.sentence-case` | Locket send-to "All friends" (owner decision 11), friends → groups | SOURCED |
| `camera.overnight.destination.some` | Selected groups | new | `retro.voice.sentence-case` | Dispo chips list only the chosen rolls (DUG); no count by tenet | SOURCED |
| `camera.overnight.a11y.destinationHint` | Choose which groups these photos develop for | new | `retro.voice.coach` | Dispo DH-TP | SOURCED |
| `camera.overnight.a11y.stack` | Photos developing until {reveal} | new | `retro.voice.explanation` (fragment) | Lapse stack (L01); Dispo "photos developing" (DLIB), number dropped | SOURCED |
| `camera.overnight.a11y.captured` | Photo taken. It develops {reveal}. | new | `retro.voice.confirmation` | Dispo DH-W | SOURCED |
| `camera.overnight.tile.label` | Developing | adapted | `retro.voice.sentence-case` | Dispo "developing" (DLIB banner), number dropped, capitalised | SOURCED |
| `camera.overnight.tile.a11y` | Photos developing, shown to everyone {reveal} | new | `retro.voice.explanation` (fragment) | DLIB; DH-W | SOURCED |
| `camera.overnight.push.title` | {group} | adapted | `retro.voice.push` | Retro context title ("Week %1$d", `post_reminder_notification_title_template`); Lapse one banner per reveal (LSE3) | SOURCED |
| `camera.overnight.push.body` | Photos have developed and are ready to view. | adapted | `retro.voice.push` | Lapse "SNAPS DEVELOPED" / "5 snaps ready to view" (LSE3): count, caps and emoji removed, "snaps" → "Photos" | SOURCED |
| `camera.overnight.push.channel.name` | Developed Photos | new | `retro.voice.push-channel` | Retro channel names ("New Posts", "Friend Activity") | SOURCED |
| `camera.overnight.push.channel.description` | When photos taken for 9 AM are ready to view | new | `retro.voice.push-channel` | Retro "Recent posts from users you care about" | SOURCED |
| `camera.overnight.settings.row` | Developed Photos | new | `retro.voice.settings` | Retro settings rows (Title Case) | SOURCED |
| `camera.overnight.settings.rowDetail` | A notification when photos taken for 9 AM are ready. | new | `retro.voice.settings` | Retro "Others will not be able to send you friend requests." | SOURCED |

`{time}` and `{reveal}` are formatted by the platform (iOS `Date.FormatStyle` / `RelativeDateTimeFormatter`, Android
`DateFormat.getTimeFormat` / `DateUtils.getRelativeDateTimeString`) — PLATFORM. The words "9 AM" inside the channel and
settings strings are `{time}` at build time of the string.

## Do-not-copy

Dispo: name, star mark, illustrated camera bodies, film canisters, small viewfinder window, palette (#B4CDE2), caps
labels, camera / film names, paid skins and prints, "dispos", "Ready to roll?", "15 photos developing". Lapse: name,
"Friends not followers®", stack number, gradient cards, lock glyph, "SNAPS DEVELOPED", 💥 🎞️, "5 snaps", "10+" badge,
36-shot rolls. Anywhere: countdown to 9 AM, "N shots left", "you missed it", "don't miss", urgency emoji.

## Gaps

| item | status | smallest capture / decision |
|---|---|---|
| dedicated reveal animation | BLOCKED; Retro insert motion used meanwhile | 60 fps screen recording of Dispo or Lapse at the moment photos develop |
| capture → stack hand-off motion; stack card geometry | BLOCKED; leading slot empty meanwhile | 60 fps recording of Lapse's shutter press + one raw screenshot of its stack |
| capture haptic in 9 AM mode | BLOCKED (none meanwhile) | recording with haptics noted, or lead decision "none" |
| reveal edge (photo at 08:59) | rule "first 09:00 after capture" is a reading of Dispo's text | owner test in Dispo at 08:55 |
| "Develop" label above the control | dropped (space); a11y label carries it | check with two non-technical members |
| delete photos still developing | not offered (no reference); tenet risk F-2 | lead decision |
| Dispo's real push text | not found | owner screenshot of Dispo's "developed" notification |
