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
        .package(path: "../swift-deque-primitives"),
        .package(path: "../swift-handle-primitives"),
        .package(path: "../swift-reference-primitives"),
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-input-primitives"),
        .package(path: "../swift-bit-primitives"),
        .package(path: "../swift-collection-primitives"),
    ],
    targets: [
        .target(
            name: "Buffer Primitives",
            dependencies: [
                .product(name: "Binary Primitives", package: "swift-binary-primitives"),
                .product(name: "Deque Primitives", package: "swift-deque-primitives"),
                .product(name: "Handle Primitives", package: "swift-handle-primitives"),
                .product(name: "Reference Primitives", package: "swift-reference-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Input Primitives", package: "swift-input-primitives"),
                .product(name: "Bit Primitives", package: "swift-bit-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety(),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
