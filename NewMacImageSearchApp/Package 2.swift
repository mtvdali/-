// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "NewMacImageSearchApp",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(
            name: "NewMacImageSearchApp",
            targets: ["NewMacImageSearchApp"]),
    ],
    targets: [
        .executableTarget(
            name: "NewMacImageSearchApp",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("Resources")
            ])
    ]
)
