#if os(iOS)
import AppModels
@preconcurrency import Contacts
import Foundation

/// Optional contacts access for inviting friends (`onboarding.permission.contacts`,
/// `groups.invite`). Reads names and phone numbers on the device only. Raw contacts never leave
/// the device: matching goes through `ContactMatcher` (AppModels), which sends only hashes
/// produced by a `PhoneNumberHashing` implementation the backend contract defines.
public struct ContactsService: Sendable {
    public enum ContactsError: Error, Equatable, Sendable {
        case notAuthorized(PermissionStatus)
    }

    public init() {}

    public static func authorization() -> PermissionStatus {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        default:
            // iOS 18 adds `.limited` (the user shared selected contacts only).
            if #available(iOS 18.0, *), status == .limited { return .limited }
            return .denied
        }
    }

    public static func requestAccess() async -> PermissionStatus {
        if authorization() == .notDetermined {
            _ = try? await CNContactStore().requestAccess(for: .contacts)
        }
        return authorization()
    }

    /// Contacts that have at least one phone number, read off the main thread.
    public func contactsWithPhoneNumbers() async throws -> [LocalContact] {
        let status = Self.authorization()
        guard status.allowsAccess else { throw ContactsError.notAuthorized(status) }
        return try await Task.detached(priority: .userInitiated) {
            try Self.readContacts()
        }.value
    }

    private static func readContacts() throws -> [LocalContact] {
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactPhoneNumbersKey as CNKeyDescriptor,
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .userDefault
        var contacts: [LocalContact] = []
        try store.enumerateContacts(with: request) { contact, _ in
            let numbers = contact.phoneNumbers.compactMap { PhoneNumber($0.value.stringValue) }
            guard !numbers.isEmpty else { return }
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            contacts.append(LocalContact(id: contact.identifier, displayName: name, phoneNumbers: numbers))
        }
        return contacts
    }
}
#endif
