// Account group — DEBUG-only in-memory `AccountDataSource` for unit tests, snapshot tests and UI tests (launch argument
// `-account-ui-test-scenario <name>`, AccountUITestScenario.swift). Holds rows like the database would and records
// every call; `failures` makes a call throw.
#if DEBUG
import AppData
import AppModels
import Foundation

@MainActor
final class InMemoryAccountData: AccountDataSource {
    /// The SMS code `verifyCode` accepts.
    static let validCode = "123456" // provenance-ok: test fixture, not user-facing

    var currentUserID: UserID?
    var networkStatus: NetworkStatus = .online
    var profilesByID: [UserID: Profile] = [:]
    var privateProfile: ProfilePrivate?
    var config = PublicAppConfig(maxGroupMembers: 30, minAgeYears: 13)
    var groups: [PhotoGroup] = []
    var membersByGroup: [GroupID: [MemberProfile]] = [:]
    var postsByGroup: [GroupID: [PostWithMedia]] = [:]
    var invites: [GroupInvite] = []
    var blocks: [Block] = []
    var settings: NotificationSettings?
    var premium = false
    var recaps: [GroupID: WeeklyRecap] = [:]
    /// Ready same-moment collages by group (`group_collages`).
    var collagesByGroup: [GroupID: [GroupCollage]] = [:]
    /// Calls that throw: method name → error.
    var failures: [String: DataError] = [:]
    /// Every call, in order (method name).
    private(set) var calls: [String] = []
    /// Waits before answering (lets tests observe in-flight states).
    var latency: Duration?

    private var authContinuations: [AsyncStream<AuthState>.Continuation] = []
    private var eventContinuations: [GroupID: [AsyncStream<GroupEvent>.Continuation]] = [:]
    private let now = Date(timeIntervalSince1970: 1_792_000_000)

    /// The fixture clock every row's time is relative to (screens that depend on "now", e.g. groups.screen's week).
    var clock: Date { now }
    private var nextID = 1

    init(signedIn user: UserID? = nil) {
        currentUserID = user
    }

    // MARK: Helpers

    private func record(_ name: String) async throws {
        calls.append(name)
        if let latency { try? await Task.sleep(for: latency) }
        if let failure = failures[name] { throw failure }
    }

    private func makeID() -> String {
        nextID += 1
        return "00000000-0000-4000-8000-" + String(format: "%012d", nextID) // provenance-ok: test fixture id
    }

    private func requireUser() throws -> UserID {
        guard let currentUserID else { throw DataError.api(.notAuthenticated) }
        return currentUserID
    }

    func emit(_ event: GroupEvent, groupID: GroupID) {
        eventContinuations[groupID]?.forEach { $0.yield(event) }
    }

    func setAuth(_ state: AuthState) {
        currentUserID = state.userID
        authContinuations.forEach { $0.yield(state) }
    }

    @discardableResult
    func addProfile(_ name: String, id: UserID? = nil, avatarPath: String? = nil) -> Profile {
        let profile = Profile(id: id ?? UserID(makeID()), displayName: name, avatarPath: avatarPath, createdAt: now, updatedAt: now)
        profilesByID[profile.id] = profile
        return profile
    }

    @discardableResult
    func addGroup(_ name: String, kind: GroupKind = .friends, createdBy: UserID?, members: [Profile], coverPath: String? = nil) -> PhotoGroup {
        let group = PhotoGroup(
            id: GroupID(makeID()), name: name, kind: kind, coverPath: coverPath, timeZone: "UTC", // provenance-ok: test fixture
            wakingStart: nil, wakingEnd: nil, invitationPaused: false, createdBy: createdBy,
            createdAt: now, updatedAt: now
        )
        groups.append(group)
        membersByGroup[group.id] = members.enumerated().map { index, profile in
            MemberProfile(
                member: GroupMember(groupID: group.id, userID: profile.id, role: profile.id == createdBy ? .admin : .member,
                                    muted: false, joinedAt: now.addingTimeInterval(TimeInterval(index * 60))),
                profile: profile
            )
        }
        return group
    }

