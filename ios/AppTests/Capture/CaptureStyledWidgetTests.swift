// Surfaces: widget.friend, widget.memories, widget.styles, widget.home.small (All Groups) — the home-screen photo widgets'
// resolution from the App Group store and their snapshots at the HIG sizes (393 × 852 screen; extra large on iPad).
// References: design/surfaces/widget.friend.md, widget.memories.md, widget.styles.md.
import AppModels
import DesignSystem
import SwiftUI
import UIKit
import XCTest
@testable import App

@MainActor
final class CaptureStyledWidgetTests: XCTestCase {
    private var directory: URL!
    private var store: WidgetStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("StyledWidgets-\(UUID().uuidString)", isDirectory: true)
        store = WidgetStore(rootURL: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private var jpeg: Data { CaptureTestImages.jpeg(CGSize(width: 600, height: 630)) }

    private func photo(group: String = "g1", post: String, sender: String = "u1", at seconds: TimeInterval) -> WidgetSnapshot {
        WidgetSnapshot(groupID: group, groupName: "Family", sourceID: post, photoFileName: "photo-\(post).jpg", senderID: sender,
                       senderDisplayName: "Ana Lima", kind: .photo, postedAt: Date(timeIntervalSince1970: seconds))
    }

    // MARK: Friend Updates

    func testFriendWidgetStates() throws {
        let now = Date()
        XCTAssertEqual(StyledEntryResolver.friend(personID: "u1", style: nil, store: store, at: now).presentation.content.state, .signedOut)
        try store.syncGroups([WidgetGroup(id: "g1", name: "Family")])
        try store.syncPeople([WidgetPerson(id: "u1", name: "Ana Lima")])
        let unchosen = StyledEntryResolver.friend(personID: nil, style: nil, store: store, at: now)
        XCTAssertEqual(unchosen.presentation.content.state, .notSetUp)
        XCTAssertEqual(unchosen.presentation.resolvedStateLine, Copy.widgetFriendEmptySetUp)
        XCTAssertEqual(StyledEntryResolver.friend(personID: "gone", style: nil, store: store, at: now).presentation.content.state, .notSetUp,
                       "someone no longer in a shared group")
        XCTAssertEqual(StyledEntryResolver.friend(personID: "u1", style: nil, store: store, at: now).presentation.content.state, .loading,
                       "never looked up: it does not claim there are no photos")
        try store.removePersonSnapshot(personID: "u1")
        let empty = StyledEntryResolver.friend(personID: "u1", style: nil, store: store, at: now)
        XCTAssertEqual(empty.presentation.content.state, .empty)
        XCTAssertEqual(empty.presentation.resolvedAccessibilityLabel, Copy.widgetFriendEmptyNoPhotos)
        try store.savePerson(photo(post: "p1", at: 1_000), personID: "u1", photo: jpeg)
        let entry = StyledEntryResolver.friend(personID: "u1", style: nil, store: store, at: now)
        XCTAssertEqual(entry.presentation.content.state, .photo)
        XCTAssertEqual(entry.presentation.content.firstName, "Ana")
        XCTAssertEqual(entry.presentation.resolvedAccessibilityLabel, Copy.widgetHomeSmallA11yPhoto(name: "Ana", group: "Family"))
        XCTAssertEqual(entry.tapURL?.absoluteString, "app://camera?group=g1", "the camera for the photo's group")
    }

    // MARK: Styles

    func testPremiumStylesDrawPhotoAndAskForThePaywallWithoutPremium() throws {
        try store.syncGroups([WidgetGroup(id: "g1", name: "Family")])
        try store.writeFile(jpeg, groupID: "g1", fileName: "photo-p1.jpg")
        try store.save(photo(post: "p1", at: 1_000))
        let locked = StyledEntryResolver.group(configuredGroupID: "g1", allGroups: false, style: .frame, store: store, at: Date())
        XCTAssertEqual(locked.presentation.style, .photo, "the free widget keeps working")
        XCTAssertTrue(locked.locked)
        XCTAssertEqual(locked.tapURL?.absoluteString, "app://premium?perk=widgets&to=camera&group=g1")
        XCTAssertEqual(DeepLinkParser(universalLinkHosts: []).parse(locked.tapURL!), .premium(perk: "widgets", then: .camera(groupID: "g1")))
        try store.setPremium(true)
        let unlocked = StyledEntryResolver.group(configuredGroupID: "g1", allGroups: false, style: .frame, store: store, at: Date())
        XCTAssertEqual(unlocked.presentation.style, .frame)
        XCTAssertFalse(unlocked.locked)
        XCTAssertEqual(unlocked.tapURL?.absoluteString, "app://camera?group=g1")
        let free = StyledEntryResolver.group(configuredGroupID: "g1", allGroups: false, style: nil, store: store, at: Date())
        XCTAssertEqual(free.presentation.style, .photo)
    }

    func testPrintFitsInsideTheWidget() {
        let small = WidgetPrintBackground.printSize(in: CGSize(width: 158, height: 158))
        XCTAssertEqual(small.height, 158 * Tokens.Layouts.WidgetStylesLayoutFrame.fit, accuracy: 0.01, "height-limited on a square")
        XCTAssertEqual(small.height / small.width, Tokens.Layouts.WidgetStylesLayoutFrame.aspect, accuracy: 0.001)
        let large = WidgetPrintBackground.printSize(in: CGSize(width: 338, height: 354))
        XCTAssertLessThanOrEqual(large.width, 338 * Tokens.Layouts.WidgetStylesLayoutFrame.fit + 0.01)
        XCTAssertLessThanOrEqual(large.height, 354 * Tokens.Layouts.WidgetStylesLayoutFrame.fit + 0.01)
    }

    // MARK: All Groups

    func testAllGroupsShowsTheNewestAcrossGroups() throws {
        try store.syncGroups([WidgetGroup(id: "g1", name: "Family"), WidgetGroup(id: "g2", name: "Roommates")])
        for (group, seconds) in [("g1", 1_000.0), ("g2", 3_000.0)] {
            try store.writeFile(jpeg, groupID: group, fileName: "photo-\(group).jpg")
            try store.save(photo(group: group, post: group, at: seconds))
        }
        let entry = StyledEntryResolver.group(configuredGroupID: "all-groups", allGroups: true, style: nil, store: store, at: Date())
        XCTAssertEqual(entry.presentation.content.state, .photo)
        XCTAssertEqual(entry.tapURL?.absoluteString, "app://camera?group=g2")
    }

    // MARK: Your Memories

    func testMemoriesWidgetDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 9)))
        XCTAssertEqual(StyledEntryResolver.memories(style: nil, store: store, at: now, calendar: calendar).presentation.content.state, .signedOut)
        try store.syncGroups([WidgetGroup(id: "g1", name: "Family")])
        XCTAssertEqual(StyledEntryResolver.memories(style: nil, store: store, at: now, calendar: calendar).presentation.content.state, .loading,
                       "not looked up yet")
        try store.replaceMemories(days: "2026-10-17"..."2026-10-18",
                                  memories: ["2026-10-18": photo(post: "m1", at: 1_729_000_000)], photos: ["photo-m1.jpg": jpeg])
        let today = StyledEntryResolver.memories(style: nil, store: store, at: now, calendar: calendar)
        XCTAssertEqual(today.presentation.content.state, .empty)
        XCTAssertEqual(today.presentation.resolvedStateLine, Copy.widgetMemoriesEmptyNone, "honest: no memory today, never another photo")
        XCTAssertNil(today.tapURL)
        let entries = StyledEntryResolver.memoryEntries(style: nil, store: store, now: now, calendar: calendar)
        XCTAssertEqual(entries.count, 3, "today, tomorrow's memory at midnight, then loading past the looked-up days")
        XCTAssertEqual(entries[1].date, calendar.startOfDay(for: try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: now))))
        XCTAssertEqual(entries[1].presentation.content.state, .photo)
        XCTAssertEqual(entries[1].tapURL?.absoluteString, "app://post?group=g1&post=m1", "the memory in the viewer")
        XCTAssertEqual(entries[1].presentation.resolvedAccessibilityLabel,
                       Copy.widgetMemoriesA11yPhoto(date: entries[1].presentation.dateText, group: "Family"))
        XCTAssertEqual(entries[2].presentation.content.state, .loading)
    }
}

