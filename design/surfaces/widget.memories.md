# widget.memories — Your Memories: your own photo from this day in an earlier year (home screen, every size)

**Mechanics and visual reference: Retro** — "See the newest posts from friends or **time hop back to your own
memories** with our new widgets" (App Store, https://apps.apple.com/us/app/id6443709020); its "Your Memories" widget
("See memories from your profile", `widget_title_memories` / `widget_description_memories`) has the same Glance layout as
its other widgets (`references/auto/retro/apk/widget_preview_memories.webp`: 'livs / Seoul', name over place). Filled with
this product's own memory rule — the same month and day in an earlier year (`onthisday`) — limited to the person's own
photos: ones they posted or tagged themselves in. Owner decision 34; research #3. **Free** (Retro's memories widget is
free; Retro Premium's perks do not include it).

**Honest by construction.** A day without a memory shows "No photos found for this day" — never another photo, never a
"memory" that is not one; a day the app has not looked up yet shows the loading state (it does not claim there is none).
Hidden memories (`hide_memory`, migration 0038) are left out by the server.

## References

| image / source | what it verifies |
|---|---|
| https://apps.apple.com/us/app/id6443709020 | Retro's widgets "time hop back to your own memories" |
| `references/auto/retro/apk/widget_preview_memories.webp` | anatomy |
| `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `widget_title_memories`, `home_rewind_upsell_feed_card_title`, `rewind_home_empty_state_message` |
| `design/surfaces/onthisday.md` | the memory rule (month and day in earlier years) |

## Structure

Exactly `widget.home.small` at every size: the memory's photo under `layout.global.photoScrim`; the stack — the poster's
first name over the group, as Retro's memories widget prints name over place. Styles: `widget.styles` (the Date style
prints the memory's date, 'Jul 22, 2022').

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| photo, scrim, stack | `widget.memories.layout.content`, as `widget.home.small` | a11y `widget.memories.a11y.photo` ("Your memory from {date} in {group}") | the newest such photo of the day |
| tap | `widget.memories.layout.content` (tap) | — | the memory in the photo viewer (`app://post?group=<id>&post=<id>`); empty: the app |
| configuration | iOS AppIntentConfiguration with the style only; Android: the style step | `widget.styles.configuration.*` | — |
| gallery | — | `widget.memories.gallery.name` ("Your Memories"), `.gallery.description` | same families as the group widget |

## States

| state | design | copy |
|---|---|---|
| loading (the day not looked up yet) | `color.global.backgroundDeep`, no content | — |
| empty (no memory today) | state column (`widget.home.small`) | `widget.memories.empty.none` |
| signed out | state column | `widget.home.small.empty.signedOut` |
| error / offline | the stored days stay | — |
| permission-denied | n/a | — |

## Motion

None; the memory changes at local midnight (a new timeline entry / a re-render), instantly.

## Haptics

None.

## Accessibility

One element with the button trait: `widget.memories.a11y.photo` or the state line.

## Data & actions

- `my_memories(p_from, p_days, p_time_zone)` (migration 0036; 0038 leaves hidden ones out): today and the next 6 days in
  the device's zone, written by the app to the widget store when a memories widget is placed (iOS: its timeline records
  `watchMemories`; Android: a placed `MemoriesWidget`), on every return to the foreground. Renditions:
  `media.widget_path`.
- iOS: one timeline entry per stored day at local midnight, then `.atEnd`. Android: a WorkManager job at the next local
  midnight re-renders the placed memories widgets (as `widget.countdown`), and the hourly provider update as a backstop.
- A deleted photo leaves the stored days at once (the store's deletion path) and on the next look-up.

## Platform notes

iOS `MemoriesWidget` (kind `MemoriesWidget`); Android `MemoriesWidget` (provider `memories_widget_info.xml`).

## Do-not-copy

Timehop's "N YEARS AGO" banners (`retro.voice.rewind` do-not-copy); Retro's "Most recent / All memories" switch is not
offered (our memories are the day's, not a shuffle of every photo).

## Gaps

| item | status | capture |
|---|---|---|
| Retro's memories widget on a device | preview art only | one home-screen screenshot |
