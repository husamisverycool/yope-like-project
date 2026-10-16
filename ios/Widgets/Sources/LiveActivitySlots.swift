// Surface: daily.liveactivity — visual reference Retro's media colours and text roles (black page, white text, the
// display serif) placed in Apple HIG's Live Activity layouts, carrying BeReal's MM:SS countdown.
// Reference images: references/auto/platform/hig-live-activities-ios-dimensions.png,
// references/auto/retro/lazyweb/retro-lazyweb-20251020-week43-dark.png (H43), references/auto/retro/press/tc-2025-12-rewind-device-a.png
// (RWA), references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png (design/surfaces/daily.liveactivity.md;
// RC-17). The presentations' content. Pure SwiftUI (no ActivityKit context), so AppTests snapshots them.
import AppModels
import DesignSystem
import SwiftUI

/// The system-drawn countdown to the window's close (`Text(timerInterval:countsDown:)` updates itself; no pushes —
/// `daily.liveactivity.layout.lifecycle`). The range is clamped so it never inverts after the close (an inverted range
/// traps).
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

/// Lock Screen (and the banner without a Dynamic Island) on `color.global.backgroundDeep` (`activityBackgroundTint`):
/// one row inside `daily.liveactivity.size.lockScreenMargin` (14), at least 84 pt tall — the group name leading in the
/// display serif (`displaySmall`, weight raised to the HIG floor `daily.liveactivity.fontWeight.min`), one line,
/// truncating; the countdown trailing (`sheetTitle`, monospaced digits); both `color.global.textOnMedia`. Stale (the end
/// push was missed): the countdown is hidden; nothing "late" is shown.
struct InvitationLockScreenSlot: View {
    let attributes: DailyInvitationAttributes
    let state: DailyInvitationAttributes.ContentState
    let isStale: Bool
    var now: Date = Date()

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(state.groupName)
                .dsTextStyle(WidgetType.liveActivityGroupName)
                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                .lineLimit(1)
            Spacer(minLength: Tokens.Sizes.dailyLiveactivitySizeLockScreenMargin)
            if !isStale {
                InvitationCountdown(closesAt: state.closesAt, now: now)
                    .dsTextStyle(WidgetType.sheetTitle)
                    .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                    .fixedSize()
            }
        }
        .padding(Tokens.Sizes.dailyLiveactivitySizeLockScreenMargin)
        .frame(maxWidth: .infinity, minHeight: Self.minimumHeight)
        .accessibilityElement(children: .combine)
    }

    /// The smallest Lock Screen height of `daily.liveactivity.layout.size` ("371x84-160": 84).
    static var minimumHeight: CGFloat? {
        WidgetLayoutSize.minimumHeight(Tokens.Layouts.DailyLiveactivityLayoutSize.w393lockScreen)
    }
}

/// Compact leading (and expanded leading region): `icon.global.camera` at `size.global.icon` in
/// `color.global.textOnMedia`, decorative.
struct InvitationCompactLeadingSlot: View {
    var body: some View {
        Image(systemName: Tokens.Icons.globalCamera)
            .resizable()
            .scaledToFit()
            .frame(width: Tokens.Sizes.globalIcon, height: Tokens.Sizes.globalIcon)
            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
            .accessibilityHidden(true)
    }
}

/// Compact trailing (and expanded trailing region): the countdown in `sheetTitle`, monospaced digits.
struct InvitationCompactTrailingSlot: View {
    let state: DailyInvitationAttributes.ContentState
    var now: Date = Date()

    var body: some View {
        InvitationCountdown(closesAt: state.closesAt, now: now)
            .dsTextStyle(WidgetType.sheetTitle)
            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
            // A timer text takes all the width it is offered; the compact presentation's width
            // (`daily.liveactivity.layout.size`, 393-pt screen) bounds it.
            .frame(maxWidth: WidgetLayoutSize.width(Tokens.Layouts.DailyLiveactivityLayoutSize.w393compact))
    }
}

/// Minimal: the remaining time — Caption 1 semibold, monospaced digits (the system's; Retro has no role this small).
struct InvitationMinimalSlot: View {
    let state: DailyInvitationAttributes.ContentState
    var now: Date = Date()

    var body: some View {
        InvitationCountdown(closesAt: state.closesAt, now: now)
            .font(WidgetType.platform(Typography.countdownMinimal))
            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
    }
}

/// Expanded bottom region: the group name in `sheetTitle`, `color.global.textOnMedia`.
struct InvitationExpandedSlot: View {
    let state: DailyInvitationAttributes.ContentState

    var body: some View {
        Text(state.groupName)
            .dsTextStyle(WidgetType.sheetTitle)
            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
            .lineLimit(1)
    }
}

extension WidgetLayoutSize {
    /// The smallest height of a "W x Hmin-Hmax" size token ("371x84-160" → 84).
    static func minimumHeight(_ token: String) -> CGFloat? {
        let parts = token.split(separator: "x")
        guard parts.count == 2, let first = parts[1].split(separator: "-").first, let value = Double(first) else { return nil }
        return CGFloat(value)
    }
}
