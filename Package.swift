// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HAMTrainer",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "HAMTrainer", targets: ["HAMTrainer"])],
    targets: [
        .executableTarget(
            name: "HAMTrainer",
            path: "HAMTrainer",
            exclude: ["Info.plist"],
            resources: [.copy("../Content")]
        )
    ]
)
