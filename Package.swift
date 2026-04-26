// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "GripeSDK",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "GripeSDK", targets: ["GripeSDK"]),
    ],
    targets: [
        .target(name: "GripeSDK", path: "Sources/GripeSDK"),
        .testTarget(name: "GripeSDKTests", dependencies: ["GripeSDK"], path: "Tests/GripeSDKTests"),
    ]
)
