// Surfaces: widget.friend (Friend Updates: one person's newest photo) and widget.memories (Your Memories: your own photo
// from this day in an earlier year), every home-screen size, in the configured style (widget.styles) —
// design/surfaces/widget.friend.md, widget.memories.md. Visual reference Retro's Friend Updates and Your Memories widgets
// (references/auto/retro/apk/widget_preview_friends.webp, widget_preview_memories.webp); mechanics Locket's one-friend
// widget (references/auto/locket/frames/locket-tt-7532209311150329102-14.500s-gallery-best-friend-widget.jpg) and
// Retro's "time hop back to your own memories" (App Store id6443709020). Both read only the App Group `WidgetStore`.
import AppIntents
import AppModels
import DesignSystem
import SwiftUI
import WidgetKit

/// The friend widget's timeline. Building it records that a widget follows this friend (`WidgetStore.watch`), so the app
/// and the Notification Service Extension keep that friend's newest photo; the same random 15–60-minute safety refresh as
/// the group widget picks up a photo whose reload was dropped.
struct FriendPhotoProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StyledPhotoEntry {
        .loading(at: Date())
    }

    func snapshot(for configuration: SelectFriendIntent, in context: Context) async -> StyledPhotoEntry {
        let entry = entry(for: configuration, at: Date(), recordsWatch: !context.isPreview)
        if context.isPreview && !entry.showsItem { return .loading(at: Date()) }
        return entry
    }

    func timeline(for configuration: SelectFriendIntent, in context: Context) async -> Timeline<StyledPhotoEntry> {
        let now = Date()
        let refresh = now.addingTimeInterval(TimeInterval.random(in: GroupPhotoProvider.safetyRefreshSeconds))
        return Timeline(entries: [entry(for: configuration, at: now, recordsWatch: true)], policy: .after(refresh))
    }

    private func entry(for configuration: SelectFriendIntent, at date: Date, recordsWatch: Bool) -> StyledPhotoEntry {
        let store = WidgetStore.forBundle(.main)
        let personID = configuration.friend?.id
        if recordsWatch, let personID { try? store.watch(personID: personID, at: date) }
        return StyledEntryResolver.friend(personID: personID, style: configuration.style?.style, store: store, at: date)
    }
}

/// Friend Updates: Retro's friend widget (name over place, full-bleed photo) following one person — Locket's one-friend
/// widget. Gallery: `widget.friend.gallery.name` / `.gallery.description`.
struct FriendPhotoWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.friendPhoto, intent: SelectFriendIntent.self, provider: FriendPhotoProvider()) { entry in
            StyledPhotoWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(Copy.widgetFriendGalleryName))
        .description(Text(Copy.widgetFriendGalleryDescription))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

/// The memories widget's timeline: an entry for each day the app looked up, starting at local midnight (the memory changes
/// with the date), then `.atEnd` — a later day stays in its loading state until the app writes more days and reloads.
/// Building it records that a memories widget is placed (`WidgetStore.watchMemories`).
struct MemoriesProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StyledPhotoEntry {
        .loading(at: Date())
    }

    func snapshot(for configuration: SelectStyleIntent, in context: Context) async -> StyledPhotoEntry {
        let store = WidgetStore.forBundle(.main)
        if !context.isPreview { try? store.watchMemories(at: Date()) }
        let entry = StyledEntryResolver.memories(style: configuration.style?.style, store: store, at: Date(), calendar: .current)
        if context.isPreview && !entry.showsItem { return .loading(at: Date()) }
        return entry
    }

    func timeline(for configuration: SelectStyleIntent, in context: Context) async -> Timeline<StyledPhotoEntry> {
        let store = WidgetStore.forBundle(.main)
        let now = Date()
        try? store.watchMemories(at: now)
        let entries = StyledEntryResolver.memoryEntries(style: configuration.style?.style, store: store, now: now, calendar: .current)
        return Timeline(entries: entries, policy: .atEnd)
    }
}

/// Your Memories: Retro's memories widget, filled with the person's own On This Day photo. Gallery:
/// `widget.memories.gallery.name` / `.gallery.description`.
struct MemoriesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.memories, intent: SelectStyleIntent.self, provider: MemoriesProvider()) { entry in
            StyledPhotoWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(Copy.widgetMemoriesGalleryName))
        .description(Text(Copy.widgetMemoriesGalleryDescription))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}
