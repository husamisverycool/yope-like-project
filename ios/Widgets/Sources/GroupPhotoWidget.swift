// Surfaces: widget.home.small / .medium / .large / .xl, widget.lock.rect / .circular / .inline, widget.arrival,
// camera.fromwidget — visual reference Retro's Glance widgets ("Group Updates", Albums variant), mechanics Locket, sizes
// and rendering Apple HIG Widgets.
// Reference images: references/auto/retro/apk/widget_preview_journals.webp, references/auto/locket/store/locket-store-03.png,
// locket-store-06.png, references/auto/locket/frames/locket-tt-7168613044728155438-15.133s-widget-placeholder-just-added.jpg →
// 15.167s-widget-photo-arrived.jpg, references/auto/platform/hig-widgets-ios-dimensions.png (design/surfaces/widget.*.md).
// Two widget kinds: the Home Screen photo widget (small, medium, large; extra large on iPad; one group or All Groups; a
// style, widget.styles) and the Lock Screen widget (circular, rectangular, inline). Both read only the App Group
// `WidgetStore`; a tap opens the camera for the widget's group (the day's collage while it shows one).
import AppIntents
import AppModels
import DesignSystem
import SwiftUI
import UIKit
import WidgetKit

/// Reads the newest photo or same-moment collage for the configured group from the App Group.
/// New photos arrive by push: the Notification Service Extension (or the app) writes the
/// rendition and requests a reload. Those reloads are budgeted and best effort
/// (docs/PLATFORM_CONSTRAINTS.md §1.2), so each timeline also asks to be rebuilt after a random
/// 15–60 minutes (§1.6 step 4: inside the 40–70 daily refreshes, jittered per request) to pick
/// up renditions whose reload was dropped. On a failed download the last photo stays (HIG).
struct GroupPhotoProvider: AppIntentTimelineProvider {
    static let safetyRefreshSeconds: ClosedRange<TimeInterval> = 15 * 60...60 * 60

    /// The Lock Screen kind skips the colour rendition (`widget.lock.rect.layout.rendering`: vibrant, no colour photo).
    var lockScreen = false

    func placeholder(in context: Context) -> GroupPhotoEntry {
        .loading(at: Date())
    }

    func snapshot(for configuration: SelectGroupIntent, in context: Context) async -> GroupPhotoEntry {
        let entry = entry(for: configuration, store: WidgetStore.forBundle(.main), at: Date())
        // The gallery preview with no photo yet shows the loading placeholder.
        if context.isPreview && entry.snapshot == nil { return .loading(at: Date()) }
        return entry
    }

    func timeline(for configuration: SelectGroupIntent, in context: Context) async -> Timeline<GroupPhotoEntry> {
        let now = Date()
        let refresh = now.addingTimeInterval(TimeInterval.random(in: Self.safetyRefreshSeconds))
        return Timeline(entries: [entry(for: configuration, store: WidgetStore.forBundle(.main), at: now)], policy: .after(refresh))
    }

    func entry(for configuration: SelectGroupIntent, store: WidgetStore, at date: Date) -> GroupPhotoEntry {
        let group = configuration.group?.id
        return lockScreen
            ? GroupWidgetEntryResolver.lockScreenEntry(configuredGroupID: group, store: store, at: date)
            : GroupWidgetEntryResolver.entry(configuredGroupID: group, store: store, at: date)
    }
}

/// The Home Screen kind's timeline: the configured group, or All Groups, drawn in the configured style
/// (`StyledEntryResolver.group`); the same random 15–60-minute safety refresh as `GroupPhotoProvider`.
struct GroupHomeProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StyledPhotoEntry {
        .loading(at: Date())
    }

    func snapshot(for configuration: SelectGroupIntent, in context: Context) async -> StyledPhotoEntry {
        let entry = entry(for: configuration, at: Date())
        if context.isPreview && !entry.showsItem { return .loading(at: Date()) }
        return entry
    }

    func timeline(for configuration: SelectGroupIntent, in context: Context) async -> Timeline<StyledPhotoEntry> {
        let now = Date()
        let refresh = now.addingTimeInterval(TimeInterval.random(in: GroupPhotoProvider.safetyRefreshSeconds))
        return Timeline(entries: [entry(for: configuration, at: now)], policy: .after(refresh))
    }

    private func entry(for configuration: SelectGroupIntent, at date: Date) -> StyledPhotoEntry {
        StyledEntryResolver.group(
            configuredGroupID: configuration.group?.id, allGroups: configuration.group?.isAllGroups ?? false,
            style: configuration.style?.style, store: WidgetStore.forBundle(.main), at: date
        )
    }
}

/// Home Screen: the photo fills the widget as the removable container background (content margins disabled); one
/// layout at every size (RC-11), in the configured style (widget.styles). Gallery: "Group Updates" /
/// `widget.home.small.gallery.description` (Retro names its widgets by content, `retro.voice.widget`).
struct GroupPhotoWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: GroupWidgetKinds.home, intent: SelectGroupIntent.self, provider: GroupHomeProvider()) { entry in
            StyledPhotoWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(Copy.widgetHomeSmallGalleryName))
        .description(Text(Copy.widgetHomeSmallGalleryDescription))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

/// Lock Screen (vibrant): circular = the poster's avatar, rectangular = C-16 row (avatar, name over group), inline =
/// "{name} · {group}". Gallery: "Group Updates" / `widget.lock.rect.gallery.description`.
struct GroupLockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: GroupWidgetKinds.lockScreen, intent: SelectGroupIntent.self, provider: GroupPhotoProvider(lockScreen: true)) { entry in
            GroupLockWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(Copy.widgetLockRectGalleryName))
        .description(Text(Copy.widgetLockRectGalleryDescription))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

/// Every home-screen photo widget (Group Updates, Friend Updates, Your Memories): the styled overlay over the styled,
/// removable container background; the whole widget is the tap.
struct StyledPhotoWidgetView: View {
    let entry: StyledPhotoEntry

    var body: some View {
        let presentation = entry.presentation
        StyledWidgetOverlay(presentation: presentation)
            .containerBackground(for: .widget) {
                StyledWidgetBackground(presentation: presentation)
            }
            .widgetURL(entry.tapURL)
    }
}

struct GroupLockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GroupPhotoEntry

    var body: some View {
        let content = entry.content
        Group {
            switch family {
            case .accessoryInline:
                WidgetInlineSlot(content: content)
            case .accessoryCircular:
                WidgetCircularSlot(content: content)
            default:
                WidgetRectangularSlot(content: content)
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(entry.tapURL)
    }
}
