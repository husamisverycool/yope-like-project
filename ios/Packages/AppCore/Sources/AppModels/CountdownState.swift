import Foundation

/// Difference between the server's clock and this device's clock (`server − device`), measured
/// by the API layer (e.g. from a response's `Date` header). All invitation times are server times.
public struct ServerClock: Hashable, Sendable {
    public var offset: TimeInterval

    public init(offset: TimeInterval) {
        self.offset = offset
    }

    public static let device = ServerClock(offset: 0)

    /// Server "now" for a device time.
    public func serverTime(atDeviceTime deviceTime: Date) -> Date {
        deviceTime.addingTimeInterval(offset)
    }

    /// The device time at which the device clock shows `serverTime` (for timers drawn by the system,
    /// such as `Text(timerInterval:)`, which count against the device clock).
    public func deviceTime(forServerTime serverTime: Date) -> Date {
        serverTime.addingTimeInterval(-offset)
    }
}

/// The state of a daily invitation window at a given moment. A pure function of its inputs, so
/// every view (camera, Live Activity, group screen) shows the same state for the same instant.
public enum CountdownState: Hashable, Sendable {
    /// The window has not opened yet.
    case upcoming(opensIn: TimeInterval)
    /// The window is open; `remaining` > 0.
    case open(remaining: TimeInterval)
    /// The window has closed. Posting afterwards is a normal post (no label, tenet 5).
    case closed

    /// - Parameters:
    ///   - opensAt: server `fires_at`; nil when only the closing time is known (e.g. Live Activity).
    ///   - closesAt: server `closes_at`.
    ///   - now: device time.
    ///   - clock: server clock offset.
    public init(opensAt: Date?, closesAt: Date, now: Date, clock: ServerClock = .device) {
        let serverNow = clock.serverTime(atDeviceTime: now)
        if let opensAt, serverNow < opensAt {
            self = .upcoming(opensIn: opensAt.timeIntervalSince(serverNow))
        } else if serverNow < closesAt {
            self = .open(remaining: closesAt.timeIntervalSince(serverNow))
        } else {
            self = .closed
        }
    }

    public var isOpen: Bool {
        if case .open = self { return true }
        return false
    }

    /// Remaining whole seconds, rounded up, so the display reaches 0 exactly when the window closes.
    public var remainingWholeSeconds: Int? {
        guard case .open(let remaining) = self else { return nil }
        return Int(remaining.rounded(.up))
    }

    /// The next device time at which the state changes (open → closed, upcoming → open), for
    /// scheduling a refresh or ending a Live Activity. Nil once closed.
    public static func nextTransition(opensAt: Date?, closesAt: Date, now: Date, clock: ServerClock = .device) -> Date? {
        switch CountdownState(opensAt: opensAt, closesAt: closesAt, now: now, clock: clock) {
        case .upcoming:
            return opensAt.map { clock.deviceTime(forServerTime: $0) }
        case .open:
            return clock.deviceTime(forServerTime: closesAt)
        case .closed:
            return nil
        }
    }

    /// Range for `Text(timerInterval:countsDown:)`, in device time. Never inverted (an inverted
    /// `ClosedRange` traps), so after the close it is the empty range `[end, end]`.
    public static func timerRange(closesAt: Date, now: Date, clock: ServerClock = .device) -> ClosedRange<Date> {
        let end = clock.deviceTime(forServerTime: closesAt)
        return min(now, end)...end
    }
}
