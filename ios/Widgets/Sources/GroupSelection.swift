import AppIntents
import AppModels
import DesignSystem
import WidgetKit

// Surfaces: widget.home.small (configuration, shared by every widget size and the Lock Screen kind), widget.friend,
// widget.memories, widget.styles. The widgets' configuration intents. Their titles are LocalizedStringResource keys (App
// Intents metadata needs compile-time literals): the copy keys `widget.*.configuration.*` (design/copy/capture.json,
// MERGE_DECISIONS C-25), resolved from the extension's Localizable table that tools/designgen.mjs generates
// (ios/Widgets/Resources/en.lproj/Localizable.strings). Entity names shown in the pickers come from the App Group store
// and `Copy` at run time.

/// A group the widget can show, from the group list the app writes to the App Group — or "All Groups"
/// (`widget.home.small.layout.allGroups`: Retro's "All Friends" row, the newest photo across the person's groups).
struct GroupEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "widget.home.small.configuration.groupType")
    }

    static var defaultQuery: GroupEntityQuery { GroupEntityQuery() }

    /// The id of the "All Groups" choice (never a group id: those are UUIDs).
    static let allGroupsID = "all-groups"

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    var isAllGroups: Bool { id == Self.allGroupsID }

    static var allGroups: GroupEntity {
        GroupEntity(id: allGroupsID, name: Copy.widgetHomeSmallConfigurationAllGroups)
    }
}

struct GroupEntityQuery: EntityQuery {
    private var groups: [GroupEntity] {
        WidgetStore.forBundle(.main).groups().map { GroupEntity(id: $0.id, name: $0.name) }
    }

    /// "All Groups" first, as Retro's picker lists "All Friends" first.
    private var choices: [GroupEntity] { [.allGroups] + groups }

    func entities(for identifiers: [GroupEntity.ID]) async throws -> [GroupEntity] {
        let all = choices
        return identifiers.compactMap { id in all.first { $0.id == id } }
    }

    func suggestedEntities() async throws -> [GroupEntity] {
        choices
    }

    func defaultResult() async -> GroupEntity? {
        groups.first
    }
}

struct SelectGroupIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.home.small.configuration.title" }

    @Parameter(title: "widget.home.small.configuration.group")
    var group: GroupEntity?

    @Parameter(title: "widget.styles.configuration.style")
    var style: WidgetStyleEntity?

    init() {}
}

// MARK: - Style (widget.styles)

/// One of the widget styles (`widget.styles.layout.styles`). While the person has no premium, the premium ones carry the
/// premium marker (`paywall.locked.badge`) as their subtitle; choosing one still works — the widget draws Photo and its
/// tap opens the paywall once per session.
struct WidgetStyleEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "widget.styles.configuration.style")
    }

    static var defaultQuery: WidgetStyleQuery { WidgetStyleQuery() }

    let id: String
    let locked: Bool

    var style: WidgetPhotoStyle { WidgetPhotoStyle(rawValue: id) ?? .photo }

    var displayRepresentation: DisplayRepresentation {
        let name = WidgetStyleEntity.name(style)
        if locked {
            return DisplayRepresentation(title: "\(name)", subtitle: "\(Copy.paywallLockedBadge)")
        }
        return DisplayRepresentation(title: "\(name)", subtitle: "\(WidgetStyleEntity.description(style))")
    }

    static func name(_ style: WidgetPhotoStyle) -> String {
        switch style {
        case .photo: return Copy.widgetStylesNamePhoto
        case .date: return Copy.widgetStylesNameDate
        case .frame: return Copy.widgetStylesNameFrame
        }
    }

    static func description(_ style: WidgetPhotoStyle) -> String {
        switch style {
        case .photo: return Copy.widgetStylesDescriptionPhoto
        case .date: return Copy.widgetStylesDescriptionDate
        case .frame: return Copy.widgetStylesDescriptionFrame
        }
    }
}

struct WidgetStyleQuery: EntityQuery {
    private var choices: [WidgetStyleEntity] {
        let premium = WidgetStore.forBundle(.main).isPremium
        return WidgetPhotoStyle.allCases.map { WidgetStyleEntity(id: $0.rawValue, locked: $0.isLocked(isPremium: premium)) }
    }

    func entities(for identifiers: [WidgetStyleEntity.ID]) async throws -> [WidgetStyleEntity] {
        let all = choices
        return identifiers.compactMap { id in all.first { $0.id == id } }
    }

    func suggestedEntities() async throws -> [WidgetStyleEntity] {
        choices
    }

    func defaultResult() async -> WidgetStyleEntity? {
        choices.first { $0.style == .photo }
    }
}

/// The memories widget's configuration: its style only (`widget.memories` shows the person's own photos).
struct SelectStyleIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.styles.configuration.title" }

    @Parameter(title: "widget.styles.configuration.style")
    var style: WidgetStyleEntity?

    init() {}
}

// MARK: - Friend (widget.friend)

/// A person the friend widget can follow: everyone who shares a group with the person, minus blocks (`widget_people`,
/// written to the App Group by the app).
struct FriendEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "widget.friend.configuration.friend")
    }

    static var defaultQuery: FriendEntityQuery { FriendEntityQuery() }

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct FriendEntityQuery: EntityQuery {
    private var people: [FriendEntity] {
        WidgetStore.forBundle(.main).people().map { FriendEntity(id: $0.id, name: $0.name) }
    }

    func entities(for identifiers: [FriendEntity.ID]) async throws -> [FriendEntity] {
        let all = people
        return identifiers.compactMap { id in all.first { $0.id == id } }
    }

    func suggestedEntities() async throws -> [FriendEntity] {
        people
    }

    /// No default: the widget asks for a friend ("Tap to choose a friend") until one is chosen.
    func defaultResult() async -> FriendEntity? {
        nil
    }
}

struct SelectFriendIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.friend.configuration.title" }

    @Parameter(title: "widget.friend.configuration.friend")
    var friend: FriendEntity?

    @Parameter(title: "widget.styles.configuration.style")
    var style: WidgetStyleEntity?

    init() {}
}
