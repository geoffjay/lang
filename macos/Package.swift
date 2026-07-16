// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "JapaneseTutor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "JapaneseTutor",
            path: "Sources/JapaneseTutor",
            swiftSettings: [
                // Keep Swift 5 concurrency semantics so the AVFoundation /
                // Speech delegate callbacks don't trip strict-concurrency errors.
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
