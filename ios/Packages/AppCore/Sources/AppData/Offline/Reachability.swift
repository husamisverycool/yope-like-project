import Foundation
#if canImport(Network)
import Network
#endif

/// Whether the device has a usable network path.
public enum NetworkStatus: Hashable, Sendable {
    case online
    case offline
    /// No monitor on this platform (Linux) or no reading yet.
    case unknown
}

/// Network reachability as an async stream (`NWPathMonitor` on Apple platforms; on Linux it
/// reports `.unknown` once and finishes). Screens show cached content with an offline state
/// while `.offline`; `SessionCoordinator` retries the post outbox when it turns `.online`.
public final class Reachability: @unchecked Sendable {
    private let lock = NSLock()
    private var status: NetworkStatus = .unknown
    private var continuations: [UUID: AsyncStream<NetworkStatus>.Continuation] = [:]
    #if canImport(Network)
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "app.data.reachability")
    #endif

    public init() {
        #if canImport(Network)
        monitor.pathUpdateHandler = { [weak self] path in
            self?.update(path.status == .satisfied ? .online : .offline)
        }
        monitor.start(queue: queue)
        #endif
    }

    deinit {
        #if canImport(Network)
        monitor.cancel()
        #endif
        lock.lock()
        let all = continuations.values
        lock.unlock()
        all.forEach { $0.finish() }
    }

    public var currentStatus: NetworkStatus {
        lock.lock()
        defer { lock.unlock() }
        return status
    }

    /// The current status, then every change.
    public func updates() -> AsyncStream<NetworkStatus> {
        let (stream, continuation) = AsyncStream<NetworkStatus>.makeStream(bufferingPolicy: .bufferingNewest(1))
        #if canImport(Network)
        let id = UUID()
        lock.lock()
        continuations[id] = continuation
        let current = status
        lock.unlock()
        continuation.yield(current)
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            self.lock.lock()
            self.continuations[id] = nil
            self.lock.unlock()
        }
        #else
        continuation.yield(.unknown)
        continuation.finish()
        #endif
        return stream
    }

    private func update(_ newStatus: NetworkStatus) {
        lock.lock()
        guard newStatus != status else {
            lock.unlock()
            return
        }
        status = newStatus
        let targets = Array(continuations.values)
        lock.unlock()
        targets.forEach { $0.yield(newStatus) }
    }
}
