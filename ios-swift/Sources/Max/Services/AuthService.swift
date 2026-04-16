import Foundation
import Combine

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    private let storageKey = "max:auth_user"

    @Published var currentUser: AuthUser?
    @Published var isLoading: Bool = false

    private init() {
        currentUser = loadUser()
    }

    // MARK: - Persistence

    private func loadUser() -> AuthUser? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let user = try? JSONDecoder().decode(AuthUser.self, from: data)
        else { return nil }
        return user
    }

    private func saveUser(_ user: AuthUser?) {
        if let user = user,
           let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
        currentUser = user
    }

    // MARK: - Auth Actions

    func signIn(email: String, password: String) async {
        isLoading = true
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 800_000_000)
        let user = AuthUser(name: nil, email: email, isDemo: false)
        saveUser(user)
        isLoading = false
    }

    func signUp(name: String, email: String) async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 800_000_000)
        let user = AuthUser(name: name, email: email, isDemo: false)
        saveUser(user)
        isLoading = false
    }

    func startDemo(name: String = "", voice: String = "female") async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 400_000_000)
        let displayName = name.isEmpty ? "Demo User" : name
        let user = AuthUser(name: displayName, email: nil, isDemo: true)
        saveUser(user)

        // Persist the voice preference so HomeView and VoiceService can use it
        var settings = StorageService.shared.loadSettings()
        settings.preferredVoice = voice
        if settings.userName.isEmpty { settings.userName = displayName }
        StorageService.shared.saveSettings(settings)

        isLoading = false
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        currentUser = nil
    }

    func signInWithGoogle() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 600_000_000)
        let user = AuthUser(name: "Google User", email: "user@gmail.com", isDemo: false)
        saveUser(user)
        isLoading = false
    }

    func signInWithApple(name: String?, email: String?) async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 400_000_000)
        let user = AuthUser(name: name ?? "Apple User", email: email, isDemo: false)
        saveUser(user)
        isLoading = false
    }
}
