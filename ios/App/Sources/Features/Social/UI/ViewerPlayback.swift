// Surface: photo.viewer — a video post and a Live Photo in the viewer (design/surfaces/photo.viewer.md → "Video",
// "Live Photo"; tokens `photo.viewer.layout.video`, `photo.viewer.layout.livePhoto`).
// References: Retro's web viewer (references/auto/retro/web/retro.app-viewer-and-hero-js-excerpts.txt §1: the video
// autoplays muted and loops, shows once it can play, and taps still go forward / back); Apple HIG Playing audio (silent
// mode plays only audio people start; pause when headphones go) and Live Photos (press to play, the system badge).
import AppData
import AVFoundation
import Combine
import Photos
import PhotosUI
import SwiftUI
import UIKit

/// How a video page plays (`photo.viewer.layout.video`).
struct ViewerVideoState {
    /// False while a layer covers the photo (the selfie capture): paused.
    var active = true
    /// False under Reduce Motion or with Auto-Play Video Previews off: the play circle starts it, once.
    var autoplay = true
    /// The viewer's sound choice (muted until the person turns it on; kept for every video of the open viewer).
    var soundOn: Binding<Bool> = .constant(false)
    /// Each "Play" request (the circle or the VoiceOver action).
    var playRequests = 0
}

/// One video page's player: what it holds, whether its first frame is drawn, whether it plays, and the sound rule —
/// muted: `AVAudioSession` `.ambient` (mixes; other apps keep playing; the silent switch applies); with sound, started by
/// the person: `.playback` (plays in silent mode, HIG "audio that people explicitly initiate"). AVPlayer pauses by
/// itself when headphones are disconnected; such a pause shows the play circle.
@MainActor
@Observable
final class ViewerVideoPlayback {
    let player = AVQueuePlayer()
    @ObservationIgnored private var looper: AVPlayerLooper?
    /// The item played once (no loop): its end shows the play circle.
    @ObservationIgnored private var onceItem: AVPlayerItem?
    @ObservationIgnored private var observations: Set<AnyCancellable> = []
    @ObservationIgnored private var wantsToPlay = false
    @ObservationIgnored private(set) var loadedPath: String?

    private(set) var isPlaying = false
    private(set) var hasFirstFrame = false
    private(set) var failed = false
    private(set) var ended = false
    /// Paused by the system (headphones out, an interruption) while it was meant to play.
    private(set) var interrupted = false
    /// Increments on "Retry" after a failure: the page loads the video again.
    private(set) var attempts = 0

    init() {
        player.publisher(for: \.timeControlStatus)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                MainActor.assumeIsolated { self?.statusChanged(status) }
            }
            .store(in: &observations)
        player.publisher(for: \.currentItem?.status)
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                MainActor.assumeIsolated { if status == .failed { self?.failed = true } }
            }
            .store(in: &observations)
        NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] note in
                MainActor.assumeIsolated { self?.itemEnded(note.object as? AVPlayerItem) }
            }
            .store(in: &observations)
    }

    /// Prepares `url` once per path (looping when `loop`), then applies the page's sound and autoplay.
    func load(path: String, url: URL, loop: Bool, autoplay: Bool, soundOn: Bool) {
        if loadedPath != path {
            stop()
            loadedPath = path
            let item = AVPlayerItem(url: url)
            if loop {
                looper = AVPlayerLooper(player: player, templateItem: item)
            } else {
                // Kept at its end so a replay seeks back.
                player.actionAtItemEnd = .pause
                player.insert(item, after: nil)
                onceItem = item
            }
        }
        setSound(soundOn)
        if autoplay { play() }
    }

    func setSound(_ on: Bool) {
        player.isMuted = !on
        let session = AVAudioSession.sharedInstance()
        if on {
            try? session.setCategory(.playback, mode: .moviePlayback)
        } else {
            try? session.setCategory(.ambient)
        }
    }

    func play() {
        if ended {
            player.seek(to: .zero)
            ended = false
        }
        interrupted = false
        wantsToPlay = true
        player.play()
    }

    func pause() {
        wantsToPlay = false
        player.pause()
    }

    func stop() {
        wantsToPlay = false
        player.pause()
        looper?.disableLooping()
        looper = nil
        onceItem = nil
        player.removeAllItems()
        loadedPath = nil
        isPlaying = false
        hasFirstFrame = false
        failed = false
        ended = false
        interrupted = false
    }

    func retry() {
        stop()
        attempts += 1
    }

    func markFirstFrame() {
        hasFirstFrame = true
    }

    func markFailed() {
        failed = true
    }

    private func statusChanged(_ status: AVPlayer.TimeControlStatus) {
        isPlaying = status == .playing
        if status == .paused, wantsToPlay, !ended, loadedPath != nil {
            wantsToPlay = false
            interrupted = true
        }
    }

    private func itemEnded(_ item: AVPlayerItem?) {
        guard let item, let onceItem, item === onceItem else { return }
        wantsToPlay = false
        ended = true
        interrupted = false
    }
}

