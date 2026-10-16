// Account group — the data seam of every account screen (also compiled into the App Clip).
// Reads and writes go through AppData only (docs/SCREENS_BRIEF.md rule 5); this protocol exists so view models can be
// tested with `InMemoryAccountData` (DEBUG) instead of a live Supabase project.
import AppData
import AppModels
import Foundation

/// Everything the account surfaces read and write. `LiveAccountData` implements it with AppData's `DataEnvironment`.
/// Errors are `DataError` (screens map them to copy keys).
@MainActor
protocol AccountDataSource: AnyObject, Sendable {
    // MARK: Session and connectivity

    /// The signed-in user (stored session; it may be refreshed on the next request).
    var currentUserID: UserID? { get }
    /// The current auth state, then every change (sign-out, account deletion, expired session).
    func authStates() -> AsyncStream<AuthState>
    var networkStatus: NetworkStatus { get }
    /// The current reachability, then every change.
    func networkUpdates() -> AsyncStream<NetworkStatus>

    // MARK: Sign-in and onboarding (docs/API.md §2)

    /// `signInWithOTP` (E.164 number). `displayName` becomes `profiles.display_name` for a new account.
    func sendCode(phone: String, displayName: String?) async throws
    /// `verifyOTP(type: .sms)`; starts the session.
    func verifyCode(phone: String, code: String) async throws -> UserID
    /// `confirm_age(p_birthdate)`.
    func confirmAge(birthdate: LocalDate) async throws
    /// `set_birthday(p_birthday, p_opt_in)`.
    func setBirthday(_ birthday: LocalDate, optIn: Bool) async throws
    func myProfile() async throws -> Profile
    func myPrivateProfile() async throws -> ProfilePrivate?
    func updateProfile(displayName: String?, avatarPath: String?) async throws -> Profile
    /// Clears `profiles.avatar_path` (settings.account "Remove Profile Photo").
    func removeAvatar() async throws -> Profile
    /// Uploads `avatars/<uid>/<uuid>.jpg`; returns its path.
    func uploadAvatar(jpeg: Data) async throws -> String
    /// `public_app_config` (readable signed out).
    func publicConfig() async throws -> PublicAppConfig
    /// `unregister_device`, `auth.signOut()`, then every local copy is cleared.
    func signOut() async
    /// `delete_account`, sign-out, local data cleared.
    func deleteAccount() async throws

    // MARK: Groups (§5.3–5.5, §6.1)

    func myGroups() async throws -> [PhotoGroup]
    func cachedGroups() async -> [PhotoGroup]?
    func group(id: GroupID) async throws -> PhotoGroup?
    func members(groupID: GroupID) async throws -> [MemberProfile]
    func cachedMembers(groupID: GroupID) async -> [MemberProfile]?
    /// The caller's own membership row (role, mute).
    func myMembership(groupID: GroupID) async throws -> GroupMember?
    func createGroup(name: String, kind: GroupKind, coverPath: String?) async throws -> PhotoGroup
    func updateGroup(id: GroupID, name: String?, kind: GroupKind?, cover: CoverChange) async throws -> PhotoGroup
    /// Uploads `u/<uid>/covers/<uuid>.jpg`; returns its path.
    func uploadCover(jpeg: Data) async throws -> String
    func setMuted(groupID: GroupID, muted: Bool) async throws
    func setInvitationHours(groupID: GroupID, start: LocalTime?, end: LocalTime?) async throws -> PhotoGroup
    func setInvitationPaused(groupID: GroupID, paused: Bool) async throws -> PhotoGroup
    func leaveGroup(id: GroupID) async throws
    func removeMember(groupID: GroupID, userID: UserID) async throws
    func activeInvites(groupID: GroupID) async throws -> [GroupInvite]
    func createInvite(groupID: GroupID) async throws -> GroupInvite
    func revokeInvite(token: String) async throws
    func joinGroup(token: String) async throws -> PhotoGroup
    /// `invite_preview` (text only: non-members cannot sign the image paths).
    func invitePreview(token: String) async throws -> InvitePreview

    // MARK: Photos (§5.8, §7, §8)

    /// A page of the group's feed, newest first (the first page is cached for offline use).
    func feed(groupID: GroupID, before: Date?) async throws -> Page<PostWithMedia>
    func cachedFeed(groupID: GroupID) async -> [PostWithMedia]?
    /// The group's newest post with its media (home list subtitle and cover); nil when it has none.
    func newestPost(groupID: GroupID) async throws -> PostWithMedia?
    func profiles(ids: [UserID]) async throws -> [Profile]
    /// The newest weekly recap (`groups.screen` recap circle).
    func latestRecap(groupID: GroupID) async throws -> WeeklyRecap?
    /// Realtime inserts, updates and deletions of the group (shared channels, §8).
    func groupEvents(groupID: GroupID) -> AsyncStream<GroupEvent>
    /// A signed URL for a storage path (1 h, cached).
    func signedURL(path: String) async throws -> URL

