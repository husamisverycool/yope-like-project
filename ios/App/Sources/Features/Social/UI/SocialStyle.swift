// Social group — view pieces shared by the social screens: the social text roles (design/tokens/social.json),
// haptics and notices, navigation and the reply-with-a-photo hand-off, private images, and token-driven formats.
// App-wide components (headers, empty states, pills, HUD, toasts, permission card) are the account pass's
// ios/App/Sources/Components, used read-only.
import AppData
import AppModels
import DesignSystem
import SwiftUI
import UIKit

// MARK: - Text roles of the social surfaces

enum SocialText {
    private static func role(_ size: CGFloat, _ weight: Font.Weight, _ textStyle: String) -> DSTextStyle {
        DSTextStyle(family: Tokens.Fonts.globalFamily, size: size, weight: weight, relativeTo: Font.TextStyle(tokenName: textStyle))
    }

    /// Composer / reply placeholder (`fontSize.global.placeholder`; weight not measured → platform regular).
    static let placeholder = role(Tokens.FontSizes.globalPlaceholder, Font.Weight.regular, Tokens.Layouts.GlobalTextStyleMap.placeholder)
    /// Quoted poster's first name on the lime reply quote.
    static let replyName = role(Tokens.FontSizes.chatThreadFontSizeReplyName, Tokens.FontWeights.chatThreadFontWeightReplyName, Tokens.Layouts.ChatThreadLayoutTextStyleMap.replyName)
    /// "pic" under the quoted name.
    static let replyLabel = role(Tokens.FontSizes.chatThreadFontSizeReplyLabel, Tokens.FontWeights.chatThreadFontWeightReplyLabel, Tokens.Layouts.ChatThreadLayoutTextStyleMap.replyLabel)
    /// Caption on a photo (thread and viewer).
    static let caption = role(Tokens.FontSizes.chatThreadFontSizeCaption, Tokens.FontWeights.chatThreadFontWeightCaption, Tokens.Layouts.ChatThreadLayoutTextStyleMap.caption)
    /// Reaction picker section labels.
    static let pickerSection = role(Tokens.FontSizes.chatReactionsFontSizePickerSection, Tokens.FontWeights.chatReactionsFontWeightPickerSection, Tokens.Layouts.ChatReactionsLayoutTextStyleMap.pickerSection)
    /// `week.recap` / `albums.*` centred header title.
    static let recapTitle = role(Tokens.FontSizes.weekRecapFontSizeTitle, Tokens.FontWeights.weekRecapFontWeightTitle, Tokens.Layouts.WeekRecapLayoutTextStyleMap.title)
    /// Week label on the recap card.
    static let recapLabel = role(Tokens.FontSizes.weekRecapFontSizeLabel, Tokens.FontWeights.weekRecapFontWeightLabel, Tokens.Layouts.WeekRecapLayoutTextStyleMap.label)
    /// "recap | pics" capsule labels.
    static let recapSegment = role(Tokens.FontSizes.weekRecapFontSizeSegmented, Tokens.FontWeights.weekRecapFontWeightSegmented, Tokens.Layouts.WeekRecapLayoutTextStyleMap.segmented)
    /// `week.history` display title (Retro display role, platform font).
    static let historyTitle = DSTextStyle(
        family: Tokens.Fonts.weekHistoryFontTitle, size: Tokens.FontSizes.weekHistoryFontSizeTitle,
        weight: Tokens.FontWeights.weekHistoryFontWeightTitle, relativeTo: Font.TextStyle(tokenName: Tokens.Layouts.WeekHistoryLayoutTextStyleMap.title)
    )
    /// "Week {n}".
    static let historyHeaderTitle = role(Tokens.FontSizes.weekHistoryFontSizeHeader, Tokens.FontWeights.weekHistoryFontWeightHeaderTitle, Tokens.Layouts.WeekHistoryLayoutTextStyleMap.header)
    /// The week's date range.
    static let historyHeaderRange = role(Tokens.FontSizes.weekHistoryFontSizeHeader, Tokens.FontWeights.weekHistoryFontWeightHeaderRange, Tokens.Layouts.WeekHistoryLayoutTextStyleMap.header)
    /// Weekday on a strip tile.
    static let historyWeekday = role(Tokens.FontSizes.weekHistoryFontSizeWeekday, Tokens.FontWeights.weekHistoryFontWeightWeekday, Tokens.Layouts.WeekHistoryLayoutTextStyleMap.weekday)
    /// The foundations coach tooltip (`camera.capture.layout.coach`), used by `tagging.coach`.
    static let coach = role(Tokens.FontSizes.cameraCaptureFontSizeCoach, Tokens.FontWeights.cameraCaptureFontWeightCoach, Tokens.Layouts.CameraCaptureLayoutTextStyleMap.coach)
    /// Album name sheet title (`groups.create.fontSize.title` / `.fontWeight.title`; Dynamic Type of the sheet title).
    static let albumSheetTitle = role(Tokens.FontSizes.groupsCreateFontSizeTitle, Tokens.FontWeights.groupsCreateFontWeightTitle, Tokens.Layouts.GlobalTextStyleMap.sheetTitle)
}

