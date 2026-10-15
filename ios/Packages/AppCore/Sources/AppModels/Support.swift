import Foundation

/// Fills `{name}` placeholders (the copy schema's placeholder syntax, docs/CONVENTIONS.md §4).
/// Placeholders without a value are left as they are, matching `t()` in the generated TypeScript.
public enum PlaceholderTemplate {
    public static func render(_ template: String, _ values: [String: String]) -> String {
        guard template.contains("{") else { return template }
        var result = ""
        result.reserveCapacity(template.count)
        var index = template.startIndex
        while index < template.endIndex {
            let character = template[index]
            if character == "{", let close = template[index...].firstIndex(of: "}") {
                let name = String(template[template.index(after: index)..<close])
                if isPlaceholderName(name), let value = values[name] {
                    result += value
                    index = template.index(after: close)
                    continue
                }
            }
            result.append(character)
            index = template.index(after: index)
        }
        return result
    }

    /// `[a-zA-Z_][a-zA-Z0-9_]*`
    static func isPlaceholderName(_ name: String) -> Bool {
        guard let first = name.unicodeScalars.first else { return false }
        func isLetter(_ s: Unicode.Scalar) -> Bool { (s >= "a" && s <= "z") || (s >= "A" && s <= "Z") || s == "_" }
        func isDigit(_ s: Unicode.Scalar) -> Bool { s >= "0" && s <= "9" }
        return isLetter(first) && name.unicodeScalars.allSatisfy { isLetter($0) || isDigit($0) }
    }
}

/// A permission's state, shared by camera, microphone, photos, contacts and notifications.
public enum PermissionStatus: String, Hashable, Sendable, CaseIterable {
    case notDetermined
    case granted
    /// Photos (selected photos only) or contacts (selected contacts only, iOS 18).
    case limited
    case denied
    /// Blocked by parental controls / device management; the user cannot change it.
    case restricted

    public var allowsAccess: Bool { self == .granted || self == .limited }
}

/// Push tokens are sent to the backend as lowercase hex.
public enum PushToken {
    public static func hex(_ data: Data) -> String {
        let digits: [Character] = Array("0123456789abcdef")
        var result = ""
        result.reserveCapacity(data.count * 2)
        for byte in data {
            result.append(digits[Int(byte >> 4)])
            result.append(digits[Int(byte & 0x0F)])
        }
        return result
    }
}
