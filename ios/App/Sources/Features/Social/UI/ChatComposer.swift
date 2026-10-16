// Surface: chat.composer (and the recording row of chat.voice) — Retro's reply / comment field (C-13) on a page with
// Apple Messages / WhatsApp's glyph order. Spec: design/surfaces/chat.composer.md, chat.voice.md "Structure — recording".
// References: references/auto/retro/press/tc-2023-07-retro-2b.jpg phone 2 (field x1357–2152, rows 1821–1934, own avatar
// x1376–1445, placeholder from x1469, '•••' ink x2077–2113), references/auto/whatsapp/store/whatsapp-store-04.png.
import AppData
import AppModels
import AppServices
import DesignSystem
import SwiftUI
import UIKit

// MARK: - The field (C-13 with the measured internals)

/// The C-13 field's measured internals (`chat.composer.dimension.*`, TC-2B at 2.209 px/pt) — the shared `ReplyBar` uses
/// platform padding there (reported as a component gap), so the social screens place its parts from these.
/// - fill `color.global.control` on a page / `color.global.controlOnDeep` on media, height `size.global.commentFieldHeight`
///   (a minimum: the field grows with its text), corners `radius.global.commentField`, `size.global.screenMargin` insets;
/// - own avatar `size.global.avatarComment` at `chat.composer.dimension.avatarInset`;
/// - text `chat.composer.dimension.avatarToText` after the avatar (text role `body`);
/// - trailing glyphs in `size.global.icon` boxes with `size.global.headerButton` hit areas, `size.global.headerIconPitch`
///   apart, the last glyph's ink `chat.composer.dimension.glyphInsetTrailing` from the field's trailing edge.
/// Single line: everything centred in the field's height; taller text: top-aligned to the first line.
enum SocialFieldMetrics {
    static var height: CGFloat { Tokens.Sizes.globalCommentFieldHeight }

    static var avatarTop: CGFloat { max(0, (height - Tokens.Sizes.globalAvatarComment) / 2) }

    /// Top and bottom inset of the text so a single line sits centred in the field.
    static var textVertical: CGFloat { max(0, (height - SocialMetrics.lineHeight(TextRole.body)) / 2) }

    static var glyphTop: CGFloat { max(0, (height - Tokens.Sizes.globalHeaderButton) / 2) }

    /// Trailing padding of the last glyph's hit area.
    static var glyphTrailing: CGFloat {
        max(0, Tokens.Sizes.chatComposerDimensionGlyphInsetTrailing - (Tokens.Sizes.globalHeaderButton - Tokens.Sizes.globalIcon) / 2)
    }

    /// Space between two glyph hit areas whose centres are `size.global.headerIconPitch` apart.
    static var glyphSpacing: CGFloat { max(0, Tokens.Sizes.globalHeaderIconPitch - Tokens.Sizes.globalHeaderButton) }
}

extension View {
    /// The C-13 field's shape: fill, corners, minimum height and side insets.
    func socialFieldShape(onMedia: Bool) -> some View {
        frame(maxWidth: .infinity, minHeight: SocialFieldMetrics.height, alignment: .topLeading)
            .background(
                onMedia ? Tokens.Colors.globalControlOnDeep : Tokens.Colors.globalControl,
                in: DSShape.rounded(Tokens.Radii.globalCommentField)
            )
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}

/// A bare glyph inside the field: `size.global.icon` box, `size.global.headerButton` hit area.
struct SocialFieldGlyph: View {
    let icon: String
    let color: Color
    let accessibilityLabel: String
    var identifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Glyph(icon)
                .foregroundStyle(color)
                .frame(width: Tokens.Sizes.globalHeaderButton, height: Tokens.Sizes.globalHeaderButton)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityIdentifier(identifier ?? "")
    }
}

