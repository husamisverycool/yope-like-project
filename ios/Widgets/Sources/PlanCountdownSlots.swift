// Surface: widget.countdown — the next plan, in days. Visual reference: Retro's Glance widget anatomy exactly as
// widget.home.small (references/auto/retro/apk/widget_preview_journals.webp: full-bleed photo, bottom scrim, white text
// at the bottom-trailing corner; the white-85 % state column); mechanics Apple Invites' widget
// (references/auto/apple-invites/store/apple-invites-store-08.png: photo + event title + "In 9 Days") and the day-only
// countdowns of Widgetsmith (references/auto/countdown-widgets/store/widgetsmith-store-05.png); sizes Apple HIG
// (references/auto/platform/hig-widgets-ios-dimensions.png) (design/surfaces/widget.countdown.md; MERGE PL-9 … PL-11).
// The entry, how it is resolved from the App Group store and the content views: no App Intents types, so AppTests
// snapshots them (linked into ios/AppTests/Plans/Linked).
import AppModels
import DesignSystem
import Foundation
import SwiftUI
import UIKit
import WidgetKit

/// What the countdown widget shows.
struct PlanCountdownContent {
    enum State: Equatable {
        /// Just added, nothing written yet (also the gallery preview): `color.global.backgroundDeep`.
        case loading
        /// The featured plan: photo + text stack.
        case plan
        /// No upcoming plan.
        case noPlans
        /// The configured group was left or deleted.
        case notSetUp
        /// Nobody is signed in on this device.
        case signedOut
    }

    var state: State
    var title: String?
    var groupName: String?
    /// Calendar days until the plan's day (0 = today).
    var days: Int?
    var photo: UIImage?

    init(state: State, title: String? = nil, groupName: String? = nil, days: Int? = nil, photo: UIImage? = nil) {
        self.state = state
        self.title = title
        self.groupName = groupName
        self.days = days
        self.photo = photo
    }

    /// The countdown line in the platform formatter's words ("In 3 days", "Tomorrow").
    var countdown: String? {
        days.flatMap { PlanCountdownText.text(days: $0) }
    }

    /// The state column's line. "No plans" (`widget.countdown.empty.noPlans`) is BLOCKED: DEBUG builds only; release
    /// builds show the glyph alone.
    var stateLine: String? {
        switch state {
        case .notSetUp: return Copy.widgetHomeSmallEmptySetUp
        case .signedOut: return Copy.widgetHomeSmallEmptySignedOut
        case .noPlans:
            #if DEBUG
            return BlockedCopy.widgetCountdownEmptyNoPlans
            #else
            return nil
            #endif
        case .loading, .plan: return nil
        }
    }

    /// `widget.countdown.a11y.plan` ("{title} with {group}, {countdown}", the day words inside the sentence); a state:
    /// its visible line.
    var accessibilityLabel: String {
        switch state {
        case .plan:
            let spoken = days.flatMap { PlanCountdownText.text(days: $0, context: .middleOfSentence) }
            return Copy.widgetCountdownA11yPlan(title: title ?? "", group: groupName ?? "", countdown: spoken ?? "")
        case .noPlans, .notSetUp, .signedOut: return stateLine ?? ""
        case .loading: return ""
        }
    }
}

/// The countdown line (`widget.countdown` "The countdown line"): the platform's relative formatter at day granularity,
/// never typed by us and never hours, minutes or seconds — ≥ 2 days `unitsStyle .full` ("In 3 days"), 1 day `.named`
/// ("Tomorrow"), both `formattingContext .beginningOfSentence` (`.middleOfSentence` inside the accessibility label). The
/// same day's word (`.named`, 0 days) is BLOCKED until a snapshot test pins it (plans.md §12 item 2): DEBUG builds show
/// it, release builds leave the line out.
enum PlanCountdownText {
    static func text(
        days: Int, locale: Locale = .current, context: Formatter.Context = .beginningOfSentence
    ) -> String? {
        guard days >= 0 else { return nil }
        #if !DEBUG
        if days == 0 { return nil }
        #endif
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = days <= 1 ? .named : .numeric
        formatter.formattingContext = context
        return formatter.localizedString(from: DateComponents(day: days))
    }
}

