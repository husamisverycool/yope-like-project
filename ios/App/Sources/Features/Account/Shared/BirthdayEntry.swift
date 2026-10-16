// Account group — auth.agegate birthday entry rules (`auth.agegate.layout.dateEntry`, FTC neutral age screen):
// free numeric entry in the device locale's short-date order, separators inserted as the person types, no default.
import AppData
import Foundation

/// The locale's numeric date order and the typing rules of the birthday field.
struct BirthdayEntry: Equatable {
    enum Component: Hashable {
        case month
        case day
        case year

        /// Digits typed for the component (months and days 2, years 4).
        var width: Int {
            switch self {
            case .month, .day: return 2
            case .year: return 4
            }
        }

        /// Letter shown in the placeholder (`{date_format}` = the pattern in lowercase letters).
        var letter: Character {
            switch self {
            case .month: return "m"
            case .day: return "d"
            case .year: return "y"
            }
        }
    }

    /// Components in the locale's order.
    let components: [Component]
    /// `separators[i]` follows `components[i]` (the last is empty).
    let separators: [String]

    /// `DateFormatter.dateFormat(fromTemplate: "MMddyyyy", options: 0, locale:)` (the token's method).
    init(locale: Locale = .current) {
        let pattern = DateFormatter.dateFormat(fromTemplate: "MMddyyyy", options: 0, locale: locale) ?? "MMddyyyy" // provenance-ok: date template named by auth.agegate.layout.dateEntry
        self.init(pattern: pattern)
    }

    init(pattern: String) {
        var components: [Component] = []
        var separators: [String] = []
        var pending = ""
        var current: Component?
        for character in pattern {
            if let component = Self.component(for: character) {
                if component != current {
                    if current != nil { separators.append(pending) }
                    pending = ""
                    components.append(component)
                    current = component
                }
            } else if character != "'", current != nil {
                pending.append(character)
            }
        }
        separators.append("")
        if components.count == 3, Set(components).count == 3 {
            self.components = components
            self.separators = separators
        } else {
            self.components = [.month, .day, .year]
            self.separators = ["/", "/", ""] // provenance-ok: fallback only when the locale pattern has no M/d/y
        }
    }

    private static func component(for character: Character) -> Component? {
        switch character {
        case "M", "L": return .month
        case "d": return .day
        case "y", "u": return .year
        default: return nil
        }
    }

    /// Total digits of a complete date.
    var digitCount: Int { components.reduce(0) { $0 + $1.width } }

    /// `{date_format}`: e.g. "mm/dd/yyyy".
    var placeholderFormat: String {
        var result = ""
        for (index, component) in components.enumerated() {
            result += String(repeating: String(component.letter), count: component.width)
            result += separators[index]
        }
        return result
    }

    /// The field text for `digits`: digits fill the components in order; a separator is inserted when the next
    /// component's first digit is typed.
    func text(forDigits digits: String) -> String {
        var remaining = Substring(digits.prefix(digitCount))
        var result = ""
        for (index, component) in components.enumerated() {
            guard !remaining.isEmpty else { break }
            let part = remaining.prefix(component.width)
            result += part
            remaining = remaining.dropFirst(part.count)
            if !remaining.isEmpty { result += separators[index] }
        }
        return result
    }

    /// The new field text after an edit from `old` to `new`: re-formatted from the digits; deleting a separator
    /// deletes the digit before it.
    func edit(from old: String, to new: String) -> String {
        var digits = PhoneNumberInput.digits(of: new)
        if new.count < old.count, digits == PhoneNumberInput.digits(of: old), !digits.isEmpty {
            digits.removeLast()
        }
        return text(forDigits: digits)
    }

    func isComplete(_ text: String) -> Bool {
        PhoneNumberInput.digits(of: text).count == digitCount
    }

    /// The date a complete entry names; nil when incomplete or not a calendar date.
    func date(from text: String) -> LocalDate? {
        let digits = Array(PhoneNumberInput.digits(of: text))
        guard digits.count == digitCount else { return nil }
        var values: [Component: Int] = [:]
        var offset = 0
        for component in components {
            values[component] = Int(String(digits[offset..<(offset + component.width)]))
            offset += component.width
        }
        guard let year = values[.year], let month = values[.month], let day = values[.day] else { return nil }
        return LocalDate(year: year, month: month, day: day)
    }
}