/// Snapshots of the friend and memories widgets and of the styles, at every home-screen size.
@MainActor
final class CaptureStyledWidgetSnapshotTests: XCTestCase {
    private func size(_ token: String) -> CGSize {
        let parts = token.split(separator: "x").compactMap { Double($0) }
        return CGSize(width: parts[0], height: parts[1])
    }

    private var families: [(String, CGSize)] {
        [
            ("small", size(Tokens.Layouts.WidgetHomeSmallLayoutSize.w393h852)),
            ("medium", size(Tokens.Layouts.WidgetHomeMediumLayoutSize.w393h852)),
            ("large", size(Tokens.Layouts.WidgetHomeLargeLayoutSize.w393h852)),
            ("xl", size(Tokens.Layouts.WidgetHomeXlLayoutSize.ipad1024x1366)),
        ]
    }

    private func content(_ state: GroupWidgetContent.State, scene: Int = 2) -> GroupWidgetContent {
        GroupWidgetContent(
            state: state, groupName: "Family", senderName: "Ana Lima", postedAt: CaptureTestRig.fixedNow,
            photo: state == .photo ? CaptureTestImages.scene(scene, CGSize(width: 600, height: 630)) : nil,
            avatar: CaptureTestImages.avatar(CGSize(width: 60, height: 60))
        )
    }

