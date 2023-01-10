// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "OasisJSBridge",
    platforms: [.iOS(.v13), .tvOS(.v13)],
    products: [
        .library(name: "OasisJSBridge", targets: ["OasisJSBridge"])
    ],
    targets: [
        .target(name: "OasisJSBridge", path: "JSBridge",
                resources: [.copy("Assets/promise.js"),
                            .copy("Assets/customStringify.js")])
    ]
)
