// Snapshot of every memory screen in every state, in the light appearance, and of each surface's primary state also in
// the dark appearance (docs/SCREENS_BRIEF.md rule 7, docs/REDESIGN_BRIEF.md "Pass 4"), written to
// ios/build/snapshots/memory/<surface>-<state>-<light|dark>.png for design/verification/<surface>.md and the Pass 5 review.
// Each snapshot wraps the view in the appearance under test (`.environment(\.colorScheme, …)`); media surfaces render
// dark in both (layout.global.appearance.media), so their two files are expected to match.
// Screens run on the fixture backend; photos and avatars are real sample photos (fixtures/photos/, `MemorySamplePhotos`).
@testable import App
import AppData
import AppModels
import DesignSystem
import SnapshotTesting
import SwiftUI
import UIKit
import XCTest

@MainActor
final class MemorySnapshotTests: XCTestCase {
    // MARK: Helpers

    private enum Appearance: String {
        case light
        case dark

        var scheme: ColorScheme { self == .dark ? .dark : .light }
    }

    /// Real sample photos (fixtures/photos/) for every storage path of the fixtures, cropped to each photo's own shape;
    /// the collage is a grid of the photos it collects, the tribute poster a 16:9 photo, avatars sample portraits.
    private func fillImages(_ context: MemoryTestContext) {
        let state = context.data.snapshot
        for (index, post) in state.posts.enumerated() {
            guard let media = post.media else { continue }
            let image = MemorySamplePhotos.photo(index: index, width: media.width ?? 1, height: media.height ?? 1)
            for path in [media.originalPath, media.displayPath, media.thumbPath].compactMap({ $0 }) {
                context.images.images[URL(string: "fixture://" + path)!] = image
            }
        }
        for collage in state.collages {
            if let path = collage.imagePath {
                context.images.images[URL(string: "fixture://" + path)!] = MemorySamplePhotos.collage(posts: collage.postIDs.count)
            }
        }
        for tribute in state.tributes {
            if let path = tribute.posterPath {
                context.images.images[URL(string: "fixture://" + path)!] = MemorySamplePhotos.poster
            }
        }
        for (index, profile) in state.profiles.enumerated() {
            if let path = profile.avatarPath {
                context.images.images[URL(string: "fixture://" + path)!] = MemorySamplePhotos.avatar(index: index)
            }
        }
    }

    /// Records `view` as `memory/<surface>-<state>-<appearance>.png` for each appearance.
    private func record<V: View>(
        _ view: @autoclosure () -> V,
        _ surface: String,
        _ state: String,
        context: MemoryTestContext,
        appearances: [Appearance] = [.light],
        layout: SwiftUISnapshotLayout = .device(config: .iPhone13),
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        for appearance in appearances {
            let name = surface + "-" + state + "-" + appearance.rawValue
            let content = view()
                .environment(\.memoryImageLoader, context.images)
                .environment(\.colorScheme, appearance.scheme)
            guard let written = SnapshotRecorder.record(content, named: name, group: "memory", layout: layout, file: file, testName: testName, line: line) else {
                XCTFail("snapshot \(name) not written", file: file, line: line)
                continue
            }
            let target = written.deletingLastPathComponent().appendingPathComponent(name + ".png")
            try? FileManager.default.removeItem(at: target)
            do {
                try FileManager.default.moveItem(at: written, to: target)
            } catch {
                XCTFail("could not name \(name): \(error)", file: file, line: line)
                continue
            }
            XCTAssertGreaterThan((try? Data(contentsOf: target).count) ?? 0, 0, file: file, line: line)
        }
    }

    private func makeContext(_ configure: (inout FixtureMemoryData.State) -> Void = { _ in }) -> MemoryTestContext {
        let context = MemoryTestContext(configure: configure)
        fillImages(context)
        return context
    }

    private let both: [Appearance] = [.light, .dark]

    // MARK: onthisday

