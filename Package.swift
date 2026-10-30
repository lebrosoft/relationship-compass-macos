// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Peoplebook",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "PeoplebookKit"),
        .testTarget(
            name: "PeoplebookKitTests",
            dependencies: ["PeoplebookKit"]
        ),
    ]
)
