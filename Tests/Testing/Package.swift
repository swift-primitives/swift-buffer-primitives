// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "testing",
    platforms: [
        .macOS(.v26),
    ],
    dependencies: [
        .package(path: "../.."),
        .package(path: "../../../../swift-foundations/swift-testing"),
    ],
    targets: [
        .testTarget(
            name: "Buffer Linear Performance Tests",
            dependencies: [
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "Buffer Linear Inline Performance Tests",
            dependencies: [
                .product(name: "Buffer Linear Inline Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "Buffer Linear Small Performance Tests",
            dependencies: [
                .product(name: "Buffer Linear Small Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "Buffer Ring Performance Tests",
            dependencies: [
                .product(name: "Buffer Ring Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "Buffer Ring Inline Performance Tests",
            dependencies: [
                .product(name: "Buffer Ring Inline Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "Buffer Ring Small Performance Tests",
            dependencies: [
                .product(name: "Buffer Ring Inline Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "Buffer Slab Performance Tests",
            dependencies: [
                .product(name: "Buffer Slab Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "Buffer Slab Inline Performance Tests",
            dependencies: [
                .product(name: "Buffer Slab Inline Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "Buffer Arena Performance Tests",
            dependencies: [
                .product(name: "Buffer Arena Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "Buffer Arena Inline Performance Tests",
            dependencies: [
                .product(name: "Buffer Arena Inline Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "Buffer Linked Performance Tests",
            dependencies: [
                .product(name: "Buffer Linked Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "Buffer Linked Inline Performance Tests",
            dependencies: [
                .product(name: "Buffer Linked Inline Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "Buffer Slots Performance Tests",
            dependencies: [
                .product(name: "Buffer Slots Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
                .product(name: "Testing", package: "swift-testing"),
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
        .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
