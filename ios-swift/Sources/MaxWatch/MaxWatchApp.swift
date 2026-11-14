import SwiftUI

@main
struct MaxWatchApp: App {
    @StateObject private var thoughts = ThoughtStore()

    var body: some Scene {
        WindowGroup {
            ThoughtsView(store: thoughts, scope: "device")
                .tint(Color(red: 0.23, green: 0.52, blue: 0.68))
        }
    }
}
