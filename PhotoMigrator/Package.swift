// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "PhotoMigrator",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "PhotoMigrator", targets: ["PhotoMigrator"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "PhotoMigrator",
            dependencies: [],
            path: "Sources/PhotoMigrator",
            resources: [
                .process("Resources")
            ]
        )
    ]
)