// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Machlif",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "MachlifCore",
            path: "Sources/MachlifCore"
        ),
        .executableTarget(
            name: "Machlif",
            dependencies: ["MachlifCore"],
            path: "Sources/Machlif"
        ),
        .testTarget(
            name: "MachlifCoreTests",
            dependencies: ["MachlifCore"],
            path: "Tests/MachlifTests"
        )
    ]
)
