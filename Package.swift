// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-buffer-primitives",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(
            name: "Buffer Primitives",
            targets: ["Buffer Primitives"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-binary-primitives"),
        .package(path: "../swift-container-primitives"),
        .package(path: "../swift-test-support-primitives"),
    ],
    targets: [
        .target(
            name: "Buffer Primitives",
            dependencies: [
                .product(name: "Binary Primitives", package: "swift-binary-primitives"),
                .product(name: "Container Primitives", package: "swift-container-primitives"),
            ]
        ),
        .testTarget(
            name: "Buffer Primitives Tests",
            dependencies: [
                "Buffer Primitives",
                .product(name: "Test Support Primitives", package: "swift-test-support-primitives"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
