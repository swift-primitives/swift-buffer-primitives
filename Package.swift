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
            name: "Buffer Ring Inline Primitives",
            targets: ["Buffer Ring Inline Primitives"]
        ),
        .library(
            name: "Buffer Linear Primitives",
            targets: ["Buffer Linear Primitives"]
        ),
        .library(
            name: "Buffer Linear Inline Primitives",
            targets: ["Buffer Linear Inline Primitives"]
        ),
        .library(
            name: "Buffer Linear Small Primitives",
            targets: ["Buffer Linear Small Primitives"]
        ),
        .library(
            name: "Buffer Slab Primitives",
            targets: ["Buffer Slab Primitives"]
        ),
        .library(
            name: "Buffer Slab Inline Primitives",
            targets: ["Buffer Slab Inline Primitives"]
        ),
        .library(
            name: "Buffer Linked Primitives",
            targets: ["Buffer Linked Primitives"]
        ),
        .library(
            name: "Buffer Linked Inline Primitives",
            targets: ["Buffer Linked Inline Primitives"]
        ),
        .library(
            name: "Buffer Slots Primitives",
            targets: ["Buffer Slots Primitives"]
        ),
        .library(
            name: "Buffer Arena Primitives",
            targets: ["Buffer Arena Primitives"]
        ),
        .library(
            name: "Buffer Arena Inline Primitives",
            targets: ["Buffer Arena Inline Primitives"]
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
        .package(path: "../swift-collection-primitives"),
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
        // Ring: Circular buffer heap and bounded variants
        .target(
            name: "Buffer Ring Primitives",
            dependencies: [
                "Buffer Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        // Ring Inline: Inline and small circular buffer variants
        .target(
            name: "Buffer Ring Inline Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Ring Primitives",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        // Linear: Contiguous buffer heap and bounded variants
        .target(
            name: "Buffer Linear Primitives",
            dependencies: [
                "Buffer Primitives Core",
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ]
        ),
        // Linear Inline: Fixed-capacity inline contiguous buffer variants
        .target(
            name: "Buffer Linear Inline Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Linear Primitives",
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ]
        ),
        // Linear Small: Small-buffer optimization (inline + heap spill)
        .target(
            name: "Buffer Linear Small Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Linear Primitives",
                "Buffer Linear Inline Primitives",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ]
        ),
        // Slab: Index-addressable slot storage heap and bounded variants
        .target(
            name: "Buffer Slab Primitives",
            dependencies: [
                "Buffer Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        // Slab Inline: Inline and small slab buffer variants
        .target(
            name: "Buffer Slab Inline Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Slab Primitives",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        // Linked: Doubly-linked list heap variant
        .target(
            name: "Buffer Linked Primitives",
            dependencies: [
                "Buffer Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        // Linked Inline: Inline and small linked list variants
        .target(
            name: "Buffer Linked Inline Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Linked Primitives",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        // Slots: Metadata-parametric random-access slots
        .target(
            name: "Buffer Slots Primitives",
            dependencies: [
                "Buffer Primitives Core",
            ]
        ),
        // Arena: Generation-token arena heap and bounded variants
        .target(
            name: "Buffer Arena Primitives",
            dependencies: [
                "Buffer Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        // Arena Inline: Inline and small arena variants
        .target(
            name: "Buffer Arena Inline Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Arena Primitives",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        // Umbrella: Re-exports all buffer primitive modules
        .target(
            name: "Buffer Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Ring Primitives",
                "Buffer Ring Inline Primitives",
                "Buffer Linear Primitives",
                "Buffer Linear Inline Primitives",
                "Buffer Linear Small Primitives",
                "Buffer Slab Primitives",
                "Buffer Slab Inline Primitives",
                "Buffer Linked Primitives",
                "Buffer Linked Inline Primitives",
                "Buffer Slots Primitives",
                "Buffer Arena Primitives",
                "Buffer Arena Inline Primitives",
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
        // Per-module test targets
        .testTarget(
            name: "Buffer Ring Primitives Tests",
            dependencies: [
                .target(name: "Buffer Ring Primitives"),
                .target(name: "Buffer Primitives Test Support"),
            ]
        ),
        .testTarget(
            name: "Buffer Ring Inline Primitives Tests",
            dependencies: [
                .target(name: "Buffer Ring Inline Primitives"),
                .target(name: "Buffer Primitives Test Support"),
            ]
        ),
        .testTarget(
            name: "Buffer Linear Primitives Tests",
            dependencies: [
                .target(name: "Buffer Linear Primitives"),
                .target(name: "Buffer Primitives Test Support"),
            ]
        ),
        .testTarget(
            name: "Buffer Linear Inline Primitives Tests",
            dependencies: [
                .target(name: "Buffer Linear Inline Primitives"),
                .target(name: "Buffer Primitives Test Support"),
            ]
        ),
        .testTarget(
            name: "Buffer Linear Small Primitives Tests",
            dependencies: [
                .target(name: "Buffer Linear Small Primitives"),
                .target(name: "Buffer Primitives Test Support"),
            ]
        ),
        .testTarget(
            name: "Buffer Slab Primitives Tests",
            dependencies: [
                .target(name: "Buffer Slab Primitives"),
                .target(name: "Buffer Primitives Test Support"),
            ]
        ),
        .testTarget(
            name: "Buffer Slab Inline Primitives Tests",
            dependencies: [
                .target(name: "Buffer Slab Inline Primitives"),
                .target(name: "Buffer Primitives Test Support"),
            ]
        ),
        .testTarget(
            name: "Buffer Linked Primitives Tests",
            dependencies: [
                .target(name: "Buffer Linked Primitives"),
                .target(name: "Buffer Primitives Test Support"),
            ]
        ),
        .testTarget(
            name: "Buffer Linked Inline Primitives Tests",
            dependencies: [
                .target(name: "Buffer Linked Inline Primitives"),
                .target(name: "Buffer Primitives Test Support"),
            ]
        ),
        .testTarget(
            name: "Buffer Slots Primitives Tests",
            dependencies: [
                .target(name: "Buffer Slots Primitives"),
                .target(name: "Buffer Primitives Test Support"),
            ]
        ),
        .testTarget(
            name: "Buffer Arena Primitives Tests",
            dependencies: [
                .target(name: "Buffer Arena Primitives"),
                .target(name: "Buffer Primitives Test Support"),
            ]
        ),
        .testTarget(
            name: "Buffer Arena Inline Primitives Tests",
            dependencies: [
                .target(name: "Buffer Arena Inline Primitives"),
                .target(name: "Buffer Primitives Test Support"),
            ]
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
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
    ]

    let package: [SwiftSetting] = [
        .enableExperimentalFeature("BuiltinModule"),
        .enableExperimentalFeature("RawLayout"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
