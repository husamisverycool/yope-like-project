// Surfaces: widget.home.small / .medium / .large / .xl, widget.lock.rect / .circular / .inline,
// widget.arrival — reference app: Locket. Reference images: design/surfaces/widget.*.md.
// Plumbing only: the photo fills the widget; every other element is a slot in WidgetSlots.swift
// that the screens pass styles with Tokens.* / Copy.*.
import AppIntents
import AppModels
import SwiftUI
import UIKit
import WidgetKit

struct GroupPhotoEntry: TimelineEntry {
    let date: Date
    /// The configured group, or the group of the newest photo when none is configured.
    let groupID: String?
    let snapshot: WidgetSnapshot?
    let photoURL: URL?

    static func empty(at date: Date) -> GroupPhotoEntry {
        GroupPhotoEntry(date: date, groupID: nil, snapshot: nil, photoURL: nil)
    }

    /// Tapping opens the camera for this group (`camera.fromwidget`).
    var tapURL: URL? {
        DeepLinkParser(universalLinkHosts: []).url(for: .camera(groupID: groupID))
    }
}

/// Reads the newest photo or same-moment collage for the configured group from the App Group.
/// Timelines never refresh on a schedule: new photos arrive by push, and the Notification
/// Service Extension (or the app) reloads this widget kind after writing the rendition.
struct GroupPhotoProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> GroupPhotoEntry {
        .empty(at: Date())
    }

    func snapshot(for configuration: SelectGroupIntent, in context: Context) async -> GroupPhotoEntry {
        entry(for: configuration, at: Date())
    }

    func timeline(for configuration: SelectGroupIntent, in context: Context) async -> Timeline<GroupPhotoEntry> {
        Timeline(entries: [entry(for: configuration, at: Date())], policy: .never)
    }

    private func entry(for configuration: SelectGroupIntent, at date: Date) -> GroupPhotoEntry {
        let store = WidgetStore.forBundle(.main)
        let configuredGroup = configuration.group?.id
        let snapshot = configuredGroup.map { store.latestSnapshot(groupID: $0) } ?? store.latestSnapshot()
        return GroupPhotoEntry(
            date: date,
            groupID: configuredGroup ?? snapshot?.groupID,
            snapshot: snapshot,
            photoURL: snapshot.flatMap { store.photoURL(for: $0) }
        )
    }
}

struct GroupPhotoWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.groupPhoto, intent: SelectGroupIntent.self, provider: GroupPhotoProvider()) { entry in
            GroupPhotoWidgetView(entry: entry)
        }
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge,
            .accessoryRectangular, .accessoryCircular, .accessoryInline,
        ])
        // The photo runs edge to edge.
        .contentMarginsDisabled()
    }
}

struct GroupPhotoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GroupPhotoEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if isHomeScreen {
                    WidgetPhoto(url: entry.photoURL, snapshot: entry.snapshot)
                }
            }
            .widgetURL(entry.tapURL)
    }

    private var isHomeScreen: Bool {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: return false
        default: return true
        }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            WidgetInlineSlot(snapshot: entry.snapshot)
        case .accessoryCircular, .accessoryRectangular:
            // Lock screen: the system removes container backgrounds, so the photo is the content.
            WidgetPhoto(url: entry.photoURL, snapshot: entry.snapshot)
        default:
            WidgetOverlay(snapshot: entry.snapshot, family: family)
        }
    }
}

/// The delivered rendition, filling its container; the empty state when none is on disk.
struct WidgetPhoto: View {
    let url: URL?
    let snapshot: WidgetSnapshot?

    var body: some View {
        if let url, let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            WidgetEmptyState(snapshot: snapshot)
        }
    }
}
