import ActivityKit
import Foundation

// MARK: - LiveActivityService
//
// Manages Max's persistent Dynamic Island presence.
//
// Session lifecycle:
//   startPersistentSession()         ← call once on sign-in / app launch
//   start()                          ← call when a conversation begins (transitions idle → listening)
//   update(phase:snippet:)           ← call as the conversation phase changes
//   showToolCard(_:)                 ← call after a tool executes to show the action card
//   clearToolCard()                  ← call to remove the card (e.g. on next listening phase)
//   keepAlive()                      ← call when a conversation ends (transitions back to idle, stays visible)
//   refreshStaleDate()               ← call from background task every ~4 hours to extend the 24-hr window
//   stopPersistentSession()          ← call only on sign-out / user explicitly closes the island

typealias ToolCard = MaxActivityAttributes.ContentState.ToolCard

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
            startPersistentSession()
        }

        update(phase: .listening)
    }

    // MARK: - Update

    /// Push a new phase + optional transcript snippet to the Dynamic Island.
    /// Clears any active tool card (conversation taking priority).
    func update(phase: MaxActivityAttributes.ContentState.Phase, snippet: String = "") {
        let clipped = snippet.count > 80 ? String(snippet.suffix(80)) : snippet
        push(MaxActivityAttributes.ContentState(phase: phase, snippet: clipped, toolCard: nil))
    }

    // MARK: - Tool Cards

    /// Show a contextual action card in the Dynamic Island after a tool executes.
    func showToolCard(_ card: ToolCard) {
        guard let activity = currentActivity else { return }
        let s = activity.content.state
        push(MaxActivityAttributes.ContentState(phase: s.phase, snippet: s.snippet, toolCard: card))
    }

    /// Remove the tool card, reverting to the current phase display.
    func clearToolCard() {
        guard let activity = currentActivity else { return }
        let s = activity.content.state
        push(MaxActivityAttributes.ContentState(phase: s.phase, snippet: s.snippet, toolCard: nil))
    }

    // MARK: - Conversation end → keep alive in standby

    func end() {
        keepAlive()
    }

    func keepAlive() {
        guard let activity = currentActivity else {
            startPersistentSession()
            return
        }
        let standbyState = MaxActivityAttributes.ContentState(phase: .idle, snippet: "")
        push(standbyState)
    }

    // MARK: - Background refresh

    func refreshStaleDate() async {
        guard let activity = currentActivity else {
            startPersistentSession()
            return
        }
        let current = activity.content.state
        await activity.update(.init(state: current, staleDate: Date().addingTimeInterval(86400)))
    }

    // MARK: - Email Alerts

    func showEmailAlert(_ alert: MaxActivityAttributes.ContentState.EmailAlert) {
        guard let activity = currentActivity else { return }
        let s = activity.content.state
        push(MaxActivityAttributes.ContentState(phase: s.phase, snippet: s.snippet,
                                                toolCard: s.toolCard, emailAlert: alert))
    }

    func clearEmailAlert() {
        guard let activity = currentActivity else { return }
        let s = activity.content.state
        guard s.emailAlert != nil else { return }
        push(MaxActivityAttributes.ContentState(phase: s.phase, snippet: s.snippet,
                                                toolCard: s.toolCard, emailAlert: nil))
    }

    // MARK: - Stop (sign-out / explicit dismiss)

    func stopPersistentSession() {
        Task { await endAll() }
    }

    // MARK: - Private

    private func push(_ state: MaxActivityAttributes.ContentState) {
        guard let activity = currentActivity else { return }
        Task {
            await activity.update(.init(state: state, staleDate: Date().addingTimeInterval(86400)))
        }
    }

    private func endAll() async {
        for activity in Activity<MaxActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
}
