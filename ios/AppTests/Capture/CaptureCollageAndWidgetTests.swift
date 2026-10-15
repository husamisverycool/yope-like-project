// collage.view / collage.share view model, the widgets' entry resolution and content
// (widget.home.*, widget.lock.*, camera.fromwidget), and the notification presentation
// (notifications.push, daily.notification). The widget and NSE sources are compiled into this
// bundle through ios/AppTests/Capture/Linked/.
@testable import App
import AppData
import AppModels
import DesignSystem
import UserNotifications
import XCTest

@MainActor
final class CaptureCollageModelTests: XCTestCase {
    private func collage(pages: Int = 2, status: RenderStatus = .ready, version: String = "v1", share: Bool = true) -> Collage {
        let folder = "g/g1/collages/c1/\(version)"
        return Collage(
            id: CollageID("c1"), groupID: GroupID("g1"), invitationID: InvitationID("inv-1"), option: "B",
            postIDs: [PostID("p1"), PostID("p2")], pageCount: pages,
            imagePath: status == .ready ? "\(folder)/display-1.jpg" : nil,
            widgetPath: nil,
            sharePath: share && status == .ready ? "\(folder)/share-1.jpg" : nil,
            status: status, composedAt: Date(), createdAt: Date()
        )
    }

    func testReadyShowsFirstPageThenPrefetchesNext() async {
        let rig = CaptureTestRig()
        rig.openInvitation(closingIn: -60)
        rig.collages.collage = collage()
        rig.collages.images = [
            "g/g1/collages/c1/v1/display-1.jpg": CaptureTestImages.photo(hue: 0.1),
            "g/g1/collages/c1/v1/display-2.jpg": CaptureTestImages.photo(hue: 0.3),
        ]
        let model = rig.collageModel()
        XCTAssertEqual(model.state, .idle)
        await model.load()
        XCTAssertEqual(model.state, .ready)
        XCTAssertEqual(model.pageCount, 2)
        XCTAssertNotNil(model.pages[1])
        XCTAssertNotNil(model.pages[2], "the next page is prefetched")
        XCTAssertTrue(model.title.hasPrefix("26"), "the invitation's local date, 'd Month'")
        XCTAssertTrue(model.canShare)
        XCTAssertEqual(model.shareItem()?.path, "g/g1/collages/c1/v1/share-1.jpg")
        model.currentPage = 2
        XCTAssertEqual(model.shareItem()?.path, "g/g1/collages/c1/v1/share-2.jpg", "shares the current page")
    }

    func testNoCollageIsEmptyAndOpensCamera() async {
        let rig = CaptureTestRig()
        let model = rig.collageModel()
        await model.load()
        XCTAssertEqual(model.state, .empty)
        model.openCamera()
        XCTAssertEqual(rig.navigation.openedCameraGroups, [CaptureFakes.groups[0].id])
    }

    func testPendingIsLoadingAndFailedIsError() async {
        let rig = CaptureTestRig()
        rig.collages.collage = collage(status: .pending)
        let pending = rig.collageModel()
        await pending.load()
        XCTAssertEqual(pending.state, .loading)
        XCTAssertFalse(pending.canShare, "the pill is hidden until the share image exists")

        rig.collages.collage = collage(status: .failed)
        let failed = rig.collageModel()
        await failed.load()
        XCTAssertEqual(failed.state, .error)
    }

    func testOfflineShowsCachedPagesWithoutLoadingFrame() async {
        let rig = CaptureTestRig()
        let cached = collage(pages: 1)
        rig.collages.cached = cached
        rig.collages.cachedImages = ["g/g1/collages/c1/v1/display-1.jpg": CaptureTestImages.photo()]
        rig.collages.error = DataError.offline
        rig.collages.isOffline = true
        let model = rig.collageModel()
        var states: [CollageModel.State] = [model.state]
        let task = Task { await model.load() }
        while !(states.last == .ready) {
            await Task.yield()
            if states.last != model.state { states.append(model.state) }
        }
        await task.value
        XCTAssertEqual(states, [.idle, .ready], "cached pages first; no HUD or empty frame in between")
        XCTAssertEqual(model.state, .ready)
    }

    func testOfflineWithoutCache() async {
        let rig = CaptureTestRig()
        rig.collages.error = DataError.offline
        let model = rig.collageModel()
        await model.load()
        XCTAssertEqual(model.state, .offline)
    }

