// Surface: camera.sendto (mic + voice note) — reference: Yope send-to (the mic on the card) recording
// with the chat.voice recorder, whose interaction is `chat.voice.layout.recording` (WhatsApp gestures +
// Telegram row, design/surfaces/chat.voice.md). Reference images:
// references/auto/yope/frames/a-chuongxetank-7694968408424582452-t6.73-sendto-voice-tooltip.png.
import DesignSystem
import SwiftUI

private typealias Field = Tokens.Layouts.CameraSendtoLayoutMessageField
private typealias Recording = Tokens.Layouts.ChatVoiceLayoutRecording

/// The mic circle (`camera.sendto.layout.messageField.micDiameter`, fill `camera.sendto.color.messageField`):
/// press and hold to record, lift to keep the note, slide left past half the field to cancel, slide up
/// one circle onto the lock for hands-free. While locked or paused it shows `icon.global.send` and keeps
/// the note. VoiceOver: activating records hands-free, then keeps the note.
struct SendToMicButton: View {
    let model: SendToModel
    /// Field width: half of it is the slide-to-cancel distance (the hint travels across the field).
    let fieldWidth: CGFloat
    @Binding var slide: CGSize

    @State private var isPressing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Tokens.Colors.cameraSendtoColorMessageField)
            Image(systemName: showsSend ? Tokens.Icons.globalSend : Tokens.Icons.globalMic)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
        }
        .frame(width: Field.micDiameter, height: Field.micDiameter)
        .overlay(alignment: .top) {
            if model.voicePhase == .holding {
                lockHint
                    .alignmentGuide(.top) { dimensions in dimensions[.bottom] }
            }
        }
        .contentShape(Circle())
        .gesture(showsSend ? nil : holdGesture)
        .onTapGesture {
            if showsSend { model.keepVoiceRecording() }
        }
        .accessibilityElement()
        .accessibilityLabel(Copy.cameraSendtoA11yVoice)
        .accessibilityValue(model.isRecordingVoice ? Copy.cameraCaptureA11yRecording : "")
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
                if value.translation.width < -fieldWidth / 2 {
                    model.cancelVoiceRecording()
                    slide = .zero
                } else if value.translation.height < -Field.micDiameter {
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

    /// The lock above the mic while holding: `icon.global.lock` over the slide-up hint glyph,
    /// `color.global.textSecondary`, at the row's text size. Decorative.
    private var lockHint: some View {
        VStack {
            Image(systemName: Tokens.Icons.globalLock)
            Image(systemName: Recording.lockHintGlyphIos)
        }
        .dsTextStyle(CaptureType.messagePlaceholder)
        .foregroundStyle(Tokens.Colors.globalTextSecondary)
        .accessibilityHidden(true)
    }
}

/// The message field's place while recording, with a draft or an attached note
/// (`chat.voice.layout.recording.row`): red dot (`color.global.destructive`) · elapsed time (mm:ss,
/// `color.global.textPrimary`) · the hint ‹ 'slide to cancel' (`color.global.textSecondary`) following
/// the finger. Hands-free: pause in the hint's place; paused draft or attached note: delete · length · ▶.
/// Text at the field's role (it replaces the field); the dot is as tall as the timer's capitals;
/// spacing is the platform's (not measured).
struct SendToVoiceRow: View {
    let model: SendToModel
    let slide: CGSize

    var body: some View {
        HStack {
            if showsDelete {
                glyphButton(Tokens.Icons.photoViewerIconDelete, label: Copy.chatThreadMenuDelete, color: Tokens.Colors.globalDestructive) {
                    if model.voicePhase == .paused {
                        model.cancelVoiceRecording()
                    } else {
                        model.removeVoiceNote()
                    }
                }
            } else {
                Circle()
                    .fill(Tokens.Colors.globalDestructive)
                    .frame(width: CaptureMetrics.capHeight(of: CaptureType.messagePlaceholder), height: CaptureMetrics.capHeight(of: CaptureType.messagePlaceholder))
                    .accessibilityHidden(true)
            }
            // The recorder's elapsed time is observable (AppServices `VoiceRecorder`), so the timer updates itself.
            Text(CaptureFormat.voiceDuration(milliseconds: model.voiceElapsedMs))
                .dsTextStyle(CaptureType.messagePlaceholder)
                .monospacedDigit()
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .accessibilityLabel(CaptureFormat.spokenCountdown(remainingSeconds: model.voiceElapsedMs / 1000))
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, Field.height / 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("camera.sendto.voiceRow")
    }

    private var showsDelete: Bool {
        model.voicePhase == .paused || (model.voicePhase == .idle && model.voiceNote != nil)
    }

    @ViewBuilder
    private var trailing: some View {
        switch model.voicePhase {
        case .holding:
            HStack {
                Image(systemName: Tokens.Icons.globalBack)
                Text(Copy.chatVoiceRecordingSlideToCancel)
                    .lineLimit(1)
            }
            .dsTextStyle(CaptureType.messagePlaceholder)
            .foregroundStyle(Tokens.Colors.globalTextSecondary)
            .offset(x: min(0, slide.width))
            .accessibilityElement(children: .combine)
        case .locked:
            glyphButton(Tokens.Icons.chatVoiceIconPause, label: Copy.chatVoiceA11yPause, color: Tokens.Colors.globalTextPrimary) {
                model.pauseVoiceRecording()
            }
        case .paused, .idle:
            let playing = model.isPlayingVoice
            glyphButton(
                playing ? Tokens.Icons.chatVoiceIconPause : Tokens.Icons.globalPlay,
                label: playing ? Copy.chatVoiceA11yPause : Copy.chatVoiceA11yPlay(duration: CaptureFormat.spokenCountdown(remainingSeconds: model.voiceElapsedMs / 1000)),
                color: Tokens.Colors.globalTextPrimary
            ) {
                model.toggleVoicePlayback()
            }
        }
    }

    /// A bare glyph at the platform's symbol size with a `size.global.minTouchTarget.ios` hit area.
    private func glyphButton(_ icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .captureMinimumHitArea(action: action)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
