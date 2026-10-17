// Surfaces: widget.home.small / .medium / .large / .xl (Group Updates, with All Groups), widget.friend (Friend Updates),
// widget.memories (Your Memories), widget.styles — design/surfaces/<id>.md. Visual reference Retro's Glance widgets
// (references/auto/retro/apk/widget_preview_journals.webp, …_friends.webp, …_memories.webp: one anatomy, name over place),
// mechanics Locket (references/auto/locket/frames/locket-tt-7532209311150329102-14.500s-gallery-best-friend-widget.jpg:
// one friend's photos) and Retro's "time hop back to your own memories" (App Store id6443709020).
// The home-screen photo widgets' timeline entry and how it is resolved from the App Group store: no network and no App
// Intents types, so AppTests exercises it directly (ios/AppTests/Capture/Linked).
import AppModels
import DesignSystem
import Foundation
import UIKit
import WidgetKit

/// One entry of a home-screen photo widget: what it draws and where a tap goes. Like the other entries it keeps file
/// URLs, not images (entries cross into WidgetKit); `presentation` reads the App Group files when the view is built.
struct StyledPhotoEntry: TimelineEntry {
    let date: Date
    var state: GroupWidgetContent.State
    var groupName: String?
    var senderName: String?
    var postedAt: Date?
    var photoURL: URL?
    var avatarURL: URL?
    /// The style drawn (a locked premium style is `.photo` here).
    var style: WidgetPhotoStyle = .photo
    /// The kind's own state line (`widget.friend.empty.*`, `widget.memories.empty.none`).
    var stateLine: String?
    /// The item is the person's memory: its label is `widget.memories.a11y.photo`.
    var isMemory = false
    /// The widget's usual destination (camera, the day's collage, a memory), before any premium prompt.
    var destination: DeepLink?
    /// A premium style was chosen without premium: the tap asks for the paywall first (`app://premium?perk=widgets…`).
    var locked = false

    static let premiumPerk = "widgets"

    var showsItem: Bool { state == .photo || state == .collage }

    var tapURL: URL? {
        let parser = DeepLinkParser(universalLinkHosts: [])
        if locked { return parser.url(for: .premium(perk: Self.premiumPerk, then: destination)) }
        return destination.flatMap { parser.url(for: $0) }
    }

    var presentation: WidgetPresentation {
        let content = GroupWidgetContent(
            state: state, groupName: groupName, senderName: senderName, postedAt: postedAt,
            photo: photoURL.flatMap { UIImage(contentsOfFile: $0.path) },
            avatar: avatarURL.flatMap { UIImage(contentsOfFile: $0.path) }
        )
        var presentation = WidgetPresentation(content: content, style: style, stateLine: stateLine)
        if isMemory {
            presentation.accessibilityLabel = Copy.widgetMemoriesA11yPhoto(date: presentation.dateText, group: groupName ?? "")
        }
        return presentation
    }

    static func loading(at date: Date) -> StyledPhotoEntry {
        StyledPhotoEntry(date: date, state: .loading)
    }
}

enum StyledEntryResolver {
    /// The style a widget draws, and whether its chosen style is locked (premium chosen, no premium: Photo is drawn).
    static func resolveStyle(_ chosen: WidgetPhotoStyle?, store: WidgetStore) -> (drawn: WidgetPhotoStyle, locked: Bool) {
        let chosen = chosen ?? .photo
        let premium = store.isPremium
        return (chosen.drawn(isPremium: premium), chosen.isLocked(isPremium: premium))
    }

    // MARK: Group Updates (one group, or All Groups)

    /// The group widget at home-screen size. `allGroups`: the newest photo or collage across every group
    /// (`widget.home.small.layout.allGroups`); the tap follows that item's group.
    static func group(configuredGroupID: String?, allGroups: Bool, style chosen: WidgetPhotoStyle?, store: WidgetStore, at date: Date) -> StyledPhotoEntry {
        let base = GroupWidgetEntryResolver.entry(configuredGroupID: allGroups ? nil : configuredGroupID, store: store, at: date)
        let (style, locked) = resolveStyle(chosen, store: store)
        return StyledPhotoEntry(
            date: date, state: base.state, groupName: base.snapshot?.groupName, senderName: base.snapshot?.senderDisplayName,
            postedAt: base.snapshot?.postedAt, photoURL: base.photoURL, avatarURL: base.avatarURL, style: style,
            destination: base.tapURL.flatMap { DeepLinkParser(universalLinkHosts: []).parse($0) }, locked: locked
        )
    }

