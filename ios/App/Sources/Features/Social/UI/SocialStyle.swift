// Social group — view pieces shared by the social screens: haptics and notices, navigation and the reply-with-a-photo
// hand-off, private images as component photo sources, token-driven formats, emoji names, and text metrics.
// The visual components are Pass 3's ios/App/Sources/Components (C-01…C-35), used read-only.
import AppData
import AppModels
import DesignSystem
import SwiftUI
import UIKit

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
        case .sendFailed, .messageNotSent: return Copy.chatThreadSendFailed
        case .copied: return Copy.chatThreadToastCopied
        case .reactionFailed: return Copy.chatReactionsError
        case .editFailed: return Copy.chatThreadEditError
        case .photoSaved: return Copy.photoViewerToastSaved
        case .photoDeleted: return Copy.photoViewerToastDeleted
        case .saveFailed: return Copy.photoViewerErrorSave
        case .deleteFailed: return Copy.photoViewerErrorDelete
        case .tagError: return Copy.taggingError
        case .tagRemoveError: return Copy.taggingRemoveError
        case .tagNotFound: return Copy.taggingNotFound
        case .tagOffline: return Copy.taggingOffline
        case .recapSaved: return Copy.weekEditToastSaved
        case .albumSaved: return Copy.weekEditToastAlbumSaved
        case .albumRenamed: return Copy.albumsViewToastRenamed
        case .albumDeleted: return Copy.albumsViewToastDeleted
        case .changesFailed: return Copy.weekEditErrorSave
        case .playFailed: return Copy.chatVoiceErrorPlay
        case .recordFailed: return Copy.chatVoiceErrorRecord
        case .selfieFailed: return Copy.viewerSelfiereactionError
        case .selfieSent: return Copy.viewerSelfiereactionA11ySent
        }
    }
}

@MainActor
extension View {
    /// Plays each new feedback event's haptic token.
    func socialFeedback(_ feedback: SocialFeedback?) -> some View {
        sensoryFeedback(trigger: feedback) { _, new in new?.kind.haptic.sensoryFeedback }
    }

    /// Confirms each new notice (C-26: on iOS an accessibility announcement — nothing is drawn; `ToastCenter` keeps it
    /// as the last confirmation).
    func socialNotices(_ event: SocialNoticeEvent?, toasts: ToastCenter) -> some View {
        onChange(of: event) { _, new in
            guard let new else { return }
            if new.notice.isAnnouncementOnly {
                AccessibilityNotification.Announcement(new.notice.text).post()
            } else {
                toasts.show(new.notice.text)
            }
        }
    }

    /// The app-drawn headers (C-01 / C-02) replace the navigation bar on every social screen.
    func socialHidesNavigationBar() -> some View {
        toolbar(.hidden, for: .navigationBar)
    }

    /// Announces the loading state once (`week.history.a11y.loading`).
    func socialAnnouncesLoading(_ isLoading: Bool) -> some View {
        onChange(of: isLoading, initial: true) { _, loading in
            if loading { AccessibilityNotification.Announcement(Copy.weekHistoryA11yLoading).post() }
        }
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

    /// A route whose spec presents it modally (`collage.view` and the recap preview full screen): the shell's
    /// `PresentedRoute` when it lists the route (account's `PresentedRoute.modal(for:)`), else a push the shell moves
    /// off the stack itself (`ShellState.presentModalRoute`).
    static func presentRoute(_ route: AppRoute) {
        if let presented = PresentedRoute.modal(for: route), let shell = ShellState.active {
            shell.presentedRoute = presented
        } else {
            push(route)
        }
    }

    /// `safety.report` (account group's sheet).
    static func report(_ target: ReportTarget) {
        router.modal = .account(.report(target))
    }

    /// `camera.capture` for one group (the composer's camera glyph, add tiles, "Get this week started"); nil lets the
    /// person choose the groups in `camera.sendto`.
    static func openCamera(groupID: String?) {
        router.modal = .camera(groupID: groupID, invitationID: nil)
    }

    /// A person's wall: mine (`walls.mine`) or theirs (`walls.member`).
    static func openWall(of userID: UserID, me: UserID?) {
        push(userID == me ? .social(.wallMine) : .social(.wallMember(userID: userID.rawValue)))
    }
}

/// Reply to a photo with a photo (`photo.viewer` camera glyph, or the thread's camera while the reply bar quotes a
/// photo → `camera.capture` → `create_post(p_group_ids: [this group], p_reply_to_post_id)`). The opener stores the
/// replied post here and presents `AppModal.camera`; the capture pass reads `replyTarget(for:)` when it builds the
/// `PostDraft` (`PostDraft.replyToPostID`, exactly this group). The target is cleared when the camera closes.
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

