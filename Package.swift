// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Netwatch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Netwatch", targets: ["Netwatch"])
    ],
    targets: [
        .executableTarget(
            name: "Netwatch",
            path: "Sources/Netwatch"
        ),
        .testTarget(
            name: "NetwatchTests",
            dependencies: ["Netwatch"],
            path: "Tests/NetwatchTests"
        )
    ]
)
