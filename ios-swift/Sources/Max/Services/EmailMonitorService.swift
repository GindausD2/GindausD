import Foundation
import CryptoKit
import Security
import AuthenticationServices
import SwiftUI

// MARK: - EmailMonitorService
//
// Connects to Gmail via OAuth, checks for unread important emails,
// and surfaces them on the Dynamic Island when Max is idle.
//
// Setup (one-time in Settings):
//   1. Tap "Connect Gmail" → OAuth flow via ASWebAuthenticationSession
//   2. Approve Gmail read-only access
//   3. Access token stored in UserDefaults; refresh token used to renew
//
// Ongoing:
//   checkAndNotify() is called from the BGAppRefreshTask every ~4 hours.
//   It fetches unread important emails and pushes an EmailAlert to
//   LiveActivityService if any are found.

@MainActor
final class EmailMonitorService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {

    static let shared = EmailMonitorService()
    private override init() {
        super.init()
        // Older unscoped credentials cannot be assigned safely to a signed-in account.
        UserDefaults.standard.removeObject(forKey: "max.gmail.accessToken")
        UserDefaults.standard.removeObject(forKey: "max.gmail.refreshToken")
    }

    // MARK: - Stored credentials

    private var kAccessToken: String { "max.gmail.\(StorageService.shared.accountScope).access" }
    private var kRefreshToken: String { "max.gmail.\(StorageService.shared.accountScope).refresh" }
    private var authenticationSession: ASWebAuthenticationSession?
    private var verifier = ""
    private var state = ""
    private var lastFetchSucceeded = false

    var isConnected: Bool { accessToken != nil }
    @Published var connectError: String? = nil

    private var accessToken: String? {
        get { SecretStore.get(kAccessToken) }
        set { SecretStore.set(newValue, for: kAccessToken) }
    }
    private var refreshToken: String? {
        get { SecretStore.get(kRefreshToken) }
        set { SecretStore.set(newValue, for: kRefreshToken) }
    }
    var clientID: String { Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String ?? "" }
    private var redirectURI: String { "com.gindausd.max:/oauth2callback" }

    func briefingSummary() async -> String {
        let scope = StorageService.shared.accountScope
        guard isConnected else { return "Email: connect Gmail in Settings to include unread important mail." }
        let emails = await fetchUnreadImportant()
        guard StorageService.shared.accountScope == scope else { return "Email: your account changed. Please refresh." }
        guard lastFetchSucceeded else { return "Email: couldn't refresh Gmail just now." }
        return emails.isEmpty ? "Email: no unread important messages." : "Email: at least \(emails.count) unread important message(s)."
    }

    // MARK: - OAuth Connect