    func testOnThisDayStates() async {
        func screen(_ model: OnThisDayModel) -> some View {
            NavigationStack { OnThisDayScreen(groupID: MemoryIDs.group.rawValue, model: model) }
        }
        let loading = makeContext { $0.suspended = [.onThisDay] }
        record(screen(OnThisDayModel(groupID: MemoryIDs.group, dependencies: loading.dependencies)), "onthisday", "loading", context: loading)

        let loaded = makeContext()
        let model = OnThisDayModel(groupID: MemoryIDs.group, dependencies: loaded.dependencies, randomIndex: { _ in 0 })
        await model.loadIfNeeded()
        XCTAssertEqual(model.phase, .loaded)
        model.dismissIntro()
        record(screen(model), "onthisday", "paused", context: loaded, appearances: both)
        model.next()
        model.next()
        record(screen(model), "onthisday", "paused-own-memory", context: loaded)
        model.togglePlay()
        record(screen(model), "onthisday", "playing", context: loaded)
        model.stopPlaying()
        await model.shuffle()
        record(screen(model), "onthisday", "shuffle", context: loaded)

        // The feature intro (C-29 sheet content; the sheet follows the appearance).
        for appearance in both {
            record(
                FeatureIntroSheet(
                    title: Copy.onthisdayNuxTitle,
                    rows: [FeatureIntroRow(icon: Tokens.Icons.globalRewind, text: Copy.onthisdayNuxMessage(group: "Sunday dinners"))],
                    buttonTitle: Copy.onthisdayNuxButton,
                    onButton: {}
                ),
                "onthisday", "intro", context: loaded, appearances: [appearance], layout: .fixed(width: 390, height: 420)
            )
        }

        let empty = makeContext()
        let emptyModel = OnThisDayModel(groupID: MemoryIDs.group, dependencies: empty.dependencies)
        await emptyModel.loadIfNeeded()
        emptyModel.dismissIntro()
        for memory in emptyModel.memories { emptyModel.removePost(memory.id) }
        XCTAssertEqual(emptyModel.phase, .empty)
        record(screen(emptyModel), "onthisday", "empty", context: empty)

        let failing = makeContext()
        failing.data.fail(.onThisDay, with: .http(status: 500))
        let errorModel = OnThisDayModel(groupID: MemoryIDs.group, dependencies: failing.dependencies)
        await errorModel.loadIfNeeded()
        record(screen(errorModel), "onthisday", "error", context: failing)

        let offline = makeContext()
        offline.data.fail(.onThisDay, with: .offline)
        let offlineModel = OnThisDayModel(groupID: MemoryIDs.group, dependencies: offline.dependencies)
        await offlineModel.loadIfNeeded()
        record(screen(offlineModel), "onthisday", "offline", context: offline)

        // The group-screen entry (feed card default; the final look belongs to groups.screen).
        let entryModel = OnThisDayEntryModel(groupID: MemoryIDs.group, dependencies: loaded.dependencies)
        await entryModel.refresh()
        XCTAssertNotNil(entryModel.content)
        record(
            OnThisDayEntry(groupID: MemoryIDs.group.rawValue, model: entryModel).padding().background(Tokens.Colors.globalBackground),
            "onthisday", "entry", context: loaded, appearances: both, layout: .fixed(width: 390, height: 440)
        )
    }

    // MARK: year.story

