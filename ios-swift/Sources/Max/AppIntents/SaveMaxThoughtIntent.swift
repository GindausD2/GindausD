import AppIntents
import Foundation

struct SaveMaxThoughtIntent: AppIntent {
    static let title: LocalizedStringResource = "Save a thought in Max"
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Thought", requestValueDialog: "What would you like to save?")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let auth = AuthService.shared
        for _ in 0..<20 where auth.isRestoringSession {
            try await Task.sleep(for: .milliseconds(150))
        }
        guard let user = auth.currentUser, let accountID = user.id, !auth.isDemoExpired,
              user.allowsAccess(hasSubscription: StoreKitService.shared.isSubscribed, at: Date()) else {
            return .result(dialog: "Open Max on your iPhone and check your access, then try again.")
        }
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return .result(dialog: "There was no thought to save.") }
        let store = ThoughtStore.shared
        store.open(scope: accountID.lowercased())
        try store.save(MaxThought(title: String(title.prefix(160)), source: "Shortcut"))
        if user.isDemo == false && store.syncEnabled { await store.sync() }
        return .result(dialog: "Saved in Max.")
    }
}
