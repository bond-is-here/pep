// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RepCometCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "RepCometCore", targets: ["RepCometCore"])],
    targets: [
        .target(name: "RepCometCore", path: "RepComet/Core"),
        .testTarget(name: "RepCometCoreTests", dependencies: ["RepCometCore"], path: "Tests/RepCometCoreTests")
    ]
)
