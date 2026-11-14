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
//   keepAlive()                      ← call when a conversation ends (transitions back to idle, stays visible)
//   refreshStaleDate()               ← call from background task every ~4 hours to extend the system-managed window
//   stopPersistentSession()          ← call only on sign-out / user explicitly closes the island

typealias ToolCard = MaxActivityAttributes.ContentState.ToolCard

@MainActor
final class LiveActivityService {

    static let shared = LiveActivityService()
    private init() {}

    private var currentActivity: Activity<MaxActivityAttributes>?
    private var retiredIDs = Set<String>()
    private var generation = UUID()
    private var currentState = MaxActivityAttributes.ContentState(phase: .idle, snippet: "")
    private var updateTask: Task<Void, Never>?
    private var cardExpiryTask: Task<Void, Never>?

    // MARK: - Persistent system-managed session

    /// Start (or resume) a standby Live Activity that stays in the Dynamic Island
    /// for up to the system-managed session window even when the app is closed.
    enum StartResult { case started, resumed, disabled, failed }

    @discardableResult
    func startPersistentSession() -> StartResult {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return .disabled }

        if let existing = Activity<MaxActivityAttributes>.activities.first(where: {
            !retiredIDs.contains($0.id) && ($0.activityState == .active || $0.activityState == .stale)
        }) {
            if currentActivity?.id != existing.id {
                currentActivity = existing
                push(.init(phase: .idle, snippet: ""))
            }
            return .resumed
        }

        let attributes = MaxActivityAttributes(sessionLabel: "Max AI")
        let standbyState = MaxActivityAttributes.ContentState(phase: .idle, snippet: "")

        do {
            currentState = standbyState
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: standbyState, staleDate: Date().addingTimeInterval(8 * 3600)),
                pushType: nil
            )
            return .started
        } catch {
            currentActivity = nil
            return .failed
        }
    }

    // MARK: - Conversation start

    /// Transition from standby idle → listening when a conversation begins.
    func start() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if currentActivity == nil || currentActivity?.activityState == .ended || currentActivity?.activityState == .dismissed {
            startPersistentSession()
        }

        cardExpiryTask?.cancel()
        push(.init(phase: .listening, snippet: "", emailAlert: currentState.emailAlert))
    }

    // MARK: - Update

    func update(phase: MaxActivityAttributes.ContentState.Phase, snippet: String = "") {
        let clipped = String(snippet.suffix(80))
        push(.init(phase: phase, snippet: clipped, toolCard: currentState.toolCard, emailAlert: currentState.emailAlert))
    }

    func showToolCard(_ card: ToolCard) {
        guard currentActivity != nil else { return }
        cardExpiryTask?.cancel()
        var state = currentState
        state.toolCard = card
        push(state)
        if card.reminderStage != .setting {
            cardExpiryTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
                self?.clearToolCard(matching: card)
            }
        }
    }

    func clearToolCard(matching card: ToolCard) {
        guard currentState.toolCard == card else { return }
        var state = currentState
        state.toolCard = nil
        push(state)
    }

    func end() { keepAlive() }

    func keepAlive() {
        guard currentActivity != nil else {
            startPersistentSession()
            return
        }
        update(phase: .idle)
    }

    // MARK: - Background refresh

    func refreshStaleDate() async {
        guard currentActivity != nil else {
            startPersistentSession()
            return
        }
        push(currentState)
        await updateTask?.value
    }

    // MARK: - Email Alerts

    func showEmailAlert(_ alert: MaxActivityAttributes.ContentState.EmailAlert) {
        var state = currentState
        state.emailAlert = alert
        push(state)
    }

    func clearEmailAlert() {
        guard currentState.emailAlert != nil else { return }
        var state = currentState
        state.emailAlert = nil
        push(state)
    }

    // MARK: - Stop (sign-out / explicit dismiss)

    func stopPersistentSession() {
        let activities = Activity<MaxActivityAttributes>.activities
        retiredIDs.formUnion(activities.map(\.id))
        generation = UUID()
        cardExpiryTask?.cancel()
        let pendingUpdate = updateTask
        updateTask?.cancel()
        updateTask = nil
        currentActivity = nil
        currentState = .init(phase: .idle, snippet: "")
        Task {
            await pendingUpdate?.value
            for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    // MARK: - Private

    private func push(_ state: MaxActivityAttributes.ContentState) {
        guard let activity = currentActivity else { return }
        currentState = state
        let version = generation
        let previous = updateTask
        previous?.cancel()
        updateTask = Task {
            await previous?.value
            guard !Task.isCancelled, generation == version, currentActivity?.id == activity.id else { return }
            await activity.update(.init(state: state, staleDate: Date().addingTimeInterval(8 * 3600)))
        }
    }

}
