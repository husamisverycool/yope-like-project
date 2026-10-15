// Surface: chat.voice — reference app: Yope. Spec: design/surfaces/chat.voice.md.
// References: references/auto/yope/store/yope-store-05.png (lossless; coordinates in
// references/auto/yope/frames/b-derot-store-05-rot-1.68.png) — the voice bubble "0:38".
import AppData
import AppModels
import AppServices
@preconcurrency import AVFoundation
import DesignSystem
import SwiftUI

// MARK: - Playback

/// One voice message plays at a time (`chat.voice` play circle: "tap plays from the start / pauses").
@MainActor
@Observable
final class SocialVoicePlayback {
    /// The message (or post voice note) playing now.
    private(set) var currentKey: String?
    @ObservationIgnored private let data: any SocialDataSource
    /// `progressInterval` paces `VoicePlayer.progress`, which moves the played / unplayed split of the waveform bar by
    /// bar (`chat.voice.color.waveformPlayed`).
    let player = VoicePlayer(progressInterval: .milliseconds(50)) // provenance-ok: progress sampling rate (engineering), finer than one bar

    init(data: any SocialDataSource) {
        self.data = data
    }

    func isPlaying(_ key: String) -> Bool {
        currentKey == key && player.isPlaying
    }

    /// 0…1 through `key` while it is playing or paused part-way; 0 otherwise (finished, or another message).
    func playedFraction(_ key: String) -> Double {
        guard currentKey == key, player.currentURL != nil, player.progress < 1 else { return 0 }
        return player.progress
    }

    /// Plays `key` from the start, or pauses it when it is playing. Returns false when it could not play
    /// (`chat.voice.error.play` is announced by the caller).
    func toggle(key: String, path: String?, localFile: URL?) async -> Bool {
        if isPlaying(key) {
            player.pause()
            return true
        }
        player.stop()
        currentKey = key
        var file = localFile
        if file == nil, let path, let url = try? await data.fileURL(path: path), let bytes = await SocialImageLoader.download(url) {
            file = try? SocialVoiceFiles.write(bytes, name: key)
        }
        guard currentKey == key, let file else {
            currentKey = nil
            return false
        }
        do {
            try player.play(fileURL: file)
            return true
        } catch {
            currentKey = nil
            return false
        }
    }

    func stop() {
        player.stop()
        currentKey = nil
    }
}

/// Downloaded voice / Live Photo files (temporary directory; the OS clears it).
enum SocialVoiceFiles {
    static func write(_ bytes: Data, name: String) throws -> URL {
        try writeMedia(bytes, name: "voice-" + name, fileExtension: "m4a")
    }

    static func writeMedia(_ bytes: Data, name: String, fileExtension: String) throws -> URL {
        let safe = name.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? String($0) : "_" }.joined()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("social-" + safe)
            .appendingPathExtension(fileExtension)
        if !FileManager.default.fileExists(atPath: url.path) { try bytes.write(to: url) }
        return url
    }
}

/// The recording's level envelope, computed from its samples on the receiving device (the API stores none,
/// `chat.voice` Platform notes): RMS per slice, normalized to the loudest slice.
enum VoiceEnvelope {
    /// Number of slices kept; the bubble resamples them to the bars that fit.
    static let resolution = 96

    static func levels(of fileURL: URL) async -> [Float]? {
        await Task.detached(priority: .utility) { () -> [Float]? in
            guard let file = try? AVAudioFile(forReading: fileURL) else { return nil }
            let frames = AVAudioFrameCount(file.length)
            guard frames > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames),
                  (try? file.read(into: buffer)) != nil,
                  let channel = buffer.floatChannelData?[0] else { return nil }
            let count = Int(buffer.frameLength)
            let slice = max(1, count / resolution)
            var levels: [Float] = []
            var start = 0
            while start < count {
                let end = min(count, start + slice)
                var sum: Float = 0
                for index in start..<end { sum += channel[index] * channel[index] }
                levels.append((sum / Float(end - start)).squareRoot())
                start = end
            }
            let peak = levels.max() ?? 0
            return peak > 0 ? levels.map { $0 / peak } : levels
        }.value
    }

    /// `count` bars from `levels` (the loudest slice of each bucket).
    static func bars(_ levels: [Float], count: Int) -> [Float] {
        guard count > 0 else { return [] }
        guard !levels.isEmpty else { return Array(repeating: 0, count: count) }
        return (0..<count).map { bar in
            let from = bar * levels.count / count
            let to = max(from + 1, (bar + 1) * levels.count / count)
            return levels[from..<min(to, levels.count)].max() ?? 0
        }
    }
}

