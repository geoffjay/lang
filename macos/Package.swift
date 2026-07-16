// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "JapaneseTutor",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "JapaneseTutor",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
            ],
            path: "Sources/JapaneseTutor",
            swiftSettings: [
                // Keep Swift 5 concurrency semantics so the AVFoundation
                // delegate callbacks don't trip strict-concurrency errors.
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
