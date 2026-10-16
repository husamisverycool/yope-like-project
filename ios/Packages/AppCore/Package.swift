// swift-tools-version:6.0
//
// AppCore: the app's shared code.
//
//   AppModels     Foundation only. Builds and tests on Linux (`swift test`, CI job `ios-core`).
//   AppData       Backend client (supabase-swift): auth, repositories, uploads, realtime, offline
//                 cache, session glue. Builds and tests on Linux too; Apple-only parts (Keychain
//                 session, background URLSession uploads, NWPathMonitor) are behind `canImport`.
//                 Its integration tests run against the local Supabase stack and skip themselves
//                 when it is not reachable.
//   DesignSystem  SwiftUI primitives the generated Tokens/Copy reference + Generated/ (tools/designgen.mjs).
//   AppServices   AVFoundation, Photos, UserNotifications, ActivityKit, WidgetKit, Contacts, RevenueCat.
//
// On Linux only AppModels and AppData exist; the Apple-only targets are left out of the manifest
// so `swift build` / `swift test` work there.
import PackageDescription

// Keep in sync with ios/project.yml `packages.Supabase`.
let supabase: Package.Dependency = .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.55.4")
// Already resolved through supabase-swift; the integration tests use it to sign test JWTs (HS256).
let swiftCrypto: Package.Dependency = .package(url: "https://github.com/apple/swift-crypto.git", "3.0.0"..<"5.0.0")

let appDataTarget: Target = .target(
    name: "AppData",
    dependencies: [
        "AppModels",
        .product(name: "Supabase", package: "supabase-swift"),
    ],
    swiftSettings: [
        // URLSession delegates, NWPathMonitor and Security carry SDK-version-dependent Sendable
        // annotations. Swift 5 mode with complete checking reports concurrency issues as warnings
        // instead of failing the build on a newer or older SDK (same as AppServices).
        .swiftLanguageMode(.v5),
        .enableUpcomingFeature("StrictConcurrency"),
    ]
)

let appDataTestsTarget: Target = .testTarget(
    name: "AppDataTests",
    dependencies: [
        "AppData",
        "AppModels",
        .product(name: "Supabase", package: "supabase-swift"),
        .product(name: "Crypto", package: "swift-crypto"),
    ],
    swiftSettings: [
        .swiftLanguageMode(.v5),
        .enableUpcomingFeature("StrictConcurrency"),
    ]
)

#if os(Linux)
let package = Package(
    name: "AppCore",
    products: [
        .library(name: "AppModels", targets: ["AppModels"]),
        .library(name: "AppData", targets: ["AppData"]),
    ],
    dependencies: [supabase, swiftCrypto],
    targets: [
        .target(name: "AppModels"),
        appDataTarget,
        .testTarget(name: "AppModelsTests", dependencies: ["AppModels"]),
        appDataTestsTarget,
    ]
)
#else
let package = Package(
    name: "AppCore",
    // macOS is listed only so `swift build` on a Mac resolves supabase-swift (macOS 13+); the
    // shipping targets are iOS.
    platforms: [.iOS("17.2"), .macOS(.v14)],
    products: [
        .library(name: "AppModels", targets: ["AppModels"]),
        .library(name: "AppData", targets: ["AppData"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "AppServices", targets: ["AppServices"]),
    ],
    dependencies: [
        // Keep in sync with ios/project.yml `packages.RevenueCat`.
        .package(url: "https://github.com/RevenueCat/purchases-ios.git", from: "5.95.0"),
        supabase,
        swiftCrypto,
    ],
    targets: [
        .target(name: "AppModels"),
        appDataTarget,
        // Fonts/: the bundled display faces (SIL OFL), registered at first use (DSBundledFonts).
        .target(name: "DesignSystem", dependencies: ["AppModels"], resources: [.copy("Fonts")]),
        .target(
            name: "AppServices",
            dependencies: [
                "AppModels",
                "DesignSystem",
                .product(name: "RevenueCat", package: "purchases-ios"),
            ],
            swiftSettings: [
                // AVFoundation / ActivityKit / UserNotifications delegate APIs carry SDK-version-dependent
                // Sendable annotations. Swift 5 mode with complete checking reports every concurrency
                // issue as a warning instead of failing the build on a newer or older SDK.
                .swiftLanguageMode(.v5),
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(name: "AppModelsTests", dependencies: ["AppModels"]),
        appDataTestsTarget,
    ]
)
#endif
