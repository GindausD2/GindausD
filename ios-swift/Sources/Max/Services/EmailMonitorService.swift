import Foundation
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
    private override init() {}

    // MARK: - Stored credentials

    private let kAccessToken  = "max.gmail.accessToken"
    private let kRefreshToken = "max.gmail.refreshToken"
    private let kClientID     = "max.gmail.clientID"

    var isConnected: Bool { accessToken != nil }
    @Published var connectError: String? = nil

    private var accessToken: String? {
        get { UserDefaults.standard.string(forKey: kAccessToken) }
        set { UserDefaults.standard.set(newValue, forKey: kAccessToken) }
    }
    private var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: kRefreshToken) }
        set { UserDefaults.standard.set(newValue, forKey: kRefreshToken) }
    }
    var clientID: String {
        get { UserDefaults.standard.string(forKey: kClientID) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: kClientID) }
    }

    // MARK: - OAuth Connect

    /// Opens the Google OAuth consent screen. The user approves Gmail read-only access.
    /// On success the access token + refresh token are saved automatically.
    func connect() async {
        guard !clientID.isEmpty else { return }

        let redirectURI = "com.gindausd.max:/oauth2callback"
        let scope = "https://www.googleapis.com/auth/gmail.readonly"
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            .init(name: "client_id",     value: clientID),
            .init(name: "redirect_uri",  value: redirectURI),
            .init(name: "response_type", value: "code"),
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
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                session.start()
            }
            await exchangeCodeForTokens(from: callbackURL)
            connectError = nil
        } catch {
            let isCancel = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
            if !isCancel {
                connectError = "Connection failed. Please try again."
            }
        }
    }

    func disconnect() {
        UserDefaults.standard.removeObject(forKey: kAccessToken)
        UserDefaults.standard.removeObject(forKey: kRefreshToken)
        LiveActivityService.shared.clearEmailAlert()
    }

    // MARK: - Check & Notify

    /// Fetches unread important emails and updates the Dynamic Island.
    /// Called from BGAppRefreshTask and on app foreground.
    func checkAndNotify() async {
        guard isConnected else { return }
        let emails = await fetchUnreadImportant()
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
        guard var token = accessToken else { return [] }

        // Try request; if 401 → refresh token and retry once
        if let result = await listMessages(token: token) {
            return result
        }
        if let newToken = await refreshAccessToken() {
            token = newToken
            return await listMessages(token: token) ?? []
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

    private func exchangeCodeForTokens(from callbackURL: URL) async {
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value else { return }

        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "code":          code,
            "client_id":     clientID,
            "redirect_uri":  "com.gindausd.max:/oauth2callback",
            "grant_type":    "authorization_code"
        ].map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        req.httpBody = body.data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        accessToken  = json["access_token"]  as? String
        refreshToken = json["refresh_token"] as? String
    }

    private func refreshAccessToken() async -> String? {
        guard let rt = refreshToken, !clientID.isEmpty else { return nil }

        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "refresh_token": rt,
            "client_id":     clientID,
            "grant_type":    "refresh_token"
        ].map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        req.httpBody = body.data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newToken = json["access_token"] as? String else { return nil }

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
