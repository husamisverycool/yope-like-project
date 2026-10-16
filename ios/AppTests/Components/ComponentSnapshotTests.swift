// One snapshot per component (design/components.md C-01…C-35) per state, in the light AND the dark appearance, recorded
// into ios/build/snapshots/components/<test>.<cNN-component-state>-<light|dark>.png for the Pass 5 design review (each
// component next to its Retro evidence). Photos and avatars are the real sample photos in fixtures/photos/
// (`SamplePhotos`). Strings are fixtures (the components take every string from their caller's copy).
@testable import App
import DesignSystem
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@MainActor
final class ComponentSnapshotTests: XCTestCase {
    // MARK: Fixtures

    /// The iPhone 13 point width the snapshots are laid out in.
    private let width: CGFloat = 390

    private enum Surface {
        case page
        case media
    }

    private func photo(_ index: Int, _ orientation: SamplePhotos.Orientation = .portrait) -> PhotoSource {
        .image(SamplePhotos.photo(index: index, orientation: orientation))
    }

    private func avatar(_ index: Int) -> PhotoSource {
        .image(SamplePhotos.image(named: SamplePhotos.avatarName(index: index)))
    }

    /// Noon on the given day (local time zone), so tile dates never cross midnight.
    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let calendar = Calendar(identifier: .iso8601)
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date(timeIntervalSince1970: 0)
    }

    /// Records `view` in the light and the dark appearance as `<name>-light` / `<name>-dark`, `width` wide on the page
    /// (`color.global.background`) or a media surface (`color.global.backgroundDeep`).
    private func record<V: View>(
        _ name: String,
        surface: Surface = .page,
        height: CGFloat? = nil,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        @ViewBuilder _ view: () -> V
    ) {
        for scheme in [ColorScheme.light, ColorScheme.dark] {
            let hosted = view()
                .frame(width: width, height: height, alignment: .top)
                .background(surface == .media ? Tokens.Colors.globalBackgroundDeep : Tokens.Colors.globalBackground)
                .environment(\.colorScheme, scheme)
                .preferredColorScheme(scheme)
            let suffix = scheme == .dark ? "dark" : "light"
            let url = SnapshotRecorder.record(
                hosted,
                named: "\(name)-\(suffix)",
                group: "components",
                layout: .sizeThatFits,
                file: file,
                testName: testName,
                line: line
            )
            XCTAssertNotNil(url, "\(name)-\(suffix) not written", file: file, line: line)
        }
    }

    // MARK: C-01 … C-03 headers

    func testC01ScreenHeader() {
        record("c01-header-root") {
            ScreenHeader(title: "Week 43", actions: [
                HeaderAction(icon: Tokens.Icons.globalAlbums, accessibilityLabel: "Albums") {},
                HeaderAction(icon: Tokens.Icons.globalChats, accessibilityLabel: "Messages") {},
            ])
        }
        record("c01-header-root-relative-week") {
            ScreenHeader(title: "Week 19", actions: [HeaderAction(icon: Tokens.Icons.globalChats, accessibilityLabel: "Messages") {}]) {
                RelativeWeekPill(label: "Last Week")
            }
        }
        record("c01-header-root-long-title") {
            ScreenHeader(title: "Sunday dinners at the lake house", actions: [HeaderAction(icon: Tokens.Icons.globalNewAlbum, accessibilityLabel: "New album") {}])
        }
    }

    func testC02PushedHeader() {
        record("c02-header-pushed") {
            PushedScreenHeader(title: "Albums", backAccessibilityLabel: "Back", actions: [
                HeaderAction(icon: Tokens.Icons.globalNewAlbum, accessibilityLabel: "New album") {},
            ]) {}
        }
        record("c02-header-pushed-search") {
            VStack(spacing: 0) {
                PushedScreenHeader(title: "Friends", backAccessibilityLabel: "Back") {}
                SearchField("Search", text: .constant(""), accessibilityLabel: "Search friends")
                    .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            }
        }
    }

    func testC03RelativeWeekPill() {
        record("c03-relative-week-pill") {
            RelativeWeekPill(label: "Last Week").padding()
        }
    }

    // MARK: C-04 tab bar

    func testC04TabBar() {
        record("c04-tabbar-page") {
            AppTabBar(selected: .groups, unread: [.walls], unreadValue: "new activity") { _ in }
        }
        record("c04-tabbar-page-profile-selected") {
            AppTabBar(selected: .me) { _ in }
        }
        record("c04-tabbar-media", surface: .media) {
            AppTabBar(selected: .camera, surface: .media) { _ in }
        }
        record("c04-tabbar-over-photo", surface: .media) {
            AppTabBar(selected: .groups, unread: [.me], unreadValue: "new activity", surface: .overPhoto) { _ in }
                .padding(.top, Tokens.Sizes.globalStripTileHeight)
                .background {
                    PhotoView(source: photo(3, .landscape))
                        .overlay { PhotoScrim() }
                }
        }
    }

    // MARK: C-05 … C-10 buttons

    func testC05PrimaryButton() {
        record("c05-primary-enabled") {
            PrimaryButton("Get started") {}.padding(.horizontal, Tokens.Sizes.globalButtonMarginH).padding(.vertical)
        }
        record("c05-primary-disabled") {
            PrimaryButton("Get started", isEnabled: false) {}.padding(.horizontal, Tokens.Sizes.globalButtonMarginH).padding(.vertical)
        }
        record("c05-primary-busy") {
            PrimaryButton("Get started", isBusy: true) {}.padding(.horizontal, Tokens.Sizes.globalButtonMarginH).padding(.vertical)
        }
        record("c05-primary-media", surface: .media) {
            PrimaryButton("Send Postcard", surface: .media) {}.padding(.horizontal, Tokens.Sizes.globalButtonMarginH).padding(.vertical)
        }
    }

    func testC06CapsuleButtons() {
        record("c06-capsules-profile-row") {
            CapsuleRow {
                CapsuleButton("Recaps", fillsWidth: true) {}
                CapsuleButton("Share Profile", fillsWidth: true) {}
                CapsuleButton(icon: Tokens.Icons.globalSettings, accessibilityLabel: "Settings") {}
            }
            .padding()
        }
        record("c06-capsules-request-row") {
            CapsuleRow {
                CapsuleButton("Accept", style: .primary, fillsWidth: true) {}
                CapsuleButton("Decide Later", style: .outline, fillsWidth: true) {}
            }
            .padding()
        }
        record("c06-capsules-fill-and-disabled") {
            HStack {
                CapsuleButton("Create", style: .fill) {}
                CapsuleButton("Create", style: .fill, isEnabled: false) {}
                CapsuleButton("Accept", style: .primary, isEnabled: false) {}
                CapsuleButton("Share", style: .outline, isEnabled: false) {}
            }
            .padding()
        }
        record("c06-capsule-toggle") {
            HStack {
                CapsuleToggle(title: "I'm in", isOn: .constant(false))
                CapsuleToggle(title: "I'm in", isOn: .constant(true))
            }
            .padding()
        }
    }

    func testC07OutlineCTA() {
        record("c07-outline-cta") {
            OutlineCTA("Get this week started") {}.padding()
        }
    }

    func testC08TextButtons() {
        record("c08-text-buttons") {
            VStack {
                TextButton("Invite") {}
                TextButton("already have an account?", style: .link) {}
            }
            .padding()
        }
    }

    func testC09LightPills() {
        record("c09-light-pills-on-photo", surface: .media) {
            ZStack {
                PhotoView(source: photo(5))
                VStack {
                    LightPill("Share") {}
                    LightPill("Add a message", icon: Tokens.Icons.globalEdit, style: .dark) {}
                }
            }
            .frame(height: Tokens.Sizes.globalFriendCardHeight)
        }
    }

    func testC10DestructiveButton() {
        record("c10-destructive") {
            VStack(alignment: .leading) {
                DestructiveButton("Delete Account") {}
                DestructiveButton("Delete from Photos", icon: Tokens.Icons.globalTrash) {}
            }
            .padding()
        }
    }

    // MARK: C-11 circles

    func testC11CircleButtons() {
        record("c11-circles-page") {
            HStack {
                CircleButton(icon: Tokens.Icons.globalAdd, accessibilityLabel: "Add") {}
                CircleButton(icon: Tokens.Icons.globalClose, accessibilityLabel: "Close") {}
                HeaderIconButton(icon: Tokens.Icons.globalChats, accessibilityLabel: "Messages") {}
            }
            .padding()
        }
        record("c11-circles-media-and-glass", surface: .media) {
            ZStack {
                PhotoView(source: photo(8, .landscape))
                HStack {
                    CircleButton(icon: Tokens.Icons.globalClose, accessibilityLabel: "Close", style: .media) {}
                    CircleButton(icon: Tokens.Icons.globalMore, accessibilityLabel: "More", style: .glass) {}
                    CircleButton(icon: Tokens.Icons.globalShare, accessibilityLabel: "Share", style: .glassLarge) {}
                    CircleButton(icon: Tokens.Icons.globalClose, accessibilityLabel: "Close", style: .glassSmall) {}
                }
            }
            .frame(height: Tokens.Sizes.globalFriendCardWidth)
        }
    }

    // MARK: C-12 … C-14 fields and rows

    func testC12Fields() {
        record("c12-field-placeholder") {
            FormField("Your name", text: .constant(""), accessibilityLabel: "Name").padding()
        }
        record("c12-field-filled") {
            FormField("Your name", text: .constant("Ana Lima"), accessibilityLabel: "Name").padding()
        }
        record("c12-field-error") {
            FormField("Your name", text: .constant("Ana Lima Costa Ferreira"), accessibilityLabel: "Name", errorMessage: "Name too long").padding()
        }
        record("c12-search-field") {
            SearchField("Search", text: .constant(""), accessibilityLabel: "Search").padding()
        }
    }

    func testC13ReplyBar() {
        record("c13-reply-bar-media-empty", surface: .media) {
            ReplyBar(
                text: .constant(""), placeholder: "Add a comment…", accessibilityLabel: "Comment", avatar: avatar(1),
                sendLabel: "Send", onSend: {}, moreLabel: "More", onMore: {}
            )
            .padding(.vertical)
        }
        record("c13-reply-bar-media-text", surface: .media) {
            ReplyBar(text: .constant("so good"), placeholder: "Add a comment…", accessibilityLabel: "Comment", avatar: avatar(1), sendLabel: "Send", onSend: {})
                .padding(.vertical)
        }
        record("c13-reply-bar-page") {
            ReplyBar(
                text: .constant(""), placeholder: "Message", accessibilityLabel: "Message", avatar: avatar(2), surface: .page,
                sendLabel: "Send", onSend: {}
            )
            .padding(.vertical)
        }
    }

    func testC14GroupedSection() {
        record("c14-grouped-section") {
            VStack {
                GroupedSection(header: "Account", rows: [
                    GroupedRow("Name", subtitle: "Ana Lima") {},
                    GroupedRow("Birthday", subtitle: "Shown to your groups") {},
                    GroupedRow("Notifications", accessory: .toggle(.constant(true))),
                ])
                GroupedSection(rows: [GroupedRow("Delete Account", icon: Tokens.Icons.globalTrash, accessory: .none, role: .destructive) {}])
            }
            .padding(.vertical)
        }
    }

    // MARK: C-15 … C-16 rows

    func testC15ThumbnailRows() {
        let avatars = (1...4).map { avatar($0) }
        record("c15-thumbnail-rows") {
            ThumbnailRowList {
                ThumbnailRow(
                    title: "Mexico City", subtitle: "daniel shared new photos", subtitleEmphasis: "daniel", thumbnail: photo(1),
                    avatars: avatars, accessibilityLabel: "Mexico City", addAccessibilityLabel: "Add photos", onAdd: {}
                ) {}
                ThumbnailRow(title: "Sunday dinners", subtitle: "Ana added photos", subtitleEmphasis: "Ana", thumbnail: photo(4), accessibilityLabel: "Sunday dinners") {}
                ThumbnailRow(title: "No cover yet", thumbnail: nil, accessibilityLabel: "No cover yet") {}
            }
            .padding(.vertical)
        }
    }

    func testC16PeopleAndCommentRows() {
        record("c16-people-rows") {
            VStack {
                PeopleRow(name: "olson", line: "wants to be friends", avatar: avatar(3), unreadValue: "new") {
                    CapsuleRow {
                        CapsuleButton("Accept", style: .primary) {}
                        CapsuleButton("Later") {}
                    }
                }
                PeopleRow(name: "Rui Costa", line: "Member", avatar: avatar(6))
                PeopleRow(name: "No photo", avatar: nil)
            }
            .padding(.vertical)
        }
        record("c16-comment-rows-media", surface: .media) {
            VStack {
                CommentRow(name: "elton", time: "2h", text: "this is the best one", avatar: avatar(4))
                CommentRow(name: "Ana", time: "1d", text: "a longer comment that wraps onto a second line of the row", avatar: avatar(1))
            }
            .padding(.vertical)
        }
        record("c16-comment-rows-page") {
            CommentRow(name: "elton", time: "2h", text: "this is the best one", avatar: avatar(4), onMedia: false)
                .padding(.vertical)
        }
    }

    // MARK: C-17 week strip

    func testC17WeekStrip() {
        let days = WeekStripLayout.days(ofWeekContaining: day(2026, 10, 14))
        let label: (WeekStripTile) -> String = { $0.id }
        record("c17-strip-empty-current-week") {
            WeekStrip(tiles: WeekStripLayout.tiles(days: days, photos: [], canAdd: true), accessibilityLabel: label)
                .padding(.vertical)
        }
        let photos = (0..<3).map { index in
            WeekStripPhoto(id: "p\(index)", date: days[index], source: photo(index + 10))
        }
        record("c17-strip-photos-then-add") {
            WeekStrip(tiles: WeekStripLayout.tiles(days: days, photos: photos, canAdd: true), accessibilityLabel: label)
                .padding(.vertical)
        }
        let full = (0..<6).map { index in
            WeekStripPhoto(id: "f\(index)", date: days[min(index, days.count - 1)], source: photo(index + 20))
        }
        record("c17-strip-past-week-overflow") {
            WeekStrip(tiles: WeekStripLayout.tiles(days: days, photos: full, canAdd: false), accessibilityLabel: label)
                .padding(.vertical)
        }
        record("c17-strip-loading-placeholders") {
            WeekStrip(tiles: WeekStripLayout.placeholders(count: 4), accessibilityLabel: label)
                .padding(.vertical)
        }
        record("c17-day-tiles") {
            HStack(spacing: Tokens.Sizes.globalStripGap) {
                DayTile(tile: WeekStripTile(id: "p", kind: .photo(photo(2)), date: days[0]))
                DayTile(tile: WeekStripTile(id: "e", kind: .emptyDay, date: days[1]))
                DayTile(tile: WeekStripTile(id: "a", kind: .add, date: nil))
                DayTile(tile: WeekStripTile(id: "l", kind: .placeholder, date: nil))
            }
            .padding()
        }
    }

    // MARK: C-18 … C-21 cards, profile, sections, grids

    func testC18FriendCards() {
        record("c18-friend-cards") {
            FriendCardPager {
                FriendCard(name: "isareyes", avatar: avatar(2), photo: photo(30), newLabel: "new", accessibilityLabel: "isareyes's week, new photos") {}
                FriendCard(name: "olson", avatar: avatar(3), photo: photo(31), accessibilityLabel: "olson's week") {}
            }
            .padding(.vertical)
        }
    }

    func testC19ProfileHeader() {
        record("c19-profile-header") {
            ProfileHeader(
                name: "isareyes",
                realName: "Isabel Reyes",
                avatar: avatar(5),
                avatarAccessibilityLabel: "Isabel Reyes",
                infoRows: [
                    ProfileInfoRow(icon: Tokens.Icons.globalLocation, text: "Prospect Heights, Brooklyn"),
                    ProfileInfoRow(icon: Tokens.Icons.globalCamera, text: "Last photo: Aspen, CO"),
                ]
            ) {
                CapsuleRow {
                    CapsuleButton("Recaps", fillsWidth: true) {}
                    CapsuleButton("Share Profile", fillsWidth: true) {}
                    CapsuleButton(icon: Tokens.Icons.globalSettings, accessibilityLabel: "Settings") {}
                }
            }
            .padding(.vertical)
        }
    }

    func testC20SectionHeaders() {
        let days = WeekStripLayout.days(ofWeekContaining: day(2026, 7, 8))
        let earlier = WeekStripLayout.days(ofWeekContaining: day(2026, 6, 30))
        record("c20-section-header-week") {
            SectionHeader(title: "Week 27", detail: "Jul 3 - 9", moreAccessibilityLabel: "More") {
                Button("Share") {}
            }
            .padding(.vertical)
        }
        record("c20-section-header-dated") {
            SectionHeader(title: "January 25, 2024", moreAccessibilityLabel: "More") {
                Button("Share") {}
            }
            .padding(.vertical)
        }
        record("c20-week-section-list") {
            WeekSectionList {
                WeekStripSection {
                    SectionHeader(title: "Week 28", detail: "Jul 6 - 12", moreAccessibilityLabel: "More") { Button("Share") {} }
                } content: {
                    WeekStrip(
                        tiles: WeekStripLayout.tiles(days: days, photos: (0..<3).map { WeekStripPhoto(id: "a\($0)", date: days[$0], source: self.photo($0 + 40)) }, canAdd: true),
                        accessibilityLabel: { $0.id }
                    )
                }
                WeekStripSection {
                    SectionHeader(title: "Week 27", detail: "Jun 29 - Jul 5", moreAccessibilityLabel: "More") { Button("Share") {} }
                } content: {
                    WeekStrip(
                        tiles: WeekStripLayout.tiles(days: earlier, photos: (0..<5).map { WeekStripPhoto(id: "b\($0)", date: earlier[$0], source: self.photo($0 + 50)) }, canAdd: false),
                        accessibilityLabel: { $0.id }
                    )
                }
            }
            .padding(.vertical)
        }
    }

    func testC21Grids() {
        let items = (0..<7).map { PhotoGridItem(id: "g\($0)", source: photo($0 + 60, $0.isMultiple(of: 2) ? .square : .portrait), accessibilityLabel: "Photo \($0)") }
        record("c21-album-grid-dated") {
            DatedPhotoSection(
                header: SectionHeader(title: "January 25, 2024", moreAccessibilityLabel: "More") { Button("Share") {} },
                grid: PhotoGrid(items: items, columns: 3)
            )
            .padding(.vertical)
        }
        record("c21-picker-grid") {
            PhotoGrid(items: items, columns: 4).padding(.vertical)
        }
        record("c21-people-grid") {
            PeopleGrid(
                people: (1...5).map { PeopleGridItem(id: "u\($0)", name: ["olson", "Ana", "Rui Costa", "isareyes", "Sam"][$0 - 1], avatar: avatar($0)) },
                columns: 3
            )
            .padding(.vertical)
        }
    }

    // MARK: C-22 viewer

    func testC22Viewer() {
        record("c22-viewer-page", surface: .media, height: 844) {
            ViewerPage(
                header: {
                    ViewerHeader(
                        name: "tim", week: "Week 28", avatar: self.avatar(7), position: "3 of 4",
                        closeLabel: "Close", onClose: {}, moreLabel: "More"
                    ) {
                        Button("Save") {}
                        Button("Report", role: .destructive) {}
                    }
                },
                photo: ViewerPhotoFrame(source: photo(3, .landscape), accessibilityLabel: "Photo by tim"),
                footer: {
                    ViewerFooter(location: "Mexico City", date: "Jul 10")
                },
                content: {
                    CommentRow(name: "elton", time: "2h", text: "this is the best one", avatar: self.avatar(4))
                    Spacer(minLength: 0)
                    ReplyBar(
                        text: .constant(""), placeholder: "Add a comment…", accessibilityLabel: "Comment", avatar: self.avatar(1),
                        sendLabel: "Send", onSend: {}, moreLabel: "More", onMore: {}
                    )
                }
            )
        }
        record("c22-viewer-header-footer", surface: .media) {
            VStack {
                ViewerHeader(name: "nathan", week: "Week 49", avatar: avatar(8), closeLabel: "Close", onClose: {})
                ViewerFooter(location: "Barcelona", date: "Aug 2")
            }
            .padding(.vertical)
        }
        record("c22-position-pill", surface: .media) {
            PositionPill(label: "3 of 4").padding()
        }
    }

    // MARK: C-23 … C-25 avatars, badges, pills

    func testC23Avatars() {
        let sizes = [
            Tokens.Sizes.globalAvatarSmall, Tokens.Sizes.globalAvatarList, Tokens.Sizes.globalAvatarComment,
            Tokens.Sizes.globalAvatarPicker, Tokens.Sizes.globalAvatarHeader, Tokens.Sizes.globalAvatarProfile,
            Tokens.Sizes.globalAvatarGrid,
        ]
        record("c23-avatar-sizes") {
            HStack(alignment: .bottom) {
                ForEach(sizes.indices, id: \.self) { index in
                    AvatarView(source: self.avatar(index + 1), diameter: sizes[index])
                }
            }
            .padding()
        }
        record("c23-avatar-no-photo") {
            HStack {
                AvatarView(source: nil, diameter: Tokens.Sizes.globalAvatarPicker)
                AvatarView(source: nil, diameter: Tokens.Sizes.globalAvatarProfile, placeholderIcon: Tokens.Icons.globalGroup)
            }
            .padding()
        }
        record("c23-avatar-stack") {
            VStack(alignment: .leading) {
                AvatarStack(sources: (1...4).map { avatar($0) })
                AvatarStack(sources: (1...9).map { avatar($0) }, maxVisible: 5)
            }
            .padding()
        }
    }

    func testC24Badges() {
        record("c24-new-badge-on-card") {
            PhotoView(source: photo(12))
                .frame(width: Tokens.Sizes.globalFriendCardWidth, height: Tokens.Sizes.globalFriendCardHeight)
                .clipShape(DSShape.rounded(Tokens.Radii.globalCard))
                .newBadge("new")
                .padding()
        }
        record("c24-unread-dot") {
            HStack {
                NewBadge(label: "new")
                UnreadDot()
            }
            .padding()
        }
    }

    func testC25SmallPills() {
        record("c25-small-pills", surface: .media) {
            HStack {
                VideoDurationPill(duration: "1:00")
                PremiumPill(label: "FREE")
            }
            .padding()
        }
    }

    // MARK: C-27 … C-28 states

    func testC27EmptyStates() {
        record("c27-empty-week", height: Tokens.Sizes.globalFriendCardHeight) {
            EmptyStateView(
                icon: Tokens.Icons.globalCalendar,
                title: "Welcome to Week 43!",
                action: EmptyStateView.Action("Get this week started", icon: Tokens.Icons.globalAdd) {}
            )
            .frame(maxHeight: .infinity)
        }
        record("c27-error-retry", height: Tokens.Sizes.globalFriendCardHeight) {
            EmptyStateView(title: "Couldn't load your week", detail: "Check your connection and try again.", action: EmptyStateView.Action("Try Again") {})
                .frame(maxHeight: .infinity)
        }
        record("c27-permission-denied", height: Tokens.Sizes.globalFriendCardHeight) {
            PermissionCard(
                title: Copy.onboardingPermissionPhotosDeniedTitle, detail: Copy.onboardingPermissionPhotosDeniedDetail,
                buttonTitle: Copy.onboardingPermissionPhotosDeniedButton, onEnable: {}, onDismiss: {}, dismissAccessibilityLabel: "Close"
            )
            .frame(maxHeight: .infinity)
        }
    }

    func testC28Loading() {
        record("c28-activity-indicator") {
            LoadingHUD().padding()
        }
        record("c28-progress-line") {
            LoadingHUD(label: "Updating…").padding()
        }
        record("c28-loading-overlay", height: Tokens.Sizes.globalFriendCardWidth) {
            Color.clear.loadingHUD(true)
        }
    }

    // MARK: C-29 … C-32 native, dots, divider

    func testC29Sheets() {
        record("c29-sheet-header") {
            SheetHeader(title: "Postcard", closeAccessibilityLabel: "Close") {}.padding(.vertical)
        }
        record("c29-sheet-toolbar", height: Tokens.Sizes.globalFriendCardWidth) {
            NavigationStack {
                Color.clear.sheetToolbar(title: "Add to Your Week", cancelTitle: "Cancel", onCancel: {}, confirmTitle: "Update", onConfirm: {})
            }
        }
        record("c29-feature-intro") {
            FeatureIntroSheet(
                title: "New! Photo Postcards",
                rows: [
                    FeatureIntroRow(icon: Tokens.Icons.globalEdit, text: "Write a note on the back of any photo."),
                    FeatureIntroRow(icon: Tokens.Icons.globalSend, text: "We print it and mail it for you."),
                ],
                buttonTitle: "Try it"
            ) {}
            .padding(.vertical)
        }
    }

    func testC30SegmentedControl() {
        record("c30-segmented") {
            SegmentedPills(
                options: [SegmentOption(0, title: "Yearly"), SegmentOption(1, title: "Monthly"), SegmentOption(2, title: "Weekly")],
                selection: .constant(1)
            )
            .padding()
        }
    }

    func testC31PageDots() {
        record("c31-page-dots") {
            PageDots(count: 5, index: 1, accessibilityValue: "page 2 of 5").padding()
        }
        record("c31-page-dots-media", surface: .media) {
            PageDots(count: 4, index: 0, onMedia: true, accessibilityValue: "page 1 of 4").padding()
        }
    }

    func testC32Divider() {
        record("c32-divider") {
            HairlineDivider().padding()
        }
    }

    // MARK: C-33 … C-35 pages

    func testC33Onboarding() {
        var finePrint = AttributedString("By continuing, I confirm I've read the Terms and Privacy Policy.")
        if let range = finePrint.range(of: "Terms") { finePrint[range].link = URL(string: "https://example.test/terms") }
        record("c33-landing", height: 700) {
            OnboardingHero(
                line: "Friends Only", primaryTitle: "Get started", onPrimary: {},
                secondaryTitle: "already have an account?", onSecondary: {}, finePrint: finePrint
            ) {
                Glyph(Tokens.Icons.globalAlbums, size: Tokens.Sizes.globalAvatarProfile)
                    .foregroundStyle(Tokens.Colors.globalTextPrimary)
            }
        }
        record("c33-onboarding-title") {
            OnboardingTitleBlock(title: "What should we call you?", subtitle: "Your friends see this name.").padding()
        }
    }

    func testC34BackdropCards() {
        record("c34-plan-card", surface: .media, height: 700) {
            BackdropCard(backdrop: photo(14)) {
                VStack(alignment: .leading) {
                    Text("Premium").dsTextStyle(TextRole.displaySmall)
                    Text("Recaps, postcards and more.").dsTextStyle(TextRole.body)
                    PrimaryButton("Claim") {}
                }
                .foregroundStyle(Tokens.Colors.globalTextPrimary)
            }
        }
        record("c34-recap-card", surface: .media, height: 700) {
            BackdropCard(backdrop: photo(15), cornerRadius: Tokens.Radii.globalThumbnail) {
                VStack(alignment: .leading) {
                    PhotoGrid(items: (0..<6).map { PhotoGridItem(id: "r\($0)", source: self.photo($0 + 16, .square), accessibilityLabel: "") }, columns: 3)
                    Text("2026").dsTextStyle(TextRole.displaySmall).foregroundStyle(Tokens.Colors.globalTextPrimary)
                }
            } below: {
                PageDots(count: 3, index: 0, onMedia: true, accessibilityValue: "page 1 of 3")
                LightPill("Share") {}
            }
        }
    }

    func testC35FullBleedMediaPage() {
        record("c35-full-bleed", surface: .media, height: 844) {
            FullBleedMediaPage(
                photo: photo(2, .story), photoAccessibilityLabel: "Photo from May 1, 2019", title: "May 1, 2019",
                subtitle: "On this week", onTitle: {}, moreAccessibilityLabel: "More",
                leading: MediaCircleAction(icon: Tokens.Icons.globalShare, accessibilityLabel: "Share") {},
                trailing: MediaCircleAction(icon: Tokens.Icons.globalRandom, accessibilityLabel: "Random") {}
            ) {
                Button("Save") {}
            } control: {
                CircleButton(icon: Tokens.Icons.globalPlay, accessibilityLabel: "Play", style: .glassLarge) {}
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AppTabBar(selected: .groups, surface: .overPhoto) { _ in }
            }
        }
    }
}