struct PlanCountdownEntry: TimelineEntry {
    let date: Date
    let state: PlanCountdownContent.State
    var title: String?
    var groupName: String?
    var days: Int?
    /// The plan's cover, else the group's newest photo, in the App Group store.
    var photoURL: URL?
    var planID: String?
    var groupID: String?

    static func loading(at date: Date) -> PlanCountdownEntry {
        PlanCountdownEntry(date: date, state: .loading)
    }

    /// The view content; the photo is read from the App Group file (no network).
    var content: PlanCountdownContent {
        PlanCountdownContent(
            state: state, title: title, groupName: groupName, days: days,
            photo: photoURL.flatMap { UIImage(contentsOfFile: $0.path) }
        )
    }

    /// Tapping opens the plan's page (`app://plan?plan=<id>&group=<id>`); the states open the app.
    var tapURL: URL? {
        planID.flatMap { DeepLinkParser(universalLinkHosts: []).url(for: .plan(planID: $0, groupID: groupID)) }
    }
}

enum PlanCountdownResolver {
    /// The configuration's "All Groups" choice (the default, Apple's "your next event").
    static let allGroupsID = "all-groups" // provenance-ok: configuration identifier, not user-facing
    /// Timeline length: one entry per local midnight up to the day after the plan's, at most this many (the timeline
    /// is rebuilt at its end, `.atEnd`).
    static let maxEntries = 32 // provenance-ok: timeline length, not a design value

    /// - signed out: the app wrote no group list on this device (sign-out removes the store);
    /// - not set up: the configured group is not in the app's group list (left or deleted);
    /// - no plans: nothing upcoming (canceled plans are never written: the next one shows);
    /// - plan: the soonest plan whose day is today or later — its cover, else the group's newest photo, else none.
    static func entry(configuredGroupID: String?, store: WidgetStore, at date: Date, calendar: Calendar) -> PlanCountdownEntry {
        let groupID = configuredGroupID == allGroupsID ? nil : configuredGroupID
        guard store.hasGroupList else { return state(.signedOut, at: date) }
        if let groupID, !store.groups().contains(where: { $0.id == groupID }) { return state(.notSetUp, at: date) }
        guard let plan = PlanCountdown.featured(store.plans(), groupID: groupID, at: date, calendar: calendar) else {
            return state(.noPlans, at: date)
        }
        return PlanCountdownEntry(
            date: date,
            state: .plan,
            title: plan.title,
            groupName: plan.groupName,
            days: PlanCountdown.days(until: plan.localDate, from: date, calendar: calendar),
            photoURL: store.coverURL(for: plan) ?? store.latestSnapshot(groupID: plan.groupID).flatMap(store.photoURL(for:)),
            planID: plan.planID,
            groupID: plan.groupID
        )
    }

    /// Entries for now and each following local midnight through the day after the featured plan's day (each midnight
    /// re-resolves, so the day after falls through to the next plan). The count changes at midnight only.
    static func entries(configuredGroupID: String?, store: WidgetStore, now: Date, calendar: Calendar) -> [PlanCountdownEntry] {
        let first = entry(configuredGroupID: configuredGroupID, store: store, at: now, calendar: calendar)
        let lastDay = store.plans().first { $0.planID == first.planID }?.localDate
        return PlanCountdown.entryDates(through: lastDay, from: now, calendar: calendar, maxEntries: maxEntries).map { date in
            date == now ? first : entry(configuredGroupID: configuredGroupID, store: store, at: date, calendar: calendar)
        }
    }

    private static func state(_ state: PlanCountdownContent.State, at date: Date) -> PlanCountdownEntry {
        PlanCountdownEntry(date: date, state: state)
    }
}

// MARK: - Views (systemSmall and systemMedium: one layout, RC-11)

/// The removable container background: the photo aspect-filling the widget under `layout.global.photoScrim`
/// (`widget.home.small.layout.photo`); no photo or a state: `color.global.backgroundDeep`.
struct PlanCountdownBackground: View {
    let content: PlanCountdownContent

