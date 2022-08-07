// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "gbserver",
    products: [
        .library(name: "GBServerPayloads", targets: ["GBServerPayloads"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "5.26.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "gbserver",
            dependencies: [.product(name: "NIO", package: "swift-nio"),
                           .product(name: "NIOHTTP1", package: "swift-nio"),
                           .product(name: "NIOFoundationCompat", package: "swift-nio"),
                           .product(name: "ArgumentParser", package: "swift-argument-parser"),
                           .product(name: "GRDB", package: "GRDB.swift"),
                           "GBServerPayloads",
            ]
        ),
        .testTarget(
            name: "gbserverTests",
            dependencies: ["gbserver"]),
        .executableTarget(
            name: "gbserverctl",
            dependencies: [.product(name: "NIO", package: "swift-nio"),
                           .product(name: "NIOFoundationCompat", package: "swift-nio"),
                           .product(name: "ArgumentParser", package: "swift-argument-parser"),
                           "GBServerPayloads",
            ]
        ),
        .target(name: "GBServerPayloads"),
    ]
)
