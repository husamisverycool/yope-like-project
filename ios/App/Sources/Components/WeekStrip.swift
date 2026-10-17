// Shared component — C-17 week strip and day tiles (design/components.md). Evidence: H43 / H22 (empty week: add tile
// first, then one empty-day tile per day; strip x48–299, y468–803; gap x300–305; corner fit R 54 px; '+' 23 pt), ST-02
// (photos then the add tile last; labels, scrim), WEB-PLUS, VID-COMP (placeholders); RV §3.4, §3.5, §3.8, §4 #2;
// design/research/retro-timehop.md ("Day strip").
import DesignSystem
import SwiftUI

/// A photo of the week, in the strip's chronological order.
struct WeekStripPhoto: Hashable {
    let id: String
    let date: Date
    var source: PhotoSource?
    /// A video's length (ms): its tile carries the video marker (`layout.global.videoMarker`); nil for photos.
    var videoDurationMs: Int?
    /// The photo leads photos posted together (`layout.global.batchMarker`): its tile carries the batch marker.
    var isBatch: Bool

    init(id: String, date: Date, source: PhotoSource?, videoDurationMs: Int? = nil, isBatch: Bool = false) {
        self.id = id
        self.date = date
        self.source = source
        self.videoDurationMs = videoDurationMs
        self.isBatch = isBatch
    }
}

/// One tile of the strip.
struct WeekStripTile: Identifiable, Hashable {
    enum Kind: Hashable {
        /// Aspect-fill photo with the weekday label over the bottom scrim.
        case photo(PhotoSource?)
        /// A day without photos: month / day number / weekday.
        case emptyDay
        /// '+': add to the week.
        case add
        /// Loading or a composer slot: the fill only.
        case placeholder
    }

    let id: String
    let kind: Kind
    /// The photo's or the empty day's date (nil for add / placeholder tiles).
    let date: Date?
    /// A video tile: its length (ms), shown by the video marker (`layout.global.videoMarker`).
    var videoDurationMs: Int? = nil
    /// The tile stands for photos posted together (`layout.global.batchMarker`, one tile for the batch).
    var isBatch: Bool = false
}

/// Which tiles a week shows (C-17): one tile per photo in chronological order (two photos of one day → two tiles);
/// a week without photos shows one empty-day tile per day instead. The add tile (when the viewer can add) is first
/// when the week is empty and last otherwise (H43 / H22 vs ST-01 / ST-02).
enum WeekStripLayout {
    static func tiles(days: [Date], photos: [WeekStripPhoto], canAdd: Bool) -> [WeekStripTile] {
        let add = WeekStripTile(id: addID, kind: .add, date: nil)
        guard !photos.isEmpty else {
            let empty = days.sorted().map { day in
                WeekStripTile(id: "day-\(Int(day.timeIntervalSinceReferenceDate))", kind: .emptyDay, date: day)
            }
            return (canAdd ? [add] : []) + empty
        }
        // Stable chronological order: by date, then by id for photos taken at the same instant.
        let ordered = photos.sorted { lhs, rhs in
            lhs.date == rhs.date ? lhs.id < rhs.id : lhs.date < rhs.date
        }
        let tiles = ordered.map { photo in
            WeekStripTile(
                id: "photo-\(photo.id)", kind: .photo(photo.source), date: photo.date, videoDurationMs: photo.videoDurationMs,
                isBatch: photo.isBatch
            )
        }
        return tiles + (canAdd ? [add] : [])
    }

    /// `count` placeholder tiles (loading; the composer's empty slots — VID-COMP).
    static func placeholders(count: Int) -> [WeekStripTile] {
        (0..<max(0, count)).map { WeekStripTile(id: "placeholder-\($0)", kind: .placeholder, date: nil) }
    }

    /// The seven days (start of day) of the week containing `date`, Monday first: Retro numbers weeks the ISO-8601 way
    /// (retro-timehop.md "Week numbering").
    static func days(ofWeekContaining date: Date, calendar: Calendar = Calendar(identifier: .iso8601)) -> [Date] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        let start = calendar.startOfDay(for: week.start)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) } // provenance-ok: 7 days in a week
    }

    static let addID = "add"
}

