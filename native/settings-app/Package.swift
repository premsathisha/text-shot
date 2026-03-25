// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TextShotSettings",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "text-shot", targets: ["TextShotSettings"])
    ],
    dependencies: [
        .package(path: "Vendor/KeyboardShortcuts"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.9.0"),
        .package(url: "https://github.com/swiftlang/swift-testing.git", branch: "release/6.2")
    ],
    targets: [
        .executableTarget(
            name: "TextShotSettings",
            dependencies: [
                "KeyboardShortcuts",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/TextShotSettings",
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("Vision"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "TextShotSettingsTests",
            dependencies: [
                "TextShotSettings",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/TextShotSettingsTests"
        )
    ]
)
