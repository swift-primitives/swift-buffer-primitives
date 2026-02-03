// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "composed-vs-static-benchmark",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-storage-primitives"),
        .package(path: "../../../swift-cyclic-index-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "composed-vs-static-benchmark",
            dependencies: [
                .product(name: "Storage Primitives", package: "swift-storage-primitives"),
                .product(name: "Cyclic Index Primitives", package: "swift-cyclic-index-primitives"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportsByDefault"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety(),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
