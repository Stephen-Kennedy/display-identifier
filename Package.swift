// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DisplayIdentifier",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "display-identify", targets: ["DisplayIdentifier"])
    ],
    targets: [
        .executableTarget(
            name: "DisplayIdentifier",
            path: "Sources/DisplayIdentifier"
        )
    ]
)
