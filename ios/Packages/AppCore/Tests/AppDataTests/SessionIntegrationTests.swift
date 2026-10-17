import AppModels
import Foundation
import Supabase
import XCTest
@testable import AppData

/// Auth with a real GoTrue session, and the session glue (devices, widgets, RevenueCat hook,
/// deletions reaching the widget store and the offline cache).
final class SessionIntegrationTests: XCTestCase {
    private var users: TestUsers!

    override func setUp() async throws {
        try await LocalStack.require()
        users = TestUsers()
    }

    override func tearDown() async throws {
        await users?.cleanUp()
    }

    /// Phone OTP needs Twilio, so the session comes from a password sign-in of an admin-created
    /// phone user (the same GoTrue session machinery: persisted, refreshed, signed out).
    func testSupabaseSessionStateProfileAndSignOut() async throws {
        let phone = await LocalStack.nextPhone()
        let password = "pw-\(UUID().uuidString)"
        let userID = try await LocalStack.createAuthUser(phone: phone, password: password, displayName: "Sam Session")
        let tokenClient = DataClient(configuration: LocalStack.configuration) { LocalStack.mintJWT(subject: userID) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("session-\(UUID().uuidString)", isDirectory: true)
        users.track(authUserID: userID, environment: DataEnvironment(client: tokenClient, directories: .under(root), uploadTransport: FoundationUploadTransport()), directory: root)

        let sessionFolder = root.appendingPathComponent("session", isDirectory: true)
        let storage = SessionStorage.File(directory: sessionFolder)
        let client = DataClient(configuration: LocalStack.configuration, sessionStorage: storage, realtime: LocalStack.realtimeTuning)
        let data = DataEnvironment(client: client, directories: .under(root.appendingPathComponent("env")), uploadTransport: FoundationUploadTransport())
        XCTAssertEqual(data.auth.currentState, .signedOut)
        let states = StateRecorder(data.auth.authStates())
        defer { states.stop() }

        // A wrong SMS code is a typed auth error (nothing was sent: no Twilio locally).
        await assertThrows(.auth(.invalidOTP)) { try await data.auth.verifyOTP(phone: "+\(phone)", token: "000000") }
        do {
            try await data.auth.signInWithOTP(phone: "+\(phone)")
        } catch let error as DataError {
            guard case .auth = error else { return XCTFail("expected an auth error, got \(error)") }
        }

        let session = try await client.supabase.auth.signIn(phone: phone, password: password)
        XCTAssertEqual(session.user.id.uuidString.lowercased(), userID)
        XCTAssertEqual(data.auth.currentUserID?.rawValue, userID)
        let signedIn = await eventually { states.states.contains(.signedIn(UserID(userID))) }
        XCTAssertTrue(signedIn, "\(states.states)")

        // The session drives every repository.
        let profile = try await data.profiles.myProfile()
        XCTAssertEqual(profile.displayName, "Sam Session")
        let renamed = try await data.profiles.updateProfile(displayName: "Sam S")
        XCTAssertEqual(renamed.displayName, "Sam S")
        let group = try await data.groups.create(name: "Session \(users.runID)", kind: .custom)
        XCTAssertEqual(group.createdBy?.rawValue, userID)
        let accessToken = try await client.accessToken()
        XCTAssertEqual(JWTClaims.subject(of: accessToken), userID)

        // Persisted: a new client over the same storage is signed in (app relaunch).
        XCTAssertTrue(FileManager.default.fileExists(atPath: sessionFolder.path))
        let relaunched = DataClient(configuration: LocalStack.configuration, sessionStorage: storage)
        XCTAssertEqual(relaunched.currentUserID?.rawValue, userID)
        let groups = try await GroupRepository(client: relaunched).myGroups()
        XCTAssertEqual(groups.map(\.id), [group.id])

        // Sign out: state, stored session and access are gone.
        await data.auth.signOut()
        XCTAssertNil(data.auth.currentUserID)
        let signedOut = await eventually { states.states.last == .signedOut }
        XCTAssertTrue(signedOut, "\(states.states)")
        await assertThrows(.api(.notAuthenticated)) { try await data.groups.create(name: "x", kind: .friends) }
        let reopened = DataClient(configuration: LocalStack.configuration, sessionStorage: storage)
        XCTAssertNil(reopened.currentUserID)
    }

    /// A relaunch: APNs has not handed this launch its token yet, so sign-out unregisters the token stored on the device
    /// (`SessionHooks.storedPushToken`) — the phone stops getting the account's notifications.
    func testSignOutUnregistersTheStoredTokenAfterARelaunch() async throws {
        let stored = String(repeating: "d1", count: 32) + users.runID
        let rui = try await users.make("Rui", hooks: SessionHooks(storedPushToken: { stored }))
        _ = try await rui.data.account.registerDevice(pushToken: stored, pushToStartToken: nil, widgetPushToken: nil)
        await rui.data.coordinator.didSignIn(rui.id)
        let before = try await rui.data.account.myDevices()
        XCTAssertEqual(before.map(\.pushToken), [stored])
        await rui.data.coordinator.signOut()
        let after = try await rui.data.account.myDevices()
        XCTAssertTrue(after.isEmpty, "the stored token is unregistered")
    }

    func testCoordinatorRegistersDeviceSyncsWidgetsAndAppliesDeletions() async throws {
        try await LocalStack.requireWebSockets() // deletions arrive over Realtime
        let widgetRoot = FileManager.default.temporaryDirectory.appendingPathComponent("widgets-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: widgetRoot) }
        let widgetStore = WidgetStore(rootURL: widgetRoot)
        let hookLog = HookLog()
        let hooks = SessionHooks(
            linkPurchases: { await hookLog.link($0) },
            reloadWidgets: { await hookLog.reload() },
            removeSessionFiles: { await hookLog.removeFiles() }
        )
        let rui = try await users.make("Rui", widgetStore: widgetStore, hooks: hooks)
        let ana = try await users.make("Ana")
        let group = try await ana.data.groups.create(name: "Glue \(users.runID)", kind: .family)
        _ = try await rui.data.groups.join(token: try await ana.data.groups.createInvite(groupID: group.id).token)

        // Tokens collected before sign-in are registered at sign-in, with all three tokens.
        let apns = String(repeating: "c0", count: 32) + users.runID
        await rui.data.coordinator.updateDeviceTokens(DevicePushTokens(apns: apns, pushToStart: "p2s-\(users.runID)", widgetPush: "w-\(users.runID)"))
        var devices = try await rui.data.account.myDevices()
        XCTAssertTrue(devices.isEmpty, "nothing is registered before sign-in")
        await rui.data.coordinator.didSignIn(rui.id)
        devices = try await rui.data.account.myDevices()
        XCTAssertEqual(devices.map(\.pushToken), [apns])
        XCTAssertEqual(devices.first?.pushToStartToken, "p2s-\(users.runID)")
        XCTAssertEqual(devices.first?.widgetPushToken, "w-\(users.runID)")
        let linked = await hookLog.linked
        XCTAssertEqual(linked, [rui.id])
        XCTAssertEqual(widgetStore.groups(), [WidgetGroup(id: group.id.rawValue, name: group.name)])

        // A token change re-registers (a nil token is cleared).
        await rui.data.coordinator.updateDeviceTokens(DevicePushTokens(apns: apns, pushToStart: "p2s-2-\(users.runID)", widgetPush: nil))
        devices = try await rui.data.account.myDevices()
        XCTAssertEqual(devices.first?.pushToStartToken, "p2s-2-\(users.runID)")
        XCTAssertNil(devices.first?.widgetPushToken)

        // Ana posts; Rui's widget shows it (as the Notification Service Extension would write)
        // and his feed is cached.
        let file = try temporaryFile(tinyJPEG, extension: "jpg")
        let posts = try await ana.data.publisher.publish(PostDraft(kind: .photo, original: .init(url: file, contentType: ContentType.jpeg), groupIDs: [group.id]))
        let post = try XCTUnwrap(posts.first)
        let snapshot = WidgetSnapshot(groupID: group.id.rawValue, sourceID: post.id.rawValue, photoFileName: "photo-\(post.id.rawValue).jpg", kind: .photo, postedAt: Date())
        try widgetStore.writeFile(tinyJPEG, groupID: group.id.rawValue, fileName: snapshot.photoFileName)
        try widgetStore.save(snapshot)
        let collageRow = try await LocalStack.insert("collages", [
            "group_id": group.id.rawValue, "option": "B", "post_ids": [post.id.rawValue],
            "image_path": "g/\(group.id.rawValue)/collages/c/image.jpg", "status": "ready",
            "composed_at": Timestamp.format(Date().addingTimeInterval(-60)),
        ])
        let collageID = try XCTUnwrap(collageRow["id"] as? String)
        let collageSnapshot = WidgetSnapshot(groupID: group.id.rawValue, sourceID: collageID, photoFileName: "collage-\(collageID).jpg", kind: .collage, postedAt: Date())
        try widgetStore.writeFile(tinyJPEG, groupID: group.id.rawValue, fileName: collageSnapshot.photoFileName)
        try widgetStore.save(collageSnapshot)
        let feed = try await rui.data.posts.feed(groupID: group.id)
        XCTAssertEqual(feed.items.map(\.id), [post.id])

        // The coordinator's deletion channel is live (a second subscriber shares it).
        let watcher = EventRecorder(rui.data.realtime.events(for: group.id, filter: .deletions))
        defer { watcher.stop() }
        let live = await eventually { watcher.contains { $0 == .subscribed(topic: "realtime:group:\(group.id.rawValue)") } }
        XCTAssertTrue(live, "\(watcher.events)")

        // Ana deletes the photo: it leaves Rui's widget (photo and the collage being recomposed)
        // and his cached feed.
        try await ana.data.posts.deleteMedia(id: post.mediaID)
        let removed = await eventually {
            widgetStore.snapshot(groupID: group.id.rawValue, kind: .photo) == nil
                && widgetStore.snapshot(groupID: group.id.rawValue, kind: .collage) == nil
        }
        XCTAssertTrue(removed, "deleted post still on the widget")
        XCTAssertNil(widgetStore.photoURL(for: snapshot))
        let cached = await rui.data.posts.cachedFeed(groupID: group.id)
        XCTAssertEqual(cached?.value.map(\.id), [])
        let reloads = await hookLog.reloads
        XCTAssertGreaterThan(reloads, 0)

        // Group changes reach the widget's group list (join → refresh, leave → folder removed).
        let second = try await ana.data.groups.create(name: "Second \(users.runID)", kind: .friends)
        _ = try await rui.data.groups.join(token: try await ana.data.groups.createInvite(groupID: second.id).token)
        let synced = await eventually { widgetStore.groups().map(\.id).sorted() == [group.id.rawValue, second.id.rawValue].sorted() }
        XCTAssertTrue(synced, "\(widgetStore.groups())")
        try await rui.data.groups.leave(groupID: group.id)
        let left = await eventually { widgetStore.groups().map(\.id) == [second.id.rawValue] }
        XCTAssertTrue(left, "\(widgetStore.groups())")

        // Sign-out: device unregistered first, then everything local is cleared.
        await rui.data.coordinator.signOut()
        let remaining = try await rui.data.account.myDevices()
        XCTAssertTrue(remaining.isEmpty, "unregister_device before signing out")
        XCTAssertTrue(widgetStore.groups().isEmpty)
        let feedAfter = await rui.data.posts.cachedFeed(groupID: second.id)
        XCTAssertNil(feedAfter)
        let finalLinks = await hookLog.linked
        XCTAssertEqual(finalLinks, [rui.id, nil], "RevenueCat logged out")
        let removals = await hookLog.fileRemovals
        XCTAssertEqual(removals, 1, "the app's session files are removed once, after sign-out")
    }
}

/// Records `AuthService.authStates()`.
final class StateRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [AuthState] = []
    private var task: Task<Void, Never>?

    init(_ stream: AsyncStream<AuthState>) {
        task = Task { [weak self] in
            for await state in stream { self?.append(state) }
        }
    }

    private func append(_ state: AuthState) {
        lock.lock()
        storage.append(state)
        lock.unlock()
    }

    var states: [AuthState] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func stop() { task?.cancel() }
}

actor HookLog {
    private(set) var linked: [UserID?] = []
    private(set) var reloads = 0
    private(set) var fileRemovals = 0

    func link(_ user: UserID?) { linked.append(user) }
    func reload() { reloads += 1 }
    func removeFiles() { fileRemovals += 1 }
}