    // MARK: Safety (§5.6, §6.3)

    func blocked() async throws -> [Block]
    func block(userID: UserID) async throws
    func unblock(userID: UserID) async throws
    func report(kind: ReportTargetKind, targetID: String, reason: String) async throws

    // MARK: Settings (§5.21, §5.22)

    func notificationSettings() async throws -> NotificationSettings?
    /// `set_quiet_hours` with the device's zone; both nil = no quiet hours.
    func setQuietHours(start: LocalTime?, end: LocalTime?) async throws
    func hasPremium() async throws -> Bool
}

/// `AccountDataSource` over AppData. With a nil environment (config/app.json has no Supabase URL / anon key yet,
/// BLOCKED) every call fails with `DataError.notConfigured` and the screens show their error states.
@MainActor
final class LiveAccountData: AccountDataSource {
    let environment: DataEnvironment?

    init(environment: DataEnvironment?) {
        self.environment = environment
    }

    private func env() throws -> DataEnvironment {
        guard let environment else { throw DataError.notConfigured }
        return environment
    }

    // MARK: Session

    var currentUserID: UserID? { environment?.auth.currentUserID }

    func authStates() -> AsyncStream<AuthState> {
        environment?.auth.authStates() ?? AsyncStream<AuthState> { $0.finish() }
    }

    var networkStatus: NetworkStatus { environment?.reachability.currentStatus ?? .unknown }

    func networkUpdates() -> AsyncStream<NetworkStatus> {
        environment?.reachability.updates() ?? AsyncStream<NetworkStatus> { $0.finish() }
    }

    // MARK: Sign-in and onboarding

    func sendCode(phone: String, displayName: String?) async throws {
        let auth = try env().auth
        try await auth.signInWithOTP(phone: phone, displayName: displayName)
    }

    func verifyCode(phone: String, code: String) async throws -> UserID {
        let auth = try env().auth
        return try await auth.verifyOTP(phone: phone, token: code)
    }

    func confirmAge(birthdate: LocalDate) async throws {
        let auth = try env().auth
        _ = try await auth.confirmAge(birthdate: birthdate)
    }

    func setBirthday(_ birthday: LocalDate, optIn: Bool) async throws {
        let birthdays = try env().birthdays
        _ = try await birthdays.setBirthday(birthday, optIn: optIn)
    }

    func myProfile() async throws -> Profile {
        let profiles = try env().profiles
        return try await profiles.myProfile()
    }

    func myPrivateProfile() async throws -> ProfilePrivate? {
        let profiles = try env().profiles
        return try await profiles.myPrivateProfile()
    }

    func updateProfile(displayName: String?, avatarPath: String?) async throws -> Profile {
        let profiles = try env().profiles
        return try await profiles.updateProfile(displayName: displayName, avatarPath: avatarPath)
    }

    func removeAvatar() async throws -> Profile {
        let profiles = try env().profiles
        return try await profiles.removeAvatar()
    }

    func uploadAvatar(jpeg: Data) async throws -> String {
        let uploader = try env().uploader
        return try await uploader.uploadAvatar(jpeg: jpeg)
    }

    func publicConfig() async throws -> PublicAppConfig {
        let account = try env().account
        return try await account.publicConfig()
    }

    func signOut() async {
        guard let coordinator = environment?.coordinator else { return }
        await coordinator.signOut()
    }

    func deleteAccount() async throws {
        let coordinator = try env().coordinator
        try await coordinator.deleteAccount()
    }

    // MARK: Groups

    func myGroups() async throws -> [PhotoGroup] {
        let groups = try env().groups
        return try await groups.myGroups()
    }

    func cachedGroups() async -> [PhotoGroup]? {
        guard let groups = environment?.groups else { return nil }
        return await groups.cachedGroups()?.value
    }

    func group(id: GroupID) async throws -> PhotoGroup? {
        let groups = try env().groups
        return try await groups.group(id: id)
    }

    func members(groupID: GroupID) async throws -> [MemberProfile] {
        let groups = try env().groups
        return try await groups.members(groupID: groupID)
    }

    func cachedMembers(groupID: GroupID) async -> [MemberProfile]? {
        guard let groups = environment?.groups else { return nil }
        return await groups.cachedMembers(groupID: groupID)?.value
    }

    func myMembership(groupID: GroupID) async throws -> GroupMember? {
        let groups = try env().groups
        return try await groups.myMembership(groupID: groupID)
    }

