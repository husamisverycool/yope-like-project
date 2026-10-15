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
| device has a **WidgetKit push token** (iOS 26+), any event | `apns-push-type: widgets`, topic `<bundle>.push-type.widgets`, body `{"aps":{"content-changed":true}}`, expiry 1 h | **≤ 1 per device per 5 minutes**; throttled devices get a follow-up refresh when the window reopens; not repeated for an unchanged state | WidgetKit reloads all push-enabled widgets on the device (budgeted, opportunistic, separate budget from background pushes); the timeline provider reads the App Group cache or fetches |
| no WidgetKit token, and **no alert carried this state** (muted group, deletion, collage) | background push: `apns-push-type: background`, priority 5, `{"aps":{"content-available":1}}` + the flat widget keys (below), expiry 1 h, collapse id `widget:<group>` | **≤ 2 per device per rolling hour** ([BG] "don't try to send more than two or three per hour"); follow-up refresh when allowed; skipped when the device already got this state | the app is woken (not if force-quit; the system may hold or drop it), downloads the rendition, reloads widget timelines |
| app in the foreground | — | — | the app reloads every widget kind on each foreground (not budgeted, PLATFORM_CONSTRAINTS §1.1) |
| nothing arrives | — | — | the timeline's own `.after(now + 15…60 min)` reload (40–70 reloads/day budget) |

Why 5 minutes: WidgetKit asks servers to throttle widget pushes because one push reloads every
push-enabled widget on the device (WWDC25, [WKP]), timeline entries should be "at least about 5
minutes apart" [KWU], and Locket documents up to 5 minutes. Apple publishes no number.

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

WidgetKit push: `{"aps":{"content-changed":true}}` (no data; the widget fetches).

## Android

| member's situation | what the worker sends | priority | what the device does |
|---|---|---|---|
| gets alerts and a new photo arrives | `push.new_post`: data message `type: new_post` (title, body, ids) | **high** (a visible notification results) | `AlertNotifier` posts the notification (silently in quiet hours, decided on the device) |
| every member, every event (including muted members, deletions, collages) | `widget.refresh`: data message `type: widget` with the flat widget keys above, TTL 1 h, `collapse_key: widget:<group>` | **normal** (no notification results; FCM deprioritizes high-priority messages without one, [FCMP]) | `WidgetUpdateScheduler` enqueues an expedited WorkManager job that downloads the rendition and updates the Glance widget |
| nothing arrives | — | — | `updatePeriodMillis` (≥ 30 min) / periodic WorkManager safety net |

When a member gets the alert, its high-priority message wakes the device, and the normal-priority
widget message sent at the same time is delivered while it is awake. A muted member's widget
message waits for a maintenance window when the device is in Doze ("delivery may be delayed").

## Limits (what can make a widget late or stale)

- **Budgets.** iOS widget reloads (40–70/day per widget), WidgetKit pushes (budget unpublished)
  and background pushes (throttled, not guaranteed, dropped for force-quit apps) are all at the
  system's discretion. Android Doze defers normal-priority messages and WorkManager jobs.
- **Muted groups on iOS < 26** depend on background pushes: at most 2 per device per hour from the
  worker, fewer if the system throttles. In a busy muted group, the widget can lag behind by up to
  an hour until the app is opened or the timeline reloads.
- **Notification Service Extension reloads are budgeted** and their effect is UNCONFIRMED
  (PLATFORM_CONSTRAINTS §1.2); its real value is the downloaded rendition in the App Group.
- **Nothing left to show.** When every photo of a group is deleted, only the WidgetKit push can
  tell an iOS widget to reload into its empty state; the background-push and Android widget
  messages require a `rendition_url` (shared contract), so those devices clear on their next
  timeline / periodic update.
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
