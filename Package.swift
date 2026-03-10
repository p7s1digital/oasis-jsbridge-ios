// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OasisJSBridge",
    platforms: [.iOS(.v12), .tvOS(.v12), .visionOS(.v1), .macOS(.v12)],
    products: [
        .library(name: "OasisJSBridge", targets: ["OasisJSBridge"])
    ],
    targets: [
        .target(
            name: "OasisJSBridge",
            path: "JSBridge/Classes",
            resources: [
                .process("Resources/PrivacyInfo.xcprivacy")
            ]
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
