// swift-tools-version: 5.10
import PackageDescription
let package = Package(
    name: "AparteModules", platforms: [.macOS(.v14)],
    products: [.library(name: "AparteCore", targets: ["AparteCore"]), .library(name: "AparteSpeech", targets: ["AparteSpeech"]), .executable(name: "aparte-check", targets: ["AparteCheck"])],
    dependencies: [.package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", revision: "1e2a163736dfa5a198e637ae44c114e1c6d5cc2d")],
    targets: [
        .target(name: "AparteCore"),
        .target(name: "AparteSpeech", dependencies: ["AparteCore", .product(name: "WhisperKit", package: "argmax-oss-swift")]),
        .executableTarget(name: "AparteCheck", dependencies: ["AparteSpeech", "AparteCore"]),
        .testTarget(name: "AparteCoreTests", dependencies: ["AparteCore"])
    ], swiftLanguageVersions: [.v5]
)
