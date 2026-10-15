// Surface: chat.reactions — reference app: Locket (reactions). Spec: design/surfaces/chat.reactions.md.
// References: references/auto/locket/store/locket-store-04.png (cluster), …/locket-store-08.png (quick reactions),
// references/auto/locket/frames/locket-tt-7460656081153445163-15.000s-emoji-picker-sheet-search-popular.jpg (picker),
// references/auto/locket/frames/locket-tt-7147749171762908462-05.300s-emoji-rain-rising-behind-photo.jpg (rain).
// Tenet: no number anywhere — not on the cluster, not in the list, not in accessibility labels.
import AppData
import AppModels
import DesignSystem
import SwiftUI

// MARK: - Cluster (§1)

/// One sticker per distinct emoji, each `chat.reactions.dimension.clusterStep` right of the previous one and drawn
/// over it; white outline. Order `chat.reactions.layout.clusterOrder`: newest first — a new emoji enters at the leading
/// end and the others shift one step trailing, flying in from below the photo's edge and shrinking from the picker's
/// size in `chat.reactions.duration.flyToCluster` (decelerating; the pick point itself is not tracked — approximation).
/// Reduce Motion: inserted without animation. Every distinct emoji shows (the visible maximum is BLOCKED,
/// `chat.reactions.count.clusterMaxVisible`), clipped by the photo. Hidden when nobody reacted.
struct ReactionCluster: View {
    let allEmoji: [String]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(emoji: [String]) {
        allEmoji = emoji
    }

    private var emoji: [String] {
        SocialBlocked.clusterMaxVisible.map { Array(allEmoji.prefix($0)) } ?? allEmoji
    }

    /// `chat.reactions.duration.flyToCluster` with a decelerating curve: the curve was not fitted (G-12), so the platform
    /// default for unmeasured custom motion (`spring.global.platformDefault.ios`, critically damped) runs over the
    /// measured duration.
    private static let flight = DSAnimation.spring(DSSpring(
        response: Tokens.Durations.chatReactionsDurationFlyToCluster,
        dampingFraction: Tokens.Springs.globalPlatformDefaultIos.dampingFraction
    ))

    private var flyIn: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: Tokens.Sizes.chatReactionsDimensionPickerEmoji / Tokens.Sizes.chatReactionsDimensionClusterEmoji)
                .combined(with: .offset(y: Tokens.Sizes.chatReactionsDimensionClusterInsetBottom + Tokens.Sizes.chatReactionsDimensionClusterEmoji)),
            removal: .identity
        )
    }

    var body: some View {
        let step = Tokens.Sizes.chatReactionsDimensionClusterStep
        let size = Tokens.Sizes.chatReactionsDimensionClusterEmoji
        ZStack(alignment: .leading) {
            ForEach(Array(emoji.enumerated()), id: \.element) { index, glyph in
                ReactionSticker(emoji: glyph)
                    .offset(x: CGFloat(index) * step)
                    .transition(flyIn)
            }
        }
        .frame(width: emoji.isEmpty ? 0 : size + CGFloat(emoji.count - 1) * step, height: emoji.isEmpty ? 0 : size, alignment: .leading)
        .animation(reduceMotion ? nil : Self.flight.animation, value: emoji)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(allEmoji.isEmpty ? "" : SocialEmoji.clusterLabel(allEmoji)))
        .accessibilityAddTraits(.isButton)
        .accessibilityHidden(allEmoji.isEmpty)
    }
}

/// An emoji with the sticker outline (`chat.reactions.dimension.clusterOutline` in `chat.reactions.color.clusterOutline`),
/// `chat.reactions.dimension.clusterEmoji` wide outline included.
struct ReactionSticker: View {
    let emoji: String

    private var outline: CGFloat { Tokens.Sizes.chatReactionsDimensionClusterOutline }

    var body: some View {
        let glyph = Tokens.Sizes.chatReactionsDimensionClusterEmoji - outline * 2
        Text(emoji)
            .font(Tokens.Fonts.globalFamily.font(size: glyph, weight: Font.Weight.regular))
            .shadow(color: Tokens.Colors.chatReactionsColorClusterOutline, radius: 0, x: outline, y: 0)
            .shadow(color: Tokens.Colors.chatReactionsColorClusterOutline, radius: 0, x: -outline, y: 0)
            .shadow(color: Tokens.Colors.chatReactionsColorClusterOutline, radius: 0, x: 0, y: outline)
            .shadow(color: Tokens.Colors.chatReactionsColorClusterOutline, radius: 0, x: 0, y: -outline)
            .frame(width: Tokens.Sizes.chatReactionsDimensionClusterEmoji, height: Tokens.Sizes.chatReactionsDimensionClusterEmoji)
            .accessibilityHidden(true)
    }
}

