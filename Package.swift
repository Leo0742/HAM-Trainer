// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HAMTrainer",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "HAMTrainer", targets: ["HAMTrainer"])],
    targets: [
        .executableTarget(
            name: "HAMTrainer",
            path: ".",
            exclude: [
                ".github",
                ".gitignore",
                "Build",
                "ContentAuthored",
                "ContentOverrides",
                "ContentRaw",
                "ExamSources",
                "HAMTrainer.xcodeproj",
                "HAMTrainer/Info.plist",
                "README.md",
                "Tests",
                "Tools",
                "docs"
            ],
            sources: ["HAMTrainer"],
            resources: [.copy("Content")]
        )
    ]
)
