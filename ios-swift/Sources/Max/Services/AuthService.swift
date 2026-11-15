import Foundation
import Combine
import Supabase
import UserNotifications
import WidgetKit
import AuthenticationServices
import CryptoKit
import Security

struct AppleSignInAttempt {
    let state: String
    let nonce: String
    let linkGuest: Bool
    let accountID: String?
    let guestID: UUID?
    let startedAt: Date

    static func consume(_ pending: inout Self?, state: String?, accountID: String?, now: Date = .now) -> Self? {
        guard let attempt = pending, let state, state == attempt.state else { return nil }
        pending = nil
        let age = now.timeIntervalSince(attempt.startedAt)
        guard attempt.accountID == accountID, (0..<300).contains(age) else { return nil }
        return attempt
    }
}

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    let supabase: SupabaseClient

    @Published var currentUser: AuthUser? {
        didSet {
            let scope = currentUser?.storageScope ?? "signed-out"
            if scope != StorageService.shared.accountScope {
                let ids = StorageService.shared.loadReminders().map(\.id) + [BriefingService.notificationID]
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
                VoiceService.shared.stopRecording(); VoiceService.shared.stopSpeaking()
                VoiceService.shared.clearRecentCloudSpeech()
                ReminderApprovalService.shared.cancel()
                LifeMemoryApproval.shared.cancel()
                LiveActivityService.shared.stopPersistentSession()
                let widget = UserDefaults(suiteName: "group.com.gindausd.max")
                widget?.removeObject(forKey: "max:widget_last_message")
                widget?.removeObject(forKey: "max:widget_last_message_time")
                WidgetCenter.shared.reloadAllTimelines()
                for key in ["max.pendingBriefing", "max.pendingQuickReply"] { UserDefaults.standard.removeObject(forKey: key) }
                MaxShortcutRequest.accountDidChange(hadPreviousUser: oldValue != nil)
            }
            if oldValue?.id != currentUser?.id, let oldID = oldValue?.id?.lowercased() {
                try? ThoughtStore.shared.cancelAlerts(scope: oldID)
            }
            ThoughtStore.shared.open(scope: currentUser?.id?.lowercased())
            StorageService.shared.setAccountScope(scope)
            if oldValue?.id != currentUser?.id || oldValue?.isDemo != currentUser?.isDemo {
                Task { await StoreKitService.shared.refreshEntitlements() }
            }
        }
    }
    @Published var isLoading: Bool = false
    @Published var authError: String? = nil
    @Published var isRestoringSession = true
    @Published var isUpgradingDemo = false
    @Published private(set) var serverExpiredDemo = false

    private let demoKey      = "max:auth_user_demo"
    private var appleAttempt: AppleSignInAttempt?

    var demoTrialExpiry: Date? {
        currentUser?.trialExpiresAt
    }

    var isDemoExpired: Bool {
        currentUser?.isDemo == true && (serverExpiredDemo || currentUser?.demoIsExpired(at: Date()) == true)
    }

    var demoTrialDaysRemaining: Int {
        guard let expiry = demoTrialExpiry else { return 0 }
        return max(0, Int(ceil(expiry.timeIntervalSinceNow / 86400)))
    }

    private init() {
        supabase = SupabaseClient(
            supabaseURL: URL(string: kSupabaseURL)!,
            supabaseKey: kSupabaseAnonKey
        )

        StorageService.shared.setAccountScope("signed-out")
        Task {
            defer { isRestoringSession = false }
            guard !kSupabaseAnonKey.isEmpty else { return }
            if let session = try? await supabase.auth.session {
                applySession(session)
            } else if let cached = supabase.auth.currentSession {
                // Keep the guest identity during a refresh/network failure; never restart its clock.
                applySession(cached)
            }
        }

        // Listen for ongoing auth state changes
        Task {
            for await (event, session) in supabase.auth.authStateChanges {
                switch event {
                case .signedIn, .tokenRefreshed, .userUpdated:
                    if let session { applySession(session) }
                case .signedOut:
                    currentUser = nil
                default: break
                }
            }
        }
    }

    func managedSession() async throws -> (token: String, userID: String) {
        guard !kSupabaseAnonKey.isEmpty, !isDemoExpired else { throw URLError(.userAuthenticationRequired) }
        let session = try await supabase.auth.session
        let userID = session.user.id.uuidString
        guard userID == currentUser?.id else { throw URLError(.userAuthenticationRequired) }
        return (session.accessToken, userID)
    }

    private func applySession(_ session: Session, appleName: String? = nil) {
        let previousID = currentUser?.id
        var user = AuthUser(supabaseUser: session.user)
        if let appleName { user.name = appleName }
        currentUser = user
        if previousID != currentUser?.id { serverExpiredDemo = false }
        if session.user.isAnonymous {
            if let data = try? JSONEncoder().encode(currentUser) { UserDefaults.standard.set(data, forKey: demoKey) }
        } else {
            isUpgradingDemo = false
            UserDefaults.standard.removeObject(forKey: demoKey)
        }
    }

    func beginDemoUpgrade() { isUpgradingDemo = true; authError = nil }
    func cancelDemoUpgrade() { isUpgradingDemo = false; authError = nil }

    func markDemoExpired() {
        guard currentUser?.isDemo == true else { return }
        serverExpiredDemo = true
        VoiceService.shared.stopRecording(); VoiceService.shared.stopSpeaking()
        VoiceService.shared.clearRecentCloudSpeech()
        LiveActivityService.shared.stopPersistentSession()
    }

    // MARK: - Apple (native button → Supabase ID-token exchange)

    func prepareAppleSignIn(_ request: ASAuthorizationAppleIDRequest, linkGuest: Bool = true) {
        authError = nil
        appleAttempt = nil
        var random = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, random.count, &random) == errSecSuccess else {
            authError = "Apple sign-in couldn’t start. Please try again."
            return
        }
        let nonce = random.map { String(format: "%02x", $0) }.joined()
        let state = UUID().uuidString
        let session = supabase.auth.currentSession
        let guestID = session?.user.isAnonymous == true ? session?.user.id : nil
        appleAttempt = AppleSignInAttempt(state: state, nonce: nonce, linkGuest: linkGuest,
                                          accountID: currentUser?.id, guestID: guestID, startedAt: .now)
        request.requestedScopes = [.fullName, .email]
        request.state = state
        request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    var hasGuestSession: Bool { supabase.auth.currentSession?.user.isAnonymous == true }

    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>, onSuccess: (() -> Void)? = nil) {
        guard !isLoading else { return }
        switch result {
        case .failure(let error):
            if authError == nil { authError = Self.appleAuthorizationMessage(error) }
            // The failure has no request state. Only a matching success or a new request
            // should consume the challenge, since a dismissal may arrive during a retry.
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let data = credential.identityToken,
                  let token = String(data: data, encoding: .utf8), !token.isEmpty else {
                authError = "Apple didn’t return a sign-in credential. Please try again."
                return
            }
            guard let attempt = AppleSignInAttempt.consume(&appleAttempt, state: credential.state,
                                                           accountID: currentUser?.id) else {
                authError = "This Apple sign-in attempt expired or was replaced. Please try again."
                return
            }
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            isLoading = true
            authError = nil
            Task { await exchangeAppleCredential(token, name: name, attempt: attempt, onSuccess: onSuccess) }
        }
    }

    static func appleAuthorizationMessage(_ error: Error) -> String? {
        let failure = error as NSError
        if failure.domain == ASAuthorizationError.errorDomain &&
            failure.code == ASAuthorizationError.Code.canceled.rawValue {
            return nil
        }
        return "Apple couldn’t complete sign-in. Please try again."
    }

    private func exchangeAppleCredential(_ idToken: String, name: String, attempt: AppleSignInAttempt,
                                         onSuccess: (() -> Void)?) async {
        defer { isLoading = false }
        guard currentUser?.id == attempt.accountID else { return }
        if attempt.linkGuest, currentUser?.isDemo == true, attempt.guestID == nil {
            authError = "Max couldn’t restore your guest account. Reopen Max and try again."
            return
        }
        do {
            let credentials = OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: attempt.nonce)
            let session: Session
            if attempt.linkGuest, let guestID = attempt.guestID {
                guard let active = supabase.auth.currentSession, active.user.isAnonymous, active.user.id == guestID else {
                    authError = "Your guest account changed. Please start Apple sign-in again."
                    return
                }
                session = try await supabase.auth.linkIdentityWithIdToken(credentials: credentials)
                guard session.user.id == guestID, !session.user.isAnonymous else {
                    authError = "Max couldn’t confirm that Apple was linked to your guest account."
                    return
                }
            } else {
                session = try await supabase.auth.signInWithIdToken(credentials: credentials)
            }
            let appleName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !appleName.isEmpty {
                _ = try? await supabase.auth.update(
                    user: UserAttributes(data: ["full_name": .string(appleName)])
                )
            }
            guard let latest = supabase.auth.currentSession, latest.user.id == session.user.id else {
                authError = "Max couldn’t confirm the new session. Please try again."
                return
            }
            applySession(latest, appleName: appleName.isEmpty ? nil : appleName)
            onSuccess?()
        } catch {
            authError = "Max couldn’t complete Apple sign-in. Check your connection and try again."
        }
    }

    // MARK: - Three-day guest demo (no Apple identity or purchase required)

    @discardableResult
    func startDemo(name: String = "", voice: String = "female") async -> Bool {
        guard !isLoading, !isRestoringSession else { return false }
        isLoading = true; authError = nil
        defer { isLoading = false }
        do {
            guard !kSupabaseAnonKey.isEmpty, !kMaxAPIBaseURL.isEmpty else {
                throw DemoError.unavailable
            }
            let session: Session
            if supabase.auth.currentSession != nil {
                // A failed refresh must fail this attempt, not silently create another trial.
                session = try await supabase.auth.session
            } else {
                session = try await supabase.auth.signInAnonymously(data: ["full_name": .string(name.isEmpty ? "Guest" : name)])
            }
            applySession(session)
            guard session.user.isAnonymous else { return true }
            var settings = StorageService.shared.loadSettings()
            settings.preferredVoice = voice
            if settings.userName.isEmpty { settings.userName = name.isEmpty ? "Guest" : name }
            StorageService.shared.saveSettings(settings)
            return true
        } catch {
            authError = "The demo couldn't start. Please check your connection and try again."
            return false
        }
    }

    func deleteAccount(accountID: String, appleCode: String?) async -> String? {
        guard !isLoading, currentUser?.id == accountID else { return "Your account changed. Try again." }
        guard let base = URL(string: kMaxAPIBaseURL), base.scheme == "https", base.host != nil else {
            return "Account deletion is temporarily unavailable."
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let session = try await supabase.auth.session
            guard session.user.id.uuidString == accountID, currentUser?.id == accountID else { return "Your account changed. Try again." }
            var request = URLRequest(url: base.appendingPathComponent("v1/account/delete"))
            request.httpMethod = "POST"
            request.timeoutInterval = 45
            request.setValue("Bearer " + session.accessToken, forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(appleCode.map { ["appleCode": $0] } ?? [:])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 204 else {
                let details = try? JSONSerialization.jsonObject(with: data) as? [String: String]
                return details?["error"] ?? "Account deletion is temporarily unavailable."
            }

            try? ThoughtStore.shared.removeLocal(scope: accountID.lowercased())

            // Clear the verified account's local scope even if the active account changed.
            let defaults = UserDefaults.standard
            let prefix = "max.account." + accountID + "."
            let reminderIDs = StorageService.shared.loadReminders(scope: accountID).map(\.id)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIDs)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: reminderIDs)
            for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
                defaults.removeObject(forKey: key)
            }
            SecretStore.set(nil, for: "max.gmail." + accountID + ".access")
            SecretStore.set(nil, for: "max.gmail." + accountID + ".refresh")
            if currentUser?.id == accountID {
                defaults.removeObject(forKey: demoKey)
                currentUser = nil
                isUpgradingDemo = false
                try? await supabase.auth.signOut(scope: .local)
            }
            return nil
        } catch { return "Max couldn’t confirm deletion. Check your connection and try again." }
    }

    // MARK: - Sign Out

    func signOut() {
        appleAttempt = nil
        let wasDemo = currentUser?.isDemo == true
        currentUser = nil
        isUpgradingDemo = false
        if wasDemo {
            // Keep Supabase's guest session so leaving/reopening cannot restart the trial.
            UserDefaults.standard.removeObject(forKey: demoKey)
        } else {
            Task { try? await supabase.auth.signOut() }
        }
    }

    /// Called on each app foreground to expire a demo whose 3-day trial is over.
    func expireDemoIfNeeded() {
        guard isDemoExpired else { return }
        markDemoExpired()
    }

    private enum DemoError: Error { case unavailable }
}

// MARK: - AuthUser from Supabase User

private extension AuthUser {
    init(supabaseUser user: Supabase.User) {
        self.id = user.id.uuidString
        self.name  = user.userMetadata["full_name"]?.stringValue
        self.email = user.email
        self.isDemo = user.isAnonymous
        self.trialStartedAt = user.isAnonymous ? user.createdAt : nil
    }
}

