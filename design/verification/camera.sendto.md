# Verification — `camera.sendto` (iOS, Pass 4 — Retro redesign)

Share Photo composer — `ios/App/Sources/Features/Capture/SendTo/SendToView.swift` (+ `SendToMessageSheet`, `SendToGroupRow`), `SendToVoice.swift`, `SendToModel.swift`, `CaptureSendCenter.swift`, `ios/App/Sources/Features/Capture/Support/CaptureComponents.swift` (`CaptureMediaHeader`).

Checklist written from the spec (`design/surfaces/camera.sendto.md`) against the iOS code; the snapshot step is the lead's: macOS CI records `ios/build/snapshots/capture/<surface>-<state>-<light|dark>.png` (every state in light, the primary state also in dark), then `tools/sidebyside.py` makes `design/verification/camera.sendto.png` next to the reference image(s) below.

Reference image(s): `references/auto/retro/store/retro-store-03.png (ST-03)`, `references/auto/retro/press/tc-2023-12-retro3.png phones 2–3 (TC-R3)`, `references/auto/retro/video/ig-DDbA_F7x-j7-composer-f130-147-f188-197.png`, `references/owner/locket-review-sendto.jpg (mechanics)`

Snapshots (CI, `ios/build/snapshots/capture/`): `camera.sendto-loaded-light.png`, `camera.sendto-loaded-dark.png`, `camera.sendto-message-sheet-light.png`, `camera.sendto-message-sheet-dark.png`, `camera.sendto-loading-light.png`, `camera.sendto-message-added-light.png`, `camera.sendto-message-sheet-empty-light.png`, `camera.sendto-nothing-selected-light.png`, `camera.sendto-voice-recording-light.png`, `camera.sendto-voice-locked-light.png`, `camera.sendto-voice-paused-light.png`, `camera.sendto-voice-paused-preview-light.png`, `camera.sendto-voice-attached-light.png`, `camera.sendto-voice-attached-dark.png`, `camera.sendto-voice-attached-playing-light.png`, `camera.sendto-sending-light.png`, `camera.sendto-empty-light.png`, `camera.sendto-offline-groups-light.png`, `camera.sendto-error-composer-kept-light.png`, `camera.sendto-video-free-member-light.png`

**Summary: 48 matched · 3 approximated · 0 not matched (BLOCKED or not buildable).**

## Page and header

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `color.global.backgroundDeep` | #000000 (SOURCED) | black modal, both appearances | background + dark subtree; the cover sets `.preferredColorScheme(.dark)` (light status-bar content) |
| matched | `camera.sendto.layout.header` | title: centred, text role sheetTitle, colour color.global.textOnMedia; its cap middle on the circles' centre line; trailing: close circle (C-11 on media): size.global.circleButton, centre 37.7 pt from the trailing edge; leading: save circle, mirrored (centre 37.7 pt from the leading edge); centreBelowSafeArea: 25.8 (SOURCED) | title centred, cap middle on the circles' line 25.8 below the safe-area top; close centre 37.7 from the trailing edge; save mirrored | `CaptureMediaHeader`: centreBelowSafeArea from the token; 37.7 from `collage.view.layout.screen.closeCentreFromTrailing` (the send-to token states it only in words) |
| matched | `camera.sendto.title` | “Share Photo” (SOURCED) | "Share Photo"; "Sending…" while sending | `CaptureMediaHeaderTitle`, cross-fade `duration.global.crossfade` |
| matched | `camera.sendto.sending` | “Sending…” (SOURCED) | busy title | same |
| matched | `size.global.circleButton` | 36 pt (SOURCED) | close / save 36, #262626 | `CircleButton(style: .media)` |
| approximated | `icon.global.close` | ios: xmark; android: Rounded.Close (PLATFORM) | glyph ≈ 9.7 pt (no token) | glyph box `size.global.iconSmall` (nearest glyph token; same as the recap preview close) |
| matched | `icon.global.download` | ios: arrow.down.to.line; android: Rounded.Download (PLATFORM) | save glyph | same box |

