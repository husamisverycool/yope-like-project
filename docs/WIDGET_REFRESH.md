# Widget refresh

How a new photo (or a deletion, or a same-moment collage) reaches each member's home-screen
widget, what the worker sends in each case, and the limits. The platform facts and their sources
are in [`PLATFORM_CONSTRAINTS.md`](PLATFORM_CONSTRAINTS.md) §1 (iOS) and §4 (Android); this file
is the strategy built on them (§1.6 "Recommended path"). Code: `backend/worker/src/jobs/widget.ts`,
`src/jobs/push.ts` (`push.new_post`), `src/push/payloads.ts`, `src/push/throttle.ts`.

## Reference expectation

Locket's help center: "When a friend sends you a photo on Locket, it will appear on your Home
Screen, but there may be a slight delay of up to 5 minutes. This delay helps conserve your phone's
battery." (help.locket.com, article 5859739, updated 2026-05-05). That is the expectation this
design aims for: usually seconds when the member gets a notification, **up to about 5 minutes**
otherwise, never a promise of "instant" (PLATFORM_CONSTRAINTS summary table: neither OS guarantees
it). Copy must not claim instant delivery.

## What triggers a refresh

| event | job(s) | sent by |
|---|---|---|
| a member posts a photo (`create_post`) | `push.new_post` + `widget.refresh` (+ `media.renditions`) | SQL, same transaction |
| a photo is deleted anywhere (`delete_media`, `delete_post`, account deletion) | `widget.refresh` (+ `collage.recompose`, `storage.delete` …) | deletion triggers (0004) |
| the daily window closes and the collage is composed / recomposed | `widget.refresh` | `collage.compose`, `collage.recompose` |
| a device was throttled | a follow-up `widget.refresh` at the end of its throttle window | `widget.refresh` itself |

`widget.refresh {group_id}` is deduplicated per group (one queued refresh per group; a newer
enqueue moves it earlier).

## What each member's widget should show

Per member, not per group: the **newest post they may see** (blocks hide each person's photos
from the other, docs/API.md §5.6), or the group's newest **ready collage** if it is newer
(SURFACES `widget.home.*`: "newest photo; after a daily invitation, the collage"). The widget
image is the `widget` rendition (`u/<owner>/<media>/r/widget.jpg`, covering the largest iPhone
widget at @3x: 1092×1146 px, see `src/media/renditions.ts`) or the collage's `widget.jpg`, sent as a
1-hour signed URL (docs/API.md §7: "Use 1 h for the app and widgets").

## iOS

| member's situation | what the worker sends | limit applied by the worker | what the device does |
|---|---|---|---|
| gets alerts for the group (not muted; also during quiet hours) and a **new photo** arrives | `push.new_post`: alert with `mutable-content: 1` and the nested `widget` object (below); quiet hours → `interruption-level: passive`, no sound, priority 5 | none (one alert per post; collapse id `post:<id>`) | Notification Service Extension downloads the rendition into the App Group (≤ 30 s), attaches it, calls `reloadTimelines` (budgeted, best effort: PLATFORM_CONSTRAINTS §1.2) |
| **no alert carries this state** (muted group, a deletion, a collage) | background push: `apns-push-type: background`, priority 5, `{"aps":{"content-available":1}}` + the flat widget keys (below), expiry 1 h, collapse id `widget:<group>` | **≤ 2 per device per rolling hour** ([BG] "don't try to send more than two or three per hour"); follow-up refresh when allowed; skipped when the device already got this state (the worker remembers per device what each alert or background push carried) or while the item's new-post alert is still queued or being sent | the app is woken (not if force-quit; the system may hold or drop it), downloads the rendition, reloads widget timelines |
| app in the foreground | — | — | the app reloads every widget kind on each foreground (not budgeted, PLATFORM_CONSTRAINTS §1.1) |
| nothing arrives | — | — | the timeline's own `.after(now + 15…60 min)` reload (40–70 reloads/day budget) |

No WidgetKit push (iOS 26 `WidgetPushHandler`): it only reloads timelines, and the widget extension
would then have to fetch the photo with the person's session, which it does not hold. The photo
reaches the App Group through the alert's Notification Service Extension, background pushes and the
app itself (migration 0030 removed `devices.widget_push_token`; PLATFORM_CONSTRAINTS §1.6).

### iOS payloads

New-photo alert (to a member who gets alerts):

```json
{
  "aps": {
    "alert": { "title": "<notifications.push.newPost.title>", "body": "<notifications.push.newPost.body>" },
    "sound": "default", "interruption-level": "active",
    "mutable-content": 1, "category": "new_post", "thread-id": "<group_id>"
  },
  "type": "new_post", "group_id": "<group_id>", "post_id": "<post_id>",
  "widget": {
    "group_id": "<group_id>", "group_name": "<name>", "kind": "photo", "post_id": "<post_id>",
    "rendition_url": "https://…/storage/v1/object/sign/media/u/…/r/widget.jpg?token=…",
    "sender": { "display_name": "<display name>", "avatar_url": "https://…signed…" },
    "caption": "<caption>", "posted_at": "2026-10-15T12:00:00.000Z"
  }
}
```

