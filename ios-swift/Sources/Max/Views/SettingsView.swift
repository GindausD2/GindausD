import AuthenticationServices
import PhotosUI
import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("max.appearance") private var appearance: String = "system"

    var onClearHistory: (() -> Void)?

    @State private var settings: AppSettings = StorageService.shared.loadSettings()
    @State private var showClearConfirm: Bool = false
    @State private var showSignOutConfirm: Bool = false
    @State private var showSubscription: Bool = false
    @State private var showPrivacy: Bool = false
    @State private var showMemory: Bool = false
    @State private var showIslandDebug: Bool = false
    @State private var showApiConfig: Bool = false
    @State private var showEmailConfig: Bool = false
    @State private var showAssistant: Bool = false
    @State private var showAppearance: Bool = false
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var profileImage: UIImage? = nil

    private let storage = StorageService.shared

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Handle + header ───────────────────────────────────────────
                sheetHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // ── Avatar + name + plan ──────────────────────────────
                        profileHeader

                        // ── QUICK ACTIONS ─────────────────────────────────────
                        ProfileSection(title: "QUICK ACTIONS") {
                            ProfileRow(icon: "crown.fill", iconColor: Color(hex: "#F59E0B"),
                                       title: "Subscription") { showSubscription = true }
                            Divider().padding(.leading, 56)
                            ProfileRow(icon: "brain", iconColor: Color(hex: "#7C3AED"),
                                       title: "Memory") { showMemory = true }
                            Divider().padding(.leading, 56)
                            ProfileRow(icon: "lock.fill", iconColor: Color(hex: "#6B7280"),
                                       title: "Privacy") { showPrivacy = true }
                            Divider().padding(.leading, 56)
                            ProfileRow(icon: "waveform", iconColor: Color(hex: "#7C3AED"),
                                       title: "Island Debug") { showIslandDebug = true }
                        }

                        // ── CONFIGURATION ─────────────────────────────────────
                        ProfileSection(title: "CONFIGURATION") {
                            ProfileRow(icon: "key.fill", iconColor: Color(hex: "#7C3AED"),
                                       title: "AI Configuration") { showApiConfig = true }
                            Divider().padding(.leading, 56)
                            ProfileRow(icon: "envelope.fill", iconColor: Color(hex: "#3B82F6"),
                                       title: "Email Reminders") { showEmailConfig = true }
                            Divider().padding(.leading, 56)
                            ProfileRow(icon: "person.fill", iconColor: Color(hex: "#10B981"),
                                       title: "Assistant") { showAssistant = true }
                            Divider().padding(.leading, 56)
                            ProfileRow(icon: "circle.lefthalf.filled", iconColor: Color(hex: "#6B7280"),
                                       title: "Appearance") { showAppearance = true }
                        }

                        // ── ABOUT ─────────────────────────────────────────────
                        ProfileSection(title: "ABOUT") {
                            ProfileRow(icon: "questionmark.circle.fill", iconColor: Color(hex: "#3B82F6"),
                                       title: "Help Center") {
                                UIApplication.shared.open(URL(string: "mailto:support@getmax.app")!)
                            }
                            Divider().padding(.leading, 56)
                            ProfileRow(icon: "doc.text.fill", iconColor: Color(hex: "#6B7280"),
                                       title: "Terms of Use") {
                                UIApplication.shared.open(URL(string: "https://www.anthropic.com/legal/consumer-terms")!)
                            }
                            Divider().padding(.leading, 56)
                            ProfileRow(icon: "lock.shield.fill", iconColor: Color(hex: "#6B7280"),
                                       title: "Privacy Policy") {
                                UIApplication.shared.open(URL(string: "https://www.anthropic.com/legal/privacy")!)
                            }
                            Divider().padding(.leading, 56)
                            HStack {
                                Label {
                                    Text("Version")
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                } icon: {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color(hex: "#6B7280"))
                                        .frame(width: 28)
                                }
                                Spacer()
                                Text("1.0.0 (1)")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                        }

                        // ── DANGER ZONE ───────────────────────────────────────
                        ProfileSection(title: "") {
                            Button {
                                showClearConfirm = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Clear Conversation History")
                                        .font(.body)
                                        .foregroundStyle(Color(hex: "#EF4444"))
                                    Spacer()
                                }
                                .padding(.vertical, 14)
                            }

                            Divider()

                            Button {
                                showSignOutConfirm = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Sign Out")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Color(hex: "#EF4444"))
                                    Spacer()
                                }
                                .padding(.vertical, 14)
                            }
                        }

                        // ── Guest Sign in with Apple ──────────────────────────
                        if authService.currentUser?.isDemo == true {
                            VStack(spacing: 10) {
                                SignInWithAppleButton(.signIn, onRequest: { req in
                                    req.requestedScopes = [.fullName, .email]
                                }, onCompletion: { result in
                                    switch result {
                                    case .success(let auth):
                                        let credential = auth.credential as? ASAuthorizationAppleIDCredential
                                        let name = [credential?.fullName?.givenName,
                                                    credential?.fullName?.familyName]
                                            .compactMap { $0 }.joined(separator: " ")
                                        let email = credential?.email
                                        Task {
                                            await authService.signInWithApple(
                                                name: name.isEmpty ? nil : name,
                                                email: email
                                            )
                                            dismiss()
                                        }
                                    case .failure:
                                        break
                                    }
                                })
                                .signInWithAppleButtonStyle(.black)
                                .frame(height: 50)
                                .cornerRadius(12)

                                Text("Sign in to sync your data across devices.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 4)
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
        // ── Destination sheets ────────────────────────────────────────────────
        .sheet(isPresented: $showSubscription) { SubscriptionSheet() }
        .sheet(isPresented: $showMemory)       { MemoryView() }
        .sheet(isPresented: $showPrivacy)      { PrivacySheet(settings: $settings, onSave: saveSettings) }
        .sheet(isPresented: $showIslandDebug)  { IslandDebugSheet() }
        .sheet(isPresented: $showApiConfig)    { ApiConfigSheet(settings: $settings, onSave: saveSettings) }
        .sheet(isPresented: $showEmailConfig)  { EmailConfigSheet() }
        .sheet(isPresented: $showAssistant)    { AssistantSheet(settings: $settings, onSave: saveSettings) }
        .sheet(isPresented: $showAppearance)   { AppearanceSheet(appearance: $appearance, settings: $settings, onSave: saveSettings) }
        .confirmationDialog("Clear all messages?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear History", role: .destructive) { onClearHistory?(); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone.") }
        .confirmationDialog("Sign out of Max?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { authService.signOut(); dismiss() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Sheet Header

    private var sheetHeader: some View {
        ZStack {
            // Handle
            VStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                Spacer()
            }

            HStack {
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(UIColor.tertiarySystemFill))
                            .frame(width: 30, height: 30)
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 16)
                .padding(.top, 4)

                Spacer()

                Text("Settings")
                    .font(.headline.weight(.semibold))
                    .padding(.top, 4)

                Spacer()

                // Balance the X button
                Color.clear
                    .frame(width: 30, height: 30)
                    .padding(.trailing, 16)
                    .padding(.top, 4)
            }
        }
        .frame(height: 50)
        .background(Color(UIColor.systemGroupedBackground))
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            // Avatar with camera badge
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let img = profileImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(Color(UIColor.systemGray3))
                        }
                    }
                    .frame(width: 100, height: 100)
                    .background(Color(UIColor.systemGray5))
                    .clipShape(Circle())

                    // Camera badge
                    ZStack {
                        Circle()
                            .fill(Color(UIColor.systemBackground))
                            .frame(width: 32, height: 32)
                        Circle()
                            .fill(.black)
                            .frame(width: 28, height: 28)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 2, y: 2)
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        profileImage = img
                    }
                }
            }

            // Name
            Text(displayName)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.primary)

            // Plan badge
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("Free Plan")
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private var displayName: String {
        if !settings.userName.isEmpty { return settings.userName }
        if let name = authService.currentUser?.name, !name.isEmpty { return name }
        if authService.currentUser?.isDemo == true { return "Guest" }
        return "Max User"
    }

    private func saveSettings() {
        storage.saveSettings(settings)
    }
}

