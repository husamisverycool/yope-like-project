// Surface: chat.voice — composition of Retro components C-06 (fill capsule), C-07 (glyph + label anatomy), C-25
// (duration format) in WhatsApp's record / play order, Telegram's elapsed time. Spec: design/surfaces/chat.voice.md.
// References: references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png (C-07 anatomy),
// references/auto/retro/store/retro-store-02.png (C-06 capsules), references/auto/retro/lazyweb/retro-lazyweb-20260529-paywall.png
// (duration format); mechanics references/auto/whatsapp/help/faq-657157755756612-send-voice-iphone.png,
// references/auto/telegram/store/telegram-store-03.png.
import AppData
import AppModels
import AppServices
@preconcurrency import AVFoundation
import DesignSystem
import SwiftUI

// MARK: - Playback (`chat.voice.layout.playback`)

/// One voice message plays at a time across the social screens (starting another stops the current one).
@MainActor
@Observable
final class SocialVoicePlayback {
    /// The message (or post voice note) playing or paused part-way.
    private(set) var currentKey: String?
    /// A message whose audio is being fetched (its capsule shows the activity indicator).
    private(set) var loadingKey: String?
    /// Messages whose audio could not play (their capsule shows `chat.voice.error.play`; a tap retries).
    private(set) var failedKeys: Set<String> = []
    @ObservationIgnored private let data: any SocialDataSource
    /// `progressInterval` paces the elapsed time label.
    let player = VoicePlayer(progressInterval: .milliseconds(250)) // provenance-ok: label refresh rate (engineering), finer than the m:ss label

    init(data: any SocialDataSource) {
        self.data = data
    }

    func isPlaying(_ key: String) -> Bool {
        currentKey == key && player.isPlaying
    }

    func isLoading(_ key: String) -> Bool { loadingKey == key }

    func hasFailed(_ key: String) -> Bool { failedKeys.contains(key) }

    /// The elapsed time while `key` plays or is paused part-way; nil when idle (the label shows the total).
    func elapsedMs(_ key: String) -> Int? {
        guard currentKey == key, player.currentURL != nil, player.progress > 0, player.progress < 1 else { return nil }
        return Int((player.progress * Double(player.durationMs)).rounded(.down))
    }

    /// Tap on a capsule: pauses it when playing, resumes it when paused part-way, else plays it from the start
    /// (stopping any other). Returns false when it could not play.
    func toggle(key: String, path: String?, localFile: URL?) async -> Bool {
        if isPlaying(key) {
            player.pause()
            return true
        }
        failedKeys.remove(key)
        if currentKey == key, let url = player.currentURL {
            do {
                try player.play(fileURL: url)
                return true
            } catch {
                failedKeys.insert(key)
                return false
            }
        }
        player.stop()
        currentKey = key
        var file = localFile
        if file == nil, let path {
            loadingKey = key
            if let url = try? await data.fileURL(path: path), let bytes = await SocialImageLoader.download(url) {
                file = try? SocialVoiceFiles.write(bytes, name: key)
            }
            if loadingKey == key { loadingKey = nil }
        }
        guard currentKey == key, let file else {
            if currentKey == key { currentKey = nil }
            failedKeys.insert(key)
            return false
        }
        do {
            try player.play(fileURL: file)
            return true
        } catch {
            currentKey = nil
            failedKeys.insert(key)
            return false
        }
    }

