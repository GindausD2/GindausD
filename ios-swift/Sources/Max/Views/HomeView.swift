import SwiftUI
import Combine
import UIKit
import WidgetKit

enum HomePage: String, CaseIterable { case home = "Home", profile = "Profile" }

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject private var authService: AuthService
    @AppStorage("max:onboarding_complete") private var onboardingComplete: Bool = false

    @StateObject private var viewModel: HomeViewModel
    @State private var showSettings: Bool = false
    @State private var showCompanion: Bool = false
    @State private var showMemory = false
    @State private var showIsland = false
    @State private var selectedPage: HomePage
    @State private var profileRefreshID = UUID()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showHistory: Bool = false
    @State private var showCamera: Bool = false
    @State private var capturedImage: UIImage? = nil
    @State private var pendingImage: UIImage? = nil
    @Namespace private var pageSelection
    @FocusState private var composerFocused: Bool

    private let liveActivity = LiveActivityService.shared

    init(viewModel: HomeViewModel? = nil, initialPage: HomePage = .home) {
        _viewModel = StateObject(wrappedValue: viewModel ?? HomeViewModel())
        _selectedPage = State(initialValue: initialPage)
    }

    var body: some View {
        ZStack {
            CompanionCanvas()

            VStack(spacing: 0) {
                topBar
                pageSwitcher
                if authService.currentUser?.isDemo == true {
                    trialBanner
                }
                TabView(selection: $selectedPage) {
                    transcriptArea.tag(HomePage.home)
                    ProfileHubView(
                        onYourDay: { showCompanion = true },
                        onIsland: { showIsland = true },
                        onMemory: { showMemory = true },
                        onSettings: { showSettings = true },
                        refreshID: profileRefreshID
                    ).tag(HomePage.profile)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selectedPage == .home { VStack(spacing: 0) {
                if let img = pendingImage {
                    imagePendingBar(img: img)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                bottomDock
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: pendingImage != nil)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: viewModel.isDictating)
            }
        }
        .onDisappear { viewModel.endConversation() }
        .onChange(of: selectedPage) { _, page in
            composerFocused = false
            if page == .profile { viewModel.endConversation() }
        }
        .onChange(of: viewModel.isDictating) { _, active in if active { composerFocused = false } }
        .alert("Voice input unavailable", isPresented: Binding(
            get: { viewModel.dictationError != nil },
            set: { if !$0 { viewModel.dictationError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.dictationError = nil }
        } message: { Text(viewModel.dictationError ?? "Please try again.") }
        .onChange(of: authService.currentUser) { _, _ in pendingImage = nil; viewModel.endConversation(); viewModel.loadMessages() }
        .sheet(isPresented: $showCompanion) { CompanionView() }
        .sheet(isPresented: $showMemory) { MemoryView() }
        .sheet(isPresented: $showIsland) { IslandOverviewView() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { viewModel.endConversation() } }
        .onReceive(NotificationCenter.default.publisher(for: .maxQuickReply)) { notification in
            UserDefaults.standard.removeObject(forKey: "max.pendingQuickReply")
            if let prompt = notification.object as? String { selectedPage = .home; viewModel.inputText = prompt; viewModel.sendTextMessage() }
        }
        .sheet(isPresented: $showHistory) {
            ConversationHistoryView(onNewChat: {
                showHistory = false
                viewModel.startNewChat()
            })
        }
        .fullScreenCover(isPresented: $showCamera) {
            ImageSourcePicker(selectedImage: $capturedImage, isPresented: $showCamera)
                .ignoresSafeArea()
        }
        .onChange(of: capturedImage) { _, img in
            guard let img else { return }
            pendingImage = img
            capturedImage = nil
        }
        .sheet(isPresented: $showSettings, onDismiss: { profileRefreshID = UUID() }) {
            SettingsView(onClearHistory: viewModel.clearHistory)
                .environmentObject(authService)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !onboardingComplete },
            set: { if !$0 { onboardingComplete = true } }
        )) {
            OnboardingView { onboardingComplete = true }
        }
        .onAppear {
            viewModel.loadMessages()
            if selectedPage == .profile { viewModel.endConversation() }
            liveActivity.startPersistentSession()
            if UserDefaults.standard.bool(forKey: "max.pendingVoiceActivation") {
                selectedPage = .home
                UserDefaults.standard.removeObject(forKey: "max.pendingVoiceActivation")
                viewModel.activateVoice()
            }
            if UserDefaults.standard.bool(forKey: "max.pendingBriefing") {
                selectedPage = .home
                UserDefaults.standard.removeObject(forKey: "max.pendingBriefing")
                viewModel.startMorningBriefing()
            }
            if let prompt = UserDefaults.standard.string(forKey: "max.pendingQuickReply") {
                selectedPage = .home
                UserDefaults.standard.removeObject(forKey: "max.pendingQuickReply")
                viewModel.inputText = prompt; viewModel.sendTextMessage()
            }
        }
        // ── Dynamic Island ─────────────────────────────────────────────────────
        .onChange(of: viewModel.conversationState) { _, newState in
            switch newState {
            case .idle:      liveActivity.keepAlive()           // stay visible, back to standby
            case .listening: liveActivity.start()               // start / transition → listening
            case .thinking:  liveActivity.update(phase: .thinking)
            case .speaking:  liveActivity.update(phase: .speaking)
            }
        }
        .onChange(of: viewModel.streamingText) { _, text in
            guard viewModel.conversationState == .thinking || viewModel.conversationState == .speaking else { return }
            liveActivity.update(
                phase: viewModel.conversationState == .thinking ? .thinking : .speaking,
                snippet: text
            )
        }
        // Start briefing when user taps the morning notification
        .onReceive(NotificationCenter.default.publisher(for: .maxStartBriefing)) { _ in
            selectedPage = .home
            UserDefaults.standard.removeObject(forKey: "max.pendingBriefing")
            viewModel.startMorningBriefing()
        }
        // Start listening when user taps the home screen widget
        .onReceive(NotificationCenter.default.publisher(for: .maxWidgetActivate)) { _ in
            selectedPage = .home
            UserDefaults.standard.removeObject(forKey: "max.pendingVoiceActivation")
            viewModel.activateVoice()
        }
    }

    // MARK: - Trial Banner

    private var trialBanner: some View {
        let days = authService.demoTrialDaysRemaining
        let urgent = days <= 2
        return HStack(spacing: 8) {
            Image(systemName: urgent ? "exclamationmark.triangle.fill" : "clock.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(days == 0
                 ? "Your free trial has ended"
                 : days == 1
                 ? "1 day left in your free trial"
                 : "\(days) days left in your free trial")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Button {
                authService.beginDemoUpgrade()
            } label: {
                Text("Continue with Apple")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(urgent ? Color.red : Color(hex: "#315E73"),
                                in: Capsule())
            }
        }
        .foregroundStyle(urgent ? Color.red : Color(hex: "#315E73"))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            (urgent ? Color.red : Color(hex: "#315E73")).opacity(0.08)
        )
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                pendingImage = nil
                selectedPage = .home
                viewModel.startNewChat()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 44, height: 44)
                    .glassCard(cornerRadius: 22, interactive: true)
            }
            .accessibilityLabel("New conversation")

            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("Max").foregroundStyle(.primary)
                Text(".").foregroundStyle(Color(hex: "#7FB6CD"))
            }
            .font(.system(size: 27, weight: .semibold, design: .rounded))
            .tracking(-1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Max")
            Spacer()

            Button { viewModel.endConversation(); showSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 44, height: 44)
                    .glassCard(cornerRadius: 22, interactive: true)
            }
            .accessibilityLabel("Settings")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var pageSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(HomePage.allCases, id: \.self) { page in
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.85)) { selectedPage = page }
                } label: {
                    Text(page.rawValue)
                        .font(.subheadline.weight(page == selectedPage ? .semibold : .regular))
                        .foregroundStyle(page == selectedPage ? Color.primary : Color.secondary)
                        .frame(minWidth: 84, minHeight: 44)
                        .background {
                            if selectedPage == page {
                                Capsule()
                                    .fill(Color.primary.opacity(0.055))
                                    .matchedGeometryEffect(id: "page", in: pageSelection)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show \(page.rawValue)")
                .accessibilityAddTraits(page == selectedPage ? .isSelected : [])
            }
        }
        .padding(4)
        .glassCard(cornerRadius: 28, interactive: true)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - Transcript

    private var transcriptArea: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        if viewModel.messages.isEmpty {
                            emptyState(availableHeight: geometry.size.height)
                                .frame(minHeight: max(0, geometry.size.height - 24))
                                .id("empty")
                        } else {
                            ForEach(viewModel.messages) { msg in
                                TranscriptBubble(message: msg, isStreaming: msg.isStreaming)
                                    .id(msg.id)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onChange(of: viewModel.streamingText) { _, _ in
                    if let last = viewModel.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func emptyState(availableHeight: CGFloat) -> some View {
        let compact = availableHeight < 500
        return VStack(spacing: 0) {
            Spacer(minLength: compact ? 12 : 24)
            VStack(spacing: 10) {
                Text("A little space for your day.")
                    .font(.system(.title, design: .rounded).weight(.medium))
                    .tracking(-0.8)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A thought, a plan, a little help.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 26)

            Spacer(minLength: compact ? 12 : 24)
            Button { viewModel.handleOrbTap() } label: {
                OrbView(state: viewModel.orbState, size: viewModel.isDictating ? 112 : compact ? 148 : 174)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.orbAccessibilityLabel)
            .accessibilityHint(viewModel.orbAccessibilityHint)

            Button { viewModel.handleOrbTap() } label: {
                Label(viewModel.orbCaption, systemImage: viewModel.conversationState == .idle ? "speaker.wave.2" : "waveform")
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .glassCard(cornerRadius: 22, interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.orbAccessibilityLabel)
            .accessibilityHint(viewModel.orbAccessibilityHint)
            .padding(.top, 6)

            Spacer(minLength: compact ? 20 : 32)
            if !viewModel.isDictating {
                HStack(spacing: 10) {
                    draftSuggestion("Plan my day", icon: "sun.horizon")
                    draftSuggestion("Save a thought", icon: "square.and.pencil")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func draftSuggestion(_ title: String, icon: String) -> some View {
        Button {
            viewModel.inputText = title == "Save a thought" ? "Remember this: " : "Help me plan my day. "
            composerFocused = true
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .glassCard(cornerRadius: 23, interactive: true)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.conversationState != .idle || viewModel.isTranscribing)
        .accessibilityHint("Start an editable message")
    }

    // MARK: - Bottom Dock (liquid glass)

    @ViewBuilder private var bottomDock: some View {
        if viewModel.isDictating {
            VoiceToTextPanel(
                transcript: viewModel.liveTranscript,
                isPreparing: viewModel.conversationState != .listening && !viewModel.isTranscribing,
                isFinishing: viewModel.isTranscribing,
                onCancel: viewModel.endConversation,
                onDone: viewModel.handleMicTap
            )
        } else {
            regularDock
        }
    }

    private var regularDock: some View {
        VStack(spacing: 10) {
            if viewModel.conversationState != .idle || viewModel.isTranscribing {
                statusPill
                    .transition(.opacity)
            }
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Menu {
                        Button("New conversation", systemImage: "square.and.pencil") {
                            pendingImage = nil
                            viewModel.startNewChat()
                        }
                        Button("Attach a photo", systemImage: "photo") { showCamera = true }
                        Button("Conversation history", systemImage: "clock.arrow.circlepath") {
                            viewModel.endConversation(); showHistory = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 19, weight: .regular))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Conversation actions")
                    TextField("Ask Max anything…", text: $viewModel.inputText, axis: .vertical)
                        .font(.body)
                        .lineLimit(1...4)
                        .fixedSize(horizontal: false, vertical: true)
                        .focused($composerFocused)
                        .submitLabel(.send)
                        .onSubmit { viewModel.sendTextMessage() }
                        .disabled(viewModel.conversationState != .idle || viewModel.isTranscribing)
                        .accessibilityLabel("Message Max")
                    Button { viewModel.handleMicTap() } label: {
                        Image(systemName: viewModel.conversationState != .idle ? "stop.fill" : "mic.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color(UIColor.systemBackground))
                            .frame(width: 44, height: 44)
                            .background(Color.primary, in: Circle())
                    }
                    .disabled(viewModel.isTranscribing)
                    .accessibilityLabel(viewModel.conversationState != .idle ? "Stop voice or response" : "Dictate a message")
                    .accessibilityHint("Turn your voice into editable text")
                    if !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.conversationState == .idle {
                        Button { viewModel.sendTextMessage() } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color(hex: "#315E73"), in: Circle())
                        }
                        .disabled(viewModel.isTranscribing)
                        .accessibilityLabel("Send message")
                    }
                }
                if viewModel.prefersTextReplyForDraft {
                    Text("Voice draft · edit, then send")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 4)
            .padding(.trailing, 10)
            .padding(.vertical, 10)
            .glassCard(cornerRadius: 34, depth: .regular)

            floatingShortcuts
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: viewModel.conversationState)
    }

    private var floatingShortcuts: some View {
        HStack(spacing: 20) {
            Button { viewModel.endConversation(); showCompanion = true } label: {
                Label("Your day", systemImage: "square.grid.2x2")
            }
            Button { viewModel.handleOrbTap() } label: {
                Label(viewModel.conversationState == .idle ? "Hear Max" : viewModel.isDictating ? "Done" : "Stop", systemImage: viewModel.conversationState == .idle ? "speaker.wave.2" : viewModel.isDictating ? "checkmark" : "stop.fill")
            }
            .accessibilityLabel(viewModel.orbAccessibilityLabel)
            .accessibilityHint(viewModel.orbAccessibilityHint)
            Button { viewModel.startMorningBriefing() } label: {
                Label("Briefing", systemImage: "sun.horizon")
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .frame(minHeight: 44)
    }

    // MARK: - Status Pill

    private var statusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
                .shadow(color: statusColor.opacity(0.9), radius: 4)
            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.10))
                .overlay(Capsule().strokeBorder(statusColor.opacity(0.25), lineWidth: 0.5))
        )
    }

    private var statusColor: Color {
        if colorScheme == .dark { return Color(hex: "#B8E3F0") }
        if viewModel.isTranscribing { return Color(hex: "#315E73") }
        switch viewModel.conversationState {
        case .idle:      return .gray
        case .listening: return Color(hex: "#315E73")
        case .thinking:  return Color(hex: "#315E73")
        case .speaking:  return Color(hex: "#315E73")
        }
    }

    private var statusText: String {
        if viewModel.isTranscribing { return "Transcribing…" }
        switch viewModel.conversationState {
        case .idle:      return "Idle"
        case .listening: return "Listening…"
        case .thinking:  return "Thinking…"
        case .speaking:  return "Speaking…"
        }
    }

    // MARK: - Camera Button

    private var cameraButton: some View {
        Button { showCamera = true } label: {
            ZStack {
                Circle()
                    .fill(Color(white: 0.0).opacity(0.06))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle().strokeBorder(Color(white: 0.0).opacity(0.12), lineWidth: 1)
                    )
                Image(systemName: "camera.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(white: 0.30))
            }
        }
    }

    // MARK: - Image Pending Bar

    private func imagePendingBar(img: UIImage) -> some View {
        HStack(spacing: 12) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text("Send this image to Max?")
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            Button { withAnimation { pendingImage = nil } } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)

            Button {
                let img = pendingImage
                pendingImage = nil
                viewModel.sendTextMessage(image: img)
            } label: {
                Text("Send")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#315E73"), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

// MARK: - HomeViewModel

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var conversationState: ConversationState = .idle
    @Published var streamingText: String = ""
    @Published var isTranscribing: Bool = false
    @Published private(set) var isDictating = false
    @Published private(set) var liveTranscript = ""
    @Published private(set) var prefersTextReplyForDraft = false
    @Published var dictationError: String?

    private let storage = StorageService.shared
    private let claude  = ClaudeService.shared
    private let voice   = VoiceService.shared
    private let capture: any VoiceCapturing
    private var voiceSubscriptions = Set<AnyCancellable>()
    private var voiceInputTask: Task<Void, Never>?
    private var dictationBaseDraft = ""
    private var dictationScope: String?

    private var streamTask: Task<Void, Never>?
    private var speechCompletionTask: Task<Void, Never>?
    private var turnID = UUID()
    private var continuousActive = false
    private var startingVoice = false
    private var loadedScope: String?
    private var streamingMessageId: String? = nil
    private var currentConversationId: String = UUID().uuidString
    private var conversationStartedAt: Date = Date()

    init(capture: (any VoiceCapturing)? = nil) {
        let capture = capture ?? VoiceService.shared
        self.capture = capture
        capture.transcriptUpdates.sink { [weak self] text in
            guard let self, self.isDictating, self.dictationScope == self.storage.accountScope else { return }
            self.liveTranscript = text
        }.store(in: &voiceSubscriptions)
        capture.recordingUpdates.sink { [weak self] recording in
            guard let self, !recording, self.isDictating, !self.isTranscribing, self.conversationState == .listening else { return }
            // Recognition errors/interruptions must leave a usable draft, not a stuck microphone.
            self.completeDictation(self.capture.currentTranscript, expectedTurn: self.turnID, scope: self.dictationScope)
        }.store(in: &voiceSubscriptions)
    }

    var orbState: OrbState {
        switch conversationState {
        case .idle:      return .idle
        case .listening: return .listening
        case .thinking:  return .thinking
        case .speaking:  return .speaking
        }
    }

    var orbAccessibilityLabel: String {
        switch conversationState {
        case .idle: return "Hear Max"
        case .listening: return "Finish voice input"
        case .thinking: return "Stop response"
        case .speaking: return "Stop Max speaking"
        }
    }

    var orbAccessibilityHint: String {
        if isDictating { return "Finish dictation and review your message before sending" }
        return conversationState == .idle ? "Tap to hear Max. Use the microphone to dictate." : "Tap to stop"
    }

    var orbCaption: String {
        if isDictating {
            if isTranscribing { return "Finishing your voice draft…" }
            return conversationState == .listening ? "Tap the orb to finish your draft" : "Getting the microphone ready…"
        }
        return conversationState == .speaking ? "Max is speaking · tap to stop" : "Tap the orb to hear Max"
    }

    func loadMessages() {
        if loadedScope != storage.accountScope {
            inputText = ""
            prefersTextReplyForDraft = false
            currentConversationId = UUID().uuidString
            conversationStartedAt = Date()
        }
        loadedScope = storage.accountScope
        messages = storage.loadMessages()
        // If there are existing messages from a previous session, assign them a stable ID
        // so resuming an app session keeps the archive up to date.
    }

    func clearHistory() {
        endConversation()
        storage.clearMessages()
        messages = []
    }

    func startNewChat() {
        archiveCurrentConversation()
        clearHistory()
        inputText = ""
        prefersTextReplyForDraft = false
        currentConversationId = UUID().uuidString
        conversationStartedAt = Date()
    }

    private func pushToWidget(_ text: String) {
        let clean = text
            .replacingOccurrences(of: #"_Using [^_]+…_"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let def = UserDefaults(suiteName: "group.com.gindausd.max")
        def?.set(clean, forKey: "max:widget_last_message")
        def?.set(Date(), forKey: "max:widget_last_message_time")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func archiveCurrentConversation() {
        guard loadedScope == storage.accountScope else { return }
        let saveable = messages.filter { !$0.isStreaming && !$0.content.isEmpty }
        guard !saveable.isEmpty else { return }
        let firstUserText = saveable.first(where: { $0.role == "user" })?.content ?? "Conversation"
        let title = String(firstUserText.prefix(70))
        let conv = Conversation(
            id: currentConversationId,
            title: title,
            messages: saveable,
            startedAt: conversationStartedAt,
            updatedAt: Date()
        )
        storage.saveConversation(conv)
    }

    func sendTextMessage(image: UIImage? = nil) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || image != nil, conversationState == .idle, !isDictating, !isTranscribing, !startingVoice else { return }
        let allowSpeech = !prefersTextReplyForDraft
        inputText = ""
        prefersTextReplyForDraft = false
        let displayText = text.isEmpty ? "What do you see in this image?" : text
        addUserMessage(displayText)
        let imageData = image.flatMap { $0.jpegData(compressionQuality: 0.8) }
        streamResponse(userText: displayText, imageData: imageData, allowSpeech: allowSpeech)
    }

    func handleMicTap() {
        if isDictating {
            if conversationState == .listening && !isTranscribing { finishDictation() }
            return
        }
        switch conversationState {
        case .idle:                startDictation()
        case .listening:           stopListening()
        case .thinking, .speaking: stopSpeaking()
        }
    }

    func handleOrbTap() {
        if isDictating { handleMicTap(); return }
        guard !startingVoice, !isTranscribing else { return }
        guard conversationState == .idle else { handleMicTap(); return }
        continuousActive = false
        turnID = UUID()
        let reply = messages.last(where: { $0.role == "assistant" && !$0.isStreaming && !$0.content.isEmpty && !$0.content.hasPrefix("⚠️") && !$0.content.hasPrefix("Error:") })?.content
        playSpeech(reply ?? "Hi, I'm Max. I'm here. What's on your mind?")
    }

    private func playSpeech(_ text: String, continueListening: Bool = false) {
        speechCompletionTask?.cancel()
        let speechID = turnID
        let speechScope = storage.accountScope
        voice.speak(text, preferredVoice: storage.loadSettings().preferredVoice)
        guard voice.isSpeaking else { conversationState = .idle; return }
        conversationState = .speaking
        speechCompletionTask = Task { [weak self] in
            guard let self else { return }
            while self.voice.isSpeaking {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
            }
            guard self.turnID == speechID, self.storage.accountScope == speechScope, !Task.isCancelled else { return }
            self.conversationState = .idle
            if continueListening, self.continuousActive, UIApplication.shared.applicationState == .active { self.startListening() }
        }
    }

    func activateVoice() {
        guard conversationState == .idle, !isTranscribing, !isDictating else { return }
        startListening()
    }

    func sendPlacesQuery() {
        guard conversationState == .idle, !isDictating, !startingVoice, !isTranscribing else { return }
        let query = "What interesting places are near me right now?"
        addUserMessage(query)
        streamResponse(userText: query, imageData: nil)
    }

    func startMorningBriefing() {
        guard conversationState == .idle, !isDictating, !startingVoice, !isTranscribing else { return }
        conversationState = .thinking
        let briefingID = UUID(); turnID = briefingID
        let scope = storage.accountScope
        streamTask = Task {
            let snapshot = await BriefingService.shared.snapshot()
            guard turnID == briefingID, !Task.isCancelled, storage.accountScope == scope else { return }
            conversationState = .idle
            addUserMessage("Good morning — give me my daily briefing.")
            if kMaxAPIBaseURL.isEmpty {
                messages.append(Message(role: "assistant", content: snapshot))
                storage.saveMessages(messages)
                archiveCurrentConversation()
                if storage.loadSettings().voiceEnabled { playSpeech(snapshot) }
            } else { streamResponse(userText: "Summarize this verified snapshot warmly. Do not invent missing sources.\n" + snapshot) }
        }
    }

    func endConversation() {
        continuousActive = false
        turnID = UUID()
        voiceInputTask?.cancel(); voiceInputTask = nil
        isDictating = false
        liveTranscript = ""
        dictationScope = nil
        streamTask?.cancel(); streamTask = nil
        speechCompletionTask?.cancel(); speechCompletionTask = nil
        voice.stopSpeaking(); capture.stopRecording()
        isTranscribing = false
        streamingText = ""
        messages.removeAll { $0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        for index in messages.indices { messages[index].isStreaming = false }
        streamingMessageId = nil
        conversationState = .idle
        if loadedScope == storage.accountScope { storage.saveMessages(messages) }
    }

    private func startDictation() {
        guard !startingVoice, !isTranscribing else { return }
        continuousActive = false
        capture.onUtteranceEnd = nil
        dictationError = nil
        dictationBaseDraft = inputText
        dictationScope = storage.accountScope
        liveTranscript = ""
        isDictating = true
        startingVoice = true
        let activationID = UUID(); turnID = activationID
        let scope = storage.accountScope
        voiceInputTask = Task { [weak self] in
            guard let self else { return }
            defer { self.startingVoice = false }
            do {
                try await self.capture.startRecording()
                guard self.turnID == activationID, self.storage.accountScope == scope, !Task.isCancelled else { self.capture.stopRecording(); return }
                self.conversationState = .listening
            } catch {
                guard self.turnID == activationID, self.storage.accountScope == scope, !(error is CancellationError) else { return }
                self.isDictating = false
                self.liveTranscript = ""
                self.dictationScope = nil
                self.dictationError = error.localizedDescription
            }
        }
    }

    private func finishDictation() {
        isTranscribing = true
        let finishingID = turnID
        let scope = dictationScope
        voiceInputTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.capture.stopAndTranscribe()
            guard !Task.isCancelled else { return }
            self.completeDictation(result, expectedTurn: finishingID, scope: scope)
        }
    }

    private func completeDictation(_ result: String?, expectedTurn: UUID, scope: String?) {
        guard isDictating, turnID == expectedTurn else { return }
        isDictating = false
        isTranscribing = false
        conversationState = .idle
        liveTranscript = ""
        dictationScope = nil
        guard scope == storage.accountScope else { inputText = ""; prefersTextReplyForDraft = false; return }
        let text = result?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { dictationError = "Couldn't catch that. Your draft is still here — try again."; return }
        inputText = dictationBaseDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText += (inputText.isEmpty ? "" : " ") + text
        prefersTextReplyForDraft = true
    }

    private func startListening() {
        guard !startingVoice, !isTranscribing else { return }
        startingVoice = true
        let activationID = turnID
        Task {
            defer { startingVoice = false }
            do {
                continuousActive = storage.loadSettings().continuousConversation ?? false
                capture.onUtteranceEnd = { [weak self] in
                    guard let self, self.continuousActive, self.conversationState == .listening else { return }
                    self.stopListening()
                }
                try await capture.startRecording()
                guard turnID == activationID else { capture.stopRecording(); return }
                conversationState = .listening
            } catch {
                guard turnID == activationID, !(error is CancellationError) else { return }
                conversationState = .idle
                addSystemError(error.localizedDescription)
            }
        }
    }

    private func stopListening() {
        guard conversationState == .listening else { return }
        conversationState = .idle
        isTranscribing = true
        let listeningID = turnID
        Task {
            let transcription = await capture.stopAndTranscribe()
            guard turnID == listeningID else { return }
            isTranscribing = false
            guard let transcription, !transcription.isEmpty else {
                addSystemError("Couldn't catch that — please try again.")
                return
            }
            addUserMessage(transcription)
            streamResponse(userText: transcription, imageData: nil)
        }
    }

    private func stopSpeaking() { endConversation() }

    private func addUserMessage(_ text: String) {
        let msg = Message(role: "user", content: text)
        messages.append(msg)
        storage.saveMessages(messages)
    }

    private func addSystemError(_ text: String) {
        let msg = Message(role: "assistant", content: "⚠️ \(text)")
        messages.append(msg)
        storage.saveMessages(messages)
    }

    private func streamResponse(userText: String, imageData: Data? = nil, allowSpeech: Bool = true) {
        let settings = storage.loadSettings()
        let thisTurn = UUID(); turnID = thisTurn
        conversationState = .thinking

        let streamId = UUID().uuidString
        streamingMessageId = streamId
        messages.append(Message(id: streamId, role: "assistant", content: "", isStreaming: true))

        var fullText = ""

        // Keep the last 40 messages (20 exchanges) to stay within token limits
        let history = messages.filter { $0.id != streamId && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var trimmed = history.count > 40 ? Array(history.suffix(40)) : history
        if let index = trimmed.lastIndex(where: { $0.role == "user" }) { trimmed[index].content = userText }

        streamTask = claude.streamMessage(
            messages: trimmed,
            imageData: imageData
        ) { [weak self] chunk in
            Task { @MainActor [weak self] in
                guard let self = self, self.turnID == thisTurn, self.loadedScope == self.storage.accountScope else { return }
                switch chunk {
                case .text(let text):
                    fullText += text
                    self.streamingText = fullText
                    if let idx = self.messages.firstIndex(where: { $0.id == streamId }) {
                        self.messages[idx].content = fullText
                        self.messages[idx].isStreaming = true
                    }
                case .toolStart(let name):
                    if let idx = self.messages.firstIndex(where: { $0.id == streamId }) {
                        self.messages[idx].content = fullText + (fullText.isEmpty ? "" : "\n") + "_Using \(name)…_"
                        self.messages[idx].isStreaming = true
                    }
                case .toolDone:
                    if let idx = self.messages.firstIndex(where: { $0.id == streamId }) {
                        self.messages[idx].content = fullText
                    }
                case .done:
                    if let idx = self.messages.firstIndex(where: { $0.id == streamId }) {
                        self.messages[idx].content = fullText
                        self.messages[idx].isStreaming = false
                    }
                    self.streamingMessageId = nil
                    self.streamingText = ""
                    self.storage.saveMessages(self.messages)
                    self.archiveCurrentConversation()
                    self.pushToWidget(fullText)
                    if allowSpeech && settings.voiceEnabled && !fullText.isEmpty {
                        self.playSpeech(fullText, continueListening: true)
                    } else {
                        self.conversationState = .idle
                    }
                case .error(let errText):
                    self.continuousActive = false
                    if let idx = self.messages.firstIndex(where: { $0.id == streamId }) {
                        self.messages[idx].content = fullText.isEmpty ? "Error: \(errText)" : fullText + "\n\nReply interrupted: " + errText
                        self.messages[idx].isStreaming = false
                    }
                    self.streamingMessageId = nil
                    self.streamingText = ""
                    self.conversationState = .idle
                    self.storage.saveMessages(self.messages)
                }
            }
        }
    }
}

#Preview {
    HomeView().environmentObject(AuthService.shared)
}
