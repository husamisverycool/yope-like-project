// Snapshot of every memory screen in every state (docs/SCREENS_BRIEF.md rule 7), written to
// ios/build/snapshots/memory/<surface>-<state>.png for design/verification/<surface>.md.
// Screens run on the fixture backend; photos are flat test images (no reference content).
@testable import App
import AppData
import DesignSystem
import SwiftUI
import UIKit
import XCTest

@MainActor
final class MemorySnapshotTests: XCTestCase {
    // MARK: Helpers

    /// Test images for every storage path of the fixtures, at each photo's own shape.
    private func fillImages(_ context: MemoryTestContext) {
        let palette: [UIColor] = [.systemTeal, .systemOrange, .systemIndigo, .systemPink, .systemGreen, .systemBrown, .systemPurple, .systemYellow]
        func image(index: Int, width: Int, height: Int) -> UIImage {
            let size = CGSize(width: CGFloat(width) * 120, height: CGFloat(height) * 120)
            return UIGraphicsImageRenderer(size: size).image { renderer in
                palette[index % palette.count].setFill()
                renderer.fill(CGRect(origin: .zero, size: size))
                UIColor.white.withAlphaComponent(0.25).setFill()
                renderer.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height / 3))
            }
        }
        let state = context.data.snapshot
        for (index, post) in state.posts.enumerated() {
            guard let media = post.media else { continue }
            for path in [media.originalPath, media.displayPath, media.thumbPath].compactMap({ $0 }) {
                context.images.images[URL(string: "fixture://" + path)!] = image(index: index, width: media.width ?? 1, height: media.height ?? 1)
            }
        }
        for collage in state.collages {
            if let path = collage.imagePath {
                context.images.images[URL(string: "fixture://" + path)!] = image(index: 5, width: 1, height: 1)
            }
        }
        for tribute in state.tributes {
            if let path = tribute.posterPath {
                context.images.images[URL(string: "fixture://" + path)!] = image(index: 2, width: 16, height: 9)
            }
        }
    }

    /// Records `view` as `memory/<surface>-<state>.png`.
    @discardableResult
    private func record<V: View>(
        _ view: V, _ surface: String, _ state: String, context: MemoryTestContext,
        layout: SwiftUISnapshotLayout = .device(config: .iPhone13),
        file: StaticString = #filePath, testName: String = #function, line: UInt = #line
    ) -> URL? {
        let name = surface + "-" + state
        let content = view
            .environment(\.memoryImageLoader, context.images)
            .environment(\.colorScheme, .dark)
        guard let written = SnapshotRecorder.record(content, named: name, group: "memory", layout: layout, file: file, testName: testName, line: line) else {
            XCTFail("snapshot \(name) not written", file: file, line: line)
            return nil
        }
        let target = written.deletingLastPathComponent().appendingPathComponent(name + ".png")
        try? FileManager.default.removeItem(at: target)
        do {
            try FileManager.default.moveItem(at: written, to: target)
        } catch {
            XCTFail("could not name \(name): \(error)", file: file, line: line)
            return nil
        }
        XCTAssertGreaterThan((try? Data(contentsOf: target).count) ?? 0, 0, file: file, line: line)
        return target
    }

    private func context(_ configure: (inout FixtureMemoryData.State) -> Void = { _ in }) -> MemoryTestContext {
        let context = MemoryTestContext(configure: configure)
        fillImages(context)
        return context
    }

    // MARK: onthisday

    func testOnThisDayStates() async {
        let loading = context { $0.suspended = [.onThisDay] }
        record(OnThisDayScreen(groupID: MemoryIDs.group.rawValue, model: OnThisDayModel(groupID: MemoryIDs.group, dependencies: loading.dependencies)),
               "onthisday", "loading", context: loading)

        let loaded = context()
        let model = OnThisDayModel(groupID: MemoryIDs.group, dependencies: loaded.dependencies)
        await model.loadIfNeeded()
        XCTAssertEqual(model.phase, .loaded)
        record(OnThisDayScreen(groupID: MemoryIDs.group.rawValue, model: model), "onthisday", "single", context: loaded)
        model.next()
        record(OnThisDayScreen(groupID: MemoryIDs.group.rawValue, model: model), "onthisday", "grid", context: loaded)

        let failing = context()
        failing.data.fail(.onThisDay, with: .http(status: 500))
        let errorModel = OnThisDayModel(groupID: MemoryIDs.group, dependencies: failing.dependencies)
        await errorModel.loadIfNeeded()
        record(OnThisDayScreen(groupID: MemoryIDs.group.rawValue, model: errorModel), "onthisday", "error", context: failing)

        let offline = context()
        offline.data.fail(.onThisDay, with: .offline)
        let offlineModel = OnThisDayModel(groupID: MemoryIDs.group, dependencies: offline.dependencies)
        await offlineModel.loadIfNeeded()
        record(OnThisDayScreen(groupID: MemoryIDs.group.rawValue, model: offlineModel), "onthisday", "offline", context: offline)

        // The group-screen entry (row look belongs to groups.screen; the plain default row).
        let entryModel = OnThisDayEntryModel(groupID: MemoryIDs.group, dependencies: loaded.dependencies)
        await entryModel.refresh()
        record(OnThisDayEntry(groupID: MemoryIDs.group.rawValue, model: entryModel).padding().background(Tokens.Colors.globalBackground),
               "onthisday", "entry", context: loaded, layout: .fixed(width: 390, height: 120))
    }

    // MARK: birthday.add

    func testBirthdayAddStates() async {
        let entry = BirthdayDateEntry(pattern: "MM/dd/yyyy")
        let loading = context { $0.suspended = [.myPrivateProfile] }
        let loadingModel = BirthdayAddModel(dependencies: loading.dependencies, entry: entry)
        record(BirthdayAddScreen(model: loadingModel), "birthday.add", "loading", context: loading)

        let add = context()
        let addModel = BirthdayAddModel(dependencies: add.dependencies, entry: entry)
        await addModel.loadIfNeeded()
        record(BirthdayAddScreen(model: addModel), "birthday.add", "empty-field", context: add)
        addModel.dateText = "05/26/2000"
        record(BirthdayAddScreen(model: addModel), "birthday.add", "filled", context: add)

        let saving = context { $0.suspended = [.setBirthday] }
        let savingModel = BirthdayAddModel(dependencies: saving.dependencies, entry: entry)
        await savingModel.loadIfNeeded()
        savingModel.dateText = "05/26/2000"
        let task = Task { await savingModel.confirm() }
        _ = await memoryEventually { savingModel.isSaving }
        record(BirthdayAddScreen(model: savingModel), "birthday.add", "saving", context: saving)
        task.cancel()

        let invalid = context()
        let invalidModel = BirthdayAddModel(dependencies: invalid.dependencies, entry: entry)
        await invalidModel.loadIfNeeded()
        invalidModel.dateText = "02/30/2000"
        await invalidModel.confirm()
        record(BirthdayAddScreen(model: invalidModel), "birthday.add", "invalid", context: invalid)

        let failing = context()
        failing.data.fail(.setBirthday, with: .http(status: 500))
        let errorModel = BirthdayAddModel(dependencies: failing.dependencies, entry: entry)
        await errorModel.loadIfNeeded()
        errorModel.dateText = "05/26/2000"
        await errorModel.confirm()
        record(BirthdayAddScreen(model: errorModel), "birthday.add", "error", context: failing)

        let offline = context()
        offline.data.fail(.setBirthday, with: .offline)
        let offlineModel = BirthdayAddModel(dependencies: offline.dependencies, entry: entry)
        await offlineModel.loadIfNeeded()
        offlineModel.dateText = "05/26/2000"
        await offlineModel.confirm()
        record(BirthdayAddScreen(model: offlineModel), "birthday.add", "offline", context: offline)

        let saved = LocalDate(year: 2000, month: 5, day: 26)!
        let manage = context {
            $0.privateProfile = ProfilePrivate(userID: MemoryIDs.me, birthday: saved, birthdayOptIn: true, ageConfirmedAt: nil, updatedAt: MemoryTestContext.referenceNow)
        }
        let manageModel = BirthdayAddModel(dependencies: manage.dependencies, entry: entry)
        await manageModel.loadIfNeeded()
        record(BirthdayAddScreen(model: manageModel), "birthday.add", "manage", context: manage)
        await manageModel.remove()
        record(BirthdayAddScreen(model: manageModel), "birthday.add", "removed-toast", context: manage)
    }

    // MARK: birthday.request

    func testBirthdayRequestStates() async {
        func screen(_ model: BirthdayRequestModel) -> BirthdayRequestScreen {
            BirthdayRequestScreen(requestID: MemoryIDs.request.rawValue, groupID: MemoryIDs.group.rawValue, model: model)
        }
        let loading = context { $0.suspended = [.request] }
        record(screen(BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: loading.dependencies)), "birthday.request", "loading", context: loading)

        let open = context()
        let openModel = BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: open.dependencies)
        await openModel.loadIfNeeded()
        record(screen(openModel), "birthday.request", "open", context: open)

        let contributed = context()
        _ = try? await contributed.data.contribute(requestID: MemoryIDs.request, postID: MemoryIDs.post(2), line: "the best laugh in the group")
        let contributedModel = BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: contributed.dependencies)
        await contributedModel.loadIfNeeded()
        record(screen(contributedModel), "birthday.request", "contributed", context: contributed)

        let closed = context { state in
            state.requests = state.requests.map { request in
                var request = request
                request.dueAt = MemoryTestContext.referenceNow.addingTimeInterval(-60)
                return request
            }
        }
        let closedModel = BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: closed.dependencies)
        await closedModel.loadIfNeeded()
        record(screen(closedModel), "birthday.request", "closed", context: closed)

        let notFound = context { $0.requests = [] }
        let notFoundModel = BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: notFound.dependencies)
        await notFoundModel.loadIfNeeded()
        record(screen(notFoundModel), "birthday.request", "not-found", context: notFound)

        let failing = context()
        failing.data.fail(.request, with: .http(status: 500))
        let errorModel = BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: failing.dependencies)
        await errorModel.loadIfNeeded()
        record(screen(errorModel), "birthday.request", "error", context: failing)

        let offline = context()
        offline.data.fail(.request, with: .offline)
        let offlineModel = BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: offline.dependencies)
        await offlineModel.loadIfNeeded()
        record(screen(offlineModel), "birthday.request", "offline", context: offline)

        let entryModel = BirthdayRequestsEntryModel(groupID: MemoryIDs.group, dependencies: open.dependencies)
        await entryModel.refresh()
        record(BirthdayRequestsEntry(groupID: MemoryIDs.group.rawValue, model: entryModel).padding().background(Tokens.Colors.globalBackground),
               "birthday.request", "entry", context: open, layout: .fixed(width: 390, height: 120))
    }

    // MARK: birthday.contribute

    func testBirthdayContributeStates() async {
        func screen(_ model: BirthdayContributeModel) -> BirthdayContributeScreen {
            BirthdayContributeScreen(requestID: MemoryIDs.request.rawValue, model: model)
        }
        let loading = context { $0.suspended = [.eligiblePostIDs] }
        let loadingModel = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: loading.dependencies)
        let loadingTask = Task { await loadingModel.loadIfNeeded() }
        _ = await memoryEventually { loadingModel.phase == .loading }
        record(screen(loadingModel), "birthday.contribute", "loading", context: loading)
        loadingTask.cancel()

        let flow = context()
        let model = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: flow.dependencies)
        await model.loadIfNeeded()
        record(screen(model), "birthday.contribute", "photo", context: flow)
        model.select(MemoryIDs.post(2))
        record(screen(model), "birthday.contribute", "photo-selected", context: flow)
        model.usePhoto()
        record(screen(model), "birthday.contribute", "message", context: flow)
        model.line = "the best laugh in the group"
        record(screen(model), "birthday.contribute", "message-filled", context: flow)
        await model.submit()
        record(screen(model), "birthday.contribute", "done", context: flow)

        let sending = context { $0.suspended = [.contribute] }
        let sendingModel = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: sending.dependencies)
        await sendingModel.loadIfNeeded()
        sendingModel.select(MemoryIDs.post(1))
        sendingModel.usePhoto()
        sendingModel.line = "for every sunday"
        let sendTask = Task { await sendingModel.submit() }
        _ = await memoryEventually { sendingModel.isSending }
        record(screen(sendingModel), "birthday.contribute", "sending", context: sending)
        sendTask.cancel()

        let notEligible = context()
        let notEligibleModel = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: notEligible.dependencies)
        await notEligibleModel.loadIfNeeded()
        notEligibleModel.select(MemoryIDs.post(2))
        notEligibleModel.usePhoto()
        notEligibleModel.line = "hello"
        notEligible.data.update { _ = $0.myTags.remove(MemoryIDs.post(2)) }
        await notEligibleModel.submit()
        record(screen(notEligibleModel), "birthday.contribute", "not-eligible", context: notEligible)

        let failing = context()
        let errorModel = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: failing.dependencies)
        await errorModel.loadIfNeeded()
        errorModel.select(MemoryIDs.post(1))
        errorModel.usePhoto()
        errorModel.line = "hello"
        failing.data.fail(.contribute, with: .http(status: 500))
        await errorModel.submit()
        record(screen(errorModel), "birthday.contribute", "error", context: failing)
        failing.data.fail(.contribute, with: .offline)
        await errorModel.submit()
        record(screen(errorModel), "birthday.contribute", "offline", context: failing)

        let empty = context { state in
            state.posts.removeAll { $0.post.authorID == MemoryIDs.me }
            state.myTags = []
        }
        let emptyModel = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: empty.dependencies)
        await emptyModel.loadIfNeeded()
        record(screen(emptyModel), "birthday.contribute", "empty", context: empty)

        let closed = context { state in
            state.requests = state.requests.map { request in
                var request = request
                request.dueAt = MemoryTestContext.referenceNow.addingTimeInterval(-60)
                return request
            }
        }
        let closedModel = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: closed.dependencies)
        await closedModel.loadIfNeeded()
        record(screen(closedModel), "birthday.contribute", "closed", context: closed)

        let loadError = context()
        loadError.data.fail(.eligiblePostIDs, with: .http(status: 500))
        let loadErrorModel = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: loadError.dependencies)
        await loadErrorModel.loadIfNeeded()
        record(screen(loadErrorModel), "birthday.contribute", "load-error", context: loadError)
    }

    // MARK: birthday.tribute

    func testTributeStates() async {
        func screen(_ model: TributeModel) -> TributeScreen {
            TributeScreen(tributeID: MemoryIDs.tribute.rawValue, groupID: MemoryIDs.group.rawValue, model: model)
        }
        let loading = context { $0.suspended = [.tribute] }
        record(screen(TributeModel(tributeID: MemoryIDs.tribute, dependencies: loading.dependencies, saveVideo: { _ in })),
               "birthday.tribute", "loading", context: loading)

        let ready = context()
        let readyModel = TributeModel(tributeID: MemoryIDs.tribute, dependencies: ready.dependencies, saveVideo: { _ in })
        await readyModel.loadIfNeeded()
        record(screen(readyModel), "birthday.tribute", "ready", context: ready)
        await readyModel.download()
        record(screen(readyModel), "birthday.tribute", "saved-toast", context: ready)

        let rendering = context { state in
            state.tributes = state.tributes.map { tribute in
                var tribute = tribute
                tribute.status = .pending
                tribute.videoPath = nil
                return tribute
            }
        }
        let renderingModel = TributeModel(tributeID: MemoryIDs.tribute, dependencies: rendering.dependencies, saveVideo: { _ in })
        await renderingModel.loadIfNeeded()
        record(screen(renderingModel), "birthday.tribute", "rendering", context: rendering)

        let notDelivered = context { state in
            state.tributes = state.tributes.map { tribute in
                var tribute = tribute
                tribute.deliveredAt = nil
                return tribute
            }
        }
        let hiddenModel = TributeModel(tributeID: MemoryIDs.tribute, dependencies: notDelivered.dependencies, saveVideo: { _ in })
        await hiddenModel.loadIfNeeded()
        record(screen(hiddenModel), "birthday.tribute", "not-found", context: notDelivered)

        let failing = context()
        failing.data.fail(.tribute, with: .http(status: 500))
        let errorModel = TributeModel(tributeID: MemoryIDs.tribute, dependencies: failing.dependencies, saveVideo: { _ in })
        await errorModel.loadIfNeeded()
        record(screen(errorModel), "birthday.tribute", "error", context: failing)

        let offline = context()
        offline.data.fail(.tribute, with: .offline)
        let offlineModel = TributeModel(tributeID: MemoryIDs.tribute, dependencies: offline.dependencies, saveVideo: { _ in })
        await offlineModel.loadIfNeeded()
        record(screen(offlineModel), "birthday.tribute", "offline", context: offline)

        struct Denied: Error {}
        let denied = context()
        let deniedModel = TributeModel(tributeID: MemoryIDs.tribute, dependencies: denied.dependencies, saveVideo: { _ in throw Denied() })
        await deniedModel.loadIfNeeded()
        await deniedModel.download()
        record(screen(deniedModel), "birthday.tribute", "save-failed", context: denied)
    }

    // MARK: year.story

    func testYearStoryCardsSummaryAndShareImages() async {
        let year = LocalDate(MemoryTestContext.referenceNow, in: MemoryFormat.utc).year
        func screen(_ model: YearStoryModel) -> YearStoryScreen {
            YearStoryScreen(groupID: MemoryIDs.group.rawValue, year: year, model: model, revealsImmediately: true)
        }
        let loading = context { $0.suspended = [.yearStory] }
        record(screen(YearStoryModel(groupID: MemoryIDs.group, year: year, dependencies: loading.dependencies)), "year.story", "loading", context: loading)

        let story = context()
        let model = YearStoryModel(groupID: MemoryIDs.group, year: year, dependencies: story.dependencies)
        await model.loadIfNeeded()
        XCTAssertEqual(model.phase, .loaded)
        // The share images first (the summary shows them), at the iPhone 13 canvas width.
        let canvas = YearStoryGeometry.canvasSize(in: CGSize(width: 390, height: 763))
        var shareNumber = 0
        for card in model.shareableCards {
            guard let output = await YearStoryShareRenderer.render(card, width: canvas.width, pixelSize: nil, images: story.images) else {
                XCTFail("share image of \(card.id) not rendered")
                continue
            }
            XCTAssertEqual(output.image.size.width * output.image.scale, Tokens.Layouts.YearStoryShareCard.width, accuracy: 1)
            XCTAssertEqual(output.image.size.height * output.image.scale, Tokens.Layouts.YearStoryShareCard.height, accuracy: 1)
            model.shareFiles[card.id] = output.file
            model.shareImages[card.id] = output.image
            shareNumber += 1
            let target = SnapshotRecorder.directory.appendingPathComponent("memory", isDirectory: true)
                .appendingPathComponent("year.story-share-\(shareNumber).png")
            try? FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: target)
            try? FileManager.default.copyItem(at: output.file, to: target)
        }
        for position in model.cards.indices {
            model.index = position
            let card = model.cards[position]
            let state = card == .summary ? "summary" : "card-\(String(format: "%02d", position + 1))-\(Self.kind(card))"
            record(screen(model), "year.story", state, context: story)
        }

        let failing = context()
        failing.data.fail(.yearStory, with: .http(status: 500))
        let errorModel = YearStoryModel(groupID: MemoryIDs.group, year: year, dependencies: failing.dependencies)
        await errorModel.loadIfNeeded()
        record(screen(errorModel), "year.story", "error", context: failing)

        let offline = context()
        offline.data.fail(.yearStory, with: .offline)
        let offlineModel = YearStoryModel(groupID: MemoryIDs.group, year: year, dependencies: offline.dependencies)
        await offlineModel.loadIfNeeded()
        record(screen(offlineModel), "year.story", "offline", context: offline)

        let entryModel = YearStoryEntryModel(groupID: MemoryIDs.group, dependencies: story.dependencies)
        await entryModel.refresh()
        record(YearStoryEntry(groupID: MemoryIDs.group.rawValue, model: entryModel).padding().background(Tokens.Colors.globalBackground),
               "year.story", "entry", context: story, layout: .fixed(width: 390, height: 140))
    }

    private static func kind(_ card: YearStoryCard) -> String {
        switch card {
        case .intro: return "intro"
        case .momentsSetup: return "moments-setup"
        case .moments: return "moments"
        case .busiestMonth: return "busiest-month"
        case .mostReactedSetup: return "most-reacted-setup"
        case .mostReacted: return "most-reacted-photo"
        case .togetherSetup: return "together-setup"
        case .togetherDay: return "together-day"
        case .teaser: return "teaser"
        case .outro: return "outro"
        case .summary: return "summary"
        }
    }

    // MARK: tagging

    func testTaggingToggleStates() async {
        let context = context()
        func slot<V: View>(_ control: V) -> some View {
            ZStack(alignment: .topTrailing) {
                Tokens.Colors.globalBackgroundDeep
                control
                    .padding(.trailing, Tokens.Sizes.photoViewerDimensionActionTrailing)
                    .padding(.top, Tokens.Sizes.globalHeaderInset)
            }
        }
        let layout = SwiftUISnapshotLayout.fixed(width: 390, height: 220)
        record(slot(SelfTagToggleControl(isOn: false, onToggle: {})), "tagging", "off", context: context, layout: layout)
        record(slot(SelfTagToggleControl(isOn: true, onToggle: {})), "tagging", "on", context: context, layout: layout)
        record(slot(SelfTagToggleControl(isOn: true, isPending: true, onToggle: {})), "tagging", "pending", context: context, layout: layout)
        record(slot(SelfTagToggleControl(isOn: false, showsCoach: true, onToggle: {})), "tagging", "coach", context: context, layout: layout)
        var toast: MemoryToastMessage? = MemoryToastMessage(text: Copy.taggingError)
        let binding = Binding(get: { toast }, set: { toast = $0 })
        record(slot(SelfTagToggleControl(isOn: false, onToggle: {})).memoryToast(binding), "tagging", "error-toast", context: context, layout: layout)
    }
}
