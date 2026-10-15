// Surface: camera.sendto (states sending / sent / error / offline) and daily.capture (send failed /
// offline). Reference: Yope 'posted in the wall' toast
// (references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png).
// The sheet closes at once; the post continues in the background through AppData's outbox and the
// result is shown on whatever screen the member is on.
import AppData
import AppModels
import DesignSystem
import Observation
import SwiftUI

/// Sends captures in the background and keeps the last failure for the error toast.
@MainActor
@Observable
final class CaptureSendCenter {
    enum Failure: Equatable {
        case offline
        case sendFailed
    }

    /// The error toast's state; nil while nothing failed.
    private(set) var failure: Failure?
    private(set) var isRetrying = false
    private(set) var inFlight = 0
    /// Number of sends that reached `create_post` (tests, the BLOCKED success toast).
    private(set) var postedCount = 0

    @ObservationIgnored private let posting: CapturePosting
    @ObservationIgnored private let playHaptic: @MainActor (DSHaptic) -> Void
    /// Requests that never reached the outbox (encoding or local-file failure); retried with it.
    @ObservationIgnored private var unqueued: [CaptureSendRequest] = []
    @ObservationIgnored private var onlineTask: Task<Void, Never>?

    init(posting: CapturePosting, playHaptic: @escaping @MainActor (DSHaptic) -> Void = CaptureSendCenter.systemHaptic) {
        self.posting = posting
        self.playHaptic = playHaptic
    }

    static func systemHaptic(_ haptic: DSHaptic) {
        haptic.play()
    }

    /// Starts following the network: a failure caused by being offline is retried when it returns.
    func startObservingNetwork() {
        guard onlineTask == nil else { return }
        let updates = posting.onlineUpdates()
        onlineTask = Task { [weak self] in
            for await online in updates where online {
                guard let self, self.failure == .offline else { continue }
                await self.retry()
            }
        }
    }

    /// Posts in the background; returns at once (the sheet closes immediately, camera.sendto).
    func submit(_ request: CaptureSendRequest) {
        inFlight += 1
        Task { [weak self] in
            await self?.run(request)
            self?.inFlight -= 1
        }
    }

    /// Waits for one send (tests).
    func send(_ request: CaptureSendRequest) async {
        inFlight += 1
        await run(request)
        inFlight -= 1
    }

    /// The toast's retry: re-sends what never reached the outbox and replays the outbox.
    func retry() async {
        guard !isRetrying else { return }
        isRetrying = true
        defer { isRetrying = false }
        failure = nil
        let pending = unqueued
        unqueued = []
        for request in pending {
            await run(request)
        }
        let result = await posting.retryPending()
        if result.posted > 0 {
            postedCount += result.posted
            playHaptic(Tokens.Haptics.globalSend)
        }
        if let error = result.error {
            fail(error == .offline ? .offline : .sendFailed)
        }
    }

    private func run(_ request: CaptureSendRequest) async {
        let draft: PostDraft
        do {
            draft = try await Task.detached(priority: .userInitiated) {
                try await CaptureDraftBuilder.build(request)
            }.value
        } catch {
            unqueued.append(request)
            fail(.sendFailed)
            return
        }
        do {
            try await posting.publish(draft)
            CaptureDraftBuilder.cleanUp(request)
            request.removeTemporaryFiles()
            postedCount += 1
            playHaptic(Tokens.Haptics.globalSend)
        } catch {
            let dataError = DataError.from(error)
            if case .localFile = dataError {
                // The outbox could not copy the files: keep the request itself for the retry.
                unqueued.append(request)
            } else {
                // The outbox holds copies of the files and replays the draft on retry.
                CaptureDraftBuilder.cleanUp(request)
                request.removeTemporaryFiles()
            }
            fail(dataError == .offline ? .offline : .sendFailed)
        }
    }

    private func fail(_ failure: Failure) {
        self.failure = failure
        playHaptic(Tokens.Haptics.globalError)
    }
}

/// The lime toast bar (`camera.sendto.layout.toast`) in its error form: the text and a trailing
/// retry text button. The success form ('posted in …') is not shown: its visible time
/// `camera.sendto.duration.toastVisible` is BLOCKED (camera.sendto Gaps).
struct CaptureFailureToast: View {
    let failure: CaptureSendCenter.Failure
    let isRetrying: Bool
    let onRetry: () -> Void

    private typealias Toast = Tokens.Layouts.CameraSendtoLayoutToast

    var body: some View {
        HStack {
            Text(failure == .offline ? Copy.cameraSendtoErrorOffline : Copy.cameraSendtoErrorSendFailed)
                .dsTextStyle(CaptureType.button)
                .foregroundStyle(Tokens.Colors.globalOnAccent)
                .lineLimit(1)
            Spacer(minLength: Toast.glyphToText)
            Button(action: onRetry) {
                Text(Copy.cameraSendtoErrorRetry)
                    .dsTextStyle(CaptureType.button)
                    .foregroundStyle(Tokens.Colors.globalOnAccent)
                    .frame(minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                    .contentShape(Rectangle())
            }
            .disabled(isRetrying)
            .accessibilityIdentifier("capture.toast.retry")
        }
        .padding(.horizontal, Toast.glyphInset)
        .frame(height: Toast.height)
        .frame(maxWidth: .infinity)
        .background(Tokens.Colors.globalAccent, in: RoundedRectangle(cornerRadius: Toast.cornerRadius, style: .continuous))
        .padding(.horizontal, Toast.marginHorizontal)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("capture.toast.failure")
    }
}

extension View {
    /// Shows the capture send-failure toast at the toast position (`camera.sendto.layout.toast.top`
    /// from the screen top). Attach to the screen the member returns to after sending.
    func captureSendStatus(_ center: CaptureSendCenter) -> some View {
        modifier(CaptureSendStatusModifier(center: center))
    }
}

private struct CaptureSendStatusModifier: ViewModifier {
    let center: CaptureSendCenter

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            // Toast motion is BLOCKED (camera.sendto Motion: toast in / out): it appears and
            // leaves without animation.
            if let failure = center.failure {
                CaptureFailureToast(failure: failure, isRetrying: center.isRetrying) {
                    Task { await center.retry() }
                }
                .padding(.top, Tokens.Layouts.CameraSendtoLayoutToast.top)
                .ignoresSafeArea(edges: .top)
                .transition(.identity)
            }
        }
    }
}
