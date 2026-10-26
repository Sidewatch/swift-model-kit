// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ModelKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GLTFReader", targets: ["GLTFReader"]),
        .library(name: "ModelPreview", targets: ["ModelPreview"]),
    ],
    targets: [
        .target(name: "GLTFReader", path: "Sources/GLTFReader", swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(
            name: "ModelPreview", dependencies: ["GLTFReader"], path: "Sources/ModelPreview", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "GLTFReaderTests", dependencies: ["GLTFReader"], path: "Tests/GLTFReaderTests"),
        .testTarget(name: "ModelPreviewTests", dependencies: ["ModelPreview", "GLTFReader"], path: "Tests/ModelPreviewTests"),
    ]
)
