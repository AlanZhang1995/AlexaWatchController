// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AlexaWatchController",
    platforms: [
        .iOS(.v16),
        .watchOS(.v9),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AlexaWatchControllerShared",
            targets: ["AlexaWatchControllerShared"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.12.0"),
    ],
    targets: [
        // Shared library containing data models
        .target(
            name: "AlexaWatchControllerShared",
            dependencies: [],
            path: "Shared"
        ),
        // Property-based tests for shared models
        .testTarget(
            name: "SharedTests",
            dependencies: [
                "AlexaWatchControllerShared",
                "SwiftCheck",
            ],
            path: "Tests/SharedTests"
        ),
    ]
)
