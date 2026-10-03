// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PictureGo",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "PictureGo", targets: ["PictureGo"])
    ],
    targets: [
        .executableTarget(
            name: "PictureGo",
            path: "Sources/PictureGo"
        )
    ]
)
