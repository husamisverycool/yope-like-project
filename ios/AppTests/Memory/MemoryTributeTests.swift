// birthday.tribute — view-model tests: who can see the video, and when.
@testable import App
import AppData
import AppModels
import AppServices
import DesignSystem
import XCTest

@MainActor
final class MemoryTributeTests: XCTestCase {
    private func tributeContext(honoree: UserID, deliveredAt: Date?, status: RenderStatus = .ready) -> MemoryTestContext {
        MemoryTestContext { state in
            state.tributes = state.tributes.map { tribute in
                var tribute = tribute
                tribute.honoreeID = honoree
                tribute.deliveredAt = deliveredAt
                tribute.status = status
                if status != .ready { tribute.videoPath = nil }
                return tribute
            }
        }
    }

    func testVisibilityRule() {
        let now = MemoryTestContext.referenceNow
        let tribute = Tribute(
            id: MemoryIDs.tribute, requestID: TributeRequestID("00000000-0000-4000-8000-0000000000c9"), groupID: MemoryIDs.group,
            honoreeID: MemoryIDs.me, videoPath: "v", posterPath: nil, status: .ready, renderedAt: now, deliveredAt: nil, createdAt: now
        )
        XCTAssertFalse(TributeModel.isVisible(tribute, to: MemoryIDs.me, now: now), "honoree, not delivered")
        XCTAssertTrue(TributeModel.isVisible(tribute, to: MemoryIDs.friend, now: now), "members: any time")
        var delivered = tribute
        delivered.deliveredAt = now.addingTimeInterval(60)
        XCTAssertFalse(TributeModel.isVisible(delivered, to: MemoryIDs.me, now: now), "honoree, delivery still ahead")
        delivered.deliveredAt = now.addingTimeInterval(-60)
        XCTAssertTrue(TributeModel.isVisible(delivered, to: MemoryIDs.me, now: now), "honoree, delivered")
    }

    func testHonoreeBeforeDeliverySeesNothing() async {
        let context = tributeContext(honoree: MemoryIDs.me, deliveredAt: nil)
        let model = TributeModel(tributeID: MemoryIDs.tribute, dependencies: context.dependencies, saveVideo: { _ in })
        await model.loadIfNeeded()
        XCTAssertEqual(model.phase, .notFound)
        XCTAssertNil(model.videoURL)
        XCTAssertEqual(context.data.calls(of: .signedURLs), 0, "no file URL is even asked for")
    }

    func testHonoreeAfterDeliveryGetsThePreparedPlayer() async {
        let context = tributeContext(honoree: MemoryIDs.me, deliveredAt: MemoryTestContext.referenceNow.addingTimeInterval(-3600))
        let model = TributeModel(tributeID: MemoryIDs.tribute, dependencies: context.dependencies, saveVideo: { _ in })
        await model.loadIfNeeded()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.groupName, "Sunday dinners")
        XCTAssertEqual(model.title, Copy.birthdayTributeTitle, "the honoree: \"Your birthday video\"")
        XCTAssertNotNil(model.videoURL)
        XCTAssertNotNil(model.posterURL)
        XCTAssertNotNil(model.player, "prepared as soon as the URL is known")
        XCTAssertNotNil(model.localFile)
        XCTAssertTrue(model.canUseFile)
    }

    func testMembersCanWatchBeforeDelivery() async {
        let context = tributeContext(honoree: MemoryIDs.friend, deliveredAt: nil)
        let model = TributeModel(tributeID: MemoryIDs.tribute, dependencies: context.dependencies, saveVideo: { _ in })
        await model.loadIfNeeded()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.title, Copy.birthdayTributeTitleMember(name: "Bea"), "members see the honoree's name")
        XCTAssertFalse(model.offersExport, "save and Share are the honoree's (owner decision 12)")
        XCTAssertNil(model.localFile, "no file is downloaded for a member")
        XCTAssertFalse(model.canUseFile)
        XCTAssertEqual(context.data.calls(of: .downloadFile), 0)
    }

    func testRenderingFailedDeletedAndOffline() async {
        let pending = tributeContext(honoree: MemoryIDs.friend, deliveredAt: nil, status: .pending)
        let pendingModel = TributeModel(tributeID: MemoryIDs.tribute, dependencies: pending.dependencies, saveVideo: { _ in })
        await pendingModel.loadIfNeeded()
        XCTAssertEqual(pendingModel.phase, .rendering)
        XCTAssertFalse(pendingModel.canUseFile, "buttons disabled while (re)rendering")
        pending.data.update { state in
            state.tributes = state.tributes.map { tribute in
                var tribute = tribute
                tribute.status = .ready
                tribute.videoPath = "g/v.mp4"
                return tribute
            }
        }
        await pendingModel.refreshIfRendering()
        XCTAssertEqual(pendingModel.phase, .ready)

        let failed = tributeContext(honoree: MemoryIDs.friend, deliveredAt: nil, status: .failed)
        let failedModel = TributeModel(tributeID: MemoryIDs.tribute, dependencies: failed.dependencies, saveVideo: { _ in })
        await failedModel.loadIfNeeded()
        XCTAssertEqual(failedModel.phase, .error)

        let deleted = MemoryTestContext { $0.tributes = [] }
        let deletedModel = TributeModel(tributeID: MemoryIDs.tribute, dependencies: deleted.dependencies, saveVideo: { _ in })
        await deletedModel.loadIfNeeded()
        XCTAssertEqual(deletedModel.phase, .notFound)

        let offline = MemoryTestContext()
        offline.data.fail(.tribute, with: .offline)
        let offlineModel = TributeModel(tributeID: MemoryIDs.tribute, dependencies: offline.dependencies, saveVideo: { _ in })
        await offlineModel.loadIfNeeded()
        XCTAssertEqual(offlineModel.phase, .offline)
    }

    func testSaveSavesAndSaysSo() async {
        let context = MemoryTestContext()
        let model = TributeModel(tributeID: MemoryIDs.tribute, dependencies: context.dependencies, saveVideo: { _ in })
        await model.loadIfNeeded()
        await model.download()
        XCTAssertEqual(context.lastToast, Copy.birthdayTributeSaved)
        XCTAssertEqual(context.haptics, [Tokens.Haptics.globalSuccess])

        struct Broken: Error {}
        let failing = MemoryTestContext()
        let failingModel = TributeModel(tributeID: MemoryIDs.tribute, dependencies: failing.dependencies, saveVideo: { _ in throw Broken() })
        await failingModel.loadIfNeeded()
        await failingModel.download()
        XCTAssertEqual(failing.lastToast, Copy.birthdayTributeSaveFailed)
        XCTAssertFalse(failingModel.showsSaveDenied)
        XCTAssertEqual(failing.haptics, [Tokens.Haptics.globalError])

        let denied = MemoryTestContext()
        let deniedModel = TributeModel(
            tributeID: MemoryIDs.tribute, dependencies: denied.dependencies,
            saveVideo: { _ in throw PhotoLibraryService.LibraryError.notAuthorized(.denied) }
        )
        await deniedModel.loadIfNeeded()
        await deniedModel.download()
        XCTAssertTrue(deniedModel.showsSaveDenied, "photo access denied: the native alert with the Settings button")
    }
}