// MARK: - Haptics and notices

extension SocialFeedbackKind {
    /// Each spec's "Haptics" table.
    var haptic: DSHaptic {
        switch self {
        case .sent: return Tokens.Haptics.globalSend
        case .failed: return Tokens.Haptics.globalError
        case .warning: return Tokens.Haptics.globalWarning
        case .success: return Tokens.Haptics.globalSuccess
        case .select: return Tokens.Haptics.globalSelect
        }
    }
}

extension SocialNotice {
    var text: String {
        switch self {
        case .sendFailed: return Copy.chatThreadSendFailed
        case .reactionFailed: return Copy.chatReactionsError
        case .photoSaved: return Copy.photoViewerToastSaved
        case .photoDeleted: return Copy.photoViewerToastDeleted
        case .saveFailed: return Copy.photoViewerErrorSave
        case .deleteFailed: return Copy.photoViewerErrorDelete
        case .tagError: return Copy.taggingError
        case .tagNotFound: return Copy.taggingNotFound
        case .tagOffline: return Copy.taggingOffline
        case .recapSaved: return Copy.weekEditToastSaved
        case .albumSaved: return Copy.weekEditToastAlbumSaved
        case .albumRenamed: return Copy.albumsViewToastRenamed
        case .albumDeleted: return Copy.albumsViewToastDeleted
        case .changesFailed: return Copy.weekEditErrorSave
        case .playFailed: return Copy.chatVoiceErrorPlay
        case .recordFailed: return Copy.chatVoiceErrorRecord
        }
    }
}

extension View {
    /// Plays each new feedback event's haptic token.
    func socialFeedback(_ feedback: SocialFeedback?) -> some View {
        sensoryFeedback(trigger: feedback) { _, new in new?.kind.haptic.sensoryFeedback }
    }

    /// Shows each new notice through the Yope toast (`ToastCenter`: announced always; drawn only while the toast
    /// dwell time is BLOCKED in DEBUG builds).
    func socialNotices(_ event: SocialNoticeEvent?, toasts: ToastCenter) -> some View {
        onChange(of: event) { _, new in
            if let new { toasts.show(new.notice.text) }
        }
    }

    /// The custom headers replace the navigation bar on every social screen.
    func socialHidesNavigationBar() -> some View {
        toolbar(.hidden, for: .navigationBar)
    }

