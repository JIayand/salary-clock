// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SalaryClock",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "SalaryClock", targets: ["SalaryClock"])],
    targets: [
        .executableTarget(name: "SalaryClock")
    ]
)
