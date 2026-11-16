import SwiftUI

@main
struct MaxMacApp: App {
    @StateObject private var thoughts = ThoughtStore()

    var body: some Scene {
        WindowGroup("Max") {
            ThoughtsView(store: thoughts, scope: "device")
                .tint(Color(red: 0.23, green: 0.52, blue: 0.68))
                .frame(minWidth: 340, minHeight: 410)
        }
    }
}
