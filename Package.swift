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
        )
    ]
)
