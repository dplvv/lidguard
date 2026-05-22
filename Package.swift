// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "lidguard",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "LidGuardGUI", targets: ["LidGuardGUI"]),
    ],
    targets: [
        .executableTarget(
            name: "LidGuardGUI",
            path: "AppSource",
            linkerSettings: [
                .linkedFramework("AppKit"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