    var body: some View {
        ZStack {
            Tokens.Colors.globalBackgroundDeep
            if content.state == .plan, let photo = content.photo {
                WidgetPhotoImage(image: photo)
                WidgetPhotoScrim()
            }
        }
    }
}

/// The content over the background: the text stack or the state column; one element with the button trait.
struct PlanCountdownOverlay: View {
    let content: PlanCountdownContent
    /// systemMedium: the group line above the title.
    var showsGroup = false

    var body: some View {
        ZStack {
            switch content.state {
            case .plan:
                PlanCountdownTextStack(group: showsGroup ? content.groupName : nil, title: content.title ?? "", countdown: content.countdown)
            case .noPlans, .notSetUp, .signedOut:
                PlanCountdownStateColumn(line: content.stateLine)
            case .loading:
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(content.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }
}

/// The text stack (widget.countdown Structure 3): bottom-trailing, trailing-aligned, `color.global.textOnMedia`, the
/// last baseline `widget.home.small.layout.overlay.lastBaselineFromBottom` above the bottom edge and
/// `.trailingInset` from the trailing edge; each line one line, truncated at the leading `size.global.screenMargin`:
/// (medium) the group (`widget.home.small.fontSize.overlay`), the title (text role `listTitle`), the countdown (text
/// role `displaySmall` in `font.global.display`). Lines stack at their own line heights (no pitch is measured for
/// this stack).
struct PlanCountdownTextStack: View {
    var group: String?
    let title: String
    var countdown: String?

    @ScaledMetric private var lastBaseline: CGFloat

    private typealias Overlay = Tokens.Layouts.WidgetHomeSmallLayoutOverlay

    init(group: String?, title: String, countdown: String?) {
        self.group = group
        self.title = title
        self.countdown = countdown
        _lastBaseline = ScaledMetric(wrappedValue: Overlay.lastBaselineFromBottom, relativeTo: PlanCountdownType.countdown.relativeTo)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
            VStack(alignment: .trailing, spacing: 0) {
                if let group {
                    Text(group)
                        .dsTextStyle(WidgetType.overlay)
                }
                Text(title)
                    .dsTextStyle(WidgetType.listTitle)
                if let countdown {
                    Text(countdown)
                        .dsTextStyle(PlanCountdownType.countdown)
                }
            }
            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
            .multilineTextAlignment(.trailing)
            .lineLimit(1)
            .truncationMode(.tail)
            .contentTransition(.identity)
            .alignmentGuide(.bottom) { dimensions in dimensions[.lastTextBaseline] + lastBaseline }
        }
        .padding(.leading, Tokens.Sizes.globalScreenMargin)
        .padding(.trailing, Overlay.trailingInset)
    }
}

/// widget.home.small's state column with `icon.global.calendar`: the glyph at `size.global.icon` in the 48-pt box
/// (`size.global.minTouchTarget.android`, as `WidgetStateColumn`), then the line in
/// `widget.home.small.fontSize.overlay`, both `widget.home.small.color.stateTint`, centred, up to 2 lines.
struct PlanCountdownStateColumn: View {
    var line: String?

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: Tokens.Icons.globalCalendar)
                .resizable()
                .scaledToFit()
                .frame(width: Tokens.Sizes.globalIcon, height: Tokens.Sizes.globalIcon)
                .frame(width: Tokens.Sizes.globalMinTouchTargetAndroid, height: Tokens.Sizes.globalMinTouchTargetAndroid)
            if let line {
                Text(line)
                    .dsTextStyle(WidgetType.overlay)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .foregroundStyle(Tokens.Colors.widgetHomeSmallColorStateTint)
        .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
    }
}

/// The countdown's text role: `displaySmall` (24, Dynamic Type Title 2) in Retro's display face `font.global.display`
/// (widget.countdown Structure 3, MERGE PL-9).
enum PlanCountdownType {
    static var countdown: DSTextStyle {
        DSTextStyle(
            family: Tokens.Fonts.globalDisplay,
            size: Tokens.FontSizes.globalDisplaySmall,
            weight: Tokens.FontWeights.fontWeightGlobalDisplaySmall,
            relativeTo: WidgetTextStyleName.resolve(Tokens.Layouts.GlobalTextStyleMap.displaySmall)
        )
    }
}