    /// The post being replied to when the camera was opened for `groupID` from a social screen; nil otherwise.
    static func replyTarget(for groupID: String?) -> PostID? {
        guard let pending, pending.groupID == groupID else { return nil }
        return PostID(pending.postID)
    }

    static func clear() {
        pending = nil
    }
}

extension AppRouter {
    /// The camera for `groupID`, replying to `postID` with a photo.
    func presentCameraReplying(toPost postID: String, groupID: String) {
        PhotoReplyHandoff.begin(PhotoReplyHandoff.Target(groupID: groupID, postID: postID))
        modal = .camera(groupID: groupID, invitationID: nil)
    }
}

@MainActor
extension View {
    /// Forgets the reply target once the camera closes.
    func socialClearsReplyHandoff() -> some View {
        onChange(of: SocialNav.router.modal) { old, new in
            if old?.isCapture == true, new == nil { PhotoReplyHandoff.clear() }
        }
    }
}

// MARK: - Images

/// Private photos as component photo sources (`PhotoSource`): a storage path loads through the components'
/// `StorageImage` pipeline (signed URL, downsampled decode); the DEBUG demo / snapshot loader hands its images over
/// directly, so previews and snapshots draw real photos on the first frame.
@MainActor
enum SocialImages {
    static func source(_ path: String?) -> PhotoSource? {
        guard let path else { return nil }
        if let image = SocialServices.shared.images.cached(path) { return .image(image) }
        return .storage(path)
    }

    /// Warms the image cache for photos about to show (the viewer's neighbours).
    static func prefetch(_ paths: [String], pixels: Int) {
        guard pixels > 0 else { return }
        let data = SocialServices.shared.data
        Task {
            var items: [(path: String, url: URL)] = []
            for path in paths where SocialServices.shared.images.cached(path) == nil {
                if let url = try? await data.fileURL(path: path) { items.append((path, url)) }
            }
            ImagePipeline.shared.prefetch(items, pixels: pixels)
        }
    }
}

/// A private photo filling the proposed frame, with `placeholder` until it has loaded (the viewer's display rendition
/// over its thumbnail uses a clear placeholder).
struct SocialImage<Placeholder: View>: View {
    let path: String?
    var contentMode: ContentMode = .fill
    @ViewBuilder var placeholder: () -> Placeholder

    var body: some View {
        if let path, let image = SocialServices.shared.images.cached(path) {
            GeometryReader { proxy in
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
        } else {
            StorageImage(path: path, contentMode: contentMode, placeholder: placeholder)
        }
    }
}

// MARK: - Formats (token patterns)

enum SocialFormat {
    /// `chat.thread.layout.timeFormat`: the locale's short time ("10:00 PM").
    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    /// `chat.thread.layout.timeFormat.dayDividers`: "Today", "Yesterday", else the long date ("January 25, 2024").
    static func dayDivider(_ day: Date, now: Date = Date()) -> String {
        switch ChatThreadLayout.dayLabel(day, now: now) {
        case .today: return Copy.chatThreadDividerToday
        case .yesterday: return Copy.chatThreadDividerYesterday
        case let .date(date): return date.formatted(.dateTime.month(.wide).day().year())
        }
    }

    /// `photo.viewer.layout.dateFormat`: "Wednesday, July 5"; a photo of another year adds it.
    static func viewerDate(_ date: Date, now: Date = Date(), timeZone: TimeZone = .current) -> String {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(
            sameYear ? Tokens.Layouts.PhotoViewerLayoutDateFormat.pattern : Tokens.Layouts.PhotoViewerLayoutDateFormat.otherYear
        )
        return formatter.string(from: date)
    }

