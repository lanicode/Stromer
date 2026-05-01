// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VictronParser",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "VictronParser",
            targets: ["VictronParser"]
        )
    ],
    targets: [
        .target(name: "VictronParser"),
        .testTarget(
            name: "VictronParserTests",
            dependencies: ["VictronParser"]
        )
    ]
)
