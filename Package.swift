// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "SVGConverter",
    products: [
        .executable(name: "SVGConverter", targets: ["SVGConverter"]),
        .library(name: "SVGConverterCore", targets: ["SVGConverterCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        .executableTarget(
            name: "SVGConverter",
            dependencies: [
                "SVGConverterCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(
            name: "SVGConverterCore",
            dependencies: []
        ),
        .testTarget(
            name: "SVGConverterCoreTests",
            dependencies: [
                "SVGConverterCore",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            exclude: ["__Snapshots__"],
            resources: [.copy("input_files")]
        )
    ]
)
