// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "slab-deinit-workaround",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-bit-vector-primitives"),
        .package(path: "../../../swift-storage-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "slab-deinit-workaround",
            dependencies: [
                .product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),
                .product(name: "Storage Primitives", package: "swift-storage-primitives"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety(),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
