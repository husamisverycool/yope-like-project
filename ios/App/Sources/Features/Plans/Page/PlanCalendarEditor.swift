// Surface: plans.page — "Add to Calendar" (Apple Invites: "Add an event to the Calendar app: Select an event, then select
// the Add to Calendar button", support.apple.com/guide/apple-invites/view-your-events-dev18a008ffb/ios). The system's
// new-event editor (EventKitUI `EKEventEditViewController`, PLATFORM) prefilled with the plan's title, time (or day) and
// place. No calendar access is asked and no calendar usage string is needed: "EventKit UI presents chooser and editor UI
// outside of your app's process on iOS 17 and later. Your app can use EventKit UI without requesting write-only or full
// calendar access." (developer.apple.com/documentation/eventkit/accessing-the-event-store).
import AppData
import EventKit
import EventKitUI
import SwiftUI
import UIKit

/// What the new event is filled with (kept apart from EventKit so it can be checked without an event store).
struct PlanCalendarFields: Equatable, Identifiable {
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    /// One editor at a time (`sheet(item:)`).
    let id = UUID()

    /// A timed plan without an end is offered as an hour long, as a new event starts out in iOS Calendar; the person
    /// changes it in the editor.
    static let defaultDuration: TimeInterval = 60 * 60 // provenance-ok: one hour in seconds (the calendars' default event length)

    init(plan: Plan, calendar: Calendar = .current) {
        title = plan.title
        isAllDay = plan.allDay
        location = plan.place.flatMap { $0.isEmpty ? nil : $0 }
        if plan.allDay {
            // The plan's day in the person's calendar; EventKit all-day events end on their last day.
            var components = DateComponents()
            components.year = plan.localDate.year
            components.month = plan.localDate.month
            components.day = plan.localDate.day
            let day = calendar.date(from: components).map { calendar.startOfDay(for: $0) } ?? plan.startsAt
            start = day
            end = day
        } else {
            start = plan.startsAt
            end = plan.endsAt.flatMap { $0 > plan.startsAt ? $0 : nil } ?? plan.startsAt.addingTimeInterval(Self.defaultDuration)
        }
    }
}

/// `EKEventEditViewController` in a sheet; `onFinish` runs when the person saves or cancels.
struct PlanCalendarEditor: UIViewControllerRepresentable {
    let fields: PlanCalendarFields
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = fields.title
        event.isAllDay = fields.isAllDay
        event.startDate = fields.start
        event.endDate = fields.end
        event.location = fields.location
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, @preconcurrency EKEventEditViewDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onFinish()
        }
    }
}
