// Account group — groups view models: groups.list (GroupsListModel), groups.screen (GroupFeedModel), groups.create
// (GroupCreateModel), groups.invite (GroupInviteModel), groups.settings (GroupSettingsModel) and the in-app invite join
// (InviteJoinModel, InvitePreviewLoader, InviteHandoff).
@testable import App
import AppData
import AppModels
import DesignSystem
import XCTest

@MainActor
final class AccountGroupsTests: XCTestCase {
    // MARK: groups.list

    func testGroupsListGoesFromLoadingToLoadedWithoutAnEmptyFrame() async {
        let fixture = AccountFixture()
        fixture.familyGroup(posts: 2)
        fixture.data.latency = .milliseconds(20)
        let model = GroupsListModel(data: fixture.data)
        let phases = await recordStates(of: { model.phase }, during: { await model.load() })
        XCTAssertEqual(phases, [.loading, .loaded])
        XCTAssertEqual(model.rows.count, 1)
        model.stop()
    }

    func testGroupsListEmptyErrorAndOfflineStates() async {
        let fixture = AccountFixture()
        let empty = GroupsListModel(data: fixture.data)
        await empty.load()
        XCTAssertEqual(empty.phase, .empty)

        fixture.data.failures["myGroups"] = .offline
        let offline = GroupsListModel(data: fixture.data)
        await offline.load()
        XCTAssertEqual(offline.phase, .offline)

        fixture.data.failures["myGroups"] = .http(status: 500)
        let failing = GroupsListModel(data: fixture.data)
        await failing.load()
        XCTAssertEqual(failing.phase, .error)

        fixture.data.failures = [:]
        fixture.familyGroup()
        await failing.retry()
        XCTAssertEqual(failing.phase, .loaded)
        failing.stop()
    }

    func testGroupsListKeepsRowsWhenARefreshFails() async {
        let fixture = AccountFixture()
        fixture.familyGroup(posts: 1)
        let model = GroupsListModel(data: fixture.data)
        await model.load()
        fixture.data.failures["myGroups"] = .offline
        await model.refresh()
        XCTAssertEqual(model.phase, .loaded, "cached rows stay; no error screen over them")
        XCTAssertEqual(model.rows.count, 1)
        model.stop()
    }

    func testGroupsListRowsShowTheNewestPostAndItsSender() async {
        let fixture = AccountFixture()
        let family = fixture.familyGroup()
        let quiet = fixture.data.addGroup("Book club", createdBy: fixture.me.id, members: [fixture.me])
        // Posted after both groups were created (a group without photos sorts by its creation time).
        fixture.data.addPost(groupID: family.id, author: fixture.rui.id, minutesAgo: -3)
        let model = GroupsListModel(data: fixture.data)
        await model.load()
        XCTAssertEqual(model.rows.map(\.group.id), [family.id, quiet.id], "most recent activity first")
        XCTAssertEqual(model.rows.first?.senderFirstName, "Rui")
        XCTAssertEqual(model.rows.first?.isOwnPost, false)
        XCTAssertNil(model.rows.last?.newest)
        XCTAssertEqual(model.rows.last?.isCreatedByMe, true, "a group without photos: 'Created by you'")
        XCTAssertEqual(model.myFirstName, "Ana")
        model.stop()
    }

    func testGroupsListUpdatesARowOnARealtimePost() async {
        let fixture = AccountFixture()
        let family = fixture.familyGroup()
        let model = GroupsListModel(data: fixture.data)
        await model.load()
        XCTAssertNil(model.rows.first?.newest)
        let post = fixture.data.addPost(groupID: family.id, author: fixture.me.id, minutesAgo: 0)
        await model.handle(.postInserted(post.post), groupID: family.id)
        XCTAssertEqual(model.rows.first?.newest?.id, post.id)
        XCTAssertEqual(model.rows.first?.isOwnPost, true)
        model.stop()
    }

