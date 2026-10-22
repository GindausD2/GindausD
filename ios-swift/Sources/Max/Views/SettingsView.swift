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
    @State private var showEmailConfig: Bool = false
    @State private var showDeviceLink: Bool = false
    @State private var showBriefing: Bool = false
    @State private var showAssistant: Bool = false
    @State private var showAppearance: Bool = false
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var profileImage: UIImage? = nil

    private let storage = StorageService.shared

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            CompanionCanvas()

            VStack(spacing: 0) {
                // ── Handle + header ───────────────────────────────────────────
                sheetHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // ── Avatar + name + plan ──────────────────────────────
                        profileHeader

                        // ── QUICK ACTIONS ─────────────────────────────────────
                        ProfileSection(title: "QUICK ACTIONS") {
                            ProfileRow(icon: "brain", iconColor: Color(hex: "#315E73"),
                                       title: "Memory") { showMemory = true }
                            Divider().padding(.leading, 56)
                            ProfileRow(icon: "lock.fill", iconColor: Color(hex: "#6B7280"),
                                       title: "Privacy") { showPrivacy = true }
                            Divider().padding(.leading, 56)
                            ProfileRow(icon: "creditcard", iconColor: Color(hex: "#315E73"),
                                       title: "Subscription") { showSubscription = true }
                        }

                        // ── CONFIGURATION ─────────────────────────────────────
                        ProfileSection(title: "CONFIGURATION") {
                            ProfileRow(icon: "sun.horizon.fill", iconColor: Color(hex: "#F59E0B"),
                                       title: "Morning Briefing") { showBriefing = true }
                            Divider().padding(.leading, 56)
                            ProfileRow(icon: "envelope.fill", iconColor: Color(hex: "#315E73"),
                                       title: "Email Reminders") { showEmailConfig = true }
                            Divider().padding(.leading, 56)
                            ProfileRow(icon: "person.fill", iconColor: Color(hex: "#315E73"),
                                       title: "Assistant") { showAssistant = true }
                            Divider().padding(.leading, 56)
                            ProfileRow(icon: "circle.lefthalf.filled", iconColor: Color(hex: "#6B7280"),
                                       title: "Appearance") { showAppearance = true }
                            Divider().padding(.leading, 56)
                            ProfileRow(icon: "link", iconColor: Color(hex: "#315E73"),
                                       title: "Device Link") { showDeviceLink = true }
                        }

                        // ── ABOUT ─────────────────────────────────────────────
                        ProfileSection(title: "ABOUT") {
                            ProfileRow(icon: "questionmark.circle.fill", iconColor: Color(hex: "#315E73"),
                                       title: "Help Center") {
                                UIApplication.shared.open(URL(string: "mailto:support@getmax.app")!)
                            }
                            Divider().padding(.leading, 56)
                            ProfileRow(icon: "doc.text.fill", iconColor: Color(hex: "#6B7280"),
                                       title: "AI Provider Policies") {
                                UIApplication.shared.open(URL(string: "https://openai.com/policies/")!)
                            }
                            Divider().padding(.leading, 56)
                            ProfileRow(icon: "lock.shield.fill", iconColor: Color(hex: "#6B7280"),
                                       title: "AI Data Handling") {
                                UIApplication.shared.open(URL(string: "https://developers.openai.com/api/docs/guides/your-data")!)
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
                                        guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                                              let data = credential.identityToken,
                                              let token = String(data: data, encoding: .utf8) else {
                                            authService.authError = "Apple sign-in couldn't complete. Please try again."
                                            return
                                        }
                                        let name = [credential.fullName?.givenName,
                                                    credential.fullName?.familyName]
                                            .compactMap { $0 }.joined(separator: " ")
                                        Task {
                                            await authService.signInWithApple(
                                                idToken: token,
                                                name: name.isEmpty ? nil : name
                                            )
                                            if authService.currentUser?.isDemo != true { dismiss() }
                                        }
                                    case .failure(let error): authService.authError = error.localizedDescription
                                    }
                                })
                                .signInWithAppleButtonStyle(.black)
                                .frame(height: 50)
                                .cornerRadius(12)

                                if let error = authService.authError { Text(error).font(.footnote).foregroundStyle(.red) }
                                Text("Continue with Apple to keep this guest account. Your notes stay on this iPhone.")
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
        .presentationCornerRadius(34).presentationDragIndicator(.hidden)
        // ── Destination sheets ────────────────────────────────────────────────
        .sheet(isPresented: $showSubscription) { SubscriptionSheet() }
        .sheet(isPresented: $showMemory)       { MemoryView() }
        .sheet(isPresented: $showPrivacy)      { PrivacySheet(settings: $settings, onSave: saveSettings) }
        .sheet(isPresented: $showIslandDebug)  { IslandDebugSheet() }
        .sheet(isPresented: $showEmailConfig)  { EmailConfigSheet() }
        .sheet(isPresented: $showAssistant)    { AssistantSheet(settings: $settings, onSave: saveSettings) }
        .sheet(isPresented: $showAppearance)   { AppearanceSheet(appearance: $appearance, settings: $settings, onSave: saveSettings) }
        .sheet(isPresented: $showDeviceLink)   { DeviceLinkView() }
        .sheet(isPresented: $showBriefing)     { BriefingSheet(settings: $settings, onSave: saveSettings) }
        .confirmationDialog("Clear all messages?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear History", role: .destructive) { onClearHistory?(); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone.") }
        .confirmationDialog("Sign out of Max?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { authService.signOut(); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Signing out stops voice and cancels scheduled notifications on this iPhone. Your saved notes and conversations stay with your account.") }
        .onAppear {
            profileImage = storage.loadProfilePhoto()
        }
    }

    // MARK: - Sheet Header

    private var sheetHeader: some View {
        CompanionSheetHeader(title: "Settings", onClose: { dismiss() })
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
                        storage.saveProfilePhoto(img)
                    }
                }
            }

            // Name
            Text(displayName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            // Plan badge
            let subscribed = StoreKitService.shared.isSubscribed
            HStack(spacing: 4) {
                Image(systemName: subscribed ? "crown.fill" : "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text(subscribed ? "Max Pro" : "7-day demo")
                    .font(.subheadline)
            }
            .foregroundStyle(subscribed ? Color(hex: "#F59E0B") : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private var displayName: String {
        if !settings.userName.isEmpty { return settings.userName }
        if let name = authService.currentUser?.name, !name.isEmpty { return name }
        if authService.currentUser?.isDemo == true { return "Guest" }
        return "Guest"
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
            .glassCard(cornerRadius: 24, depth: .regular)
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
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = StoreKitService.shared
    var body: some View {
        NavigationStack {
            ZStack {
                CompanionCanvas()
                if authService.currentUser?.isDemo == true {
                    VStack(spacing: 20) {
                        MaxLogoView(color: .primary, width: 84)
                        Text("Your seven-day demo").font(.title2.weight(.semibold))
                        Text("No payment is needed during your demo. Continue with Apple when you’re ready to subscribe.")
                        Button("Continue with Apple") { authService.beginDemoUpgrade(); dismiss() }
                    }.multilineTextAlignment(.center).padding(24)
                } else if store.isSubscribed {
                    VStack(spacing: 20) {
                        MaxLogoView(color: .primary, width: 84)
                        Text("Your Max subscription is active").font(.title2.weight(.semibold))
                        Link("Manage subscription", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                        Button("Restore Purchases") { Task { await store.restorePurchases() } }
                            .disabled(store.isLoading)
                        if let error = store.purchaseError { Text(error).font(.footnote).foregroundStyle(.secondary) }
                    }
                    .multilineTextAlignment(.center).padding(24)
                } else {
                    PlanPage(onBack: { dismiss() })
                }
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
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
                        .tint(Color(hex: "#315E73"))
                        .onChange(of: settings.shareAnalytics) { _, _ in onSave() }
                    Toggle("Personalised suggestions", isOn: $settings.personalisedSuggestions)
                        .tint(Color(hex: "#315E73"))
                        .onChange(of: settings.personalisedSuggestions) { _, _ in onSave() }
                } header: { Text("Data Usage") }
                Section {
                    Text("When you send a message, Max sends the conversation and relevant saved context to OpenAI through Max's server. Notes and history remain stored on this device. See AI Data Handling for the provider's retention controls.")
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
                .tint(Color(hex: "#315E73"))

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

private struct EmailConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var clientID: String = EmailMonitorService.shared.clientID
    @State private var isConnecting: Bool = false
    @State private var connectError: String? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(clientID.isEmpty ? "Email connection is coming soon." : "Connect your account to receive important email reminders.")
                        .foregroundStyle(.secondary)
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
                            .tint(Color(hex: "#315E73"))
                            .onChange(of: settings.userName) { _, _ in onSave() }
                    }
                    Toggle(isOn: $settings.voiceEnabled) {
                        Label("Voice Responses", systemImage: "speaker.wave.2.fill")
                    }
                    .tint(Color(hex: "#315E73"))
                    .onChange(of: settings.voiceEnabled) { _, _ in onSave() }

                    Toggle("Speaking haptics", isOn: Binding(get: { settings.speakingHapticsEnabled ?? true }, set: { settings.speakingHapticsEnabled = $0; onSave() }))
                        .tint(Color(hex: "#78B5CD"))
                    Text("Gentle pulses while Max speaks. Tap the orb to hear Max, and tap again to stop.")
                        .font(.caption).foregroundStyle(.secondary)

                    Toggle("Continuous conversation", isOn: Binding(get: { settings.continuousConversation ?? false }, set: { settings.continuousConversation = $0; onSave() }))
                        .tint(Color(hex: "#78B5CD"))
                    Text("When enabled, Max listens again after a spoken reply while this app is open. Tap the stop control to end the conversation.")
                        .font(.caption).foregroundStyle(.secondary)
                    if settings.voiceEnabled {
                        Picker("Spoken replies", selection: Binding(get: { settings.voiceProvider ?? "openai" }, set: { settings.voiceProvider = $0; onSave() })) {
                            Text("OpenAI voice").tag("openai")
                            Text("iPhone voice").tag("device")
                        }
                        if (settings.voiceProvider ?? "openai") == "openai" {
                            Picker("Voice style", selection: Binding(get: { settings.openAIVoice ?? "marin" }, set: { settings.openAIVoice = $0; onSave() })) {
                                Text("Marin").tag("marin")
                                Text("Cedar").tag("cedar")
                            }
                            Text("Max’s voice is AI-generated. Spoken text is sent to OpenAI. Up to 3,000 characters per UTC day; longer replies and unavailable voice use your iPhone voice.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Picker(selection: $settings.preferredVoice) {
                            Text("Female").tag("female")
                            Text("Male").tag("male")
                        } label: {
                            Label("iPhone fallback voice", systemImage: "waveform")
                        }
                        .tint(Color(hex: "#315E73"))
                        .onChange(of: settings.preferredVoice) { _, _ in onSave() }
                    }
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

// MARK: - BriefingSheet

private struct BriefingSheet: View {
    @Binding var settings: AppSettings
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    // Local date for the time picker
    @State private var briefingTime: Date

    init(settings: Binding<AppSettings>, onSave: @escaping () -> Void) {
        _settings = settings
        self.onSave = onSave
        var dc = DateComponents()
        dc.hour   = settings.wrappedValue.briefingHour
        dc.minute = settings.wrappedValue.briefingMinute
        _briefingTime = State(initialValue: Calendar.current.date(from: dc) ?? Date())
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $settings.briefingEnabled) {
                        Label("Daily Briefing", systemImage: "sun.horizon.fill")
                    }
                    .onChange(of: settings.briefingEnabled) { _, enabled in
                        onSave()
                        if enabled {
                            BriefingService.shared.schedule(
                                hour: settings.briefingHour,
                                minute: settings.briefingMinute
                            )
                        } else {
                            BriefingService.shared.cancel()
                        }
                    }
                } footer: {
                    Text("Max sends a morning notification. Tap it to hear your available calendar, weather, and reminder summary. This is not a system alarm. Gmail must be connected for email counts. Missed-call history is not available to Max.")
                }

                if settings.briefingEnabled {
                    Section {
                        DatePicker(
                            "Briefing Time",
                            selection: $briefingTime,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: briefingTime) { _, date in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                            settings.briefingHour   = comps.hour   ?? 8
                            settings.briefingMinute = comps.minute ?? 0
                            onSave()
                            BriefingService.shared.schedule(
                                hour: settings.briefingHour,
                                minute: settings.briefingMinute
                            )
                        }
                    } header: {
                        Text("Delivery Time")
                    } footer: {
                        let h = settings.briefingHour
                        let m = settings.briefingMinute
                        let label = String(format: "%d:%02d %@",
                                          h % 12 == 0 ? 12 : h % 12, m, h < 12 ? "AM" : "PM")
                        Text("Your briefing will arrive every day at \(label).")
                    }

                    Section {
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                NotificationCenter.default.post(name: .maxStartBriefing, object: nil)
                            }
                        } label: {
                            Label("Run Briefing Now", systemImage: "play.circle.fill")
                        }
                    } footer: {
                        Text("Test your briefing immediately.")
                    }
                }
            }
            .navigationTitle("Morning Briefing")
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
