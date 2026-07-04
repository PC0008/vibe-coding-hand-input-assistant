// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VibeHandInputAssistant",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "VibeHandInputAssistant", targets: ["VibeHandInputAssistant"])
    ],
    targets: [
        .executableTarget(
            name: "VibeHandInputAssistant",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices")
            ]
        )
    ]
)