// MARK: - Reusable Row Components

private struct ProfileSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            VStack(spacing: 0) {
                content()
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct ProfileRow: View {
    var icon: String
    var iconColor: Color
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
                    .frame(width: 28)
                    .padding(.leading, 4)

                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Destination Sheets

private struct SubscriptionSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let violet = Color(hex: "#7C3AED")
    private let amber  = Color(hex: "#F59E0B")

    private let features: [(icon: String, title: String, detail: String)] = [
        ("infinity",          "Unlimited Conversations", "No message caps — talk to Max as much as you want"),
        ("bolt.fill",         "Priority Responses",      "Faster replies during peak hours"),
        ("icloud.fill",       "Full iCloud Sync",        "Sync history, memories, and notes across all devices"),
        ("waveform",          "Advanced Voice",          "Premium neural voices and custom wake phrases"),
        ("bell.badge.fill",   "Smart Notifications",     "Proactive reminders and email alerts")
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(amber.opacity(0.12))
                                .frame(width: 88, height: 88)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(amber)
                        }
                        .padding(.top, 24)

                        Text("Max Pro")
                            .font(.system(size: 32, weight: .bold))
                        Text("Everything you need for a truly personal AI assistant.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    // Feature list
                    VStack(spacing: 0) {
                        ForEach(features, id: \.title) { f in
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(violet.opacity(0.10))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: f.icon)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundStyle(violet)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.title)
                                        .font(.system(size: 15, weight: .semibold))
                                    Text(f.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            if f.title != features.last?.title {
                                Divider().padding(.leading, 72)
                            }
                        }
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)

                    // CTA
                    VStack(spacing: 12) {
                        Button {
                            UIApplication.shared.open(URL(string: "mailto:pro@getmax.app?subject=Max%20Pro%20Early%20Access")!)
                        } label: {
                            Text("Join the Waitlist")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(violet, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)

                        Text("Pro is coming soon. Join the waitlist to get early access.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.bottom, 40)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.fontWeight(.semibold)
            }}
        }
    }
}