Background push (flat keys, `WidgetPushPayload` silent shape):

```json
{
  "aps": { "content-available": 1 },
  "type": "widget", "group_id": "…", "group_name": "…", "kind": "photo" | "collage",
  "post_id": "…" | "collage_id": "…", "rendition_url": "https://…",
  "sender_name": "…", "sender_avatar_url": "https://…", "caption": "…", "posted_at": "…"
}
```


## Android

| member's situation | what the worker sends | priority | what the device does |
|---|---|---|---|
| gets alerts and a new photo arrives | `push.new_post`: data message `type: new_post` (title, body, ids) | **high** (a visible notification results) | `AlertNotifier` posts the notification (silently in quiet hours, decided on the device) |
| every member, every event (including muted members, deletions, collages) | `widget.refresh`: data message `type: widget` with the flat widget keys above, TTL 1 h, `collapse_key: widget:<group>` | **normal** (no notification results; FCM deprioritizes high-priority messages without one, [FCMP]) | `WidgetUpdateScheduler` enqueues an expedited WorkManager job that downloads the rendition and updates the Glance widget |
| nothing arrives | — | — | `updatePeriodMillis` (≥ 30 min) / periodic WorkManager safety net |

When a member gets the alert, its high-priority message wakes the device, and the normal-priority
widget message sent at the same time is delivered while it is awake. A muted member's widget
message waits for a maintenance window when the device is in Doze ("delivery may be delayed").

## The app itself

Pushes alone left two gaps: a widget added (or a group joined) after the last push showed "No photos yet" although the
group had photos, and a person without a push token (notifications never allowed, no Firebase) never got an update.
So the apps write the widgets from their own data too, with the same downloads as the pushes:

| when | iOS (`AppData/Glue/WidgetContentSync.swift`, `SessionCoordinator`) | Android (`WidgetPrefetch`) |
|---|---|---|
| sign-in, a group joined or left (the group list reloads) | every group | — (the widget picker fills a widget when it is placed) |
| each return to the foreground | every group | every group a placed widget shows (`refreshPlaced`, MainActivity start) |
| a group's feed loads its first page | that group | — |

Per group: the newest photo the person may see (RLS applies blocks) and the newest ready collage; nothing is
downloaded for an item the widget store already shows. When the shown photo is gone (deleted or hidden) the older
newest one replaces it, and a group with no photo left shows the widget's empty state. iOS reloads the timelines only
when a snapshot changed; reloads from the foreground app are not budgeted (PLATFORM_CONSTRAINTS §1.1).

## Limits (what can make a widget late or stale)

- **Budgets.** iOS widget reloads (40–70/day per widget) and background pushes (throttled, not
  guaranteed, dropped for force-quit apps) are at the system's discretion. Android Doze defers
  normal-priority messages and WorkManager jobs.
- **Muted groups on iOS** depend on background pushes: at most 2 per device per hour from the
  worker, fewer if the system throttles. In a busy muted group, the widget can lag behind by up to
  an hour until the app is opened or the timeline reloads.
- **Notification Service Extension reloads are budgeted** and their effect is UNCONFIRMED
  (PLATFORM_CONSTRAINTS §1.2); its real value is the downloaded rendition in the App Group.
- **Nothing left to show.** When every photo of a group is deleted, the background-push and
  Android widget messages carry nothing (they require a `rendition_url`, shared contract): the app
  clears the widget when it is running (the realtime deletion) or next opened ("The app itself").
- **An older photo after a deletion.** The stores keep the newest item, so the older photo sent
  after the shown one was deleted would be refused: the iOS app replaces it when it runs; Android
  drops a shown photo the server no longer returns when the widget message arrives
  (`ShownWidgetPhoto`, one lookup inside FCM's handler window) and when the app starts.
- **Throttle state is in memory** in the worker (one instance, docs/OWNER_SETUP.md §7). A restart
  forgets it, which can let one extra push per device through; running several worker instances
  multiplies the per-device allowance.
- **FCM collapsible messages** are limited to a burst of 20 per app per device, refilled one every
  3 minutes; widget messages use a per-group collapse key, so only the newest undelivered one is
  kept.
- **Signed URLs** in pushes are valid for 1 hour; a push delivered later than that cannot download
  the rendition (the widget then fetches through the app's session).
- **Blocks** are applied per member (each gets the newest photo they may see); collages are
  rendered once per group (docs/API.md §12.13).
