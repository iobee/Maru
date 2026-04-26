// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "Maru",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Maru", targets: ["Maru"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1")
    ],
    targets: [
        .executableTarget(
            name: "Maru",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/Maru",
            exclude: [
                "Utilities/demo.lua",
                "Info.plist"
            ],
            resources: [
                .process("Assets.xcassets"),
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "MaruTests",
            dependencies: ["Maru"],
            path: "Tests/MaruTests"
        )
    ]
)