/// The field's avatar and text input, without the trailing glyphs.
struct SocialFieldInput: View {
    @Binding var text: String
    let avatar: PhotoSource?
    let placeholder: String
    let accessibilityLabel: String
    var onMedia = false
    var identifier: String?
    var focus: FocusState<Bool>.Binding?

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Sizes.chatComposerDimensionAvatarToText) {
            AvatarView(source: avatar, diameter: Tokens.Sizes.globalAvatarComment)
                .padding(.top, SocialFieldMetrics.avatarTop)
            field
                .padding(.vertical, SocialFieldMetrics.textVertical)
        }
        .padding(.leading, Tokens.Sizes.chatComposerDimensionAvatarInset)
    }

    @ViewBuilder
    private var field: some View {
        let input = TextField(
            text: $text,
            prompt: Text(placeholder).foregroundStyle(Tokens.Colors.globalTextSecondary),
            axis: .vertical
        ) {
            Text(accessibilityLabel)
        }
        .dsTextStyle(TextRole.body)
        .foregroundStyle(onMedia ? Tokens.Colors.globalTextOnMedia : Tokens.Colors.globalTextPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityIdentifier(identifier ?? "")
        if let focus {
            input.focused(focus)
        } else {
            input
        }
    }
}

// MARK: - chat.composer

/// `chat.composer`: the C-13 field pinned to the bottom, `chat.composer.dimension.bottomInset` above the safe area (on
/// the keyboard while typing). Idle: own avatar, "Send a message…" (replying: "Reply…"), then `icon.global.camera` and
/// `icon.global.mic` in `color.global.textSecondary`; with text both give way to `icon.global.send` in
/// `color.global.textPrimary` at the mic's place (cross-fade `duration.global.crossfade`). Holding the mic records
/// (`chat.voice.layout.recording`): the field's content becomes the recording row and the lock circle shows above the mic.
/// Locked (`chat.voice.layout.locked`): the field shows the live (or paused draft's) waveform and a controls row under it
/// holds delete · pause / continue · send.
struct ChatComposer: View {
    @Binding var text: String
    let avatar: PhotoSource?
    let isReplying: Bool
    let send: () -> Void
    let camera: () -> Void
    let recorder: SocialVoiceRecorder
    /// A finished recording to send.
    let onRecorded: (VoiceRecording) -> Void
    let onRecordFailed: () -> Void
    /// The microphone is denied: the native alert shows.
    let onMicDenied: () -> Void
    var focus: FocusState<Bool>.Binding?

    @State private var drag: CGSize = .zero
    /// The finger is on the mic (reset by the system when the gesture ends or is cancelled).
    @GestureState private var touching = false
    /// This touch already started a recording (or tried to).
    @State private var didStart = false
    @State private var rowWidth: CGFloat = 0

