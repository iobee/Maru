// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "HiWindowGuy",
    platforms: [
        .macOS(.v11)
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
            path: ".",
            exclude: [
                "demo.lua",
                "README.md",
                "Info.plist"
            ],
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
) 