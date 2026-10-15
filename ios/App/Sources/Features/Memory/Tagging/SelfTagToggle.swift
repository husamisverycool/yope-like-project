// Surface: tagging — reference: Yope voice (Yope has no tagging UI; built from foundation roles).
// Reference images: references/auto/yope/frames/a-chuongxetank-7694968408424582452-t7.73-posted-toast-contacts-card.png,
// references/auto/yope/store/yope-store-04.png, references/auto/yope/frames/a-jacob-7691153057177931039-t3.73-camera-hold-to-record.png,
// references/auto/yope/frames/a-chuongxetank-7694968408424582452-t6.73-sendto-voice-tooltip.png (design/surfaces/tagging.md).
import AppData
import DesignSystem
import SwiftUI

/// The "i'm in this" control, drawn from state the host owns. Use it when the host already keeps
/// the photo's tag state (e.g. `PhotoViewerModel.toggleTag()`); use `SelfTagToggle` to let the
/// control read and write the tag itself.
///
/// - White capsule (`color.global.surfaceLight`, `radius.global.capsule`, height
///   `size.global.buttonHeight`, label inset by the capsule radius): state glyph
///   (`size.global.checkCircle`) — off `icon.global.uncheck` in `color.global.onSurfaceLight`, on
///   `icon.global.check` in `color.global.selection` — then `size.global.headerGap`, then
///   `tagging.toggle` in text role `button`.
/// - VoiceOver: a button labelled "i'm in this", with the selected trait when on.
/// - With `showsCoach`, the first-use coach (`tagging.coach`) hangs below it, pointing at it.
/// - The host places it (photo.viewer: `photo.viewer.dimension.actionTrailing` / `.actionCenterTop`)
///   and shows the toasts.
struct SelfTagToggleControl: View {
    let isOn: Bool
    var isPending = false
    var showsCoach = false
    let onToggle: () -> Void
    var onDismissCoach: () -> Void = {}

    @State private var width: CGFloat = 0

    var body: some View {
        Button {
            guard !isPending else { return }
            onToggle()
        } label: {
            HStack(spacing: Tokens.Sizes.globalHeaderGap) {
                Image(systemName: isOn ? Tokens.Icons.globalCheck : Tokens.Icons.globalUncheck)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(isOn ? Tokens.Colors.globalSelection : Tokens.Colors.globalOnSurfaceLight)
                    .frame(width: Tokens.Sizes.globalCheckCircle, height: Tokens.Sizes.globalCheckCircle)
                Text(Copy.taggingToggle)
                    .dsTextStyle(MemoryType.button)
                    .foregroundStyle(Tokens.Colors.globalOnSurfaceLight)
            }
            .padding(.horizontal, Tokens.Sizes.globalButtonHeight / 2)
            .frame(minHeight: max(Tokens.Sizes.globalButtonHeight, Tokens.Sizes.globalMinTouchTargetIos))
            .background(Tokens.Colors.globalSurfaceLight, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Copy.taggingToggle)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : [.isButton])
        .accessibilityIdentifier("tagging.toggle")
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { width = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, value in width = value }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showsCoach {
                TaggingCoach(pointerFromTrailing: width / 2, onDismiss: onDismissCoach)
                    .alignmentGuide(.bottom) { $0[.top] - Tokens.Layouts.CameraCaptureLayoutCoach.pointerToTarget }
                    .fixedSize()
            }
        }
    }
}

/// "i'm in this" that reads and writes the caller's own tag (`tag_self` / `untag_self`) itself:
/// optimistic, one call at a time, reverts on failure; `haptic.global.select` on change,
/// `haptic.global.error` on failure.
///
///     SelfTagToggle(postID: post.id.rawValue, isTagged: tagged, isOthersPhoto: post.authorID != me,
///                   onMessage: { toastCenter.show($0) }, onPostGone: { closePhoto() })
///
/// - Parameters:
///   - isTagged: the state from the host's `post_tags` read; nil = the control reads it.
///   - isOthersPhoto: shows the first-use coach (once per account) on photos someone else posted.
///   - onMessage: the toast line to show (`tagging.error`, `.notFound`, `.offline`); also announced.
///   - onPostGone: the photo no longer exists (`post_not_found`): the viewer closes it.
///   - onChange: the new state after a successful call (or the optimistic one while it runs).
/// Not for collages.
@MainActor
struct SelfTagToggle: View {
    @State private var model: SelfTagModel
    private let onMessage: ((String) -> Void)?
    private let onPostGone: (() -> Void)?
    private let onChange: ((Bool) -> Void)?

