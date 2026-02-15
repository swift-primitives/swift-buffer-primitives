// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "rawlayout-release-verifier-crash",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-storage-primitives"),
    ],
    targets: [
        .target(
            name: "StorageModule",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
            ]
        ),
        .executableTarget(
            name: "BufferModule",
            dependencies: ["StorageModule"],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
            ]
        ),
        // V13: Uses the REAL storage-primitives to test if the actual
        // library code triggers the bug when consumed cross-module.
        .executableTarget(
            name: "RealStorageModule",
            dependencies: [
                .product(name: "Storage Inline Primitives", package: "swift-storage-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .swiftLanguageMode(.v6),
                .strictMemorySafety(),
            ]
        ),
    ]
)