    func stop() {
        player.stop()
        currentKey = nil
        loadingKey = nil
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

// MARK: - Voice capsule (`chat.voice.layout.capsule`)

/// The voice message: a C-06 fill capsule laid out like C-07 — `size.global.pillPaddingLeading` → `icon.global.play`
/// (playing: `icon.global.pause`) at `size.global.iconSmall` → `size.global.pillIconGap` → the duration
/// (`chat.voice.layout.durationFormat`, monospaced digits, text role `pill`) → `size.global.pillPaddingTrailing`; height
/// `size.global.pillHeight` (grows with Dynamic Type), `radius.global.capsule`; hugs its content. Fill
/// `color.global.control` on a page, `color.global.controlOnDeep` on media (the viewer). Idle: the total length;
/// playing or paused part-way: the elapsed time. Loading: the platform activity indicator in the glyph's place. Error:
/// `chat.voice.error.play` in `color.global.destructive` in the label's place; a tap retries.
/// Accessibility: one button (`chat.voice.a11y.message` / `.messageMine`), action name play / pause.
struct VoiceCapsule: View {
    /// Playback identity (message id, or the post id for a photo's voice note).
    let key: String
    let path: String?
    var localFile: URL?
    let durationMs: Int
    var onMedia = false
    /// `chat.voice.a11y.messageMine` / `.message`.
    let accessibilityLabel: String

    private var playback: SocialVoicePlayback { SocialServices.shared.playback }

    var body: some View {
        let playing = playback.isPlaying(key)
        let failed = playback.hasFailed(key)
        Button {
            Task { _ = await playback.toggle(key: key, path: path, localFile: localFile) }
        } label: {
            HStack(spacing: Tokens.Sizes.globalPillIconGap) {
                ZStack {
                    if playback.isLoading(key) {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(Tokens.Colors.globalTextPrimary)
                    } else {
                        Glyph(playing ? Tokens.Icons.globalPause : Tokens.Icons.globalPlay, size: Tokens.Sizes.globalIconSmall, relativeTo: TextRole.pill.relativeTo)
                    }
                }
                .frame(width: SocialMetrics.scaled(Tokens.Sizes.globalIconSmall, like: TextRole.pill))
                Group {
                    if failed {
                        Text(Copy.chatVoiceErrorPlay)
                            .foregroundStyle(Tokens.Colors.globalDestructive)
                    } else {
                        Text(SocialFormat.duration(milliseconds: playback.elapsedMs(key) ?? durationMs))
                            .monospacedDigit()
                    }
                }
                .dsTextStyle(TextRole.pill)
                .lineLimit(1)
            }
            .foregroundStyle(Tokens.Colors.globalTextPrimary)
            .padding(.leading, Tokens.Sizes.globalPillPaddingLeading)
            .padding(.trailing, Tokens.Sizes.globalPillPaddingTrailing)
            .frame(minHeight: Tokens.Sizes.globalPillHeight)
            .background(onMedia ? Tokens.Colors.globalControlOnDeep : Tokens.Colors.globalControl, in: Capsule())
            .contentShape(Capsule())
            .dsAnimation(ComponentMotion.crossfade, value: playing)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityValue(Text(failed ? Copy.chatVoiceErrorPlay : ""))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text(playing ? Copy.chatVoiceA11yPause : Copy.chatVoiceA11yPlay(duration: SocialFormat.spokenDuration(milliseconds: durationMs)))) {
            Task { _ = await playback.toggle(key: key, path: path, localFile: localFile) }
        }
    }
}

// MARK: - Recording (`chat.voice.layout.recording`)

/// WhatsApp's gestures: press and hold the mic to record, lift to send, slide left to cancel, slide up onto the lock
/// to keep recording hands-free (then the trash glyph discards and the send glyph sends). No haptics (the microphone).
@MainActor
@Observable
final class SocialVoiceRecorder {
    enum Phase: Equatable {
        case idle
        /// Finger down on the mic.
        case holding
        /// Hands-free (slid onto the lock, or started by VoiceOver).
        case locked
    }

    enum Start: Equatable {
        case started
        /// The system prompt was shown; the person presses again once they answered.
        case askedPermission
        case denied
        case failed
    }

    /// `meteringInterval` paces the elapsed time.
    let recorder = VoiceRecorder(meteringInterval: .seconds(1))
    private(set) var phase: Phase = .idle
    private(set) var permission: PermissionStatus = VoiceRecorder.permission()

    var isActive: Bool { phase != .idle }
    var elapsedMs: Int { recorder.elapsedMs }

    /// Finger down on the mic (`locked`: VoiceOver's "Record" action starts hands-free).
    func begin(locked: Bool = false) -> Start {
        permission = VoiceRecorder.permission()
        if permission == .notDetermined { return .askedPermission }
        guard permission.allowsAccess else { return .denied }
        do {
            try recorder.start()
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

    /// Slide left, or the trash glyph: nothing is sent.
    func cancel() {
        recorder.cancel()
        phase = .idle
    }

    /// Lift (holding) or send (locked): the finished recording; nil when it would read 0:00 in the duration format
    /// (`chat.voice.layout.durationFormat`) — a tap is not a voice message.
    func finish() throws -> VoiceRecording? {
        defer { phase = .idle }
        guard recorder.isRecording else { return nil }
        let recording = try recorder.stop()
        guard SocialFormat.duration(milliseconds: recording.durationMs) != SocialFormat.duration(milliseconds: 0) else {
            try? FileManager.default.removeItem(at: recording.fileURL)
            return nil
        }
        return recording
    }
}
