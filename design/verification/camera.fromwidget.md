# Verification — `camera.fromwidget` (iOS)

Widget tap → camera with the widget's group preselected — `GroupWidgetEntry.tapURL`, `CameraScreen`, `SendToModel` preselection.

Checklist written from the spec (`design/surfaces/camera.fromwidget.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>.png`, then `tools/sidebyside.py` makes `design/verification/camera.fromwidget.png` next to the reference image(s) below.

Reference image(s): `references/auto/locket/store/locket-store-07.png`

Snapshots (CI): `camera.fromwidget-preselected.png`

**Summary: 1 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Route

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.fromwidget.layout.target` | link: app://camera?group=<group_id>; ios: widgetURL on the whole widget; android: PendingIntent ACTION_VIEW on the widget root; opens: camera.capture, group preselected in camera.sendto (SOURCED) | widgetURL app://camera?group=<id> on the whole widget | `.widgetURL(entry.tapURL)` on both widget kinds; Live Activity uses the daily link |

## Notes

- Unreadable / missing id → nothing preselected → send-to's no-context default (all groups); a left group → nothing preselected (send hidden).
- Signed-out: links wait in `AppRouter.pendingLink` until the account flow sets ready (shell).
