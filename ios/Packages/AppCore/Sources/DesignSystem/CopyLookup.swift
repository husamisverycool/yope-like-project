import AppModels
import Foundation

/// Backs the generated `Copy.*` accessors. Each string's default is its canonical text from
/// design/copy.json; a `Localizable.strings` entry with the same key in the running bundle
/// (the app or extension) overrides it, which is how translations plug in later.
public enum CopyLookup {
    /// Returned by `Bundle.localizedString` when the key is absent; never a real string.
    private static let missing = "\u{1}copy-missing\u{1}"

    public static func string(_ key: String, default defaultValue: String) -> String {
        let localized = Bundle.main.localizedString(forKey: key, value: missing, table: nil)
        return localized == missing ? defaultValue : localized
    }

    /// Fills `{name}` placeholders in the (possibly localized) string.
    public static func format(_ key: String, default defaultValue: String, _ params: [String: String]) -> String {
        PlaceholderTemplate.render(string(key, default: defaultValue), params)
    }
}
