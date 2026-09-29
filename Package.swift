// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Buckit",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Buckit",
            path: "Sources/Buckit"
        )
    ]
)
