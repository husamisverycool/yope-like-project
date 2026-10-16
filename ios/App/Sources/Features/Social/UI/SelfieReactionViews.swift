// Surface: viewer.selfiereaction — react to a photo with a live selfie, inside photo.viewer. Mechanics BeReal's Instant
// RealMoji (touch and hold the smiley, a live front-camera circle opens over the post, slide into the target ring,
// release to send; one per person per post; faces at the photo's bottom-left); visual reference Retro, composed of
// C-09, C-11, C-16, C-22, C-23, C-29 and existing tokens. Spec: design/surfaces/viewer.selfiereaction.md (MERGE_DECISIONS
// SR-1 … SR-9). References: references/auto/bereal/frames/appstore-preview-2026_t12.47s_instant-realmoji-capture.png
// (AP-375: circle, border, hint, target ring), …_t13.47s_instant-realmoji-armed.png (AP-405: armed ring),
// …_t14.20s_realmoji-stack.png (AP-427: stack), references/auto/bereal/help/
// help-21088572284317_realpeople-realmoji-comments-3x.png (H-RP: face border, insets),
// references/auto/retro/press/tc-2023-07-retro-2b.jpg (TC-2B: Retro's viewer ring), references/auto/retro/store/
// retro-store-03.png (ST-03: C-09 pill on media). Not copied: counts, "+N", the unlock gate, stored moods, bubbles,
// fly-to-stack, the white capture flash, double-tap to react.
import AppData
import AppModels
import AppServices
import DesignSystem
import ImageIO
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Faces on the photo (`viewer.selfiereaction.layout.stack`)

/// The newest `chat.reactions.count.clusterMaxVisible` selfies over the photo's bottom-leading corner (the caller insets
/// it `size.global.screenMargin` from the visible image's edges), newest leading, each trailing face drawn over the one
/// before it, overlapping by `size.global.avatarStackOverlap` (C-23). No "+N" and no other number. One button — its
/// hit area at least `size.global.minTouchTarget.ios` — that opens the Reactions sheet; a tap on it never advances the
/// photo. A face enters with `spring.global.playful` and the stack shifts with the same spring; a removed face fades
/// out (`duration.global.fade`). Reduce Motion: cross-fades (`duration.global.crossfade`). Hidden when nobody reacted
/// with a selfie. Accessibility: "Selfie reactions: Ana, Cleo" (`viewer.selfiereaction.a11y.stack`, the names of the
/// faces shown joined by the platform list formatter — never a count).
struct SelfieFaceStack: View {
    let faces: [SelfieReaction]
    /// The first names of `faces`, in order.
    let names: [String]
    let source: (SelfieReaction) -> PhotoSource?
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shift: DSAnimation { reduceMotion ? ComponentMotion.crossfade : .spring(Tokens.Springs.globalPlayful) }
    private var removal: DSAnimation { reduceMotion ? ComponentMotion.crossfade : ComponentMotion.fade }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if !faces.isEmpty {
                Button(action: action) {
                    HStack(spacing: -Tokens.Sizes.globalAvatarStackOverlap) {
                        ForEach(faces, id: \.userID) { face in
                            SelfieFace(source: source(face))
                                .transition(.asymmetric(insertion: .opacity, removal: .opacity.animation(removal.animation)))
                        }
                    }
                    .minimumHitArea(drawn: CGSize(
                        width: AvatarStackLayout.width(
                            count: faces.count, diameter: Tokens.Sizes.globalAvatarHeader, overlap: Tokens.Sizes.globalAvatarStackOverlap
                        ),
                        height: Tokens.Sizes.globalAvatarHeader
                    ))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(Copy.viewerSelfiereactionA11yStack(names: ListFormatter.localizedString(byJoining: names))))
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("photo.viewer.selfies") // provenance-ok: accessibility identifier for UI tests
            }
        }
        .dsAnimation(shift, value: faces.map(\.userID))
    }
}

/// One face: a circle `size.global.avatarHeader` across, ring included (SR-2) — the selfie aspect-fill, Retro's white
/// stack ring `color.global.textOnMedia` `photo.viewer.layout.avatarRing.strokeWidth` (2.0) wide on its edge (SR-3).
struct SelfieFace: View {
    let source: PhotoSource?
    var diameter: CGFloat = Tokens.Sizes.globalAvatarHeader

