import AuthenticationServices
import SwiftUI

struct AccountDeletionButton: View {
    @EnvironmentObject private var auth: AuthService
    @State private var showing = false

    var body: some View {
        if let user = auth.currentUser, let id = user.id {
            Button("Delete Account", role: .destructive) { showing = true }
                .sheet(isPresented: $showing) {
                    AccountDeletionView(accountID: id, isGuest: user.isDemo == true)
                }
        }
    }
}

private struct AccountDeletionView: View {
    let accountID: String
    let isGuest: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthService
    @State private var confirmed = false
    @State private var busy = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Permanent deletion") {
                    Text("Delete your Max account and the Max data stored for it on this iPhone.")
                    if !isGuest {
                        Text("Apple subscriptions are managed separately. Cancel in Apple’s subscription settings to stop renewal.")
                        Link("Manage Apple subscriptions", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    }
                    Toggle("I understand this is permanent", isOn: $confirmed)
                }
                Section {
                    if isGuest {
                        Button("Permanently delete account", role: .destructive) { delete(code: nil) }
                            .disabled(!confirmed || busy)
                    } else {
                        Text("Confirm with the same Apple Account you use for Max.")
                        SignInWithAppleButton(.continue, onRequest: { _ in }, onCompletion: { result in
                            guard case .success(let response) = result,
                                  let credential = response.credential as? ASAuthorizationAppleIDCredential,
                                  let code = credential.authorizationCode,
                                  let value = String(data: code, encoding: .utf8) else {
                                failure = "Apple confirmation was not completed."
                                return
                            }
                            delete(code: value)
                        })
                        .frame(height: 48)
                        .disabled(!confirmed || busy)
                    }
                    if busy { ProgressView("Deleting account…") }
                    if let failure { Text(failure).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) } }
        }
        .interactiveDismissDisabled(busy)
    }

    private func delete(code: String?) {
        guard confirmed, !busy else { return }
        busy = true
        failure = nil
        Task {
            defer { busy = false }
            if let error = await auth.deleteAccount(accountID: accountID, appleCode: code) { failure = error }
            else { dismiss() }
        }
    }
}

struct SupportContactView: View {
    let reporting: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var unavailable = false
    private let address = "support@getmax.app"

    var body: some View {
        NavigationStack {
            Form {
                Text(reporting ? "Describe what went wrong. Include only the details you want to share." : "Contact Max support for help with your account or the app.")
                Button(reporting ? "Open report email" : "Open support email") {
                    var url = URLComponents()
                    url.scheme = "mailto"
                    url.path = address
                    url.queryItems = [.init(name: "subject", value: reporting ? "Max AI content report" : "Max AI support")]
                    if let destination = url.url { openURL(destination) { unavailable = !$0 } }
                }
                if unavailable { Text("No email app opened. Copy the address below to send your message.").foregroundStyle(.secondary) }
                Text(address).textSelection(.enabled)
            }
            .navigationTitle(reporting ? "Report a response" : "Max Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct PrivacyPolicyLink: View {
    var body: some View {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "MAX_PRIVACY_POLICY_URL") as? String,
           let url = URL(string: raw), url.scheme == "https", url.host != nil {
            Link("Privacy Policy", destination: url)
        }
    }
}
