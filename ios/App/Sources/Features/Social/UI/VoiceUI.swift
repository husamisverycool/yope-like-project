// Surface: chat.voice — composition of Retro components C-06 (fill capsule), C-07 (glyph + label anatomy), C-36 (voice
// waveform, owner decision 16), C-25 (duration format) in WhatsApp's record / play order, Apple Messages' play · waveform ·
// duration row, Telegram's elapsed time and played bars. Spec: design/surfaces/chat.voice.md.
// References: references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png (C-07 anatomy),
// references/auto/retro/store/retro-store-02.png (C-06 capsules), references/auto/retro/lazyweb/retro-lazyweb-20260529-paywall.png
// (duration format), references/auto/imessage/apple-support/messages-audio-message-ios27.png (waveform row);
// mechanics references/auto/whatsapp/help/faq-657157755756612-send-voice-iphone.png,
// references/auto/whatsapp/blog/whatsapp-blog-2022-03-voice-updates.png (locked recording, draft preview),
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
    /// Waveforms computed on the device for notes stored without levels, once their audio was downloaded (C-36
    /// fallback, `layout.global.waveform.fallback`).
    private(set) var computedLevels: [String: [Int]] = [:]
    @ObservationIgnored private let data: any SocialDataSource
    /// `progressInterval` paces the elapsed label and the played bars (C-36: a 2-s note's 38 bars each get a tick).
    let player = VoicePlayer(progressInterval: .milliseconds(50)) // provenance-ok: progress refresh rate (engineering), at least once per bar of a 2-s note

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
        guard let progress = progress(key) else { return nil }
        return Int((progress * Double(player.durationMs)).rounded(.down))
    }

    /// 0…1 of `key` while it plays or is paused part-way (the played bars); nil when idle.
    func progress(_ key: String) -> Double? {
        guard currentKey == key, player.currentURL != nil else { return nil }
        if player.isPlaying { return player.progress }
        return player.progress > 0 && player.progress < 1 ? player.progress : nil
    }

    /// Tap on a capsule: pauses it when playing, resumes it when paused part-way, else plays it from the start
    /// (stopping any other). `needsLevels`: the note has no stored waveform — once its file is here, its levels are
    /// computed and kept (`computedLevels`). Returns false when it could not play.
    func toggle(key: String, path: String?, localFile: URL?, needsLevels: Bool = false) async -> Bool {
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
        if needsLevels, computedLevels[key] == nil {
            Task { [weak self] in
                guard let levels = await VoiceFileLevels.levels(of: file) else { return }
                self?.computedLevels[key] = levels
            }
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
/// (playing: `icon.global.pause`) at `size.global.iconSmall` → `size.global.pillIconGap` → the C-36 waveform
/// (`chat.voice.dimension.waveform` long; played bars follow the playback) → `size.global.pillIconGap` → the duration
/// (`chat.voice.layout.durationFormat`, monospaced digits, text role `pill`) → `size.global.pillPaddingTrailing`; height
/// `size.global.pillHeight` (grows with Dynamic Type), `radius.global.capsule`; hugs its content. Fill
/// `color.global.control` on a page, `color.global.controlOnDeep` on media (the viewer). Idle: the total length and every
/// bar unplayed; playing or paused part-way: the elapsed time and the played bars. Loading: the platform activity
/// indicator in the glyph's place. Error: `chat.voice.error.play` in `color.global.destructive` in the waveform's and the
/// label's place; a tap retries. Accessibility: one button (`chat.voice.a11y.message` / `.messageMine`), action name
/// play / pause; the waveform is decorative.
struct VoiceCapsule: View {
    /// Playback identity (message id, or the post id for a photo's voice note).
    let key: String
    let path: String?
    var localFile: URL?
    let durationMs: Int
    /// The note's stored waveform (`voice_levels`); nil → dots until it was played once (C-36 fallback).
    var levels: [Int]?
    var onMedia = false
    /// `chat.voice.a11y.messageMine` / `.message`.
    let accessibilityLabel: String

    private var playback: SocialVoicePlayback { SocialServices.shared.playback }

    var body: some View {
        let playing = playback.isPlaying(key)
        let failed = playback.hasFailed(key)
        Button {
            Task { _ = await playback.toggle(key: key, path: path, localFile: localFile, needsLevels: levels == nil) }
        } label: {
            HStack(spacing: Tokens.Sizes.globalPillIconGap) {
                ZStack {
                    if playback.isLoading(key) {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(onMedia ? Tokens.Colors.globalTextOnMedia : Tokens.Colors.globalTextPrimary)
                    } else {
                        Glyph(playing ? Tokens.Icons.globalPause : Tokens.Icons.globalPlay, size: Tokens.Sizes.globalIconSmall, relativeTo: TextRole.pill.relativeTo)
                    }
                }
                .frame(width: SocialMetrics.scaled(Tokens.Sizes.globalIconSmall, like: TextRole.pill))
                if failed {
                    Text(Copy.chatVoiceErrorPlay)
                        .foregroundStyle(Tokens.Colors.globalDestructive)
                        .dsTextStyle(TextRole.pill)
                        .lineLimit(1)
                } else {
                    VoiceWaveform(
                        levels: levels ?? playback.computedLevels[key],
                        progress: playback.progress(key),
                        onMedia: onMedia,
                        holderHeight: SocialMetrics.scaled(Tokens.Sizes.globalPillHeight, like: TextRole.pill)
                    )
                    .frame(width: Tokens.Sizes.chatVoiceDimensionWaveform)
                    Text(SocialFormat.duration(milliseconds: playback.elapsedMs(key) ?? durationMs))
                        .monospacedDigit()
                        .dsTextStyle(TextRole.pill)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(onMedia ? Tokens.Colors.globalTextOnMedia : Tokens.Colors.globalTextPrimary)
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
            Task { _ = await playback.toggle(key: key, path: path, localFile: localFile, needsLevels: levels == nil) }
        }
    }
}

// MARK: - Recording (`chat.voice.layout.recording`, `chat.voice.layout.locked`)

/// WhatsApp's gestures: press and hold the mic to record, lift to send, slide left to cancel, slide up onto the lock
/// to keep recording hands-free. Locked: pause stops into a draft that can be played (preview), continued, deleted or
/// sent (`chat.voice.layout.locked`; WhatsApp "tap [pause] to pause recording and preview a draft … Tap [mic] to
/// continue recording"). No haptics (the microphone).
@MainActor
@Observable
final class SocialVoiceRecorder {
    enum Phase: Equatable {
        case idle
        /// Finger down on the mic.
        case holding
        /// Hands-free (slid onto the lock, or started by VoiceOver).
        case locked
        /// Locked and paused: the draft can be previewed, continued, deleted or sent.
        case paused
    }

    enum Start: Equatable {
        case started
        /// The system prompt was shown; the person presses again once they answered.
        case askedPermission
        case denied
        case failed
    }

    let recorder = VoiceRecorder()
    /// Plays the paused draft (`chat.voice.layout.locked` preview).
    let preview = VoicePlayer(progressInterval: .milliseconds(50)) // provenance-ok: progress refresh rate (engineering), at least once per bar of a 2-s draft
    private(set) var phase: Phase = .idle
    private(set) var permission: PermissionStatus = VoiceRecorder.permission()
    /// Snapshot tests (`showRecordingForSnapshot`, DEBUG): the elapsed time and waveform without a microphone.
    @ObservationIgnored private var snapshotElapsedMs: Int?
    @ObservationIgnored private var snapshotLevels: [Int]?
    @ObservationIgnored private var snapshotPreviewProgress: Double?

    var isActive: Bool { phase != .idle }
    /// Hands-free: the field shows the waveform and the controls row shows (`chat.voice.layout.locked`).
    var isLocked: Bool { phase == .locked || phase == .paused }

    var elapsedMs: Int {
        snapshotElapsedMs ?? recorder.elapsedMs
    }

    /// The live (recording) or draft (paused) waveform.
    var levels: [Int] {
        snapshotLevels ?? recorder.levels
    }

    var isPreviewing: Bool { preview.isPlaying }

    /// 0…1 of the draft while it plays or is paused part-way; nil otherwise.
    var previewProgress: Double? {
        if let snapshotPreviewProgress { return snapshotPreviewProgress }
        guard preview.currentURL != nil else { return nil }
        if preview.isPlaying { return preview.progress }
        return preview.progress > 0 && preview.progress < 1 ? preview.progress : nil
    }

    /// The paused field's label: the elapsed preview time while previewing, else the draft's length.
    var pausedLabelMs: Int {
        guard let progress = previewProgress else { return elapsedMs }
        return Int((progress * Double(elapsedMs)).rounded(.down))
    }

    /// Finger down on the mic (`locked`: VoiceOver's "Record" action starts hands-free).
    func begin(locked: Bool = false) -> Start {
        permission = VoiceRecorder.permission()
        if permission == .notDetermined { return .askedPermission }
        guard permission.allowsAccess else { return .denied }
        SocialServices.shared.playback.stop()
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

    /// Locked → paused (`chat.voice.a11y.pauseRecording`).
    func pause() {
        guard phase == .locked else { return }
        recorder.pause()
        phase = .paused
    }

    /// Paused → locked, recording at the end of the draft (`chat.voice.a11y.resumeRecording`). False when the recorder
    /// could not continue (the draft stays paused).
    @discardableResult
    func resume() -> Bool {
        guard phase == .paused else { return false }
        preview.stop()
        do {
            try recorder.resume()
            phase = .locked
            return true
        } catch {
            return false
        }
    }

    /// Paused: plays / pauses the draft from its start.
    func togglePreview() async {
        guard phase == .paused else { return }
        if preview.isPlaying {
            preview.pause()
            return
        }
        if let current = preview.currentURL {
            try? preview.play(fileURL: current)
            return
        }
        guard let draft = try? await recorder.draftFile(), phase == .paused else { return }
        try? preview.play(fileURL: draft)
    }

    #if DEBUG
    /// Snapshot tests: the composer's recording rows without a microphone.
    func showRecordingForSnapshot(_ phase: Phase, elapsedMs: Int = 0, levels: [Int]? = nil, previewProgress: Double? = nil) {
        self.phase = phase
        snapshotElapsedMs = elapsedMs
        snapshotLevels = levels
        snapshotPreviewProgress = previewProgress
    }
    #endif

    /// Slide left, or the trash glyph: nothing is sent.
    func cancel() {
        preview.stop()
        recorder.cancel()
        phase = .idle
    }

    /// Lift (holding) or send (locked / paused): the finished recording; nil when it would read 0:00 in the duration
    /// format (`chat.voice.layout.durationFormat`) — a tap is not a voice message.
    func finish() async throws -> VoiceRecording? {
        preview.stop()
        phase = .idle
        guard recorder.isRecording else { return nil }
        let recording = try await recorder.stop()
        guard SocialFormat.duration(milliseconds: recording.durationMs) != SocialFormat.duration(milliseconds: 0) else {
            try? FileManager.default.removeItem(at: recording.fileURL)
            return nil
        }
        return recording
    }
}
