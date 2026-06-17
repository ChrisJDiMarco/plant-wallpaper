// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WallpaperGarden",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PlantGardenCore",
            targets: ["PlantGardenCore"]
        ),
        .executable(
            name: "PlantWallpaper",
            targets: ["PlantWallpaper"]
        )
    ],
    targets: [
        .target(name: "PlantGardenCore"),
        .executableTarget(
            name: "PlantWallpaper",
            dependencies: ["PlantGardenCore"],
            resources: [
                .process("Resources"),
                .copy("WebAssets")
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("UserNotifications")
            ]
        ),
        .testTarget(
            name: "PlantGardenCoreTests",
            dependencies: ["PlantGardenCore"]
        ),
        .testTarget(
            name: "PlantWallpaperTests",
            dependencies: ["PlantWallpaper"]
        )
    ]
)
