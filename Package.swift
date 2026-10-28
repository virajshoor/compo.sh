// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "compo",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "compo", targets: ["Compo"])],
    targets: [
        .target(name: "CompoCore"),
        .executableTarget(name: "Compo", dependencies: ["CompoCore"]),
        .testTarget(name: "CompoCoreTests", dependencies: ["CompoCore"])
    ]
)
