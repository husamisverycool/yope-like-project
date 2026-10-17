// Surface: camera.sendto — visual reference Retro's Postcard composer, mechanics Locket (send to many, save, send states).
// Reference images: references/auto/retro/store/retro-store-03.png, references/auto/retro/press/tc-2023-12-retro3.png
// phones 2–3, references/owner/locket-review-sendto.jpg, -review-sending.jpg, -review-sent.jpg
// (design/surfaces/camera.sendto.md; MERGE_DECISIONS RC-5 … RC-8).
// Choose one or more groups, an optional message and voice note, send. No mandatory edit step. The composer waits for
// the send (busy capsule, "Sending…"); a failure keeps everything and shows the native alert.
import AppData
import AppModels
import DesignSystem
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class SendToModel: Identifiable {
    /// `chat.voice.layout.recording`: press and hold the mic to record, lift to keep the note, slide left
    /// to cancel, slide up onto the lock for hands-free; while locked, pause keeps a draft that can be
    /// previewed, continued or deleted (`chat.voice.layout.locked`); the mic capsule (showing send) keeps it.
    enum VoicePhase: Equatable {
        case idle
        /// Finger down on the mic.
        case holding
        /// Hands-free (slid onto the lock, or started by VoiceOver).
        case locked
        /// Locked and paused: the draft can be previewed, continued, deleted or kept.
        case paused
    }

    enum ListState: Equatable {
        /// Before the offline cache answered: nothing is drawn, so cached groups appear without a
        /// spinner frame first.
        case idle
        case loading
        case loaded
        /// The member has no groups.
        case empty
        /// No cached groups and no connection.
        case offline
        /// No cached groups and the request failed.
        case failed
    }

    let id = UUID()
    let media: CapturedMedia
    /// The group from context; nil = no context (all groups preselected).
    let contextGroupID: String?

    private(set) var listState: ListState = .idle
    /// The capture decoded off the main actor at the preview card's size.
    private(set) var previewImage: UIImage? = nil
    private(set) var groups: [CaptureGroup] = []
    /// Selected group ids in list order.
    private(set) var selection: [String] = []
    private(set) var covers: [String: UIImage] = [:]
    /// Each group's daily invitation open when the list loaded (`open_invitations`, migration 0035), by group id: its row
    /// counts down to `closes_at`, and a post sent while it is open answers it as from the notification. Nothing marks
    /// a post sent after (tenet 5).
    private(set) var openInvitations: [String: DailyInvitation] = [:]
    var caption = ""
    /// The voice note attached to the post (optional; it goes on every chosen group's post).
    private(set) var voiceNote: VoiceNote? = nil
    /// The recorder's state (`chat.voice.layout.recording`).
    private(set) var voicePhase: VoicePhase = .idle
    private(set) var isPremium = false
    /// While the capture uploads and `create_post` runs (busy capsule, title "Sending…", controls disabled).
    private(set) var isSending = false
    /// The last send's failure, shown as the native alert until Try Again or Cancel.
    private(set) var sendFailure: CaptureSendCenter.Failure? = nil
    /// Increments on every recipient toggle (`haptic.global.select` trigger).
    private(set) var selectionChanges = 0

    private let groupSource: CaptureGroupSource
    private let premium: CapturePremium
    private let library: CaptureLibrary
    private let voice: CaptureVoiceRecorder
    private let sendCenter: CaptureSendCenter
    private let navigation: CaptureNavigation
    private let onClose: @MainActor () -> Void
    private let onSent: @MainActor () -> Void
    /// The post being replied to when the camera was opened from `photo.viewer` for a group
    /// (social's `PhotoReplyHandoff`), and its reset once the reply is sent.
    private let replyTarget: @MainActor (String?) -> String?
    private let clearReply: @MainActor () -> Void
    @ObservationIgnored private var didPreselect = false

    init(
        media: CapturedMedia,
        contextGroupID: String?,
        groups: CaptureGroupSource,
        premium: CapturePremium,
        library: CaptureLibrary,
        voice: CaptureVoiceRecorder,
        sendCenter: CaptureSendCenter,
        navigation: CaptureNavigation,
        onClose: @escaping @MainActor () -> Void,
        onSent: @escaping @MainActor () -> Void,
        replyTarget: @escaping @MainActor (String?) -> String? = { PhotoReplyHandoff.replyTarget(for: $0)?.rawValue },
        clearReply: @escaping @MainActor () -> Void = { PhotoReplyHandoff.clear() }
    ) {
        self.media = media
        self.contextGroupID = contextGroupID
        groupSource = groups
        self.premium = premium
        self.library = library
        self.voice = voice
        self.sendCenter = sendCenter
        self.navigation = navigation
        self.onClose = onClose
        self.onSent = onSent
        self.replyTarget = replyTarget
        self.clearReply = clearReply
    }

    // MARK: Derived state

    /// The longest message (`camera.sendto.size.captionMaxLength` 250, the counter's {max}).
    static var captionMaxLength: Int { Int(Tokens.Counts.cameraSendtoSizeCaptionMaxLength) }

    /// A message was added (blank text is no message).
    var hasMessage: Bool { !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Closing asks first only when a message or a voice note would be lost (Retro's lost-changes warning, RC-8).
    var needsDiscardConfirmation: Bool { hasMessage || voiceNote != nil || voicePhase != .idle }

    /// Keeps the caption within `captionMaxLength` (called as the member types).
    func clampCaption() {
        if caption.count > Self.captionMaxLength {
            caption = String(caption.prefix(Self.captionMaxLength))
        }
    }

    var isRecordingVoice: Bool { voicePhase == .holding || voicePhase == .locked }

    /// The recorder row replaces the message field while recording, with a draft or an attached note.
    var showsVoiceRow: Bool { voicePhase != .idle || voiceNote != nil }

    /// Elapsed time of the recording, or the length of the paused draft / attached note.
    var voiceElapsedMs: Int {
        if voicePhase == .idle, let voiceNote { return voiceNote.durationMs }
        return voice.elapsedMs
    }

    var isPlayingVoice: Bool { voice.isPlaying }

    /// The live / paused draft's waveform (C-36).
    var voiceLevels: [Int] { voice.levels }

    /// The attached note is playing.
    var isPlayingNote: Bool { voice.isPlaying && voiceNote != nil && voice.playingFile == voiceNote?.fileURL }

    /// 0…1 of the attached note while it plays or is paused part-way (its played bars); nil when idle.
    var noteProgress: Double? {
        guard let voiceNote, voice.playingFile == voiceNote.fileURL else { return nil }
        return voice.playbackProgress
    }

    /// 0…1 of the paused draft's preview; nil when it is not playing or paused part-way.
    var draftProgress: Double? {
        voicePhase == .paused ? voice.playbackProgress : nil
    }

    /// A video needs premium at `create_post`; a free member's video cannot be sent.
    var isMediaSendable: Bool { !media.needsPremium || isPremium }

    /// The send capsule is enabled with at least one group and sendable media (disabled #4D4D4D otherwise, Retro's
    /// disabled Send Postcard).
    var canSend: Bool { !selection.isEmpty && isMediaSendable }

    var canCreateGroup: Bool { navigation.canCreateGroup }

    /// A photo reply to a photo carries its target only when it goes to exactly that post's group
    /// (`create_post`: `reply_group_mismatch` otherwise); sent to more groups it is an ordinary post.
    var replyToPostID: String? {
        guard let contextGroupID, selection == [contextGroupID] else { return nil }
        return replyTarget(contextGroupID)
    }

    func isSelected(_ groupID: String) -> Bool {
        selection.contains(groupID)
    }

    /// The open invitation `groupID`'s row shows: none for a photo reply (a reply is not an answer).
    func shownInvitation(for groupID: String) -> DailyInvitation? {
        replyToPostID == nil ? openInvitations[groupID] : nil
    }

    /// The chosen groups' invitations still open at `date` (device clock; the server decides at `create_post`).
    func answeredInvitations(at date: Date) -> [String] {
        selection.compactMap { groupID in
            guard let invitation = shownInvitation(for: groupID),
                  CountdownState(opensAt: invitation.firesAt, closesAt: invitation.closesAt, now: date).isOpen else { return nil }
            return invitation.id.rawValue
        }
    }

    // MARK: Loading

    func load() async {
        async let decoded = decodePreview()
        isPremium = await premium.isPremium()
        if let cached = await groupSource.cachedGroups(), !cached.isEmpty {
            apply(cached)
        } else if listState == .idle {
            listState = .loading
        }
        previewImage = await decoded
        do {
            apply(try await groupSource.loadGroups())
            let open = await groupSource.openInvitations()
            openInvitations = Dictionary(open.map { ($0.groupID.rawValue, $0) }, uniquingKeysWith: { first, _ in first })
        } catch {
            guard groups.isEmpty else { return }
            let offline = groupSource.isOffline || DataError.from(error) == .offline
            listState = offline ? .offline : .failed
        }
    }

    func reload() async {
        if groups.isEmpty { listState = .loading }
        await load()
    }

    private func decodePreview() async -> UIImage? {
        if let previewImage { return previewImage }
        guard let data = media.still?.imageData else { return nil }
        let side = CaptureImageDecoder.pixels(Tokens.Layouts.CameraSendtoLayoutPreview.maxHeight)
        return await CaptureImageDecoder.image(data: data, maxPixelSize: side)
    }

    private func apply(_ list: [CaptureGroup]) {
        groups = list
        listState = list.isEmpty ? .empty : .loaded
        let ids = Set(list.map(\.id))
        if didPreselect {
            selection = list.map(\.id).filter { selection.contains($0) }
        } else {
            didPreselect = true
            if let contextGroupID {
                // A group the member left or that was deleted is not preselected.
                selection = ids.contains(contextGroupID) ? [contextGroupID] : []
            } else {
                // No context: every group (references preselect everyone; owner to confirm).
                selection = list.map(\.id)
            }
        }
        for group in list where covers[group.id] == nil {
            guard let path = group.coverPath else { continue }
            Task { [weak self] in
                guard let self, let image = await self.groupSource.coverImage(path: path) else { return }
                self.covers[group.id] = image
            }
        }
    }

    // MARK: Actions

    func toggle(_ groupID: String) {
        guard !isSending else { return }
        if let index = selection.firstIndex(of: groupID) {
            selection.remove(at: index)
        } else {
            let order = groups.map(\.id)
            selection = order.filter { $0 == groupID || selection.contains($0) }
        }
        selectionChanges += 1
    }

    /// Upload + `create_post` while the composer waits (camera.sendto "sending"). Posted: the composer closes (`onSent`),
    /// with `haptic.global.send` and the confirmation announced (iOS, C-26). Failed: everything stays and the alert shows.
    func send() async {
        guard canSend, !isSending else { return }
        if voicePhase != .idle { await keepVoiceRecording() }
        voice.stopPlayback()
        sendFailure = nil
        isSending = true
        let names = groups.filter { selection.contains($0.id) }.map(\.name)
        let answering = answeredInvitations(at: Date())
        let request = CaptureSendRequest(
            payload: .media(media),
            groupIDs: selection,
            caption: hasMessage ? caption : nil,
            voice: voiceNote,
            invitationIDs: answering.isEmpty ? nil : answering,
            confirmation: names.count == 1 ? Copy.cameraSendtoToastPostedOne(group: names[0]) : Copy.cameraSendtoToastPostedMany,
            replyToPostID: replyToPostID
        )
        let outcome = await sendCenter.send(request)
        isSending = false
        switch outcome {
        case .posted:
            clearReply()
            onSent()
        case let .failed(failure):
            sendFailure = failure
        }
    }

    /// The alert's Try Again.
    func retrySend() async {
        sendFailure = nil
        await send()
    }

    /// The alert's Cancel: keeps the capture, message, voice note and selection.
    func dismissSendFailure() {
        sendFailure = nil
    }

    /// ✕ (after the discard alert when a message or voice note exists): discards the capture, message and voice note;
    /// back to the camera.
    func close() {
        guard !isSending else { return }
        cancelVoiceRecording()
        removeVoiceNote()
        onClose()
    }

    /// Save: the photo / Live Photo / video with add-only access, confirmed by `camera.sendto.toast.saved` (iOS: an
    /// accessibility announcement, C-26).
    func save() async {
        guard !isSending else { return }
        do {
            try await library.save(media)
            sendCenter.confirm(Copy.cameraSendtoToastSaved)
        } catch {
            // Add-only access refused: the system-settings path belongs to system.permissions.
        }
    }

    // MARK: Voice note (optional; the note goes on every chosen group's post)

    /// Finger down on the mic (`locked`: VoiceOver's activation records hands-free). Microphone
    /// permission is asked here at first use (App Review 5.1.1(iv)); the system prompt ends the hold,
    /// so the member presses again once they answered.
    @discardableResult
    func beginVoiceRecording(locked: Bool = false) async -> Bool {
        guard voicePhase == .idle else { return false }
        let status = voice.permission()
        if status == .notDetermined {
            _ = await voice.requestPermission()
            return false
        }
        guard status.allowsAccess else {
            // Microphone denied: the system-settings path (owned by system.permissions).
            navigation.openSystemSettings()
            return false
        }
        voice.stopPlayback()
        do {
            try voice.start()
            voicePhase = locked ? .locked : .holding
            return true
        } catch {
            voicePhase = .idle
            return false
        }
    }

    /// Slide up onto the lock: recording continues hands-free.
    func lockVoiceRecording() {
        if voicePhase == .holding { voicePhase = .locked }
    }

    /// Slide left (or delete while locked / paused): the recording is discarded.
    func cancelVoiceRecording() {
        voice.stopPlayback()
        voice.cancel()
        voicePhase = .idle
    }

    /// Locked → paused (`chat.voice.a11y.pauseRecording`): the draft can be previewed, continued, deleted or kept.
    func pauseVoiceRecording() {
        guard voicePhase == .locked else { return }
        voice.pause()
        voicePhase = .paused
    }

    /// Paused → locked (`chat.voice.a11y.resumeRecording`): recording continues at the end of the draft.
    func resumeVoiceRecording() {
        guard voicePhase == .paused else { return }
        voice.stopPlayback()
        do {
            try voice.resume()
            voicePhase = .locked
        } catch {
            // The draft stays paused (it can still be kept or deleted).
        }
    }

    /// Lift (holding) or the send capsule (locked / paused): the recording becomes the post's voice
    /// note, replacing an earlier one. A recording that reads 00:00 is not a note.
    func keepVoiceRecording() async {
        guard voicePhase != .idle else { return }
        voice.stopPlayback()
        voicePhase = .idle
        guard let recording = try? await voice.stop() else { return }
        guard recording.durationMs >= 1000 else {
            try? FileManager.default.removeItem(at: recording.fileURL)
            return
        }
        removeVoiceNote()
        voiceNote = recording
    }

    /// Delete on the attached note.
    func removeVoiceNote() {
        voice.stopPlayback()
        if let voiceNote { try? FileManager.default.removeItem(at: voiceNote.fileURL) }
        voiceNote = nil
    }

    /// ▶ / pause on the attached note.
    func toggleVoicePlayback() {
        guard let file = voiceNote?.fileURL else { return }
        voice.togglePlayback(file)
    }

    /// ▶ / pause on the paused draft (the preview): the first tap makes the draft playable.
    func toggleDraftPreview() async {
        guard voicePhase == .paused else { return }
        if let playing = voice.playingFile {
            voice.togglePlayback(playing)
            return
        }
        guard let draft = try? await voice.draftFile(), voicePhase == .paused else { return }
        voice.togglePlayback(draft)
    }
}
