import SwiftUI
import Combine
import UIKit

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject private var authService: AuthService

    @StateObject private var viewModel = HomeViewModel()
    @State private var showSettings: Bool = false
    @State private var showDeviceLink: Bool = false
    @State private var showCamera: Bool = false
    @State private var capturedImage: UIImage? = nil

    private let liveActivity = LiveActivityService.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Liquid glass background ───────────────────────────────────────
            LinearGradient(
                stops: [
                    .init(color: Color(red: 1.00, green: 1.00, blue: 1.00), location: 0.0),
                    .init(color: Color(red: 0.97, green: 0.96, blue: 1.00), location: 0.5),
                    .init(color: Color(red: 0.94, green: 0.91, blue: 1.00), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                transcriptArea
                    .padding(.bottom, 140) // space for dock
            }

            // ── Floating glass dock ────────────────────────────────────────────
            bottomDock
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .sheet(isPresented: $showDeviceLink) { DeviceLinkView() }
        .fullScreenCover(isPresented: $showCamera) {
            ImageSourcePicker(selectedImage: $capturedImage, isPresented: $showCamera)
                .ignoresSafeArea()
        }
        .onChange(of: capturedImage) { _, img in
            guard let img else { return }
            viewModel.sendTextMessage(image: img)
            capturedImage = nil
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(onClearHistory: viewModel.clearHistory)
                .environmentObject(authService)
        }
        .onAppear {
            viewModel.loadMessages()
            liveActivity.startPersistentSession() // ensure island is alive
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
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Settings
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(Color(white: 0.35))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Logo
            MaxLogoView(color: Color(white: 0.15), width: 54)

            Spacer()

            // Device link
            Button { showDeviceLink = true } label: {
                Image(systemName: "link")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(Color(white: 0.35))
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                Rectangle()
                    .fill(Color.white.opacity(0.65))
                // Specular top streak
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.90), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 2)
                    Spacer()
                }
                // Bottom hairline border
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.49, green: 0.23, blue: 0.93).opacity(0.12), .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(height: 0.5)
                }
            }
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 3)
            .shadow(color: Color(red: 0.49, green: 0.23, blue: 0.93).opacity(0.04), radius: 20, x: 0, y: 6)
        )
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
            OrbView(state: .idle, size: 64)
            Text("Hi! I'm Max")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color(white: 0.15))
            Text("Tap the orb to talk\nor the camera to show Max something")
                .font(.subheadline)
                .foregroundStyle(Color(white: 0.5))
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
            if viewModel.conversationState != .idle {
                statusPill
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Main dock row
            HStack(spacing: 0) {
                // Orb (voice)
                OrbView(state: viewModel.orbState, size: 100)
                    .onTapGesture { viewModel.handleOrbTap() }
                    .frame(maxWidth: .infinity)

                // Camera (vision)
                cameraButton
                    .frame(maxWidth: .infinity)

                // Places memory
                placesButton
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 20)
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(Color.white.opacity(0.55))
                // Specular top streak
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.85), .clear],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.45)
                            )
                        )
                        .frame(height: 48)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.90), location: 0.0),
                            .init(color: .white.opacity(0.50), location: 0.35),
                            .init(color: .white.opacity(0.15), location: 0.70),
                            .init(color: .clear,               location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: .black.opacity(0.10), radius: 24, x: 0, y: -4)
        .shadow(color: Color(red: 0.49, green: 0.23, blue: 0.93).opacity(0.08), radius: 40, x: 0, y: -10)
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
        switch viewModel.conversationState {
        case .idle:      return .gray
        case .listening: return Color(red: 0.94, green: 0.27, blue: 0.27)
        case .thinking:  return Color(red: 0.49, green: 0.23, blue: 0.93)
        case .speaking:  return Color(red: 0.23, green: 0.51, blue: 0.96)
        }
    }

    private var statusText: String {
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
            // Activate Dynamic Island in listening state, then start voice
            LiveActivityService.shared.start()
            viewModel.handleMicTap()
        } label: {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(Color(white: 0.35))
                .frame(width: 44, height: 44)
        }
    }

    // MARK: - Image Thumbnail Row

}

// MARK: - HomeViewModel

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var conversationState: ConversationState = .idle
    @Published var streamingText: String = ""

    private let storage = StorageService.shared
    private let claude  = ClaudeService.shared
    private let voice   = VoiceService.shared

    private var streamingMessageId: String? = nil

    var orbState: OrbState {
        switch conversationState {
        case .idle:      return .idle
        case .listening: return .listening
        case .thinking:  return .thinking
        case .speaking:  return .speaking
        }
    }

    func loadMessages()  { messages = storage.loadMessages() }
    func clearHistory()  { storage.clearMessages(); messages = [] }
    func startNewChat()  { clearHistory() }

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

    private func startListening() {
        Task {
            do {
                conversationState = .listening
                try await voice.startRecording()
            } catch {
                conversationState = .idle
                addSystemError("Microphone access denied.")
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
                addSystemError("Add your API key in Settings to use voice.")
                return
            }
            guard let transcription = await voice.stopAndTranscribe(apiKey: settings.apiKey),
                  !transcription.isEmpty else {
                conversationState = .idle
                return
            }
            addUserMessage(transcription)
            streamResponse(userText: transcription, imageData: nil)
        }
    }

    private func stopSpeaking() {
        voice.stopSpeaking()
        conversationState = .idle
    }

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
        guard !settings.apiKey.isEmpty else {
            conversationState = .idle
            addSystemError("Add your API key in Settings.")
            return
        }
        conversationState = .thinking

        let streamId = UUID().uuidString
        streamingMessageId = streamId
        messages.append(Message(id: streamId, role: "assistant", content: "", isStreaming: true))

        var fullText = ""

        claude.streamMessage(
            apiKey: settings.apiKey,
            messages: messages.filter { $0.id != streamId },
            imageData: imageData
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
                    if settings.voiceEnabled && !fullText.isEmpty {
                        self.conversationState = .speaking
                        self.voice.speak(fullText, preferredVoice: settings.preferredVoice)
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

// MARK: - ConversationState

enum ConversationState: Equatable {
    case idle
    case listening
    case thinking
    case speaking
}

#Preview {
    HomeView().environmentObject(AuthService.shared)
}
