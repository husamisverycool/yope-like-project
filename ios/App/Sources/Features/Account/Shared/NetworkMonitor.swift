// Account group — reachability for screens (offline states), fed by AppData's `Reachability`.
import AppData
import Foundation
import Observation

/// The device's network status as observable state. `isOffline` drives the offline states of every account surface.
@MainActor
@Observable
final class NetworkMonitor {
    private(set) var status: NetworkStatus
    @ObservationIgnored private var task: Task<Void, Never>?

    init(status: NetworkStatus = .unknown) {
        self.status = status
    }

    /// Only a reading of `.offline` counts as offline (`.unknown` = no monitor / no reading yet).
    var isOffline: Bool { status == .offline }

    /// Follows `updates` until `stop()` (one stream at a time).
    func follow(_ updates: AsyncStream<NetworkStatus>) {
        task?.cancel()
        task = Task { [weak self] in
            for await status in updates {
                self?.status = status
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    /// Sets the status directly (tests, UI-test scenarios).
    func set(_ status: NetworkStatus) {
        self.status = status
    }
}
