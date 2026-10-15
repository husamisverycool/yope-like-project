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
    /// `progressInterval` paces `VoicePlayer.progress`, which nothing draws: the playing state's progress visual is
    /// BLOCKED (`chat.voice.color.waveformPlayed`).
    let player = VoicePlayer(progressInterval: .seconds(1))

    init(data: any SocialDataSource) {
        self.data = data
    }

    func isPlaying(_ key: String) -> Bool {
        currentKey == key && player.isPlaying
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
/// `chat.voice.dimension.height`, corners `chat.voice.radius.bubble`, fill `chat.voice.color.bubble` (mine; another
/// member's fill is BLOCKED, `chat.voice.color.bubbleTheirs`: their bubble is drawn without a fill). The observed
/// width is used for every duration (`chat.voice.layout.widthRule` BLOCKED). Playing: the pause glyph and the played
/// colour are BLOCKED (`chat.voice.icon.pause`, `chat.voice.color.waveformPlayed`): the ▶ stays; VoiceOver hears
/// "pause".
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
                Image(systemName: playing ? (SocialBlocked.pauseIcon ?? Tokens.Icons.globalPlay) : Tokens.Icons.globalPlay)
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

            Waveform(levels: levels)

            Text(SocialFormat.duration(milliseconds: durationMs))
                .dsTextStyle(TextRole.caption)
                .foregroundStyle(Tokens.Colors.chatVoiceColorDuration)
                .padding(.leading, Tokens.Sizes.chatVoiceDimensionWaveformToDuration)
                .padding(.trailing, Tokens.Sizes.chatVoiceDimensionDurationTrailing)
                .accessibilityHidden(true)
        }
        .frame(width: Tokens.Sizes.chatVoiceDimensionWidth)
        .frame(minHeight: Tokens.Sizes.chatVoiceDimensionHeight)
        .background {
            if let fill = isMine ? Tokens.Colors.chatVoiceColorBubble : SocialBlocked.voiceBubbleTheirs {
                RoundedRectangle(cornerRadius: Tokens.Radii.chatVoiceRadiusBubble).fill(fill)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(accessibilityLabel))
        .task(id: key) {
            guard levels == nil else { return }
            levels = await SocialServices.shared.voiceLevels.levels(path: path, localFile: localFile)
        }
    }
}

/// Vertical bars `chat.voice.dimension.barWidth` wide at `.barPitch`, rounded ends, heights from the level envelope
/// between `.barMinHeight` and `.barMaxHeight`, `chat.voice.color.waveform`, as many as fit. Decorative.
struct Waveform: View {
    let levels: [Float]?

    var body: some View {
        GeometryReader { geometry in
            let width = Tokens.Sizes.chatVoiceDimensionBarWidth
            let pitch = Tokens.Sizes.chatVoiceDimensionBarPitch
            let count = max(0, Int((geometry.size.width - width) / pitch) + 1)
            let bars = VoiceEnvelope.bars(levels ?? [], count: count)
            let low = Tokens.Sizes.chatVoiceDimensionBarMinHeight
            let high = Tokens.Sizes.chatVoiceDimensionBarMaxHeight
            HStack(spacing: pitch - width) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(Tokens.Colors.chatVoiceColorWaveform)
                        .frame(width: width, height: low + (high - low) * CGFloat(level))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(height: Tokens.Sizes.chatVoiceDimensionBarMaxHeight)
        .accessibilityHidden(true)
    }
}

// MARK: - Recording (BLOCKED)

#if DEBUG
/// `chat.voice.layout.recording` is BLOCKED (hold vs tap, lock, cancel, live waveform, timer). DEBUG builds record
/// with a tap on the mic and send with a second tap, so the permission card, upload and send can be reviewed; no
/// recording UI is drawn. Release builds have no mic circle (chat.composer: the mic's only function is BLOCKED).
@MainActor
@Observable
final class SocialVoiceRecording {
    /// `meteringInterval` paces the live level samples, which nothing draws (the live waveform is BLOCKED).
    let recorder = VoiceRecorder(meteringInterval: .seconds(1))
    private(set) var permission: PermissionStatus = VoiceRecorder.permission()

    var isRecording: Bool { recorder.isRecording }

    /// First tap asks for the microphone (system prompt) and starts; a second tap stops and returns the file.
    func toggle() async -> Result<VoiceRecording?, Error> {
        if recorder.isRecording {
            do {
                return .success(try recorder.stop())
            } catch {
                return .failure(error)
            }
        }
        permission = await VoiceRecorder.requestPermission()
        guard permission.allowsAccess else { return .success(nil) }
        do {
            try recorder.start()
            return .success(nil)
        } catch {
            return .failure(error)
        }
    }

    func refreshPermission() {
        permission = VoiceRecorder.permission()
    }
}
#endif
