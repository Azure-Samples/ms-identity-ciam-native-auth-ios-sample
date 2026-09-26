// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NativeAuthSampleSupport",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "NativeAuthSampleSupport", targets: ["NativeAuthSampleSupport"])
    ],
    targets: [
        .target(
            name: "NativeAuthSampleSupport",
            path: "NativeAuthSampleApp",
            exclude: [
                "App",
                "Assets.xcassets",
                "Configuration.swift",
                "Info.plist",
                "NativeAuthSampleApp-macOS.entitlements",
                "NativeAuthSampleApp.entitlements",
                "SignIn"
            ],
            sources: ["ProtectedAPIClient.swift"]
        ),
        .testTarget(
            name: "NativeAuthSampleSupportTests",
            dependencies: ["NativeAuthSampleSupport"],
            path: "NativeAuthSampleAppTests"
        )
    ]
)
