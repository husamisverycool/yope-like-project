// Surface: daily.liveactivity — reference: BeReal countdown format + Apple HIG (Live Activities).
// Reference images: references/auto/platform/hig-live-activities-ios-dimensions.png,
// references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png (design/surfaces/daily.liveactivity.md).
// The presentations' content. Pure SwiftUI (no ActivityKit context), so AppTests snapshots them.
import AppModels
import DesignSystem
import SwiftUI

/// The system-drawn countdown to the window's close (`Text(timerInterval:countsDown:)` updates
/// itself; no pushes). The range is clamped so it never inverts after the close (an inverted
/// range traps).
struct InvitationCountdown: View {
    let closesAt: Date
    var now: Date = Date()

    var body: some View {
        Text(timerInterval: CountdownState.timerRange(closesAt: closesAt, now: now), countsDown: true, showsHours: false)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
    }
}

private typealias Typography = Tokens.Layouts.DailyLiveactivityLayoutTypography

/// Lock Screen (and the banner without a Dynamic Island): one row inside the 14-pt margin —
/// the group name leading, the countdown trailing in `color.global.accent`. Background
/// `color.global.backgroundDeep` (set with `activityBackgroundTint`). Stale (the end push was
/// missed): the countdown is hidden; nothing 'late' is shown.
struct InvitationLockScreenSlot: View {
    let attributes: DailyInvitationAttributes
    let state: DailyInvitationAttributes.ContentState
    let isStale: Bool
    var now: Date = Date()

    var body: some View {
        HStack {
            Text(state.groupName)
                .font(WidgetType.platform(Typography.groupName))
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
                .lineLimit(1)
            Spacer(minLength: Tokens.Sizes.dailyLiveactivitySizeLockScreenMargin)
            if !isStale {
                InvitationCountdown(closesAt: state.closesAt, now: now)
                    .dsTextStyle(WidgetType.lockScreenCountdown)
                    .foregroundStyle(Tokens.Colors.globalAccent)
                    .fixedSize()
            }
        }
        .padding(Tokens.Sizes.dailyLiveactivitySizeLockScreenMargin)
    }
}

/// Compact leading (and expanded leading region): the camera glyph, decorative.
struct InvitationCompactLeadingSlot: View {
    var body: some View {
        Image(systemName: Tokens.Icons.globalCamera)
            .foregroundStyle(Tokens.Colors.globalAccent)
            .accessibilityHidden(true)
    }
}

/// Compact trailing (and expanded trailing region): the countdown, Headline, monospaced digits.
struct InvitationCompactTrailingSlot: View {
    let state: DailyInvitationAttributes.ContentState
    var now: Date = Date()

    var body: some View {
        InvitationCountdown(closesAt: state.closesAt, now: now)
            .font(WidgetType.platform(Typography.countdownCompact))
            .foregroundStyle(Tokens.Colors.globalAccent)
            // A timer text takes all the width it is offered; the compact presentation's width
            // (`daily.liveactivity.layout.size`, 393-pt screen) bounds it.
            .frame(maxWidth: WidgetLayoutSize.width(Tokens.Layouts.DailyLiveactivityLayoutSize.w393compact))
    }
}

/// Minimal: "the remaining time instead of a static icon" — Caption 1 emphasized, monospaced digits.
struct InvitationMinimalSlot: View {
    let state: DailyInvitationAttributes.ContentState
    var now: Date = Date()

    var body: some View {
        InvitationCountdown(closesAt: state.closesAt, now: now)
            .font(WidgetType.platform(Typography.countdownMinimal))
            .foregroundStyle(Tokens.Colors.globalAccent)
    }
}

/// Expanded bottom region: the group name.
struct InvitationExpandedSlot: View {
    let state: DailyInvitationAttributes.ContentState

    var body: some View {
        Text(state.groupName)
            .font(WidgetType.platform(Typography.groupName))
            .foregroundStyle(Tokens.Colors.globalTextPrimary)
            .lineLimit(1)
    }
}

/// Reads the "W x H" sizes of the PLATFORM size tokens ("52.33x36.67").
enum WidgetLayoutSize {
    static func width(_ token: String) -> CGFloat? {
        guard let first = token.split(separator: "x").first, let value = Double(first) else { return nil }
        return CGFloat(value)
    }
}
