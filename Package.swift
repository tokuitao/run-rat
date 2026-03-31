// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RunRat",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "RunRat",
            targets: ["RunRat"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "RunRat",
            resources: [
                .process("Resources"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
