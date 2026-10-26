// swift-tools-version: 6.0
import PackageDescription

// MissionCore and MissionContent are Foundation-only and build and test on Linux.
// MissionUI needs SwiftUI, so it only exists in the manifest on Apple platforms.

var products: [Product] = [
    .library(name: "MissionCore", targets: ["MissionCore"]),
    .library(name: "MissionContent", targets: ["MissionContent"]),
]

var targets: [Target] = [
    .target(name: "MissionCore"),
    .target(
        name: "MissionContent",
        dependencies: ["MissionCore"],
        resources: [.copy("Content")]
    ),
    .testTarget(name: "MissionCoreTests", dependencies: ["MissionCore"]),
    .testTarget(
        name: "MissionContentTests",
        dependencies: ["MissionCore", "MissionContent"]
    ),
]

#if canImport(SwiftUI)
    products.append(.library(name: "MissionUI", targets: ["MissionUI"]))
    targets.append(.target(name: "MissionUI", dependencies: ["MissionCore"]))
#endif

let package = Package(
    name: "MissionKit",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: products,
    targets: targets
)