    /// Opens the Google OAuth consent screen. The user approves Gmail read-only access.
    /// On success the access token + refresh token are saved automatically.
    func connect() async {
        guard !clientID.isEmpty else { connectError = "Email connection isn't available yet."; return }
        guard AuthService.shared.currentUser?.id != nil else { connectError = "Sign in to connect your email."; return }
        let accountScope = StorageService.shared.accountScope
        var random = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, random.count, &random) == errSecSuccess else { connectError = "Couldn't start email sign-in."; return }
        verifier = Data(random).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        state = UUID().uuidString
        let scope = "https://www.googleapis.com/auth/gmail.readonly"
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            .init(name: "client_id",     value: clientID),
            .init(name: "redirect_uri",  value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "state", value: state),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "scope",         value: scope),
            .init(name: "access_type",   value: "offline"),
            .init(name: "prompt",        value: "consent")
        ]
        guard let authURL = components.url else { return }

        do {
            let callbackURL = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
                let session = ASWebAuthenticationSession(
                    url: authURL,
                    callbackURLScheme: "com.gindausd.max"
                ) { url, error in
                    if let url { cont.resume(returning: url) }
                    else { cont.resume(throwing: error ?? URLError(.unknown)) }
                }
                authenticationSession = session
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                if !session.start() { authenticationSession = nil; cont.resume(throwing: URLError(.cannotConnectToHost)) }
            }
            authenticationSession = nil
            guard StorageService.shared.accountScope == accountScope,
                  URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "state" })?.value == state else { throw URLError(.userAuthenticationRequired) }
            await exchangeCodeForTokens(from: callbackURL, accountScope: accountScope)
            connectError = isConnected ? nil : "Couldn't connect Gmail. Please try again."
        } catch {
            authenticationSession = nil
            let isCancel = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
            if !isCancel {
                connectError = "Connection failed. Please try again."
            }
        }
    }

    func disconnect() {
        SecretStore.set(nil, for: kAccessToken)
        SecretStore.set(nil, for: kRefreshToken)
        LiveActivityService.shared.clearEmailAlert()
    }

    // MARK: - Check & Notify

    /// Fetches unread important emails and updates the Dynamic Island.
    /// Called from BGAppRefreshTask and on app foreground.
    func checkAndNotify() async {
        let scope = StorageService.shared.accountScope
        guard isConnected else { return }
        let emails = await fetchUnreadImportant()
        guard StorageService.shared.accountScope == scope, lastFetchSucceeded else { return }
        if emails.isEmpty {
            LiveActivityService.shared.clearEmailAlert()
        } else {
            let alert = MaxActivityAttributes.ContentState.EmailAlert(
                count: emails.count,
                latestFrom: emails[0].from,
                latestSubject: emails[0].subject
            )
            LiveActivityService.shared.showEmailAlert(alert)
        }
    }

    // MARK: - Gmail API

    private struct EmailSummary {
        let from: String
        let subject: String
    }

    private func fetchUnreadImportant() async -> [EmailSummary] {
        lastFetchSucceeded = false
        guard var token = accessToken else { return [] }

        // Try request; if 401 → refresh token and retry once
        if let result = await listMessages(token: token) {
            lastFetchSucceeded = true
            return result
        }
        if let newToken = await refreshAccessToken() {
            token = newToken
            if let result = await listMessages(token: token) { lastFetchSucceeded = true; return result }
            return []
        }
        return []
    }

    private func listMessages(token: String) async -> [EmailSummary]? {
        var comps = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")!
        comps.queryItems = [
            .init(name: "q",          value: "is:unread is:important"),
            .init(name: "maxResults", value: "5")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let msgs = json["messages"] as? [[String: Any]] else { return nil }

        var results: [EmailSummary] = []
        for msg in msgs.prefix(3) {
            guard let id = msg["id"] as? String,
                  let summary = await fetchMetadata(id: id, token: token) else { continue }
            results.append(summary)
        }
        return results
    }

    private func fetchMetadata(id: String, token: String) async -> EmailSummary? {
        var comps = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)")!
        comps.queryItems = [
            .init(name: "format",          value: "metadata"),
            .init(name: "metadataHeaders", value: "From"),
            .init(name: "metadataHeaders", value: "Subject")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = json["payload"] as? [String: Any],
              let headers = payload["headers"] as? [[String: Any]] else { return nil }

        var from = ""; var subject = ""
        for h in headers {
            let name = h["name"] as? String ?? ""
            let val  = h["value"] as? String ?? ""
            if name == "From"    { from    = extractSenderName(val) }
            if name == "Subject" { subject = val }
        }
        return EmailSummary(from: from, subject: subject)
    }

    // MARK: - Token Management

    private func exchangeCodeForTokens(from callbackURL: URL, accountScope: String) async {
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value else { return }

        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "code":          code,
            "client_id":     clientID,
            "redirect_uri":  redirectURI,
            "code_verifier": verifier,
            "grant_type":    "authorization_code"
        ].map { pair in
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
            return "\(pair.key)=\(pair.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        }.joined(separator: "&")
        req.httpBody = body.data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        guard StorageService.shared.accountScope == accountScope else { return }
        accessToken  = json["access_token"]  as? String
        refreshToken = json["refresh_token"] as? String
    }

    private func refreshAccessToken() async -> String? {
        let scope = StorageService.shared.accountScope
        guard let rt = refreshToken, !clientID.isEmpty else { return nil }

        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "refresh_token": rt,
            "client_id":     clientID,
            "grant_type":    "refresh_token"
        ].map { pair in
            let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
            return "\(pair.key)=\(pair.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        }.joined(separator: "&")
        req.httpBody = body.data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newToken = json["access_token"] as? String else { return nil }

        guard StorageService.shared.accountScope == scope else { return nil }
        accessToken = newToken
        return newToken
    }

    // MARK: - Helpers

    private func extractSenderName(_ header: String) -> String {
        if let range = header.range(of: " <") { return String(header[..<range.lowerBound]) }
        return header.components(separatedBy: "@").first ?? header
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