    func testYearStoryCardsSummaryAndShareImages() async {
        let year = LocalDate(MemoryTestContext.referenceNow, in: MemoryFormat.utc).year
        func screen(_ model: YearStoryModel) -> YearStoryScreen {
            YearStoryScreen(groupID: MemoryIDs.group.rawValue, year: year, model: model, revealsImmediately: true)
        }
        let loading = makeContext { $0.suspended = [.yearStory] }
        record(screen(YearStoryModel(groupID: MemoryIDs.group, year: year, dependencies: loading.dependencies)), "year.story", "loading", context: loading)

        let story = makeContext()
        let model = YearStoryModel(groupID: MemoryIDs.group, year: year, dependencies: story.dependencies)
        await model.loadIfNeeded()
        XCTAssertEqual(model.phase, .loaded)
        // The share images (1080 × 1920) of every shareable card and both summary styles, at the iPhone 13 frame width.
        let frameWidth: CGFloat = 390
        var shareNumber = 0
        for card in model.cards where card.isShareable {
            let styles: [YearStorySummary.Style] = card == .summary ? model.summaryStyles : [model.summaryStyle]
            for style in styles {
                guard let output = await YearStoryShareRenderer.render(
                    card, width: frameWidth, summary: model.summary, summaryStyle: style, coverURL: model.coverURL,
                    images: story.images, name: card.id + "-" + style.rawValue
                ) else {
                    XCTFail("share image of \(card.id) not rendered")
                    continue
                }
                XCTAssertEqual(output.image.size.width * output.image.scale, Tokens.Layouts.YearStoryShareCard.width, accuracy: 1)
                XCTAssertEqual(output.image.size.height * output.image.scale, Tokens.Layouts.YearStoryShareCard.height, accuracy: 1)
                shareNumber += 1
                let target = SnapshotRecorder.directory.appendingPathComponent("memory", isDirectory: true)
                    .appendingPathComponent("year.story-share-\(String(format: "%02d", shareNumber))-\(card.id).png")
                try? FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? FileManager.default.removeItem(at: target)
                try? FileManager.default.copyItem(at: output.file, to: target)
            }
        }
        // Every card, paused so no timer runs while recording; the first fact card also in dark.
        model.togglePause()
        for position in model.cards.indices {
            model.index = position
            let card = model.cards[position]
            if card == .summary {
                for (page, style) in model.summaryStyles.enumerated() {
                    model.summaryPage = page
                    record(screen(model), "year.story", "summary-" + style.rawValue, context: story, appearances: page == 0 ? both : [.light])
                }
                model.summaryPage = 0
            } else {
                let state = "card-\(String(format: "%02d", position + 1))-\(Self.kind(card))"
                record(screen(model), "year.story", state, context: story, appearances: card.id == "moments" ? both : [.light])
            }
        }
        // Playing (pause glyph) on the intro.
        model.index = 0
        model.togglePause()
        XCTAssertFalse(model.isPaused)
        record(screen(model), "year.story", "playing", context: story)
        model.stopListening()

        let failing = makeContext()
        failing.data.fail(.yearStory, with: .http(status: 500))
        let errorModel = YearStoryModel(groupID: MemoryIDs.group, year: year, dependencies: failing.dependencies)
        await errorModel.loadIfNeeded()
        record(screen(errorModel), "year.story", "error", context: failing)

        let offline = makeContext()
        offline.data.fail(.yearStory, with: .offline)
        let offlineModel = YearStoryModel(groupID: MemoryIDs.group, year: year, dependencies: offline.dependencies)
        await offlineModel.loadIfNeeded()
        record(screen(offlineModel), "year.story", "offline", context: offline)

        let entryModel = YearStoryEntryModel(groupID: MemoryIDs.group, dependencies: story.dependencies)
        await entryModel.refresh()
        record(
            YearStoryEntry(groupID: MemoryIDs.group.rawValue, model: entryModel).padding().background(Tokens.Colors.globalBackground),
            "year.story", "entry", context: story, appearances: both, layout: .fixed(width: 390, height: 440)
        )
    }

    private static func kind(_ card: YearStoryCard) -> String {
        switch card {
        case .intro: return "intro"
        case .lookBack: return "look-back"
        case .moments: return "moments"
        case .busiestMonth: return "busiest-month"
        case .mostReactedSetup: return "most-reacted-setup"
        case .mostReacted: return "most-reacted-photo"
        case .taggedSetup: return "tagged-setup"
        case .tagged: return "tagged-photo"
        case .togetherSetup: return "together-setup"
        case .togetherDay: return "together-day"
        case .outro: return "outro"
        case .summary: return "summary"
        }
    }

    /// The recap card on its own (white in both appearances, L-4), as week.recap uses it.
    func testRecapCard() {
        let context = makeContext()
        let photos = (0..<24).map { index in
            RecapCardPhoto(id: String(index), source: .image(MemorySamplePhotos.photo(index: index % 9, width: 3, height: 4)), accessibilityLabel: "")
        }
        for appearance in both {
            record(
                ZStack {
                    BlurredBackdrop(source: .image(MemorySamplePhotos.photo(index: 1, width: 4, height: 3)))
                    RecapCard(photos: photos, title: "2026", name: "Sunday dinners", frameWidth: 390)
                },
                "year.story", "recap-card", context: context, appearances: [appearance], layout: .fixed(width: 390, height: 700)
            )
        }
    }

    // MARK: birthday.add

