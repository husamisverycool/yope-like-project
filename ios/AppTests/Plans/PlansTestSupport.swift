// Fixtures for the plans group's tests: a fixed clock, a fake backend (`FakePlansData`) with a group, four people and a
// plan, real sample photos (fixtures/photos/, `SamplePhotos`) behind every storage path, and the snapshot recorder for
// ios/build/snapshots/plans/<surface>-<state>-<light|dark>.png.
@testable import App
import AppData
import AppModels
import DesignSystem
import SnapshotTesting
import SwiftUI
import XCTest

/// A fake backend keyed to one group ("Roommates", UTC) on Friday 2026-10-16 10:00 UTC, with a plan on Saturday at
/// 19:30 made by Ana. Every storage path is `sample/<photo>.jpg`.
@MainActor
struct PlansFixture {
    static let now = Date(timeIntervalSince1970: 1_792_144_800) // 2026-10-16T10:00:00Z (Friday)
    static let hour: TimeInterval = 3600
    static let day: TimeInterval = 86_400

    static let groupID = GroupID("00000000-0000-4000-8000-00000000a0b1")
    static let me = UserID("00000000-0000-4000-8000-00000000a001")
    static let ana = UserID("00000000-0000-4000-8000-00000000a002")
    static let ben = UserID("00000000-0000-4000-8000-00000000a003")
    static let cleo = UserID("00000000-0000-4000-8000-00000000a004")
    static let planID = PlanID("00000000-0000-4000-8000-00000000f101")
    static let questionID = GroupQuestionID("00000000-0000-4000-8000-00000000f201")

    /// Saturday 2026-10-17 19:30 UTC.
    static let dinnerStart = now.addingTimeInterval(day + 9.5 * hour)

    let data: FakePlansData
    var clock: Date

    init(clock: Date = PlansFixture.now, me: UserID = PlansFixture.me) {
        self.clock = clock
        let fixed = clock
        data = FakePlansData(me: me, clock: { fixed })
        let people = [(Self.me, "Sam Reed", "avatar-02"), (Self.ana, "Ana Lima", "avatar-01"), (Self.ben, "Ben Ortiz", "avatar-06"), (Self.cleo, "Cleo Park", "avatar-05")]
        let group = PhotoGroup(
            id: Self.groupID, name: "Roommates", kind: .roommates, coverPath: "sample/movie-night-couch-4x3.jpg",
            timeZone: "UTC", wakingStart: nil, wakingEnd: nil, invitationPaused: false, createdBy: Self.ana,
            createdAt: clock.addingTimeInterval(-30 * Self.day), updatedAt: clock
        )
        let members = people.map { id, name, avatar in
            MemberProfile(
                member: GroupMember(groupID: Self.groupID, userID: id, role: id == Self.ana ? .admin : .member, muted: false, joinedAt: group.createdAt),
                profile: Profile(id: id, displayName: name, avatarPath: "sample/\(avatar).jpg", createdAt: group.createdAt, updatedAt: group.createdAt)
            )
        }
        data.update { state in
            state.groups = [group]
            state.members[Self.groupID] = members
        }
    }

    var services: PlansServices {
        let fixed = clock
        return PlansServices(plans: data, questions: data, now: { fixed })
    }

    /// The Saturday dinner (Ana's), with a cover and a note; `answers` as (who, answer) in answer order.
    func addDinner(
        canceled: Bool = false,
        answers: [(UserID, PlanAnswerKind)] = [(PlansFixture.ana, .going), (PlansFixture.ben, .going), (PlansFixture.cleo, .maybe)],
        cover: String? = "sample/dinner-long-table-3x4.jpg"
    ) {
        let made = clock.addingTimeInterval(-2 * Self.day)
        let plan = Plan(
            id: Self.planID, groupID: Self.groupID, createdBy: Self.ana, title: "Dinner at ours",
            startsAt: Self.dinnerStart, allDay: false, localDate: LocalDate(year: 2026, month: 10, day: 17)!,
            place: "Our kitchen", note: "Bring something sweet — we'll have pasta.", coverPath: cover,
            canceledAt: canceled ? clock.addingTimeInterval(-Self.hour) : nil, canceledBy: canceled ? Self.ana : nil,
            createdAt: made, updatedAt: made
        )
        let rows = answers.enumerated().map { index, answer in
            PlanAnswer(planID: Self.planID, userID: answer.0, groupID: Self.groupID, answer: answer.1, answeredAt: made.addingTimeInterval(Double(index) * Self.hour))
        }
        data.update { state in
            state.plans[Self.planID] = plan
            state.answers = rows
        }
    }

    /// Posts of the plan's day (the album after it).
    func addPlanPhotos(_ names: [String]) {
        let posts = names.enumerated().map { index, name in
            Self.post(index: index, photo: name, by: index.isMultiple(of: 2) ? Self.ben : Self.ana, at: Self.dinnerStart.addingTimeInterval(Double(index) * 600))
        }
        data.update { $0.photos[Self.planID] = posts }
    }

