// Social group — values shared by the social view models. Foundation + AppData only.
import AppData
import AppModels
import Foundation

/// What a screen shows for its main content (each spec's "States" table).
enum SocialPhase: Equatable, Sendable {
    /// First load, nothing to show yet.
    case loading
    /// Content (possibly the offline copy; see the model's `isOffline`).
    case ready
    /// Loaded, nothing there.
    case empty
    /// The load failed and nothing is cached.
    case failed
    /// Offline and nothing is cached.
    case offline
}

/// A haptic-worthy moment; the views map each kind to its `Tokens.Haptics.*` token
/// (each spec's "Haptics" table).
enum SocialFeedbackKind: Equatable, Sendable {
    /// `haptic.global.send`
    case sent
    /// `haptic.global.error`
    case failed
    /// `haptic.global.warning` (a destructive action was confirmed)
    case warning
    /// `haptic.global.success`
    case success
    /// `haptic.global.select`
    case select
}

/// One feedback event; `id` changes every time so `.sensoryFeedback(trigger:)` fires again for the same kind.
struct SocialFeedback: Equatable, Sendable {
    var kind: SocialFeedbackKind
    var id: Int
}

/// A line the screen announces (and, once the toast dwell time is captured, shows as a toast).
enum SocialNotice: Equatable, Sendable {
    case sendFailed
    case reactionFailed
    case photoSaved
    case photoDeleted
    case saveFailed
    case deleteFailed
    case tagError
    case tagNotFound
    case tagOffline
    case recapSaved
    case albumSaved
    case albumRenamed
    case albumDeleted
    /// `week.edit.error.save` (album rename / delete failed).
    case changesFailed
    case playFailed
    case recordFailed
}

/// One notice event; `id` changes every time.
struct SocialNoticeEvent: Equatable, Sendable {
    var notice: SocialNotice
    var id: Int
}

/// Emits feedback and notices with increasing ids (shared by every social view model).
struct SocialSignals: Equatable, Sendable {
    private(set) var feedback: SocialFeedback?
    private(set) var notice: SocialNoticeEvent?
    private var counter = 0

    mutating func emit(_ kind: SocialFeedbackKind) {
        counter += 1
        feedback = SocialFeedback(kind: kind, id: counter)
    }

    mutating func post(_ notice: SocialNotice) {
        counter += 1
        self.notice = SocialNoticeEvent(notice: notice, id: counter)
    }
}

/// The reactions on one post, as rows `(user, emoji)` — who reacted with what, never how many
/// (docs/API.md §5.10; `chat.reactions`: no number anywhere). Deliberately has no count API.
struct ReactionSummary: Equatable, Sendable {
    private(set) var rows: [Reaction]

    init(_ rows: [Reaction] = []) {
        self.rows = []
        for row in rows { insert(row) }
    }

    /// One sticker per distinct emoji, in the order the data arrives (first reacted first; the
    /// sticker order itself is BLOCKED, `chat.reactions.layout.clusterOrder`).
    var distinctEmoji: [String] {
        var seen = Set<String>()
        return rows.compactMap { seen.insert($0.emoji).inserted ? $0.emoji : nil }
    }

    var isEmpty: Bool { rows.isEmpty }

    func contains(userID: UserID, emoji: String) -> Bool {
        rows.contains { $0.userID == userID && $0.emoji == emoji }
    }

    /// Adds a row unless the same person already reacted with the same emoji (`react` is idempotent).
    mutating func insert(_ reaction: Reaction) {
        guard !contains(userID: reaction.userID, emoji: reaction.emoji) else { return }
        rows.append(reaction)
    }

    mutating func remove(userID: UserID, emoji: String) {
        rows.removeAll { $0.userID == userID && $0.emoji == emoji }
    }

    /// Groups rows by post (feed pages, thread pages).
    static func byPost(_ reactions: [Reaction]) -> [PostID: ReactionSummary] {
        var result: [PostID: ReactionSummary] = [:]
        for reaction in reactions {
            result[reaction.postID, default: ReactionSummary()].insert(reaction)
        }
        return result
    }
}

extension Array where Element: Hashable {
    /// The elements in order, without repeats.
    func socialUnique() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension Media {
    /// The storage path a grid tile shows (`thumb_path`, the original until renditions are ready).
    var gridPath: String? { imagePath(for: .thumb) }
    /// The storage path the full-screen viewer shows (`display_path`, the original until ready).
    var displayImagePath: String? { imagePath(for: .display) }
}

extension Profile {
    /// The first name shown in titles and quotes (falls back to the whole display name).
    var socialFirstName: String { firstName ?? displayName }
}

/// Dates in a group's week (Monday start, docs/API.md §5.14 `week_start`; ISO-8601 week numbers).
enum SocialCalendar {
    /// ISO-8601 calendar in `timeZone` (Monday first, minimum four days in the first week).
    static func iso(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone
        return calendar
    }

    /// Midnight at the start of `date` in `timeZone`.
    static func start(of date: LocalDate, in timeZone: TimeZone) -> Date {
        var components = DateComponents()
        components.year = date.year
        components.month = date.month
        components.day = date.day
        return iso(timeZone).date(from: components) ?? Date(timeIntervalSince1970: TimeInterval(date.dayNumber) * 86_400)
    }

    /// The Monday of the week containing `date` (group-local).
    static func weekStart(containing date: Date, in timeZone: TimeZone) -> LocalDate {
        let calendar = iso(timeZone)
        let day = LocalDate(date, in: timeZone)
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday … 7 = Saturday
        let daysSinceMonday = (weekday + 5) % 7
        return day.adding(days: -daysSinceMonday)
    }

    /// The ISO-8601 week number of the week starting `weekStart`.
    static func weekNumber(of weekStart: LocalDate, in timeZone: TimeZone) -> Int {
        iso(timeZone).component(.weekOfYear, from: start(of: weekStart, in: timeZone))
    }

    /// The seven days of the week starting `weekStart`.
    static func days(of weekStart: LocalDate) -> [LocalDate] {
        (0..<7).map { weekStart.adding(days: $0) }
    }
}