    /// `chat.voice.layout.durationFormat` ("0:38").
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

    /// The week's date range: the locale's interval for Monday–Sunday ("Jul 3 – 9", "Apr 29 – May 5").
    static func weekRange(_ weekStart: LocalDate, timeZone: TimeZone) -> String {
        interval(weekStart, timeZone: timeZone, template: "MMMd") // provenance-ok: date template (locale interval, spec)
    }

    /// The range for VoiceOver ("July 3 – 9" in full month names).
    static func spokenWeekRange(_ weekStart: LocalDate, timeZone: TimeZone) -> String {
        interval(weekStart, timeZone: timeZone, template: "MMMMd") // provenance-ok: date template (spoken form)
    }

    private static func interval(_ weekStart: LocalDate, timeZone: TimeZone, template: String) -> String {
        let formatter = DateIntervalFormatter()
        formatter.timeZone = timeZone
        formatter.dateTemplate = template
        let start = SocialCalendar.start(of: weekStart, in: timeZone)
        let end = SocialCalendar.start(of: weekStart.adding(days: 6), in: timeZone)
        return formatter.string(from: start, to: end)
    }

    /// Weekday on a strip tile ("Mon").
    static func weekday(_ date: Date, timeZone: TimeZone) -> String {
        var style = Date.FormatStyle.dateTime.weekday(.wide)
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

// MARK: - Accessibility labels

enum SocialA11y {
    /// `photo.viewer.a11y.photoMine` ("Your photo, {date}") / `photo.viewer.a11y.photo` ("{name}'s photo, {date}").
    static func photo(_ post: PostWithMedia, author: Profile?, me: UserID?) -> String {
        let date = SocialFormat.spokenDate(post.post.createdAt)
        if post.post.authorID == me { return Copy.photoViewerA11yPhotoMine(date: date) }
        return Copy.photoViewerA11yPhoto(name: author?.socialFirstName ?? "", date: date)
    }

    /// `week.history.a11y.tile` ("Monday, October 12, Ana's photo").
    static func tile(date: Date, name: String, timeZone: TimeZone) -> String {
        Copy.weekHistoryA11yTile(
            weekday: SocialFormat.weekday(date, timeZone: timeZone),
            date: SocialFormat.spokenDate(date, timeZone: timeZone),
            name: name
        )
    }

    /// `label`, then `chat.thread.a11y.video` ("Video, 10 seconds") when `media` is a video (`layout.global.videoMarker`).
    static func withVideo(_ label: String, media: Media?) -> String {
        guard let durationMs = media?.videoDurationMs else { return label }
        return label + ", " + Copy.chatThreadA11yVideo(duration: SocialFormat.spokenDuration(milliseconds: durationMs)) // provenance-ok: list separator joining two copy strings
    }

    /// `week.history.a11y.emptyDay` ("Thursday, October 15, no photos").
    static func emptyDay(_ date: Date, timeZone: TimeZone) -> String {
        Copy.weekHistoryA11yEmptyDay(
            weekday: SocialFormat.weekday(date, timeZone: timeZone),
            date: SocialFormat.spokenDate(date, timeZone: timeZone)
        )
    }

    /// The C-20 header read as "Week 27, July 3 – 9".
    static func weekHeader(number: Int, weekStart: LocalDate, timeZone: TimeZone, showsRange: Bool) -> String {
        let title = Copy.weekHistoryHeaderTitle(weekNumber: String(number))
        guard showsRange else { return title }
        return title + ", " + SocialFormat.spokenWeekRange(weekStart, timeZone: timeZone) // provenance-ok: list separator joining two copy strings
    }
}

// MARK: - Emoji

enum SocialEmoji {
    /// The emoji's name ("fire", "waving hand: light skin tone", "flag: Japan"), for VoiceOver (`chat.reactions`
    /// Accessibility): Unicode's CLDR name from the picker's catalog, else the system's character names.
    static func name(_ emoji: String) -> String {
        if let name = SocialEmojiCatalog.names[emoji] { return name }
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
        Copy.chatReactionsA11yCluster(emojiNames: emoji.map(name).joined(separator: ", ")) // provenance-ok: list separator
    }

    /// The quick reactions of `chat.reactions.layout.quickReactions` (🔥 then 💖), read from the token.
    static var quick: [String] {
        Tokens.Layouts.ChatReactionsLayoutQuickReactions.emoji.compactMap { character in
            SocialEmojiText.isEmoji(character) ? String(character) : nil
        }
    }
}

// MARK: - Numbers inside layout tokens

/// Some layout tokens carry their measured numbers inside their description (e.g. `chat.reactions.layout.chip.padding`
/// "12 horizontal / 8 vertical", `week.edit.layout.message.limit` "2000 characters"): read in order, never typed here.
enum SocialTokenNumbers {
    static func all(in text: String) -> [CGFloat] {
        var result: [CGFloat] = []
        var current = ""
        for character in text + " " {
            if character.isNumber || (character == "." && !current.isEmpty) {
                current.append(character)
            } else {
                if let value = Double(current) { result.append(CGFloat(value)) }
                current = ""
            }
        }
        return result
    }

    static func first(in text: String) -> CGFloat? { all(in: text).first }

    /// The whole number written right before `word` ("3 columns" → 3).
    static func count(of word: String, in text: String) -> Int? {
        let parts = text.split(whereSeparator: { $0 == " " || $0 == "," || $0 == ";" || $0 == ":" })
        for (index, part) in parts.enumerated() where index > 0 && part.hasPrefix(word) {
            if let value = Int(parts[index - 1]) { return value }
        }
        return nil
    }
}

// MARK: - Text metrics

/// Text metrics of a text role at the current Dynamic Type size (cap tops and baselines are how Retro's spacings are
/// measured; `TextMetrics` is the components' helper).
enum SocialMetrics {
    static func metrics(_ style: DSTextStyle) -> TextMetrics {
        TextMetrics(style: style, size: DSDynamicType.scaled(style.size, relativeTo: style.relativeTo))
    }

    /// From the top of a one-line text's frame to its cap top.
    static func capTopOffset(_ style: DSTextStyle) -> CGFloat { metrics(style).capTopOffset }

    /// From the last baseline to the bottom of the text's frame.
    static func belowBaseline(_ style: DSTextStyle) -> CGFloat { metrics(style).belowBaseline }

    /// The natural line height (ascender + below-baseline).
    static func lineHeight(_ style: DSTextStyle) -> CGFloat {
        let metrics = metrics(style)
        return metrics.ascender + metrics.belowBaseline
    }

    /// `value` scaled with Dynamic Type like the text role it sits next to.
    static func scaled(_ value: CGFloat, like style: DSTextStyle) -> CGFloat {
        DSDynamicType.scaled(value, relativeTo: style.relativeTo)
    }
}

/// Text roles the social specs derive from the global roles.
enum SocialTextRole {
    /// Message and comment text: `body` with its lines `chat.thread.dimension.rowLinePitch` apart (C-16, TC-2B).
    static let threadBody = DSTextStyle(
        family: TextRole.body.family, size: TextRole.body.size, weight: TextRole.body.weight,
        relativeTo: TextRole.body.relativeTo, lineHeight: Tokens.Sizes.chatThreadDimensionRowLinePitch
    )

    /// A message of 1…`chat.thread.count.emojiOnlyMax` emoji: `fontSize.global.headerTitle` in the body face
    /// (Dynamic Type of `headerTitle`).
    static let emojiOnly = DSTextStyle(
        family: TextRole.body.family, size: Tokens.FontSizes.globalHeaderTitle, weight: TextRole.body.weight,
        relativeTo: TextRole.headerTitle.relativeTo
    )

    /// Emoji in the reaction chip: `fontSize.global.pill` (`chat.reactions.layout.chip.emoji`).
    static let chipEmoji = DSTextStyle(
        family: TextRole.pill.family, size: Tokens.FontSizes.globalPill, weight: TextRole.body.weight,
        relativeTo: TextRole.pill.relativeTo
    )

    /// Picker cells: `fontSize.global.headerTitle` (`chat.reactions.layout.picker.grid`).
    static let pickerEmoji = emojiOnly
}
