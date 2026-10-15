// Surface: camera.sendto — reference app: Yope (+ Locket default audience, C-5).
// Reference images: references/auto/yope/frames/a-chuongxetank-7694968408424582452-t6.73-sendto-voice-tooltip.png,
// a-savannahclooney-7683341732695592206-t5.73-sendto-caption-keyboard.png,
// a-virgi-7686278541255642390-t56.23-sendto-three-selected-es.png (design/surfaces/camera.sendto.md).
// Choose one or more groups, optional caption and voice note, send. No mandatory edit step.
import AppData
import AppModels
import DesignSystem
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class SendToModel: Identifiable {
    enum ListState: Equatable {
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

    private(set) var listState: ListState = .loading
    private(set) var groups: [CaptureGroup] = []
    /// Selected group ids in list order.
    private(set) var selection: [String] = []
    private(set) var covers: [String: UIImage] = [:]
    var caption = ""
    private(set) var voiceNote: VoiceNote? = nil
    private(set) var isRecordingVoice = false
    private(set) var showsVoiceCoach = false
    private(set) var isPremium = false
    /// Increments on every recipient toggle (`haptic.global.select` trigger).
    private(set) var selectionChanges = 0

    @ObservationIgnored private let groupSource: CaptureGroupSource
    @ObservationIgnored private let premium: CapturePremium
    @ObservationIgnored private let library: CaptureLibrary
    @ObservationIgnored private let voice: CaptureVoiceRecorder
    @ObservationIgnored private let coach: CaptureCoachStore
    @ObservationIgnored private let sendCenter: CaptureSendCenter
    @ObservationIgnored private let navigation: CaptureNavigation
    @ObservationIgnored private let onClose: @MainActor () -> Void
    @ObservationIgnored private let onSent: @MainActor () -> Void
    @ObservationIgnored private var didPreselect = false

    init(
        media: CapturedMedia,
        contextGroupID: String?,
        groups: CaptureGroupSource,
        premium: CapturePremium,
        library: CaptureLibrary,
        voice: CaptureVoiceRecorder,
        coach: CaptureCoachStore,
        sendCenter: CaptureSendCenter,
        navigation: CaptureNavigation,
        onClose: @escaping @MainActor () -> Void,
        onSent: @escaping @MainActor () -> Void
    ) {
        self.media = media
        self.contextGroupID = contextGroupID
        groupSource = groups
        self.premium = premium
        self.library = library
        self.voice = voice
        self.coach = coach
        self.sendCenter = sendCenter
        self.navigation = navigation
        self.onClose = onClose
        self.onSent = onSent
    }

    // MARK: Derived state

    /// The voice note is left out of release builds (CaptureBlockedElements.voiceNote).
    var isVoiceNoteAvailable: Bool { CaptureBlockedElements.voiceNote }

    /// A video needs premium at `create_post`; a free member's video cannot be sent.
    var isMediaSendable: Bool { !media.needsPremium || isPremium }

    /// The send button is hidden with nothing selected (a disabled look was never observed).
    var canSend: Bool { !selection.isEmpty && isMediaSendable }

    var groupCreation: (() -> Void)? { navigation.openGroupCreation }

    func isSelected(_ groupID: String) -> Bool {
        selection.contains(groupID)
    }

    // MARK: Loading

    func load() async {
        isPremium = await premium.isPremium()
        showsVoiceCoach = isVoiceNoteAvailable && !coach.isDismissed(.voice)
        if let cached = await groupSource.cachedGroups(), !cached.isEmpty {
            apply(cached)
        }
        do {
            apply(try await groupSource.loadGroups())
        } catch {
            guard groups.isEmpty else { return }
            let offline = groupSource.isOffline || DataError.from(error) == .offline
            listState = offline ? .offline : .failed
        }
    }

    func reload() async {
        listState = .loading
        await load()
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
        if let index = selection.firstIndex(of: groupID) {
            selection.remove(at: index)
        } else {
            let order = groups.map(\.id)
            selection = order.filter { $0 == groupID || selection.contains($0) }
        }
        selectionChanges += 1
    }

    /// Upload + `create_post` in the background; the sheet closes at once.
    func send() {
        guard canSend else { return }
        if isRecordingVoice { finishVoiceRecording() }
        let request = CaptureSendRequest(
            payload: .media(media),
            groupIDs: selection,
            caption: caption,
            voice: voiceNote
        )
        sendCenter.submit(request)
        onSent()
    }

    /// ✕: discards the capture, caption and voice note; back to the camera (no confirmation).
    func close() {
        voice.cancel()
        isRecordingVoice = false
        if let voiceNote { try? FileManager.default.removeItem(at: voiceNote.fileURL) }
        voiceNote = nil
        onClose()
    }

    /// Download: saves the photo / Live Photo / video with add-only access. The 'saved' toast's
    /// visible time is BLOCKED (`camera.sendto.duration.toastVisible`), so no toast follows.
    func save() async {
        try? await library.save(media)
    }

    // MARK: Voice note (optional; the note goes on every chosen group's post)

    func toggleVoiceRecording() async {
        guard isVoiceNoteAvailable else { return }
        if isRecordingVoice {
            finishVoiceRecording()
            return
        }
        // Microphone permission is asked here at first use (App Review 5.1.1(iv)).
        var status = voice.permission()
        if status == .notDetermined { status = await voice.requestPermission() }
        guard status == .granted else {
            if status == .denied || status == .restricted { navigation.openSystemSettings() }
            return
        }
        dismissVoiceCoach()
        do {
            if let voiceNote { try? FileManager.default.removeItem(at: voiceNote.fileURL) }
            voiceNote = nil
            try voice.start()
            isRecordingVoice = true
        } catch {
            isRecordingVoice = false
        }
    }

    private func finishVoiceRecording() {
        voiceNote = try? voice.stop()
        isRecordingVoice = false
    }

    func dismissVoiceCoach() {
        guard showsVoiceCoach else { return }
        showsVoiceCoach = false
        coach.dismiss(.voice)
    }
}
