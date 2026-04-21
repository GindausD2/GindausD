import Foundation
import Supabase

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    let supabase: SupabaseClient

    @Published var currentUser: AuthUser?
    @Published var isLoading: Bool = false
    @Published var authError: String? = nil

    private let demoKey = "max:auth_user_demo"

    private init() {
        supabase = SupabaseClient(
            supabaseURL: URL(string: kSupabaseURL)!,
            supabaseKey: kSupabaseAnonKey
        )

        // Restore demo session first (no network needed)
        if let data = UserDefaults.standard.data(forKey: demoKey),
           let user = try? JSONDecoder().decode(AuthUser.self, from: data) {
            currentUser = user
        }

        // Then try to restore real Supabase session
        Task {
            if let session = try? await supabase.auth.session {
                currentUser = AuthUser(supabaseUser: session.user)
            }
        }

        // Listen for ongoing auth state changes
        Task {
            for await (event, session) in await supabase.auth.authStateChanges {
                switch event {
                case .signedIn, .tokenRefreshed, .userUpdated:
                    if let session { currentUser = AuthUser(supabaseUser: session.user) }
                case .signedOut:
                    if currentUser?.isDemo != true { currentUser = nil }
                default: break
                }
            }
        }
    }

    // MARK: - Apple (native button → Supabase ID-token exchange)

    func signInWithApple(idToken: String, name: String?) async {
        isLoading = true; authError = nil
        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken)
            )
            if let name, !name.isEmpty {
                try? await supabase.auth.update(
                    user: UserAttributes(data: ["full_name": .string(name)])
                )
            }
            currentUser = AuthUser(
                name: name ?? session.user.userMetadata["full_name"]?.stringValue,
                email: session.user.email,
                isDemo: false
            )
        } catch {
            authError = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Demo (local only, no Supabase)

    func startDemo(name: String = "", voice: String = "female") async {
        isLoading = true
        let displayName = name.isEmpty ? "Guest" : name
        let user = AuthUser(name: displayName, email: nil, isDemo: true)
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: demoKey)
        }
        var settings = StorageService.shared.loadSettings()
        settings.preferredVoice = voice
        if settings.userName.isEmpty { settings.userName = displayName }
        StorageService.shared.saveSettings(settings)
        currentUser = user
        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() {
        if currentUser?.isDemo == true {
            UserDefaults.standard.removeObject(forKey: demoKey)
            currentUser = nil
        } else {
            Task { try? await supabase.auth.signOut() }
        }
    }
}

// MARK: - AuthUser from Supabase User

private extension AuthUser {
    init(supabaseUser user: Supabase.User) {
        self.name  = user.userMetadata["full_name"]?.stringValue
        self.email = user.email
        self.isDemo = false
    }
}
