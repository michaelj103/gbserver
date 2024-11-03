// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "gbserver",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "GBServerPayloads", targets: ["GBServerPayloads"]),
        .library(name: "GBLinkServerProtocol", targets: ["GBLinkServerProtocol"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.13.3"),
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
                           .product(name: "Crypto", package: "swift-crypto"),
                           .product(name: "SQLite", package: "sqlite.swift"),
                           "GBServerPayloads",
                           "GBLinkServerProtocol",
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
        .executableTarget(
            name: "gbserverclient",
            dependencies: [ .product(name: "NIO", package: "swift-nio"),
                            .product(name: "NIOFoundationCompat", package: "swift-nio"),
                            .product(name: "NIOHTTP1", package: "swift-nio"),
                            .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                            .product(name: "ArgumentParser", package: "swift-argument-parser"),
                            "GBServerPayloads",
                            "GBLinkServerProtocol",
            ]
        ),
        .target(name: "GBServerPayloads"),
        .target(name: "GBLinkServerProtocol",
                dependencies: [ .product(name: "NIO", package: "swift-nio"),
                                .product(name: "NIOFoundationCompat", package: "swift-nio"),
               ]),
    ]
)