    @discardableResult
    func addPost(groupID: GroupID, author: UserID, minutesAgo: Int, caption: String? = nil) -> PostWithMedia {
        let mediaID = MediaID(makeID())
        let created = now.addingTimeInterval(TimeInterval(-minutesAgo * 60))
        let post = Post(id: PostID(makeID()), mediaID: mediaID, groupID: groupID, authorID: author, caption: caption, createdAt: created)
        let media = Media(id: mediaID, ownerID: author, kind: .photo, originalPath: "u/" + author.rawValue + "/" + mediaID.rawValue + "/original.jpg", createdAt: created)
        let item = PostWithMedia(post: post, media: media)
        postsByGroup[groupID, default: []].append(item)
        postsByGroup[groupID]?.sort { $0.post.createdAt > $1.post.createdAt }
        return item
    }

    // MARK: Session

    func authStates() -> AsyncStream<AuthState> {
        let (stream, continuation) = AsyncStream<AuthState>.makeStream()
        continuation.yield(currentUserID.map(AuthState.signedIn) ?? .signedOut)
        authContinuations.append(continuation)
        return stream
    }

    func networkUpdates() -> AsyncStream<NetworkStatus> {
        let (stream, continuation) = AsyncStream<NetworkStatus>.makeStream()
        continuation.yield(networkStatus)
        return stream
    }

    // MARK: Sign-in and onboarding

    var sentCodes: [String] = []

    func sendCode(phone: String, displayName: String?) async throws {
        try await record("sendCode")
        sentCodes.append(phone)
    }

    func verifyCode(phone: String, code: String) async throws -> UserID {
        try await record("verifyCode")
        guard code == Self.validCode else { throw DataError.auth(.invalidOTP) }
        let user = currentUserID ?? UserID(makeID())
        if profilesByID[user] == nil { addProfile("", id: user) }
        currentUserID = user
        return user
    }

    func confirmAge(birthdate: LocalDate) async throws {
        try await record("confirmAge")
        let user = try requireUser()
        privateProfile = ProfilePrivate(userID: user, birthday: privateProfile?.birthday, birthdayOptIn: privateProfile?.birthdayOptIn ?? false,
                                        ageConfirmedAt: now, updatedAt: now)
    }

    func setBirthday(_ birthday: LocalDate, optIn: Bool) async throws {
        try await record("setBirthday")
        let user = try requireUser()
        privateProfile = ProfilePrivate(userID: user, birthday: birthday, birthdayOptIn: optIn, ageConfirmedAt: privateProfile?.ageConfirmedAt, updatedAt: now)
    }

    func myProfile() async throws -> Profile {
        try await record("myProfile")
        let user = try requireUser()
        return profilesByID[user] ?? addProfile("", id: user)
    }

    func myPrivateProfile() async throws -> ProfilePrivate? {
        try await record("myPrivateProfile")
        return privateProfile
    }

    func updateProfile(displayName: String?, avatarPath: String?) async throws -> Profile {
        try await record("updateProfile")
        let user = try requireUser()
        var profile = profilesByID[user] ?? addProfile("", id: user)
        if let displayName { profile.displayName = displayName }
        if let avatarPath { profile.avatarPath = avatarPath }
        profilesByID[user] = profile
        return profile
    }

    func removeAvatar() async throws -> Profile {
        try await record("removeAvatar")
        let user = try requireUser()
        var profile = profilesByID[user] ?? addProfile("", id: user)
        profile.avatarPath = nil
        profilesByID[user] = profile
        return profile
    }

    func uploadAvatar(jpeg: Data) async throws -> String {
        try await record("uploadAvatar")
        return "avatars/" + (try requireUser()).rawValue + "/" + makeID() + ".jpg"
    }

    func publicConfig() async throws -> PublicAppConfig {
        try await record("publicConfig")
        return config
    }

    func signOut() async {
        calls.append("signOut")
        setAuth(.signedOut)
    }

    func deleteAccount() async throws {
        try await record("deleteAccount")
        setAuth(.signedOut)
    }

    // MARK: Groups

    func myGroups() async throws -> [PhotoGroup] {
        try await record("myGroups")
        return groups
    }

    func cachedGroups() async -> [PhotoGroup]? { nil }

    func group(id: GroupID) async throws -> PhotoGroup? {
        try await record("group")
        return groups.first { $0.id == id }
    }

    func members(groupID: GroupID) async throws -> [MemberProfile] {
        try await record("members")
        return membersByGroup[groupID] ?? []
    }

