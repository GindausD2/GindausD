// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Max",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(
            name: "Max",
            targets: ["Max"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Max",
            dependencies: [],
            path: "Sources/Max",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ImplicitOpenExistentials"),
                .enableUpcomingFeature("ForwardTrailingClosures")
            ]
        )
    ]
)
