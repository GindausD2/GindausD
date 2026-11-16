import SwiftUI

@main
struct MaxWatchApp: App {
    @StateObject private var thoughts = ThoughtStore()

    @State private var captureRequested = false

    var body: some Scene {
        WindowGroup {
            ThoughtsView(store: thoughts, scope: "device", captureRequested: $captureRequested)
                .onOpenURL { url in
                    if url.scheme == "max-watch", url.host == "capture", url.path.isEmpty {
                        captureRequested = true
                    }
                }
                .tint(Color(red: 0.23, green: 0.52, blue: 0.68))
        }
    }
}
