// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "cross-module-type-declaration",
    platforms: [.macOS(.v26)],
    dependencies: [],
    targets: [
        .target(
            name: "Core",
            dependencies: []
        ),
        .target(
            name: "Variant",
            dependencies: ["Core"]
        ),
        .executableTarget(
            name: "cross-module-type-declaration",
            dependencies: ["Core", "Variant"],
            swiftSettings: [
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety(),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