/// The player's picture, aspect fit (`AVPlayerLayer`), transparent until its first frame (the poster under it shows).
struct ViewerVideoSurface: UIViewRepresentable {
    let playback: ViewerVideoPlayback

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer?.player = playback.player
        view.playerLayer?.videoGravity = .resizeAspect
        view.onReady = { [weak playback] in playback?.markFirstFrame() }
        return view
    }

    func updateUIView(_ view: PlayerLayerView, context: Context) {
        if view.playerLayer?.player !== playback.player { view.playerLayer?.player = playback.player }
    }

    final class PlayerLayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
        var onReady: (@MainActor () -> Void)?
        private var observation: NSKeyValueObservation?

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            observation = playerLayer?.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
                guard layer.isReadyForDisplay else { return }
                Task { @MainActor in self?.onReady?() }
            }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            nil
        }
    }
}

/// A video page's media layer: the picture over the poster; loads when the page shows, follows the page's state, and
/// pauses when the page goes, the app leaves the foreground, or a layer covers it.
struct ViewerVideo: View {
    let media: Media
    let playback: ViewerVideoPlayback
    let state: ViewerVideoState

    @Environment(\.scenePhase) private var scenePhase
    @State private var requestsBefore: Int?

    var body: some View {
        ViewerVideoSurface(playback: playback)
            .opacity(playback.hasFirstFrame ? 1 : 0)
            .accessibilityHidden(true)
            .task(id: media.originalPath + "#" + String(playback.attempts)) {
                if requestsBefore == nil { requestsBefore = state.playRequests }
                guard let url = try? await SocialServices.shared.data.fileURL(path: media.originalPath) else {
                    playback.markFailed()
                    return
                }
                playback.load(
                    path: media.originalPath, url: url, loop: state.autoplay,
                    autoplay: state.autoplay && state.active, soundOn: state.soundOn.wrappedValue || !state.autoplay
                )
            }
            .onChange(of: state.active) { _, active in
                if active, state.autoplay { playback.play() } else if !active { playback.pause() }
            }
            .onChange(of: state.soundOn.wrappedValue) { _, on in playback.setSound(on) }
            .onChange(of: state.playRequests) { _, requests in
                guard requests > (requestsBefore ?? requests) else { return }
                playback.setSound(true)
                playback.play()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { playback.pause() }
            }
            .onDisappear { playback.stop() }
    }
}

/// The Live Photo of a page (`photo.viewer.layout.livePhoto`): played while held, once from VoiceOver; playable once
/// the still and its motion are in (its badge shows then).
@MainActor
@Observable
final class LivePhotoPlayback {
    @ObservationIgnored weak var view: PHLivePhotoView?
    private(set) var isPlayable = false

    func attach(_ view: PHLivePhotoView) {
        self.view = view
        // The page's hold drives playback (the photo's taps go forward and back).
        view.playbackGestureRecognizer.isEnabled = false
    }

    func loaded(_ playable: Bool) {
        isPlayable = playable
    }

    func start() {
        view?.startPlayback(with: .full)
    }

    func stop() {
        view?.stopPlayback()
    }

    /// VoiceOver's "Play": the whole motion once.
    func playOnce() {
        view?.startPlayback(with: .full)
    }
}

/// The system's Live Photo badge over the content (HIG: "show a system-provided badge above the photo").
struct LivePhotoBadge: View {
    var body: some View {
        Image(uiImage: PHLivePhotoView.livePhotoBadgeImage(options: .overContent))
            .accessibilityHidden(true)
    }
}