## Photo, message pill, voice capsule

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.sendto.layout.preview` | width: 297.6; maxHeight: 422.8; cornerRadius: 8.5; topBelowHeaderCircle: 20; fit: native aspect, aspect-fill; height = min(width ÷ aspect, maxHeight); centred horizontally (SOURCED) | 297.6 wide, native aspect (3:4 → 396.8), ≤ 422.8, corners 8.5, 20 below the circles | frame from the still's pixel aspect, `DSShape.rounded(8.5)`, `metricGap(topBelowHeaderCircle)` |
| matched | `camera.sendto.layout.messageField` | message: C-09 glass pill on the photo: fill color.global.controlOnDeep, icon.global.edit + label text role pill, colour color.global.textOnMedia, height size.global.pillHeight, width hugs the label; voice: icon-only capsule after it: width size.global.iconPillWidth, height size.global.pillHeight, same fill, icon.global.mic; gap: size.global.pillGap; bottomInset: 20.5; align: the pair centred horizontally on the photo (SOURCED) | pill + voice capsule centred, bottom 20.5 above the photo bottom, gap pillGap | bottom overlay HStack(spacing: pillGap), padding bottomInset |
| matched | `camera.sendto.message.add` | “Add a message” (SOURCED) | "Add a message" / "Edit message" after one | `LightPill(style: .dark, icon: icon.global.edit)`, label cross-fade |
| matched | `camera.sendto.message.edit` | “Edit message” (SOURCED) | after a message | same |
| matched | `size.global.iconPillWidth` | 49 pt (SOURCED) | voice capsule 49 × 37, icon.global.mic | `CapsuleLabel(icon:, style: .fill)` in the dark subtree (#262626, white glyph) |
| matched | `camera.sendto.a11y.voice` | “Add a voice note” (SOURCED) | voice label | element label |
| approximated | `icon.global.mic` | ios: mic; android: Outlined.Mic (PLATFORM) | recording: red mic · elapsed · ‹ Slide to cancel (chat.voice) | `SendToRecordingCapsule` replaces the pill: C-07 anatomy on #262626, text role `pill` (chat.voice uses `body` in the composer field; here the capsule's role) |
| matched | `icon.global.lock` | ios: lock.fill; android: Rounded.Lock (PLATFORM) | lock circle pillGap above while holding | `CircleButtonFace(.media)` overlay |
| matched | `icon.global.trash` | ios: trash; android: Outlined.Delete (PLATFORM) | paused draft: delete (destructive) | glyph button `chat.voice.a11y.discard` |
| matched | `icon.global.play` | ios: play.fill; android: Rounded.PlayArrow (PLATFORM) | attached note: ▶ + duration (chat.voice capsule) | `SendToVoiceNoteCapsule`; delete from its context menu / VoiceOver action |
| matched | `camera.sendto.layout.messageField` (`.note`)<br>`chat.voice.dimension.waveform`<br>`layout.global.waveform`<br>`size.global.waveformBarWidth` / `.waveformBarGap` / `.waveformBarMinHeight`<br>`color.global.textOnMedia` / `.textSecondary` | note: the chat.voice capsule on media, centred `size.global.pillGap` above the pill pair (SOURCED)<br>154 pt (SOURCED)<br>C-36, max 0.553 × holder (SOURCED)<br>2.0 / 2.1 / 2.0 pt (SOURCED)<br>#FFFFFF / #999999 (SOURCED) | attached note: play · C-36 waveform · duration (owner decision 16) | `SendToVoiceNoteCapsule` with `VoiceWaveform(levels:progress:onMedia: true, holderHeight: pillHeight)` 154 pt wide (38 bars, tallest 20.46 pt); played bars follow `noteProgress`; snapshots `voice-attached`, `voice-attached-playing` |
| matched | `camera.sendto.layout.messageField` (`.recording`)<br>`chat.voice.layout.locked`<br>`chat.voice.a11y.pauseRecording` / `.resumeRecording` | locked: red mic · elapsed · live waveform · pause; paused: trash · preview · draft waveform · length · red mic; the capsule spans the photo less `size.global.pillGap` on each side, the voice capsule and the gap (SOURCED)<br>(SOURCED)<br>“Pause recording” / “Continue recording” (SOURCED) | locked / paused recording capsule | `SendToRecordingCapsule` (`recordingWidth` = 297.6 − 3 × 8.8 − 49 = 222.2 pt), C-36 across the remaining width; the voice capsule shows `icon.global.send` and keeps the note; `SendToModel` voice phase machine unit-tested (CaptureSendFlowTests); snapshots `voice-locked`, `voice-paused`, `voice-paused-preview` |

## Groups

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| approximated | `camera.sendto.groupsLabel` | “Groups” (SOURCED) | "Groups", text role meta, textSecondary, 35.2 below the photo, at the margin | label cap top `size.global.sectionGap` (36.4, Retro's photo → section-header gap) below the photo: 35.2 exists only in the token's prose (gap reported) |
| matched | `camera.sendto.layout.recipientRow` | label: section label above the rows: text role meta, color.global.textSecondary, 35.2 pt below the preview bottom, at size.global.screenMargin; row: C-16 people row: group cover avatar size.global.avatarPicker (circle; no cover → icon.global.group on color.global.controlOnDeep), name text role listTitle color.global.textOnMedia starting size.global.cardNameGap after the avatar (Retro avatar → name gap, C-18), trailing check size.global.checkCircle with its ink at the trailing margin; padding: 16; insets: size.global.screenMargin; divider: C-32 hairline between rows, color.global.separator dark value (#4D4D4D) on media, inside the margins; check: selected icon.global.check in color.global.selection; not selected icon.global.uncheck in color.global.textSecondary (SOURCED) | C-16 row: avatar 37 → 11 → listTitle name; check ink on the margin; 16 above/below (69); hairline between rows inside the margins | `SendToGroupRow` (PeopleRow has no avatar→name gap token nor check slot — composed locally), `HairlineDivider` (separator dark #4D4D4D) |
| matched | `size.global.avatarPicker` | 37 pt (SOURCED) | 37 circle; no cover: group glyph on #262626 | `AvatarView(placeholderIcon: icon.global.group)` (fallback fill `control` = #262626 in the dark subtree) |
| matched | `size.global.cardNameGap` | 11 pt (SOURCED) | 11 | leading padding of the name |
| matched | `size.global.checkCircle` | 24 pt (SOURCED) | 24 | Image frame |
| matched | `color.global.selection` | light: #0088FF; dark: #0091FF (PLATFORM) | selected check | foreground |
| matched | `color.global.textSecondary` | #999999 (SOURCED) | unselected ring | foreground |
| matched | `haptic.global.select` | ios: selection; android: SEGMENT_FREQUENT_TICK (PLATFORM) | tick on toggle | `.dsHaptic(select, trigger: selectionChanges)` |

## Send capsule (C-05 on media)

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `size.global.buttonHeight` | 60 pt (SOURCED) | 60 | PrimaryButton |
| matched | `size.global.buttonMarginH` | 20 pt (SOURCED) | 20 | horizontal padding |
| matched | `camera.sendto.size.sendButtonBottom` | 44.5 pt (SOURCED) | bottom 44.5 above the screen bottom | bottom padding = 44.5 − safe-area bottom (safeAreaInset) |
| matched | `color.global.surfaceLight` | #FFFFFF (SOURCED) | white fill, black label | `PrimaryButton(surface: .media)` |
| matched | `color.global.controlRaised` | light: #CCCCCC; dark: #4D4D4D (SOURCED) | disabled #4D4D4D, label black | PrimaryButton disabled in the dark subtree (controlRaised dark / onAccent dark) |
| matched | `camera.sendto.send` | “Send” (SOURCED) | "Send" | label |
| matched | `haptic.global.send` | ios: notification.success; android: CONFIRM (PLATFORM) | on posted | `CaptureSendCenter.send` |
| matched | `haptic.global.error` | ios: notification.error; android: REJECT (PLATFORM) | on failure | same |

## Add a Message sheet

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.sendto.layout.messageSheet` | header: native sheet toolbar: centred title text role sheetTitle; trailing 'Done' text button (C-08, text role textButton, color.global.textPrimary); field: multi-line text, text role placeholder (17), typed color.global.textPrimary, placeholder color.global.textSecondary, on color.global.background; textInset: 22; counterTrailingInset: 20.7; counterAboveKeyboard: 22; counter: camera.sendto.fontSize.counter, monospaced digits (iOS Font.Design.monospaced; Android FontFamily.Monospace), color.global.textSecondary (SOURCED) | native page sheet following the appearance; toolbar title + Done; field from 22; counter 20.7 from the edge, 22 above the keyboard | `SendToMessageSheet` in `.sheet`, `.preferredColorScheme(system appearance)`; principal title `sheetTitle`, `TextButton` Done; padding textInset; counter paddings from the token |
| matched | `camera.sendto.message.title` | “Add a Message” (SOURCED) | "Add a Message" | toolbar principal |
| matched | `camera.sendto.message.done` | “Done” (SOURCED) | C-08 textButton, textPrimary | `TextButton(style: .header)` |
| matched | `camera.sendto.caption.placeholder` | “Add a message…” (SOURCED) | placeholder textSecondary, typed textPrimary, role placeholder (17) | TextField prompt |
| matched | `camera.sendto.fontSize.counter` | 16 pt (SOURCED) | 16, monospaced digits, callout | `CaptureType.counter` + `.fontDesign(.monospaced)` + `.monospacedDigit()` |
| matched | `camera.sendto.message.counter` | “{count}/{max}” (SOURCED) | "58/250", read as "58 of 250" | `global.a11y.pagePosition` as its label |
| matched | `camera.sendto.size.captionMaxLength` | 250 (SOURCED) | input stops at 250 | `clampCaption` |