    func testBirthdayAddStates() async {
        let entry = BirthdayEntry(pattern: "MM/dd/yyyy")
        func screen(_ model: BirthdayAddModel) -> some View {
            NavigationStack { BirthdayAddScreen(model: model) }
        }
        let loading = makeContext { $0.suspended = [.myPrivateProfile] }
        record(screen(BirthdayAddModel(dependencies: loading.dependencies, entry: entry)), "birthday.add", "loading", context: loading)

        let add = makeContext()
        let addModel = BirthdayAddModel(dependencies: add.dependencies, entry: entry)
        await addModel.loadIfNeeded()
        record(screen(addModel), "birthday.add", "empty-field", context: add, appearances: both)
        addModel.setText("05262000")
        record(screen(addModel), "birthday.add", "filled", context: add)

        let saving = makeContext { $0.suspended = [.setBirthday] }
        let savingModel = BirthdayAddModel(dependencies: saving.dependencies, entry: entry)
        await savingModel.loadIfNeeded()
        savingModel.setText("05262000")
        let task = Task { await savingModel.confirm() }
        _ = await memoryEventually { savingModel.isSaving }
        record(screen(savingModel), "birthday.add", "saving", context: saving)
        task.cancel()

        let invalid = makeContext()
        let invalidModel = BirthdayAddModel(dependencies: invalid.dependencies, entry: entry)
        await invalidModel.loadIfNeeded()
        invalidModel.setText("02302000")
        await invalidModel.confirm()
        record(screen(invalidModel), "birthday.add", "invalid", context: invalid)

        let failing = makeContext()
        failing.data.fail(.setBirthday, with: .http(status: 500))
        let errorModel = BirthdayAddModel(dependencies: failing.dependencies, entry: entry)
        await errorModel.loadIfNeeded()
        errorModel.setText("05262000")
        await errorModel.confirm()
        record(screen(errorModel), "birthday.add", "error", context: failing)

        let offline = makeContext()
        offline.data.fail(.setBirthday, with: .offline)
        let offlineModel = BirthdayAddModel(dependencies: offline.dependencies, entry: entry)
        await offlineModel.loadIfNeeded()
        offlineModel.setText("05262000")
        await offlineModel.confirm()
        record(screen(offlineModel), "birthday.add", "offline", context: offline)

        let saved = LocalDate(year: 2000, month: 5, day: 26)!
        let manage = makeContext {
            $0.privateProfile = ProfilePrivate(userID: MemoryIDs.me, birthday: saved, birthdayOptIn: true, ageConfirmedAt: nil, updatedAt: MemoryTestContext.referenceNow)
        }
        let manageModel = BirthdayAddModel(dependencies: manage.dependencies, entry: entry)
        await manageModel.loadIfNeeded()
        record(screen(manageModel), "birthday.add", "manage", context: manage, appearances: both)
    }

    // MARK: birthday.request

    func testBirthdayRequestStates() async {
        func screen(_ model: BirthdayRequestModel) -> BirthdayRequestScreen {
            BirthdayRequestScreen(requestID: MemoryIDs.request.rawValue, groupID: MemoryIDs.group.rawValue, model: model)
        }
        let loading = makeContext { $0.suspended = [.request] }
        record(screen(BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: loading.dependencies)), "birthday.request", "loading", context: loading)

