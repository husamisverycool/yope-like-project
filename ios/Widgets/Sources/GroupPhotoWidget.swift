// Surfaces: widget.home.small / .medium / .large / .xl, widget.lock.rect / .circular / .inline,
// widget.arrival, camera.fromwidget — reference app: Locket (+ Apple HIG Widgets).
// Reference images: references/auto/locket/store/locket-store-03.png, locket-store-06.png,
// references/auto/locket/frames/locket-tt-7168613044728155438-15.133s-widget-placeholder-just-added.jpg →
// 15.167s-widget-photo-arrived.jpg, references/auto/platform/hig-widgets-ios-dimensions.png
// (design/surfaces/widget.*.md). Two widget kinds: the Home Screen photo widget (small, medium,
// large; extra large on iPad) and the Lock Screen widget (circular, rectangular, inline). Both read
// only the App Group `WidgetStore`; a tap opens the camera for the widget's group.
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

    /// The Lock Screen kind resolves the newest single photo (`widget.lock.rect.layout.content`).
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

/// Home Screen: the photo fills the widget as the removable container background (content
/// margins disabled; the overlay sits inside the 6-pt inset, C-6). One description for all sizes;
/// the gallery name is `{app_name}` (BLOCKED), so the system shows the app's name.
struct GroupPhotoWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: GroupWidgetKinds.home, intent: SelectGroupIntent.self, provider: GroupPhotoProvider()) { entry in
            GroupPhotoWidgetView(entry: entry)
        }
        .description(Text(Copy.widgetHomeSmallGalleryDescription))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

/// Lock Screen (vibrant): circular = sender avatar, rectangular = avatar + caption, inline = caption.
struct GroupLockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: GroupWidgetKinds.lockScreen, intent: SelectGroupIntent.self, provider: GroupPhotoProvider(lockScreen: true)) { entry in
            GroupLockWidgetView(entry: entry)
        }
        .description(Text(Copy.widgetLockRectGalleryDescription))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct GroupPhotoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GroupPhotoEntry

    var body: some View {
        let content = entry.content
        WidgetOverlay(content: content, family: family)
            .containerBackground(for: .widget) {
                WidgetEmptyState(content: content)
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
