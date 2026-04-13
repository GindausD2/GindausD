import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    var onClearHistory: (() -> Void)?

    @State private var settings: AppSettings = StorageService.shared.loadSettings()
    @State private var showClearConfirm: Bool = false
    @State private var showSignOutConfirm: Bool = false
    @State private var apiKeyVisible: Bool = false
    @State private var savedIndicator: Bool = false

    private let storage = StorageService.shared

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Profile Section
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#7C3AED"), Color(hex: "#4F46E5")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 52, height: 52)
                            Text(avatarInitials)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName)
                                .font(.body.weight(.semibold))
                            if let email = authService.currentUser?.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if authService.currentUser?.isDemo == true {
                                Text("Demo Account")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(Color(hex: "#7C3AED").opacity(0.85))
                                    )
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Profile")
                }

                // MARK: Profile Name
                Section {
                    HStack {
                        TextField("Your name", text: $settings.userName)
                            .textContentType(.name)
                            .onChange(of: settings.userName) { _, _ in
                                saveSettings()
                            }
                    }
                } header: {
                    Text("Display Name")
                } footer: {
                    Text("Max will use this name when addressing you.")
                }

                // MARK: API Key Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Group {
                                if apiKeyVisible {
                                    TextField("sk-ant-...", text: $settings.apiKey)
                                        .font(.system(.body, design: .monospaced))
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                } else {
                                    SecureField("sk-ant-...", text: $settings.apiKey)
                                        .font(.system(.body, design: .monospaced))
                                }
                            }
                            .textContentType(.password)
                            .onChange(of: settings.apiKey) { _, _ in
                                saveSettings()
                            }

                            Button {
                                apiKeyVisible.toggle()
                            } label: {
                                Image(systemName: apiKeyVisible ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Required for AI responses. Your key is stored locally and never sent anywhere except Anthropic's API.")
                        Link("Get your API key →", destination: URL(string: "https://console.anthropic.com/settings/keys")!)
                            .font(.caption)
                    }
                }

                // MARK: Assistant Settings
                Section {
                    HStack {
                        Label("Assistant Name", systemImage: "person.wave.2")
                        Spacer()
                        TextField("Max", text: $settings.assistantName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .onChange(of: settings.assistantName) { _, _ in
                                saveSettings()
                            }
                    }

                    Toggle(isOn: $settings.voiceEnabled) {
                        Label("Voice Responses", systemImage: settings.voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash")
                    }
                    .onChange(of: settings.voiceEnabled) { _, _ in
                        saveSettings()
                    }
                    .tint(Color(hex: "#7C3AED"))
                } header: {
                    Text("Assistant")
                } footer: {
                    Text("When Voice Responses is on, Max will speak replies using your device's text-to-speech.")
                }

                // MARK: Data Section
                Section {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("Clear Conversation History", systemImage: "trash")
                    }
                    .confirmationDialog(
                        "Clear all messages?",
                        isPresented: $showClearConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("Clear History", role: .destructive) {
                            onClearHistory?()
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete all messages. This cannot be undone.")
                    }
                } header: {
                    Text("Data")
                }

                // MARK: Account Section
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .confirmationDialog(
                        "Sign out of Max?",
                        isPresented: $showSignOutConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("Sign Out", role: .destructive) {
                            authService.signOut()
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                } header: {
                    Text("Account")
                }

                // MARK: About Section
                Section {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Model", value: "Claude Sonnet 4.6")
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Helpers

    private var displayName: String {
        if !settings.userName.isEmpty { return settings.userName }
        if let name = authService.currentUser?.name, !name.isEmpty { return name }
        if let email = authService.currentUser?.email { return email }
        return "Max User"
    }

    private var avatarInitials: String {
        let name = displayName
        let parts = name.components(separatedBy: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        return String(name.prefix(2)).uppercased()
    }

    private func saveSettings() {
        storage.saveSettings(settings)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthService.shared)
}
