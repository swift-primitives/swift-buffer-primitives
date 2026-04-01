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
        .package(path: "../swift-link-primitives"),
        .package(path: "../swift-storage-primitives"),
        .package(path: "../swift-cyclic-index-primitives"),
        .package(path: "../swift-memory-primitives"),
        .package(path: "../swift-bit-vector-primitives"),
        .package(path: "../swift-finite-primitives"),
        .package(path: "../swift-sequence-primitives"),
        .package(path: "../swift-collection-primitives"),
    ],
    targets: [

        // MARK: - Core
        .target(
            name: "Buffer Primitives Core",
            dependencies: [
                .product(name: "Link Primitives", package: "swift-link-primitives"),
                .product(name: "Storage Primitives", package: "swift-storage-primitives"),
                .product(name: "Cyclic Index Primitives", package: "swift-cyclic-index-primitives"),
                .product(name: "Memory Primitives", package: "swift-memory-primitives"),
                .product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),
            ],
            // RESOLVED: LLVM and SIL verifier crashes eliminated by moving
            // Inline types from extension-file pattern to struct-body pattern.
            // See Research/release-mode-llvm-verifier-crash-diagnosis.md
            swiftSettings: []
        ),

        // MARK: - Per-Variant Core Targets
        .target(name: "Buffer Ring Primitives Core",     dependencies: ["Buffer Primitives Core"]),
        .target(name: "Buffer Linear Primitives Core",   dependencies: ["Buffer Primitives Core"]),
        .target(name: "Buffer Slab Primitives Core",     dependencies: ["Buffer Primitives Core"]),
        .target(name: "Buffer Linked Primitives Core",   dependencies: ["Buffer Primitives Core"]),
        .target(name: "Buffer Arena Primitives Core",    dependencies: ["Buffer Primitives Core"]),
        .target(name: "Buffer Slots Primitives Core",    dependencies: ["Buffer Primitives Core"]),
        .target(name: "Buffer Aligned Primitives Core",  dependencies: ["Buffer Primitives Core"]),
        .target(
            name: "Buffer Unbounded Primitives Core",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Aligned Primitives Core",
            ]
        ),

        // MARK: - Ring
        .target(
            name: "Buffer Ring Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Ring Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        .target(
            name: "Buffer Ring Inline Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Ring Primitives Core",
                "Buffer Ring Primitives",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),

        // MARK: - Linear
        .target(
            name: "Buffer Linear Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Linear Primitives Core",
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ]
        ),
        .target(
            name: "Buffer Linear Inline Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Linear Primitives Core",
                "Buffer Linear Primitives",
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ]
        ),
        .target(
            name: "Buffer Linear Small Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Linear Primitives Core",
                "Buffer Linear Primitives",
                "Buffer Linear Inline Primitives",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ]
        ),

        // MARK: - Slab
        .target(
            name: "Buffer Slab Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Slab Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        .target(
            name: "Buffer Slab Inline Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Slab Primitives Core",
                "Buffer Slab Primitives",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),

        // MARK: - Linked
        .target(
            name: "Buffer Linked Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Linked Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        .target(
            name: "Buffer Linked Inline Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Linked Primitives Core",
                "Buffer Linked Primitives",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),

        // MARK: - Slots
        .target(
            name: "Buffer Slots Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Slots Primitives Core",
            ]
        ),

        // MARK: - Arena
        .target(
            name: "Buffer Arena Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Arena Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        .target(
            name: "Buffer Arena Inline Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Arena Primitives Core",
                "Buffer Arena Primitives",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),

        // MARK: - Umbrella
        .target(
            name: "Buffer Primitives",
            dependencies: [
                "Buffer Primitives Core",
                "Buffer Ring Primitives Core",
                "Buffer Linear Primitives Core",
                "Buffer Slab Primitives Core",
                "Buffer Linked Primitives Core",
                "Buffer Arena Primitives Core",
                "Buffer Slots Primitives Core",
                "Buffer Aligned Primitives Core",
                "Buffer Unbounded Primitives Core",
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

        // MARK: - Test Support
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

        // MARK: - Tests
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
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
    ]

    let package: [SwiftSetting] = [
        .enableExperimentalFeature("BuiltinModule"),
        .enableExperimentalFeature("RawLayout"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
