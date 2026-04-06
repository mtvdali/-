// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NewMacImageSearchApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "NewMacImageSearchApp",
            targets: ["NewMacImageSearchApp"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .executableTarget(
            name: "NewMacImageSearchApp",
            dependencies: []
        ),
        .testTarget(
            name: "NewMacImageSearchAppTests",
            dependencies: ["NewMacImageSearchApp"]
        ),
    ]
)