    func cachedMembers(groupID: GroupID) async -> [MemberProfile]? { nil }

    func myMembership(groupID: GroupID) async throws -> GroupMember? {
        try await record("myMembership")
        return membersByGroup[groupID]?.first { $0.member.userID == currentUserID }?.member
    }

    func createGroup(name: String, kind: GroupKind, coverPath: String?) async throws -> PhotoGroup {
        try await record("createGroup")
        let user = try requireUser()
        return addGroup(name, kind: kind, createdBy: user, members: [profilesByID[user] ?? addProfile("", id: user)], coverPath: coverPath)
    }

    func updateGroup(id: GroupID, name: String?, kind: GroupKind?, cover: CoverChange) async throws -> PhotoGroup {
        try await record("updateGroup")
        guard let index = groups.firstIndex(where: { $0.id == id }) else { throw DataError.api(.notGroupMember) }
        if let name { groups[index].name = name }
        if let kind { groups[index].kind = kind }
        switch cover {
        case .unchanged: break
        case .remove: groups[index].coverPath = nil
        case let .set(path): groups[index].coverPath = path
        }
        return groups[index]
    }

    func uploadCover(jpeg: Data) async throws -> String {
        try await record("uploadCover")
        return "u/" + (try requireUser()).rawValue + "/covers/" + makeID() + ".jpg"
    }

    func setMuted(groupID: GroupID, muted: Bool) async throws {
        try await record("setMuted")
        guard let index = membersByGroup[groupID]?.firstIndex(where: { $0.member.userID == currentUserID }) else { return }
        membersByGroup[groupID]?[index].member.muted = muted
    }

    func setInvitationHours(groupID: GroupID, start: LocalTime?, end: LocalTime?) async throws -> PhotoGroup {
        try await record("setInvitationHours")
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { throw DataError.api(.notGroupMember) }
        groups[index].wakingStart = start
        groups[index].wakingEnd = end
        return groups[index]
    }

    func setInvitationPaused(groupID: GroupID, paused: Bool) async throws -> PhotoGroup {
        try await record("setInvitationPaused")
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { throw DataError.api(.notGroupMember) }
        groups[index].invitationPaused = paused
        return groups[index]
    }

    func leaveGroup(id: GroupID) async throws {
        try await record("leaveGroup")
        groups.removeAll { $0.id == id }
    }

    func removeMember(groupID: GroupID, userID: UserID) async throws {
        try await record("removeMember")
        membersByGroup[groupID]?.removeAll { $0.member.userID == userID }
    }

    func activeInvites(groupID: GroupID) async throws -> [GroupInvite] {
        try await record("activeInvites")
        return invites.filter { $0.groupID == groupID && $0.isUsable(at: now) }
    }

    func createInvite(groupID: GroupID) async throws -> GroupInvite {
        try await record("createInvite")
        let invite = GroupInvite(id: InviteID(makeID()), groupID: groupID, token: "tok" + String(nextID), createdBy: try requireUser(), // provenance-ok: test fixture token
                                 createdAt: now, expiresAt: nil, revokedAt: nil)
        invites.append(invite)
        return invite
    }

    func revokeInvite(token: String) async throws {
        try await record("revokeInvite")
        if let index = invites.firstIndex(where: { $0.token == token }) { invites[index].revokedAt = now }
    }

    func joinGroup(token: String) async throws -> PhotoGroup {
        try await record("joinGroup")
        guard let invite = invites.first(where: { $0.token == token }),
              let group = groups.first(where: { $0.id == invite.groupID }) else { throw DataError.api(.inviteNotFound) }
        return group
    }

    func invitePreview(token: String) async throws -> InvitePreview {
        try await record("invitePreview")
        guard let invite = invites.first(where: { $0.token == token }),
              let group = groups.first(where: { $0.id == invite.groupID }) else { throw DataError.api(.inviteNotFound) }
        let members = (membersByGroup[group.id] ?? []).map { InvitePreview.Member(firstName: $0.profile?.firstName, avatarPath: $0.profile?.avatarPath) }
        let inviter = profilesByID[invite.createdBy]
        return InvitePreview(groupName: group.name, groupKind: group.kind, coverPath: group.coverPath,
                             inviterFirstName: inviter?.firstName, members: members, inviterAvatarPath: inviter?.avatarPath)
    }

