// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "PhotoMigrator",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(
            name: "PhotoMigrator",
            targets: ["PhotoMigrator"]
        ),
    ],
    dependencies: [
        // Supabase Swift client
        .package(url: "https://github.com/supabase-community/supabase-swift.git", from: "0.3.0"),
        // For HTTP requests
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.6.0"),
        // For JSON handling
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.0"),
        // For JWT handling
        .package(url: "https://github.com/auth0/JWTDecode.swift.git", from: "3.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "PhotoMigrator",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                "Alamofire",
                "SwiftyJSON",
                .product(name: "JWTDecode", package: "JWTDecode.swift"),
            ],
            path: "PhotoMigrator"
        ),
        .testTarget(
            name: "PhotoMigratorTests",
            dependencies: ["PhotoMigrator"],
            path: "Tests"
        ),
    ]
)