    /// A hairline rim shading from `top` to `bottom` (bubbles, composer field).
    func socialRim<S: InsettableShape>(_ shape: S, top: Color, bottom: Color, width: CGFloat) -> some View {
        overlay {
            shape.strokeBorder(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom), lineWidth: width)
        }
    }

    /// Keeps `width` equal to this view's width (frame-sized image decoding).
    func socialReadsWidth(_ width: Binding<CGFloat>) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { width.wrappedValue = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, new in width.wrappedValue = new }
            }
        }
    }

    /// Extends the hit area to `size.global.minTouchTarget.ios` without changing the drawn size.
    func socialMinimumHitArea() -> some View {
        frame(minWidth: Tokens.Sizes.globalMinTouchTargetIos, minHeight: Tokens.Sizes.globalMinTouchTargetIos)
            .contentShape(Rectangle())
    }
}

// MARK: - Navigation

/// Pushes and modals on the app's router (`AppRouter`).
@MainActor
enum SocialNav {
    static var router: AppRouter { AppEnvironment.shared.router }

    static func push(_ route: AppRoute) {
        router.path.append(route)
    }

    static func present(_ modal: AppModal) {
        router.modal = modal
    }

    /// `safety.report` (account group's sheet).
    static func report(_ target: ReportTarget) {
        router.modal = .account(.report(target))
    }

    /// `camera.capture` for one group (`chat.composer` camera circle, empty-state "share a pic").
    static func openCamera(groupID: String?) {
        router.modal = .camera(groupID: groupID, invitationID: nil)
    }
}

/// Reply to a photo with a photo (`photo.viewer` camera circle → `camera.capture` → `create_post(p_group_ids: [this
/// group], p_reply_to_post_id)`). The viewer stores the replied post here and presents `AppModal.camera`; the
/// capture pass reads `replyTarget(for:)` when it builds the `PostDraft` (`PostDraft.replyToPostID`, exactly this
/// group). The target is cleared when the camera closes.
@MainActor
enum PhotoReplyHandoff {
    struct Target: Equatable, Sendable {
        let groupID: String
        let postID: String
    }

    private(set) static var pending: Target?

    static func begin(_ target: Target) {
        pending = target
    }

    /// The post being replied to when the camera was opened for `groupID` from `photo.viewer`; nil otherwise.
    static func replyTarget(for groupID: String?) -> PostID? {
        guard let pending, pending.groupID == groupID else { return nil }
        return PostID(pending.postID)
    }

    static func clear() {
        pending = nil
    }
}

extension AppRouter {
    /// `photo.viewer` camera circle: the camera for `groupID`, replying to `postID` with a photo.
    func presentCameraReplying(toPost postID: String, groupID: String) {
        PhotoReplyHandoff.begin(PhotoReplyHandoff.Target(groupID: groupID, postID: postID))
        modal = .camera(groupID: groupID, invitationID: nil)
    }
}

extension View {
    /// Forgets the reply target once the camera closes.
    func socialClearsReplyHandoff() -> some View {
        onChange(of: SocialNav.router.modal) { old, new in
            if old?.isCapture == true, new == nil { PhotoReplyHandoff.clear() }
        }
    }
}

// MARK: - Images

/// A private photo by storage path, filling the proposed frame (`thumb_path` in grids, `display_path` full screen).
struct SocialPhoto<Failure: View>: View {
    let path: String?
    var contentMode: ContentMode = .fill
    /// Longest side of the frame in pixels: the image is decoded at that size (nil: full size).
    var maxPixel: Int?
    @ViewBuilder var failure: () -> Failure

    @State private var image: UIImage?
    @State private var failed = false

    init(path: String?, contentMode: ContentMode = .fill, maxPixel: Int? = nil, @ViewBuilder failure: @escaping () -> Failure) {
        self.path = path
        self.contentMode = contentMode
        self.maxPixel = maxPixel
        self.failure = failure
        _image = State(initialValue: path.flatMap { SocialServices.shared.images.cached($0, maxPixel: maxPixel) })
    }

    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else if failed {
                    failure()
                }
            }
            .clipped()
            .task(id: path) {
                guard let path else {
                    image = nil
                    return
                }
                if let cached = SocialServices.shared.images.cached(path, maxPixel: maxPixel) {
                    image = cached
                    return
                }
                let loaded = await SocialServices.shared.images.load(path, maxPixel: maxPixel)
                image = loaded
                failed = loaded == nil
            }
            .accessibilityHidden(true)
    }
}