    func testRecomposeKeepsPreviousPagesUntilNewOnesArrive() async {
        let rig = CaptureTestRig()
        rig.collages.cached = collage(pages: 1, version: "v1")
        let old = CaptureTestImages.photo(hue: 0.1)
        rig.collages.cachedImages = ["g/g1/collages/c1/v1/display-1.jpg": old]
        rig.collages.collage = collage(pages: 1, status: .pending)
        let model = rig.collageModel()
        await model.load()
        XCTAssertEqual(model.state, .ready, "recomposing: the previous pages stay")
        XCTAssertTrue(model.pages[1] === old)

        let new = CaptureTestImages.photo(hue: 0.5)
        rig.collages.collage = collage(pages: 1, version: "v2")
        rig.collages.images = ["g/g1/collages/c1/v2/display-1.jpg": new]
        await model.reload()
        XCTAssertEqual(model.state, .ready)
        XCTAssertTrue(model.pages[1] === new, "swapped once the new page was decoded")
    }
}

final class CaptureWidgetEntryTests: XCTestCase {
    private var directory: URL!
    private var store: WidgetStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        store = WidgetStore.resolve(appGroupIdentifier: nil, fallbackDirectory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func savePhoto(groupID: String, kind: WidgetSnapshot.Kind = .photo, caption: String? = nil, avatar: Bool = false, at seconds: TimeInterval = 1_000) throws {
        let file = "\(kind.rawValue)-\(Int(seconds)).jpg"
        try store.writeFile(CaptureTestImages.jpeg(), groupID: groupID, fileName: file)
        var avatarFile: String?
        if avatar {
            avatarFile = "avatar-\(Int(seconds)).jpg"
            try store.writeFile(CaptureTestImages.jpeg(CGSize(width: 40, height: 40), hue: 0.7), groupID: groupID, fileName: avatarFile!)
        }
        try store.save(WidgetSnapshot(groupID: groupID, sourceID: "p\(Int(seconds))", photoFileName: file, senderDisplayName: "Ana",
                                      senderAvatarFileName: avatarFile, caption: caption, kind: kind, postedAt: Date(timeIntervalSince1970: seconds)))
    }

    func testNoGroupsIsNotSetUp() {
        let entry = GroupWidgetEntryResolver.entry(configuredGroupID: nil, store: store, at: Date())
        XCTAssertEqual(entry.state, .notSetUp)
        XCTAssertEqual(entry.content.emptyText, Copy.widgetHomeSmallEmptySetUp)
        XCTAssertEqual(entry.tapURL?.absoluteString, "app://camera", "tap still opens the camera")
    }

    func testLeftGroupIsNotSetUp() throws {
        try store.syncGroups([WidgetGroup(id: "g1", name: "Family")])
        let entry = GroupWidgetEntryResolver.entry(configuredGroupID: "gone", store: store, at: Date())
        XCTAssertEqual(entry.state, .notSetUp)
    }

    func testConfiguredGroupWithoutPhotoIsEmptyAndTapsIntoItsCamera() throws {
        try store.syncGroups([WidgetGroup(id: "g1", name: "Family")])
        let entry = GroupWidgetEntryResolver.entry(configuredGroupID: "g1", store: store, at: Date())
        XCTAssertEqual(entry.state, .empty)
        XCTAssertEqual(entry.content.emptyText, Copy.widgetHomeSmallEmptyNoPhotos)
        XCTAssertEqual(entry.tapURL?.absoluteString, "app://camera?group=g1")
    }

    func testNewestPhotoWithCaptionAndAvatar() throws {
        try store.syncGroups([WidgetGroup(id: "g1", name: "Family")])
        try savePhoto(groupID: "g1", caption: "Sundays", avatar: true)
        let entry = GroupWidgetEntryResolver.entry(configuredGroupID: "g1", store: store, at: Date())
        XCTAssertEqual(entry.state, .photo)
        let content = entry.content
        XCTAssertNotNil(content.photo)
        XCTAssertNotNil(content.avatar)
        XCTAssertEqual(content.groupName, "Family", "named from the group list when the push had no name")
        XCTAssertEqual(content.accessibilityLabel, Copy.widgetHomeSmallA11yPhotoWithCaption(name: "Ana", group: "Family", caption: "Sundays"))
    }

    func testCollageNewerThanPhotoWins() throws {
        try store.syncGroups([WidgetGroup(id: "g1", name: "Family")])
        try savePhoto(groupID: "g1", at: 1_000)
        try savePhoto(groupID: "g1", kind: .collage, at: 2_000)
        let entry = GroupWidgetEntryResolver.entry(configuredGroupID: "g1", store: store, at: Date())
        XCTAssertEqual(entry.state, .collage)
        XCTAssertTrue(entry.content.accessibilityLabel.contains("Family"))
    }

    func testUnconfiguredUsesNewestAcrossGroups() throws {
        try store.syncGroups([WidgetGroup(id: "g1", name: "Family"), WidgetGroup(id: "g2", name: "Roommates")])
        try savePhoto(groupID: "g1", at: 1_000)
        try savePhoto(groupID: "g2", at: 3_000)
        let entry = GroupWidgetEntryResolver.entry(configuredGroupID: nil, store: store, at: Date())
        XCTAssertEqual(entry.groupID, "g2")
        XCTAssertEqual(entry.tapURL?.absoluteString, "app://camera?group=g2")
    }

    func testLockScreenKeepsNewestSinglePhotoWhenACollageIsNewer() throws {
        try store.syncGroups([WidgetGroup(id: "g1", name: "Family")])
        try savePhoto(groupID: "g1", caption: "Sundays", avatar: true, at: 1_000)
        try savePhoto(groupID: "g1", kind: .collage, at: 2_000)
        let entry = GroupWidgetEntryResolver.lockScreenEntry(configuredGroupID: "g1", store: store, at: Date())
        XCTAssertEqual(entry.state, .photo, "widget.lock.rect.layout.content: the newest single photo's sender")
        XCTAssertEqual(entry.snapshot?.caption, "Sundays")
        XCTAssertNotNil(entry.content.avatar)
        XCTAssertEqual(GroupWidgetEntryResolver.entry(configuredGroupID: "g1", store: store, at: Date()).state, .collage,
                       "the Home Screen still shows the collage")
    }

    func testLockScreenWithoutPhotoIsEmptyAndWithoutGroupNotSetUp() throws {
        XCTAssertEqual(GroupWidgetEntryResolver.lockScreenEntry(configuredGroupID: nil, store: store, at: Date()).state, .notSetUp)
        try store.syncGroups([WidgetGroup(id: "g1", name: "Family")])
        try savePhoto(groupID: "g1", kind: .collage)
        XCTAssertEqual(GroupWidgetEntryResolver.lockScreenEntry(configuredGroupID: "g1", store: store, at: Date()).state, .empty)
    }

    func testInlineWithoutCaptionReadsThePhotoSentence() {
        let content = GroupWidgetContent(state: .photo, groupName: "Family", senderName: "Ana")
        XCTAssertEqual(WidgetInlineSlot(content: content).line, Copy.widgetHomeSmallA11yPhoto(name: "Ana", group: "Family"))
        let captioned = GroupWidgetContent(state: .photo, groupName: "Family", senderName: "Ana", caption: "Sundays")
        XCTAssertEqual(WidgetInlineSlot(content: captioned).line, "Sundays")
    }

    func testNoCountsInAnyLabel() throws {
        try store.syncGroups([WidgetGroup(id: "g1", name: "Family")])
        try savePhoto(groupID: "g1")
        let label = GroupWidgetEntryResolver.entry(configuredGroupID: "g1", store: store, at: Date()).content.accessibilityLabel
        XCTAssertFalse(label.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) })
    }
}

