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
        .library(
            name: "Buffer Primitives Core",
            targets: ["Buffer Primitives Core"]
        ),
        .library(
            name: "Buffer Ring Primitives",
            targets: ["Buffer Ring Primitives"]
        ),
        .library(
            name: "Buffer Linear Primitives",
            targets: ["Buffer Linear Primitives"]
        ),
        .library(
            name: "Buffer Slab Primitives",
            targets: ["Buffer Slab Primitives"]
        ),
        .library(
            name: "Buffer Slots Primitives",
            targets: ["Buffer Slots Primitives"]
        ),
        .library(
            name: "Buffer Primitives Test Support",
            targets: ["Buffer Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-storage-primitives"),
        .package(path: "../swift-cyclic-index-primitives"),
        .package(path: "../swift-memory-primitives"),
        .package(path: "../swift-bit-vector-primitives"),
        .package(path: "../swift-finite-primitives"),
        .package(path: "../swift-sequence-primitives"),
    ],
    targets: [
        // Core: Namespace enums, header types, growth policy
        .target(
            name: "Buffer Primitives Core",
            dependencies: [
                .product(name: "Storage Primitives", package: "swift-storage-primitives"),
                .product(name: "Cyclic Index Primitives", package: "swift-cyclic-index-primitives"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),
            ]
        ),
        // Ring: Circular buffer static ops and composed types
        .target(
            name: "Buffer Ring Primitives",
            dependencies: [
                "Buffer Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        // Linear: Contiguous buffer static ops and composed types
        .target(
            name: "Buffer Linear Primitives",
            dependencies: [
                "Buffer Primitives Core",
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        // Slab: Index-addressable slot storage static ops and composed types
        .target(
            name: "Buffer Slab Primitives",
            dependencies: [
                "Buffer Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        // Slots: Metadata-parametric random-access slots static ops and composed types
        .target(
            name: "Buffer Slots Primitives",
            dependencies: [
                "Buffer Primitives Core",
            ]
        ),
        // Umbrella: Re-exports Core, Ring, Linear, Slab, Slots
        .target(
            name: "Buffer Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Ring Primitives",
                "Buffer Linear Primitives",
                "Buffer Slab Primitives",
                "Buffer Slots Primitives",
            ]
        ),
        .target(
            name: "Buffer Primitives Test Support",
            dependencies: [
                "Buffer Primitives",
                .product(name: "Storage Primitives Test Support", package: "swift-storage-primitives"),
                .product(name: "Cyclic Index Primitives Test Support", package: "swift-cyclic-index-primitives"),
                .product(name: "Bit Vector Primitives Test Support", package: "swift-bit-vector-primitives"),
                .product(name: "Memory Primitives Test Support", package: "swift-memory-primitives"),
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: "Buffer Primitives Tests",
            dependencies: [
                .target(name: "Buffer Primitives"),
                .target(name: "Buffer Primitives Test Support"),
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