    var body: some View {
        AvatarView(source: source, diameter: diameter)
            .overlay {
                Circle()
                    .strokeBorder(Tokens.Colors.globalTextOnMedia, lineWidth: Tokens.Layouts.PhotoViewerLayoutAvatarRing.strokeWidth)
            }
            .accessibilityHidden(true)
    }
}

/// The picture of a face: the JPEG sent from this device (decoded once at the face's size, so a face never blanks while
/// its file loads), else the stored file (`image_path`, signed URL).
@MainActor
enum SelfieFaceImages {
    private static let cache = NSCache<NSString, UIImage>()

    static func source(_ selfie: SelfieReaction, sent: Data?, displayScale: CGFloat) -> PhotoSource? {
        if let sent, let image = decoded(selfie.id, sent, displayScale: displayScale) { return .image(image) }
        guard !selfie.imagePath.isEmpty else { return nil }
        return SocialImages.source(selfie.imagePath)
    }

    private static func decoded(_ id: SelfieReactionID, _ data: Data, displayScale: CGFloat) -> UIImage? {
        let key = "\(id.rawValue)#\(data.count)" as NSString // provenance-ok: cache key
        if let image = cache.object(forKey: key) { return image }
        let pixels = Int((Tokens.Sizes.globalAvatarHeader * max(displayScale, 1)).rounded(.up))
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: pixels,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: key)
        return image
    }
}

// MARK: - Rows in the Reactions sheet (viewer.selfiereaction §4)

/// What the Reactions sheet does with selfie rows (photo.viewer only).
struct SelfieRowActions {
    /// The face of a row.
    let face: (SelfieReaction) -> PhotoSource?
    /// The photo is mine: "Remove" on the others' rows (→ the confirmation).
    let isAuthor: Bool
    /// Tap on my row: takes my selfie back.
    let removeMine: (SelfieReaction) -> Void
    /// The author's "Remove" (`viewer.selfiereaction.menu.remove`) → the confirmation.
    let remove: (SelfieReaction) -> Void
    /// "Report Selfie" (`viewer.selfiereaction.menu.report`) → `safety.report`; nil without the account group's flow.
    let report: ((SelfieReaction) -> Void)?
}

/// A selfie row: chat.reactions' C-16 row with the selfie as the row avatar (`size.global.avatarPicker`, circle), the
/// name (text role `listTitle`, `color.global.textPrimary`) over the line `viewer.selfiereaction.activity.row` /
/// `.activity.rowMine` (`listSubtitle`, `color.global.textSecondary`); my row adds `chat.reactions.list.removeHint`.
/// Avatar and text `chat.thread.dimension.rowAvatarToText` apart, inside `size.global.screenMargin` (`SocialPersonRow`'s
/// measured spacing). No number anywhere.
struct SelfieReactionRow: View {
    let name: String
    let line: String
    var removeHint: String?
    let face: PhotoSource?

