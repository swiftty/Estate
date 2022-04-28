// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Estate",
    platforms: [
        .macOS(.v12), .iOS(.v15)
    ],
    products: [
        .library(
            name: "Estate",
            targets: ["Estate"]),
        .library(
            name: "EstateSwiftUI",
            targets: ["EstateSwiftUI"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Estate",
            dependencies: []),
        .target(
            name: "EstateSwiftUI",
            dependencies: ["Estate"]),
        .testTarget(
            name: "EstateTests",
            dependencies: ["Estate"])
    ]
)
