// Account group — phone number entry rules for auth.phone and the App Clip join sheet (data, not design):
// prefill with the device region's country calling code, format as typed (`auth.phone.layout.countryCode` autoFormat),
// normalise to E.164 before sending (docs/API.md §2).
import Foundation
import PhoneNumberKit

enum PhoneNumberInput {
    /// The text the field starts with: "+" and the calling code of `region` (ISO 3166-1 alpha-2), or "+" alone
    /// when the region is unknown.
    static func initialText(region: String? = Locale.current.region?.identifier) -> String {
        guard let region, let code = CallingCodes.byRegion[region.uppercased()] else { return "+" }
        return "+" + code
    }

    /// The digits of `text` (formatting and the leading "+" dropped).
    static func digits(of text: String) -> String {
        String(text.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) && $0.isASCII }.map { Character($0) })
    }

    /// The country calling code `text` starts with (ITU-T E.164 codes are prefix-free), if any.
    static func callingCode(of text: String) -> String? {
        let digits = digits(of: text)
        for length in 1...3 where digits.count >= length {
            let prefix = String(digits.prefix(length))
            if CallingCodes.all.contains(prefix) { return prefix }
        }
        return nil
    }

    /// True when the field holds digits after the calling code (auth.phone: "continue" is enabled).
    static func hasSubscriberDigits(_ text: String) -> Bool {
        let digits = digits(of: text)
        guard let code = callingCode(of: text) else { return !digits.isEmpty }
        return digits.count > code.count
    }

    /// The region whose flag the field shows for `text` (`auth.phone.layout.countryCode`: "the flag follows the code
    /// as it is typed or edited"): the first of `preferred` (the country picked in the list, then the device region)
    /// that uses the typed calling code, else the code's main region (the first listed for it by the ITU).
    static func region(of text: String, preferring preferred: [String?]) -> String? {
        guard let code = callingCode(of: text) else { return nil }
        for case let region? in preferred where CallingCodes.byRegion[region.uppercased()] == code {
            return region.uppercased()
        }
        return CallingCodes.primaryRegion[code]
    }

    /// `text` with its calling code replaced by `code` (a country chosen in the list); what follows the old code is
    /// kept as typed. Without a recognised code the field becomes "+" and `code`.
    static func replacingCallingCode(in text: String, with code: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let current = callingCode(of: trimmed) else { return "+" + code }
        var remaining = Substring(trimmed)
        if remaining.first == "+" { remaining = remaining.dropFirst() }
        var toDrop = current.count
        while toDrop > 0, let character = remaining.first {
            remaining = remaining.dropFirst()
            if character.isASCII, character.isNumber { toDrop -= 1 }
        }
        if let first = remaining.first, first.isNumber { return "+" + code + " " + remaining } // provenance-ok: separator between the code and the number
        return "+" + code + remaining
    }

    /// The regional-indicator flag emoji of an ISO 3166-1 alpha-2 region (`auth.phone.layout.countryCode` flagArt);
    /// empty for anything else.
    static func flag(for region: String) -> String {
        let letters = region.uppercased().unicodeScalars
        guard letters.count == 2 else { return "" }
        var flag = ""
        for letter in letters {
            // Regional indicator symbols: U+1F1E6 ("A") … U+1F1FF ("Z").
            guard ("A"..."Z").contains(letter), let scalar = Unicode.Scalar(0x1F1E6 + letter.value - 0x41) else { return "" } // provenance-ok: Unicode code points
            flag.unicodeScalars.append(scalar)
        }
        return flag
    }

    /// The country list behind the flag: every region with a calling code and a name in `locale`, by name.
    static func countries(locale: Locale = .current) -> [Country] {
        CallingCodes.byRegion.compactMap { region, code -> Country? in
            guard let name = locale.localizedString(forRegionCode: region) else { return nil }
            return Country(region: region, name: name, callingCode: code)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// One row of the country list.
    struct Country: Identifiable, Hashable, Sendable {
        let region: String
        let name: String
        let callingCode: String
        var id: String { region }
        var flag: String { PhoneNumberInput.flag(for: region) }
    }

    /// The E.164 form ("+15551234567") of `text`, or nil when it is not one: a "+" (or none), then 2–15 digits not
    /// starting with 0, separated by nothing but spaces, dashes, dots, slashes and parentheses.
    static func normalized(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = ""
        for (offset, scalar) in trimmed.unicodeScalars.enumerated() {
            switch scalar {
            case "0"..."9": result.unicodeScalars.append(scalar)
            case "+" where offset == 0: continue
            case " ", "-", ".", "(", ")", "/", "\u{00A0}": continue
            default: return nil
            }
        }
        guard (2...15).contains(result.count), result.first != "0" else { return nil }
        return "+" + result
    }
}

/// As-you-type formatting of the phone field (`auth.phone.layout.countryCode` autoFormat): PhoneNumberKit's
/// `PartialFormatter`, the Swift port of libphonenumber's `AsYouTypeFormatter` that Android uses
/// (android/feature/account/.../auth/PhoneNumbers.kt). Only the shown text is formatted; what is sent stays the E.164
/// form (`PhoneNumberInput.normalized`, which drops the spaces, dashes and parentheses the formatter adds).
/// Main actor: PhoneNumberKit's types are not `Sendable`, and the field is edited on the main actor.
@MainActor
enum PhoneNumberFormatting {
    /// Loads PhoneNumberKit's metadata once, on first use.
    private static let formatter = PartialFormatter(utility: PhoneNumberUtility(), defaultRegion: "US", withPrefix: true) // provenance-ok: ISO region code, only for numbers typed without "+" (never formatted here)

    /// `text` formatted for its calling code ("+15551234567" → "+1 555-123-4567"). Text without a leading "+" is left
    /// as typed: the field is always international, and a national format would misread it.
    static func formatted(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("+") else { return text }
        let digits = PhoneNumberInput.digits(of: trimmed)
        guard !digits.isEmpty else { return "+" }
        return formatter.formatPartial("+" + digits)
    }

    /// The field text after an edit from `old` to `new`.
    /// - Typing or deleting at the end (and pasting or AutoFill over the whole text): re-formatted; the cursor stays at
    ///   the end, where the edit was.
    /// - Deleting a separator at the end ("+1 555-" → "+1 555"): the digit before it goes too, as Android's formatter
    ///   field does (otherwise the separator would come straight back).
    /// - An edit inside the number (the text after it is unchanged): kept as typed, so the cursor does not jump; the
    ///   next edit at the end formats it again. The submitted number is the same either way.
    static func edit(from old: String, to new: String) -> String {
        guard new != old else { return new }
        let oldDigits = PhoneNumberInput.digits(of: old)
        let newDigits = PhoneNumberInput.digits(of: new)
        if new.count < old.count, old.hasPrefix(new), newDigits == oldDigits, !newDigits.isEmpty {
            return formatted("+" + String(newDigits.dropLast()))
        }
        let atEnd = new.hasPrefix(old) || old.hasPrefix(new)
        let wholeText = commonSuffixLength(old, new) == 0
        guard atEnd || wholeText else { return new }
        return formatted(new)
    }

    private static func commonSuffixLength(_ a: String, _ b: String) -> Int {
        zip(a.reversed(), b.reversed()).prefix { pair in pair.0 == pair.1 }.count
    }
}

/// ITU-T E.164 assigned country calling codes by ISO 3166-1 alpha-2 region (ITU-T Recommendation E.164,
/// "List of ITU-T Recommendation E.164 assigned country codes").
enum CallingCodes {
    static let byRegion: [String: String] = {
        var table: [String: String] = [:]
        for (code, regions) in assignments {
            for region in regions.split(separator: " ") { table[String(region)] = code }
        }
        return table
    }()

    static let all: Set<String> = Set(assignments.map { $0.code })

    /// The main region of each calling code (the first listed for it), for the flag of a shared code.
    static let primaryRegion: [String: String] = {
        var table: [String: String] = [:]
        for (code, regions) in assignments {
            if let first = regions.split(separator: " ").first { table[code] = String(first) }
        }
        return table
    }()

    private static let assignments: [(code: String, regions: String)] = [
        ("1", "US CA AG AI AS BB BM BS DM DO GD GU JM KN KY LC MP MS PR SX TC TT VC VG VI UM"),
        ("7", "RU KZ"),
        ("20", "EG"), ("211", "SS"), ("212", "MA EH"), ("213", "DZ"), ("216", "TN"), ("218", "LY"),
        ("220", "GM"), ("221", "SN"), ("222", "MR"), ("223", "ML"), ("224", "GN"), ("225", "CI"), ("226", "BF"),
        ("227", "NE"), ("228", "TG"), ("229", "BJ"), ("230", "MU"), ("231", "LR"), ("232", "SL"), ("233", "GH"),
        ("234", "NG"), ("235", "TD"), ("236", "CF"), ("237", "CM"), ("238", "CV"), ("239", "ST"), ("240", "GQ"),
        ("241", "GA"), ("242", "CG"), ("243", "CD"), ("244", "AO"), ("245", "GW"), ("246", "IO"), ("247", "AC"),
        ("248", "SC"), ("249", "SD"), ("250", "RW"), ("251", "ET"), ("252", "SO"), ("253", "DJ"), ("254", "KE"),
        ("255", "TZ"), ("256", "UG"), ("257", "BI"), ("258", "MZ"), ("260", "ZM"), ("261", "MG"), ("262", "RE YT"),
        ("263", "ZW"), ("264", "NA"), ("265", "MW"), ("266", "LS"), ("267", "BW"), ("268", "SZ"), ("269", "KM"),
        ("27", "ZA"), ("290", "SH TA"), ("291", "ER"), ("297", "AW"), ("298", "FO"), ("299", "GL"),
        ("30", "GR"), ("31", "NL"), ("32", "BE"), ("33", "FR"), ("34", "ES"), ("350", "GI"), ("351", "PT"),
        ("352", "LU"), ("353", "IE"), ("354", "IS"), ("355", "AL"), ("356", "MT"), ("357", "CY"), ("358", "FI AX"),
        ("359", "BG"), ("36", "HU"), ("370", "LT"), ("371", "LV"), ("372", "EE"), ("373", "MD"), ("374", "AM"),
        ("375", "BY"), ("376", "AD"), ("377", "MC"), ("378", "SM"), ("380", "UA"), ("381", "RS"), ("382", "ME"),
        ("383", "XK"), ("385", "HR"), ("386", "SI"), ("387", "BA"), ("389", "MK"), ("39", "IT VA"), ("40", "RO"),
        ("41", "CH"), ("420", "CZ"), ("421", "SK"), ("423", "LI"), ("43", "AT"), ("44", "GB GG IM JE"), ("45", "DK"),
        ("46", "SE"), ("47", "NO SJ"), ("48", "PL"), ("49", "DE"),
        ("500", "FK GS"), ("501", "BZ"), ("502", "GT"), ("503", "SV"), ("504", "HN"), ("505", "NI"), ("506", "CR"),
        ("507", "PA"), ("508", "PM"), ("509", "HT"), ("51", "PE"), ("52", "MX"), ("53", "CU"), ("54", "AR"),
        ("55", "BR"), ("56", "CL"), ("57", "CO"), ("58", "VE"), ("590", "GP BL MF"), ("591", "BO"), ("592", "GY"),
        ("593", "EC"), ("594", "GF"), ("595", "PY"), ("596", "MQ"), ("597", "SR"), ("598", "UY"), ("599", "CW BQ"),
        ("60", "MY"), ("61", "AU CX CC"), ("62", "ID"), ("63", "PH"), ("64", "NZ PN"), ("65", "SG"), ("66", "TH"),
        ("670", "TL"), ("672", "NF AQ"), ("673", "BN"), ("674", "NR"), ("675", "PG"), ("676", "TO"), ("677", "SB"),
        ("678", "VU"), ("679", "FJ"), ("680", "PW"), ("681", "WF"), ("682", "CK"), ("683", "NU"), ("685", "WS"),
        ("686", "KI"), ("687", "NC"), ("688", "TV"), ("689", "PF"), ("690", "TK"), ("691", "FM"), ("692", "MH"),
        ("81", "JP"), ("82", "KR"), ("84", "VN"), ("850", "KP"), ("852", "HK"), ("853", "MO"), ("855", "KH"),
        ("856", "LA"), ("86", "CN"), ("880", "BD"), ("886", "TW"),
        ("90", "TR"), ("91", "IN"), ("92", "PK"), ("93", "AF"), ("94", "LK"), ("95", "MM"), ("960", "MV"),
        ("961", "LB"), ("962", "JO"), ("963", "SY"), ("964", "IQ"), ("965", "KW"), ("966", "SA"), ("967", "YE"),
        ("968", "OM"), ("970", "PS"), ("971", "AE"), ("972", "IL"), ("973", "BH"), ("974", "QA"), ("975", "BT"),
        ("976", "MN"), ("977", "NP"), ("98", "IR"), ("992", "TJ"), ("993", "TM"), ("994", "AZ"), ("995", "GE"),
        ("996", "KG"), ("998", "UZ"),
    ]
}
