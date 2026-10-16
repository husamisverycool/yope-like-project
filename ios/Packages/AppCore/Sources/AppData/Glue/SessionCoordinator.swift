import AppModels
import Foundation

/// Push tokens collected on this device: APNs (`PushService.onDeviceToken`), the Live Activity
/// push-to-start token (`LiveActivityService.onPushToStartToken`) and the WidgetKit push token
/// (iOS 26 widget push handler, shared through `WidgetPushTokenStore`). All lowercase hex.
public struct DevicePushTokens: Codable, Hashable, Sendable {
    public var apns: String?
    public var pushToStart: String?
    public var widgetPush: String?

    public init(apns: String? = nil, pushToStart: String? = nil, widgetPush: String? = nil) {
        self.apns = apns
        self.pushToStart = pushToStart
        self.widgetPush = widgetPush
    }
}

/// What the coordinator calls outside AppData (implemented in the App target with
/// `PurchasesService` and `WidgetReloader`, which live in AppServices).
public struct SessionHooks: Sendable {
    /// RevenueCat identity: called with the user id after sign-in, nil after sign-out.
    public var linkPurchases: (@Sendable (UserID?) async -> Void)?
    /// Reload widget timelines after the widget's group list or snapshots changed.
    public var reloadWidgets: (@Sendable () async -> Void)?
    /// After sign-out, account deletion or expiry: remove the files the app keeps outside AppData for the person who
    /// was signed in (capture drafts, voice recordings, downloaded media copies, share images, collage pages).
    public var removeSessionFiles: (@Sendable () async -> Void)?

    public init(
        linkPurchases: (@Sendable (UserID?) async -> Void)? = nil,
        reloadWidgets: (@Sendable () async -> Void)? = nil,
        removeSessionFiles: (@Sendable () async -> Void)? = nil
    ) {
        self.linkPurchases = linkPurchases
        self.reloadWidgets = reloadWidgets
        self.removeSessionFiles = removeSessionFiles
    }
}

