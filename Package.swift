// swift-tools-version: 5.5

import PackageDescription

let package = Package(
    name: "Koe",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Koe",
            path: "Sources/Koe"
        )
    ]
)