// MARK: - Bubble

/// The voice message bubble (`chat.voice` Structure — playback): `chat.voice.dimension.width` ×
/// `chat.voice.dimension.height`, corners `chat.voice.radius.bubble`, fill `chat.voice.color.bubble` (mine) or
/// `chat.voice.color.bubbleTheirs`. The observed width is used for every duration (`chat.voice.layout.widthRule`
/// BLOCKED). Playing: ▶ becomes `chat.voice.icon.pause`; the bars up to the playhead draw in
/// `chat.voice.color.waveformPlayed`.
struct VoiceBubble: View {
    /// Playback identity (message id, or the post id for a photo's voice note).
    let key: String
    let path: String?
    var localFile: URL?
    let durationMs: Int
    let isMine: Bool
    /// The whole bubble's VoiceOver label (`chat.voice.a11y.messageMine` / `.message`).
    let accessibilityLabel: String
    var onPlayFailed: () -> Void = {}

    @State private var levels: [Float]?

    private var playback: SocialVoicePlayback { SocialServices.shared.playback }

    init(key: String, path: String?, localFile: URL? = nil, durationMs: Int, isMine: Bool, accessibilityLabel: String, onPlayFailed: @escaping () -> Void = {}) {
        self.key = key
        self.path = path
        self.localFile = localFile
        self.durationMs = durationMs
        self.isMine = isMine
        self.accessibilityLabel = accessibilityLabel
        self.onPlayFailed = onPlayFailed
        _levels = State(initialValue: SocialServices.shared.voiceLevels.cached(localFile?.absoluteString ?? path ?? ""))
    }

    var body: some View {
        let playing = playback.isPlaying(key)
        HStack(spacing: 0) {
            Button {
                Task {
                    let played = await playback.toggle(key: key, path: path, localFile: localFile)
                    if !played { onPlayFailed() }
                }
            } label: {
                Image(systemName: playing ? Tokens.Icons.chatVoiceIconPause : Tokens.Icons.globalPlay)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Tokens.Sizes.chatVoiceDimensionPlayGlyph)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .frame(width: Tokens.Sizes.chatVoiceDimensionPlayButton, height: Tokens.Sizes.chatVoiceDimensionPlayButton)
                    .background(Tokens.Colors.chatVoiceColorPlayButton, in: Circle())
                    .socialMinimumHitArea()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(playing ? Copy.chatVoiceA11yPause : Copy.chatVoiceA11yPlay(duration: SocialFormat.spokenDuration(milliseconds: durationMs))))
            .padding(.leading, Tokens.Sizes.chatVoiceDimensionPlayInsetLeading - (Tokens.Sizes.globalMinTouchTargetIos - Tokens.Sizes.chatVoiceDimensionPlayButton) / 2)
            .padding(.trailing, Tokens.Sizes.chatVoiceDimensionPlayToWaveform - (Tokens.Sizes.globalMinTouchTargetIos - Tokens.Sizes.chatVoiceDimensionPlayButton) / 2)

            Waveform(levels: levels, playedFraction: playback.playedFraction(key))

            Text(SocialFormat.duration(milliseconds: durationMs))
                .dsTextStyle(TextRole.caption)
                .foregroundStyle(Tokens.Colors.chatVoiceColorDuration)
                .padding(.leading, Tokens.Sizes.chatVoiceDimensionWaveformToDuration)
                .padding(.trailing, Tokens.Sizes.chatVoiceDimensionDurationTrailing)
                .accessibilityHidden(true)
        }
        .frame(width: Tokens.Sizes.chatVoiceDimensionWidth)
        .frame(minHeight: Tokens.Sizes.chatVoiceDimensionHeight)
        .background(
            isMine ? Tokens.Colors.chatVoiceColorBubble : Tokens.Colors.chatVoiceColorBubbleTheirs,
            in: RoundedRectangle(cornerRadius: Tokens.Radii.chatVoiceRadiusBubble)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(accessibilityLabel))
        .task(id: key) {
            guard levels == nil else { return }
            levels = await SocialServices.shared.voiceLevels.levels(path: path, localFile: localFile)
        }
    }
}

