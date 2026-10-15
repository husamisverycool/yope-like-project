// BLOCKED design values used by the shared components and the account screens — the one place to switch when a value
// is unblocked. Each accessor returns nil while its token is BLOCKED (the element it drives is omitted, per
// docs/SCREENS_BRIEF.md rule 1); when `tools/designgen.mjs` moves the token into `Tokens`, replace `nil` with the
// generated constant named in the comment and the element ships. BLOCKED copy lives in `AccountBlockedCopy`.
import DesignSystem
import SwiftUI

enum DesignGaps {
    /// `safety.report.layout.reasons`: the report reason list. False → no list (free-text details only).
    static var showsReportReasons: Bool { false }

    /// `paywall.layout.iconTileArt`: the paywall icon tile art. False → the tile is omitted.
    static var showsPaywallIconTile: Bool { false }
}
