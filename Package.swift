// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "HiWindowGuy",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "HiWindowGuy", targets: ["HiWindowGuy"])
    ],
    dependencies: [
    ],
    targets: [
        .executableTarget(
            name: "HiWindowGuy",
            dependencies: [],
            path: "Sources",
            exclude: [
                "HiWindowGuy/Utilities/demo.lua",
                "HiWindowGuy/Info.plist"
            ],
            resources: [
                .process("HiWindowGuy/Assets.xcassets")
            ]
        )
    ]
) 