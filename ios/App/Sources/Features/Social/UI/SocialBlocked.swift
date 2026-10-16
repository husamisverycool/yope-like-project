// Social group — the values the social specs still leave BLOCKED (design/BLOCKED.md), behind one accessor each.
//
// A BLOCKED token is not generated into `Tokens` (only into the DEBUG-only `BlockedTokens`, as `Never`), so a release
// build never reads one. Each accessor below returns the release behaviour — the element is left out, or the data's
// order is kept — and, in DEBUG builds only, the development approximation written in the token's `notes`
// (design/tokens/social.json), so the layout can be reviewed. When the owner's capture fills a value,
// `tools/designgen.mjs` moves it into `Tokens`: replace the accessor with the token and delete the DEBUG branch.
// The row orders (`walls.browse.layout.rowOrder`, `chat.reactions.layout.listOrder`) are in Core (`SocialOrdering`).
// No longer BLOCKED and read from `Tokens` at their use sites: `photo.viewer.layout.voiceNote`,
// `week.history.layout.weekMenu`, `chat.reactions.count.clusterMaxVisible` (RS-7, RS-8, RS-13, RS-20).
import DesignSystem
import SwiftUI

enum SocialBlocked {
    /// `photo.viewer.layout.backZone` — the share of the photo's width (from the leading edge) whose tap goes back.
    /// Release: none (every tap advances; "Previous photo" stays an accessibility action). DEBUG: the leading third.
    static var viewerBackZoneFraction: CGFloat {
        #if DEBUG
        return 1.0 / 3.0 // provenance-ok: BLOCKED photo.viewer.layout.backZone development approximation (token notes), DEBUG only
        #else
        return 0
        #endif
    }

    /// `week.recap.layout.gridFill` — the items the recap card's grid (`layout.year.story.recapCard`, `columns` ×
    /// `maxRows`) shows. Only a full grid is unambiguous; release builds show the card page only then (nil: the page is
    /// left out and the preview shows the cover page). DEBUG: row by row in item order, empty cells in the card fill,
    /// items beyond the grid not drawn.
    static func recapCardItems<Item>(_ items: [Item], columns: Int, maxRows: Int) -> [Item]? {
        let capacity = max(0, columns * maxRows)
        if items.count == capacity, capacity > 0 { return items }
        #if DEBUG
        return items.isEmpty ? nil : Array(items.prefix(capacity))
        #else
        return nil
        #endif
    }

    /// `week.edit.layout.selectionMark` — the in / out mark on a grid cell. Release: none (the state is in the strip and
    /// the cell's accessibility value). DEBUG: `size.global.checkCircle` at the cell's top-right corner, `inset` in,
    /// `icon.global.check` / `icon.global.uncheck` in `color.global.textOnMedia`.
    static var showsSelectionMark: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// The DEBUG approximation's inset of the selection mark (token notes: "6 pt in").
    static var selectionMarkInset: CGFloat {
        #if DEBUG
        return 6 // provenance-ok: BLOCKED week.edit.layout.selectionMark development approximation (token notes), DEBUG only
        #else
        return 0
        #endif
    }

    // `albums.view.shadow.cover` — the album cover is drawn flat in every build until captured (token notes).
}