extension SocialPhoto where Failure == EmptyView {
    init(path: String?, contentMode: ContentMode = .fill, maxPixel: Int? = nil) {
        self.init(path: path, contentMode: contentMode, maxPixel: maxPixel) { EmptyView() }
    }
}

/// A person's (or a group's) round avatar through the social image loader, with the shared `AvatarView` look
/// as its placeholder.
struct SocialAvatar: View {
    let path: String?
    let diameter: CGFloat
    var placeholderIcon: String = Tokens.Icons.globalPerson

    @State private var image: UIImage?

    init(path: String?, diameter: CGFloat, placeholderIcon: String = Tokens.Icons.globalPerson) {
        self.path = path
        self.diameter = diameter
        self.placeholderIcon = placeholderIcon
        _image = State(initialValue: path.flatMap { SocialServices.shared.images.cached($0) })
    }

    var body: some View {
        AvatarView(path: nil, localImage: image.map { Image(uiImage: $0) }, diameter: diameter, placeholderIcon: placeholderIcon)
            .task(id: path) {
                guard let path, image == nil else { return }
                image = await SocialServices.shared.images.load(path)
            }
    }
}

// MARK: - Formats (token patterns)

enum SocialFormat {
    /// `chat.thread.layout.timeFormat`: device-locale short time from the template ("10:00 PM").
    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate(Tokens.Layouts.ChatThreadLayoutTimeFormat.pattern)
        return formatter.string(from: date)
    }

    /// `photo.viewer.layout.dateFormat` ("Oct 30 2025").
    static func viewerDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = Tokens.Layouts.PhotoViewerLayoutDateFormat.pattern
        return formatter.string(from: date)
    }

    /// `chat.voice.layout.durationFormat` ("00:38").
    static func duration(milliseconds: Int) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = Tokens.Layouts.ChatVoiceLayoutDurationFormat.pattern
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(max(0, milliseconds)) / 1000))
    }

    /// The duration as words for VoiceOver (minutes and seconds).
    static func spokenDuration(milliseconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.minute, .second]
        return formatter.string(from: TimeInterval(max(0, milliseconds)) / 1000) ?? duration(milliseconds: milliseconds)
    }

    /// `week.recap.layout.weekFormat` title form ("18 aug-24 aug"): the token's "d MMM-d MMM" pattern, lowercase,
    /// bare hyphen, in the group's time zone.
    static func weekTitle(_ weekStart: LocalDate, timeZone: TimeZone) -> String {
        let pattern = Tokens.Layouts.WeekRecapLayoutWeekFormat.title.split(separator: ",").first.map(String.init) ?? ""
        let halves = pattern.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
        guard halves.count == 2 else { return weekStart.description }
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        let start = SocialCalendar.start(of: weekStart, in: timeZone)
        let end = SocialCalendar.start(of: weekStart.adding(days: 6), in: timeZone)
        formatter.dateFormat = halves[0]
        let first = formatter.string(from: start)
        formatter.dateFormat = halves[1]
        return (first + "-" + formatter.string(from: end)).lowercased()
    }

    /// The label form on the recap card: the title in uppercase ("18 AUG-24 AUG").
    static func weekLabel(_ weekStart: LocalDate, timeZone: TimeZone) -> String {
        weekTitle(weekStart, timeZone: timeZone).uppercased()
    }

    /// `week.history` range: the locale's interval for Monday–Sunday ("Apr 29 – May 5", "10–16 Aug").
    static func weekRange(_ weekStart: LocalDate, timeZone: TimeZone) -> String {
        let formatter = DateIntervalFormatter()
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.dateTemplate = "MMMd"
        let start = SocialCalendar.start(of: weekStart, in: timeZone)
        let end = SocialCalendar.start(of: weekStart.adding(days: 6), in: timeZone)
        return formatter.string(from: start, to: end)
    }

    /// Weekday on a strip tile ("Mon").
    static func weekday(_ date: Date, timeZone: TimeZone) -> String {
        var style = Date.FormatStyle.dateTime.weekday(.abbreviated)
        style.timeZone = timeZone
        return date.formatted(style)
    }

    /// Month ("Oct") of an empty-day tile.
    static func month(_ date: Date, timeZone: TimeZone) -> String {
        var style = Date.FormatStyle.dateTime.month(.abbreviated)
        style.timeZone = timeZone
        return date.formatted(style)
    }

    /// Day number of an empty-day tile.
    static func dayNumber(_ date: Date, timeZone: TimeZone) -> String {
        var style = Date.FormatStyle.dateTime.day()
        style.timeZone = timeZone
        return date.formatted(style)
    }

    /// A date for VoiceOver labels ("October 12").
    static func spokenDate(_ date: Date, timeZone: TimeZone = .current) -> String {
        var style = Date.FormatStyle.dateTime.month(.wide).day()
        style.timeZone = timeZone
        return date.formatted(style)
    }
}