    // MARK: groups.screen

    func testFeedGoesFromLoadingToLoadedWithoutAnEmptyFrame() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup(posts: 3)
        fixture.data.latency = .milliseconds(20)
        let model = GroupFeedModel(groupID: group.id, data: fixture.data)
        let phases = await recordStates(of: { model.phase }, during: { await model.load() })
        XCTAssertEqual(phases, [.loading, .loaded])
        XCTAssertEqual(model.posts.count, 3)
        model.stop()
    }

    func testFeedCreatedEmptyRemovedAndOfflineStates() async {
        let fixture = AccountFixture()
        let mine = fixture.familyGroup()
        let created = GroupFeedModel(groupID: mine.id, data: fixture.data)
        await created.refresh()
        XCTAssertEqual(created.phase, .created, "the creator's new group")
        XCTAssertTrue(created.isCreator)
        XCTAssertTrue(created.isAdmin)

        let theirs = fixture.data.addGroup("Sunday dinners", createdBy: fixture.rui.id, members: [fixture.rui, fixture.me])
        let empty = GroupFeedModel(groupID: theirs.id, data: fixture.data)
        await empty.refresh()
        XCTAssertEqual(empty.phase, .empty)

        let removed = GroupFeedModel(groupID: GroupID("00000000-0000-4000-8000-999999999999"), data: fixture.data)
        await removed.refresh()
        XCTAssertEqual(removed.phase, .removed)

        fixture.data.failures["group"] = .offline
        let offline = GroupFeedModel(groupID: theirs.id, data: fixture.data)
        await offline.refresh()
        XCTAssertEqual(offline.phase, .offline)

        fixture.data.failures["group"] = .api(.notGroupMember)
        await offline.refresh()
        XCTAssertEqual(offline.phase, .removed)
    }

    func testFeedPagesAndInsertsNewPostsAtTheTop() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup(posts: PostRepository.pageSize + 5)
        let model = GroupFeedModel(groupID: group.id, data: fixture.data)
        await model.refresh()
        XCTAssertEqual(model.posts.count, PostRepository.pageSize)
        XCTAssertNotNil(model.nextCursor)
        await model.loadMore()
        XCTAssertEqual(model.posts.count, PostRepository.pageSize + 5)
        XCTAssertNil(model.nextCursor)

        let fresh = fixture.data.addPost(groupID: group.id, author: fixture.rui.id, minutesAgo: -1)
        await model.handle(.postInserted(fresh.post))
        XCTAssertEqual(model.posts.first?.id, fresh.id)
        XCTAssertEqual(model.insertedCount, 1)

        await model.handle(.postDeleted(postID: fresh.id, mediaID: nil))
        XCTAssertFalse(model.posts.contains { $0.id == fresh.id })
    }

    func testFeedSplitsThisWeekIntoMemberCardsAndEarlierDays() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup()
        // The fixture clock is Wednesday 14 October 2026, 17:46 UTC (ISO week 42; the group is in UTC).
        let ruiOlder = fixture.data.addPost(groupID: group.id, author: fixture.rui.id, minutesAgo: 600)
        let ruiNewest = fixture.data.addPost(groupID: group.id, author: fixture.rui.id, minutesAgo: 30)
        let anaNewest = fixture.data.addPost(groupID: group.id, author: fixture.me.id, minutesAgo: 120)
        let lastWeek = fixture.data.addPost(groupID: group.id, author: fixture.rui.id, minutesAgo: 60 * 24 * 5)
        let model = GroupFeedModel(groupID: group.id, data: fixture.data, now: { fixture.data.clock })
        await model.refresh()

        XCTAssertEqual(model.weekNumber, 42)
        XCTAssertEqual(model.thisWeekPosts.map(\.id), [ruiOlder.id, anaNewest.id, ruiNewest.id], "the strip: oldest to newest")
        XCTAssertEqual(model.memberWeeks.map(\.newest.id), [ruiNewest.id, anaNewest.id], "one card per member, newest first")
        XCTAssertEqual(model.earlierSections.count, 1)
        XCTAssertEqual(model.earlierSections.first?.posts.map(\.id), [lastWeek.id])
        XCTAssertEqual(model.remainingDaysOfWeek.count, 5, "Wednesday to Sunday")
        XCTAssertFalse(model.isQuietWeek)
        model.stop()
    }

    func testFeedShowsPhotosPostedTogetherAsOneCardAndOneCell() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup()
        let first = fixture.data.addPost(groupID: group.id, author: fixture.rui.id, minutesAgo: 32, batchID: "b1")
        fixture.data.addPost(groupID: group.id, author: fixture.rui.id, minutesAgo: 31, batchID: "B1")
        let oldFirst = fixture.data.addPost(groupID: group.id, author: fixture.rui.id, minutesAgo: 60 * 24 * 5, batchID: "b2")
        fixture.data.addPost(groupID: group.id, author: fixture.rui.id, minutesAgo: 60 * 24 * 5 - 1, batchID: "b2")
        let model = GroupFeedModel(groupID: group.id, data: fixture.data, now: { fixture.data.clock })
        await model.refresh()

        XCTAssertEqual(model.memberWeeks.map(\.newest.id), [first.id], "the card shows the batch's first photo")
        XCTAssertEqual(model.memberWeeks.map(\.isBatch), [true])
        XCTAssertEqual(model.earlierSections.flatMap(\.posts).map(\.id), [oldFirst.id], "one cell for the batch")
        XCTAssertEqual(model.earlierSections.first?.runs.first?.count, 2)
        model.stop()
    }

    func testFeedQuietWeekKeepsEarlierPhotos() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup()
        fixture.data.addPost(groupID: group.id, author: fixture.rui.id, minutesAgo: 60 * 24 * 9)
        let model = GroupFeedModel(groupID: group.id, data: fixture.data, now: { fixture.data.clock })
        await model.refresh()
        XCTAssertEqual(model.phase, .loaded)
        XCTAssertTrue(model.isQuietWeek)
        XCTAssertTrue(model.memberWeeks.isEmpty)
        XCTAssertEqual(model.earlierSections.count, 1)
        model.stop()
    }

    func testFeedDropsABlockedPersonsPosts() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup(posts: 4)
        let model = GroupFeedModel(groupID: group.id, data: fixture.data)
        await model.refresh()
        fixture.data.postsByGroup[group.id]?.removeAll { $0.post.authorID == fixture.rui.id }
        await model.blocked(fixture.rui.id)
        XCTAssertFalse(model.posts.contains { $0.post.authorID == fixture.rui.id })
    }

    // MARK: groups.create

    func testCreateGroupWithTheTrimmedNameAndKind() async {
        let fixture = AccountFixture()
        let model = GroupCreateModel(data: fixture.data)
        XCTAssertFalse(model.canSubmit)
        model.setName("  Lima family ")
        model.kind = .family
        let group = await model.submit()
        XCTAssertEqual(group?.name, "Lima family")
        XCTAssertEqual(group?.kind, .family)
        XCTAssertEqual(model.successCount, 1)
        XCTAssertFalse(fixture.data.calls.contains("uploadCover"))
    }

    func testCreateGroupFailureAndOfflineMessages() async {
        let fixture = AccountFixture()
        let model = GroupCreateModel(data: fixture.data)
        model.setName("Lima family")
        fixture.data.failures["createGroup"] = .http(status: 500)
        var group = await model.submit()
        XCTAssertNil(group)
        XCTAssertEqual(model.failureMessage, Copy.groupsCreateErrorFailed)
        fixture.data.failures["createGroup"] = .offline
        group = await model.submit()
        XCTAssertNil(group)
        XCTAssertEqual(model.failureMessage, Copy.groupsCreateOffline)
        XCTAssertEqual(model.errorCount, 2)
    }

    func testEditGroupPrefillsAndSaves() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup()
        let model = GroupCreateModel(data: fixture.data, editingGroupID: group.id)
        await model.loadForEdit()
        XCTAssertEqual(model.name, "Lima family")
        XCTAssertEqual(model.kind, .family)
        model.setName("Limas")
        let saved = await model.submit()
        XCTAssertEqual(saved?.name, "Limas")
        XCTAssertEqual(fixture.data.calls.last, "updateGroup")
    }

    func testGroupNameTooLongIsRefusedInline() {
        let model = GroupCreateModel(data: InMemoryAccountData())
        model.setName(String(repeating: "x", count: 120))
        XCTAssertEqual(model.name.count, 120, "typing is not cut: 'Name too long' shows under the field")
        XCTAssertTrue(model.isNameTooLong)
        XCTAssertFalse(model.canSubmit)
        XCTAssertEqual(GroupCreateModel.title(of: .unknown), Copy.groupsCreateTypeCustom)
    }

    func testCreateStartsAtTheTypeStepUnlessAKindWasChosen() {
        let data = InMemoryAccountData()
        let fresh = GroupCreateModel(data: data)
        XCTAssertEqual(fresh.step, .type)
        fresh.choose(.roommates)
        XCTAssertEqual(fresh.step, .details)
        XCTAssertEqual(fresh.kind, .roommates)
        fresh.backToType()
        XCTAssertEqual(fresh.step, .type)

        let fromTemplate = GroupCreateModel(data: data, kind: .family)
        XCTAssertEqual(fromTemplate.step, .details, "a groups.list template row skips step A")
        XCTAssertEqual(fromTemplate.kind, .family)
        XCTAssertEqual(GroupCreateModel.kinds, [.friends, .family, .roommates, .custom])
    }

    // MARK: groups.invite

    func testInviteCreatesOneLinkAndReusesIt() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup()
        let model = GroupInviteModel(groupID: group.id, data: fixture.data, domain: "example.test")
        await model.load()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertTrue(model.isAdmin)
        let first = await model.linkToShare()
        XCTAssertEqual(first?.absoluteString.hasPrefix("https://example.test/i/"), true)
        let second = await model.linkToShare()
        XCTAssertEqual(first, second)
        XCTAssertEqual(fixture.data.calls.filter { $0 == "createInvite" }.count, 1)
        XCTAssertTrue(model.canTurnOff)
    }

    func testInviteWithoutADomainIsTheErrorState() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup()
        let model = GroupInviteModel(groupID: group.id, data: fixture.data, domain: nil)
        await model.load()
        let link = await model.linkToShare()
        XCTAssertNil(link)
        XCTAssertEqual(model.phase, .error)
    }

    func testFullGroupShowsTheFullState() async {
        let fixture = AccountFixture()
        fixture.data.config = PublicAppConfig(maxGroupMembers: 2, minAgeYears: 13)
        let group = fixture.familyGroup()
        let model = GroupInviteModel(groupID: group.id, data: fixture.data, domain: "example.test")
        await model.load()
        XCTAssertEqual(model.phase, .full)
        XCTAssertEqual(model.maxMembers, 2)
    }

    func testTurnOffLinkIsOptimisticAndRestoresOnFailure() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup()
        let model = GroupInviteModel(groupID: group.id, data: fixture.data, domain: "example.test")
        await model.load()
        _ = await model.linkToShare()
        fixture.data.failures["revokeInvite"] = .offline
        var turnedOff = await model.turnOffLink()
        XCTAssertFalse(turnedOff)
        XCTAssertNotNil(model.invite, "restored")

        fixture.data.failures = [:]
        turnedOff = await model.turnOffLink()
        XCTAssertTrue(turnedOff)
        XCTAssertNil(model.invite)
        XCTAssertEqual(model.warningCount, 1)
    }

    func testInviteContactsAreMarkedOnceSent() {
        let model = GroupInviteModel(groupID: GroupID("g"), data: InMemoryAccountData(), domain: nil)
        let contact = LocalContact(id: "c1", displayName: "Rui Costa", phoneNumbers: [PhoneNumber("+351912345678")].compactMap { $0 })
        model.add(contact)
        model.add(contact)
        XCTAssertEqual(model.contacts.count, 1)
        model.markInvited("c1")
        XCTAssertEqual(model.invitedContactIDs, ["c1"])
        XCTAssertEqual(model.sendCount, 1)
    }

    // MARK: groups.settings

    func testSettingsLoadAndOptimisticMuteRollsBack() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup()
        let model = GroupSettingsModel(groupID: group.id, data: fixture.data, notifications: StaticNotificationAuthorizer(status: .granted))
        await model.load()
        XCTAssertFalse(model.isLoading)
        XCTAssertTrue(model.isAdmin)
        XCTAssertEqual(model.members.count, 2)

        await model.setMuted(true)
        XCTAssertTrue(model.muted)
        XCTAssertNil(model.notificationsError)

        fixture.data.failures["setMuted"] = .offline
        await model.setMuted(false)
        XCTAssertTrue(model.muted, "reverted")
        XCTAssertEqual(model.notificationsError, Copy.groupsSettingsErrorGeneric)
    }

    func testSettingsInvitationHoursAndPause() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup()
        let model = GroupSettingsModel(groupID: group.id, data: fixture.data, notifications: StaticNotificationAuthorizer(status: .denied))
        await model.load()
        XCTAssertTrue(model.systemNotificationsOff)
        XCTAssertEqual(model.invitationHoursText, Copy.groupsSettingsInvitationDefault)

        let start = LocalTime(hour: 9, minute: 0)!
        let end = LocalTime(hour: 21, minute: 0)!
        await model.setInvitationHours(start: start, end: end)
        XCTAssertEqual(model.group?.wakingStart, start)
        XCTAssertEqual(model.group?.wakingEnd, end)

        fixture.data.failures["setInvitationHours"] = .api(.invalidWakingWindow)
        await model.setInvitationHours(start: LocalTime(hour: 10, minute: 0)!, end: LocalTime(hour: 11, minute: 0)!)
        XCTAssertEqual(model.group?.wakingStart, start, "reverted")
        XCTAssertEqual(model.invitationError, Copy.groupsSettingsInvitationInvalid)

        await model.setPaused(true)
        XCTAssertTrue(model.paused)
        fixture.data.failures["setInvitationPaused"] = .offline
        await model.setPaused(false)
        XCTAssertTrue(model.paused, "reverted")
    }

    func testRemovingAMemberIsOptimistic() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup()
        let model = GroupSettingsModel(groupID: group.id, data: fixture.data, notifications: StaticNotificationAuthorizer(status: .granted))
        await model.load()
        let rui = model.members.first { $0.member.userID == fixture.rui.id }!
        fixture.data.failures["removeMember"] = .offline
        await model.remove(rui)
        XCTAssertEqual(model.members.count, 2, "restored")
        XCTAssertNotNil(model.memberError)
        fixture.data.failures = [:]
        await model.remove(rui)
        XCTAssertEqual(model.members.count, 1)
    }

    func testMakeAdminAndRemoveAsAdminAreOptimistic() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup()
        let model = GroupSettingsModel(groupID: group.id, data: fixture.data, notifications: StaticNotificationAuthorizer(status: .granted))
        await model.load()
        XCTAssertTrue(model.isAdmin)
        let rui = model.members.first { $0.member.userID == fixture.rui.id }!
        XCTAssertEqual(rui.member.role, .member)
        await model.setRole(.admin, of: rui)
        XCTAssertEqual(model.members.first { $0.id == rui.id }?.member.role, .admin)
        XCTAssertNil(model.memberError)

        let ruiAdmin = model.members.first { $0.id == rui.id }!
        fixture.data.failures["setMemberRole"] = .offline
        await model.setRole(.member, of: ruiAdmin)
        XCTAssertEqual(model.members.first { $0.id == rui.id }?.member.role, .admin, "restored")
        XCTAssertNotNil(model.memberError)
        fixture.data.failures = [:]
        await model.setRole(.member, of: ruiAdmin)
        XCTAssertEqual(model.members.first { $0.id == rui.id }?.member.role, .member)
    }

    // MARK: invite (in the app)

    func testInviteJoinFallsBackToTheRPCPreviewWithoutADomain() async {
        let fixture = AccountFixture()
        let group = fixture.familyGroup()
        let invite = try? await fixture.data.createInvite(groupID: group.id)
        let model = InviteJoinModel(token: invite?.token ?? "", data: fixture.data, loader: InvitePreviewLoader(domain: nil))
        await model.load()
        guard case let .valid(preview) = model.state else { return XCTFail("expected a preview, got \(model.state)") }
        XCTAssertEqual(preview.groupName, "Lima family")
        XCTAssertEqual(preview.inviterFirstName, "Ana")
        XCTAssertEqual(preview.members.count, 2, "storage paths stand in for the web's image URLs")
        let joined = await model.join()
        XCTAssertEqual(joined?.id, group.id)
        XCTAssertEqual(model.successCount, 1)
    }

    func testInviteJoinErrorStates() async {
        let data = InMemoryAccountData()
        let model = InviteJoinModel(token: "missing", data: data, loader: InvitePreviewLoader(domain: nil))
        await model.load()
        XCTAssertEqual(model.state, .notFound)
        XCTAssertEqual(InviteJoinModel.state(for: DataError.api(.groupFull)), .full)
        XCTAssertEqual(InviteJoinModel.state(for: DataError.api(.inviteExpired)), .unavailable)
        XCTAssertEqual(InviteJoinModel.state(for: DataError.api(.inviteRevoked)), .unavailable)
        XCTAssertEqual(InviteJoinModel.state(for: DataError.offline), .offline)
        XCTAssertEqual(InviteJoinModel.state(for: DataError.http(status: 500)), .error)
    }

    func testPreviewJSONStatesAndURL() {
        let loader = InvitePreviewLoader(domain: "example.test")
        XCTAssertEqual(loader.previewURL(token: "abc")?.absoluteString, "https://example.test/i/abc/preview.json")
        XCTAssertNil(InvitePreviewLoader(domain: nil).previewURL(token: "abc"))
        let json = Data(#"{"group_name":"Lima family","group_kind":"family","inviter_first_name":"Ana","members":[{"first_name":"Rui"}]}"#.utf8)
        guard case let .valid(preview) = InvitePreviewLoader.state(status: 200, data: json) else { return XCTFail("not decoded") }
        XCTAssertEqual(preview.members.first?.firstName, "Rui")
        XCTAssertEqual(InvitePreviewLoader.state(status: 200, data: Data("{}".utf8)), .error)
        XCTAssertEqual(InvitePreviewLoader.state(status: 404, data: Data()), .notFound)
        XCTAssertEqual(InvitePreviewLoader.state(status: 410, data: Data()), .unavailable)
        XCTAssertEqual(InvitePreviewLoader.state(status: 429, data: Data()), .rateLimited)
        XCTAssertEqual(InvitePreviewLoader.state(status: 503, data: Data()), .error)
    }

    func testAppClipHandoffIsReadOnce() throws {
        let suite = "account.tests.handoff." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        InviteHandoff(token: "tok", joinedGroupID: "g1").save(to: defaults)
        XCTAssertEqual(InviteHandoff.take(from: defaults), InviteHandoff(token: "tok", joinedGroupID: "g1"))
        XCTAssertNil(InviteHandoff.take(from: defaults))
        defaults.removePersistentDomain(forName: suite)
    }
}
