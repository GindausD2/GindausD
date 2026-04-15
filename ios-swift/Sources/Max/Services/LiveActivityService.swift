import ActivityKit
import Foundation

// MARK: - LiveActivityService
//
// Manages the Dynamic Island Live Activity for Max.
// Call start() when a conversation begins, update() as the phase changes,
// and end() when the user dismisses or the session is complete.

@MainActor
final class LiveActivityService {

    static let shared = LiveActivityService()
    private init() {}

    private var currentActivity: Activity<MaxActivityAttributes>?

    // MARK: - Start

    /// Begin a new Live Activity, replacing any existing one.
    func start() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // End any stale activity first
        Task { await endAll() }

        let attributes = MaxActivityAttributes(sessionLabel: "Max AI")
        let initialState = MaxActivityAttributes.ContentState(phase: .listening, snippet: "")

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: Date().addingTimeInterval(3600)),
                pushType: nil
            )
        } catch {
            // Silently fail — Live Activities not supported on this device/OS
        }
    }

    // MARK: - Update

    /// Push a new phase + optional transcript snippet to the Dynamic Island.
    func update(phase: MaxActivityAttributes.ContentState.Phase, snippet: String = "") {
        guard let activity = currentActivity else { return }
        let clipped = snippet.count > 80 ? String(snippet.suffix(80)) : snippet
        let state = MaxActivityAttributes.ContentState(phase: phase, snippet: clipped)
        Task {
            await activity.update(.init(state: state, staleDate: Date().addingTimeInterval(3600)))
        }
    }

    // MARK: - End

    /// Dismiss the Live Activity when the conversation is fully complete.
    func end() {
        guard let activity = currentActivity else { return }
        let finalState = MaxActivityAttributes.ContentState(phase: .idle, snippet: "")
        Task {
            await activity.end(
                .init(state: finalState, staleDate: nil),
                dismissalPolicy: .after(Date().addingTimeInterval(4))
            )
            currentActivity = nil
        }
    }

    // MARK: - Private

    private func endAll() async {
        for activity in Activity<MaxActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
}
