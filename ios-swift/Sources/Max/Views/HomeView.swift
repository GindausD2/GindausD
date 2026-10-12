import SwiftUI
import Combine
import UIKit
import WidgetKit

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject private var authService: AuthService
    @AppStorage("max:onboarding_complete") private var onboardingComplete: Bool = false

    @StateObject private var viewModel = HomeViewModel()
    @State private var showSettings: Bool = false
    @State private var showCompanion: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var showHistory: Bool = false
    @State private var showCamera: Bool = false
    @State private var capturedImage: UIImage? = nil
    @State private var pendingImage: UIImage? = nil

    private let liveActivity = LiveActivityService.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Liquid glass background ───────────────────────────────────────
            LinearGradient(
                stops: [
                    .init(color: Color(red: 1.00, green: 1.00, blue: 1.00), location: 0.0),
                    .init(color: Color(hex: "#F4F1EB"), location: 0.5),
                    .init(color: Color(hex: "#DCE4DA"), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                if authService.currentUser?.isDemo == true {
                    trialBanner
                }
                transcriptArea
                    .padding(.bottom, 215) // space for voice and text controls
            }

            // ── Image preview bar ──────────────────────────────────────────────
            VStack(spacing: 0) {
                Spacer()
                if let img = pendingImage {
                    imagePendingBar(img: img)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                // ── Floating glass dock ────────────────────────────────────────
                bottomDock
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: pendingImage != nil)
        }
        .onDisappear { viewModel.endConversation() }
        .onChange(of: authService.currentUser) { _, _ in viewModel.endConversation(); viewModel.loadMessages() }
        .sheet(isPresented: $showCompanion) { CompanionView() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { viewModel.endConversation() } }
        .onReceive(NotificationCenter.default.publisher(for: .maxQuickReply)) { notification in
            UserDefaults.standard.removeObject(forKey: "max.pendingQuickReply")
            if let prompt = notification.object as? String { viewModel.inputText = prompt; viewModel.sendTextMessage() }
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
        .sheet(isPresented: $showSettings) {
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
            liveActivity.startPersistentSession()
            if UserDefaults.standard.bool(forKey: "max.pendingVoiceActivation") {
                UserDefaults.standard.removeObject(forKey: "max.pendingVoiceActivation")
                viewModel.activateVoice()
            }
            if UserDefaults.standard.bool(forKey: "max.pendingBriefing") {
                UserDefaults.standard.removeObject(forKey: "max.pendingBriefing")
                viewModel.startMorningBriefing()
            }
            if let prompt = UserDefaults.standard.string(forKey: "max.pendingQuickReply") {
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
            UserDefaults.standard.removeObject(forKey: "max.pendingBriefing")
            viewModel.startMorningBriefing()
        }
        // Start listening when user taps the home screen widget
        .onReceive(NotificationCenter.default.publisher(for: .maxWidgetActivate)) { _ in
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
                authService.signOut()   // clears demo → WelcomeView shows plan page
            } label: {
                Text("Subscribe")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(urgent ? Color.red : Color(hex: "#596F60"),
                                in: Capsule())
            }
        }
        .foregroundStyle(urgent ? Color.red : Color(hex: "#596F60"))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            (urgent ? Color.red : Color(hex: "#596F60")).opacity(0.08)
        )
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Settings
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Logo
            MaxLogoView(color: Color.primary, width: 54)

            Spacer()

            // Conversation history
            Button { showHistory = true } label: {
                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassCard(cornerRadius: 28)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Transcript

    private var transcriptArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    if viewModel.messages.isEmpty {
                        emptyState.id("empty")
                    } else {
                        ForEach(viewModel.messages) { msg in
                            TranscriptBubble(message: msg, isStreaming: msg.isStreaming)
                                .id(msg.id)
                        }
                    }
                }
                .padding(.vertical, 14)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: viewModel.streamingText) { _, _ in
                if let last = viewModel.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            OrbView(state: .idle, size: 90)
            Text("Make room for\nwhat matters.")
                .font(.system(size: 38, weight: .regular, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.primary)
            Text("A thought, a plan, a little help.\nStart wherever you are.")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 40)
    }

    // MARK: - Bottom Dock (liquid glass)

    private var bottomDock: some View {
        VStack(spacing: 0) {
            // Status pill
            if viewModel.conversationState != .idle || viewModel.isTranscribing {
                statusPill
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 12) {
                TextField("Ask Max anything…", text: $viewModel.inputText)
                    .font(.body)
                    .submitLabel(.send)
                    .onSubmit { viewModel.sendTextMessage() }
                    .disabled(viewModel.conversationState != .idle)
                    .accessibilityLabel("Message Max")
                Button { viewModel.sendTextMessage() } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "#292D2B"), in: Circle())
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.conversationState != .idle)
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            // Main dock row
            HStack(spacing: 0) {
                // Places memory
                placesButton
                    .frame(maxWidth: .infinity)

                // Orb (voice) — centre
                Button { viewModel.handleOrbTap() } label: {
                    OrbView(state: viewModel.orbState, size: 84)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.conversationState == .listening ? "Finish voice input" : "Talk to Max")
                .frame(maxWidth: .infinity)

                // Camera (vision)
                Button { viewModel.startMorningBriefing() } label: {
                    Image(systemName: "sun.horizon")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 50, height: 50)
                }
                .accessibilityLabel("Morning briefing")
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 20)
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.conversationState != .idle {
                Button { viewModel.endConversation() } label: {
                    Image(systemName: "stop.circle.fill").font(.system(size: 24)).foregroundStyle(Color.secondary)
                }.accessibilityLabel("End conversation").padding(8)
            }
        }
        .glassCard(cornerRadius: 36, depth: .regular)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.conversationState)
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
        if viewModel.isTranscribing { return Color(red: 0.95, green: 0.60, blue: 0.11) }
        switch viewModel.conversationState {
        case .idle:      return .gray
        case .listening: return Color(red: 0.94, green: 0.27, blue: 0.27)
        case .thinking:  return Color(hex: "#596F60")
        case .speaking:  return Color(hex: "#596F60")
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

    // MARK: - Places Button

    private var placesButton: some View {
        Button {
            viewModel.sendPlacesQuery()
        } label: {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(Color.secondary)
                .frame(width: 44, height: 44)
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
                    .background(Color(hex: "#596F60"), in: Capsule())
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

    private let storage = StorageService.shared
    private let claude  = ClaudeService.shared
    private let voice   = VoiceService.shared

    private var streamTask: Task<Void, Never>?
    private var turnID = UUID()
    private var continuousActive = false
    private var startingVoice = false
    private var loadedScope: String?
    private var streamingMessageId: String? = nil
    private var currentConversationId: String = UUID().uuidString
    private var conversationStartedAt: Date = Date()

    var orbState: OrbState {
        switch conversationState {
        case .idle:      return .idle
        case .listening: return .listening
        case .thinking:  return .thinking
        case .speaking:  return .speaking
        }
    }

    func loadMessages() {
        if loadedScope != storage.accountScope {
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
        guard !text.isEmpty || image != nil, conversationState == .idle else { return }
        inputText = ""
        let displayText = text.isEmpty ? "What do you see in this image?" : text
        addUserMessage(displayText)
        let imageData = image.flatMap { $0.jpegData(compressionQuality: 0.8) }
        streamResponse(userText: displayText, imageData: imageData)
    }

    func handleMicTap() {
        switch conversationState {
        case .idle:                startListening()
        case .listening:           stopListening()
        case .thinking, .speaking: stopSpeaking()
        }
    }

    func handleOrbTap() { handleMicTap() }

    func activateVoice() {
        guard conversationState == .idle, !isTranscribing else { return }
        startListening()
    }

    func sendPlacesQuery() {
        guard conversationState == .idle else { return }
        let query = "What interesting places are near me right now?"
        addUserMessage(query)
        streamResponse(userText: query, imageData: nil)
    }

    func startMorningBriefing() {
        guard conversationState == .idle else { return }
        conversationState = .thinking
        let briefingID = UUID(); turnID = briefingID
        let scope = storage.accountScope
        streamTask = Task {
            let snapshot = await BriefingService.shared.snapshot()
            guard turnID == briefingID, !Task.isCancelled, storage.accountScope == scope else { return }
            conversationState = .idle
            addUserMessage("Good morning — give me my daily briefing.")
            if kMaxAPIBaseURL.isEmpty || AuthService.shared.currentUser?.isDemo == true {
                messages.append(Message(role: "assistant", content: snapshot))
                storage.saveMessages(messages)
                archiveCurrentConversation()
                if storage.loadSettings().voiceEnabled { voice.speak(snapshot, preferredVoice: storage.loadSettings().preferredVoice) }
            } else { streamResponse(userText: "Summarize this verified snapshot warmly. Do not invent missing sources.\n" + snapshot) }
        }
    }

    func endConversation() {
        continuousActive = false
        turnID = UUID()
        streamTask?.cancel(); streamTask = nil
        voice.stopSpeaking(); voice.stopRecording()
        isTranscribing = false
        for index in messages.indices { messages[index].isStreaming = false }
        streamingMessageId = nil
        conversationState = .idle
        if loadedScope == storage.accountScope { storage.saveMessages(messages) }
    }

    private func startListening() {
        guard !startingVoice, !isTranscribing else { return }
        startingVoice = true
        let activationID = turnID
        Task {
            defer { startingVoice = false }
            do {
                continuousActive = storage.loadSettings().continuousConversation ?? false
                voice.onUtteranceEnd = { [weak self] in
                    guard let self, self.continuousActive, self.conversationState == .listening else { return }
                    self.stopListening()
                }
                try await voice.startRecording()
                guard turnID == activationID else { voice.stopRecording(); return }
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
            let transcription = await voice.stopAndTranscribe()
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

    private func streamResponse(userText: String, imageData: Data? = nil) {
        let settings = storage.loadSettings()
        let thisTurn = UUID(); turnID = thisTurn
        conversationState = .thinking

        let streamId = UUID().uuidString
        streamingMessageId = streamId
        messages.append(Message(id: streamId, role: "assistant", content: "", isStreaming: true))

        var fullText = ""

        // Keep the last 40 messages (20 exchanges) to stay within token limits
        let history = messages.filter { $0.id != streamId }
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
                    if settings.voiceEnabled && !fullText.isEmpty {
                        self.conversationState = .speaking
                        self.voice.speak(fullText, preferredVoice: settings.preferredVoice)
                        Task {
                            while self.voice.isSpeaking {
                                try? await Task.sleep(nanoseconds: 200_000_000)
                            }
                            guard self.turnID == thisTurn else { return }
                            self.conversationState = .idle
                            if self.continuousActive, UIApplication.shared.applicationState == .active { self.startListening() }
                        }
                    } else {
                        self.conversationState = .idle
                    }
                case .error(let errText):
                    self.continuousActive = false
                    if let idx = self.messages.firstIndex(where: { $0.id == streamId }) {
                        if fullText.isEmpty { self.messages[idx].content = "Error: \(errText)" }
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
