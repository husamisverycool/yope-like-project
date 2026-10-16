// Surface: widget.countdown — the next plan, in days (design/surfaces/widget.countdown.md; MERGE PL-9 … PL-11). Visual
// reference Retro's Glance widget (references/auto/retro/apk/widget_preview_journals.webp), mechanics Apple Invites'
// widget (references/auto/apple-invites/store/apple-invites-store-08.png; "Edit Widget" to change the featured event),
// sizes and refresh Apple HIG Widgets / WidgetKit. Reads only the App Group `WidgetStore` (the app writes the plans);
// a tap opens the plan's page.
import AppIntents
import AppModels
import DesignSystem
import SwiftUI
import WidgetKit

// The configuration's titles are LocalizedStringResource keys (App Intents metadata needs compile-time literals): the
// copy keys `widget.countdown.configuration.*` (design/copy/plans.json). Their texts reach the extension only through a
// Localizable.strings entry per key, which the copy pipeline does not emit yet (as `SelectGroupIntent`).

/// "All Groups" (the default: Apple's "your next event") or one of the groups the app wrote to the App Group.
struct CountdownGroupEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "widget.countdown.configuration.group")
    }

    static var defaultQuery: CountdownGroupQuery { CountdownGroupQuery() }

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var allGroups: CountdownGroupEntity {
        CountdownGroupEntity(id: PlanCountdownResolver.allGroupsID, name: Copy.widgetCountdownConfigurationAllGroups)
    }
}

struct CountdownGroupQuery: EntityQuery {
    private var choices: [CountdownGroupEntity] {
        [.allGroups] + WidgetStore.forBundle(.main).groups().map { CountdownGroupEntity(id: $0.id, name: $0.name) }
    }

    func entities(for identifiers: [CountdownGroupEntity.ID]) async throws -> [CountdownGroupEntity] {
        let all = choices
        return identifiers.compactMap { id in all.first { $0.id == id } }
    }

    func suggestedEntities() async throws -> [CountdownGroupEntity] {
        choices
    }

    func defaultResult() async -> CountdownGroupEntity? {
        .allGroups
    }
}

struct SelectCountdownGroupIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.countdown.configuration.title" }

    @Parameter(title: "widget.countdown.configuration.group")
    var group: CountdownGroupEntity?

    init() {}
}

/// Entries for today and each following local midnight up to the day after the plan's (policy `.atEnd`): the day
/// count changes at midnight only, with the instant swap of `widget.arrival.duration.transition` (no animation). On a
/// missing store the last entry stays (HIG: don't hide stale data).
struct PlanCountdownProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PlanCountdownEntry {
        .loading(at: Date())
    }

    func snapshot(for configuration: SelectCountdownGroupIntent, in context: Context) async -> PlanCountdownEntry {
        let entry = PlanCountdownResolver.entry(
            configuredGroupID: configuration.group?.id, store: WidgetStore.forBundle(.main), at: Date(), calendar: .current
        )
        if context.isPreview && entry.state != .plan { return .loading(at: Date()) }
        return entry
    }

    func timeline(for configuration: SelectCountdownGroupIntent, in context: Context) async -> Timeline<PlanCountdownEntry> {
        let entries = PlanCountdownResolver.entries(
            configuredGroupID: configuration.group?.id, store: WidgetStore.forBundle(.main), now: Date(), calendar: .current
        )
        return Timeline(entries: entries, policy: .atEnd)
    }
}

/// systemSmall and systemMedium (`widget.home.small.layout.size`, `widget.home.medium.layout.size`): the photo as the
/// removable container background (content margins disabled), one layout at both sizes (RC-11). Gallery:
/// `widget.countdown.gallery.name` / `.gallery.description`.
struct PlanCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.planCountdown, intent: SelectCountdownGroupIntent.self, provider: PlanCountdownProvider()) { entry in
            PlanCountdownWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(Copy.widgetCountdownGalleryName))
        .description(Text(Copy.widgetCountdownGalleryDescription))
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct PlanCountdownWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PlanCountdownEntry

    var body: some View {
        let content = entry.content
        PlanCountdownOverlay(content: content, showsGroup: family == .systemMedium)
            .containerBackground(for: .widget) {
                PlanCountdownBackground(content: content)
            }
            .widgetURL(entry.tapURL)
    }
}
