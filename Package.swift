// swift-tools-version:5.3
import PackageDescription

let package = Package(
  name: "Beethoven",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(name: "Beethoven", targets: ["Beethoven"]),
    ],
  dependencies: [
    .package(url: "https://github.com/Megatron1000/Pitchy",.upToNextMajor(from: Version(stringLiteral: "3")))
  ],
    targets: [
        .target(name: "Beethoven", dependencies: [], path: "Source"),
        .testTarget(name: "Beethoven-iOS-Tests", dependencies: [], path: "Tests"),
    ]
)
