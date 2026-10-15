// swift-tools-version:6.0
//
// AppCore: the app's shared code.
//
//   AppModels     Foundation only. Builds and tests on Linux (`swift test`, CI job `ios-core`).
//   DesignSystem  SwiftUI primitives the generated Tokens/Copy reference + Generated/ (tools/designgen.mjs).
//   AppServices   AVFoundation, Photos, UserNotifications, ActivityKit, WidgetKit, Contacts, RevenueCat.
//
// On Linux only AppModels exists; the Apple-only targets are left out of the manifest so
// `swift build` / `swift test` work there.
import PackageDescription

#if os(Linux)
let package = Package(
    name: "AppCore",
    products: [
        .library(name: "AppModels", targets: ["AppModels"]),
    ],
    targets: [
        .target(name: "AppModels"),
        .testTarget(name: "AppModelsTests", dependencies: ["AppModels"]),
    ]
)
#else
let package = Package(
    name: "AppCore",
    platforms: [.iOS("17.2")],
    products: [
        .library(name: "AppModels", targets: ["AppModels"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "AppServices", targets: ["AppServices"]),
    ],
    dependencies: [
        // Keep in sync with ios/project.yml `packages.RevenueCat`.
        .package(url: "https://github.com/RevenueCat/purchases-ios.git", from: "5.95.0"),
    ],
    targets: [
        .target(name: "AppModels"),
        .target(name: "DesignSystem", dependencies: ["AppModels"]),
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
    ]
)
#endif
