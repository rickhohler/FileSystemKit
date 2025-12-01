// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FileSystemKit",
    platforms: [
        .macOS(.v12), .iOS(.v15), .tvOS(.v15), .watchOS(.v8)
    ],
    products: [
        // Library product for use in other Swift packages or apps
        .library(
            name: "FileSystemKit",
            targets: ["FileSystemKit"]
        ),
        // Executable product for command-line tool
        .executable(
            name: "filesystemkit",
            targets: ["FileSystemKitCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.2"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    plugins: [
        .plugin(name: "Swift-DocC", package: "swift-docc-plugin")
    ],
    targets: [
        // Core library target containing file system functionality
        .target(
            name: "FileSystemKit",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
            ],
            path: "Sources/FileSystemKit",
            exclude: []
        ),
        // Command-line tool target
        .executableTarget(
            name: "FileSystemKitCLI",
            dependencies: [
                "FileSystemKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/FileSystemKitCLI"
        ),
        // Test target
        .testTarget(
            name: "FileSystemKitTests",
            dependencies: ["FileSystemKit"],
            resources: [
                .copy("Resources")
            ]
        ),
    ]
)
