import AuthenticationServices
import Foundation
import Supabase

@MainActor
final class AuthService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AuthService()

    // Supabase client — shared across the app for DB / storage if needed later
    let supabase: SupabaseClient

    @Published var currentUser: AuthUser?
    @Published var isLoading: Bool = false
    @Published var authError: String? = nil

    private let callbackScheme = "com.gindausd.max"
    private let demoKey = "max:auth_user_demo"

    private override init() {
        supabase = SupabaseClient(
            supabaseURL: URL(string: kSupabaseURL)!,
            supabaseKey: kSupabaseAnonKey
        )
        super.init()

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

    // MARK: - Email / Password

    func signUp(name: String, email: String, password: String) async {
        isLoading = true; authError = nil
        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(name)]
            )
            if let user = response.user {
                currentUser = AuthUser(supabaseUser: user)
            }
        } catch {
            authError = error.localizedDescription
        }
        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true; authError = nil
        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            currentUser = AuthUser(supabaseUser: session.user)
        } catch {
            authError = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Apple (native button → Supabase ID-token exchange)

    func signInWithApple(idToken: String, name: String?) async {
        isLoading = true; authError = nil
        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken)
            )
            // Store display name in Supabase user metadata on first sign-in
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

    // MARK: - Google (web OAuth via ASWebAuthenticationSession)

    func signInWithGoogle() async {
        isLoading = true; authError = nil
        do {
            let url = try await supabase.auth.getOAuthSignInURL(
                provider: .google,
                redirectTo: URL(string: "\(callbackScheme)://login-callback")!
            )
            let callbackURL = try await openOAuth(url: url)
            let session = try await supabase.auth.session(from: callbackURL)
            currentUser = AuthUser(supabaseUser: session.user)
        } catch {
            let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
            if !cancelled { authError = error.localizedDescription }
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

    // MARK: - OAuth browser helper

    private func openOAuth(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error      { continuation.resume(throwing: error) }
                else if let cbURL { continuation.resume(returning: cbURL) }
                else              { continuation.resume(throwing: URLError(.badURL)) }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
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