    // MARK: Friend Updates

    /// One friend's newest photo (`widget.friend.layout.content`): signed out, not set up (no friend, or they no longer
    /// share a group — the people list lacks them), loading (the app has not looked them up yet), empty ("No photos
    /// yet"), or the photo with the poster over the group. The tap opens the camera for the photo's group.
    static func friend(personID: String?, style chosen: WidgetPhotoStyle?, store: WidgetStore, at date: Date) -> StyledPhotoEntry {
        let (style, locked) = resolveStyle(chosen, store: store)
        func state(_ state: GroupWidgetContent.State, line: String? = nil) -> StyledPhotoEntry {
            StyledPhotoEntry(date: date, state: state, style: style, stateLine: line, destination: .camera(groupID: nil), locked: locked)
        }
        guard store.hasGroupList else { return state(.signedOut) }
        guard let personID, store.people().contains(where: { $0.id == personID }) else {
            return state(.notSetUp, line: Copy.widgetFriendEmptySetUp)
        }
        guard let snapshot = store.personSnapshot(personID: personID) else {
            return store.isPersonLookedUp(personID: personID) ? state(.empty, line: Copy.widgetFriendEmptyNoPhotos) : state(.loading)
        }
        return StyledPhotoEntry(
            date: date, state: .photo, groupName: snapshot.groupName, senderName: snapshot.senderDisplayName, postedAt: snapshot.postedAt,
            photoURL: store.personPhotoURL(personID: personID, snapshot: snapshot),
            avatarURL: store.personAvatarURL(personID: personID, snapshot: snapshot), style: style,
            destination: .camera(groupID: snapshot.groupID), locked: locked
        )
    }

    // MARK: Your Memories

    /// The person's memory for `date`'s day (`widget.memories.layout.content`): signed out; loading for a day the app has
    /// not looked up; the empty state ("No photos found for this day") for a looked-up day without one — never another
    /// photo; or the memory, whose tap opens it in the viewer.
    static func memories(style chosen: WidgetPhotoStyle?, store: WidgetStore, at date: Date, calendar: Calendar) -> StyledPhotoEntry {
        let (style, locked) = resolveStyle(chosen, store: store)
        guard store.hasGroupList else { return StyledPhotoEntry(date: date, state: .signedOut, style: style, locked: locked) }
        let day = WidgetStore.dayString(date, calendar: calendar)
        guard let days = store.memoryDays(), days.contains(day) else { return .loading(at: date) }
        guard let memory = store.memory(day: day) else {
            return StyledPhotoEntry(date: date, state: .empty, style: style, stateLine: Copy.widgetMemoriesEmptyNone, locked: locked)
        }
        return StyledPhotoEntry(
            date: date, state: .photo, groupName: memory.groupName, senderName: memory.senderDisplayName, postedAt: memory.postedAt,
            photoURL: store.memoryPhotoURL(memory), style: style, isMemory: true,
            destination: memory.sourceID.map { DeepLink.post(groupID: memory.groupID, postID: $0) }, locked: locked
        )
    }

    /// The memories widget's timeline: one entry per day from `now` to the last looked-up day, each starting at local
    /// midnight (the photo changes with the date, as the countdown's day count does), then the loading state until the app
    /// looks further ahead.
    static func memoryEntries(style chosen: WidgetPhotoStyle?, store: WidgetStore, now: Date, calendar: Calendar) -> [StyledPhotoEntry] {
        var entries = [memories(style: chosen, store: store, at: now, calendar: calendar)]
        guard let last = store.memoryDays()?.upperBound else { return entries }
        var midnight = calendar.startOfDay(for: now)
        for _ in 0..<WidgetStore.memoryLookAheadLimit {
            guard let next = calendar.date(byAdding: .day, value: 1, to: midnight) else { break }
            midnight = next
            let entry = memories(style: chosen, store: store, at: midnight, calendar: calendar)
            entries.append(entry)
            if WidgetStore.dayString(midnight, calendar: calendar) > last { break }
        }
        return entries
    }
}

extension WidgetStore {
    /// At most this many days are laid out ahead in one memories timeline (the app stores a week).
    static let memoryLookAheadLimit = 14
}