private struct PrivacySheet: View {
    @Binding var settings: AppSettings
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Share analytics", isOn: $settings.shareAnalytics)
                        .tint(Color(hex: "#7C3AED"))
                        .onChange(of: settings.shareAnalytics) { _, _ in onSave() }
                    Toggle("Personalised suggestions", isOn: $settings.personalisedSuggestions)
                        .tint(Color(hex: "#7C3AED"))
                        .onChange(of: settings.personalisedSuggestions) { _, _ in onSave() }
                } header: { Text("Data Usage") }
                Section {
                    Text("Your conversations are processed by Anthropic's Claude API and are subject to Anthropic's privacy policy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: { Text("Note") }
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.fontWeight(.semibold)
            }}
        }
    }
}

private struct IslandDebugSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phase: MaxActivityAttributes.ContentState.Phase = .idle

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Test the Dynamic Island state by selecting a phase below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                    .padding(.horizontal, 24)

                Picker("Phase", selection: $phase) {
                    Text("Idle").tag(MaxActivityAttributes.ContentState.Phase.idle)
                    Text("Listening").tag(MaxActivityAttributes.ContentState.Phase.listening)
                    Text("Thinking").tag(MaxActivityAttributes.ContentState.Phase.thinking)
                    Text("Speaking").tag(MaxActivityAttributes.ContentState.Phase.speaking)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .onChange(of: phase) { _, p in
                    LiveActivityService.shared.update(phase: p)
                }

                Button("Simulate Email Alert") {
                    LiveActivityService.shared.showEmailAlert(
                        .init(count: 3, latestFrom: "Tim Cook", latestSubject: "Important update for you")
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#3B82F6"))

                Button("Clear Email Alert") {
                    LiveActivityService.shared.clearEmailAlert()
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                Spacer()
            }
            .navigationTitle("Island Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.fontWeight(.semibold)
            }}
        }
    }
}

