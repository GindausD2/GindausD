import ActivityKit
import Foundation

// MARK: - LiveActivityService
//
// Manages Max's persistent Dynamic Island presence.
//
// Session lifecycle:
//   startPersistentSession()  ← call once on sign-in / app launch
//   start()                   ← call when a conversation begins (transitions idle → listening)
//   update(phase:snippet:)    ← call as the conversation phase changes
//   keepAlive()               ← call when a conversation ends (transitions back to idle, stays visible)
//   refreshStaleDate()        ← call from background task every ~4 hours to extend the 24-hr window
//   stopPersistentSession()   ← call only on sign-out / user explicitly closes the island

@MainActor
final class LiveActivityService {

    static let shared = LiveActivityService()
    private init() {}

    private var currentActivity: Activity<MaxActivityAttributes>?

    // MARK: - Persistent 24-hour session

    /// Start (or resume) a standby Live Activity that stays in the Dynamic Island
    /// for up to 24 hours even when the app is closed.
    func startPersistentSession() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // If we already have a live activity, just refresh it
        if let existing = Activity<MaxActivityAttributes>.activities.first {
            currentActivity = existing
            Task {
                await existing.update(.init(
                    state: MaxActivityAttributes.ContentState(phase: .idle, snippet: ""),
                    staleDate: Date().addingTimeInterval(86400)
                ))
            }
            return
        }

        let attributes = MaxActivityAttributes(sessionLabel: "Max AI")
        let standbyState = MaxActivityAttributes.ContentState(phase: .idle, snippet: "")

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: standbyState, staleDate: Date().addingTimeInterval(86400)),
                pushType: nil
            )
        } catch {
            // Live Activities not supported on this device/OS — fail silently
        }
    }

    // MARK: - Conversation start

    /// Transition from standby idle → listening when a conversation begins.
    func start() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if currentActivity == nil {
            // No persistent session yet — create one
            startPersistentSession()
        }

        update(phase: .listening)
    }

    // MARK: - Update

    /// Push a new phase + optional transcript snippet to the Dynamic Island.
    func update(phase: MaxActivityAttributes.ContentState.Phase, snippet: String = "") {
        guard let activity = currentActivity else { return }
        let clipped = snippet.count > 80 ? String(snippet.suffix(80)) : snippet
        let state = MaxActivityAttributes.ContentState(phase: phase, snippet: clipped)
        Task {
            await activity.update(.init(state: state, staleDate: Date().addingTimeInterval(86400)))
        }
    }

    // MARK: - Conversation end → keep alive in standby

    /// Called when a conversation finishes. Transitions the activity back to idle
    /// standby WITHOUT ending it — Max stays visible in the Dynamic Island.
    func end() {
        keepAlive()
    }

    func keepAlive() {
        guard let activity = currentActivity else {
            startPersistentSession()
            return
        }
        let standbyState = MaxActivityAttributes.ContentState(phase: .idle, snippet: "")
        Task {
            await activity.update(.init(state: standbyState, staleDate: Date().addingTimeInterval(86400)))
        }
    }

    // MARK: - Background refresh

    /// Called from a BGAppRefreshTask every ~4 hours to reset the 24-hour staleDate
    /// window so the activity never goes stale while the user is away.
    func refreshStaleDate() async {
        guard let activity = currentActivity else {
            startPersistentSession()
            return
        }
        let current = activity.content.state
        await activity.update(.init(state: current, staleDate: Date().addingTimeInterval(86400)))
    }

    // MARK: - Stop (sign-out / explicit dismiss)

    /// Permanently end the Live Activity. Only call this on sign-out or when the
    /// user explicitly chooses to remove Max from the Dynamic Island.
    func stopPersistentSession() {
        Task { await endAll() }
    }

    // MARK: - Private

    private func endAll() async {
        for activity in Activity<MaxActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
}