// MARK: - Emoji rain (§4)

/// `chat.reactions.layout.rainPath`: `chat.reactions.count.rainCopies` copies of the emoji just sent, entering below
/// the bottom edge at random x positions, one every `chat.reactions.duration.rainSpawnInterval`, each rising past the
/// top edge in `chat.reactions.duration.rainTravel` along `chat.reactions.easing.rain`; the effect lasts
/// `chat.reactions.duration.rainTotal`. Placed behind the photo, in front of the background; never interactive; hidden
/// from accessibility.
///
/// Reduce Motion (`chat.reactions.layout.reduceMotion`): not played; the sticker appears in place.
struct EmojiRain: View {
    let trigger: SentReaction?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var run: RainRun?

    struct RainRun: Equatable {
        let emoji: String
        let start: Date
        /// One x position (0…1 of the width) per copy.
        let positions: [Double]
    }

    var body: some View {
        content
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onChange(of: trigger) { _, new in
                guard let new, !reduceMotion else { return }
                let copies = Int(Tokens.Counts.chatReactionsCountRainCopies)
                run = RainRun(emoji: new.emoji, start: Date(), positions: (0..<copies).map { _ in Double.random(in: 0...1) })
            }
    }

    @ViewBuilder
    private var content: some View {
        if let run {
            TimelineView(.animation) { context in
                GeometryReader { geometry in
                    let elapsed = context.date.timeIntervalSince(run.start)
                    ZStack {
                        ForEach(Array(run.positions.enumerated()), id: \.offset) { index, x in
                            copy(run.emoji, index: index, x: x, elapsed: elapsed, size: geometry.size)
                        }
                    }
                    .onChange(of: elapsed >= Tokens.Durations.chatReactionsDurationRainTotal) { _, finished in
                        if finished { self.run = nil }
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func copy(_ emoji: String, index: Int, x: Double, elapsed: TimeInterval, size: CGSize) -> some View {
        let glyph = Tokens.Sizes.chatReactionsDimensionRainEmoji
        let linear = (elapsed - Double(index) * Tokens.Durations.chatReactionsDurationRainSpawnInterval) / Tokens.Durations.chatReactionsDurationRainTravel
        let progress = Tokens.Easings.chatReactionsEasingRain.unitCurve.value(at: min(max(linear, 0), 1))
        if linear >= 0, linear <= 1 {
            // From just below the bottom edge to just past the top edge.
            let startY = size.height + glyph / 2
            let endY = -glyph / 2
            Text(emoji)
                .font(Tokens.Fonts.globalFamily.font(size: glyph, weight: Font.Weight.regular))
                .position(x: x * size.width, y: startY + (endY - startY) * progress)
        }
    }
}

// MARK: - Picker (§2)

/// Identifies the post a picker sheet reacts to.
struct ReactionPickerTarget: Identifiable, Hashable {
    let postID: PostID
    var id: String { postID.rawValue }
}

/// `chat.reactions.layout.picker`: native sheet with a grabber — search, "Frequently Used" (this device's recent
/// emoji, one row of `chat.reactions.count.pickerColumns`), "Popular" (`chat.reactions.layout.pickerPopular`), "All"
/// (every emoji in Unicode order; the system categories order is not available to apps). Grid of
/// `chat.reactions.count.pickerColumns` columns, emoji at `chat.reactions.dimension.pickerEmoji`. A tap sends and closes.
struct ReactionPicker: View {
    /// The emoji I already reacted with on this photo (`chat.reactions.layout.unreact`): highlighted on a
    /// `color.global.selection` circle with the selected trait; tapping one takes it back (the sheet stays).
    var mine: Set<String> = []
    let onPick: (String) -> Void
    var onRemove: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var recent: [String] = []

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: Int(Tokens.Counts.chatReactionsCountPickerColumns))
    }

    static let popular: [String] = [
        Tokens.Layouts.ChatReactionsLayoutPickerPopular.row1, Tokens.Layouts.ChatReactionsLayoutPickerPopular.row2,
        Tokens.Layouts.ChatReactionsLayoutPickerPopular.row3, Tokens.Layouts.ChatReactionsLayoutPickerPopular.row4,
        Tokens.Layouts.ChatReactionsLayoutPickerPopular.row5,
    ].flatMap { $0.split(separator: " ").map(String.init) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, alignment: .center, pinnedViews: []) {
                    if search.isEmpty {
                        if !recent.isEmpty {
                            section(Copy.chatReactionsPickerFrequent, recent)
                        }
                        section(Copy.chatReactionsPickerPopular, Self.popular)
                        section(Copy.chatReactionsPickerAll, ReactionPicker.allEmoji)
                    } else {
                        ForEach(ReactionPicker.allEmoji.filter { SocialEmoji.name($0).contains(search.lowercased()) }, id: \.self) { emoji in
                            cell(emoji)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: Text(Copy.chatReactionsPickerSearch))
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            recent = Array(SocialServices.shared.flags.recentEmoji().prefix(Int(Tokens.Counts.chatReactionsCountPickerColumns)))
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ emoji: [String]) -> some View {
        Section {
            ForEach(emoji, id: \.self) { cell($0) }
        } header: {
            Text(title)
                .dsTextStyle(SocialText.pickerSection)
                .foregroundStyle(Tokens.Colors.globalTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func cell(_ emoji: String) -> some View {
        let isMine = mine.contains(emoji)
        return Button {
            if isMine {
                onRemove(emoji)
            } else {
                SocialServices.shared.flags.recordEmoji(emoji, keep: Int(Tokens.Counts.chatReactionsCountPickerColumns))
                onPick(emoji)
                dismiss()
            }
        } label: {
            Text(emoji)
                .font(Tokens.Fonts.globalFamily.font(size: Tokens.Sizes.chatReactionsDimensionPickerEmoji, weight: Font.Weight.regular))
                .frame(minWidth: Tokens.Sizes.globalMinTouchTargetIos, minHeight: Tokens.Sizes.globalMinTouchTargetIos)
                .background {
                    if isMine { Circle().fill(Tokens.Colors.globalSelection) }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(SocialEmoji.name(emoji)))
        .accessibilityAddTraits(isMine ? .isSelected : [])
    }

    /// Single-scalar emoji with emoji presentation, in code point order.
    static let allEmoji: [String] = {
        let ranges: [ClosedRange<UInt32>] = [0x2600...0x27BF, 0x1F300...0x1F5FF, 0x1F600...0x1F64F, 0x1F680...0x1F6FF, 0x1F900...0x1F9FF, 0x1FA70...0x1FAFF] // provenance-ok: Unicode emoji blocks
        return ranges.flatMap { range in
            range.compactMap { value -> String? in
                guard let scalar = Unicode.Scalar(value), scalar.properties.isEmojiPresentation else { return nil }
                return String(scalar)
            }
        }
    }()
}

// MARK: - Activity sheet (§5)

/// Identifies the post whose reactions list is open.
struct ReactionActivityTarget: Identifiable, Hashable {
    let postID: PostID
    var id: String { postID.rawValue }
}

/// "Activity": one row per reaction — "{name} sent {emoji}" or, for mine, "You reacted {emoji} to {name}’s pic".
/// No counts, no totals. The row layout and order are BLOCKED (`chat.reactions.layout.activitySheet`): native list
/// rows in the data's order. Empty: "No reactions yet".
struct ReactionActivitySheet: View {
    let reactions: ReactionSummary
    let me: UserID?
    let posterFirstName: String
    let nameOf: (UserID) -> String

    var body: some View {
        NavigationStack {
            Group {
                if reactions.isEmpty {
                    Text(Copy.chatReactionsEmpty)
                        .foregroundStyle(Tokens.Colors.globalTextSecondary)
                } else {
                    List(Array(reactions.rows.enumerated()), id: \.offset) { _, row in
                        Text(row.userID == me
                            ? Copy.chatReactionsActivityRowMine(emoji: row.emoji, name: posterFirstName)
                            : Copy.chatReactionsActivityRow(name: nameOf(row.userID), emoji: row.emoji))
                    }
                }
            }
            .navigationTitle(Text(Copy.chatReactionsActivityTitle))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDragIndicator(.visible)
    }
}