## States and flows

| status | token / copy | reference value | element | iOS implementation |
|---|---|---|---|---|
| matched | `camera.sendto.empty.title` | “No groups yet” (SOURCED) | C-27 in the rows area → groups.create | `EmptyStateView` with the group glyph; `AccountModalDestination(.groupCreate)` sheet |
| matched | `camera.sendto.error.sendFailed` | “Couldn't send photo” (SOURCED) | native alert: Try Again / Cancel, keeps everything | `.alert(presenting: sendFailure)`; the failed outbox draft is discarded so Try Again sends the composer's capture once |
| matched | `camera.sendto.error.offline` | “Check your connection and try again.” (SOURCED) | offline alert message | Failure.offline.message |
| matched | `camera.sendto.error.generic` | “There was a problem. Please try again.” (SOURCED) | other failures | Failure.sendFailed.message |
| matched | `camera.sendto.discard.title` | “Discard photo?” (SOURCED) | asks only with a message or voice note | `needsDiscardConfirmation` → native alert, destructive "Yes, go back" |
| matched | `camera.sendto.toast.postedOne` | “Added to {group}!” (SOURCED) | Android toast / iOS announcement | `ToastCenter.show` (C-26: announcement, nothing drawn) |
| matched | `camera.sendto.toast.saved` | “Saved” (SOURCED) | save confirmation (iOS announcement) | same |
| matched | `camera.sendto.a11y.save` | “Save to Camera Roll” (SOURCED) | save label | header circle |
| matched | `camera.sendto.a11y.close` | “Close” (SOURCED) | close label | header circle |

## Notes

- The groups list's own load failures (offline with nothing cached, server error) have no spec row: drawn as C-27 detail + Try Again with `camera.sendto.error.offline` / `.generic` (retro.voice.error).
- Alerts are system-drawn; the snapshot `error-composer-kept` shows the composer state behind it.
- The cover's `.preferredColorScheme(.dark)` (status bar) also makes the system alerts dark in light appearance; the message sheet and groups.create explicitly follow the system appearance.
