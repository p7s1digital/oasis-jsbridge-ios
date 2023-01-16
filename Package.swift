// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "OasisJSBridge",
    platforms: [.iOS(.v13), .tvOS(.v13)],
    products: [
        .library(name: "OasisJSBridge", targets: ["OasisJSBridge"])
    ],
    dependencies: [
        .package(url: "https://github.com/AliSoftware/OHHTTPStubs.git", from: "9.1.0"),
    ],
    targets: [
        .target(
            name: "OasisJSBridge",
            path: "JSBridge/Classes"
        ),
        .testTarget(
            name: "OasisJSBridgeTests",
            dependencies: [
                "OasisJSBridge",
                .product(name: "OHHTTPStubsSwift", package: "OHHTTPStubs"),
            ],
            path: "JSBridge/Tests",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
