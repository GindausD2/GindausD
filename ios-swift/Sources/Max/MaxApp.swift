import SwiftUI
import UserNotifications

@main
struct MaxApp: App {
    @StateObject private var authService = AuthService.shared

    init() {
        configureAppearance()
        requestNotificationPermission()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
        }
    }

    // MARK: - Setup

    private func configureAppearance() {
        // Navigation bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor.systemBackground
        navAppearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[MaxApp] Notification permission error: \(error.localizedDescription)")
            }
        }
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
                        removal: .opacity.animation(.easeOut(duration: 0.25))
                    ))
            } else {
                WelcomeView()
                    .environmentObject(authService)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: 0.35)),
                        removal: .opacity.animation(.easeOut(duration: 0.25))
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.currentUser != nil)
    }
}
