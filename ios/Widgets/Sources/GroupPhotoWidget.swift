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

/// Kinds of this extension. The Home Screen kind keeps the shared `WidgetKind.groupPhoto` that the
/// app and the Notification Service Extension reload.
enum GroupWidgetKinds {
    static let home = WidgetKind.groupPhoto
    static let lockScreen = "GroupPhotoLockWidget"
    static let all = [home, lockScreen]
}

struct GroupPhotoEntry: TimelineEntry {
    let date: Date
    /// The configured group, or the group of the newest photo when none is configured.
    let groupID: String?
    let state: GroupWidgetContent.State
    let snapshot: WidgetSnapshot?
    let photoURL: URL?
    let avatarURL: URL?

    static func loading(at date: Date) -> GroupPhotoEntry {
        GroupPhotoEntry(date: date, groupID: nil, state: .loading, snapshot: nil, photoURL: nil, avatarURL: nil)
    }

    /// Tapping opens the camera for this group (`camera.fromwidget`).
    var tapURL: URL? {
        DeepLinkParser(universalLinkHosts: []).url(for: .camera(groupID: groupID))
    }

    /// The view content; images are read from the App Group files (no network).
    var content: GroupWidgetContent {
        GroupWidgetContent(
            state: state,
            groupName: snapshot?.groupName,
            senderName: snapshot?.senderDisplayName,
            caption: snapshot?.caption,
            postedAt: snapshot?.postedAt,
            photo: photoURL.flatMap { UIImage(contentsOfFile: $0.path) },
            avatar: avatarURL.flatMap { UIImage(contentsOfFile: $0.path) }
        )
    }
}

/// Reads the newest photo or same-moment collage for the configured group from the App Group.
/// New photos arrive by push: the Notification Service Extension (or the app) writes the
/// rendition and requests a reload. Those reloads are budgeted and best effort
/// (docs/PLATFORM_CONSTRAINTS.md §1.2), so each timeline also asks to be rebuilt after a random
/// 15–60 minutes (§1.6 step 4: inside the 40–70 daily refreshes, jittered per request) to pick
/// up renditions whose reload was dropped. On a failed download the last photo stays (HIG).
struct GroupPhotoProvider: AppIntentTimelineProvider {
    static let safetyRefreshSeconds: ClosedRange<TimeInterval> = 15 * 60...60 * 60

    func placeholder(in context: Context) -> GroupPhotoEntry {
        .loading(at: Date())
    }

    func snapshot(for configuration: SelectGroupIntent, in context: Context) async -> GroupPhotoEntry {
        let entry = Self.entry(for: configuration, store: WidgetStore.forBundle(.main), at: Date())
        // The gallery preview with no photo yet shows the loading placeholder.
        if context.isPreview && entry.snapshot == nil { return .loading(at: Date()) }
        return entry
    }

    func timeline(for configuration: SelectGroupIntent, in context: Context) async -> Timeline<GroupPhotoEntry> {
        let now = Date()
        let refresh = now.addingTimeInterval(TimeInterval.random(in: Self.safetyRefreshSeconds))
        return Timeline(entries: [Self.entry(for: configuration, store: WidgetStore.forBundle(.main), at: now)], policy: .after(refresh))
    }

    static func entry(for configuration: SelectGroupIntent, store: WidgetStore, at date: Date) -> GroupPhotoEntry {
        entry(configuredGroupID: configuration.group?.id, store: store, at: date)
    }

    /// - not set up: no group (none chosen, left, deleted, signed out: the app's group list lacks it);
    /// - empty: the configured group has no photo yet;
    /// - photo / collage: the newest item. Muted groups still update.
    static func entry(configuredGroupID: String?, store: WidgetStore, at date: Date) -> GroupPhotoEntry {
        let groups = store.groups()
        let snapshot: WidgetSnapshot?
        let groupID: String?
        if let configuredGroupID {
            guard groups.contains(where: { $0.id == configuredGroupID }) else {
                return GroupPhotoEntry(date: date, groupID: nil, state: .notSetUp, snapshot: nil, photoURL: nil, avatarURL: nil)
            }
            groupID = configuredGroupID
            snapshot = store.latestSnapshot(groupID: configuredGroupID)
        } else {
            guard !groups.isEmpty else {
                return GroupPhotoEntry(date: date, groupID: nil, state: .notSetUp, snapshot: nil, photoURL: nil, avatarURL: nil)
            }
            snapshot = store.latestSnapshot()
            groupID = snapshot?.groupID ?? groups.first?.id
        }
        guard let snapshot else {
            return GroupPhotoEntry(date: date, groupID: groupID, state: .empty, snapshot: nil, photoURL: nil, avatarURL: nil)
        }
        var named = snapshot
        if named.groupName == nil { named.groupName = groups.first { $0.id == snapshot.groupID }?.name }
        return GroupPhotoEntry(
            date: date,
            groupID: groupID,
            state: snapshot.kind == .collage ? .collage : .photo,
            snapshot: named,
            photoURL: store.photoURL(for: snapshot),
            avatarURL: store.avatarURL(for: snapshot)
        )
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
        AppIntentConfiguration(kind: GroupWidgetKinds.lockScreen, intent: SelectGroupIntent.self, provider: GroupPhotoProvider()) { entry in
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
