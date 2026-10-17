// Surface: safety.report — the report entry on the media surfaces that show group-made or shared content (birthday.tribute,
// year.story, collage.view, week.recap): a C-11 "•••" circle on media holding one destructive item, "Report {noun}"
// (design/surfaces/safety.report.md "Entries"; MERGE FV-4). Visual reference: Retro Rewind's "•••" circle and native menu
// (references/auto/retro/press/tc-2025-12-rewind-panels.png, TC-RWP: native menu, destructive red) at the C-01 pair pitch
// `size.global.headerIconPitch` from the close circle (references/auto/retro/lazyweb/retro-lazyweb-20260528-week22-dark-a.png).
import DesignSystem
import SwiftUI

/// The "•••" circle of a recap-preview surface (collage.view, week.recap, year.story): C-11 on media
/// (`size.global.circleButton`, `color.global.controlOnDeep`, `icon.global.more`), its centre on the close circle's
/// centre line, `size.global.headerIconPitch` before it (the C-01 pair pitch), opening the native menu with
/// `itemTitle` (destructive).
struct RecapPreviewReportMenu: View {
    let geometry: RecapPreviewGeometry
    let itemTitle: String
    let action: () -> Void

    var body: some View {
        MediaReportMenu(itemTitle: itemTitle, action: action)
            .position(x: geometry.closeCentreInFrame.x - Tokens.Sizes.globalHeaderIconPitch, y: geometry.closeCentreInFrame.y)
    }
}

/// The "•••" circle on media (C-11, `color.global.controlOnDeep`) with one destructive item, `safety.report.a11y.more`.
struct MediaReportMenu: View {
    let itemTitle: String
    let action: () -> Void

    var body: some View {
        CircleMenu(icon: Tokens.Icons.globalMore, accessibilityLabel: Copy.safetyReportA11yMore, style: .media) {
            Button(itemTitle, role: .destructive, action: action)
        }
        .accessibilityIdentifier("safety.report.more")
    }
}

extension View {
    /// The report flow (`reportFlow(target:dependencies:)`) when the account dependencies are in the environment; screens
    /// rendered without them (some snapshots) attach nothing.
    @ViewBuilder
    func reportFlowIfAvailable(target: Binding<ReportTarget?>, dependencies: AccountDependencies?) -> some View {
        if let dependencies {
            reportFlow(target: target, dependencies: dependencies)
        } else {
            self
        }
    }
}