/// Vertical bars `chat.voice.dimension.barWidth` wide at `.barPitch`, rounded ends, heights from the level envelope
/// between `.barMinHeight` and `.barMaxHeight`, as many as fit; `chat.voice.color.waveform`, the bars up to the
/// playhead `chat.voice.color.waveformPlayed` (the split moves bar by bar, no easing). Decorative.
struct Waveform: View {
    let levels: [Float]?
    var playedFraction: Double = 0

    var body: some View {
        GeometryReader { geometry in
            let width = Tokens.Sizes.chatVoiceDimensionBarWidth
            let pitch = Tokens.Sizes.chatVoiceDimensionBarPitch
            let count = max(0, Int((geometry.size.width - width) / pitch) + 1)
            let bars = VoiceEnvelope.bars(levels ?? [], count: count)
            let low = Tokens.Sizes.chatVoiceDimensionBarMinHeight
            let high = Tokens.Sizes.chatVoiceDimensionBarMaxHeight
            let played = Int((playedFraction * Double(bars.count)).rounded(.down))
            HStack(spacing: pitch - width) {
                ForEach(Array(bars.enumerated()), id: \.offset) { index, level in
                    Capsule()
                        .fill(index < played ? Tokens.Colors.chatVoiceColorWaveformPlayed : Tokens.Colors.chatVoiceColorWaveform)
                        .frame(width: width, height: low + (high - low) * CGFloat(level))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(height: Tokens.Sizes.chatVoiceDimensionBarMaxHeight)
        .accessibilityHidden(true)
    }
}

// MARK: - Recording

/// `chat.voice.layout.recording` (WhatsApp gestures + Telegram row, MERGE_DECISIONS G-9): press and hold the mic to
/// record, lift to send, slide left to cancel, slide up onto the lock to keep recording hands-free; while locked, pause
/// stops the recording so the draft can be played, and the send circle sends it. No haptics (the microphone).
@MainActor
@Observable
final class SocialVoiceRecorder {
    enum Phase: Equatable {
        case idle
        /// Finger down on the mic.
        case holding
        /// Hands-free (slid onto the lock, or started by VoiceOver).
        case locked
        /// Locked and paused: the draft is finished and can be played before sending.
        case paused
    }

    enum Start: Equatable {
        case started
        /// The system prompt was shown; the person presses again once they answered.
        case askedPermission
        case denied
        case failed
    }

    /// `meteringInterval` paces the elapsed time (the live waveform is not drawn: not observed).
    let recorder = VoiceRecorder(meteringInterval: .seconds(1))
    private(set) var phase: Phase = .idle
    private(set) var permission: PermissionStatus = VoiceRecorder.permission()
    private(set) var draft: VoiceRecording?

    var isActive: Bool { phase != .idle }
    var elapsedMs: Int { draft?.durationMs ?? recorder.elapsedMs }

    /// Finger down on the mic (`locked`: VoiceOver's activation starts hands-free).
    func begin(locked: Bool = false) -> Start {
        permission = VoiceRecorder.permission()
        if permission == .notDetermined { return .askedPermission }
        guard permission.allowsAccess else { return .denied }
        do {
            try recorder.start()
            draft = nil
            phase = locked ? .locked : .holding
            return .started
        } catch {
            phase = .idle
            return .failed
        }
    }

    /// The system microphone prompt (first use).
    func requestPermission() async {
        permission = await VoiceRecorder.requestPermission()
    }

    func refreshPermission() {
        permission = VoiceRecorder.permission()
    }

    func lock() {
        if phase == .holding { phase = .locked }
    }

    /// Slide left (or the delete control): nothing is sent.
    func cancel() {
        recorder.cancel()
        if let draft { try? FileManager.default.removeItem(at: draft.fileURL) }
        draft = nil
        phase = .idle
    }

    /// Locked → paused: the recording stops into a draft that can be played.
    func pause() throws {
        guard phase == .locked else { return }
        draft = try recorder.stop()
        phase = .paused
    }

    /// Lift (holding) or send (locked / paused): the finished recording; nil when it would read 00:00 in the timer
    /// (`chat.voice.layout.durationFormat`) — a tap is not a voice message.
    func finish() throws -> VoiceRecording? {
        defer { phase = .idle }
        let recording: VoiceRecording
        if phase == .paused, let draft {
            recording = draft
            self.draft = nil
        } else {
            guard recorder.isRecording else { return nil }
            recording = try recorder.stop()
        }
        guard SocialFormat.duration(milliseconds: recording.durationMs) != SocialFormat.duration(milliseconds: 0) else {
            try? FileManager.default.removeItem(at: recording.fileURL)
            return nil
        }
        return recording
    }
}

/// The composer row while recording (`chat.voice.layout.recording.row`): red dot (`color.global.destructive`) · elapsed
/// time (`chat.voice.layout.durationFormat`, `color.global.textPrimary`) · the centred hint ‹ "slide to cancel"
/// (`color.global.textSecondary`), following the finger. Timer and hint take the text role of the field they replace
/// (body); the dot is as tall as the timer's capitals; spacing is the platform default (not measured). Hands-free: the
/// hint's place holds pause (`chat.voice.icon.pause`) — then ▶ plays the draft — and a delete control leads the row
/// (approximation: the token names no discard control once locked).
struct VoiceRecordingRow: View {
    let recorder: SocialVoiceRecorder
    /// The finger's horizontal travel (≤ 0 moves the hint with it).
    let slide: CGFloat
    let onCancel: () -> Void

    private static let draftKey = "voice-draft" // provenance-ok: playback key, not UI text

    private var playback: SocialVoicePlayback { SocialServices.shared.playback }

    var body: some View {
        HStack {
            if recorder.phase != .holding {
                glyphButton(Tokens.Icons.photoViewerIconDelete, label: Copy.chatThreadMenuDelete, color: Tokens.Colors.globalDestructive) {
                    playback.stop()
                    onCancel()
                }
            }
            if recorder.phase != .paused {
                Circle()
                    .fill(Tokens.Colors.globalDestructive)
                    .frame(width: SocialMetrics.capHeight(SocialText.recordingRow), height: SocialMetrics.capHeight(SocialText.recordingRow))
                    .accessibilityHidden(true)
            }
            Text(SocialFormat.duration(milliseconds: recorder.elapsedMs))
                .dsTextStyle(SocialText.recordingRow)
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .accessibilityLabel(Text(SocialFormat.spokenDuration(milliseconds: recorder.elapsedMs)))
            Spacer(minLength: 0)
            center
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.chatComposerDimensionFieldHeight)
    }

    @ViewBuilder
    private var center: some View {
        switch recorder.phase {
        case .holding, .idle:
            HStack {
                Image(systemName: Tokens.Icons.globalBack)
                Text(Copy.chatVoiceRecordingSlideToCancel)
            }
            .dsTextStyle(SocialText.recordingRow)
            .foregroundStyle(Tokens.Colors.globalTextSecondary)
            .offset(x: min(0, slide))
            .accessibilityElement(children: .combine)
        case .locked:
            glyphButton(Tokens.Icons.chatVoiceIconPause, label: Copy.chatVoiceA11yPause, color: Tokens.Colors.globalTextPrimary) {
                do { try recorder.pause() } catch { recorder.cancel() }
            }
        case .paused:
            let playing = playback.isPlaying(Self.draftKey)
            glyphButton(
                playing ? Tokens.Icons.chatVoiceIconPause : Tokens.Icons.globalPlay,
                label: playing ? Copy.chatVoiceA11yPause : Copy.chatVoiceA11yPlay(duration: SocialFormat.spokenDuration(milliseconds: recorder.elapsedMs)),
                color: Tokens.Colors.globalTextPrimary
            ) {
                guard let file = recorder.draft?.fileURL else { return }
                Task { _ = await playback.toggle(key: Self.draftKey, path: nil, localFile: file) }
            }
        }
    }

    /// A bare glyph at the mic glyph's height (the control it sits beside), 44-pt hit area.
    private func glyphButton(_ icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(height: Tokens.Sizes.chatComposerDimensionMicGlyph)
                .foregroundStyle(color)
                .socialMinimumHitArea()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

/// The lock above the mic while holding (`chat.voice.layout.recording.lock`): `icon.global.lock` over the "slide up" hint
/// glyph (`lockHintGlyphIos`), `color.global.textSecondary`, at the timer's text size. Decorative.
struct VoiceLockHint: View {
    var body: some View {
        VStack {
            Image(systemName: Tokens.Icons.globalLock)
            Image(systemName: Tokens.Layouts.ChatVoiceLayoutRecording.lockHintGlyphIos)
        }
        .dsTextStyle(SocialText.recordingRow)
        .foregroundStyle(Tokens.Colors.globalTextSecondary)
        .accessibilityHidden(true)
    }
}
