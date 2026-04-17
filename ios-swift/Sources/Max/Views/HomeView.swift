import SwiftUI
import Combine
import UIKit

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var viewModel = HomeViewModel()
    @State private var showSettings: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var pendingImage: UIImage? = nil

    private let liveActivity = LiveActivityService.shared

    var body: some View {
        ZStack {
            // ── Adaptive background ────────────────────────────────────────────
            backgroundGradient.ignoresSafeArea()
            ambientBlobs

            VStack(spacing: 0) {
                topBar
                transcriptArea
                bottomDock
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(onClearHistory: viewModel.clearHistory)
                .environmentObject(authService)
        }
        .fullScreenCover(isPresented: $showImagePicker) {
            ImageSourcePicker(selectedImage: $pendingImage, isPresented: $showImagePicker)
                .ignoresSafeArea()
        }
        .onAppear {
            viewModel.loadMessages()
        }
        // ── Dynamic Island integration ─────────────────────────────────────
        .onChange(of: viewModel.conversationState) { _, newState in
            switch newState {
            case .idle:
                liveActivity.end()
            case .listening:
                liveActivity.start()
                liveActivity.update(phase: .listening)
            case .thinking:
                liveActivity.update(phase: .thinking)
            case .speaking:
                liveActivity.update(phase: .speaking)
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

    // MARK: - Adaptive Background

    private var backgroundGradient: some View {
        Group {
            if colorScheme == .dark {
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "#06030F"), location: 0.0),
                        .init(color: Color(hex: "#0E0620"), location: 0.5),
                        .init(color: Color(hex: "#100825"), location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            } else {
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.97, green: 0.96, blue: 1.00), location: 0.0),
                        .init(color: Color(red: 0.93, green: 0.91, blue: 0.99), location: 0.5),
                        .init(color: Color(red: 0.96, green: 0.93, blue: 1.00), location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
    }

    private var ambientBlobs: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#7C3AED").opacity(colorScheme == .dark ? 0.12 : 0.06))
                .frame(width: 380, height: 380)
                .blur(radius: 100)
                .offset(x: 80, y: 340)
                .allowsHitTesting(false)
            Circle()
                .fill(Color(hex: "#4F46E5").opacity(colorScheme == .dark ? 0.08 : 0.05))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: -100, y: 60)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Top Bar (glass blur)

    private var topBar: some View {
        HStack {
            Button {
                viewModel.startNewChat()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.75))
                    .frame(width: 40, height: 40)
            }

            Spacer()

            MaxLogoView(color: .white, width: 52)

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.75))
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .white.opacity(0.04)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Transcript Area

    private var transcriptArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    if viewModel.messages.isEmpty {
                        emptyState.id("empty")
                    } else {
                        ForEach(viewModel.messages) { message in
                            TranscriptBubble(message: message, isStreaming: message.isStreaming)
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
                .foregroundStyle(Color.primary)
            Text("Tap the mic to start talking,\nor type a message")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 40)
    }

    // MARK: - Bottom Dock (floating glass panel)

    private var bottomDock: some View {
        VStack(spacing: 0) {
            statusIndicator

            VStack(spacing: 18) {
                OrbView(state: viewModel.orbState, size: 128)
                    .onTapGesture { viewModel.handleOrbTap() }
                if let img = pendingImage {
                    imageThumbnailRow(img)
                }
                inputRow
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(
            ZStack {
                // Frosted glass
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.regularMaterial)
                // White tint
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                // Specular top streak
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.18), .clear],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.4)
                            )
                        )
                        .frame(height: 56)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.50), location: 0.0),
                            .init(color: .white.opacity(0.18), location: 0.35),
                            .init(color: .white.opacity(0.04), location: 0.75),
                            .init(color: .clear,               location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
        .shadow(color: .black.opacity(0.35), radius: 28, x: 0, y: -6)
        .shadow(color: Color(hex: "#7C3AED").opacity(0.08), radius: 40, x: 0, y: -10)
    }

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
                .shadow(color: statusColor.opacity(0.8), radius: 5)
            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(statusColor.opacity(0.10))
        .animation(.easeInOut(duration: 0.3), value: viewModel.conversationState)
        .opacity(viewModel.conversationState == .idle ? 0 : 1)
    }

    private var statusColor: Color {
        switch viewModel.conversationState {
        case .idle:      return .white.opacity(0.4)
        case .listening: return Color(hex: "#EF4444")
        case .thinking:  return Color(hex: "#7C3AED")
        case .speaking:  return Color(hex: "#4F46E5")
        }
    }

    private var statusText: String {
        switch viewModel.conversationState {
        case .idle:      return "Idle"
        case .listening: return "Listening..."
        case .thinking:  return "Thinking..."
        case .speaking:  return "Speaking..."
        }
    }

    // MARK: - Image Thumbnail Row

    private func imageThumbnailRow(_ image: UIImage) -> some View {
        HStack(spacing: 10) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.75)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Photo attached")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Ask Max anything about it")
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    pendingImage = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Input Row

    private var inputRow: some View {
        HStack(spacing: 12) {
            // Glass text input
            HStack(spacing: 0) {
                TextField("Message Max...", text: $viewModel.inputText, axis: .vertical)
                    .font(.body)
                    .foregroundStyle(.white)
                    .tint(Color(hex: "#A78BFA"))
                    .lineLimit(1...4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .onSubmit {
                        viewModel.sendTextMessage(image: pendingImage)
                        pendingImage = nil
                    }

                if !viewModel.inputText.isEmpty {
                    Button {
                        viewModel.sendTextMessage(image: pendingImage)
                        pendingImage = nil
                    } label: {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#7C3AED"), Color(hex: "#4F46E5")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                    }
                    .padding(.trailing, 8)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.14), .clear],
                                startPoint: .top,
                                endPoint: UnitPoint(x: 0.5, y: 0.5)
                            )
                        )
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.35), .white.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.inputText.isEmpty)

            // Camera button — left of the mic circle
            Button {
                showImagePicker = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle().strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.35), .white.opacity(0.08)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.75
                            )
                        )

                    Image(systemName: pendingImage == nil ? "camera" : "camera.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(
                            pendingImage == nil
                                ? Color.white.opacity(0.80)
                                : Color(hex: "#A78BFA")
                        )
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: pendingImage == nil)

            // Mic button with glow rings
            Button {
                viewModel.handleMicTap()
            } label: {
                ZStack {
                    // Outer glow ring
                    Circle()
                        .fill(micColor.opacity(0.18))
                        .frame(width: 62, height: 62)
                        .blur(radius: 6)

                    // Button body
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [micColor, micColor.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle().fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.25), .clear],
                                    startPoint: .top, endPoint: .center
                                )
                            )
                        )
                        .overlay(
                            Circle().strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.45), .clear],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.75
                            )
                        )
                        .shadow(color: micColor.opacity(0.55), radius: 10, x: 0, y: 4)
                        .shadow(color: micColor.opacity(0.25), radius: 24, x: 0, y: 8)

                    Image(systemName: viewModel.conversationState == .listening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .scaleEffect(viewModel.conversationState == .listening ? 1.08 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.conversationState)
        }
    }

    private var micColor: Color {
        switch viewModel.conversationState {
        case .listening:          return Color(hex: "#EF4444")
        case .thinking, .speaking: return Color(hex: "#6B7280")
        default:                  return Color(hex: "#7C3AED")
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
    private let claude  = ClaudeService.shared
    private let voice   = VoiceService.shared

    private var streamingMessageId: String? = nil
    private var cancellables = Set<AnyCancellable>()

    var orbState: OrbState {
        switch conversationState {
        case .idle:      return .idle
        case .listening: return .listening
        case .thinking:  return .thinking
        case .speaking:  return .speaking
        }
    }

    // MARK: - Lifecycle

    func loadMessages()  { messages = storage.loadMessages() }
    func clearHistory()  { storage.clearMessages(); messages = [] }
    func startNewChat()  { clearHistory() }

    // MARK: - Input

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
        case .idle:              startListening()
        case .listening:         stopListening()
        case .thinking, .speaking: stopSpeaking()
        }
    }

    func handleOrbTap() { handleMicTap() }

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
            streamResponse(userText: transcription, imageData: nil)
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

    private func streamResponse(userText: String, imageData: Data? = nil) {
        let settings = storage.loadSettings()
        guard !settings.apiKey.isEmpty else {
            conversationState = .idle
            addSystemError("Please add your API key in Settings.")
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