    /// The Home Screen widget comp (as CaptureWidgetSnapshotTests.home): styled background + overlay, clipped with Retro's
    /// widget corner, on a `color.global.controlRaised` wallpaper.
    private func home(_ presentation: WidgetPresentation, size: CGSize) -> some View {
        ZStack {
            StyledWidgetBackground(presentation: presentation)
            StyledWidgetOverlay(presentation: presentation)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radii.widgetAndroidRadiusWidget, style: .continuous))
        .padding(Tokens.Sizes.globalScreenMargin)
        .background(Tokens.Colors.globalControlRaised)
    }

    private func record(_ presentation: WidgetPresentation, size: CGSize, surface: String, state: String, appearances: [ColorScheme] = [.light]) {
        let margin = Tokens.Sizes.globalScreenMargin * 2
        let url = CaptureSnapshot.record(home(presentation, size: size), surface: surface, state: state, appearances: appearances,
                                         layout: .fixed(width: size.width + margin, height: size.height + margin))
        XCTAssertNotNil(url)
    }

    func testFriendWidgetFamiliesAndStates() {
        for (family, frame) in families {
            let surface = "widget.friend.\(family)"
            record(WidgetPresentation(content: content(.photo)), size: frame, surface: surface, state: "photo", appearances: CaptureSnapshot.both)
            record(WidgetPresentation(content: .loading), size: frame, surface: surface, state: "loading")
            record(WidgetPresentation(content: GroupWidgetContent(state: .empty), stateLine: Copy.widgetFriendEmptyNoPhotos), size: frame, surface: surface, state: "empty")
            record(WidgetPresentation(content: GroupWidgetContent(state: .notSetUp), stateLine: Copy.widgetFriendEmptySetUp), size: frame, surface: surface, state: "not-set-up")
            record(WidgetPresentation(content: GroupWidgetContent(state: .signedOut)), size: frame, surface: surface, state: "signed-out")
        }
    }

    func testMemoriesWidgetFamiliesAndStates() {
        for (family, frame) in families {
            let surface = "widget.memories.\(family)"
            record(WidgetPresentation(content: content(.photo, scene: 6)), size: frame, surface: surface, state: "photo", appearances: CaptureSnapshot.both)
            record(WidgetPresentation(content: GroupWidgetContent(state: .empty), stateLine: Copy.widgetMemoriesEmptyNone), size: frame, surface: surface, state: "empty")
            record(WidgetPresentation(content: .loading), size: frame, surface: surface, state: "loading")
        }
    }

    func testStylesAtEverySize() {
        for (family, frame) in families {
            let surface = "widget.styles.\(family)"
            record(WidgetPresentation(content: content(.photo), style: .date), size: frame, surface: surface, state: "date", appearances: CaptureSnapshot.both)
            record(WidgetPresentation(content: content(.photo), style: .frame), size: frame, surface: surface, state: "frame", appearances: CaptureSnapshot.both)
            record(WidgetPresentation(content: GroupWidgetContent(state: .empty), style: .frame), size: frame, surface: surface, state: "frame-empty")
        }
        let small = families[0].1
        let long = GroupWidgetContent(state: .photo, groupName: "Saturday Morning Climbing Crew", senderName: "Maximiliana",
                                      postedAt: CaptureTestRig.fixedNow, photo: CaptureTestImages.scene(5, CGSize(width: 600, height: 630)))
        record(WidgetPresentation(content: long, style: .date), size: small, surface: "widget.styles.small", state: "date-long-names")
    }
}
