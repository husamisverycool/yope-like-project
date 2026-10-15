import AppIntents
import AppModels
import WidgetKit

// The widget's "choose group" configuration. Its titles are LocalizedStringResource keys
// (App Intents metadata needs compile-time literals); their texts belong in design/copy.json
// and reach the extension's Localizable.strings through the copy pipeline.

/// A group the widget can show, from the group list the app writes to the App Group.
struct GroupEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "widget.configuration.group.type")
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
    static var title: LocalizedStringResource { "widget.configuration.title" }

    @Parameter(title: "widget.configuration.group")
    var group: GroupEntity?

    init() {}
}