    func createGroup(name: String, kind: GroupKind, coverPath: String?) async throws -> PhotoGroup {
        let groups = try env().groups
        return try await groups.create(name: name, kind: kind, coverPath: coverPath)
    }

    func updateGroup(id: GroupID, name: String?, kind: GroupKind?, cover: CoverChange) async throws -> PhotoGroup {
        let groups = try env().groups
        return try await groups.update(groupID: id, name: name, kind: kind, cover: cover)
    }

    func uploadCover(jpeg: Data) async throws -> String {
        let uploader = try env().uploader
        return try await uploader.uploadCover(jpeg: jpeg)
    }

    func setMuted(groupID: GroupID, muted: Bool) async throws {
        let groups = try env().groups
        try await groups.setMuted(groupID: groupID, muted: muted)
    }

    func setInvitationHours(groupID: GroupID, start: LocalTime?, end: LocalTime?) async throws -> PhotoGroup {
        let groups = try env().groups
        return try await groups.setInvitationHours(groupID: groupID, start: start, end: end)
    }

    func setInvitationPaused(groupID: GroupID, paused: Bool) async throws -> PhotoGroup {
        let groups = try env().groups
        return try await groups.setInvitationPaused(groupID: groupID, paused: paused)
    }

    func leaveGroup(id: GroupID) async throws {
        let groups = try env().groups
        try await groups.leave(groupID: id)
    }

    func removeMember(groupID: GroupID, userID: UserID) async throws {
        let groups = try env().groups
        try await groups.removeMember(groupID: groupID, userID: userID)
    }

    func activeInvites(groupID: GroupID) async throws -> [GroupInvite] {
        let groups = try env().groups
        return try await groups.activeInvites(groupID: groupID)
    }

    func createInvite(groupID: GroupID) async throws -> GroupInvite {
        let groups = try env().groups
        return try await groups.createInvite(groupID: groupID)
    }

    func revokeInvite(token: String) async throws {
        let groups = try env().groups
        try await groups.revokeInvite(token: token)
    }

    func joinGroup(token: String) async throws -> PhotoGroup {
        let groups = try env().groups
        return try await groups.join(token: token)
    }

    func invitePreview(token: String) async throws -> InvitePreview {
        let groups = try env().groups
        return try await groups.invitePreview(token: token)
    }

    // MARK: Photos

    func feed(groupID: GroupID, before: Date?) async throws -> Page<PostWithMedia> {
        let posts = try env().posts
        return try await posts.feed(groupID: groupID, before: before)
    }

    func cachedFeed(groupID: GroupID) async -> [PostWithMedia]? {
        guard let posts = environment?.posts else { return nil }
        return await posts.cachedFeed(groupID: groupID)?.value
    }

    func newestPost(groupID: GroupID) async throws -> PostWithMedia? {
        let posts = try env().posts
        // `page`, not `feed`: a one-post read must not replace the group's cached first feed page.
        let page = try await posts.page(groupID: groupID, before: nil, limit: 1)
        return try await posts.withMedia(page.items).first
    }

    func profiles(ids: [UserID]) async throws -> [Profile] {
        let profiles = try env().profiles
        return try await profiles.profiles(ids: ids)
    }

    func latestRecap(groupID: GroupID) async throws -> WeeklyRecap? {
        let memories = try env().memories
        return try await memories.recaps(groupID: groupID, limit: 1).first
    }

    func groupEvents(groupID: GroupID) -> AsyncStream<GroupEvent> {
        environment?.realtime.events(for: groupID, filter: .all) ?? AsyncStream<GroupEvent> { $0.finish() }
    }

    func signedURL(path: String) async throws -> URL {
        let signedURLs = try env().signedURLs
        return try await signedURLs.url(for: path)
    }

    // MARK: Safety

    func blocked() async throws -> [Block] {
        let safety = try env().safety
        return try await safety.blocked()
    }

    func block(userID: UserID) async throws {
        let safety = try env().safety
        try await safety.block(userID: userID)
    }

    func unblock(userID: UserID) async throws {
        let safety = try env().safety
        try await safety.unblock(userID: userID)
    }

    func report(kind: ReportTargetKind, targetID: String, reason: String) async throws {
        let safety = try env().safety
        _ = try await safety.report(kind, targetID: targetID, reason: reason)
    }

    // MARK: Settings

    func notificationSettings() async throws -> NotificationSettings? {
        let account = try env().account
        return try await account.notificationSettings()
    }

    func setQuietHours(start: LocalTime?, end: LocalTime?) async throws {
        let account = try env().account
        _ = try await account.setQuietHours(start: start, end: end)
    }

    func hasPremium() async throws -> Bool {
        let account = try env().account
        return try await account.hasPremium()
    }
}
