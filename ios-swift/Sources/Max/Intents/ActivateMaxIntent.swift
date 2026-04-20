import AppIntents
import ActivityKit

// MARK: - ActivateMaxIntent
//
// Assigned to the iPhone Action Button via:
//   Settings → Action Button → Shortcut → "Activate Max"
//
// Pressing the Action Button starts (or resumes) the Max Dynamic Island
// session and switches it to the listening phase so Max is ready to hear.

struct ActivateMaxIntent: AppIntent {
    static var title: LocalizedStringResource = "Activate Max"
    static var description = IntentDescription(
        "Activates Max AI on the Dynamic Island and starts listening.",
        categoryName: "Max AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            LiveActivityService.shared.startPersistentSession()
            LiveActivityService.shared.start()
        }
        return .result()
    }
}

// MARK: - MaxShortcuts
//
// Registers the intent with the Shortcuts app and Action Button picker.

struct MaxShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ActivateMaxIntent(),
            phrases: [
                "Activate \(.applicationName)",
                "Start \(.applicationName)",
                "Open \(.applicationName)"
            ],
            shortTitle: "Activate Max",
            systemImageName: "waveform.circle.fill"
        )
    }
}
