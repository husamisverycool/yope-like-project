// Styling slots for the widgets and the Live Activity. They receive the data and render
// nothing visible yet (`Color.clear` keeps a real view in the tree so modifiers such as
// `containerBackground` stay attached): every text, color, size and layout here comes from the surface
// specs (design/surfaces/widget.*.md, daily.liveactivity.md) as Tokens.* / Copy.* in the
// screens pass. The photo itself (GroupPhotoWidget.swift) and the countdown text
// (`InvitationCountdown`) are data and render now.
import AppModels
import SwiftUI
import WidgetKit

/// Home-screen widget content over the photo (sender, caption, collage marker).
struct WidgetOverlay: View {
    let snapshot: WidgetSnapshot?
    let family: WidgetFamily

    var body: some View {
        Color.clear
    }
}

/// `.accessoryInline` (one line of text next to the clock).
struct WidgetInlineSlot: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        Color.clear
    }
}

/// Shown when no rendition has arrived for the group yet (`widget.*` empty state).
struct WidgetEmptyState: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        Color.clear
    }
}

/// Lock-screen / banner presentation of the daily invitation Live Activity, around the countdown.
struct InvitationLockScreenSlot: View {
    let attributes: DailyInvitationAttributes
    let state: DailyInvitationAttributes.ContentState
    let isStale: Bool

    var body: some View {
        InvitationCountdown(closesAt: state.closesAt)
    }
}

/// Expanded Dynamic Island content.
struct InvitationExpandedSlot: View {
    let state: DailyInvitationAttributes.ContentState

    var body: some View {
        InvitationCountdown(closesAt: state.closesAt)
    }
}

/// Compact leading Dynamic Island content.
struct InvitationCompactLeadingSlot: View {
    let state: DailyInvitationAttributes.ContentState

    var body: some View {
        EmptyView()
    }
}
