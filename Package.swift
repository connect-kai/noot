// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Noot",
    platforms: [.macOS(.v13)],
    targets: [.executableTarget(name: "Noot", path: "Sources")]
)
