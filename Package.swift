// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SpaceSnap",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "SpaceSnap", targets: ["SpaceSnap"]),
    ],
    targets: [
        .target(
            name: "SpaceSnapCore",
            linkerSettings: [
                .unsafeFlags(["-F", "/System/Library/PrivateFrameworks"]),
                .linkedFramework("SkyLight"),
                .linkedFramework("Carbon"),
            ]
        ),
        .executableTarget(
            name: "SpaceSnap",
            dependencies: ["SpaceSnapCore"]
        ),
        .testTarget(
            name: "SpaceSnapCoreTests",
            dependencies: ["SpaceSnapCore"]
        ),
    ]
)
