// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MicroApp",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MicroApp",
            path: "Sources/MicroApp",
            exclude: ["Info.plist"]
        )
    ]
)
