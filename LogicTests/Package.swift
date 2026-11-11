// swift-tools-version:5.10
import PackageDescription

// Sources are symlinks into ../Shared and ../ITProjectTests so this package
// can run on Linux. Xcode builds the same files from the app project.
let package = Package(
    name: "LogicTests",
    targets: [
        .target(name: "ITLogic"),
        .testTarget(name: "ITLogicTests", dependencies: ["ITLogic"])
    ]
)
