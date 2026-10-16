// Surface: camera.sendto (voice capsule + optional voice note), recorded with the chat.voice recorder
// (`chat.voice.layout.recording`: WhatsApp's press-and-hold, slide to cancel, lock for hands-free) — design/surfaces/
// camera.sendto.md, chat.voice.md. Reference images: references/auto/retro/store/retro-store-03.png (ST-03: capsules on
// the photo), references/auto/whatsapp/help/faq-657157755756612-send-voice-iphone.png (mechanics), Retro's media
// duration format "1:00" (references/auto/retro/lazyweb/retro-lazyweb-20260529-paywall.png).
// Everything here sits on the photo of the black composer (media appearance: the C-06 `.fill` capsule and the C-11
// `.page` circle read #262626 with white glyphs, = `color.global.controlOnDeep` / `color.global.textOnMedia`).
import DesignSystem
import SwiftUI

/// The voice capsule after the message pill (C-06 icon-only capsule: `size.global.iconPillWidth` ×
/// `size.global.pillHeight`, `icon.global.mic`). Press and hold to record, lift to keep the note, slide left past half the
/// recording capsule to cancel, slide up onto the lock circle for hands-free; while locked or paused it shows
/// `icon.global.send` and keeps the note. With a note attached it becomes the chat.voice capsule (▶ + duration). VoiceOver:
/// activating records hands-free, then keeps the note.
struct SendToVoiceCapsule: View {
    let model: SendToModel
    /// The width the recording capsule can take (half of it is the slide-to-cancel distance).
    let rowWidth: CGFloat
    @Binding var slide: CGSize

    @State private var isPressing = false

    var body: some View {
        if model.voicePhase == .idle, let note = model.voiceNote {
            SendToVoiceNoteCapsule(model: model, durationMs: note.durationMs)
        } else {
            recorder
        }
    }

    private var recorder: some View {
        CapsuleLabel(icon: showsSend ? Tokens.Icons.globalSend : Tokens.Icons.globalMic, style: .fill)
            .overlay(alignment: .top) {
                if model.voicePhase == .holding {
                    // `chat.voice` lock circle: C-11, `size.global.pillGap` above the capsule; decorative (the gesture's target).
                    CircleButtonFace(icon: Tokens.Icons.globalLock, style: .media)
                        .alignmentGuide(.top) { dimensions in dimensions[.bottom] + Tokens.Sizes.globalPillGap }
                        .accessibilityHidden(true)
                        .dsTransition(.opacity)
                }
            }
            .dsAnimation(ComponentMotion.fade, value: model.voicePhase)
            .contentShape(Capsule())
            // Locked / paused: the capsule is a send button (tap), not a hold target.
            .gesture(holdGesture, including: showsSend ? .none : .all)
            .onTapGesture {
                if showsSend { model.keepVoiceRecording() }
            }
            .allowsHitTesting(!model.isSending)
            .accessibilityElement()
            .accessibilityLabel(Text(Copy.cameraSendtoA11yVoice))
            .accessibilityValue(Text(model.isRecordingVoice ? Copy.cameraCaptureA11yRecording : ""))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                if showsSend {
                    model.keepVoiceRecording()
                } else if model.voicePhase == .idle {
                    Task { await model.beginVoiceRecording(locked: true) }
                }
            }
            .accessibilityIdentifier("camera.sendto.voice")
    }

    private var showsSend: Bool {
        model.voicePhase == .locked || model.voicePhase == .paused
    }

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isPressing {
                    isPressing = true
                    Task { await model.beginVoiceRecording() }
                }
                guard model.voicePhase == .holding else { return }
                slide = value.translation
                if rowWidth > 0, value.translation.width < -rowWidth / 2 {
                    model.cancelVoiceRecording()
                    slide = .zero
                } else if value.translation.height < -Tokens.Sizes.globalPillHeight {
                    model.lockVoiceRecording()
                    slide = .zero
                }
            }
            .onEnded { _ in
                isPressing = false
                slide = .zero
                if model.voicePhase == .holding { model.keepVoiceRecording() }
            }
    }
}

/// An attached voice note as the chat.voice capsule on media (C-06 fill + C-07 anatomy, `chat.voice.layout.capsule`):
/// `size.global.pillPaddingLeading` → `icon.global.play` / `.pause` at `size.global.iconSmall` → `size.global.pillIconGap`
/// → the duration (Retro's "1:00", monospaced digits, text role `pill`) → `size.global.pillPaddingTrailing`. Tap plays /
/// pauses; the context menu (and a VoiceOver action) deletes it.
struct SendToVoiceNoteCapsule: View {
    let model: SendToModel
    let durationMs: Int