/// The glue between the signed-in session and the rest of the device:
///
/// - after sign-in: registers the device's push tokens (`register_device`), logs RevenueCat in
///   with the user id, syncs the widget's group list, resumes the post outbox;
/// - whenever a token changes: registers again with all three tokens;
/// - while running: listens to every group's private deletion topic and removes deleted posts
///   from `WidgetStore` (widget snapshots), the offline cache and signed URLs (security invariant 2);
/// - on sign-out / account deletion: unregisters the device first, then clears everything local.
public actor SessionCoordinator {
    /// The services the coordinator drives.
    public struct Services: Sendable {
        public var auth: AuthService
        public var groups: GroupRepository
        public var account: AccountRepository
        public var memories: MemoriesRepository
        public var realtime: RealtimeHub
        public var cache: OfflineCache
        public var signedURLs: SignedURLCache
        public var publisher: PostPublisher
        public var reachability: Reachability

        public init(
            auth: AuthService, groups: GroupRepository, account: AccountRepository, memories: MemoriesRepository,
            realtime: RealtimeHub, cache: OfflineCache, signedURLs: SignedURLCache, publisher: PostPublisher,
            reachability: Reachability
        ) {
            self.auth = auth
            self.groups = groups
            self.account = account
            self.memories = memories
            self.realtime = realtime
            self.cache = cache
            self.signedURLs = signedURLs
            self.publisher = publisher
            self.reachability = reachability
        }
    }

    public let environment: Services
    public let widgetStore: WidgetStore?
    public let hooks: SessionHooks

    private var tokens = DevicePushTokens()
    private var registered: (user: UserID, tokens: DevicePushTokens)?
    private var signedInUser: UserID?
    private var authTask: Task<Void, Never>?
    private var reachabilityTask: Task<Void, Never>?
    private var deletionWatchers: [GroupID: Task<Void, Never>] = [:]

    public init(services: Services, widgetStore: WidgetStore?, hooks: SessionHooks = SessionHooks()) {
        self.environment = services
        self.widgetStore = widgetStore
        self.hooks = hooks
    }

    // MARK: Lifecycle

    /// Starts following the auth state (call once at launch).
    public func start() {
        guard authTask == nil else { return }
        let states = environment.auth.authStates()
        authTask = Task { [weak self] in
            for await state in states {
                await self?.apply(state)
            }
        }
        let updates = environment.reachability.updates()
        reachabilityTask = Task { [weak self] in
            for await status in updates where status == .online {
                await self?.cameOnline()
            }
        }
    }

    public func stop() {
        authTask?.cancel()
        authTask = nil
        reachabilityTask?.cancel()
        reachabilityTask = nil
        stopDeletionWatchers()
    }

    /// Runs the signed-in setup for `userID` (also called by `start()` on every sign-in).
    public func didSignIn(_ userID: UserID) async {
        let isNewUser = signedInUser != userID
        signedInUser = userID
        if isNewUser { await hooks.linkPurchases?(userID) }
        await registerDeviceIfNeeded()
        await refreshGroups()
        await resumeOutbox()
    }

    private func apply(_ state: AuthState) async {
        switch state {
        case let .signedIn(userID):
            await didSignIn(userID)
        case .signedOut:
            if signedInUser != nil {
                signedInUser = nil
                await clearLocalData()
            }
        }
    }

    // MARK: Devices

    /// Records the device's current tokens and registers them when signed in. Pass every token
    /// you have: a nil token is cleared on the server (`register_device` semantics).
    public func updateDeviceTokens(_ tokens: DevicePushTokens) async {
        self.tokens = tokens
        await registerDeviceIfNeeded()
    }

    public var currentDeviceTokens: DevicePushTokens { tokens }

    private func registerDeviceIfNeeded() async {
        guard let user = signedInUser, let apns = tokens.apns else { return }
        if let registered, registered.user == user, registered.tokens == tokens { return }
        do {
            try await environment.account.registerDevice(
                pushToken: apns,
                pushToStartToken: tokens.pushToStart,
                widgetPushToken: tokens.widgetPush
            )
            registered = (user, tokens)
        } catch {
            // Retried on the next token change or sign-in.
        }
    }

    // MARK: Groups and widgets

    /// Reloads the caller's groups, writes the widget's group list (which also deletes the
    /// widget folders of groups the user left) and follows each group's deletion topic.
    public func refreshGroups() async {
        guard signedInUser != nil else { return }
        guard let groups = try? await environment.groups.myGroups() else { return }
        if let widgetStore {
            try? widgetStore.syncGroups(groups.map { WidgetGroup(id: $0.id.rawValue, name: $0.name) })
            await hooks.reloadWidgets?()
        }
        for group in groups where deletionWatchers[group.id] == nil {
            watchDeletions(group.id)
        }
        let current = Set(groups.map(\.id))
        for (id, task) in deletionWatchers where !current.contains(id) {
            task.cancel()
            deletionWatchers[id] = nil
            await environment.cache.removeGroup(id)
        }
    }

    private func watchDeletions(_ groupID: GroupID) {
        let events = environment.realtime.events(for: groupID, filter: .deletions)
        deletionWatchers[groupID] = Task { [weak self] in
            for await event in events {
                await self?.handle(event, groupID: groupID)
            }
        }
    }

    private func stopDeletionWatchers() {
        deletionWatchers.values.forEach { $0.cancel() }
        deletionWatchers.removeAll()
    }

    /// Applies a deletion broadcast to everything stored on the device.
    public func handle(_ event: GroupEvent, groupID: GroupID) async {
        switch event {
        case let .postDeleted(postID, mediaID):
            await environment.cache.purgePost(postID)
            if let mediaID { await environment.signedURLs.invalidate(mediaID: mediaID) }
            await removeFromWidgets(postID: postID, groupID: groupID)
        case let .messageDeleted(messageID):
            await environment.cache.purgeMessage(messageID, groupID: groupID)
        case .resubscribed:
            // Deletions may have been missed while disconnected: drop collage snapshots that may
            // show them; the next widget refresh push restores current ones.
            await removeStaleCollageSnapshot(groupID: groupID)
        default:
            break
        }
    }

    /// Removes the deleted post's widget snapshot, and the group's collage snapshot when that
    /// collage is being recomposed without it (the server clears the collage's images and sets
    /// it back to pending in the same transaction as the deletion broadcast).
    private func removeFromWidgets(postID: PostID, groupID: GroupID) async {
        guard let widgetStore else { return }
        var changed = (try? widgetStore.removeSource(postID.rawValue)) ?? false
        changed = await removeStaleCollageSnapshot(groupID: groupID) || changed
        if changed { await hooks.reloadWidgets?() }
    }

    @discardableResult
    private func removeStaleCollageSnapshot(groupID: GroupID) async -> Bool {
        guard let widgetStore,
              let snapshot = widgetStore.snapshot(groupID: groupID.rawValue, kind: .collage),
              let source = snapshot.sourceID else { return false }
        let collage = try? await environment.memories.collage(id: CollageID(source))
        let stillShown = collage.map { $0.status == .ready && $0.imagePath != nil && ($0.composedAt ?? .distantPast) <= snapshot.postedAt } ?? false
        guard !stillShown else { return false }
        return (try? widgetStore.removeSource(source)) ?? false
    }

    /// Back online: whatever failed for lack of network is retried.
    private func cameOnline() async {
        await registerDeviceIfNeeded()
        await resumeOutbox()
    }

    // MARK: Outbox

    public func resumeOutbox() async {
        guard signedInUser != nil else { return }
        await environment.publisher.resumePending()
    }

    // MARK: Signing out

    /// Unregisters the device (docs/API.md §2: before `auth.signOut()`), signs out and clears
    /// every local copy of the user's data.
    public func signOut() async {
        if signedInUser != nil, let apns = tokens.apns {
            try? await environment.account.unregisterDevice(pushToken: apns)
        }
        await environment.auth.signOut()
        signedInUser = nil
        await clearLocalData()
    }

    /// `delete_account`, then sign out and clear local data. The server deletes the devices rows.
    public func deleteAccount() async throws {
        try await environment.account.deleteAccount()
        await environment.auth.signOut()
        signedInUser = nil
        await clearLocalData()
    }

    private func clearLocalData() async {
        registered = nil
        stopDeletionWatchers()
        await environment.realtime.stopAll()
        await environment.cache.removeAll()
        await environment.signedURLs.removeAll()
        await environment.publisher.removeAll()
        if let widgetStore {
            try? widgetStore.removeAll()
            await hooks.reloadWidgets?()
        }
        await hooks.linkPurchases?(nil)
        await hooks.removeSessionFiles?()
    }
}
