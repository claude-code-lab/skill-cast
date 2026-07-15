// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SkillCast",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SkillCast",
            path: "Sources/SkillCast"
        ),
        .testTarget(
            name: "SkillCastTests",
            dependencies: ["SkillCast"],
            path: "Tests/SkillCastTests"
        ),
    ]
)