    // MARK: Photos

    func feed(groupID: GroupID, before: Date?) async throws -> Page<PostWithMedia> {
        try await record("feed")
        let all = postsByGroup[groupID] ?? []
        let items = all.filter { before == nil || $0.post.createdAt < before! }
        let page = Array(items.prefix(PostRepository.pageSize))
        return Page(items: page, nextCursor: page.count == PostRepository.pageSize ? page.last?.post.createdAt : nil)
    }

    func cachedFeed(groupID: GroupID) async -> [PostWithMedia]? { nil }

    func newestPost(groupID: GroupID) async throws -> PostWithMedia? {
        try await record("newestPost")
        return postsByGroup[groupID]?.first
    }

    func profiles(ids: [UserID]) async throws -> [Profile] {
        try await record("profiles")
        return ids.compactMap { profilesByID[$0] }
    }

    func latestRecap(groupID: GroupID) async throws -> WeeklyRecap? {
        try await record("latestRecap")
        return recaps[groupID]
    }

    func groupCollages(groupID: GroupID, from: LocalDate, to: LocalDate) async throws -> [GroupCollage] {
        try await record("groupCollages")
        return (collagesByGroup[groupID] ?? [])
            .filter { $0.localDate >= from && $0.localDate <= to }
            .sorted { $0.localDate > $1.localDate }
    }

    func groupEvents(groupID: GroupID) -> AsyncStream<GroupEvent> {
        let (stream, continuation) = AsyncStream<GroupEvent>.makeStream()
        eventContinuations[groupID, default: []].append(continuation)
        return stream
    }

    func signedURL(path: String) async throws -> URL {
        try await record("signedURL")
        // The Jolt demo build carries the photos its world names (`DemoPhotos`).
        if let url = DemoPhotos.url(for: path) { return url }
        throw DataError.storage(.notFound)
    }

    // MARK: Safety

    func blocked() async throws -> [Block] {
        try await record("blocked")
        return blocks
    }

    func block(userID: UserID) async throws {
        try await record("block")
        blocks.append(Block(blockerID: try requireUser(), blockedID: userID, createdAt: now))
    }

    func unblock(userID: UserID) async throws {
        try await record("unblock")
        blocks.removeAll { $0.blockedID == userID }
    }

    var reports: [(kind: ReportTargetKind, id: String, reason: String)] = []

    func report(kind: ReportTargetKind, targetID: String, reason: String) async throws {
        try await record("report")
        reports.append((kind, targetID, reason))
    }

    // MARK: Settings

    func notificationSettings() async throws -> NotificationSettings? {
        try await record("notificationSettings")
        return settings
    }

    func setQuietHours(start: LocalTime?, end: LocalTime?) async throws {
        try await record("setQuietHours")
        settings = NotificationSettings(
            userID: try requireUser(), quietStart: start, quietEnd: end, timeZone: "UTC", updatedAt: now, // provenance-ok: test fixture
            overnight: settings?.overnight ?? true
        )
    }

    func setOvernightAlerts(_ on: Bool) async throws {
        try await record("setOvernightAlerts")
        settings = NotificationSettings(
            userID: try requireUser(), quietStart: settings?.quietStart, quietEnd: settings?.quietEnd,
            timeZone: settings?.timeZone, updatedAt: now, overnight: on
        )
    }

    func hasPremium() async throws -> Bool {
        try await record("hasPremium")
        return premium
    }
}

/// Fixed plans for paywall tests and UI-test scenarios (no store).
@MainActor
final class InMemoryPurchases: PurchasesProviding {
    var isPremium = false
    var plansResult: Result<[PlanOption], PurchasesFailure> = .success([])
    var purchaseResult: Result<PurchaseResult, PurchasesFailure> = .success(.purchased)
    var restoreResult: Result<Bool, PurchasesFailure> = .success(false)

    func plans() async throws -> [PlanOption] { try plansResult.get() }

    func purchase(_ plan: PlanOption) async throws -> PurchaseResult {
        let result = try purchaseResult.get()
        if result == .purchased { isPremium = true }
        return result
    }

    func restore() async throws -> Bool { try restoreResult.get() }
}
#endif
