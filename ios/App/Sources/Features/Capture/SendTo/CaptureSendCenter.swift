// Surfaces: camera.sendto (states sending / sent / error / offline) and daily.capture (send, send failed / offline) —
// design/surfaces/camera.sendto.md, daily.capture.md (RC-8). Reference: references/auto/retro/press/tc-2023-12-retro3.png
// phone 2 (Retro's Postcard composer sends in place: "Ordering postcard…"), references/owner/locket-review-sending.jpg
// (mechanics: sending → sent).
// The composer waits for its send: busy capsule and "Sending…" title while the capture uploads and `create_post`
// runs (docs/API.md recipe 9.4, through AppData's outbox); success closes the composer with `haptic.global.send` and
// the confirmation (iOS: an accessibility announcement, C-26 — iOS draws no toast); failure keeps everything in the
// composer, plays `haptic.global.error` and returns the reason for the native alert.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

@MainActor
@Observable
final class CaptureSendCenter {
    enum Failure: Equatable {
        /// No connection (`camera.sendto.error.offline`).
        case offline
        /// Upload or `create_post` failed (`camera.sendto.error.generic`).
        case sendFailed
    }

    enum Outcome: Equatable {
        case posted
        case failed(Failure)
    }

    /// Sends that reached `create_post` (tests).
    private(set) var postedCount = 0
    /// C-26 confirmations ("Added to Family!", "Saved"): announced to VoiceOver, nothing drawn on iOS.
    let confirmations = ToastCenter()

    private let posting: CapturePosting
    private let playHaptic: @MainActor (DSHaptic) -> Void

    init(posting: CapturePosting, playHaptic: @escaping @MainActor (DSHaptic) -> Void = CaptureSendCenter.systemHaptic) {
        self.posting = posting
        self.playHaptic = playHaptic
    }

    static func systemHaptic(_ haptic: DSHaptic) {
        haptic.play()
    }

    /// A confirmation (C-26): an accessibility announcement on iOS.
    func confirm(_ text: String) {
        confirmations.show(text)
    }

    /// Uploads and posts one capture while the composer waits. Posted: `haptic.global.send` and the request's
    /// confirmation; the camera's temporary files are removed. Failed: `haptic.global.error`; the outbox copy is
    /// discarded (the composer still holds the capture, and Try Again sends it as a new draft), the camera's files stay.
    func send(_ request: CaptureSendRequest) async -> Outcome {
        let draft: PostDraft
        do {
            draft = try await Task.detached(priority: .userInitiated) {
                try await CaptureDraftBuilder.build(request)
            }.value
        } catch {
            CaptureDraftBuilder.cleanUp(request)
            return fail(.sendFailed)
        }
        do {
            try await posting.publish(draft)
            CaptureDraftBuilder.cleanUp(request)
            request.removeTemporaryFiles()
            postedCount += 1
            playHaptic(Tokens.Haptics.globalSend)
            if let text = request.confirmation { confirm(text) }
            return .posted
        } catch {
            await posting.discard(draft.mediaID)
            CaptureDraftBuilder.cleanUp(request)
            return fail(DataError.from(error) == .offline ? .offline : .sendFailed)
        }
    }

    private func fail(_ failure: Failure) -> Outcome {
        playHaptic(Tokens.Haptics.globalError)
        return .failed(failure)
    }
}

extension CaptureSendCenter.Failure {
    /// The alert message (camera.sendto States: error / offline).
    var message: String {
        switch self {
        case .offline: return Copy.cameraSendtoErrorOffline
        case .sendFailed: return Copy.cameraSendtoErrorGeneric
        }
    }
}

extension View {
    /// Kept for the shell (`RootView` attaches it): sends no longer continue in the background — the composer waits for
    /// its result and shows failures in its own alert (RC-8) — so there is nothing to show here. Adds nothing.
    func captureSendStatus(_ center: CaptureSendCenter) -> some View {
        self
    }
}
