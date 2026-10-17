// Surface: settings.downloads — "Download My Photos" (free) and albums.view's "Download Album" (premium) (owner decisions 29
// and 34; docs/RESEARCH_FEATURES_2026-10-17.md #2: Retro "Download your package", Yope "download all photos"). Spec:
// design/surfaces/settings.downloads.md. View model only (Foundation + Observation + AppData); the view is
// DownloadViews.swift.
import AppData
import AppModels
import Foundation
import Observation

/// Where a download stopped: the last photo saved (kept on the device, per account and scope, so reopening the page goes
/// on from there).
struct DownloadCursor: Codable, Equatable, Sendable {
    /// The last saved row's `posted_at` (`'mine'`: the next page's `p_before`).
    var postedAt: Date
    /// The last saved row's post (`'album'`: the rows after it in album order).
    var postID: PostID
}

/// Keeps each scope's `DownloadCursor` in `UserDefaults`.
final class DownloadCursorStore: @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static func key(scope: DownloadScope, user: UserID?) -> String {
        let owner = user?.rawValue ?? ""
        switch scope {
        case .mine: return "social.downloads." + owner + ".mine" // provenance-ok: defaults key, not UI text
        case let .album(id): return "social.downloads." + owner + ".album." + id.rawValue // provenance-ok: defaults key
        }
    }

    func cursor(for key: String) -> DownloadCursor? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(DownloadCursor.self, from: data)
    }

    func set(_ cursor: DownloadCursor?, for key: String) {
        if let cursor, let data = try? JSONEncoder().encode(cursor) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

/// Pages `download_items` and saves each original to the photo library (Live Photo: still + motion; video) with add-only
/// access, as Save to Camera Roll does (owner decision 28). Progress never carries a number of photos (tenet 2): `'mine'`
/// is an indeterminate bar, an album a bar without figures. Cancellable; after a stop (Cancel, a failure, the page closed)
/// Continue goes on from the last photo saved.
@MainActor
@Observable
final class PhotoDownloadModel {
    enum Phase: Equatable {
        /// Ready to start (or to continue: `canResume`).
        case idle
        case running
        /// Every photo was saved.
        case done
        /// There was nothing to save.
        case empty
        case failed
        case offline
    }

    let scope: DownloadScope
    private(set) var phase: Phase = .idle
    /// An earlier download stopped before the end: the capsule reads Continue.
    private(set) var canResume = false
    /// An album's share saved so far (0…1, drawn as a bar without figures); nil for `'mine'` (indeterminate: the total is
    /// never asked for).
    private(set) var fraction: Double?
    /// Add-only photo access was denied: the platform alert with the Settings button.
    var saveDenied = false
    /// The album needs premium (`premium_required`): each change asks the view to open the paywall at the downloads perk.
    private(set) var paywallRequests = 0
    private(set) var signals = SocialSignals()

    @ObservationIgnored private let data: any SocialDataSource
    @ObservationIgnored private let saver: any SocialPhotoSaving
    @ObservationIgnored private let store: DownloadCursorStore
    @ObservationIgnored private var me: UserID?
    @ObservationIgnored private var task: Task<Void, Never>?

    init(scope: DownloadScope, data: any SocialDataSource, saver: any SocialPhotoSaving, store: DownloadCursorStore = DownloadCursorStore()) {
        self.scope = scope
        self.data = data
        self.saver = saver
        self.store = store
    }

    var isRunning: Bool { phase == .running }

    private var cursorKey: String { DownloadCursorStore.key(scope: scope, user: me) }

    /// Reads who is signed in and whether a stopped download can continue.
    func load() async {
        me = await data.currentUserID()
        canResume = store.cursor(for: cursorKey) != nil
    }

    /// Download / Continue: starts saving from the last photo saved (or the newest). Returns the running task (tests wait
    /// on it).
    @discardableResult
    func start() -> Task<Void, Never>? {
        guard phase != .running else { return task }
        phase = .running
        fraction = scope == .mine ? nil : (fraction ?? 0)
        let run = Task { [weak self] in
            guard let self else { return }
            await self.run()
        }
        task = run
        return run
    }

    /// Cancel: stops after the photo being saved; Continue goes on from there.
    func cancel() {
        task?.cancel()
    }

    /// The page closed: the download stops (it goes on from there when the page opens again).
    func stop() {
        task?.cancel()
    }

    private func run() async {
        if me == nil { me = await data.currentUserID() }
        let key = cursorKey
        let startCursor = store.cursor(for: key)
        var savedAny = startCursor != nil
        do {
            switch scope {
            case .mine:
                var before = startCursor?.postedAt
                while true {
                    try Task.checkCancellation()
                    let page = try await data.downloadItems(.mine, before: before)
                    for item in page {
                        try Task.checkCancellation()
                        try await save(item)
                        store.set(DownloadCursor(postedAt: item.postedAt, postID: item.postID), for: key)
                        savedAny = true
                    }
                    guard page.count >= SocialPaging.downloads, let last = page.last else { break }
                    before = last.postedAt
                }
            case .album:
                let items = try await data.downloadItems(scope, before: nil)
                let first = startCursor.flatMap { cursor in items.firstIndex { $0.postID == cursor.postID }.map { $0 + 1 } } ?? 0
                if !items.isEmpty { fraction = Double(first) / Double(items.count) }
                for index in items.indices where index >= first {
                    try Task.checkCancellation()
                    try await save(items[index])
                    store.set(DownloadCursor(postedAt: items[index].postedAt, postID: items[index].postID), for: key)
                    savedAny = true
                    fraction = Double(index + 1) / Double(items.count)
                }
            }
            store.set(nil, for: key)
            canResume = false
            if savedAny {
                phase = .done
                signals.emit(.success)
            } else {
                phase = .empty
            }
        } catch is CancellationError {
            stopped(key)
        } catch SocialSaveFailure.notAuthorized {
            stopped(key)
            saveDenied = true
            signals.emit(.failed)
        } catch {
            if Task.isCancelled {
                stopped(key)
                return
            }
            if DataError.from(error).apiCode == .premiumRequired {
                stopped(key)
                paywallRequests += 1
                return
            }
            canResume = store.cursor(for: key) != nil
            phase = SocialFailure(error) == .offline ? .offline : .failed
            signals.emit(.failed)
        }
    }

    /// Back to idle; Continue when something was saved.
    private func stopped(_ key: String) {
        canResume = store.cursor(for: key) != nil
        phase = .idle
    }

    /// One original into the library; a photo deleted meanwhile is skipped.
    private func save(_ item: DownloadItem) async throws {
        do {
            let fileURL = try await data.fileURL(path: item.originalPath)
            var motionURL: URL?
            if item.kind == .livePhoto, let motionPath = item.motionPath {
                motionURL = try await data.fileURL(path: motionPath)
            }
            try await saver.save(kind: item.kind, fileURL: fileURL, motionURL: motionURL)
        } catch let error as SocialSaveFailure {
            throw error
        } catch {
            if SocialFailure(error) == .notFound { return }
            throw error
        }
    }
}
