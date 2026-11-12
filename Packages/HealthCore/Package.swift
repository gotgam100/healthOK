// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HealthCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "HealthCore", targets: ["HealthCore"]),
    ],
    targets: [
        .target(name: "HealthCore", resources: [.process("Resources")]),
        .testTarget(name: "HealthCoreTests", dependencies: ["HealthCore"]),
    ]
)
