import Foundation

/// A phone number reduced to an optional leading `+` and digits. Region-aware E.164
/// normalization belongs to whoever defines the matching scheme (backend decision).
public struct PhoneNumber: Hashable, Sendable, CustomStringConvertible {
    public let canonical: String

    /// Strips formatting (spaces, dashes, dots, parentheses, slashes). Returns nil when the text
    /// contains anything else or has no digits.
    public init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = ""
        for (offset, scalar) in trimmed.unicodeScalars.enumerated() {
            switch scalar {
            case "0"..."9":
                result.unicodeScalars.append(scalar)
            case "+" where offset == 0:
                result.unicodeScalars.append(scalar)
            case " ", "-", ".", "(", ")", "/", "\u{00A0}":
                continue
            default:
                return nil
            }
        }
        guard result.unicodeScalars.contains(where: { $0 != "+" }) else { return nil }
        canonical = result
    }

    public var description: String { canonical }
}

/// A contact as read on the device. Never leaves the device as-is.
public struct LocalContact: Hashable, Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let phoneNumbers: [PhoneNumber]

    public init(id: String, displayName: String, phoneNumbers: [PhoneNumber]) {
        self.id = id
        self.displayName = displayName
        self.phoneNumbers = phoneNumbers
    }
}

/// Turns a phone number into the value sent for matching (hash scheme, salt, normalization:
/// backend decision, see docs/API.md once defined).
public protocol PhoneNumberHashing: Sendable {
    func hash(_ number: PhoneNumber) -> String
}

/// Asks the backend which hashes belong to registered users. Receives only hashes.
public protocol ContactMatching: Sendable {
    /// Returns hash → user id for the hashes that matched.
    func matchingUserIDs(forHashes hashes: Set<String>) async throws -> [String: String]
}

public struct ContactMatch: Hashable, Sendable {
    public let contactID: String
    public let userID: String
}

/// Hashes every number locally, sends only the hashes, and maps matches back to local contacts.
public struct ContactMatcher: Sendable {
    public let hasher: any PhoneNumberHashing
    public let backend: any ContactMatching

    public init(hasher: any PhoneNumberHashing, backend: any ContactMatching) {
        self.hasher = hasher
        self.backend = backend
    }

    public func matches(for contacts: [LocalContact]) async throws -> [ContactMatch] {
        var contactIDsByHash: [String: Set<String>] = [:]
        for contact in contacts {
            for number in contact.phoneNumbers {
                contactIDsByHash[hasher.hash(number), default: []].insert(contact.id)
            }
        }
        guard !contactIDsByHash.isEmpty else { return [] }
        let matched = try await backend.matchingUserIDs(forHashes: Set(contactIDsByHash.keys))
        var result: Set<ContactMatch> = []
        for (hash, userID) in matched {
            for contactID in contactIDsByHash[hash] ?? [] {
                result.insert(ContactMatch(contactID: contactID, userID: userID))
            }
        }
        return result.sorted { ($0.contactID, $0.userID) < ($1.contactID, $1.userID) }
    }
}