/// A day tile: `size.global.stripTileWidth` × `.stripTileHeight` (3:4), square inner corners (`radius.global.photo`).
///
/// - Photo: aspect-fill; bottom scrim `layout.global.photoScrim`; weekday (text role `tileLabel`,
///   `color.global.textOnMedia`) centred, its baseline `size.global.tileLabelBaseline` above the bottom; a video carries
///   the video marker at the top-trailing corner (`layout.global.videoMarker`; glyph only at this width); the first of
///   photos posted together carries the batch marker there (`layout.global.batchMarker`).
/// - Empty day: fill `color.global.control`; three centred lines in `color.global.emptyTileText` — month (text role
///   `tileMonth`), day number (text role `tileDay`, tabular digits), weekday (`tileMonth`). Retro's 27 pt line pitch has
///   no token (Gap) — the lines stack at the fonts' own line heights.
/// - Add: fill `color.global.control`; `icon.global.add` in the `size.global.icon` box (the measured 23 pt ink),
///   `color.global.textPrimary`.
/// - Placeholder: fill `color.global.control`.
/// Dates are formatted in the person's locale (abbreviated month and weekday, as Retro's 'Oct' / 'Mon').
struct DayTile: View {
    let tile: WeekStripTile

    var body: some View {
        content
            .frame(width: Tokens.Sizes.globalStripTileWidth, height: Tokens.Sizes.globalStripTileHeight)
            .clipShape(Rectangle())
    }

    @ViewBuilder
    private var content: some View {
        switch tile.kind {
        case let .photo(source):
            PhotoView(source: source)
                .overlay { PhotoScrim() }
                .overlay(alignment: .bottom) {
                    if let date = tile.date {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .dsTextStyle(TextRole.tileLabel)
                            .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                            .lineLimit(1)
                            .alignmentGuide(.bottom) { label in label[.lastTextBaseline] + Tokens.Sizes.globalTileLabelBaseline }
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if let durationMs = tile.videoDurationMs { VideoTileMarker(durationMs: durationMs) }
                }
                .overlay(alignment: .topTrailing) {
                    if tile.isBatch { BatchTileMarker(belowVideoMarker: tile.videoDurationMs != nil) }
                }
        case .emptyDay:
            ZStack {
                Tokens.Colors.globalControl
                if let date = tile.date {
                    VStack(spacing: 0) {
                        Text(date.formatted(.dateTime.month(.abbreviated)))
                            .dsTextStyle(TextRole.tileMonth)
                        Text(date.formatted(.dateTime.day()))
                            .dsTextStyle(TextRole.tileDay)
                            .monospacedDigit()
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .dsTextStyle(TextRole.tileMonth)
                    }
                    .lineLimit(1)
                    .foregroundStyle(Tokens.Colors.globalEmptyTileText)
                }
            }
        case .add:
            ZStack {
                Tokens.Colors.globalControl
                Glyph(Tokens.Icons.globalAdd)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
            }
        case .placeholder:
            Tokens.Colors.globalControl
        }
    }
}

/// C-17 week strip: a horizontal scroller starting at the leading `size.global.screenMargin` (no trailing inset when it
/// overflows), tiles `size.global.stripGap` apart with the page colour showing through, only the strip's outer corners
/// rounded (`radius.global.card`, continuous). Tiles insert with `duration.global.stripInsert` /
/// `easing.global.standard` and fade in with `duration.global.fade` (Retro's ≤ 0.875 start scale has no token — Gap —
/// so the tile only fades); Reduce Motion keeps the fade.
///
/// Pressed: platform default (iOS plays no tap haptic). Selected (composer): not legible in VID-COMP (Gap).
/// Accessibility: each tile except placeholders is a button labelled by `accessibilityLabel` (copy: "Monday, June 26,
/// photo by {name}", "Thursday, June 29, no photos", "Add a photo") — the empty-tile text fails contrast (failure 3) and
/// the photo label depends on the photo (failure 8), so the label carries the information; text in the fixed tiles is
/// not relied on at large Dynamic Type sizes. The strip is one container.
struct WeekStrip: View {
    let tiles: [WeekStripTile]
    let accessibilityLabel: (WeekStripTile) -> String
    var onSelect: (WeekStripTile) -> Void = { _ in }

    init(
        tiles: [WeekStripTile],
        accessibilityLabel: @escaping (WeekStripTile) -> String,
        onSelect: @escaping (WeekStripTile) -> Void = { _ in }
    ) {
        self.tiles = tiles
        self.accessibilityLabel = accessibilityLabel
        self.onSelect = onSelect
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Sizes.globalStripGap) {
                ForEach(tiles) { tile in
                    tileView(tile)
                        .dsTransition(AnyTransition.opacity.animation(ComponentMotion.fade.animation))
                }
            }
            .clipShape(DSShape.rounded(Tokens.Radii.globalCard))
            .padding(.leading, Tokens.Sizes.globalScreenMargin)
            .dsAnimation(ComponentMotion.stripInsert, value: tiles.map(\.id))
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func tileView(_ tile: WeekStripTile) -> some View {
        if tile.kind == .placeholder {
            DayTile(tile: tile)
                .accessibilityHidden(true)
        } else {
            Button {
                onSelect(tile)
            } label: {
                DayTile(tile: tile)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(accessibilityLabel(tile)))
        }
    }
}
