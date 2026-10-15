// BLOCKED design values of the account screens — the one place to switch when a value is unblocked. Each flag is false
// while its token is BLOCKED (the element it drives is omitted, per docs/SCREENS_BRIEF.md rule 1); when
// `tools/designgen.mjs` moves the token into `Tokens`, build the element from the generated constant and delete the flag.
// BLOCKED copy lives in `AccountBlockedCopy`.
import DesignSystem
import SwiftUI

enum DesignGaps {
    /// `safety.report.layout.reasons`: the report categories (owner decision). False → no list: the sheet ships with the
    /// optional free-text details (the sourced presentation, MERGE G2-8). With categories: one single-select list of
    /// rows above the details field in the same sheet.
    static var showsReportReasons: Bool { false }

    /// `paywall.layout.iconTileArt`: the paywall icon tile art. False → the tile is omitted.
    static var showsPaywallIconTile: Bool { false }
}
