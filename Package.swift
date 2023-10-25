// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "OasisJSBridge",
    platforms: [.iOS(.v12), .tvOS(.v12)],
    products: [
        .library(name: "OasisJSBridge", targets: ["OasisJSBridge"])
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
            ],
            path: "JSBridge/Tests",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