    var body: some View {
        HStack(spacing: Tokens.Sizes.chatThreadDimensionRowAvatarToText) {
            AvatarView(source: face, diameter: Tokens.Sizes.globalAvatarPicker)
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .dsTextStyle(TextRole.listTitle)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
                    .lineLimit(1)
                Text(line)
                    .dsTextStyle(TextRole.listSubtitle)
                    .foregroundStyle(Tokens.Colors.globalTextSecondary)
                if let removeHint {
                    Text(removeHint)
                        .dsTextStyle(TextRole.listSubtitle)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}

// MARK: - Entry: touch and hold the add-reaction glyph (viewer.selfiereaction §1)

/// The add-reaction glyph's touch (the shutter's mechanic, `CameraCaptureModel`): a tap opens the emoji picker; held
/// past the platform's long-press time (`UILongPressGestureRecognizer.minimumPressDuration`) the capture layer opens in
/// hold mode with the finger still down, then the finger's moves and its release go to the layer.
@MainActor
final class SelfieHoldTracker {
    private let threshold: Duration
    private var isTouching = false
    private var isHolding = false
    private var task: Task<Void, Never>?

    init(threshold: Duration = CameraCaptureModel.platformLongPress) {
        self.threshold = threshold
    }

    func changed(_ location: CGPoint, onHold: @escaping @MainActor () -> Void, onMove: (CGPoint) -> Void) {
        guard isTouching else {
            isTouching = true
            isHolding = false
            let threshold = threshold
            task = Task { [weak self] in
                try? await Task.sleep(for: threshold)
                guard !Task.isCancelled, let self, self.isTouching else { return }
                self.isHolding = true
                onHold()
            }
            return
        }
        if isHolding { onMove(location) }
    }

    func ended(_ location: CGPoint, onTap: () -> Void, onRelease: (CGPoint) -> Void) {
        guard isTouching else { return }
        isTouching = false
        task?.cancel()
        if isHolding {
            isHolding = false
            onRelease(location)
        } else {
            onTap()
        }
    }
}

/// The selfie entry points of one photo (nil on my own photo or without a front camera: hidden).
struct SelfieEntry {
    let hold: SelfieHoldTracker
    /// A plain tap on the glyph: the emoji picker.
    let onTap: () -> Void
    let onHoldBegan: @MainActor () -> Void
    let onMove: (CGPoint) -> Void
    let onRelease: (CGPoint) -> Void
    /// The context-menu item and the accessibility action: the layer in tap mode (WCAG 2.2 SC 2.5.7).
    let openTapMode: () -> Void

    @MainActor
    func changed(_ location: CGPoint) {
        hold.changed(location, onHold: onHoldBegan, onMove: onMove)
    }

    @MainActor
    func ended(_ location: CGPoint) {
        hold.ended(location, onTap: onTap, onRelease: onRelease)
    }
}

// MARK: - Capture layer (viewer.selfiereaction §2)

/// The capture layer's camera and finger: the front camera live in the circle, hold mode's armed state, the capture.
@MainActor
@Observable
final class SelfieCaptureModel {
    enum Mode: Equatable {
        /// Opened by holding the add-reaction glyph: slide into the ring and release to send.
        case hold
        /// Opened from the menu item or the accessibility action: the ring is a button.
        case tap
    }

    enum Phase: Equatable {
        /// The circle stays `color.global.backgroundDeep` with the platform activity indicator until the camera runs.
        case starting
        case live
        /// Camera permission denied or restricted: the `camera.capture.denied.*` block where the circle is.
        case denied
        /// The camera could not start: the `camera.capture.unavailable.*` block where the circle is.
        case unavailable
    }

    let postID: PostID
    let mode: Mode
    let camera: CaptureCamera
    private(set) var phase: Phase = .starting
    /// Hold mode: the finger is inside the target ring or the circle (the armed ring shows).
    private(set) var isArmed = false
    /// Increments each time the finger enters the target (`haptic.global.select`).
    private(set) var armings = 0
    private(set) var isCapturing = false
    /// The live circle and the target ring in global coordinates (set by the layer; hit-testing the held finger).
    @ObservationIgnored var circleFrame: CGRect = .zero
    @ObservationIgnored var ringFrame: CGRect = .zero

    init(postID: PostID, mode: Mode, camera: CaptureCamera) {
        self.postID = postID
        self.mode = mode
        self.camera = camera
    }

    /// Asks for the camera at first use (the system alert over the viewer), then runs the front camera.
    func start() async {
        var status = camera.authorization()
        if status == .notDetermined { status = await camera.requestAccess() }
        guard status == .granted else {
            phase = .denied
            return
        }
        phase = .starting
        do {
            try await camera.configure(.photo(.front))
            phase = .live
        } catch {
            phase = .unavailable
        }
    }

    func stop() async {
        await camera.stop()
    }

    /// Inside the target ring or the live circle (release there sends; elsewhere nothing is sent — PLATFORM).
    func contains(_ point: CGPoint) -> Bool {
        if ringFrame.contains(point) { return true }
        guard circleFrame.width > 0 else { return false }
        let dx = point.x - circleFrame.midX
        let dy = point.y - circleFrame.midY
        return (dx * dx + dy * dy).squareRoot() <= circleFrame.width / 2
    }

    /// Hold mode: the finger moved.
    func moved(to point: CGPoint) {
        guard mode == .hold else { return }
        let inside = contains(point)
        guard inside != isArmed else { return }
        isArmed = inside
        if inside { armings += 1 }
    }

    /// The selfie: one still without motion (`haptic.global.shutter`: none; no flash, no shutter animation), as a square
    /// JPEG without metadata. Nil when the camera is not running or failed.
    func capture() async -> Data? {
        guard phase == .live, !isCapturing else { return nil }
        isCapturing = true
        defer { isCapturing = false }
        guard let still = try? await camera.captureStill(flash: false) else { return nil }
        return await SelfieJPEG.square(from: still.imageData)
    }
}

/// `viewer.selfiereaction.layout.captureCircle` in the layer's space (the whole screen): the live circle
/// `screen − 2 × size.global.screenMargin` across, centred horizontally, its centre on the screen's vertical middle
/// (AP-375); the target ring (`camera.capture.size.shutterOuter`) centred on the circle's bottom edge; the second hint's
/// first cap top `size.global.screenMargin` below the ring. When the panel (`panelTop` … `contentBottom`) is shorter than
/// circle + ring + hint, the circle shrinks with its centre on the panel's middle.
struct SelfieLayerGeometry: Equatable {
    var circle: CGRect
    var ring: CGRect
    var hintCapTop: CGFloat

    static func layout(size: CGSize, panelTop: CGFloat, contentBottom: CGFloat, hintHeight: CGFloat) -> SelfieLayerGeometry {
        let margin = Tokens.Sizes.globalScreenMargin
        let ringOuter = Tokens.Sizes.cameraCaptureSizeShutterOuter
        let below = ringOuter / 2 + margin + hintHeight
        var diameter = max(0, size.width - 2 * margin)
        var centreY = size.height / 2
        if centreY - diameter / 2 < panelTop || centreY + diameter / 2 + below > contentBottom {
            centreY = (panelTop + contentBottom) / 2
            diameter = max(0, min(diameter, 2 * ((contentBottom - panelTop) / 2 - below)))
        }
        let circle = CGRect(x: size.width / 2 - diameter / 2, y: centreY - diameter / 2, width: diameter, height: diameter)
        let ring = CGRect(x: circle.midX - ringOuter / 2, y: circle.maxY - ringOuter / 2, width: ringOuter, height: ringOuter)
        return SelfieLayerGeometry(circle: circle, ring: ring, hintCapTop: ring.maxY + margin)
    }
}

/// The layer over the viewer, below its header (which stays visible and inert): the panel (`color.global.controlOnDeep`,
/// `radius.global.photo`) from the photo's top to the screen's bottom, hiding photo, footer, comments and reply field;
/// the live circle (front camera, aspect-fill, circular clip) with its `viewer.selfiereaction.size.captureBorder` border
/// in `color.global.backgroundDeep` outside the clip; the C-09 hint pill centred on the circle; the target ring (Jolt's
/// shutter ring, no disc, `color.global.textSecondary`); in hold mode the second hint "Slide in to send" (`meta`) and,
/// while the finger is inside, the armed ring (`color.global.textOnMedia`, `photo.viewer.layout.avatarRing`'s stroke,
/// its outer edge `.gap` inside the circle) with `duration.global.crossfade`. Tap mode: the ring is a button, a tap on
/// the panel outside the circle closes. In and out: `duration.global.fade` (the caller's transition).
struct SelfieCaptureLayer: View {
    let model: SelfieCaptureModel
    /// Where the panel starts, in global coordinates: `photo.viewer.dimension.headerToPhoto` below the header.
    let panelTop: CGFloat
    let onCapture: () -> Void
    let onClose: () -> Void
    let onOpenSettings: () -> Void

    @AccessibilityFocusState private var ringFocused: Bool
    @ScaledMetric private var hintSize: CGFloat

    init(model: SelfieCaptureModel, panelTop: CGFloat, onCapture: @escaping () -> Void, onClose: @escaping () -> Void, onOpenSettings: @escaping () -> Void) {
        self.model = model
        self.panelTop = panelTop
        self.onCapture = onCapture
        self.onClose = onClose
        self.onOpenSettings = onOpenSettings
        _hintSize = ScaledMetric(wrappedValue: TextRole.meta.size, relativeTo: TextRole.meta.relativeTo)
    }

    private typealias Ring = Tokens.Layouts.PhotoViewerLayoutAvatarRing

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            let top = max(0, panelTop - frame.minY)
            let metrics = TextMetrics(style: TextRole.meta, size: hintSize)
            let geometry = SelfieLayerGeometry.layout(
                size: proxy.size, panelTop: top, contentBottom: proxy.size.height - proxy.safeAreaInsets.bottom,
                hintHeight: metrics.ascender + metrics.belowBaseline
            )
            ZStack(alignment: .topLeading) {
                panel(top: top, size: proxy.size)
                switch model.phase {
                case .denied:
                    block(geometry, title: Copy.cameraCaptureDeniedTitle, detail: Copy.cameraCaptureDeniedDetail, button: Copy.cameraCaptureDeniedButton, action: onOpenSettings)
                case .unavailable:
                    block(geometry, title: Copy.cameraCaptureUnavailableTitle, detail: Copy.cameraCaptureUnavailableDetail, button: Copy.cameraCaptureUnavailableButton) {
                        Task { await model.start() }
                    }
                case .starting, .live:
                    circle(geometry)
                        .accessibilitySortPriority(1)
                    ring(geometry)
                        .accessibilitySortPriority(2)
                    hintPill
                        .position(x: geometry.circle.midX, y: geometry.circle.midY)
                        .accessibilityHidden(model.mode == .hold)
                    if model.mode == .hold {
                        secondHint(geometry, width: proxy.size.width)
                    }
                }
            }
            .onAppear { report(geometry, origin: frame.origin) }
            .onChange(of: geometry) { _, new in report(new, origin: frame.origin) }
        }
        .ignoresSafeArea()
        .dsHaptic(Tokens.Haptics.globalSelect, trigger: model.armings)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { onClose() }
        .accessibilityIdentifier("photo.viewer.selfieLayer") // provenance-ok: accessibility identifier for UI tests
        .onAppear { if model.mode == .tap { ringFocused = true } }
    }

    private func report(_ geometry: SelfieLayerGeometry, origin: CGPoint) {
        model.circleFrame = geometry.circle.offsetBy(dx: origin.x, dy: origin.y)
        model.ringFrame = geometry.ring.offsetBy(dx: origin.x, dy: origin.y)
    }

    /// Full width, from the photo's top to the bottom of the screen; in tap mode a tap outside the circle closes.
    private func panel(top: CGFloat, size: CGSize) -> some View {
        VStack(spacing: 0) {
            // Above the panel: the inert header shows through.
            Color.clear
                .frame(height: top)
                .allowsHitTesting(false)
            DSShape.rounded(Tokens.Radii.globalPhoto)
                .fill(Tokens.Colors.globalControlOnDeep)
                .contentShape(Rectangle())
                .onTapGesture { if model.mode == .tap { onClose() } }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    private func circle(_ geometry: SelfieLayerGeometry) -> some View {
        let diameter = geometry.circle.width
        let border = Tokens.Sizes.viewerSelfiereactionSizeCaptureBorder
        return ZStack {
            Circle()
                .fill(Tokens.Colors.globalBackgroundDeep)
                .frame(width: diameter + 2 * border, height: diameter + 2 * border)
            ZStack {
                Tokens.Colors.globalBackgroundDeep
                if model.phase == .live {
                    model.camera.preview(position: .front)
                        .dsTransition(.opacity)
                } else {
                    // C-28: the platform activity indicator until the camera runs.
                    ProgressView()
                        .tint(Tokens.Colors.globalTextOnMedia)
                }
            }
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .dsAnimation(ComponentMotion.fade, value: model.phase)
            if model.mode == .hold && model.isArmed {
                Circle()
                    .strokeBorder(Tokens.Colors.globalTextOnMedia, lineWidth: Ring.strokeWidth)
                    .frame(width: max(0, diameter - 2 * Ring.gap), height: max(0, diameter - 2 * Ring.gap))
                    .transition(.opacity)
            }
        }
        .dsAnimation(ComponentMotion.crossfade, value: model.isArmed)
        // A tap inside the circle neither sends nor closes (tap mode closes on the panel outside it).
        .contentShape(Circle())
        .onTapGesture {}
        .position(x: geometry.circle.midX, y: geometry.circle.midY)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Copy.viewerSelfiereactionA11yPreview))
        .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder
    private func ring(_ geometry: SelfieLayerGeometry) -> some View {
        let face = Circle()
            .strokeBorder(Tokens.Colors.globalTextSecondary, lineWidth: Tokens.Sizes.cameraCaptureSizeShutterRing)
            .frame(width: geometry.ring.width, height: geometry.ring.height)
            .contentShape(Circle())
        switch model.mode {
        case .tap:
            Button(action: onCapture) { face }
                .buttonStyle(.plain)
                .disabled(model.phase != .live || model.isCapturing)
                .accessibilityLabel(Text(Copy.viewerSelfiereactionA11yCapture))
                .accessibilityFocused($ringFocused)
                .accessibilityIdentifier("photo.viewer.selfieLayer.capture") // provenance-ok: accessibility identifier for UI tests
                .position(x: geometry.ring.midX, y: geometry.ring.midY)
        case .hold:
            face
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .position(x: geometry.ring.midX, y: geometry.ring.midY)
        }
    }

    /// C-09 coach pill on media: `color.global.controlOnDeep`, the label (text role `pill`, `color.global.textOnMedia`)
    /// between `size.global.pillPaddingLeading` and `.pillPaddingTrailing`, at least `size.global.pillHeight` tall.
    private var hintPill: some View {
        Text(model.mode == .hold ? Copy.viewerSelfiereactionCoachSlideHere : Copy.viewerSelfiereactionCoachTapRing)
            .dsTextStyle(TextRole.pill)
            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
            .lineLimit(1)
            .padding(.leading, Tokens.Sizes.globalPillPaddingLeading)
            .padding(.trailing, Tokens.Sizes.globalPillPaddingTrailing)
            .frame(minHeight: Tokens.Sizes.globalPillHeight)
            .background(Tokens.Colors.globalControlOnDeep, in: Capsule())
            .fixedSize()
            .allowsHitTesting(false)
    }

    /// "Slide in to send" (`meta`, `color.global.textSecondary`), centred, its first cap top `size.global.screenMargin`
    /// below the ring's outer bottom.
    private func secondHint(_ geometry: SelfieLayerGeometry, width: CGFloat) -> some View {
        MetricStack(alignment: .center) {
            Color.clear
                .frame(width: width, height: geometry.ring.maxY)
            Text(Copy.viewerSelfiereactionCoachSlideToSend)
                .dsTextRole(TextRole.meta)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
                .capHeight(of: TextRole.meta)
                .metricGap(Tokens.Sizes.globalScreenMargin, from: .bottom, to: .capTop)
        }
        .frame(width: width)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// C-27 centred where the circle is (permission denied: no ring, no hints).
    private func block(_ geometry: SelfieLayerGeometry, title: String, detail: String, button: String, action: @escaping () -> Void) -> some View {
        EmptyStateView(title: title, detail: detail, action: EmptyStateView.Action(button, handler: action))
            .frame(width: geometry.circle.width)
            .position(x: geometry.circle.midX, y: geometry.circle.midY)
            .accessibilityElement(children: .contain)
    }
}

// MARK: - The stored selfie

/// The selfie as uploaded (docs/API.md §14.1): a still JPEG without metadata, centre-cropped to a square for the circle,
/// at the camera's own resolution (never downscaled — the size is BLOCKED, a backend decision) and the uploads' JPEG
/// quality (`CaptureDraftBuilder.jpegQuality`). Mirroring is BLOCKED: stored as the camera captured it.
enum SelfieJPEG {
    static func square(from data: Data) async -> Data? {
        await Task.detached(priority: .userInitiated) { () -> Data? in
            guard let size = ImageEncoder.pixelSize(data), let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            let side = min(image.width, image.height)
            let square = CGRect(x: (image.width - side) / 2, y: (image.height - side) / 2, width: side, height: side)
            guard let cropped = image.cropping(to: square) else { return nil }
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(output as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
                return nil
            }
            let properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: CaptureDraftBuilder.jpegQuality]
            CGImageDestinationAddImage(destination, cropped, properties as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { return nil }
            return output as Data
        }.value
    }
}
