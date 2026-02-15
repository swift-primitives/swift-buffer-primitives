// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "copy-propagation-noncopyable-enum",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "StorageLib"),
        .executableTarget(
            name: "copy-propagation-noncopyable-enum",
            dependencies: ["StorageLib"]
        )
    ],
    swiftLanguageModes: [.v6]
)
