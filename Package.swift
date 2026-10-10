// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "BudNote", platforms: [.macOS(.v12)],
    products: [.executable(name: "BudNote", targets: ["BudNote"])],
    targets: [.target(name: "BudCore"), .executableTarget(name: "BudNote", dependencies: ["BudCore"]),
              .testTarget(name: "BudCoreTests", dependencies: ["BudCore"])])
