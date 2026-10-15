// Account group — small records the account flow keeps on the device.
import Foundation
import Security

/// Remembers an age-gate refusal on the device so the screen cannot be retried by going back or reinstalling
/// (auth.agegate "under age": Keychain-backed; the Keychain survives app deletion).
@MainActor
protocol AgeGateRefusalStoring: AnyObject, Sendable {
    /// The minimum age shown in the refusal, when a refusal was recorded (0 when it was not known).
    var refusal: Int? { get }
    func recordRefusal(minAge: Int?)
}

/// Keychain implementation (generic password item, this device only).
@MainActor
final class KeychainAgeGateRefusalStore: AgeGateRefusalStoring {
    private let service = "app.agegate" // provenance-ok: Keychain service name, not user-facing
    private let account = "refusal" // provenance-ok: Keychain account name, not user-facing

    var refusal: Int? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, let text = String(data: data, encoding: .utf8) else { return nil }
        return Int(text) ?? 0
    }

    func recordRefusal(minAge: Int?) {
        let data = Data(String(minAge ?? 0).utf8)
        SecItemDelete(baseQuery as CFDictionary)
        var item = baseQuery
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

/// Process-memory implementation (tests, UI-test scenarios).
@MainActor
final class InMemoryAgeGateRefusalStore: AgeGateRefusalStoring {
    private(set) var refusal: Int?

    init(refusal: Int? = nil) {
        self.refusal = refusal
    }

    func recordRefusal(minAge: Int?) {
        refusal = minAge ?? 0
    }
}

/// Users who finished onboarding on this device, so a later launch (also offline) goes straight home.
@MainActor
final class OnboardingRecord {
    private let defaults: UserDefaults
    private let key = "account.onboarded" // provenance-ok: UserDefaults key, not user-facing

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isComplete(for userID: String) -> Bool {
        (defaults.stringArray(forKey: key) ?? []).contains(userID)
    }

    func markComplete(for userID: String) {
        var users = defaults.stringArray(forKey: key) ?? []
        guard !users.contains(userID) else { return }
        users.append(userID)
        defaults.set(users, forKey: key)
    }
}

/// Device-local preference of `settings.notifications` → "Live Activity": when off, the push-to-start token is not
/// registered (`register_device(… p_push_to_start_token: null)`).
@MainActor
final class LiveActivityPreference {
    private let defaults: UserDefaults
    private let key = "settings.liveActivity.enabled" // provenance-ok: UserDefaults key, not user-facing

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// On unless the person turned it off.
    var isEnabled: Bool {
        get { defaults.object(forKey: key) as? Bool ?? true }
        set { defaults.set(newValue, forKey: key) }
    }
}
