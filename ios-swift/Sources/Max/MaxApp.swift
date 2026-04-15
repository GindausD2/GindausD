import SwiftUI
import UserNotifications

@main
struct MaxApp: App {
    @StateObject private var authService = AuthService.shared

    /// Stored in UserDefaults so SettingsView can mutate it with @AppStorage
    /// and MaxApp reacts immediately — no manual save/load needed.
    @AppStorage("max.appearance") private var appearance: String = "system"

    init() {
        configureAppearance()
        requestNotificationPermission()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .preferredColorScheme(resolvedScheme)
        }
    }

    // MARK: - Helpers

    private var resolvedScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil   // follows system
        }
    }

    private func configureAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance  = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}

// MARK: - Root View (Auth Gate)

struct RootView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        Group {
            if authService.currentUser != nil {
                HomeView()
                    .environmentObject(authService)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: 0.35)),
                        removal:   .opacity.animation(.easeOut(duration: 0.25))
                    ))
            } else {
                WelcomeView()
                    .environmentObject(authService)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: 0.35)),
                        removal:   .opacity.animation(.easeOut(duration: 0.25))
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.currentUser != nil)
    }
}
