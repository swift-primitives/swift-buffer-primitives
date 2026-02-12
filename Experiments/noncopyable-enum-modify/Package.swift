// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "noncopyable-enum-modify",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "noncopyable-enum-modify",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety(),
            ]
        )
    ]
)
