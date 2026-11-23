// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "loupe",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "loupe", targets: ["loupe"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(name: "LoupeCore"),
        .executableTarget(
            name: "loupe",
            dependencies: [
                "LoupeCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "LoupeCoreTests", dependencies: ["LoupeCore"]),
    ]
)
