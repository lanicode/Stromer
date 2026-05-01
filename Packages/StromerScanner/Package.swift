// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "StromerScanner",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "StromerScanner",
            targets: ["StromerScanner"]
        )
    ],
    dependencies: [
        .package(path: "../VictronParser")
    ],
    targets: [
        .target(
            name: "StromerScanner",
            dependencies: ["VictronParser"]
        ),
        .testTarget(
            name: "StromerScannerTests",
            dependencies: ["StromerScanner"]
        )
    ]
)
