// Logic of the shared components (design/components.md): week-strip tile selection (C-17), avatar-stack overflow
// (C-23), the app's tab items (C-04), confirmations (C-26), token parsing (C-25), the text roles' families, and the
// metric stack that places views by baseline / cap height (C-01, C-20, C-27).
@testable import App
import DesignSystem
import SwiftUI
import UIKit
import XCTest

@MainActor
final class ComponentLogicTests: XCTestCase {
    private let calendar = Calendar(identifier: .iso8601)

    private func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date(timeIntervalSince1970: 0)
    }

    // MARK: C-17 week strip

    func testWeekDaysAreMondayFirstAndSeven() {
        let days = WeekStripLayout.days(ofWeekContaining: day(2026, 10, 15), calendar: calendar)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(calendar.component(.weekday, from: days[0]), 2, "Monday first (ISO-8601)")
        XCTAssertEqual(calendar.component(.day, from: days[0]), 12)
        XCTAssertEqual(calendar.component(.day, from: days[6]), 18)
        XCTAssertEqual(days, days.sorted())
    }

    func testEmptyWeekShowsAddFirstThenEveryDay() {
        let days = WeekStripLayout.days(ofWeekContaining: day(2026, 10, 15), calendar: calendar)
        let tiles = WeekStripLayout.tiles(days: days, photos: [], canAdd: true)
        XCTAssertEqual(tiles.count, 8)
        XCTAssertEqual(tiles.first?.kind, .add, "the add tile is first when the week is empty (H43 / H22)")
        XCTAssertEqual(tiles.dropFirst().map(\.kind), Array(repeating: .emptyDay, count: 7))
        XCTAssertEqual(tiles.dropFirst().compactMap(\.date), days)
        XCTAssertEqual(Set(tiles.map(\.id)).count, tiles.count, "tile ids are unique")
    }

    func testEmptyWeekWithoutAddShowsOnlyDays() {
        let days = WeekStripLayout.days(ofWeekContaining: day(2026, 10, 15), calendar: calendar)
        let tiles = WeekStripLayout.tiles(days: days, photos: [], canAdd: false)
        XCTAssertEqual(tiles.map(\.kind), Array(repeating: .emptyDay, count: 7))
    }

    func testPhotosAreChronologicalWithAddLast() {
        let days = WeekStripLayout.days(ofWeekContaining: day(2026, 10, 15), calendar: calendar)
        let photos = [
            WeekStripPhoto(id: "wed", date: day(2026, 10, 14), source: nil),
            WeekStripPhoto(id: "mon", date: day(2026, 10, 12), source: nil),
            WeekStripPhoto(id: "tue-b", date: day(2026, 10, 13, hour: 18), source: nil),
            WeekStripPhoto(id: "tue-a", date: day(2026, 10, 13, hour: 9), source: nil),
        ]
        let tiles = WeekStripLayout.tiles(days: days, photos: photos, canAdd: true)
        XCTAssertEqual(tiles.map(\.id), ["photo-mon", "photo-tue-a", "photo-tue-b", "photo-wed", WeekStripLayout.addID])
        XCTAssertEqual(tiles.last?.kind, .add, "the add tile is last once the week has photos (ST-01 / ST-02)")
        XCTAssertFalse(tiles.contains { $0.kind == .emptyDay }, "a week with photos shows its photos, not empty days")
    }

    func testTwoPhotosOfOneDayAreTwoTiles() {
        let same = day(2026, 10, 13)
        let photos = [
            WeekStripPhoto(id: "b", date: same, source: nil),
            WeekStripPhoto(id: "a", date: same, source: nil),
        ]
        let tiles = WeekStripLayout.tiles(days: [], photos: photos, canAdd: false)
        XCTAssertEqual(tiles.map(\.id), ["photo-a", "photo-b"], "same instant: stable order by id")
        XCTAssertEqual(tiles.compactMap(\.date), [same, same])
    }

    func testPlaceholdersHaveNoContent() {
        let tiles = WeekStripLayout.placeholders(count: 3)
        XCTAssertEqual(tiles.map(\.kind), [.placeholder, .placeholder, .placeholder])
        XCTAssertEqual(Set(tiles.map(\.id)).count, 3)
        XCTAssertTrue(WeekStripLayout.placeholders(count: -1).isEmpty)
    }

    // MARK: C-23 avatar stack

    func testAvatarStackNeverExceedsItsLimits() {
        let diameter = Tokens.Sizes.globalAvatarSmall
        let overlap = Tokens.Sizes.globalAvatarStackOverlap
        XCTAssertEqual(AvatarStackLayout.visibleCount(count: 4, diameter: diameter, overlap: overlap), 4)
        XCTAssertEqual(AvatarStackLayout.visibleCount(count: 9, maxVisible: 5, diameter: diameter, overlap: overlap), 5)
        XCTAssertEqual(AvatarStackLayout.visibleCount(count: 2, maxVisible: 5, diameter: diameter, overlap: overlap), 2)
        XCTAssertEqual(AvatarStackLayout.visibleCount(count: 0, maxVisible: 5, diameter: diameter, overlap: overlap), 0)
        XCTAssertEqual(AvatarStackLayout.visibleCount(count: 3, maxVisible: -2, diameter: diameter, overlap: overlap), 0)
    }

    func testAvatarStackFitsWidthExactly() {
        let diameter = Tokens.Sizes.globalAvatarSmall
        let overlap = Tokens.Sizes.globalAvatarStackOverlap
        for count in 1...12 {
            let width = AvatarStackLayout.width(count: count, diameter: diameter, overlap: overlap)
            XCTAssertEqual(AvatarStackLayout.fittingCount(width: width, diameter: diameter, overlap: overlap), count, "exact fit of \(count)")
            XCTAssertEqual(AvatarStackLayout.fittingCount(width: width - 0.01, diameter: diameter, overlap: overlap), count - 1, "one short of \(count)")
        }
        XCTAssertEqual(AvatarStackLayout.fittingCount(width: 0, diameter: diameter, overlap: overlap), 0)
        XCTAssertEqual(
            AvatarStackLayout.visibleCount(
                count: 10, maxWidth: AvatarStackLayout.width(count: 3, diameter: diameter, overlap: overlap),
                diameter: diameter, overlap: overlap
            ),
            3
        )
        XCTAssertEqual(AvatarStackLayout.width(count: 0, diameter: diameter, overlap: overlap), 0)
        XCTAssertEqual(AvatarStackLayout.width(count: 2, diameter: diameter, overlap: overlap), diameter * 2 - overlap, accuracy: 0.0001)
    }

    // MARK: C-04 tab bar

    func testAppTabsUseRetroOutlineGlyphsAndCountFreeDots() {
        XCTAssertEqual(AppTab.allCases, [.camera, .groups, .walls, .me])
        XCTAssertEqual(AppTab.camera.icon, Tokens.Icons.globalCamera)
        XCTAssertEqual(AppTab.groups.icon, Tokens.Icons.globalHome)
        XCTAssertEqual(AppTab.walls.icon, Tokens.Icons.globalGroup)
        XCTAssertEqual(AppTab.me.icon, Tokens.Icons.globalWall)
        XCTAssertFalse(AppTab.allCases.map(\.icon).contains { $0.hasSuffix(".fill") }, "tab glyphs are outline (icon.global.variantRule)")

        let bar = AppTabBar(selected: .groups, unread: [.walls], unreadValue: "new activity") { _ in }
        let items = bar.items
        XCTAssertEqual(items.map(\.id), AppTab.allCases)
        XCTAssertEqual(items.first { $0.id == .walls }?.unreadValue, "new activity")
        XCTAssertNil(items.first { $0.id == .groups }?.unreadValue)
        XCTAssertEqual(items.map(\.accessibilityLabel), AppTab.allCases.map(\.accessibilityLabel))
    }

    // MARK: C-26 confirmations

    func testConfirmationIsAnnouncedAndKeptUntilDismissed() {
        let toasts = ToastCenter()
        toasts.show("Copied!")
        XCTAssertEqual(toasts.message, "Copied!")
        toasts.show("Saved!")
        XCTAssertEqual(toasts.message, "Saved!", "the next confirmation replaces the last")
        toasts.dismiss()
        XCTAssertNil(toasts.message)
    }

    // MARK: Tokens read by components

    func testPremiumGradientParsesItsTokenHex() throws {
        let top = try XCTUnwrap(PremiumGradient.color(hex: Tokens.Layouts.GlobalPremiumGradient.top))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(top).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        XCTAssertEqual(red, 0xD5 / 255.0, accuracy: 0.002)
        XCTAssertEqual(green, 0x43 / 255.0, accuracy: 0.002)
        XCTAssertEqual(blue, 0xDE / 255.0, accuracy: 0.002)
        XCTAssertEqual(alpha, 1, accuracy: 0.001)
        XCTAssertNil(PremiumGradient.color(hex: "not a colour"))
        XCTAssertNil(PremiumGradient.color(hex: "#12345"))
    }

    func testDisplayRolesUseTheSerifAndUIRolesTheSans() {
        for role in [TextRole.headerTitle, TextRole.displayMedium, TextRole.displaySmall] {
            XCTAssertEqual(role.family, Tokens.Fonts.globalDisplay)
        }
        for role in [TextRole.body, TextRole.listTitle, TextRole.button, TextRole.pill, TextRole.badge, TextRole.tileLabel] {
            XCTAssertEqual(role.family, Tokens.Fonts.globalFamily)
        }
        XCTAssertEqual(TextRole.headerTitle.size, Tokens.FontSizes.globalHeaderTitle)
        XCTAssertEqual(TextRole.headerTitle.lineHeight, Tokens.LineHeights.globalHeaderTitle)
        XCTAssertEqual(TextRole.headerTitle.relativeTo, Font.TextStyle(tokenName: Tokens.Layouts.GlobalTextStyleMap.headerTitle))
        XCTAssertEqual(TextRole.caption.lineHeight, Tokens.LineHeights.globalCaption)
        XCTAssertEqual(TextRole.badge.relativeTo, .caption2)
    }

    func testSerifMetricsResolve() {
        let serif = TextMetrics(style: TextRole.headerTitle, size: TextRole.headerTitle.size)
        let sans = TextMetrics(style: TextRole.body, size: TextRole.body.size)
        XCTAssertGreaterThan(serif.capHeight, 0)
        XCTAssertLessThan(serif.capHeight, TextRole.headerTitle.size)
        XCTAssertGreaterThan(serif.belowBaseline, 0)
        XCTAssertGreaterThan(serif.capHeight, sans.capHeight)
        XCTAssertGreaterThanOrEqual(sans.capTopOffset, 0)
    }

    func testDarkAppearanceValueResolvesTheDarkToken() {
        var white: CGFloat = 0, alpha: CGFloat = 0
        UIColor(Tokens.Colors.globalTextPrimary.darkAppearanceValue).getWhite(&white, alpha: &alpha)
        XCTAssertEqual(white, 1, accuracy: 0.01, "color.global.textPrimary dark = #FFFFFF")
    }

    // MARK: Metric stack (C-01, C-20, C-27 spacing by text metrics)

    private func fittingHeight<V: View>(_ view: V, width: CGFloat = 390) -> CGFloat {
        let host = UIHostingController(rootView: view)
        return host.sizeThatFits(in: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height
    }

    func testMetricStackSpacesByLines() {
        let stacked = MetricStack {
            Color.clear.frame(height: 10)
            Color.clear.frame(height: 10).metricGap(5, from: .bottom, to: .top)
            Color.clear.frame(height: 10)
        }
        XCTAssertEqual(fittingHeight(stacked), 35, accuracy: 0.5, "gap, then a child directly below")

        let overlapping = MetricStack {
            Color.clear.frame(height: 10)
            Color.clear.frame(height: 10).metricGap(-4, from: .bottom, to: .top)
        }
        XCTAssertEqual(fittingHeight(overlapping), 16, accuracy: 0.5)

        let fromTop = MetricStack {
            Color.clear.frame(height: 10).metricGap(-6, from: .top, to: .top)
        }
        XCTAssertEqual(fittingHeight(fromTop), 10, accuracy: 0.5, "a child above the top moves everything down")
    }

    func testRootHeaderEndsWhereContentStarts() {
        // Title baseline `size.global.titleTop` below the top; content `size.global.titleToContent` below the baseline.
        let height = fittingHeight(ScreenHeader(title: "Week 43").environment(\.dynamicTypeSize, .large))
        XCTAssertEqual(height, Tokens.Sizes.globalTitleTop + Tokens.Sizes.globalTitleToContent, accuracy: 2)
    }
}