private struct ApiConfigSheet: View {
    @Binding var settings: AppSettings
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var apiKeyVisible: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Group {
                            if apiKeyVisible {
                                TextField("sk-ant-...", text: $settings.apiKey)
                                    .autocapitalization(.none).autocorrectionDisabled()
                            } else {
                                SecureField("sk-ant-...", text: $settings.apiKey)
                            }
                        }
                        .font(.system(.body, design: .monospaced))
                        .tint(Color(hex: "#7C3AED"))
                        .onChange(of: settings.apiKey) { _, _ in onSave() }
                        Button { apiKeyVisible.toggle() } label: {
                            Image(systemName: apiKeyVisible ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }.buttonStyle(.plain)
                    }
                } header: { Text("Anthropic API Key") }
                  footer: { Text("Stored locally · only sent to Anthropic's API") }

                Section {
                    Link("Get your key →", destination: URL(string: "https://console.anthropic.com/settings/keys")!)
                        .foregroundStyle(Color(hex: "#7C3AED"))
                }
            }
            .navigationTitle("AI Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.fontWeight(.semibold)
            }}
        }
    }
}

private struct EmailConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var clientID: String = EmailMonitorService.shared.clientID
    @State private var isConnecting: Bool = false
    @State private var connectError: String? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("com.example.app.googleusercontent.com", text: $clientID)
                        .autocapitalization(.none).autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: clientID) { _, v in EmailMonitorService.shared.clientID = v }
                } header: { Text("Google Client ID") }
                  footer: {
                    Text("Max will surface unread important emails on your Dynamic Island.")
                }

                Section {
                    if EmailMonitorService.shared.isConnected {
                        HStack {
                            Label("Gmail connected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Spacer()
                            Button("Disconnect") { EmailMonitorService.shared.disconnect() }
                                .foregroundStyle(.red)
                        }
                    } else {
                        Button {
                            isConnecting = true
                            connectError = nil
                            Task {
                                await EmailMonitorService.shared.connect()
                                connectError = EmailMonitorService.shared.connectError
                                if connectError == nil {
                                    await EmailMonitorService.shared.checkAndNotify()
                                }
                                isConnecting = false
                            }
                        } label: {
                            HStack {
                                if isConnecting { ProgressView().scaleEffect(0.8) }
                                Text(isConnecting ? "Connecting…" : "Connect Gmail")
                            }
                        }
                        .disabled(clientID.isEmpty || isConnecting)
                        if let err = connectError {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Section {
                    Link("Create credentials →",
                         destination: URL(string: "https://console.cloud.google.com/apis/credentials")!)
                        .foregroundStyle(Color(hex: "#7C3AED"))
                }
            }
            .navigationTitle("Email Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.fontWeight(.semibold)
            }}
        }
    }
}

private struct AssistantSheet: View {
    @Binding var settings: AppSettings
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Your Name")
                        Spacer()
                        TextField("Name", text: $settings.userName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .tint(Color(hex: "#7C3AED"))
                            .onChange(of: settings.userName) { _, _ in onSave() }
                    }
                    Toggle(isOn: $settings.voiceEnabled) {
                        Label("Voice Responses", systemImage: "speaker.wave.2.fill")
                    }
                    .tint(Color(hex: "#7C3AED"))
                    .onChange(of: settings.voiceEnabled) { _, _ in onSave() }
                } header: { Text("Preferences") }
            }
            .navigationTitle("Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.fontWeight(.semibold)
            }}
        }
    }
}

private struct AppearanceSheet: View {
    @Binding var appearance: String
    @Binding var settings: AppSettings
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Theme", selection: $appearance) {
                        Label("System", systemImage: "gear").tag("system")
                        Label("Light",  systemImage: "sun.max").tag("light")
                        Label("Dark",   systemImage: "moon.stars").tag("dark")
                    }
                    .pickerStyle(.inline)
                    .onChange(of: appearance) { _, v in settings.colorScheme = v; onSave() }
                } header: { Text("Color Scheme") }
            }
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.fontWeight(.semibold)
            }}
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AuthService.shared)
}
