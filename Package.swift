// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Kairo",
    platforms: [
        .iOS(.v15),
        .macOS(.v13),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(name: "Kairo", targets: ["Kairo"])
    ],
    targets: [
        .target(name: "Kairo", path: "Sources/Kairo"),
        .testTarget(name: "KairoTests", dependencies: ["Kairo"], path: "Tests/KairoTests")
    ]
)
