// Surface: daily.liveactivity — reference: BeReal + Apple HIG (Live Activities).
// Reference images: design/surfaces/daily.liveactivity.md. Plumbing: regions and the countdown;
// styling goes into the slots in WidgetSlots.swift.
import ActivityKit
import AppModels
import SwiftUI
import WidgetKit

struct DailyInvitationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DailyInvitationAttributes.self) { context in
            InvitationLockScreenSlot(attributes: context.attributes, state: context.state, isStale: context.isStale)
                .widgetURL(InvitationLink.url(for: context.attributes))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    InvitationExpandedSlot(state: context.state)
                }
            } compactLeading: {
                InvitationCompactLeadingSlot(state: context.state)
            } compactTrailing: {
                InvitationCountdown(closesAt: context.state.closesAt)
            } minimal: {
                InvitationCountdown(closesAt: context.state.closesAt)
            }
            .widgetURL(InvitationLink.url(for: context.attributes))
        }
    }
}

/// The system-drawn countdown to the window's close. The range is clamped so it never inverts
/// after the close (an inverted range traps).
struct InvitationCountdown: View {
    let closesAt: Date

    var body: some View {
        Text(timerInterval: CountdownState.timerRange(closesAt: closesAt, now: Date()), countsDown: true)
    }
}

enum InvitationLink {
    /// Tapping opens the daily capture for the group (`daily.capture`).
    static func url(for attributes: DailyInvitationAttributes) -> URL? {
        DeepLinkParser(universalLinkHosts: []).url(for: .dailyInvitation(groupID: attributes.groupID, invitationID: attributes.invitationID))
    }
}
