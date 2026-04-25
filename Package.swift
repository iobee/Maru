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
                .process("HiWindowGuy/Assets.xcassets"),
                .copy("HiWindowGuy/Resources")
            ]
        ),
        .testTarget(
            name: "HiWindowGuyTests",
            dependencies: ["HiWindowGuy"],
            path: "Tests"
        )
    ]
)
