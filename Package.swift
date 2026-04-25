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
    ],
    targets: [
        .executableTarget(
            name: "Maru",
            dependencies: [],
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
