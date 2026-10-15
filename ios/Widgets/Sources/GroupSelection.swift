import AppIntents
import AppModels
import WidgetKit

// Surfaces: widget.home.small (configuration, shared by every widget size and the Lock Screen kind).
// The widget's "choose group" configuration. Its titles are LocalizedStringResource keys (App
// Intents metadata needs compile-time literals): the copy keys `widget.home.small.configuration.*`
// (design/copy/capture.json, MERGE_DECISIONS C-25). Their texts reach the extension only through a
// Localizable.strings entry per key, which the copy pipeline does not emit yet (reported).

/// A group the widget can show, from the group list the app writes to the App Group.
struct GroupEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "widget.home.small.configuration.groupType")
    }

    static var defaultQuery: GroupEntityQuery { GroupEntityQuery() }

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct GroupEntityQuery: EntityQuery {
    private var groups: [GroupEntity] {
        WidgetStore.forBundle(.main).groups().map { GroupEntity(id: $0.id, name: $0.name) }
    }

    func entities(for identifiers: [GroupEntity.ID]) async throws -> [GroupEntity] {
        let all = groups
        return identifiers.compactMap { id in all.first { $0.id == id } }
    }

    func suggestedEntities() async throws -> [GroupEntity] {
        groups
    }

    func defaultResult() async -> GroupEntity? {
        groups.first
    }
}

struct SelectGroupIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.home.small.configuration.title" }

    @Parameter(title: "widget.home.small.configuration.group")
    var group: GroupEntity?

    init() {}
}
