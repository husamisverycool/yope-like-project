import AppModels
import Foundation
import Supabase

/// Every AppData service, wired once per process. Screens take the repositories they need from here.
///
///     let data = try DataEnvironment.live(configuration: appConfiguration, widgetStore: widgetStore, hooks: hooks)
///     await data.coordinator.start()
public final class DataEnvironment: Sendable {
    /// Where AppData keeps files.
    public struct Directories: Sendable {
        public var cache: URL
        public var outbox: URL
        public var uploadLedger: URL
        public var scratch: URL

        public init(cache: URL, outbox: URL, uploadLedger: URL, scratch: URL) {
            self.cache = cache
            self.outbox = outbox
            self.uploadLedger = uploadLedger
            self.scratch = scratch
        }

        /// Application Support (cache, outbox, ledger) and the temporary directory (chunks).
        public static func standard() -> Directories {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            return Directories(
                cache: OfflineCache.defaultDirectory(),
                outbox: PostPublisher.defaultDirectory(),
                uploadLedger: base.appendingPathComponent("AppDataUploads.json"),
                scratch: FileManager.default.temporaryDirectory.appendingPathComponent("AppDataUploads", isDirectory: true)
            )
        }

        /// Everything under one folder (tests).
        public static func under(_ root: URL) -> Directories {
            Directories(
                cache: root.appendingPathComponent("cache", isDirectory: true),
                outbox: root.appendingPathComponent("outbox", isDirectory: true),
                uploadLedger: root.appendingPathComponent("uploads.json"),
                scratch: root.appendingPathComponent("scratch", isDirectory: true)
            )
        }
    }

    public let client: DataClient
    public let auth: AuthService
    public let cache: OfflineCache
    public let reachability: Reachability
    public let signedURLs: SignedURLCache
    public let uploader: MediaUploader
    public let publisher: PostPublisher
    public let realtime: RealtimeHub

    public let profiles: ProfileRepository
    public let groups: GroupRepository
    public let posts: PostRepository
    public let chat: ChatRepository
    public let reactions: ReactionRepository
    public let memories: MemoriesRepository
    public let invitations: InvitationRepository
    public let birthdays: BirthdayRepository
    public let safety: SafetyRepository
    public let account: AccountRepository

    /// Session glue (device tokens, widgets, RevenueCat, deletions). Call `start()` once.
    public let coordinator: SessionCoordinator

    /// - Parameters:
    ///   - uploadTransport: defaults to a background `URLSession` on Apple platforms
    ///     (`BackgroundUploadTransport`), a foreground one elsewhere.
    ///   - widgetStore: the App Group widget store kept in sync (nil in the App Clip and tests).
    public init(
        client: DataClient,
        directories: Directories = .standard(),
        uploadTransport: (any UploadTransport)? = nil,
        widgetStore: WidgetStore? = nil,
        hooks: SessionHooks = SessionHooks()
    ) {
        self.client = client
        auth = AuthService(client: client)
        cache = OfflineCache(directory: directories.cache)
        reachability = Reachability()
        signedURLs = SignedURLCache(client: client)
        let ledger = UploadLedger(fileURL: directories.uploadLedger)
        let transport: any UploadTransport
        if let uploadTransport {
            transport = uploadTransport
        } else {
            #if canImport(Darwin) && !os(macOS)
            transport = BackgroundUploadTransport(ledger: ledger)
            #else
            transport = FoundationUploadTransport()
            #endif
        }
        uploader = MediaUploader(client: client, transport: transport, ledger: ledger, scratchDirectory: directories.scratch)
        realtime = RealtimeHub(client: client)

        let relay = GroupChangeRelay()
        profiles = ProfileRepository(client: client)
        groups = GroupRepository(client: client, cache: cache, onGroupsChanged: { await relay.notify() })
        posts = PostRepository(client: client, cache: cache)
        chat = ChatRepository(client: client, cache: cache)
        reactions = ReactionRepository(client: client)
        memories = MemoriesRepository(client: client, cache: cache)
        invitations = InvitationRepository(client: client)
        birthdays = BirthdayRepository(client: client)
        safety = SafetyRepository(client: client)
        account = AccountRepository(client: client)
        publisher = PostPublisher(posts: posts, uploader: uploader, directory: directories.outbox)

        let coordinator = SessionCoordinator(
            services: SessionCoordinator.Services(
                auth: auth, groups: groups, account: account, memories: memories, realtime: realtime,
                cache: cache, signedURLs: signedURLs, publisher: publisher, reachability: reachability
            ),
            widgetStore: widgetStore,
            hooks: hooks
        )
        self.coordinator = coordinator
        relay.setHandler { [weak coordinator] in await coordinator?.refreshGroups() }
    }

    /// The app's environment from `config/app.json`; throws `DataError.notConfigured` while the
    /// Supabase URL / anon key are not provided. Create it once per process.
    /// - Parameter backgroundUploads: false in the App Clip (App Clips get no background networking,
    ///   docs/PLATFORM_CONSTRAINTS.md §3) and wherever a background `URLSession` is unavailable.
    public static func live(
        configuration: AppConfiguration,
        sessionStorage: (any AuthLocalStorage)? = nil,
        widgetStore: WidgetStore? = nil,
        hooks: SessionHooks = SessionHooks(),
        backgroundUploads: Bool = true
    ) throws -> DataEnvironment {
        let client = DataClient(configuration: try DataConfiguration(configuration), sessionStorage: sessionStorage)
        return DataEnvironment(
            client: client,
            uploadTransport: backgroundUploads ? nil : FoundationUploadTransport(),
            widgetStore: widgetStore,
            hooks: hooks
        )
    }

    /// Forward `application(_:handleEventsForBackgroundURLSession:completionHandler:)`. Returns
    /// false when the session is not AppData's (call the handler yourself then).
    public func handleBackgroundURLSessionEvents(identifier: String, completionHandler: @escaping () -> Void) -> Bool {
        #if canImport(Darwin)
        if let background = uploader.transport as? BackgroundUploadTransport {
            return background.handleEvents(forSession: identifier, completionHandler: completionHandler)
        }
        #endif
        return false
    }
}

/// Lets `GroupRepository` notify the coordinator, which is created after it.
final class GroupChangeRelay: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable () async -> Void)?

    func setHandler(_ handler: @escaping @Sendable () async -> Void) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    func notify() async {
        await currentHandler()?()
    }

    private func currentHandler() -> (@Sendable () async -> Void)? {
        lock.lock()
        defer { lock.unlock() }
        return handler
    }
}
