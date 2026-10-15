import Foundation
import XCTest
@testable import AppModels

/// Reads the repository's real configuration files, so a change to config/app.json that the
/// iOS build settings do not follow fails here (CI job `ios-core`).
final class AppConfigurationTests: XCTestCase {
    /// <repo>/ios/Packages/AppCore/Tests/AppModelsTests/<this file>
    static let repoRoot: URL = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { url.deleteLastPathComponent() }
        return url
    }()

    private func read(_ relativePath: String) throws -> Data {
        try Data(contentsOf: Self.repoRoot.appendingPathComponent(relativePath))
    }

    /// `KEY = value` lines of an xcconfig (comments and includes skipped).
    private func xcconfig(_ relativePath: String) throws -> [String: String] {
        let text = try XCTUnwrap(String(data: try read(relativePath), encoding: .utf8))
        var values: [String: String] = [:]
        for rawLine in text.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.hasPrefix("//"), !line.hasPrefix("#"), let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            var value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if let comment = value.range(of: " //") { value = String(value[..<comment.lowerBound]).trimmingCharacters(in: .whitespaces) }
            values[key] = value
        }
        return values
    }

    func testDecodesRepositoryConfig() throws {
        let configuration = try AppConfiguration.load(from: try read("config/app.json"))
        XCTAssertNotNil(configuration.iOSBundleID)
        XCTAssertNotNil(configuration.premiumEntitlement)
    }

    func testBlockedValuesDecodeAsNil() throws {
        let json = Data("""
        {
          "displayName": { "value": null, "level": "BLOCKED" },
          "domain": { "value": "Example.TEST", "level": "SOURCED" },
          "ios": { "bundleId": "com.example.x", "teamId": null, "deploymentTarget": "17.2" },
          "supabase": { "url": "https://abc.supabase.co", "anonKey": "" },
          "revenuecat": { "iosApiKey": null, "entitlement": "premium" },
          "premium": { "productIds": { "monthly": "m", "yearly": "y" } },
          "legal": { "privacyUrl": null }
        }
        """.utf8)
        let configuration = try AppConfiguration.load(from: json)
        XCTAssertNil(configuration.displayName)
        XCTAssertEqual(configuration.domain, "example.test")
        XCTAssertEqual(configuration.iOSBundleID, "com.example.x")
        XCTAssertEqual(configuration.supabaseURL?.host, "abc.supabase.co")
        XCTAssertNil(configuration.supabaseAnonKey, "empty string counts as missing")
        XCTAssertNil(configuration.revenueCatAPIKey)
        XCTAssertEqual(configuration.premiumEntitlement, "premium")
        XCTAssertEqual(configuration.monthlyProductID, "m")
        XCTAssertNil(configuration.termsURL)
        XCTAssertEqual(DeepLinkParser(configuration: configuration).parse(URL(string: "https://example.test/i/t")!), .invite(token: "t"))
    }

    func testXcodeBuildSettingsFollowConfig() throws {
        let configuration = try AppConfiguration.load(from: try read("config/app.json"))
        let base = try xcconfig("ios/Config/Base.xcconfig")
        XCTAssertEqual(base["APP_BUNDLE_ID"], configuration.iOSBundleID, "ios/Config/Base.xcconfig APP_BUNDLE_ID must equal config/app.json ios.bundleId")
        XCTAssertEqual(base["IPHONEOS_DEPLOYMENT_TARGET"], configuration.iOSDeploymentTarget, "deployment target must equal config/app.json ios.deploymentTarget")
        if let domain = configuration.domain {
            XCTAssertEqual(base["APP_DOMAIN"], domain, "APP_DOMAIN must equal config/app.json domain")
        }
    }

    func testPackageManifestDeploymentTarget() throws {
        let configuration = try AppConfiguration.load(from: try read("config/app.json"))
        let manifest = try XCTUnwrap(String(data: try read("ios/Packages/AppCore/Package.swift"), encoding: .utf8))
        let target = try XCTUnwrap(configuration.iOSDeploymentTarget)
        XCTAssertTrue(manifest.contains(".iOS(\"\(target)\")"), "Package.swift platforms must use config/app.json ios.deploymentTarget")
    }
}
