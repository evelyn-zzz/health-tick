// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HealthTick",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "HealthTick",
            path: "Sources",
            exclude: ["Info.plist"],
            resources: [
                .copy("Resources"),
            ]
        ),
    ]
)
