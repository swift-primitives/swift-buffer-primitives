// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "initialization-consistency",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-storage-primitives"),
        .package(path: "../../../swift-cyclic-index-primitives"),
        .package(path: "../../../swift-bit-vector-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "initialization-consistency",
            dependencies: [
                .product(name: "Storage Primitives", package: "swift-storage-primitives"),
                .product(name: "Cyclic Index Primitives", package: "swift-cyclic-index-primitives"),
                .product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety(),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