    /// The weekly question (q01) on for the group, with `answers` as photos (newest first).
    func addQuestion(answers photos: [String] = [], hidden: Bool = false) {
        let posts = photos.enumerated().map { index, name in
            Self.post(index: 20 + index, photo: name, by: Self.ben, at: clock.addingTimeInterval(-Double(index + 1) * Self.hour))
        }
        data.update { state in
            state.weeklyQuestion[Self.groupID] = true
            state.questions[Self.groupID] = GroupQuestion(
                id: Self.questionID, questionKey: "question.weekly.q01", weekStart: LocalDate(year: 2026, month: 10, day: 12)!, hiddenByMe: hidden
            )
            state.questionAnswers[Self.questionID] = posts
        }
    }

    static func post(index: Int, photo: String, by author: UserID, at date: Date) -> PostWithMedia {
        let id = PostID("00000000-0000-4000-8000-0000000c" + String(1000 + index))
        let media = MediaID("00000000-0000-4000-8000-0000000d" + String(1000 + index))
        let path = "sample/\(photo).jpg"
        return PostWithMedia(
            post: Post(id: id, mediaID: media, groupID: groupID, authorID: author, createdAt: date),
            media: Media(
                id: media, ownerID: author, kind: .photo, originalPath: path, displayPath: path, thumbPath: path,
                width: 1080, height: 1440, renditionsReadyAt: date, createdAt: date
            )
        )
    }

    /// Every storage path of the fixture decoded into the image pipeline (avatars, covers, posts).
    func warmPhotos() async {
        let state = data.read { $0 }
        var paths: [(String, [ClosedRange<CGFloat>])] = []
        for member in state.members.values.flatMap({ $0 }) {
            if let path = member.profile?.avatarPath { paths.append((path, AccountSamplePhotos.avatarFrames)) }
        }
        for plan in state.plans.values {
            if let path = plan.coverPath { paths.append((path, AccountSamplePhotos.coverFrames + [Tokens.Sizes.groupsScreenSizeCoverHeight...Tokens.Sizes.groupsScreenSizeCoverHeight])) }
        }
        let posts = state.photos.values.flatMap { $0 } + state.questionAnswers.values.flatMap { $0 }
        for post in posts {
            if let path = post.media?.displayPath { paths.append((path, AccountSamplePhotos.postFrames + [Tokens.Sizes.globalFriendCardHeight...Tokens.Sizes.globalFriendCardHeight])) }
        }
        for (path, frames) in paths {
            await AccountSamplePhotos.warm(path: path, frames: frames)
        }
    }
}

/// Records `ios/build/snapshots/plans/<surface>-<state>-<light|dark>.png`.
enum PlansSnapshot {
    static let folder = SnapshotRecorder.directory.appendingPathComponent("plans", isDirectory: true)
    static let both: [ColorScheme] = [.light, .dark]

    @MainActor
    @discardableResult
    static func record<V: View>(
        _ view: V,
        surface: String,
        state: String,
        dependencies: AccountDependencies? = nil,
        appearances: [ColorScheme] = [.light],
        layout: SwiftUISnapshotLayout = .device(config: .iPhone13),
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) -> URL? {
        let dependencies = dependencies ?? PlansTestDependencies.make()
        var last: URL?
        for scheme in appearances {
            let name = "\(surface)-\(state)-\(scheme == .dark ? "dark" : "light")"
            let hosted = view
                .environment(dependencies)
                .environment(\.storageURLResolver, dependencies.storageURLResolver)
                .toastHost(dependencies.toasts)
                .environment(\.colorScheme, scheme)
                .preferredColorScheme(scheme)
            guard let written = SnapshotRecorder.record(hosted, named: name, group: "plans", layout: layout, file: file, testName: testName, line: line) else {
                XCTFail("snapshot \(name) not written", file: file, line: line)
                return nil
            }
            let target = folder.appendingPathComponent("\(name).png")
            try? FileManager.default.removeItem(at: target)
            do {
                try FileManager.default.moveItem(at: written, to: target)
                last = target
            } catch {
                last = written
            }
        }
        return last
    }
}

/// Account dependencies for hosting plan screens (router, toasts; storage paths resolve to the sample photos).
@MainActor
enum PlansTestDependencies {
    static func make(router: AppRouter = AppRouter(parser: .init(universalLinkHosts: []))) -> AccountDependencies {
        let suite = "plans.tests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let data = InMemoryAccountData(signedIn: PlansFixture.me)
        return AccountDependencies.live(
            data: data,
            router: router,
            configuration: AppConfiguration(),
            notifications: StaticNotificationAuthorizer(status: .granted),
            purchases: InMemoryPurchases(),
            liveActivity: LiveActivityPreference(defaults: defaults),
            refusals: InMemoryAgeGateRefusalStore(),
            onboarding: OnboardingRecord(defaults: defaults)
        )
    }
}