// MARK: - Emoji names (accessibility)

enum SocialEmoji {
    /// The emoji's system name ("fire"), for VoiceOver (`chat.reactions` Accessibility).
    static func name(_ emoji: String) -> String {
        let mutable = NSMutableString(string: emoji) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformToUnicodeName, false)
        let raw = (mutable as String)
        let names = raw.components(separatedBy: "\\N{")
            .compactMap { $0.split(separator: "}").first.map(String.init) }
            .filter { !$0.hasPrefix("VARIATION SELECTOR") && !$0.hasPrefix("ZERO WIDTH") && !$0.hasPrefix("EMOJI MODIFIER") }
        return names.isEmpty ? emoji : names.joined(separator: " ").lowercased()
    }

    /// "Reactions: fire, sparkling heart" — names only, never a count.
    static func clusterLabel(_ emoji: [String]) -> String {
        Copy.chatReactionsA11yCluster(emojiNames: emoji.map(name).joined(separator: ", "))
    }
}

// MARK: - Font metrics (cap-top / baseline placement)

enum SocialMetrics {
    /// Cap height of a token text style at the current Dynamic Type size.
    static func capHeight(_ style: DSTextStyle) -> CGFloat {
        font(style).capHeight
    }

    /// Line height of a token text style at the default content size.
    static func lineHeight(_ style: DSTextStyle) -> CGFloat {
        UIFont.systemFont(ofSize: style.size, weight: uiWeight(style.weight)).lineHeight
    }

    private static func font(_ style: DSTextStyle) -> UIFont {
        UIFont.systemFont(ofSize: DSDynamicType.scaled(style.size, relativeTo: style.relativeTo), weight: uiWeight(style.weight))
    }

    static func uiWeight(_ weight: Font.Weight) -> UIFont.Weight {
        let pairs: [(Font.Weight, UIFont.Weight)] = [
            (.ultraLight, .ultraLight), (.thin, .thin), (.light, .light), (.regular, .regular),
            (.medium, .medium), (.semibold, .semibold), (.bold, .bold), (.heavy, .heavy), (.black, .black),
        ]
        return pairs.first { $0.0 == weight }?.1 ?? .regular
    }

    /// Vertical inset that keeps a single line where it sits in a control of `height` when the text wraps
    /// (multi-line layouts were not measured).
    static func singleLineInset(height: CGFloat, style: DSTextStyle) -> CGFloat {
        max(0, (height - lineHeight(style)) / 2)
    }
}
