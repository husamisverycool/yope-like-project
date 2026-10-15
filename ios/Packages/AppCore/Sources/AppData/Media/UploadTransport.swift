import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Request headers AppData uses between the uploader and the transport; never sent to the server.
public enum UploadHeaders {
    /// The bucket object a whole-file upload writes (a background transport records it on completion).
    public static let objectPath = "X-AppData-Object-Path"
}

/// Sends one HTTP request whose body (if any) is a local file. Transports remove
/// `UploadHeaders` before sending.
public protocol UploadTransport: Sendable {
    func send(_ request: URLRequest, bodyFile: URL?) async throws -> (Data, HTTPURLResponse)
}

/// Foreground transport over a regular `URLSession` (Linux, tests, requests without a body).
public struct FoundationUploadTransport: UploadTransport {
    public let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest, bodyFile: URL?) async throws -> (Data, HTTPURLResponse) {
        var request = request
        request.setValue(nil, forHTTPHeaderField: UploadHeaders.objectPath)
        let data: Data
        let response: URLResponse
        if let bodyFile {
            #if canImport(FoundationNetworking)
            // swift-corelibs-foundation: upload the bytes (chunks and single uploads are ≤ 6 MiB).
            let body = try Data(contentsOf: bodyFile)
            (data, response) = try await session.upload(for: request, from: body)
            #else
            (data, response) = try await session.upload(for: request, fromFile: bodyFile)
            #endif
        } else {
            (data, response) = try await session.data(for: request)
        }
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

/// Which object uploads finished and where a resumable upload lives, persisted so an upload
/// that completed while the app was suspended or terminated (background `URLSession`) is not
/// sent again, and a resumable upload continues from its server offset after a relaunch.
public final class UploadLedger: @unchecked Sendable {
    private struct State: Codable {
        var completed: Set<String> = []
        var resumable: [String: String] = [:]
    }

    public let fileURL: URL
    private let lock = NSLock()
    private var state: State

    public init(fileURL: URL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL), let state = try? JSONDecoder().decode(State.self, from: data) {
            self.state = state
        } else {
            self.state = State()
        }
    }

    public func isCompleted(_ path: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return state.completed.contains(path)
    }

    public func markCompleted(_ path: String) {
        mutate {
            $0.completed.insert(path)
            $0.resumable[path] = nil
        }
    }

    public func resumableLocation(for path: String) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        return state.resumable[path].flatMap(URL.init(string:))
    }

    public func setResumableLocation(_ url: URL?, for path: String) {
        mutate { $0.resumable[path] = url?.absoluteString }
    }

    /// Drops what is known about `paths` (the post they belong to was published or discarded).
    public func forget(_ paths: [String]) {
        mutate { state in
            for path in paths {
                state.completed.remove(path)
                state.resumable[path] = nil
            }
        }
    }

    private func mutate(_ body: (inout State) -> Void) {
        lock.lock()
        body(&state)
        let data = try? JSONEncoder().encode(state)
        lock.unlock()
        guard let data else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: [.atomic])
    }
}

#if canImport(Darwin)
/// Uploads through a background `URLSession` (Apple platforms): a file upload keeps going while
/// the app is suspended, and the system relaunches the app to report it.
///
/// Requests with a body file run as background upload tasks; requests without one (resumable
/// upload creation, offset checks) use `foreground`, since background sessions only run upload
/// and download tasks reliably. The task description carries the object path: when an upload
/// finishes after the app was terminated (no one awaits it any more), the path is recorded in
/// `ledger` so `PostPublisher.resumePending()` does not send it again.
///
/// Forward `application(_:handleEventsForBackgroundURLSession:completionHandler:)` to
/// `handleEvents(forSession:completionHandler:)`.
public final class BackgroundUploadTransport: NSObject, UploadTransport, URLSessionDataDelegate, @unchecked Sendable {
    public static let defaultIdentifier = "app.data.uploads"

    public let identifier: String
    public let foreground: FoundationUploadTransport
    private let ledger: UploadLedger?
    private let lock = NSLock()
    private var session: URLSession?
    private var pending: [Int: Pending] = [:]
    private var eventsCompletionHandler: (() -> Void)?

    private final class Pending {
        let continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>
        var data = Data()

        init(continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>) {
            self.continuation = continuation
        }
    }

    /// - Parameter sharedContainerIdentifier: the App Group, when an extension starts uploads.
    public init(
        identifier: String = BackgroundUploadTransport.defaultIdentifier,
        sharedContainerIdentifier: String? = nil,
        ledger: UploadLedger?,
        foreground: FoundationUploadTransport = FoundationUploadTransport()
    ) {
        self.identifier = identifier
        self.ledger = ledger
        self.foreground = foreground
        super.init()
        let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
        configuration.sharedContainerIdentifier = sharedContainerIdentifier
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        configuration.timeoutIntervalForResource = 24 * 60 * 60
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    public func send(_ request: URLRequest, bodyFile: URL?) async throws -> (Data, HTTPURLResponse) {
        guard let bodyFile, let session = currentSession() else {
            return try await foreground.send(request, bodyFile: bodyFile)
        }
        var request = request
        let path = request.value(forHTTPHeaderField: UploadHeaders.objectPath)
        request.setValue(nil, forHTTPHeaderField: UploadHeaders.objectPath)
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.uploadTask(with: request, fromFile: bodyFile)
            task.taskDescription = path
            lock.lock()
            pending[task.taskIdentifier] = Pending(continuation: continuation)
            lock.unlock()
            task.resume()
        }
    }

    /// Call from the app delegate's `handleEventsForBackgroundURLSession`; returns false when the
    /// identifier belongs to another session.
    @discardableResult
    public func handleEvents(forSession identifier: String, completionHandler: @escaping () -> Void) -> Bool {
        guard identifier == self.identifier else { return false }
        lock.lock()
        eventsCompletionHandler = completionHandler
        lock.unlock()
        return true
    }

    private func currentSession() -> URLSession? {
        lock.lock()
        defer { lock.unlock() }
        return session
    }

    // MARK: URLSessionDataDelegate

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        pending[dataTask.taskIdentifier]?.data.append(data)
        lock.unlock()
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let entry = pending.removeValue(forKey: task.taskIdentifier)
        lock.unlock()
        let response = task.response as? HTTPURLResponse
        if entry == nil, error == nil, let path = task.taskDescription, let status = response?.statusCode,
           (200..<300).contains(status) {
            // Finished after a relaunch: nobody awaits it, remember it for resumePending().
            ledger?.markCompleted(path)
        }
        guard let entry else { return }
        if let error {
            entry.continuation.resume(throwing: error)
        } else if let response {
            entry.continuation.resume(returning: (entry.data, response))
        } else {
            entry.continuation.resume(throwing: URLError(.badServerResponse))
        }
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        lock.lock()
        let handler = eventsCompletionHandler
        eventsCompletionHandler = nil
        lock.unlock()
        guard let handler else { return }
        DispatchQueue.main.async { handler() }
    }
}
#endif
