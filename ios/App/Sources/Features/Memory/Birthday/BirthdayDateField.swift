// The birthday entry of `auth.agegate` (`auth.agegate.layout.dateEntry`), reused by `birthday.add`
// (design/surfaces/birthday.add.md: "Date entry is the auth.agegate component"). The account pass
// owns that component; it was not available to this pass, so it is built here from the same tokens:
// the Yope form field (`groups.create.color.field`, `size.global.fieldHeight`, `radius.global.field`,
// `groups.create.fontSize/fontWeight.fieldText`, centred), numeric keyboard, separators inserted in
// the locale's numeric short-date order, empty by default, no default year.
import AppData
import DesignSystem
import Foundation
import SwiftUI

/// Free numeric date entry in the device locale's order (e.g. "MM/dd/yyyy" or "dd.MM.yyyy").
struct BirthdayDateEntry: Equatable, Sendable {
    struct Part: Equatable, Sendable {
        /// `M`, `d` or `y`.
        let field: Character
        let length: Int
    }

    /// The locale pattern shown in the placeholder (`auth.agegate.field.placeholder`, `{date_format}`).
    let pattern: String
    let parts: [Part]
    let separators: [String]

    /// The template named by `auth.agegate.layout.dateEntry` ("dateFormat(fromTemplate: MMddyyyy)").
    static let template = "MMddyyyy" // provenance-ok: date template quoted in the token auth.agegate.layout.dateEntry.format

    init(locale: Locale = .current) {
        let localized = DateFormatter.dateFormat(fromTemplate: Self.template, options: 0, locale: locale) ?? Self.template
        self.init(pattern: localized)
    }

    init(pattern: String) {
        var parts: [Part] = []
        var separators: [String] = []
        var pendingSeparator = ""
        var last: Character?
        for character in pattern {
            if character == "M" || character == "d" || character == "y" {
                if character != last {
                    if !parts.isEmpty { separators.append(pendingSeparator) }
                    pendingSeparator = ""
                    // Two-digit month and day, four-digit year (the template's field widths).
                    parts.append(Part(field: character, length: character == "y" ? 4 : 2))
                }
                last = character
            } else if character != "'" {
                pendingSeparator.append(character)
                last = nil
            }
        }
        self.parts = parts
        self.separators = separators
        // Placeholder pattern with the normalised widths ("MM/dd/yyyy").
        var display = ""
        for (index, part) in parts.enumerated() {
            if index > 0 { display += separators[index - 1] }
            display += String(repeating: part.field, count: part.length)
        }
        self.pattern = display
    }

    var digitCount: Int { parts.reduce(0) { $0 + $1.length } }

    /// Keeps the digits and inserts the separators between filled parts (never a trailing one,
    /// so deleting works as typed).
    func format(_ input: String) -> String {
        let digits = Array(input.filter(\.isASCIIDigit).prefix(digitCount))
        var result = ""
        var offset = 0
        for (index, part) in parts.enumerated() where offset < digits.count {
            if index > 0 { result += separators[index - 1] }
            let end = min(offset + part.length, digits.count)
            result += String(digits[offset..<end])
            offset = end
        }
        return result
    }

    /// True once every digit is typed (the date may still be invalid).
    func isComplete(_ text: String) -> Bool {
        text.filter(\.isASCIIDigit).count == digitCount
    }

    /// The typed date, when complete and a real calendar day.
    func date(from text: String) -> LocalDate? {
        let digits = Array(text.filter(\.isASCIIDigit))
        guard digits.count == digitCount else { return nil }
        var values: [Character: Int] = [:]
        var offset = 0
        for part in parts {
            values[part.field] = Int(String(digits[offset..<(offset + part.length)]))
            offset += part.length
        }
        guard let year = values["y"], let month = values["M"], let day = values["d"] else { return nil }
        return LocalDate(year: year, month: month, day: day)
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}

/// The field itself.
struct BirthdayDateField: View {
    @Binding var text: String
    var entry = BirthdayDateEntry()

    private var style: DSTextStyle {
        // Field text scales with `subheadline` (auth.agegate accessibility: "field … subheadline").
        MemoryType.style(Tokens.Fonts.globalFamily, size: Tokens.FontSizes.groupsCreateFontSizeFieldText,
                         weight: Tokens.FontWeights.groupsCreateFontWeightFieldText,
                         relativeTo: Tokens.Layouts.GlobalTextStyleMap.listSubtitle)
    }

    var body: some View {
        TextField(text: $text, prompt: Text(Copy.authAgegateFieldPlaceholder(dateFormat: entry.pattern))
            .foregroundStyle(Tokens.Colors.globalTextSecondary)) {
            Text(Copy.authAgegateFieldAccessibilityLabel)
        }
        .keyboardType(.numberPad)
        .textContentType(.birthdate)
        .dsTextStyle(style)
        .foregroundStyle(Tokens.Colors.globalTextPrimary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: Tokens.Sizes.globalFieldHeight)
        .background(Tokens.Colors.groupsCreateColorField, in: RoundedRectangle(cornerRadius: Tokens.Radii.globalField))
        .accessibilityLabel(Copy.authAgegateFieldAccessibilityLabel)
        .accessibilityHint(entry.pattern)
        .onChange(of: text) { _, newValue in
            let formatted = entry.format(newValue)
            if formatted != newValue { text = formatted }
        }
        .accessibilityIdentifier("birthday.add.field")
    }
}
