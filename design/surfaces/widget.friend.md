# widget.friend — Friend Updates: one person's newest photo (home screen, every size)

**Mechanics: Locket** — "'Crush' or 'Best Friend' picture widget… photos only from that person"
(https://apps.apple.com/us/app/id1600525061); its gallery card "Best Friend" / "Pick one friend"
(`references/auto/locket/frames/locket-tt-7532209311150329102-14.500s-gallery-best-friend-widget.jpg`).
**Visual reference: Retro's Friend Updates widget** — the same Glance layout as its Albums widget (full-bleed photo,
white name-over-place stack bottom-trailing; `references/auto/retro/apk/widget_preview_friends.webp`), and its picker
"See photos from…" (`app_widget_config_screen_title_friend_picker`). Owner decision 34 ("more widgets"; research #3).
**Free** — Locket offers the one-friend widget to everyone (Locket Gold's perks, MB-2, do not include it) and Retro's
Friend Updates widget is free; the directive's premium perk is "extra widget styles" (`widget.styles`), which this widget
takes like the others.

What "that person's photos" means here: photos the person **posted**, or photos they **tagged themselves in** ("I'm in
this", `tagging`) — never found by face (directive: no face recognition). Only groups the viewer and the person both
are in, and nothing across a block in either direction, as walls (`newest_photos_of`, migration 0036).

## References

| image / source | what it verifies |
|---|---|
| `references/auto/locket/frames/locket-tt-7532209311150329102-14.500s-gallery-best-friend-widget.jpg`, `…15.500s-gallery-crush-widget.jpg` | one-person widget, chosen in its configuration |
| https://apps.apple.com/us/app/id1600525061 | "photos only from that person" |
| `references/auto/retro/apk/widget_preview_friends.webp` | anatomy (name over place) |
| `references/auto/retro/apk/retro-android-2026.10.1150-strings.txt` | `widget_title_friends`, `widget_description_friends`, `app_widget_config_screen_title_friend_picker`, `app_widget_empty_message` |

## Structure

Exactly `widget.home.small` (and `.medium`, `.large`, `.xl`; Android `widget.android` at every size): the photo
aspect-filling the widget under `layout.global.photoScrim`, the stack bottom-trailing — line 1 the **poster's** first
name (for a photo the friend tagged themselves in, the person who took it), line 2 the group. Styles: `widget.styles`.

## Elements

| element | tokens | copy | behaviour |
|---|---|---|---|
| photo, scrim, stack | as `widget.home.small`; `widget.friend.layout.content` | a11y `widget.home.small.a11y.photo` | — |
| tap | `camera.fromwidget.layout.target` | — | `camera.capture` with the photo's group preselected; no photo yet: the camera |
| configuration (iOS) | AppIntentConfiguration | title `widget.friend.configuration.title` ("See photos from…"), parameter `widget.friend.configuration.friend`, style `widget.styles.configuration.style` | people from `widget_people` (everyone who shares a group, minus blocks), no default |
| configure activity (Android) | as `widget.android` (C-29 title, C-16 rows: avatar `size.global.avatarPicker` + name `listTitle`, C-32 hairlines) | title `widget.friend.configuration.title`; empty `widget.friend.configure.empty`; then `widget.styles.configuration.title` | tap a person → the style step → done |
| gallery | — | `widget.friend.gallery.name` ("Friend Updates"), `.gallery.description` | same families as the group widget |

## States

| state | design | copy |
|---|---|---|
| loading (just added; the app has not looked the friend up yet) | `color.global.backgroundDeep`, no content | — |
| empty (looked up; nothing of theirs the viewer may see) | state column (`widget.home.small`) | `widget.friend.empty.noPhotos` |
| not set up (no friend chosen, or no shared group any more / a block) | state column | `widget.friend.empty.setUp` |
| signed out | state column | `widget.home.small.empty.signedOut` |
| error / offline | the last photo stays (HIG) | — |
| permission-denied | n/a | — |

## Motion

Instant swap (`widget.arrival.duration.transition`).

## Haptics

None; Android configure rows `haptic.global.tap`.

## Accessibility

One element with the button trait; label `widget.home.small.a11y.photo` ("{name}'s photo in {group}") or the state
line. Contrast as `widget.home.small`.

## Data & actions

- The widget's timeline records the friend it follows in the App Group (iOS `WidgetStore.watch`; Android: the widget's
  binding). Pushes: every widget push names its poster (`sender_id`); the Notification Service Extension, background
  pushes and the Android widget worker copy a followed poster's photo into the friend's slot when newer.
- The app (`WidgetContentSync.syncFriends`, Android `WidgetPrefetch.refreshPlaced`) asks `newest_photos_of` for each
  followed friend on every return to the foreground: this is how self-tags arrive (tagging sends no push) and how a
  deleted, blocked or left photo leaves. A deleted photo also leaves at once (realtime deletion → the store removes it).
- Picker: `widget_people`, written to the App Group (`people.json`) whenever the app loads its groups.

## Platform notes

iOS `FriendPhotoWidget` (kind `FriendPhotoWidget`, systemSmall … systemExtraLarge); Android `FriendPhotoWidget` (Glance,
provider `friend_photo_widget_info.xml`, home screen and keyguard as `widget.android`).

## Do-not-copy

Locket's "Crush" naming, crown / heart art, streak frames; Retro's "Keyholders" picker row and "Post to see" lock.

## Gaps

| item | status | capture |
|---|---|---|
| Retro's friend widget with one friend chosen, on a device | preview art only (mdpi) | one home-screen screenshot |
