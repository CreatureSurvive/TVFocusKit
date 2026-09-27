// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TVFocusKit",
    platforms: [
        .tvOS(.v17),
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "TVFocusKit", targets: ["TVFocusKit"]),
    ],
    targets: [
        .target(
            name: "TVFocusKit",
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]
        ),
        .testTarget(
            name: "TVFocusKitTests",
            dependencies: ["TVFocusKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
