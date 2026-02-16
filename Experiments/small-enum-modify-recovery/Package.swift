// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "small-enum-modify-recovery",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "small-enum-modify-recovery",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety(),
            ]
        )
    ]
)
