# Research: Plans (Partiful · Apple Invites) and the countdown widget

Pass date: 2026-10-16. New surfaces: `plans.create`, `plans.page`, `widget.countdown` (draft specs in
`design/surfaces/`), data note `design/research/plans-data.md`. Image indexes: `references/auto/partiful/INDEX.md`
(section "Added by the plans research pass"), `references/auto/apple-invites/INDEX.md` (+ `store/INDEX.md`),
`references/auto/countdown-widgets/INDEX.md`.

Visual system: **Retro** (owner decision 2026-10-15). Partiful, Apple Invites and the countdown apps supply
**mechanics only** — fields and their order, answer states, who sees what, when notifications go out, what a widget
says. Every visual value of the drafts is an existing Jolt token (`design/tokens/global.json`, `capture.json`) placed
by a Retro composition (`design/components.md`); the measurements below are recorded so the mapping can be checked,
not to be copied.

Leads re-checked: `/home/user/newproject/research/21-events-plans.md`, `15-wrapped-partiful-exact.md`,
`04-wrapped-duolingo-partiful.md`. A lead row is used only where it was re-fetched below.

## 0. Sources and how they were measured

| id | source | what it is | scale (px → pt) | date / version |
|---|---|---|---|---|
| **AI-S** | `references/auto/apple-invites/store/apple-invites-store-0N.png` (02–10) | App Store screenshots, 1320×2868, raw captures (9:41 status bar, no device frame) | 1320 px = 440 pt (iPhone 6.9"), **3.000 px/pt** | listing v1.12.1 (2026-10-14), app id **6472498645** |
| **AI-N** | `references/auto/apple-invites/newsroom/ai-newsroom-2025-02-*.jpg` | Apple Newsroom device renders in a phone frame, 1306×1828 | not used for pt values (frame + perspective-free but scaled render); layout and order only | 2025-02-04 |
| **AI-G** | Apple Invites User Guide for iPhone, https://support.apple.com/guide/apple-invites/<slug>/ios (11 pages, list in `apple-invites/INDEX.md`) + `support/*.png` | official text | — | read 2026-10-16 |
| **PF-S** | `references/auto/partiful/store/partiful-store-0N.png` | App Store marketing composites (phone mock-ups), 1242×2688 | ratios only (screen width not measurable, as in `wrapped-tribute-partiful.md` §5) | listing v3.10.09 |
| **PF-AP** | App Store App Preview video (HLS `P930222191`, 886×1920, 30 fps, 30.0 s); cited frames `references/auto/partiful/frames/pf-apppreview-t*.png` | official marketing video built from screen recordings; **assumed 1:1** (886 px = 393 pt) | **2.2545 px/pt**, ±3 % (the video is edited: zooms at 5.0–6.5 s; frames used are after the zoom settles) | poster dated 2025-02-12 |
| **PF-W** | `references/auto/partiful/web/pf-web-*` (+ `*.computed-styles.json`) | live event pages and the RSVP sheet, Playwright, 390 CSS px = 390 pt | **VERIFIED** (computed styles) | captured 2026-10-15 (`wrapped-tribute-partiful.md` §5, reused) |
| **PF-H** | help.partiful.com articles (ids in `partiful/INDEX.md`) + `references/auto/partiful/help/*.png` | official help-centre text and images | — | articles dated 2026-06-16 … 2026-08-14 |
| **CW-DU** | `references/auto/countdown-widgets/store/cwdu-store-01/02/04.png` | "Countdown Widget: Days Until" (APPLAYERS LTD), id6756182989, v1.3.1, 437 ratings — store composites | widget-relative ratios; one scale assumption stated per row | 2026-10-12 |
| **WS** | `countdown-widgets/store/widgetsmith-store-05.png` | Widgetsmith (Cross Forward Consulting), id1523682319, v8.7, **775,771 ratings** | wording only | 2026-09-28 |
| **CW-DC** | `countdown-widgets/store/cwdc-store-01/04.png` | "Countdown Widget \| Day Counter" (Evgeniia Ludinova), id6446944824, v1.2, 209 ratings | wording only | 2025-09-06 |
| **HIG / docs** | HIG Widgets (`references/auto/platform/hig-widgets-ios-dimensions.png`, `design/research/platform.md` widget section); Apple `RelativeDateTimeFormatter` docs; Android `DateUtils` reference | official | — | fetched 2026-10-16 |

**Unreachable / not found (recorded, not worked around).** Apple id `6741047478` (named in the brief) → HTTP 404 on
apps.apple.com and an empty lookup; the real Apple Invites id is 6472498645. Apple Invites has **no App Preview video**
(no `.m3u8` in the listing). The App Store search API returned HTTP 403 (apps were found by web search, then the lookup
API, which works). Firecrawl was out of credits (pages were fetched with curl instead). The Partiful in-app RSVP sheet
and plan-edit screens are not in any store image or the App Preview (the preview shows creation, theming, text blasts,
the photo roll and the activity feed only).

---

## 1. Mechanics evidence (text, VERIFIED unless marked)

### 1.1 Apple Invites — creating, answering, editing, cancelling (AI-G, verbatim)

| topic | quote | page |
|---|---|---|
| create fields and order | "Background image: Tap Add Background, then choose Photos … or Camera" → "Title: Tap Event Title, choose a font style, enter the name for your event" → "Date and time: Tap Date and Time … You can also choose a time zone, whether the event has an end time, or whether it's an all-day event." → "Location: Tap Location, then search for a location … Optionally, you can enter a name for the location, such as "Danny's House."" → "Event details: Tap Add Description" → "Shared album: Tap Create Album" → "Link" → "Shared playlist" → "Tap Preview … then tap Next." → "Invite guests" | create-an-event |
| draft | "If you want to save the event as a draft instead, tap [×] in the upper-left corner, then tap Save Event." | create-an-event |
| location side effects | "When you set a location, Maps information is automatically added … If you also set a date, the weather forecast for that date is added." (do-not-copy: we never collect location) | create-an-event |
| answer | "Tap Going, Not Going, or Maybe, then tap Send Reply. Optionally, add a note that will be visible to the host and other guests." | rsvp-to-an-event |
| leave | "Tap an event, then tap Not Going or Maybe. Tap Send Reply." / "If you want to rejoin an event you left, ask the host to reinvite you." | leave-an-event |
| cancel vs delete | Cancel: "everyone on the guest list automatically receives a notification that the event has been canceled. You can still see the event, guest list, shared album, and playlist …, but the name is crossed out and no one else can RSVP. If you change your mind …, you can restore the event." Delete: "Everyone on the guest list automatically receives a notification that the event has been deleted. The shared album and playlist remain available …" "There's no Recently Deleted folder" | cancel-or-delete-an-event |
| cancel path | "Tap [•••] in the upper-right corner, tap Event Settings, then tap an option." | same |
| edit | "If the event is published, tap [•••], then tap Edit. Tap an event detail, then make any changes. When you're finished, tap [✓] or tap [×] to discard the changes." | edit-an-event |
| settings | "Additional Guests — Set the number of additional people each guest can bring." (do-not-copy) · "Show Who's Invited — By default, guests can see who's invited after they reply." · "Approve Guests" · "Duplicate Event" · "Cancel Event or Restore Event" · "Delete Event" | change-event-settings |
| notifications | "you can choose whether you're notified about changes for events you're hosting or attending … Tap Push Notifications or Email Updates, then turn options on or off." Also "Sync All Events" to Calendar. | change-notification-settings |
| host note | "post a note that everyone on the guest list can see. For example, you can let guests know if you changed the location" — "Send a Note" / "Send Note" | send-a-note-to-guests |
| album | "Tap an event, tap Join Album, then tap Add Photos." (manual; ours is automatic) | add-items-… |
| **widget** | "You can also add a widget to your Home Screen to **count down the days until your next event**." · "you can quickly see your next event—and count down the days until the event—by adding an Apple Invites widget … To change the featured event, touch and hold the widget, then tap Edit Widget." | view-your-events |
| home categories | "Upcoming, All Events, Past Events, Drafts, Hosting, and Attending" | view-your-events |

Newsroom (2025-02-04): "participants can easily contribute photos and videos to a dedicated Shared Album within each
invite to help preserve memories and relive the event." · "Attendees control how their details show up to others, and
have the ability to leave or report an event at any time."

### 1.2 Partiful — reminders, cancel, photos, answers (PF-H, verbatim)

| topic | quote | article |
|---|---|---|
| auto-reminders | "For guests who RSVP "Going", we send reminders 2 hours before the event. If someone RSVPs "Maybe" or hasn't RSVP'd yet, we'll remind them to finalize their RSVP 1 week before the event." | 15525436 |
| schedule fixed | "At this time, you can only turn auto-reminders on or off - there's no option to choose when they go out." | 15525435 |
| complaints exist | title "I'm getting too many reminders about an event!" — "Auto-reminders for an event are controlled by the host of the event!" | 15525538 |
| **Group Reminder** (the lightweight plan) | "a lightweight way to do this without setting up a full event. It's built for the plans that don't need a full RSVP process … Group Reminders are hostless, meaning anyone added can edit the details (title, time, location), add more mutuals, or remove themselves at any time. **All participants will receive a notification when they are added and 24 hours before the Group Reminder.**" "Give your reminder a title, emoji, date, and time. Add any desired details such as location and description" | 15774034 (2026-07-01) |
| cancel | "click on the three dots on the Edit toolbar … click "Cancel Event." Your guests will be notified that the event was canceled!" · "Can I cancel an event without notifying my guests?" → "Unfortunately not!" · "there's not an option to un-cancel an event! The best solution is to clone the event" | 15525451, 15525452, 15525449 |
| date change | "Your guests won't be notified of any date or time changes - you'll need to send them a text blast" · "You can't change the date and time for events that are in the past" | 15525367 |
| photos | "Guests and hosts can upload pictures to the Partiful page using the "Upload Photos" button at the top of the Activity Feed! Then anyone on the event can view and download the pics." | 15525446 |
| guest count is optional | "an option to "Show Guest List" and "Show Guest Count" (aka "# Going") on your party page, which you can switch off" | 15525441 |
| answers | "guests will only be able to RSVP "Going" or "Can't Go"" (with Maybe off; default allows "Maybe") | 15525363 |
| change answer | "RSVP again using the original Partiful link … it will replace your previous RSVP." · after the event: "We don't enable people to change their RSVP after the event so that it remains a fairly accurate record of who went" | 15525520, 15525507 |
| host notified | "On our app, you'll get a notification for every RSVP." (do-not-copy) | 15525377 |
| cover image | "Upload a square image or GIF (1:1 aspect ratio) at 1200 x 1200 pixels or larger … some views crop the poster to a square" | 15525294 |

### 1.3 Countdown apps (SOURCED wording)

| app | what a widget says | file |
|---|---|---|
| Apple Invites | photo + "Weekend Retreat" + **"In 9 Days"** (+ a "👤 15" guest-count pill, do-not-copy) | AI-S 08 |
| Widgetsmith | "SPRING BREAK" / **"4 DAYS"** over a full-bleed photo | WS |
| Countdown Widget: Days Until | "Holiday Travel" / **"9"** / "days left"; "My Birthday" / "132" / "days left" / "22 January, 2026" | CW-DU 02 |
| Countdown Widget \| Day Counter | "UNTIL VACATION 52 14 18 DAYS HOURS MINUTES" (do-not-copy), "64 DAYS OF SOBRIETY" (count-up, do-not-copy) | CW-DC 01 |
| — notifications | "One day until "Anniversary"!" · "One week until "Vacation"!" · "Kate's Birthday!!!" | CW-DC 04 |
| — seconds | DAYS / HOURS / MINUTES / SECONDS share view (do-not-copy, brief + SPEC_FLAGS T4) | CW-DU 04 |

Platform relative-date wording (PLATFORM, docs fetched 2026-10-16):
- Apple `RelativeDateTimeFormatter`: "Use the strings that the formatter produces, such as "1 hour ago", "in 2 weeks",
  "yesterday", and "tomorrow" as standalone strings." `DateTimeStyle.named`: "uses named styles to describe relative
  dates, such as "yesterday", "last week", or "next week"."
  (https://developer.apple.com/documentation/foundation/relativedatetimeformatter)
- Android `DateUtils.getRelativeTimeSpanString`: "Time spans in the future are formatted like "In 42 minutes"."
  (https://developer.android.com/reference/android/text/format/DateUtils); ICU `android.icu.text.RelativeDateTimeFormatter`
  (API 24) formats `RelativeUnit.DAYS` and `AbsoluteUnit.DAY` with `Direction.NEXT` / `THIS`.
- The exact output for "0 days" ("today") is **not printed in either doc**: it is produced by the formatter at run
  time and must be pinned by a snapshot test, not typed by us (see §12).

---

## 2. Plan creation flow

### 2.1 Fields and order in the references

| # | Apple Invites (AI-G create-an-event, AI-N create image) | Partiful (PF-AP t 7.250, t 9.250) |
|---|---|---|
| 1 | Background image ("Add Background" → Photos / Camera; "Edit Background" pill on the image) | Title field "My Birthday" (display face, centred) |
| 2 | Title ("Event Title" placeholder over the image) | Poster (square, stacked look) |
| 3 | Date and Time (tile, glyph above label; options: time zone, end time, all-day) | "Set a date..." field with ▾; "Ask your guests instead **Poll your guests →**" |
| 4 | Location (tile; Maps search + optional name) | "Hosted by (optional) host nickname" card with the host's avatar + name |
| 5 | "Hosted by {name}" / "Add a description." tile | Place row: pin glyph + "Place name, address, or link…" |
| 6 | Create Album · Add a Link · Add Playlist | (description further down; theme / effect / settings in a floating toolbar) |
| chrome | × (upper-left) · "Preview" capsule (upper-right) → Preview → Next → invite | "Cancel" · "New Event" · "Done" (sheet toolbar) |

Common order in both: **image and title first, then date/time, then place, then description**. Jolt's fields (brief):
cover (optional) → title → date and time → place (optional, typed text) → note (optional). Apple's order is the one the
guide states field by field (VERIFIED), so it is used; Partiful agrees on date → place → description.

### 2.2 Measured values

| value | element | file | coords (px) | method | precision | level |
|---|---|---|---|---|---|---|
| 67.4 pt high, 359 pt wide, inset 9.8 pt | Partiful title field | PF-AP t 7.250 | y 269–421, x 22–832 | luminance edges at x 40 / 830 ÷ 2.2545 | ±3 % (scale assumed) | SOURCED |
| 59.4 pt high, 361.5 pt wide | Partiful date field ("Set a date...") | PF-AP t 7.250 | y 1310–1444, x 20–835 | same | ±3 % | SOURCED |
| 3 items: Theme / Effect / Settings | Partiful floating create toolbar | PF-AP t 7.250 | y ≈ 1650–1830 | read | — | SOURCED (theme and effect do-not-copy) |
| 1:1, ≥ 1200 × 1200 px | Partiful cover guideline; "some views crop the poster to a square" | PF-H 15525294 | — | text | exact | VERIFIED |
| "time zone", "end time", "all-day" options | Apple date/time picker options | AI-G create-an-event | — | text | exact | VERIFIED |

The Jolt sizes are not taken from these: the form composes Retro's New Album / `groups.create` components (C-29, C-24
cover, C-07, C-12, C-05) — see `design/surfaces/plans.create.md`.

### 2.3 Pickers

- **Date and time:** both references open a calendar (Partiful: "click on the date and time, and a calendar will open
  up. You can also change the timezone by clicking the default timezone at the bottom of the calendar"; Apple: Date and
  Time with time zone / end / all-day). Jolt: the **native** date picker (iOS `DatePicker` graphical + time wheel;
  Android M3 `DatePicker` + `TimePicker`) — PLATFORM, as C-29 requires for pickers. All-day toggle: Apple (VERIFIED).
  Time zone: none to pick — a group has one `time_zone` (docs/API.md §5.3). End time: not proposed (not in the brief).
- **Place:** a plain text field (Partiful's "Place name, address, or link" is a free-text row; Apple's optional
  "name for the location, such as "Danny's House"" is the part we keep). No Maps search, no coordinates, no weather.
- **Cover:** the system photo picker (as `groups.create`); Partiful's square crop rule informs the stored crop.

---

## 3. Plan page layout

### 3.1 Order in the references

| Apple Invites (AI-S 04 / 05, AI-N event-view) | Partiful in-app (PF-S 01) and web (PF-W) |
|---|---|
| background photo full-bleed under the status bar, × and calendar/••• glass buttons | title (display face, centred) |
| title (centred, over the photo's fade) | poster (full content width, own aspect) |
| date + time line, location line (centred) | date (28/500), time (20/400, dimmer) |
| RSVP control Going / Not Going / Maybe | "Hosted by" + host avatars |
| host tile: host avatars, "Hosted by A & B", description | location (pin, name, address) |
| guests tile: "12 Going • 3 Maybe • 4 Not Going" (do-not-copy) + avatar cluster + guest notes | description |
| Weather, Directions (do-not-copy) | Guest List with counts (do-not-copy) + avatar row |
| Shared Album tile: 3 photos + "Add Photos" capsule | Photo Album / Photo Roll + "Upload"; Activity Feed |
| Link / Shared Note / Playlist tiles | floating RSVP (in-app: round "Going" button bottom-right) |

### 3.2 Measured values — Apple Invites event page (AI-S, 3.000 px/pt)

| value | element | file | coords (px) | method | precision | level |
|---|---|---|---|---|---|---|
| cap 29.6 pt → ≈ 42 pt bold, centred | title "Sophie's 25th" | AI-S 04 | 'S' y 1147–1236; ink x 275–1043 | first-glyph rows ÷ 3; ÷ 0.705 (SF cap height) | ±0.5 pt cap | SOURCED |
| cap 12.0 pt → 17 pt | date line, location line | AI-S 04 | 'W' 1324–1359; 'B' 1403–1438 | same | ±0.3 pt | SOURCED |
| 26.3 pt | date → location line pitch | AI-S 04 | 1323 → 1402 | difference | ±0.3 pt | SOURCED |
| 36 pt | location baseline → RSVP control top | AI-S 04 | 1438 → 1546 | difference | ±0.5 pt | SOURCED |
| 404.3 × 80.0 pt, capsule, side margin 17.7 pt | RSVP control container | AI-S 04 | x 53–1266, y 1546–1786 | luminance edges at y 1665 / x 1000 | ±0.5 pt | SOURCED |
| 130 × 73.7 pt, inset ≈ 3.3 pt | selected segment | AI-S 04 | x 63–452, y 1555–1776 | bright run (L > 200) | ±0.5 pt | SOURCED |
| `#FFF9F1` | selected segment fill | AI-S 04 | (90–130, 1620–1640) | median | ±3/255 | SOURCED (theme-tinted; not copied) |
| `#30D158` | selected label + glyph ("Going", filled check circle) | AI-S 04 | label pixels x 180–330, y 1680–1740 (2,206 px with G−R > 60) | median | ±3/255 | SOURCED — equals iOS systemGreen (dark), a PLATFORM colour |
| glyph above label: ✓ filled circle (selected), ⊗ / ? outline circles | segment icons | AI-S 04 | — | read | — | SOURCED |
| 403 pt wide, margin 18.3 pt; 12 pt apart | content tiles (host, guests, album) | AI-S 04 / 05 | x 55–1264; tile 1 bottom 1266 → tile 2 top 1302 | edges | ±0.5 pt | SOURCED |
| 145.7 × 35 pt capsule | "Add Photos" | AI-S 05 | x 441–878, y 2015–2119 | edges | ±0.5 pt | SOURCED (fill `#BDF4FF` is theme-tinted; not copied) |
| 88 pt rows, 8 pt apart, 404 pt wide | Guest List rows | AI-S 07 | host row y 1356–1620; row gap 2099 → 2123; x 53–1266 | edges at x 700 | ±0.5 pt | SOURCED |
| 47.7 pt | avatar in a guest row, inset 16.7 pt | AI-S 07 | y 1416–1559 at x 176; left 103 | edges | ±0.5 pt | SOURCED |
| cap 12 pt → 17 pt | guest name | AI-S 07 | 'A' 1474–1509 | cap ÷ 3 ÷ 0.705 | ±0.3 pt | SOURCED |
| cap 15.3 pt → ≈ 22 pt bold | section header "Host" | AI-S 07 | 'H' 1264–1309 | same | ±0.3 pt | SOURCED |
| sections Host · Going · (Maybe · Not Going) with a note line under a name ("Can't wait to be there!") | guest list structure | AI-S 07, AI-N guest-list | — | read | — | SOURCED (the counts in "12 Going" / "GOING (9)" are do-not-copy) |
| crossed-out name, no RSVP | cancelled event | AI-G cancel | — | text | — | VERIFIED |

### 3.3 Partiful values reused from the 2026-10-15 pass (PF-W, VERIFIED)

Screen margin 16; title auto-fit 25–40 / 700; date 28 / 500; time 20 / 400 at α .5–.6; host and guest avatars 48 with a
4 gap; section header 18 / 700; RSVP choice buttons 96 × 96 circles, emoji 28, label 12 / 600, order **Going · Maybe ·
Can't Go**; durations 100 / 150 / 200 / 300 / 600 ms (`wrapped-tribute-partiful.md` §5.3).

---

## 4. RSVP control

| aspect | Apple Invites | Partiful | Jolt draft (mapping) | level of the Jolt value |
|---|---|---|---|---|
| states | Going · Not Going · Maybe (+ no reply) | Going · Maybe · Can't Go (+ no reply); Maybe can be turned off | **Going · Maybe · Can't go** (+ no answer), Partiful's order (brief) | VERIFIED (PF-W, PF-H) |
| commit | choose, then "Send Reply" (optional note) | web: tap opens name/phone sheet; app: one tap | one tap commits (members are already signed in, so Partiful's verify step and Apple's Send Reply have nothing to collect) | SOURCED (PF-S 01 floating one-tap "Going" button) |
| shape | one capsule container 80 pt, selected segment light-filled | three 96 pt circles (web); one round button (app) | three **C-06 medium capsules** (37 pt) in a row, equal widths, `size.global.pillGap` apart; unselected = outline, selected = primary fill — C-06's own "selected toggle: outline → primary fill" | SOURCED (composition of Retro C-06) |
| colour | selected label systemGreen | event-theme alpha tokens | `color.global.accent` / `.onAccent` (selected), `color.global.textPrimary` 1-pt border (unselected) | SOURCED (Retro) |
| glyphs | ✓ / ⊗ / ? circles above the labels | emoji 👍 / 🤔 / 😢-style sets (host-picked) | none (Retro capsules carry text only; emoji in UI breaks `retro.voice.emoji`) | SOURCED |
| haptic | not observable | not observable | `haptic.global.select` (C-30: a selection among siblings) | PLATFORM |
| after the day | — | "We don't enable people to change their RSVP after the event" | answers lock at the end of the plan's day (`plans.page` past state shows who went, no control) | VERIFIED (PF-H 15525507) |
| leave | Not Going / Maybe = leave | — | choosing Can't go is always allowed; no "are you sure" | VERIFIED (AI-G leave) |

## 5. Guest display

- **Names and faces, never a number.** Apple shows "12 Going • 3 Maybe • 4 Not Going" and "GOING (9)"; Partiful "9514
  Going · …", "+10" overflow discs and the host toolbar "1 Going" — all **do-not-copy** (tenet 2; SPEC_FLAGS T7 already
  chose "first names and avatars only, no count" for the invite page). Partiful itself lets hosts switch the count off
  ("Show Guest Count") — evidence that a guest list works without one.
- **Who sees which list.** Partiful: "only the hosts can see who's been invited to an event. Guests also cannot see who
  RSVP'd "Can't Go." Guests can only see the "Going" and "Maybe" lists." (help 15525438, VERIFIED 2026-10-16); the
  host sees Can't Go replies in the guest tracker (15525415). Apple: guests see who's invited after they reply. Jolt draft: everyone in the group sees **Going**
  and **Maybe**; **Can't go** is shown only to the person who answered it and to the plan's maker (Partiful's split); a
  member who has not answered is in **no** list and is never named (no "hasn't replied" — tenet 5).
- **On the page:** a section per answer (Apple's guest-list sections, without the number): Retro C-20 section label
  ("Going", "Maybe") then a C-23 avatar stack (`size.global.avatarSmall`, overlap `size.global.avatarStackOverlap`) and
  the first names joined by the platform list formatter (iOS `ListFormatter`, Android ICU `ListFormatter`) —
  "Ana, Ben, and Chloe" (PLATFORM). With ≤ 30 members every name fits in at most a few lines, so there is no overflow
  disc ("+N" is a count).
- **Full list** (tap the section): C-14 grouped rows of C-16 people rows (avatar `size.global.avatarPicker` 37, name
  `listTitle`) grouped Going / Maybe — Apple's guest-list sheet structure in Retro components.

## 6. Plan album

| reference | mechanic | level |
|---|---|---|
| Apple Invites | "a dedicated Shared Album within each invite"; guests add photos by hand ("Join Album" → "Add Photos"); the album survives cancel and delete | VERIFIED |
| Partiful | "Upload Photos" at the top of the Activity Feed; "Photo Album" / "Photo Roll" header + "Upload" capsule + grid toggle (PF-S 07, PF-AP t 25.000) | VERIFIED / SOURCED |
| Jolt (brief) | **automatic**: after the plan's day, the group's posts from that day collect into the plan's album | — |

Draft rule: when the plan's local day (group `time_zone`) has ended, every post of the group created during that day is
listed in the plan's album, oldest first; the album appears on the plan page (C-21 dated grid, as `albums.view`) and in
`albums.list` like any album. Nothing is uploaded twice and nobody has to "Join Album". Posts deleted later or hidden by
blocks follow the post (docs/API.md §5.15 rule: "album items also need the post to be visible to you").
No reference collects automatically, so the **day boundary** (midnight vs. a late-night plan running past midnight) is
**BLOCKED** (§9).

## 7. Notifications

| reference | what it sends | level |
|---|---|---|
| Partiful events | Going: 2 h before; Maybe / no answer: "remind them to finalize their RSVP 1 week before"; fixed schedule; host gets a push "for every RSVP"; cancel always notifies; date changes do not | VERIFIED |
| Partiful **Group Reminder** | "a notification when they are added and **24 hours before**" — nothing else | VERIFIED |
| Apple Invites | cancel and delete notify everyone; "notified about changes" (toggle per person, push / email); no documented reminder | VERIFIED |
| Countdown Widget \| Day Counter | "One day until "Anniversary"!", "One week until "Vacation"!" | SOURCED |

Jolt draft (each is one push; per-group mute and quiet hours apply as everywhere — quiet hours "Notifications arrive
silently between these times."):

| when | to whom | evidence | copy key |
|---|---|---|---|
| a plan is made | the other members of the group | Partiful Group Reminder ("when they are added") | `notifications.push.planNew.*` |
| **24 h before the start** (all-day plans: 24 h before the day's start in the group time zone) | members who answered **Going or Maybe** | Partiful Group Reminder ("24 hours before"); "One day until …" wording (CW-DC) | `notifications.push.planTomorrow.*` |
| the date, time or place changes | Going + Maybe | Apple ("notified about changes"); WhatsApp lead (not re-verified) | `notifications.push.planChanged.*` |
| the plan is cancelled | Going + Maybe | Apple and Partiful (cancel always notifies) | `notifications.push.planCanceled.*` |

Proposed copy (English; Retro push voice `retro.voice.push`: title = the context, body = one plain line with a period):

| key | text | origin | pattern / source | level |
|---|---|---|---|---|
| `notifications.push.planNew.title` | {group_name} | new | retro.voice.push (title names the context: "Week %1$d") | SOURCED |
| `notifications.push.planNew.body` | {first_name} made a plan: {plan_title} | new | retro.voice.push ("%1$s commented on your post: …" — sender, verb, colon, content); trigger from Partiful Group Reminder | SOURCED |
| `notifications.push.planTomorrow.title` | {plan_title} | new | retro.voice.push (context = the plan) | SOURCED |
| `notifications.push.planTomorrow.body` | Tomorrow at {time}. / Tomorrow. (all-day) | adapted | CW-DC "One day until "Anniversary"!" with the "!" dropped (`retro.voice.punctuation`: "!" only for greetings and success); "Tomorrow" is the platform formatter's word (§1.3) | SOURCED |
| `notifications.push.planChanged.body` | {plan_title} is now {date_time}. / {plan_title} is now at {place}. | new | retro.voice.push plain statement; content Apple "let guests know if you changed the location" | SOURCED |
| `notifications.push.planCanceled.body` | {first_name} canceled {plan_title}. | adapted | Apple "the event has been canceled" / Partiful "the event was canceled" (US spelling) in retro.voice.push form | SOURCED |
| `notifications.push.channel.plans.name` / `.description` | Plans / When someone makes, changes or cancels a plan, and the day before one you're going to | new | retro.voice.push-channel ("New Posts" / "Recent posts from users you care about") | SOURCED |

**Not sent (tenet 5):** Partiful's "finalize your RSVP" reminder to Maybe / unanswered people; any second reminder
(Partiful's 2-hour one is replaced by the single day-before push); a push to the maker for every answer (Partiful);
"N people are going" summaries; an "album is ready" push (the plan page and `albums.list` show it; T6 noise).

## 8. Editing and cancelling

| aspect | references | Jolt draft |
|---|---|---|
| who can edit | Apple: host + co-hosts; Partiful events: "cohosts are able to cancel or delete the event. If your cohost takes either of these actions, you will be notified." (15525428); Group Reminder: anyone added | the plan's maker and group admins — the same rule Jolt already uses for albums (`albums.view`: "for the album's creator and group admins") |
| edit entry | Apple: ••• → Edit, ✓ / × | page header ••• (C-01 glyph) → native menu "Edit Plan" → the `plans.create` sheet in edit mode (`groups.create` precedent) |
| past plans | Partiful: "You can't change the date and time for events that are in the past" | no edits after the plan's day (title and note stay editable? **BLOCKED** — no evidence) |
| cancel | Apple: crossed-out name, no RSVP, restorable, everyone notified; Partiful: notifies, no un-cancel | menu item "Cancel Plan" in `color.global.destructive` (C-10), native confirm (`retro.voice.confirm`); page shows the title struck through (Apple) and the answer row disappears; "Restore Plan" for maker / admins (Apple) |
| delete | Apple: separate from cancel, permanent | **not proposed** for v1 (cancel covers mistakes; tenet 4 "nothing gets lost") — owner can ask |

## 9. Countdown widget

### 9.1 Measured values

| value | element | file | coords (px) | method | precision | level |
|---|---|---|---|---|---|---|
| 382.3 × 180.3 pt | Apple Invites medium widget on a 440-pt iPhone | AI-S 08 | x 86–1233, y 295–836 | colour-distance edges ÷ 3 | ±0.5 pt | SOURCED (HIG table has no 440-pt row; Jolt uses `widget.home.medium.layout.size`, VERIFIED) |
| 139.5 pt square, inset 20 pt (left / top) | its photo | AI-S 08 | x 145–563, y 355–772 | edges | ±0.5 pt | SOURCED |
| r ≈ 10.9 pt | photo corner | AI-S 08 | top-left, 14 rows | circle fit (r 32.8 px; continuous corner, so approximate) | ±1 pt | SOURCED |
| 18.7 pt | photo → text column | AI-S 08 | 563 → 619 | difference | ±0.5 pt | SOURCED |
| cap 13.7 pt → ≈ 19–20 pt, white ≈ 62 % | event title "Weekend Retreat" | AI-S 08 | 'W' 551–592; colour #D5D5C6 over #919292 | cap ÷ 0.705; α = (213−145)/(255−145) | ±0.5 pt; ±0.05 | SOURCED |
| cap 16.7 pt → ≈ 24 pt bold, white | countdown "In 9 Days" | AI-S 08 | 'I' 623–673 | same | ±0.5 pt | SOURCED |
| 27 pt | title baseline → countdown baseline | AI-S 08 | 592 → 673 | difference | ±0.5 pt | SOURCED |
| centred vertically | text block (pill top 450 … descender 687; centre 568 vs widget centre 565) | AI-S 08 | — | midpoints | ±1 pt | SOURCED |
| "In {n} Days" (Title Case), days only | countdown wording | AI-S 08 | — | read | — | SOURCED |
| number 0.36 of the widget height | "9" on a small photo widget | CW-DU 02 | widget y 1224–1596 (372 px); "9" y 1345–1480 | ratio | ±0.01 | SOURCED (big-number style; not proposed) |
| title above, "{n} DAYS" below, full-bleed photo | Widgetsmith medium | WS | — | read | — | SOURCED |

### 9.2 Locket's widget conventions (`design/research/locket.md` §1)

Full-bleed photo, system corner (`ContainerRelativeShape`), tap opens the app; do-not-copy: count badge ("9"), streak
pill, yellow rings. Jolt's existing widget anatomy (`widget.home.small`: Retro Glance — full-bleed photo, scrim, a
bottom-trailing text stack) is the base for the countdown widget, so it reads as the same app.

### 9.3 Jolt draft

- **Content:** the next plan (Apple: "your next event"; default across all the person's groups; one group can be picked
  in the widget's configuration — Apple's "Edit Widget" to change the featured event).
- **Line 1:** the plan's title; **line 2:** how far away it is, in days, from the platform relative formatter at day
  granularity, sentence-case standalone: "In 3 days", "Tomorrow", and the same day's word (§12 item 2). Apple's
  "In 9 Days" is the mechanic; Retro's sentence case (`retro.voice.sentence-case`) and the platform formatter give the
  casing.
- **Never** hours, minutes or seconds; no ticking (T4). The entry changes once a day at local midnight (WidgetKit
  timeline entry at midnight; Android Glance update at midnight) — nothing animates.
- **Background:** the plan's cover; without one, the group's newest photo (as `widget.home.small`); without photos,
  `color.global.backgroundDeep` (Retro widget state background).
- Sizes: small and medium (`widget.home.small.layout.size`, `widget.home.medium.layout.size`, VERIFIED HIG); one layout
  at every size (Retro's resizable widget, MERGE RC-11). Apple's split layout (square photo + text column) is recorded in
  §9.1 as the alternative if the owner prefers it.

## 10. Do-not-copy

- **Counts of any kind:** "12 Going • 3 Maybe • 4 Not Going", "GOING (9)", "7 Going", "+ 2 additional guests", "{n}
  Going" host toolbar, "+10" overflow discs, "Grace +32 are Interested", reaction chips with numbers, the widget's "👤 15"
  pill, "Ben is Going 👍" social-proof stickers.
- **Urgency:** hours / minutes / seconds countdowns (CW-DU 04, CW-DC 01), "finalize your RSVP" reminders, a second
  reminder 2 hours before, "!!!" notification copy, deadline language, "spots left" / waitlists / capacity.
- **+1s and ticketing:** Apple "Additional Guests", "Specify Number of Kids"; Partiful "Going with guest", ticket tiers,
  "Collect Payments from Guests", promo codes, QR check-in, "Request Money".
- **Public discovery:** "Explore Curated Events Near You", "Trending in LA", "Interested", Follow, organisation pages.
- **Approval / gating:** "Approve Guests", "Guest Approval", waitlist, "Restricted Access" (a group plan is for the group).
- **Location services:** Maps search, directions, weather (the app never collects location).
- **Activity feed of answers:** "Joy Tao rsvp'd Going 👍 12h" (performative log), host push "for every RSVP".
- **Branding and art:** Partiful logo, PartifulGrotesk / Lausanne, animated themes and effects, emoji RSVP sets,
  "Poll your guests" (date polls are a separate feature); Apple's icon, SF Pro Rounded titles over photos, Image
  Playground backgrounds, Apple Music playlists, liquid-glass event tiles; countdown apps' emoji titles and gradient
  number art.
- **Drafts / preview step** (Apple "Save Event", "Preview"): not needed for a private group plan.

## 11. Mapping onto Retro (existing Jolt tokens and components)

| plan element | reference mechanic | Jolt component / tokens |
|---|---|---|
| create sheet | Apple × / Preview; Partiful Cancel / New Event / Done | C-29 page sheet, sheet header (`sheetTitle`) + C-11 close; primary C-05 at the bottom (`groups.create` precedent) |
| cover | Apple background / Partiful poster | `groups.screen.size.coverWidth` × `.coverHeight`, `radius.global.thumbnail`, `groups.screen.shadow.cover`; C-07 "Add cover image" |
| title field | Apple "Event Title" / Partiful title | C-12 (`size.global.fieldHeight` 52, `radius.global.field` 19) |
| date / time / place / note rows | Apple tiles; Partiful rows | C-14 grouped rows (`radius.global.groupedRow` 12) with leading glyphs `icon.global.calendar`, `icon.global.location` (glyph only — no location data), `icon.global.edit`; native pickers |
| plan page header | Apple × + ••• | C-02 back + C-01 trailing `icon.global.more` |
| plan page cover + title + meta | Apple centred title + date/location lines | album-detail skeleton (`albums.view` / `groups.screen`): cover, title `font.global.display` `displayMedium`, meta lines `listSubtitle` `color.global.textSecondary` |
| RSVP | Apple segmented / Partiful circles | 3 × C-06 (outline ↔ primary), `size.global.pillHeight`, `size.global.pillGap`, `haptic.global.select` |
| maker + note | Apple host tile | C-16 people row (avatar `size.global.avatarPicker`) + note `body` |
| guests | Apple guest sections | C-20 label + C-23 stack + list-formatted names; full list C-14 + C-16 |
| album | Apple Shared Album tile / Partiful Photo Album | C-20 dated header + C-21 3-column grid (`size.global.stripGap`, `radius.global.photo`) |
| cancelled | Apple crossed-out name | title with strikethrough (platform text attribute) + line `listSubtitle` |
| widget | Apple Invites widget + Retro Glance anatomy | `widget.home.small.layout.size` / `.medium`, `layout.global.photoScrim`, `color.global.textOnMedia`, `font.global.display` `displaySmall` (24) for the countdown line — Apple's countdown line is ≈ 24 pt (§9.1) and Retro sets its photo-card titles in displaySmall 24 (`groups.screen` feed cards) |
| group screen entry | — | one C-14 row on `groups.screen` (as the birthday request row, item 6) for the next plan; "+" in the group's menu |

## 12. BLOCKED (no evidence; never ships until resolved)

1. **Plan-day boundary for the album** — midnight in the group time zone vs. a cut-off after midnight for late plans.
   No reference collects automatically. Smallest evidence: the owner's decision, or an app that auto-collects by event
   (e.g. Google Photos event albums) captured on a device.
2. **The "today" word on the widget** — the platform formatter's output for 0 days is not printed in Apple's or
   Android's docs; pin it with a snapshot test of `RelativeDateTimeFormatter(.named)` / ICU `AbsoluteUnit.DAY,
   Direction.THIS` in en-US (expected but unverified: "today").
3. **Answer-change lock time** — Partiful locks after the event; whether Jolt locks at the end of the day or at the start
   time is not evidenced.
4. **Editing a past plan's title / note** — no reference.
5. **Retro press / selected motion of a capsule toggle** — C-06 "Gap for a captured toggle" (no Retro capture of a
   toggling capsule); the crossfade `duration.global.crossfade` is the component default.
6. **Plan row placement on `groups.screen`** relative to the birthday row (both are C-14 rows; order not evidenced).
7. **Widget empty-state line** — Retro's widget voice has "No media. Tap to reload"; no reference widget shows "no
   upcoming events" (Apple's empty widget not captured). Smallest capture: an Apple Invites widget with no upcoming event.
8. **Notification for the maker when nobody has answered** — none proposed; no evidence either way.
9. **Countdown for plans more than ~1 year away** — the formatter keeps days ("In 400 days"); Apple shows "In 9 Days"
   only. No evidence for a cap.

## 13. Tenet risks

| tenet | risk | handled by |
|---|---|---|
| 2 No counts | guest numbers, "N days" being read as a score | names only; the day count is a date distance, not a social metric (Apple, Widgetsmith) |
| 5 Invitations, never obligations | reminders to people who did not answer; a visible "hasn't replied" list; countdown urgency | one day-before push to Going / Maybe only; no unanswered list; days only, no seconds (T4) |
| 5 | Can't go shown to everyone reads as a judgement | Can't go visible only to the person and the maker (Partiful) |
| 3 The group, not the individual | the maker as "host" with a crown badge (Partiful) | "Made by {name}" line, no badge; admins can edit too |
| 4 Nothing gets lost | deleting a plan loses its album | no delete in v1; cancel keeps the plan and its album |
| 1 / privacy | place text may contain a home address | plans are visible only to group members (RLS); no link preview or public page (Apple's "Remove Background Preview" privacy setting is moot) |