final class CaptureNotificationPresentationTests: XCTestCase {
    func testDailyInvitationIsNeverTimeSensitiveAndThreadsByGroup() {
        let content = UNMutableNotificationContent()
        content.userInfo = [PushKey.type: PushType.dailyInvitation.rawValue, PushKey.groupID: "g1", PushKey.invitationID: "i1"]
        content.interruptionLevel = .timeSensitive
        NotificationPresentation.apply(to: content)
        XCTAssertEqual(content.interruptionLevel, .active)
        XCTAssertEqual(content.threadIdentifier, "g1")
        XCTAssertEqual(content.categoryIdentifier, PushType.dailyInvitation.rawValue)
    }

    func testPassiveStaysPassiveAndExistingThreadKept() {
        let content = UNMutableNotificationContent()
        content.userInfo = [PushKey.type: PushType.newPost.rawValue, PushKey.groupID: "g1"]
        content.interruptionLevel = .passive
        content.threadIdentifier = "server-thread"
        NotificationPresentation.apply(to: content)
        XCTAssertEqual(content.interruptionLevel, .passive, "quiet hours")
        XCTAssertEqual(content.threadIdentifier, "server-thread")
    }

    func testWidgetKindsIncludeLockScreen() {
        XCTAssertEqual(NotificationPresentation.widgetKinds, GroupWidgetKinds.all)
    }
}
