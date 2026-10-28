import Foundation
import AppIntents

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
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            MaxShortcutRequest.enqueue(.voice)
        }
        return .result()
    }
}

/// Opens Max first, allowing its access gate to finish before Home starts the activity.
/// It deliberately does not open the microphone or promise background listening.
struct StartMaxIslandIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Max Island"
    static var description = IntentDescription(
        "Opens Max and shows its Live Activity controls on supported iPhones, or on the Lock Screen.",
        categoryName: "Max AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run { MaxShortcutRequest.enqueue(.island) }
        return .result()
    }
}

// MARK: - MaxShortcuts
//
// Registers the intent with the Shortcuts app and Action Button picker.

struct MaxShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartMaxIslandIntent(),
            phrases: ["Show \(.applicationName) Island", "Start \(.applicationName) Island"],
            shortTitle: "Start Max Island",
            systemImageName: "capsule"
        )
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
