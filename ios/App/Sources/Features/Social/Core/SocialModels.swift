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
    /// `chat.thread.sendFailed` for a message that stays in the thread with the failed-message layout: announced only
    /// (the status line under the message shows it).
    case messageNotSent
    /// `chat.thread.toast.copied`
    case copied
    case reactionFailed
    case photoSaved
    case photoDeleted
    case saveFailed
    case deleteFailed
    case tagError
    /// `tagging.removeError` (untag failed).
    case tagRemoveError
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
    /// `viewer.selfiereaction.error` (the face is taken back out of the stack).
    case selfieFailed
    /// `viewer.selfiereaction.a11y.sent`: the announcement after a selfie is sent.
    case selfieSent
}

extension SocialNotice {
    /// Shown on screen already (the failed-message label), or an iOS announcement by spec (viewer.selfiereaction's
    /// sent and error lines: "Android Toast / iOS announcement"): announced to VoiceOver, never drawn as a toast.
    var isAnnouncementOnly: Bool { self == .messageNotSent || self == .selfieSent || self == .selfieFailed }
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

    /// The distinct emoji, newest first (`chat.reactions.layout.clusterOrder`): a newly added emoji enters at the
    /// leading end and an emoji used again moves to the front. The chip shows the first
    /// `chat.reactions.count.clusterMaxVisible` of them.
    var distinctEmoji: [String] {
        var seen = Set<String>()
        return rows.reversed().compactMap { seen.insert($0.emoji).inserted ? $0.emoji : nil }
    }

    /// The rows of the Reactions sheet (`chat.reactions.layout.list`: one per person and emoji), newest first by
    /// `reactions.created_at` (`chat.reactions.layout.listOrder`: the reaction list of Stream Chat's SDK); rows with the
    /// same time keep the later-inserted one first.
    func listRows() -> [Reaction] {
        rows.enumerated()
            .sorted { lhs, rhs in lhs.element.createdAt != rhs.element.createdAt ? lhs.element.createdAt > rhs.element.createdAt : lhs.offset > rhs.offset }
            .map(\.element)
    }

    /// The emoji this person reacted with (highlighted in the picker, `chat.reactions.layout.unreact`).
    func emoji(by userID: UserID) -> Set<String> {
        Set(rows.filter { $0.userID == userID }.map(\.emoji))
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

/// `walls.browse.layout.rowOrder` (Apple Photos' people grid, "Sort by Name"): display name A to Z in the device
/// locale's collation ignoring case and accents (Android: `Collator` PRIMARY — the same comparison); equal names by
/// user id so the order is stable.
enum SocialOrdering {
    static func byName<Item>(_ items: [Item], name: (Item) -> String, id: (Item) -> String, locale: Locale = .current) -> [Item] {
        items.sorted { lhs, rhs in
            switch name(lhs).compare(name(rhs), options: [.caseInsensitive, .diacriticInsensitive], range: nil, locale: locale) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: return id(lhs) < id(rhs)
            }
        }
    }
}

/// Emoji-only messages (`chat.thread`: a message of only 1…`chat.thread.count.emojiOnlyMax` emoji renders at
/// `fontSize.global.headerTitle`).
enum SocialEmojiText {
    /// How many emoji `text` holds when it is made of emoji only (spaces ignored); nil otherwise.
    static func emojiOnlyCount(_ text: String) -> Int? {
        let characters = text.filter { !$0.isWhitespace }
        guard !characters.isEmpty, characters.allSatisfy(isEmoji) else { return nil }
        return characters.count
    }

    /// Emoji shown as emoji: emoji presentation by default, or a sequence (variation selector, keycap, ZWJ, skin tone).
    static func isEmoji(_ character: Character) -> Bool {
        guard let first = character.unicodeScalars.first else { return false }
        return first.properties.isEmojiPresentation || (first.properties.isEmoji && character.unicodeScalars.count > 1)
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

    /// The ISO-8601 week number of the week containing `date` (group-local).
    static func weekNumber(containing date: Date, in timeZone: TimeZone) -> Int {
        iso(timeZone).component(.weekOfYear, from: date)
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
