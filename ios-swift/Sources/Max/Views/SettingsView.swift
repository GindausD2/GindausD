import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// @AppStorage so changes propagate instantly to MaxApp's preferredColorScheme
    @AppStorage("max.appearance") private var appearance: String = "system"

    var onClearHistory: (() -> Void)?

    @State private var settings: AppSettings = StorageService.shared.loadSettings()
    @State private var apiKeyVisible: Bool = false
    @State private var showClearConfirm: Bool = false
    @State private var showSignOutConfirm: Bool = false
    @State private var savedBanner: Bool = false

    private let storage = StorageService.shared

    // MARK: - Body

    var body: some View {
        ZStack {
            // Adaptive background
            settingsBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Spacer().frame(height: 8)

                    profileCard
                    appearanceSection
                    apiKeySection
                    emailSection
                    assistantSection
                    dataSection
                    aboutSection

                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.primary)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(hex: "#7C3AED"))
            }
        }
        .overlay(savedToast, alignment: .bottom)
        .confirmationDialog("Clear all messages?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear History", role: .destructive) {
                onClearHistory?()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all messages and cannot be undone.")
        }
        .confirmationDialog("Sign out of Max?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                authService.signOut()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Background

    private var settingsBackground: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "#06030F"), location: 0),
                        .init(color: Color(hex: "#0E0620"), location: 0.6),
                        .init(color: Color(hex: "#100825"), location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            } else {
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.97, green: 0.96, blue: 1.00), location: 0),
                        .init(color: Color(red: 0.93, green: 0.91, blue: 0.99), location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        GlassCard(cornerRadius: 24, depth: colorScheme == .dark ? .thin : .ultraThin) {
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#7C3AED"), Color(hex: "#4F46E5")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    Text(avatarInitials)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .shadow(color: Color(hex: "#7C3AED").opacity(0.4), radius: 10, x: 0, y: 4)

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.primary)

                    if let email = authService.currentUser?.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }

                    if authService.currentUser?.isDemo == true {
                        Text("Demo Account")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "#7C3AED").opacity(0.80))
                                    .overlay(
                                        Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                                    )
                            )
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        SettingsGlassSection(title: "Appearance", colorScheme: colorScheme) {
            VStack(spacing: 14) {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Theme")
                                .font(.body)
                                .foregroundStyle(Color.primary)
                            Text("Controls the app's color scheme")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                    } icon: {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(hex: "#7C3AED"))
                    }
                    Spacer()
                }

                Picker("Theme", selection: $appearance) {
                    Label("System", systemImage: "gear").tag("system")
                    Label("Light",  systemImage: "sun.max").tag("light")
                    Label("Dark",   systemImage: "moon.stars").tag("dark")
                }
                .pickerStyle(.segmented)
                .onChange(of: appearance) { _, _ in
                    // @AppStorage automatically persists; also sync AppSettings
                    settings.colorScheme = appearance
                    saveSettings()
                }
            }
        }
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        SettingsGlassSection(title: "AI Configuration", colorScheme: colorScheme) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Anthropic API Key", systemImage: "key.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.secondary)

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
                    .foregroundStyle(Color.primary)
                    .tint(Color(hex: "#7C3AED"))
                    .onChange(of: settings.apiKey) { _, _ in saveSettings() }

                    Button {
                        apiKeyVisible.toggle()
                    } label: {
                        Image(systemName: apiKeyVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                )

                Text("Stored locally · only sent to Anthropic's API")
                    .font(.caption)
                    .foregroundStyle(Color.secondary.opacity(0.8))

                Link("Get your key at console.anthropic.com →",
                     destination: URL(string: "https://console.anthropic.com/settings/keys")!)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(hex: "#7C3AED"))
            }
        }
    }

    // MARK: - Email Section

    @State private var gmailClientID: String = EmailMonitorService.shared.clientID
    @State private var isConnectingGmail: Bool = false

    private var emailSection: some View {
        SettingsGlassSection(title: "Email Reminders", colorScheme: colorScheme) {
            VStack(alignment: .leading, spacing: 14) {

                Text("Max will show unread important emails on your Dynamic Island while the app is in the background.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Google Client ID input
                VStack(alignment: .leading, spacing: 6) {
                    Text("Google Client ID")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("com.example.app.googleusercontent.com", text: $gmailClientID)
                        .font(.system(size: 14, design: .monospaced))
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onChange(of: gmailClientID) { _, v in
                            EmailMonitorService.shared.clientID = v
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.04))
                                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
                        )
                    Link("Create one at console.cloud.google.com →",
                         destination: URL(string: "https://console.cloud.google.com/apis/credentials")!)
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#7C3AED"))
                }

                // Connect / Disconnect button
                if EmailMonitorService.shared.isConnected {
                    HStack {
                        Label("Gmail connected", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Disconnect") {
                            EmailMonitorService.shared.disconnect()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.red)
                    }
                } else {
                    Button {
                        guard !gmailClientID.isEmpty else { return }
                        isConnectingGmail = true
                        Task {
                            await EmailMonitorService.shared.connect()
                            await EmailMonitorService.shared.checkAndNotify()
                            isConnectingGmail = false
                        }
                    } label: {
                        HStack {
                            if isConnectingGmail {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "envelope.badge.fill")
                            }
                            Text(isConnectingGmail ? "Connecting…" : "Connect Gmail")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#4285F4"), Color(hex: "#1A73E8")],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                        )
                    }
                    .disabled(gmailClientID.isEmpty || isConnectingGmail)
                    .opacity(gmailClientID.isEmpty ? 0.5 : 1.0)
                }
            }
        }
    }

    // MARK: - Assistant Section

    private var assistantSection: some View {
        SettingsGlassSection(title: "Assistant", colorScheme: colorScheme) {
            VStack(spacing: 16) {
                // Display name
                HStack {
                    Label {
                        Text("Your Name")
                            .foregroundStyle(Color.primary)
                    } icon: {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color(hex: "#7C3AED"))
                    }
                    Spacer()
                    TextField("Your name", text: $settings.userName)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Color.secondary)
                        .tint(Color(hex: "#7C3AED"))
                        .onChange(of: settings.userName) { _, _ in saveSettings() }
                }

                Divider().opacity(0.3)

                // Voice toggle
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Voice Responses")
                                .foregroundStyle(Color.primary)
                            Text("Max speaks replies aloud")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                    } icon: {
                        Image(systemName: settings.voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .foregroundStyle(Color(hex: "#7C3AED"))
                    }
                    Spacer()
                    Toggle("", isOn: $settings.voiceEnabled)
                        .labelsHidden()
                        .tint(Color(hex: "#7C3AED"))
                        .onChange(of: settings.voiceEnabled) { _, _ in saveSettings() }
                }
            }
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        SettingsGlassSection(title: "Data", colorScheme: colorScheme) {
            VStack(spacing: 4) {
                SettingsActionRow(
                    icon: "trash",
                    title: "Clear Conversation History",
                    subtitle: "Remove all messages",
                    tint: Color(hex: "#EF4444")
                ) {
                    showClearConfirm = true
                }

                Divider().opacity(0.3)

                SettingsActionRow(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Sign Out",
                    subtitle: "Return to the welcome screen",
                    tint: Color(hex: "#EF4444")
                ) {
                    showSignOutConfirm = true
                }
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        SettingsGlassSection(title: "About", colorScheme: colorScheme) {
            VStack(spacing: 12) {
                SettingsInfoRow(label: "Version", value: "1.0.0")
                Divider().opacity(0.3)
                SettingsInfoRow(label: "Model", value: "Claude Sonnet 4.6")
                Divider().opacity(0.3)
                SettingsInfoRow(label: "Platform", value: "iOS")
            }
        }
    }

    // MARK: - Saved Toast

    private var savedToast: some View {
        Group {
            if savedBanner {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(hex: "#10B981"))
                    Text("Settings saved")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.primary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .glassCard(cornerRadius: 24, depth: .thin)
                .padding(.bottom, 32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: savedBanner)
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
        withAnimation {
            savedBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { savedBanner = false }
        }
    }
}

// MARK: - Settings Section Container

private struct SettingsGlassSection<Content: View>: View {
    var title: String
    var colorScheme: ColorScheme
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondary)
                .padding(.leading, 4)

            GlassCard(
                cornerRadius: 20,
                depth: colorScheme == .dark ? .thin : .ultraThin
            ) {
                content()
            }
        }
    }
}

// MARK: - Action Row

private struct SettingsActionRow: View {
    var icon: String
    var title: String
    var subtitle: String
    var tint: Color = Color(hex: "#1A1A2E")
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(tint)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Info Row

private struct SettingsInfoRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundStyle(Color.primary)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundStyle(Color.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AuthService.shared)
    }
}