    init(
        postID: String,
        isTagged: Bool? = nil,
        isOthersPhoto: Bool,
        model: SelfTagModel? = nil,
        onMessage: ((String) -> Void)? = nil,
        onPostGone: (() -> Void)? = nil,
        onChange: ((Bool) -> Void)? = nil
    ) {
        _model = State(initialValue: model ?? SelfTagModel(
            postID: PostID(postID), isTagged: isTagged, isOthersPhoto: isOthersPhoto, dependencies: .current
        ))
        self.onMessage = onMessage
        self.onPostGone = onPostGone
        self.onChange = onChange
    }

    var body: some View {
        SelfTagToggleControl(
            isOn: model.isOn,
            isPending: model.isPending,
            showsCoach: model.coachVisible,
            onToggle: { Task { await model.toggle() } },
            onDismissCoach: { Task { await model.dismissCoach() } }
        )
        .disabled(!model.isKnown)
        .task { await model.loadIfNeeded() }
        .onChange(of: model.isOn) { _, value in onChange?(value) }
        .onChange(of: model.message) { _, message in
            guard let message else { return }
            AccessibilityNotification.Announcement(message.text).post()
            onMessage?(message.text)
        }
        .onChange(of: model.isGone) { _, gone in
            if gone { onPostGone?() }
        }
    }
}

/// The foundations coach tooltip (`color.global.accent` / `color.global.onAccent`, dismissible ✕),
/// with the geometry of the only measured Yope coach (`camera.capture.layout.coach`) and its text
/// role (`camera.capture.fontSize/fontWeight.coach`, `caption2`). The pointer sits on its top edge.
struct TaggingCoach: View {
    /// Distance from the coach's trailing edge to the pointer's centre (the toggle's centre).
    let pointerFromTrailing: CGFloat
    let onDismiss: () -> Void

    private typealias Coach = Tokens.Layouts.CameraCaptureLayoutCoach

    private var textStyle: DSTextStyle {
        MemoryType.style(Tokens.Fonts.globalFamily, size: Tokens.FontSizes.cameraCaptureFontSizeCoach,
                         weight: Tokens.FontWeights.cameraCaptureFontWeightCoach,
                         relativeTo: Tokens.Layouts.CameraCaptureLayoutTextStyleMap.coach)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            CoachPointer()
                .fill(Tokens.Colors.globalAccent)
                .frame(width: Coach.pointerWidth, height: Coach.pointerHeight)
                .padding(.trailing, max(0, pointerFromTrailing - Coach.pointerWidth / 2))
            HStack(spacing: Coach.textToCloseGap) {
                Text(Copy.taggingCoach)
                    .dsTextStyle(textStyle)
                Button(action: onDismiss) {
                    Image(systemName: Tokens.Icons.globalClose)
                        .resizable()
                        .scaledToFit()
                        .frame(height: Coach.closeGlyph)
                        .frame(minWidth: Tokens.Sizes.globalMinTouchTargetIos, minHeight: Coach.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // No tagging key for the coach ✕: the viewer's own close label (Yope voice).
                .accessibilityLabel(Copy.photoViewerA11yClose)
                .accessibilityIdentifier("tagging.coach.close")
            }
            .foregroundStyle(Tokens.Colors.globalOnAccent)
            .padding(.leading, Coach.paddingHorizontal)
            .frame(minHeight: Coach.height)
            .background(Tokens.Colors.globalAccent, in: RoundedRectangle(cornerRadius: Coach.cornerRadius))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tagging.coach")
    }
}

/// An upward triangle (the coach's pointer).
private struct CoachPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
