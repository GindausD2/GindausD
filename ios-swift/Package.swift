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
        ),
        // The MaxLiveActivity widget extension is built as a library here
        // for source organization. The actual app extension target must be
        // created in Xcode (File → New → Target → Widget Extension) and
        // linked against the sources in Sources/MaxLiveActivity/.
        .library(
            name: "MaxLiveActivity",
            targets: ["MaxLiveActivity"]
        ),
        // The MaxWidget home-screen / lock-screen widget extension.
        // Xcode setup: File → New → Target → Widget Extension → "MaxWidget"
        //   1. Point source folder at Sources/MaxWidget/
        //   2. Add App Group "group.com.gindausd.max" to main app + this target
        //   3. Add URL scheme "maxapp" to main app target → Info → URL Types
        .library(
            name: "MaxWidget",
            targets: ["MaxWidget"]
        )
    ],
    dependencies: [],
    targets: [
        // ── Main app ─────────────────────────────────────────────────────────
        .executableTarget(
            name: "Max",
            dependencies: [],
            path: "Sources/Max",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppIntents"),
                .linkedFramework("WidgetKit")
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableUpcomingFeature("ImplicitOpenExistentials"),
                .enableUpcomingFeature("ForwardTrailingClosures")
            ]
        ),

        // ── Dynamic Island / Live Activity widget extension ───────────────────
        // Sources: Sources/MaxLiveActivity/MaxLiveActivityWidget.swift
        //
        // Xcode setup:
        //   1. Add a Widget Extension target named "MaxLiveActivity"
        //   2. Point it at Sources/MaxLiveActivity/
        //   3. Add MaxActivityAttributes.swift (from Sources/Max/LiveActivity/)
        //      to the widget extension's target membership
        //   4. In main app Info.plist: NSSupportsLiveActivities = YES
        //   5. Enable "Push Notifications" capability on the main app target
        .target(
            name: "MaxLiveActivity",
            dependencies: [],
            path: "Sources/MaxLiveActivity",
            linkerSettings: [
                .linkedFramework("WidgetKit"),
                .linkedFramework("ActivityKit"),
                .linkedFramework("SwiftUI")
            ]
        ),

        // ── Home screen / lock screen widget extension ───────────────────────
        .target(
            name: "MaxWidget",
            dependencies: [],
            path: "Sources/MaxWidget",
            linkerSettings: [
                .linkedFramework("WidgetKit"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
