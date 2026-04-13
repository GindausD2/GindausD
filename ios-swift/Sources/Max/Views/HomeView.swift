import SwiftUI
import Combine

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject private var authService: AuthService

    @StateObject private var viewModel = HomeViewModel()
    @State private var showSettings: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            transcriptArea
            bottomBar
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showSettings) {
            SettingsView(onClearHistory: viewModel.clearHistory)
                .environmentObject(authService)
        }
        .onAppear {
            viewModel.loadMessages()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                viewModel.startNewChat()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .frame(width: 40, height: 40)
            }

            Spacer()

            Text("Max")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primary)

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Divider(),
            alignment: .bottom
        )
    }

    // MARK: - Transcript Area

    private var transcriptArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    if viewModel.messages.isEmpty {
                        emptyState
                            .id("empty")
                    } else {
                        ForEach(viewModel.messages) { message in
                            TranscriptBubble(
                                message: message,
                                isStreaming: message.isStreaming
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.streamingText) { _, _ in
                if let last = viewModel.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            OrbView(state: .idle, size: 72)
            Text("Hi! I'm Max")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Tap the mic to start talking,\nor type a message")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 40)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            // Status indicator bar
            statusBar

            VStack(spacing: 16) {
                // Clock
                ClockView()

                // Orb
                OrbView(state: viewModel.orbState, size: 128)
                    .onTapGesture {
                        viewModel.handleOrbTap()
                    }

                // Mic button + text input
                inputRow
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .overlay(
            Divider(),
            alignment: .top
        )
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusColor.opacity(0.6), radius: 4)
            Text(statusText)
                .font(.caption.weight(.medium))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(statusColor.opacity(0.08))
        .animation(.easeInOut(duration: 0.3), value: viewModel.conversationState)
    }

    private var statusColor: Color {
        switch viewModel.conversationState {
        case .idle: return Color.secondary
        case .listening: return Color.red
        case .thinking: return Color(hex: "#7C3AED")
        case .speaking: return Color(hex: "#4F46E5")
        }
    }

    private var statusText: String {
        switch viewModel.conversationState {
        case .idle: return "Idle"
        case .listening: return "Listening..."
        case .thinking: return "Thinking..."
        case .speaking: return "Speaking..."
        }
    }

    private var inputRow: some View {
        HStack(spacing: 12) {
            // Text input field
            HStack {
                TextField("Message Max...", text: $viewModel.inputText, axis: .vertical)
                    .font(.body)
                    .lineLimit(1...4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .onSubmit {
                        viewModel.sendTextMessage()
                    }

                if !viewModel.inputText.isEmpty {
                    Button {
                        viewModel.sendTextMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color(hex: "#7C3AED"))
                    }
                    .padding(.trailing, 8)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.inputText.isEmpty)

            // Mic button
            Button {
                viewModel.handleMicTap()
            } label: {
                ZStack {
                    Circle()
                        .fill(micButtonColor)
                        .frame(width: 48, height: 48)
                        .shadow(color: micButtonColor.opacity(0.4), radius: 8, y: 3)

                    Image(systemName: viewModel.conversationState == .listening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .scaleEffect(viewModel.conversationState == .listening ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.conversationState)
        }
    }

    private var micButtonColor: Color {
        switch viewModel.conversationState {
        case .listening: return Color.red
        case .thinking, .speaking: return Color.gray
        default: return Color(hex: "#7C3AED")
        }
    }
}

// MARK: - Clock View

private struct ClockView: View {
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: now)
    }

    var body: some View {
        Text(timeString)
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.secondary)
            .monospacedDigit()
            .onReceive(timer) { date in
                now = date
            }
    }
}

// MARK: - HomeViewModel

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var conversationState: ConversationState = .idle
    @Published var streamingText: String = ""

    private let storage = StorageService.shared
    private let claude = ClaudeService.shared
    private let voice = VoiceService.shared

    private var streamingMessageId: String? = nil
    private var cancellables = Set<AnyCancellable>()

    var orbState: OrbState {
        switch conversationState {
        case .idle: return .idle
        case .listening: return .listening
        case .thinking: return .thinking
        case .speaking: return .speaking
        }
    }

    // MARK: - Lifecycle

    func loadMessages() {
        messages = storage.loadMessages()
    }

    func clearHistory() {
        storage.clearMessages()
        messages = []
    }

    func startNewChat() {
        clearHistory()
    }

    // MARK: - Input Handling

    func sendTextMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, conversationState == .idle else { return }
        inputText = ""
        addUserMessage(text)
        streamResponse(userText: text)
    }

    func handleMicTap() {
        switch conversationState {
        case .idle:
            startListening()
        case .listening:
            stopListening()
        case .thinking, .speaking:
            stopSpeaking()
        }
    }

    func handleOrbTap() {
        handleMicTap()
    }

    // MARK: - Voice

    private func startListening() {
        Task {
            do {
                conversationState = .listening
                try await voice.startRecording()
            } catch {
                conversationState = .idle
                addSystemError("Microphone access denied. Please allow microphone access in Settings.")
            }
        }
    }

    private func stopListening() {
        guard conversationState == .listening else { return }
        conversationState = .thinking

        Task {
            let settings = storage.loadSettings()
            guard !settings.apiKey.isEmpty else {
                conversationState = .idle
                addSystemError("Please add your API key in Settings to use voice.")
                return
            }

            guard let transcription = await voice.stopAndTranscribe(apiKey: settings.apiKey),
                  !transcription.isEmpty else {
                conversationState = .idle
                return
            }

            addUserMessage(transcription)
            streamResponse(userText: transcription)
        }
    }

    private func stopSpeaking() {
        voice.stopSpeaking()
        conversationState = .idle
    }

    // MARK: - Messaging

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

    private func streamResponse(userText: String) {
        let settings = storage.loadSettings()
        guard !settings.apiKey.isEmpty else {
            conversationState = .idle
            addSystemError("Please add your API key in Settings.")
            return
        }

        conversationState = .thinking

        // Create placeholder streaming message
        let streamId = UUID().uuidString
        streamingMessageId = streamId
        var streamingMsg = Message(id: streamId, role: "assistant", content: "", isStreaming: true)
        messages.append(streamingMsg)

        var fullText = ""

        claude.streamMessage(
            apiKey: settings.apiKey,
            messages: messages.filter { $0.id != streamId }
        ) { [weak self] chunk in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch chunk {
                case .text(let text):
                    fullText += text
                    self.streamingText = fullText
                    if let idx = self.messages.firstIndex(where: { $0.id == streamId }) {
                        self.messages[idx].content = fullText
                        self.messages[idx].isStreaming = true
                    }

                case .toolStart(let name):
                    // Optionally show tool name in UI
                    if let idx = self.messages.firstIndex(where: { $0.id == streamId }) {
                        self.messages[idx].content = fullText + (fullText.isEmpty ? "" : "\n") + "_Using \(name)..._"
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

                    if settings.voiceEnabled && !fullText.isEmpty {
                        self.conversationState = .speaking
                        self.voice.speak(fullText)
                        // Wait for speech to finish
                        Task {
                            while self.voice.isSpeaking {
                                try? await Task.sleep(nanoseconds: 200_000_000)
                            }
                            await MainActor.run { self.conversationState = .idle }
                        }
                    } else {
                        self.conversationState = .idle
                    }

                case .error(let errText):
                    if let idx = self.messages.firstIndex(where: { $0.id == streamId }) {
                        if fullText.isEmpty {
                            self.messages[idx].content = "Error: \(errText)"
                        }
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
    HomeView()
        .environmentObject(AuthService.shared)
}