    var body: some View {
        let spoken = CaptureFormat.spokenCountdown(remainingSeconds: durationMs / 1000)
        Button {
            model.toggleVoicePlayback()
        } label: {
            HStack(spacing: Tokens.Sizes.globalPillIconGap) {
                Glyph(model.isPlayingVoice ? Tokens.Icons.globalPause : Tokens.Icons.globalPlay, size: Tokens.Sizes.globalIconSmall, relativeTo: TextRole.pill.relativeTo)
                Text(CaptureFormat.voiceDuration(milliseconds: durationMs))
                    .dsTextStyle(TextRole.pill)
                    .monospacedDigit()
            }
            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
            .padding(.leading, Tokens.Sizes.globalPillPaddingLeading)
            .padding(.trailing, Tokens.Sizes.globalPillPaddingTrailing)
            .frame(minHeight: Tokens.Sizes.globalPillHeight)
            .background(Tokens.Colors.globalControlOnDeep, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(model.isSending)
        .contextMenu {
            Button(role: .destructive) {
                model.removeVoiceNote()
            } label: {
                Label(Copy.chatVoiceA11yDiscard, systemImage: Tokens.Icons.globalTrash)
            }
        }
        .accessibilityLabel(Text(model.isPlayingVoice ? Copy.chatVoiceA11yPause : Copy.chatVoiceA11yPlay(duration: spoken)))
        .accessibilityAction(named: Text(Copy.chatVoiceA11yDiscard)) { model.removeVoiceNote() }
        .accessibilityIdentifier("camera.sendto.voiceNote")
    }
}

/// The recording capsule that takes the message pill's place while recording or with a paused draft
/// (`chat.voice.layout.recording`, on media): holding — `icon.global.mic` in `color.global.destructive` · elapsed time
/// (monospaced, text role `pill`, `color.global.textOnMedia`) · ‹ `chat.voice.recording.slideToCancel`
/// (`color.global.textSecondary`) following the finger; locked — the pause glyph in the hint's place; paused draft —
/// `icon.global.trash` (`color.global.destructive`) · length · ▶. Fill `color.global.controlOnDeep`, height
/// `size.global.pillHeight`, C-07 paddings.
struct SendToRecordingCapsule: View {
    let model: SendToModel
    let slide: CGSize

    var body: some View {
        HStack(spacing: Tokens.Sizes.globalPillIconGap) {
            leading
            // The recorder's elapsed time is observable (AppServices `VoiceRecorder`), so the timer updates itself.
            Text(CaptureFormat.voiceDuration(milliseconds: model.voiceElapsedMs))
                .dsTextStyle(TextRole.pill)
                .monospacedDigit()
                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                .accessibilityLabel(Text(CaptureFormat.spokenCountdown(remainingSeconds: model.voiceElapsedMs / 1000)))
            trailing
        }
        .padding(.leading, Tokens.Sizes.globalPillPaddingLeading)
        .padding(.trailing, Tokens.Sizes.globalPillPaddingTrailing)
        .frame(minHeight: Tokens.Sizes.globalPillHeight)
        .background(Tokens.Colors.globalControlOnDeep, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("camera.sendto.voiceRow")
    }

    @ViewBuilder
    private var leading: some View {
        if model.voicePhase == .paused {
            glyphButton(Tokens.Icons.globalTrash, label: Copy.chatVoiceA11yDiscard, color: Tokens.Colors.globalDestructive) {
                model.cancelVoiceRecording()
            }
        } else {
            Glyph(Tokens.Icons.globalMic, size: Tokens.Sizes.globalIconSmall, relativeTo: TextRole.pill.relativeTo)
                .foregroundStyle(Tokens.Colors.globalDestructive)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch model.voicePhase {
        case .holding:
            HStack(spacing: Tokens.Sizes.globalPillIconGap) {
                Glyph(Tokens.Icons.globalBack, size: Tokens.Sizes.globalIconSmall, relativeTo: TextRole.pill.relativeTo)
                Text(Copy.chatVoiceRecordingSlideToCancel)
                    .dsTextStyle(TextRole.pill)
                    .lineLimit(1)
            }
            .foregroundStyle(Tokens.Colors.globalTextSecondary)
            .offset(x: min(0, slide.width))
            .accessibilityElement(children: .combine)
        case .locked:
            glyphButton(Tokens.Icons.globalPause, label: Copy.chatVoiceA11yPause, color: Tokens.Colors.globalTextOnMedia) {
                model.pauseVoiceRecording()
            }
        case .paused, .idle:
            let playing = model.isPlayingVoice
            glyphButton(
                playing ? Tokens.Icons.globalPause : Tokens.Icons.globalPlay,
                label: playing ? Copy.chatVoiceA11yPause : Copy.chatVoiceA11yPlay(duration: CaptureFormat.spokenCountdown(remainingSeconds: model.voiceElapsedMs / 1000)),
                color: Tokens.Colors.globalTextOnMedia
            ) {
                model.toggleVoicePlayback()
            }
        }
    }

    /// A glyph at `size.global.iconSmall` with a `size.global.minTouchTarget.ios` hit area.
    private func glyphButton(_ icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Glyph(icon, size: Tokens.Sizes.globalIconSmall, relativeTo: TextRole.pill.relativeTo)
                .foregroundStyle(color)
                .minimumHitArea(drawn: CGSize(width: Tokens.Sizes.globalIconSmall, height: Tokens.Sizes.globalIconSmall))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}
