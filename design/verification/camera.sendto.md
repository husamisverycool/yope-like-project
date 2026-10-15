# Verification — `camera.sendto` (iOS)

Choose groups, optional caption / voice note, send — `ios/App/Sources/Features/Capture/SendTo/`.

Checklist written from the spec (`design/surfaces/camera.sendto.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>.png`, then `tools/sidebyside.py` makes `design/verification/camera.sendto.png` next to the reference image(s) below.

Reference image(s): `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t6.73-sendto-voice-tooltip.png`, `references/auto/yope/frames/a-savannahclooney-7683341732695592206-t5.73-sendto-caption-keyboard.png`, `references/auto/yope/frames/a-virgi-7686278541255642390-t56.23-sendto-three-selected-es.png`, `references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png`

Snapshots (CI): `camera.sendto-loading.png`, `camera.sendto-loaded.png`, `camera.sendto-nothing-selected.png`, `camera.sendto-voice-coach.png`, `camera.sendto-empty.png`, `camera.sendto-offline.png`, `camera.sendto-error.png`, `camera.sendto-offline-send.png`, `camera.sendto-video-free-member.png`, `camera.sendto-sent-toast.png`

**Summary: 48 matched · 2 approximated · 5 not matched (BLOCKED or not buildable).**

## Header

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `size.global.headerButton` | 44 pt (SOURCED) | ✕ / download circles 44 | shared HeaderCircleButton (Components) |
| matched | `color.global.controlOnDeep` | #101010 (SOURCED) | circle fill | HeaderCircleFill.onDeep |
| matched | `size.global.headerInset` | 11.5 pt (SOURCED) | inset 11.5 | padding(.horizontal) |
| matched | `icon.global.close` | ios: xmark; android: Rounded.Close (PLATFORM) | ✕ | Image |
| matched | `icon.global.download` | ios: arrow.down.to.line; android: Rounded.Download (PLATFORM) | download | Image |
| matched | `camera.sendto.title` | “send to...” (SOURCED) | ‘send to...’ | Copy, text role sheetTitle |
| matched | `fontSize.global.sheetTitle` | 19.5 pt (SOURCED) | title size | DSTextStyle (title3) |
| matched | `fontWeight.global.sheetTitle` | bold (SOURCED) | title weight | DSTextStyle |

## Preview card

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.sendto.layout.preview` | width: 218; height: 290; top: 130; gapBelowHeader: 30.5 (SOURCED) | 218 × 290, top 130, 30.5 below header | frame + offset(y: top); header top = top − gap − 44 (centre 78) |
| matched | `radius.global.photo` | 15 pt (SOURCED) | card corners 15 | clipShape |
| matched | `camera.capture.hourOverlay` | “{time}” (SOURCED) | overlay on the card (capture hour) | Text, overlayTimeCamera role |
| matched | `camera.sendto.size.captionBaselineOffset` | 31 pt (SOURCED) | caption baseline 31 under overlay baseline | custom VerticalAlignment (last → first baseline + offset) |
| matched | `camera.sendto.fontSize.caption` | 16 pt (SOURCED) | caption 16 | DSTextStyle (callout) |
| matched | `camera.sendto.fontWeight.caption` | semibold (SOURCED) | caption semibold | DSTextStyle |
| matched | `camera.sendto.layout.messageField` | height: 37; insetLeading: 10; insetBottom: 14.5; gapToMic: 7.5; micDiameter: 38; insetTrailing: 8.5 (SOURCED) | field h 37, inset 10 / 14.5, mic 38, gap 7.5, trailing 8.5 | HStack paddings / frames |
| not matched | `camera.sendto.color.messageField` | None (BLOCKED) | field + mic fill (BLOCKED) | no fill drawn until unblocked (CaptureBlocked.messageFieldFill) |
| approximated | `camera.sendto.fontSize.messagePlaceholder` | 15 pt (SOURCED) | placeholder 15, textPrimary | TextField prompt; weight not measured → platform regular; text inset = h/2 (capsule radius, not measured) |
| matched | `camera.sendto.caption.placeholder` | “add a message” (SOURCED) | ‘add a message’ | Copy; field label for VoiceOver |
| not matched | `icon.global.mic` | ios: mic.fill; android: Rounded.Mic (PLATFORM) | mic glyph | Image — DEBUG builds only: the recording interaction `chat.voice.layout.recording` is BLOCKED |
| not matched | `camera.sendto.coach.voice` | “add a voice memo on this pic” (SOURCED) | voice coach | CaptureCoachTooltip, wraps within the card (DEBUG with the mic) |
| not matched | `camera.sendto.size.captionMaxLength` | None (BLOCKED) | caption limit (BLOCKED) | no client limit until unblocked (server bound 1000) |

## Recipient rows

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.sendto.layout.recipientRow` | pitch: 60; avatarCenterInset: 51.5; nameInset: 83; checkTrailingInset: 29; firstRowCenterBelowPreview: 49.5 (SOURCED) | pitch 60, avatar centre 51.5, name at 83, check trailing 29, first row centre 49.5 below card | HStack paddings derived from the tokens |
| matched | `size.global.avatarSmall` | 32.6 pt (SOURCED) | group avatar 32.6 | frame; cover downsampled to its size off the main actor |
| approximated | `icon.global.group` | ios: person.2.fill; android: Rounded.Group (PLATFORM) | no cover | glyph textPrimary (colour/size not specified) |
| matched | `fontSize.global.headerTitle` | 15 pt (SOURCED) | name 15 bold | DSTextStyle (subheadline) |
| matched | `size.global.checkCircle` | 24 pt (SOURCED) | check 24 | CaptureCheckCircle |
| matched | `icon.global.check` | ios: checkmark.circle.fill; android: Rounded.CheckCircle (PLATFORM) | selected | selection colour |
| matched | `color.global.selection` | #0091FF (PLATFORM) | check colour | foregroundStyle |
| matched | `icon.global.uncheck` | ios: circle; android: Rounded.RadioButtonUnchecked (PLATFORM) | unselected | textSecondary |
| matched | `haptic.global.select` | ios: selection; android: SEGMENT_TICK (PLATFORM) | toggle haptic | dsHaptic(trigger: selectionChanges) |

## Send button

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `size.global.buttonHeightSheet` | 47 pt (SOURCED) | height 47 | frame |
| matched | `size.global.buttonMarginHSheet` | 27 pt (SOURCED) | side margins 27 | width − 2 × margin |
| matched | `camera.sendto.size.sendButtonBottom` | 41.5 pt (SOURCED) | bottom 41.5 above screen bottom | padding(.bottom) in a safe-area-ignoring stack |
| matched | `radius.global.button` | 14 pt (SOURCED) | corners 14 | RoundedRectangle |
| matched | `camera.sendto.send` | “send” (SOURCED) | ‘send’ | Copy, role button, onAccent |
| matched | `camera.sendto.size.countDisc` | 18.5 pt (SOURCED) | count disc 18.5 | frame + Circle(onAccent) |
| matched | `camera.sendto.size.countDiscGap` | 7 pt (SOURCED) | gap 7 | HStack spacing |
| matched | `camera.sendto.fontSize.countNumber` | 11 pt (SOURCED) | number 11 | DSTextStyle (caption2), accent |
| matched | `camera.sendto.fontWeight.countNumber` | bold (SOURCED) | number bold | DSTextStyle |
| matched | `haptic.global.send` | ios: notification.success; android: CONFIRM (PLATFORM) | sent haptic | played when create_post succeeds (CaptureSendCenter) |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | failed haptic | played on failure |

## Toast and states

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.sendto.layout.toast` | height: 49; marginHorizontal: 8.5; top: 59; cornerRadius: 20; glyph: 17; glyphInset: 19.5; glyphToText: 11 (SOURCED) | lime bar 49 high, margins 8.5, top 59, r 20, glyph 17 at 19.5, gap 11 | CaptureConfirmationToast / CaptureFailureToast |
| not matched | `camera.sendto.duration.toastVisible` | None (BLOCKED) | visible time (BLOCKED) | confirmations announced to VoiceOver only; the toast is drawn once unblocked (CaptureBlocked.toastVisible) |
| matched | `camera.sendto.toast.postedOne` | “posted in {group}” (SOURCED) | ‘posted in {group}’ | request.confirmation |
| matched | `camera.sendto.toast.postedMany` | “posted in your groups” (SOURCED) | ‘posted in your groups’ | request.confirmation |
| matched | `camera.sendto.toast.saved` | “saved to your library” (SOURCED) | ‘saved to your library’ | after save |
| matched | `camera.sendto.error.sendFailed` | “your pic didn’t send” (SOURCED) | error toast | failure toast with retry (no animation: toast motion BLOCKED) |
| matched | `camera.sendto.error.offline` | “you’re offline” (SOURCED) | offline toast | failure toast; retried automatically when the network returns |
| matched | `camera.sendto.error.retry` | “try again” (SOURCED) | retry text button | Button → outbox replay |
| matched | `camera.sendto.empty.title` | “no groups yet” (SOURCED) | no groups | CaptureEmptyState; button opens AccountModal.groupCreate as a sheet over send-to (capture kept) |
| matched | `camera.sendto.empty.detail` | “start one and share this pic with your people” (SOURCED) | detail | CaptureEmptyState |
| matched | `camera.sendto.empty.button` | “create group” (SOURCED) | ‘create group’ | CaptureLightPill |

## Accessibility

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.sendto.a11y.close` | “close” (SOURCED) | ✕ | label |
| matched | `camera.sendto.a11y.save` | “save” (SOURCED) | download | label |
| matched | `camera.sendto.a11y.voice` | “add a voice memo” (SOURCED) | mic | label (+ recording value) |

## Notes

- Presentation: full-screen cover with the system slide-up (the Yope sheet spring `spring.global.sheetPresent` is BLOCKED; documented alternative = native presentation). A cover keeps the measured positions from the screen top.
- Groups-load failure without a cache (not in the spec's state table): offline → `camera.sendto.error.offline` + retry pill; other errors → the retry pill alone (no copy exists).
- After editing, the field shows the typed caption (not observed in the reference).
- The success toast belongs on the screen the member returns to (groups.list): the shell must attach `.captureSendStatus(CaptureEnvironment.shared.sendCenter)` (reported).