    private var hasText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: Tokens.Sizes.globalPillGap) {
            field
            if recorder.isLocked {
                lockedControls
                    .transition(.opacity)
            }
        }
        .padding(.bottom, Tokens.Sizes.chatComposerDimensionBottomInset)
        .dsAnimation(ComponentMotion.fade, value: recorder.isActive)
        .dsAnimation(ComponentMotion.fade, value: recorder.phase)
        .onChange(of: recorder.isActive) { _, active in
            if !active { drag = .zero }
        }
        .onChange(of: touching) { _, isTouching in
            if !isTouching { didStart = false }
        }
    }

    private var field: some View {
        HStack(alignment: .top, spacing: 0) {
            if recorder.isLocked {
                lockedField
            } else if recorder.isActive {
                recordingRow
            } else {
                SocialFieldInput(
                    text: $text,
                    avatar: avatar,
                    placeholder: isReplying ? Copy.chatComposerPlaceholderReply : Copy.chatComposerPlaceholder,
                    accessibilityLabel: Copy.chatComposerA11yField,
                    identifier: "chat.composer.field", // provenance-ok: accessibility identifier for UI tests
                    focus: focus
                )
            }
            if !recorder.isLocked {
                trailing
                    .padding(.top, SocialFieldMetrics.glyphTop)
                    .padding(.trailing, SocialFieldMetrics.glyphTrailing)
                    .dsAnimation(ComponentMotion.crossfade, value: hasText)
            }
        }
        .socialFieldShape(onMedia: false)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { rowWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, value in rowWidth = value }
            }
        }
    }

    // MARK: Trailing glyphs (`chat.composer.layout.typingState`)

    @ViewBuilder
    private var trailing: some View {
        switch recorder.phase {
        case .locked, .paused:
            EmptyView()
        case .idle where hasText:
            SocialFieldGlyph(
                icon: Tokens.Icons.globalSend, color: Tokens.Colors.globalTextPrimary, accessibilityLabel: Copy.chatComposerA11ySend,
                identifier: "chat.composer.send" // provenance-ok: accessibility identifier for UI tests
            ) { send() }
            .transition(.opacity)
        case .idle, .holding:
            HStack(spacing: SocialFieldMetrics.glyphSpacing) {
                if recorder.phase == .idle {
                    SocialFieldGlyph(icon: Tokens.Icons.globalCamera, color: Tokens.Colors.globalTextSecondary, accessibilityLabel: Copy.chatComposerA11yCamera, action: camera)
                        .transition(.opacity)
                }
                micGlyph
            }
        }
    }

    /// The mic: press and hold records; lift sends; slide left past the hint cancels; slide up onto the lock (one
    /// `size.global.pillGap` above the field) keeps recording hands-free. VoiceOver: the default action starts a
    /// hands-free recording.
    private var micGlyph: some View {
        Glyph(Tokens.Icons.globalMic)
            .foregroundStyle(Tokens.Colors.globalTextSecondary)
            .frame(width: Tokens.Sizes.globalHeaderButton, height: Tokens.Sizes.globalHeaderButton)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                if recorder.phase == .holding {
                    // C-11 lock circle centred over the mic, `size.global.pillGap` above the field.
                    CircleButtonFace(icon: Tokens.Icons.globalLock, style: .page)
                        .alignmentGuide(.top) { $0[.bottom] + SocialFieldMetrics.glyphTop + Tokens.Sizes.globalPillGap }
                        .accessibilityLabel(Text(Copy.chatVoiceA11yLock))
                        .transition(.opacity)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($touching) { _, state, _ in state = true }
                    .onChanged { value in fingerMoved(value.translation) }
                    .onEnded { _ in fingerLifted() }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(Copy.chatComposerA11yMic))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default) { start(locked: true) }
            .accessibilityIdentifier("chat.composer.mic") // provenance-ok: accessibility identifier for UI tests
    }

    // MARK: Recording row

    /// `chat.voice.layout.recording.field`: `icon.global.mic` in `color.global.destructive` in the avatar's place, the
    /// elapsed time (text role `body`, monospaced, `color.global.textPrimary`) where the text starts, and — centred in
    /// the remaining width, following the finger — `icon.global.back` + "Slide to cancel" in `color.global.textSecondary`.
    private var recordingRow: some View {
        HStack(alignment: .top, spacing: Tokens.Sizes.chatComposerDimensionAvatarToText) {
            Glyph(Tokens.Icons.globalMic)
                .foregroundStyle(Tokens.Colors.globalDestructive)
                .frame(width: Tokens.Sizes.globalAvatarComment, height: Tokens.Sizes.globalAvatarComment)
                .padding(.top, SocialFieldMetrics.avatarTop)
                .accessibilityHidden(true)
            HStack(spacing: 0) {
                Text(SocialFormat.duration(milliseconds: recorder.elapsedMs))
                    .dsTextStyle(TextRole.body)
                    .monospacedDigit()
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .accessibilityLabel(Text(SocialFormat.spokenDuration(milliseconds: recorder.elapsedMs)))
                    .accessibilityAddTraits(.updatesFrequently)
                Spacer(minLength: 0)
                if recorder.phase == .holding {
                    HStack(spacing: Tokens.Sizes.globalPillIconGap) {
                        Glyph(Tokens.Icons.globalBack, size: Tokens.Sizes.globalIconSmall, relativeTo: TextRole.body.relativeTo)
                        Text(Copy.chatVoiceRecordingSlideToCancel)
                            .dsTextStyle(TextRole.body)
                            .lineLimit(1)
                    }
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .offset(x: min(0, drag.width))
                    .accessibilityElement(children: .combine)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, SocialFieldMetrics.textVertical)
        }
        .padding(.leading, Tokens.Sizes.chatComposerDimensionAvatarInset)
    }

    private func fingerMoved(_ translation: CGSize) {
        if !didStart {
            didStart = true
            start(locked: false)
            return
        }
        guard recorder.phase == .holding else { return }
        drag = translation
        if translation.width <= -rowWidth / 2 {
            recorder.cancel()
        } else if translation.height <= -(SocialFieldMetrics.height / 2 + Tokens.Sizes.globalPillGap) {
            recorder.lock()
            drag = .zero
        }
    }

    private func fingerLifted() {
        didStart = false
        drag = .zero
        if recorder.phase == .holding { finishRecording() }
    }

    private func start(locked: Bool) {
        switch recorder.begin(locked: locked) {
        case .started:
            break
        case .askedPermission:
            Task {
                await recorder.requestPermission()
                if !recorder.permission.allowsAccess { onMicDenied() }
            }
        case .denied:
            onMicDenied()
        case .failed:
            onRecordFailed()
        }
    }

    private func finishRecording() {
        Task {
            do {
                if let recording = try await recorder.finish() { onRecorded(recording) }
            } catch {
                onRecordFailed()
            }
        }
    }

    // MARK: Locked recording (`chat.voice.layout.locked`)

    /// The field while hands-free: recording — `icon.global.mic` in `color.global.destructive` in the avatar's place ·
    /// the elapsed time (text role `body`, monospaced, a live region) · the C-36 live waveform to the trailing glyph inset;
    /// paused — the preview glyph (`icon.global.play` / `.pause`, a button) · the draft's waveform with the preview's
    /// progress · its length (previewing: the elapsed time).
    private var lockedField: some View {
        let paused = recorder.phase == .paused
        return HStack(spacing: Tokens.Sizes.chatComposerDimensionAvatarToText) {
            Group {
                if paused {
                    Button {
                        Task { await recorder.togglePreview() }
                    } label: {
                        Glyph(recorder.isPreviewing ? Tokens.Icons.globalPause : Tokens.Icons.globalPlay)
                            .foregroundStyle(Tokens.Colors.globalTextPrimary)
                            .frame(width: Tokens.Sizes.globalAvatarComment, height: Tokens.Sizes.globalAvatarComment)
                            .minimumHitArea(drawn: CGSize(width: Tokens.Sizes.globalAvatarComment, height: Tokens.Sizes.globalAvatarComment))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(recorder.isPreviewing
                        ? Copy.chatVoiceA11yPause
                        : Copy.chatVoiceA11yPlay(duration: SocialFormat.spokenDuration(milliseconds: recorder.elapsedMs))))
                    .accessibilityIdentifier("chat.composer.preview") // provenance-ok: accessibility identifier for UI tests
                } else {
                    Glyph(Tokens.Icons.globalMic)
                        .foregroundStyle(Tokens.Colors.globalDestructive)
                        .frame(width: Tokens.Sizes.globalAvatarComment, height: Tokens.Sizes.globalAvatarComment)
                        .accessibilityHidden(true)
                }
            }
            .dsAnimation(ComponentMotion.crossfade, value: recorder.isPreviewing)
            if !paused {
                elapsedLabel(recorder.elapsedMs)
            }
            VoiceWaveform(
                levels: recorder.levels,
                progress: paused ? recorder.previewProgress : nil,
                holderHeight: SocialFieldMetrics.height
            )
            .frame(maxWidth: .infinity)
            if paused {
                elapsedLabel(recorder.pausedLabelMs)
            }
        }
        .frame(maxWidth: .infinity, minHeight: SocialFieldMetrics.height)
        .padding(.leading, Tokens.Sizes.chatComposerDimensionAvatarInset)
        .padding(.trailing, Tokens.Sizes.chatComposerDimensionGlyphInsetTrailing)
    }

    private func elapsedLabel(_ milliseconds: Int) -> some View {
        Text(SocialFormat.duration(milliseconds: milliseconds))
            .dsTextStyle(TextRole.body)
            .monospacedDigit()
            .foregroundStyle(Tokens.Colors.globalTextPrimary)
            .fixedSize()
            .accessibilityLabel(Text(SocialFormat.spokenDuration(milliseconds: milliseconds)))
            .accessibilityAddTraits(.updatesFrequently)
    }

    /// The controls row `size.global.pillGap` under the field (`size.global.headerButton` high): delete — a bare
    /// `icon.global.trash` in `color.global.destructive` under the field's leading glyph; centred, a C-11 page circle with
    /// `icon.global.pause` (recording) or `icon.global.mic` (paused) in `color.global.destructive`; send — a C-11 circle in
    /// the primary fill under the field's trailing glyph.
    private var lockedControls: some View {
        let paused = recorder.phase == .paused
        let leadingCentre = Tokens.Sizes.globalScreenMargin + Tokens.Sizes.chatComposerDimensionAvatarInset + Tokens.Sizes.globalAvatarComment / 2
        let trailingCentre = Tokens.Sizes.globalScreenMargin + Tokens.Sizes.chatComposerDimensionGlyphInsetTrailing + Tokens.Sizes.globalIcon / 2
        return ZStack {
            HStack(spacing: 0) {
                SocialFieldGlyph(icon: Tokens.Icons.globalTrash, color: Tokens.Colors.globalDestructive, accessibilityLabel: Copy.chatVoiceA11yDiscard) {
                    recorder.cancel()
                }
                .padding(.leading, max(0, leadingCentre - Tokens.Sizes.globalHeaderButton / 2))
                Spacer(minLength: 0)
                CircleButton(icon: Tokens.Icons.globalSend, accessibilityLabel: Copy.chatComposerA11ySend, style: .primary) {
                    finishRecording()
                }
                .accessibilityIdentifier("chat.composer.send") // provenance-ok: accessibility identifier for UI tests
                .padding(.trailing, max(0, trailingCentre - Tokens.Sizes.globalCircleButton / 2))
            }
            Button {
                if paused { recorder.resume() } else { recorder.pause() }
            } label: {
                CircleButtonFace(icon: paused ? Tokens.Icons.globalMic : Tokens.Icons.globalPause, style: .page, glyphColor: Tokens.Colors.globalDestructive)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(paused ? Copy.chatVoiceA11yResumeRecording : Copy.chatVoiceA11yPauseRecording))
            .accessibilityIdentifier("chat.composer.pauseResume") // provenance-ok: accessibility identifier for UI tests
        }
        .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.globalHeaderButton)
    }
}

/// The reply bar above the field while replying (`chat.thread.reply.bar`): one line "Replying to {name}" (text role
/// `listSubtitle`, `color.global.textSecondary`) at the margin and a bare `icon.global.close` in the `size.global.icon`
/// box at the trailing margin (hit area `size.global.minTouchTarget.ios`).
struct ChatReplyBar: View {
    let label: String
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(label)
                .dsTextStyle(TextRole.listSubtitle)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: Tokens.Sizes.globalPillGap)
            Button(action: onCancel) {
                Glyph(Tokens.Icons.globalClose)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                    .minimumHitArea(drawn: CGSize(width: Tokens.Sizes.globalIcon, height: Tokens.Sizes.globalIcon))
            }
            .buttonStyle(.plain)
            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + SocialMetrics.metrics(TextRole.listSubtitle).capHeight / 2 }
            .accessibilityLabel(Text(Copy.chatThreadA11yCancelReply))
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}
