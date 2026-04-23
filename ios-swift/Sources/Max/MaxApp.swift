import BackgroundTasks
import SwiftUI
import UserNotifications

// ── Required Info.plist keys (add these in Xcode → target → Info) ─────────────
//
//  NSSupportsLiveActivities              → YES
//  NSSupportsLiveActivitiesFrequentUpdates → YES
//
//  BGTaskSchedulerPermittedIdentifiers   → Array
//      Item 0 → com.max.ai.liveactivity.refresh
//
//  UIBackgroundModes                     → Array
//      Item 0 → fetch
//      Item 1 → processing
//
// ─────────────────────────────────────────────────────────────────────────────

private let kLiveActivityRefreshID = "com.max.ai.liveactivity.refresh"
private let kRefreshInterval: TimeInterval = 4 * 3600 // 4 hours

@main
struct MaxApp: App {
    @StateObject private var authService = AuthService.shared
    @AppStorage("max.appearance") private var appearance: String = "system"
    @Environment(\.scenePhase) private var scenePhase

    init() {
        configureAppearance()
        requestNotificationPermission()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .preferredColorScheme(resolvedScheme)
                // Start / stop the persistent Dynamic Island session when auth changes
                .onChange(of: authService.currentUser) { _, user in
                    if user != nil {
                        LiveActivityService.shared.startPersistentSession()
                        scheduleBackgroundRefresh()
                    } else {
                        LiveActivityService.shared.stopPersistentSession()
                    }
                }
                // Re-schedule background refresh whenever the app moves to background
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background && authService.currentUser != nil {
                        scheduleBackgroundRefresh()
                    }
                    // When app becomes active, ensure the session is alive + refresh emails
                    if phase == .active && authService.currentUser != nil {
                        LiveActivityService.shared.startPersistentSession()
                        Task { await EmailMonitorService.shared.checkAndNotify() }
                    }
                }
        }
        // ── Background task: refresh staleDate + check emails every ~4 hours
        .backgroundTask(.appRefresh(kLiveActivityRefreshID)) {
            await LiveActivityService.shared.refreshStaleDate()
            await EmailMonitorService.shared.checkAndNotify()
            scheduleBackgroundRefresh()
        }
    }

    // MARK: - Helpers

    private var resolvedScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    private func configureAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance   = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationDelegate.shared
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}

// MARK: - Foreground notification display

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound, .badge])
    }
}

// MARK: - Background refresh scheduling

/// Schedules the next BGAppRefreshTask ~4 hours from now.
/// Must be called each time to keep the chain going.
func scheduleBackgroundRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: kLiveActivityRefreshID)
    request.earliestBeginDate = Date(timeIntervalSinceNow: kRefreshInterval)
    try? BGTaskScheduler.shared.submit(request)
}

// MARK: - Root View (Auth + Subscription Gate)

struct RootView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var store = StoreKitService.shared

    var body: some View {
        Group {
            if showHome {
                HomeView()
                    .environmentObject(authService)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: 0.35)),
                        removal:   .opacity.animation(.easeOut(duration: 0.25))
                    ))
            } else {
                // WelcomeView handles: login, signup, plan selection, and
                // returning users who need to resubscribe (jumps to page 3).
                WelcomeView()
                    .environmentObject(authService)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: 0.35)),
                        removal:   .opacity.animation(.easeOut(duration: 0.25))
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showHome)
    }

    private var showHome: Bool {
        guard let user = authService.currentUser else { return false }
        return user.isDemo == true || store.isSubscribed
    }
}
