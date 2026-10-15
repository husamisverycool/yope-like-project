import Foundation
import XCTest
@testable import AppModels

final class PlaceholderTemplateTests: XCTestCase {
    func testRender() {
        XCTAssertEqual(PlaceholderTemplate.render("Hi {name}!", ["name": "Ana"]), "Hi Ana!")
        XCTAssertEqual(PlaceholderTemplate.render("{a}{b} {a}", ["a": "1", "b": "2"]), "12 1")
        XCTAssertEqual(PlaceholderTemplate.render("{missing} stays", [:]), "{missing} stays")
        XCTAssertEqual(PlaceholderTemplate.render("{not valid} {1x} {}", ["not valid": "x", "1x": "y"]), "{not valid} {1x} {}")
        XCTAssertEqual(PlaceholderTemplate.render("no braces", ["a": "b"]), "no braces")
        XCTAssertEqual(PlaceholderTemplate.render("open { only", [:]), "open { only")
        XCTAssertEqual(PlaceholderTemplate.render("{app_name} · {group}", ["app_name": "X", "group": "{app_name}"]), "X · {app_name}", "values are not re-expanded")
    }
}

final class PushTokenTests: XCTestCase {
    func testHex() {
        XCTAssertEqual(PushToken.hex(Data([0x00, 0x0F, 0xA0, 0xFF])), "000fa0ff")
        XCTAssertEqual(PushToken.hex(Data()), "")
    }
}

final class ContactMatchingTests: XCTestCase {
    func testPhoneNumberCanonicalForm() {
        XCTAssertEqual(PhoneNumber("+1 (415) 555-0100")?.canonical, "+14155550100")
        XCTAssertEqual(PhoneNumber(" 0612.34.56.78 ")?.canonical, "0612345678")
        XCTAssertNil(PhoneNumber("555-CALL"))
        XCTAssertNil(PhoneNumber("1+2"))
        XCTAssertNil(PhoneNumber("+"))
        XCTAssertNil(PhoneNumber(""))
    }

    struct ReversingHasher: PhoneNumberHashing {
        func hash(_ number: PhoneNumber) -> String { String(number.canonical.reversed()) }
    }

    actor RecordingBackend: ContactMatching {
        private(set) var received: Set<String> = []
        let users: [String: String]
        init(users: [String: String]) { self.users = users }
        func matchingUserIDs(forHashes hashes: Set<String>) async throws -> [String: String] {
            received = hashes
            return users.filter { hashes.contains($0.key) }
        }
    }

    func testMatcherSendsOnlyHashes() async throws {
        let contacts = [
            LocalContact(id: "c1", displayName: "A", phoneNumbers: [PhoneNumber("+1 415 555 0100")!]),
            LocalContact(id: "c2", displayName: "B", phoneNumbers: [PhoneNumber("+14155550100")!, PhoneNumber("0612")!]),
            LocalContact(id: "c3", displayName: "C", phoneNumbers: []),
        ]
        let backend = RecordingBackend(users: ["00105555141+": "u1"])
        let matches = try await ContactMatcher(hasher: ReversingHasher(), backend: backend).matches(for: contacts)
        let received = await backend.received
        XCTAssertEqual(received, ["00105555141+", "2160"])
        XCTAssertFalse(received.contains("+14155550100"))
        XCTAssertEqual(matches, [ContactMatch(contactID: "c1", userID: "u1"), ContactMatch(contactID: "c2", userID: "u1")])
    }

    func testNoNumbersNoRequest() async throws {
        let backend = RecordingBackend(users: [:])
        let matches = try await ContactMatcher(hasher: ReversingHasher(), backend: backend).matches(for: [])
        XCTAssertEqual(matches, [])
        let received = await backend.received
        XCTAssertEqual(received, [])
    }
}

final class PermissionStatusTests: XCTestCase {
    func testAllowsAccess() {
        XCTAssertEqual(PermissionStatus.allCases.filter(\.allowsAccess), [.granted, .limited])
    }
}
