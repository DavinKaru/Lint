// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LintCore",
    // macOS is only listed so the tests can run with `swift test` on a Mac, no simulator needed.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LintCore", targets: ["LintCore"]),
    ],
    targets: [
        .target(name: "LintCore"),
        .testTarget(name: "LintCoreTests", dependencies: ["LintCore"]),
    ]
)
