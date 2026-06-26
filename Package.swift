// swift-tools-version: 6.3.1

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
        // MARK: - Substrate (per [MOD-031]) — the buffer-discipline substrate.
        // Every specialized discipline (Linear, Ring, Slab, Linked, Slots, Arena,
        // Unbounded, Aligned) is its own sibling package.
        .library(name: "Buffer Primitive", targets: ["Buffer Primitive"]),
        // Consumer-facing capability protocol (per [MOD-031]; sub-namespace target —
        // references Index<Element>.Count so it cannot live in the zero-dep Buffer Primitive root).
        .library(name: "Buffer Protocol Primitives", targets: ["Buffer Protocol Primitives"]),

        // MARK: - Umbrella
        .library(name: "Buffer Primitives", targets: ["Buffer Primitives"]),

        // MARK: - Test Support
        .library(name: "Buffer Primitives Test Support", targets: ["Buffer Primitives Test Support"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        // W4 audit #2: the seam-ledger LAWS (test support) span Store.Protocol × Buffer.Protocol.
        .package(url: "https://github.com/swift-primitives/swift-storage-primitives.git", branch: "main"),
        // W2 mesh: resolve memory against the W2 worktree so every path to memory in
        // the buffer cohort unifies on identity `swift-memory-primitives` (no
        // url-form memory in the graph → no "multiple similar targets" collision).
        // Buffer.Protocol is count-based and vends NO span conformance, so no source
        // reconform is needed here — this is the dependency-mesh repoint only.
        .package(url: "https://github.com/swift-primitives/swift-memory-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-carrier-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-cardinal-primitives.git", branch: "main"),
    ],
    targets: [

        // MARK: - Namespace (per [MOD-017])
        .target(
            name: "Buffer Primitive",
            dependencies: []
        ),

        // MARK: - Growth (capacity-growth vocabulary)

        // MARK: - Protocol (consumer-facing capability surface, per [API-IMPL-009] hoisted protocol)
        .target(
            name: "Buffer Protocol Primitives",
            dependencies: [
                "Buffer Primitive",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Carrier Protocol", package: "swift-carrier-primitives"),
                .product(name: "Cardinal Primitive", package: "swift-cardinal-primitives"),
            ]
        ),

        // MARK: - Umbrella
        .target(
            name: "Buffer Primitives",
            dependencies: [
                "Buffer Primitive",
                "Buffer Protocol Primitives",
            ]
        ),

        // MARK: - Test Support
        .target(
            name: "Buffer Primitives Test Support",
            dependencies: [
                "Buffer Primitives",
                .product(name: "Store Protocol Primitives", package: "swift-storage-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Memory Primitives Test Support", package: "swift-memory-primitives"),
            ],
            path: "Tests/Support"
        ),

        // MARK: - Tests
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
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = [
        .enableExperimentalFeature("BuiltinModule"),
        .enableExperimentalFeature("RawLayout"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
