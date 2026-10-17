import Foundation

/// `config/app.json` — the single source of app configuration — decoded at runtime.
/// The App and App Clip bundle the file as `app.json`. Values the owner has not provided yet
/// (level BLOCKED) decode as nil.
public struct AppConfiguration: Hashable, Sendable {
    public static let resourceName = "app"
    public static let resourceExtension = "json"

    public var displayName: String?
    public var domain: String?
    public var iOSBundleID: String?
    public var iOSDeploymentTarget: String?
    public var supabaseURL: URL?
    public var supabaseAnonKey: String?
    public var revenueCatAPIKey: String?
    public var premiumEntitlement: String?
    public var monthlyProductID: String?
    public var yearlyProductID: String?
    public var privacyURL: URL?
    public var termsURL: URL?
    /// `support.email`: Settings → Contact Us (a mail to this address); nil until the owner sets it.
    public var supportEmail: String?

    public init(
        displayName: String? = nil,
        domain: String? = nil,
        iOSBundleID: String? = nil,
        iOSDeploymentTarget: String? = nil,
        supabaseURL: URL? = nil,
        supabaseAnonKey: String? = nil,
        revenueCatAPIKey: String? = nil,
        premiumEntitlement: String? = nil,
        monthlyProductID: String? = nil,
        yearlyProductID: String? = nil,
        privacyURL: URL? = nil,
        termsURL: URL? = nil,
        supportEmail: String? = nil
    ) {
        self.displayName = displayName
        self.domain = domain
        self.iOSBundleID = iOSBundleID
        self.iOSDeploymentTarget = iOSDeploymentTarget
        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = supabaseAnonKey
        self.revenueCatAPIKey = revenueCatAPIKey
        self.premiumEntitlement = premiumEntitlement
        self.monthlyProductID = monthlyProductID
        self.yearlyProductID = yearlyProductID
        self.privacyURL = privacyURL
        self.termsURL = termsURL
        self.supportEmail = supportEmail
    }

    /// `mailto:` for Contact Us; nil without a support address (or one that does not form a URL).
    public var supportMailURL: URL? {
        guard let supportEmail, supportEmail.contains("@"), !supportEmail.contains(where: \.isWhitespace) else { return nil }
        return URL(string: "mailto:\(supportEmail)")
    }

    public static func load(from data: Data) throws -> AppConfiguration {
        let file = try JSONDecoder().decode(File.self, from: data)
        return AppConfiguration(
            displayName: file.displayName?.value.nonEmpty,
            domain: file.domain?.value.nonEmpty?.lowercased(),
            iOSBundleID: file.ios?.bundleId.nonEmpty,
            iOSDeploymentTarget: file.ios?.deploymentTarget.nonEmpty,
            supabaseURL: file.supabase?.url.nonEmpty.flatMap(URL.init(string:)),
            supabaseAnonKey: file.supabase?.anonKey.nonEmpty,
            revenueCatAPIKey: file.revenuecat?.iosApiKey.nonEmpty,
            premiumEntitlement: file.revenuecat?.entitlement.nonEmpty,
            monthlyProductID: file.premium?.productIds?.monthly.nonEmpty,
            yearlyProductID: file.premium?.productIds?.yearly.nonEmpty,
            privacyURL: file.legal?.privacyUrl.nonEmpty.flatMap(URL.init(string:)),
            termsURL: file.legal?.termsUrl.nonEmpty.flatMap(URL.init(string:)),
            supportEmail: file.support?.email.nonEmpty
        )
    }

    /// Loads the bundled `app.json`; nil when the resource is missing or unreadable.
    public static func load(from bundle: Bundle) -> AppConfiguration? {
        guard let url = bundle.url(forResource: resourceName, withExtension: resourceExtension),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? load(from: data)
    }

    // The file's shape (see config/app.json). Every field is optional so a partially filled
    // file still loads.
    private struct File: Decodable {
        struct Leveled: Decodable { var value: String? }
        struct IOS: Decodable { var bundleId: String?; var deploymentTarget: String? }
        struct Supabase: Decodable { var url: String?; var anonKey: String? }
        struct RevenueCat: Decodable { var iosApiKey: String?; var entitlement: String? }
        struct Premium: Decodable {
            struct ProductIDs: Decodable { var monthly: String?; var yearly: String? }
            var productIds: ProductIDs?
        }
        struct Legal: Decodable { var privacyUrl: String?; var termsUrl: String? }
        struct Support: Decodable { var email: String? }

        var displayName: Leveled?
        var domain: Leveled?
        var ios: IOS?
        var supabase: Supabase?
        var revenuecat: RevenueCat?
        var premium: Premium?
        var legal: Legal?
        var support: Support?
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
