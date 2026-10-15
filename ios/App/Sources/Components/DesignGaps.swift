// BLOCKED design values used by the shared components and the account screens — the one place to switch when a value
// is unblocked. Each accessor returns nil while its token is BLOCKED (the element it drives is omitted, per
// docs/SCREENS_BRIEF.md rule 1); when `tools/designgen.mjs` moves the token into `Tokens`, replace `nil` with the
// generated constant named in the comment and the element ships. BLOCKED copy lives in `AccountBlockedCopy`.
import DesignSystem
import SwiftUI

enum DesignGaps {
    /// `safety.block.duration.toast` (seconds): how long the lime toast stays. Nil → release builds draw no toast.
    /// Unblocked: `Tokens.Durations.safetyBlockDurationToast`.
    static var toastDwell: TimeInterval? { nil }

    /// `chat.thread.radius.loadingHud`: Loading HUD corner radius. Nil → square corners.
    /// Unblocked: `Tokens.Radii.chatThreadRadiusLoadingHud`.
    static var hudCornerRadius: CGFloat? { nil }

    /// `groups.list.color.headerCircleOverPhoto`: fill of the header circles over the home cover photo.
    /// Nil → the glyph is drawn without a fill. Unblocked: `Tokens.Colors.groupsListColorHeaderCircleOverPhoto`.
    static var headerCircleOverPhoto: Color? { nil }

    /// `auth.phone.layout.inlineError`: how form errors are presented (auth.*, groups.create). False → not drawn
    /// (the message is announced to VoiceOver). Unblocked: implement the token's layout in `InlineError`.
    static var showsInlineErrors: Bool { false }

    /// `auth.phone.layout.countryCode`: the country-code selector of auth.phone. False → the calling code is typed
    /// as text (pre-filled from the device region). Unblocked: build the selector the token describes.
    static var showsCountryCodeSelector: Bool { false }

    /// `safety.report.layout.reasons`: the report reason list. False → no list (free-text details only).
    static var showsReportReasons: Bool { false }

    /// `paywall.layout.iconTileArt`: the paywall icon tile art. False → the tile is omitted.
    static var showsPaywallIconTile: Bool { false }
}

/// A form error under a field. Draws nothing while `auth.phone.layout.inlineError` is BLOCKED.
struct InlineError: View {
    let message: String?

    var body: some View {
        if DesignGaps.showsInlineErrors, let message {
            Text(message)
        }
    }
}
