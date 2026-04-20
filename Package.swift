// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Koe",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Koe",
            path: "Sources/Koe",
            exclude: ["Resources/Info.plist"],
            resources: [
                .copy("Resources/whisper-cli"),
                .copy("Resources/ggml-base.en.bin")
            ]
        )
    ]
)
