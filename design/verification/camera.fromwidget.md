# Verification — `camera.fromwidget` (iOS, Pass 4 — Retro redesign)

Widget tap → camera with the group preselected — `ios/Widgets/Sources/GroupWidgetEntry.swift` (`tapURL`), `ios/App/Sources/Features/Capture/SendTo/SendToModel.swift` (preselection).

Checklist written from the spec (`design/surfaces/camera.fromwidget.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>-<light|dark>.png` (every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/camera.fromwidget.png` next to the reference image(s) below.

Reference image(s): `references/auto/locket/store/locket-store-07.png`, `references/auto/locket/play/locket-play-05.png`

Snapshots (CI, `ios/build/snapshots/capture/`): `camera.fromwidget-preselected-light.png`, `camera.fromwidget-preselected-dark.png`

**Summary: 4 matched · 0 approximated · 0 not matched (BLOCKED or not buildable).**

## Route

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.fromwidget.layout.target` | link: app://camera?group=<group_id>; ios: widgetURL on the whole widget; android: PendingIntent ACTION_VIEW on the widget root; opens: camera.capture, group preselected in camera.sendto (SOURCED) | `widgetURL(app://camera?group=<id>)` on the whole widget | `GroupPhotoEntry.tapURL` via `DeepLinkParser.url(for: .camera(groupID:))`; Home and Lock Screen kinds |
| matched | `camera.capture.title` | “Week {number}” (SOURCED) | opens directly on camera.capture | shell opens the camera tab for `.camera(groupID:, nil)` |
| matched | `camera.sendto.groupsLabel` | “Groups” (SOURCED) | the widget's group selected in send-to; a left / unknown group: nothing preselected | `SendToModel.apply` (unit-tested) |
| matched | `widget.home.small.a11y.photo` | “{name}'s photo in {group}” (SOURCED) | the widget's label announces it | one element, button trait |

## Notes

- Signed-out tap: the app opens on sign-in (shell); the widget shows `widget.home.small.empty.signedOut`.
