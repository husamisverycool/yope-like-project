// Surface: daily.liveactivity — reference: BeReal + Apple HIG (Live Activities).
// Reference images: references/auto/platform/hig-live-activities-ios-dimensions.png,
// references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png (design/surfaces/daily.liveactivity.md).
// Presentations: Lock Screen / banner, Dynamic Island compact, minimal and expanded. Content views
// are in LiveActivitySlots.swift. Every tap opens the daily capture for the group.
import ActivityKit
import AppModels
import DesignSystem
import SwiftUI
import WidgetKit

struct DailyInvitationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DailyInvitationAttributes.self) { context in
            InvitationLockScreenSlot(attributes: context.attributes, state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Tokens.Colors.globalBackgroundDeep)
                .activitySystemActionForegroundColor(Tokens.Colors.globalTextPrimary)
                .widgetURL(InvitationLink.url(for: context.attributes))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    InvitationCompactLeadingSlot()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !context.isStale {
                        InvitationCompactTrailingSlot(state: context.state)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    InvitationExpandedSlot(state: context.state)
                }
            } compactLeading: {
                InvitationCompactLeadingSlot()
            } compactTrailing: {
                if !context.isStale {
                    InvitationCompactTrailingSlot(state: context.state)
                }
            } minimal: {
                if context.isStale {
                    InvitationCompactLeadingSlot()
                } else {
                    InvitationMinimalSlot(state: context.state)
                }
            }
            .keylineTint(Tokens.Colors.globalAccent)
            .widgetURL(InvitationLink.url(for: context.attributes))
        }
    }
}

enum InvitationLink {
    /// Tapping opens the daily capture for the group (`daily.capture`).
    static func url(for attributes: DailyInvitationAttributes) -> URL? {
        DeepLinkParser(universalLinkHosts: []).url(for: .dailyInvitation(groupID: attributes.groupID, invitationID: attributes.invitationID))
    }
}
