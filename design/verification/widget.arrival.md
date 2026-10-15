# Verification — `widget.arrival` (iOS)

How a new photo reaches the widget — NSE + App Group store + timeline.

Checklist written from the spec (`design/surfaces/widget.arrival.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>.png`, then `tools/sidebyside.py` makes `design/verification/widget.arrival.png` next to the reference image(s) below.

Reference image(s): `references/auto/locket/frames/locket-tt-7168613044728155438-15.133s-widget-placeholder-just-added.jpg`, `references/auto/locket/frames/locket-tt-7168613044728155438-15.167s-widget-photo-arrived.jpg`

Snapshots (CI): `widget.arrival-before.png`, `widget.arrival-after.png`

**Summary: 2 matched · 0 approximated · 1 not matched (BLOCKED or not buildable).**

## Values

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `widget.arrival.duration.transition` | 0 ms (SOURCED) | 0 ms | identity transitions; new entry replaces the old |
| matched | `widget.arrival.duration.expectedDelay` | 300000 ms (SOURCED) | QA bound 300 s | timeline .after(15–60 min jitter) safety net; NSE reloads both widget kinds |
| not matched | `widget.arrival.help.delay` | “When someone in your group sends a photo, it will appear on your Home Screen, but there may be a slight delay of up to a few minutes. This delay helps conserve your phone’s battery.” (SOURCED) | help text | not shown by this pass (onboarding.widget / settings own help) |

## Notes

- The app's background-push path (`WidgetReloader.reloadGroupWidgets`, AppServices) reloads only the Home Screen kind; the Lock Screen kind updates on foreground / its timeline (reported).
