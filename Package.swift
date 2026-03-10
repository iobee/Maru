// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "HiWindowGuy",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "HiWindowGuy", targets: ["HiWindowGuy"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.8.1")
    ],
    targets: [
        .executableTarget(
            name: "HiWindowGuy",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
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