        let open = makeContext()
        let openModel = BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: open.dependencies)
        await openModel.loadIfNeeded()
        record(screen(openModel), "birthday.request", "open", context: open, appearances: both)

        let contributed = makeContext()
        _ = try? await contributed.data.contribute(requestID: MemoryIDs.request, postID: MemoryIDs.post(2), line: "the best laugh in the group")
        let contributedModel = BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: contributed.dependencies)
        await contributedModel.loadIfNeeded()
        record(screen(contributedModel), "birthday.request", "contributed", context: contributed, appearances: both)

        let closed = makeContext { state in
            state.requests = state.requests.map { request in
                var request = request
                request.dueAt = MemoryTestContext.referenceNow.addingTimeInterval(-60)
                return request
            }
        }
        let closedModel = BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: closed.dependencies)
        await closedModel.loadIfNeeded()
        record(screen(closedModel), "birthday.request", "closed", context: closed)

        let notFound = makeContext { $0.requests = [] }
        let notFoundModel = BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: notFound.dependencies)
        await notFoundModel.loadIfNeeded()
        record(screen(notFoundModel), "birthday.request", "not-found", context: notFound)

        let failing = makeContext()
        failing.data.fail(.request, with: .http(status: 500))
        let errorModel = BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: failing.dependencies)
        await errorModel.loadIfNeeded()
        record(screen(errorModel), "birthday.request", "error", context: failing)

        let offline = makeContext()
        offline.data.fail(.request, with: .offline)
        let offlineModel = BirthdayRequestModel(requestID: MemoryIDs.request, dependencies: offline.dependencies)
        await offlineModel.loadIfNeeded()
        record(screen(offlineModel), "birthday.request", "offline", context: offline)

        let entryModel = BirthdayRequestsEntryModel(groupID: MemoryIDs.group, dependencies: open.dependencies)
        await entryModel.refresh()
        record(
            BirthdayRequestsEntry(groupID: MemoryIDs.group.rawValue, model: entryModel).padding(.vertical).background(Tokens.Colors.globalBackground),
            "birthday.request", "entry", context: open, appearances: both, layout: .fixed(width: 390, height: 120)
        )
    }

    // MARK: birthday.contribute

    func testBirthdayContributeStates() async {
        func screen(_ model: BirthdayContributeModel) -> BirthdayContributeScreen {
            BirthdayContributeScreen(requestID: MemoryIDs.request.rawValue, model: model)
        }
        let loading = makeContext { $0.suspended = [.eligiblePostIDs] }
        let loadingModel = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: loading.dependencies)
        let loadingTask = Task { await loadingModel.loadIfNeeded() }
        _ = await memoryEventually { loadingModel.phase == .loading }
        record(screen(loadingModel), "birthday.contribute", "loading", context: loading)
        loadingTask.cancel()

        let flow = makeContext()
        let model = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: flow.dependencies)
        await model.loadIfNeeded()
        record(screen(model), "birthday.contribute", "picker", context: flow, appearances: both)
        model.select(MemoryIDs.post(2))
        record(screen(model), "birthday.contribute", "picker-selected", context: flow)
        model.usePhoto()
        record(screen(model), "birthday.contribute", "composer", context: flow, appearances: both)
        model.line = "the best laugh in the group"
        record(screen(model), "birthday.contribute", "composer-filled", context: flow)
        for appearance in both {
            record(BirthdayContributeMessage(model: model), "birthday.contribute", "message", context: flow, appearances: [appearance])
        }

        let sending = makeContext { $0.suspended = [.contribute] }
        let sendingModel = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: sending.dependencies)
        await sendingModel.loadIfNeeded()
        sendingModel.select(MemoryIDs.post(1))
        sendingModel.usePhoto()
        sendingModel.line = "for every sunday"
        let sendTask = Task { await sendingModel.submit() }
        _ = await memoryEventually { sendingModel.isSending }
        record(screen(sendingModel), "birthday.contribute", "sending", context: sending)
        sendTask.cancel()

        let notEligible = makeContext()
        let notEligibleModel = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: notEligible.dependencies)
        await notEligibleModel.loadIfNeeded()
        notEligibleModel.select(MemoryIDs.post(2))
        notEligibleModel.usePhoto()
        notEligibleModel.line = "hello"
        notEligible.data.update { _ = $0.myTags.remove(MemoryIDs.post(2)) }
        await notEligibleModel.submit()
        record(screen(notEligibleModel), "birthday.contribute", "not-eligible", context: notEligible)

        let failing = makeContext()
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

        let empty = makeContext { state in
            state.posts.removeAll { $0.post.authorID == MemoryIDs.me }
            state.myTags = []
        }
        let emptyModel = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: empty.dependencies)
        await emptyModel.loadIfNeeded()
        record(screen(emptyModel), "birthday.contribute", "empty", context: empty)

        let closed = makeContext { state in
            state.requests = state.requests.map { request in
                var request = request
                request.dueAt = MemoryTestContext.referenceNow.addingTimeInterval(-60)
                return request
            }
        }
        let closedModel = BirthdayContributeModel(requestID: MemoryIDs.request, dependencies: closed.dependencies)
        await closedModel.loadIfNeeded()
        record(screen(closedModel), "birthday.contribute", "closed", context: closed)

        let loadError = makeContext()
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
        let loading = makeContext { $0.suspended = [.tribute] }
        record(screen(TributeModel(tributeID: MemoryIDs.tribute, dependencies: loading.dependencies, saveVideo: { _ in })),
               "birthday.tribute", "loading", context: loading)

        let ready = makeContext()
        let readyModel = TributeModel(tributeID: MemoryIDs.tribute, dependencies: ready.dependencies, saveVideo: { _ in })
        await readyModel.loadIfNeeded()
        record(screen(readyModel), "birthday.tribute", "ready-honoree", context: ready, appearances: both)

        let member = makeContext { state in
            state.tributes = state.tributes.map { tribute in
                var tribute = tribute
                tribute.honoreeID = MemoryIDs.friend
                return tribute
            }
        }
        let memberModel = TributeModel(tributeID: MemoryIDs.tribute, dependencies: member.dependencies, saveVideo: { _ in })
        await memberModel.loadIfNeeded()
        record(screen(memberModel), "birthday.tribute", "ready-member", context: member)

        let rendering = makeContext { state in
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

        let notDelivered = makeContext { state in
            state.tributes = state.tributes.map { tribute in
                var tribute = tribute
                tribute.deliveredAt = nil
                return tribute
            }
        }
        let hiddenModel = TributeModel(tributeID: MemoryIDs.tribute, dependencies: notDelivered.dependencies, saveVideo: { _ in })
        await hiddenModel.loadIfNeeded()
        record(screen(hiddenModel), "birthday.tribute", "not-found", context: notDelivered)

        let failing = makeContext()
        failing.data.fail(.tribute, with: .http(status: 500))
        let errorModel = TributeModel(tributeID: MemoryIDs.tribute, dependencies: failing.dependencies, saveVideo: { _ in })
        await errorModel.loadIfNeeded()
        record(screen(errorModel), "birthday.tribute", "error", context: failing)

        let offline = makeContext()
        offline.data.fail(.tribute, with: .offline)
        let offlineModel = TributeModel(tributeID: MemoryIDs.tribute, dependencies: offline.dependencies, saveVideo: { _ in })
        await offlineModel.loadIfNeeded()
        record(screen(offlineModel), "birthday.tribute", "offline", context: offline)
    }

    // MARK: tagging

    /// The run on the viewer footer's second line (C-22 on `color.global.backgroundDeep`), after the date.
    private func footer(_ run: TagRun) -> some View {
        TagRunLine(leadingText: MemoryFormat.weekdayMonthDay(LocalDate(year: 2026, month: 7, day: 1)!), run: run)
            .padding(.horizontal, Tokens.Sizes.globalScreenMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Tokens.Colors.globalBackgroundDeep)
    }

    func testTaggingStates() {
        let context = makeContext()
        let layout = SwiftUISnapshotLayout.fixed(width: 390, height: 80)
        record(footer(TagRun(names: [], isTagged: false) {}), "tagging", "run-untagged", context: context, appearances: both, layout: layout)
        record(footer(TagRun(names: ["Bea", "Ana"], isTagged: true) {}), "tagging", "run-tagged", context: context, appearances: both, layout: layout)
        record(footer(TagRun(names: ["Bea", "Caio", "Ana", "Dani", "Eli"], isTagged: true) {}), "tagging", "run-truncated", context: context, layout: layout)
        record(footer(TagRun(names: ["Ana"], isTagged: true, isPending: true) {}), "tagging", "run-pending", context: context, layout: layout)

        let people = [
            TaggingSheetPerson(id: "b", firstName: "Bea", avatar: .image(MemorySamplePhotos.avatar(index: 1)), isMe: false),
            TaggingSheetPerson(id: "a", firstName: "Ana", avatar: .image(MemorySamplePhotos.avatar(index: 0)), isMe: true),
        ]
        let sheet = SwiftUISnapshotLayout.fixed(width: 390, height: 420)
        record(TaggingSheet(people: people, isTagged: true, onRemove: {}, onTag: {}, onClose: {}),
               "tagging", "sheet-tagged", context: context, appearances: both, layout: sheet)
        record(TaggingSheet(people: Array(people.prefix(1)), isTagged: false, onRemove: {}, onTag: {}, onClose: {}),
               "tagging", "sheet-not-tagged", context: context, layout: sheet)
        record(TaggingSheet(people: [], isTagged: false, onRemove: {}, onTag: {}, onClose: {}),
               "tagging", "sheet-empty", context: context, layout: sheet)
    }
}
