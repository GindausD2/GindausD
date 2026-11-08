import SwiftUI
import Combine
import UIKit
import WidgetKit

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject private var authService: AuthService

    @ObservedObject private var playback = VoiceService.shared
    @ObservedObject private var reminderApproval = ReminderApprovalService.shared
    @ObservedObject private var factApproval = FactApproval.shared
    @ObservedObject private var lifeApproval = LifeMemoryApproval.shared
    @StateObject private var viewModel: HomeViewModel
    @State private var showCompanion: Bool = false
    @State private var showProfile = false
    @State private var showProjectResume = false
    @State private var inspectedMemory: MemoryLink?
    @State private var inspectedLifeMemory: MemoryLink?
    @State private var isTyping: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var islandNotice: String?
    @State private var showHistory: Bool = false
    @State private var showCamera: Bool = false
    @State private var capturedImage: UIImage? = nil
    @State private var pendingImage: UIImage? = nil
    @FocusState private var composerFocused: Bool

    private struct MemoryLink: Identifiable {
        let id: String
        var account: String = ""
    }

    private let liveActivity = LiveActivityService.shared

    init(viewModel: HomeViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? HomeViewModel())
        _isTyping = State(initialValue: !(viewModel?.inputText.isEmpty ?? true))
    }

    private var homeLayout: some View {
        ZStack {
            CompanionCanvas()

            VStack(spacing: 0) {
                topBar
                if authService.currentUser?.isDemo == true {
                    trialBanner
                }
                transcriptArea
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
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

    private var homeLifecycle: some View {
        homeLayout
        .onDisappear { viewModel.endConversation() }
        .onChange(of: viewModel.inputText) { _, text in
            if !text.isEmpty { isTyping = true }
        }
        .onChange(of: viewModel.isDictating) { _, active in if active { composerFocused = false } }
        .alert("Voice input unavailable", isPresented: Binding(
            get: { viewModel.dictationError != nil },
            set: { if !$0 { viewModel.dictationError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.dictationError = nil }
        } message: { Text(viewModel.dictationError ?? "Please try again.") }
        .alert("Max controls unavailable", isPresented: Binding(
            get: { islandNotice != nil },
            set: { if !$0 { islandNotice = nil } }
        )) {
            Button("iPhone settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("OK", role: .cancel) { islandNotice = nil }
        } message: { Text(islandNotice ?? "Please try again.") }
        .onChange(of: authService.currentUser) { _, _ in showProjectResume = false; inspectedMemory = nil; inspectedLifeMemory = nil; pendingImage = nil; isTyping = false; composerFocused = false; viewModel.endConversation(); viewModel.loadMessages() }
        .sheet(isPresented: $showCompanion) { CompanionView() }
        .sheet(isPresented: $showProfile) { CompanionProfileSheet(onClearHistory: viewModel.clearHistory) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { viewModel.endConversation() }
            if phase == .active { handlePendingShortcut() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .maxQuickReply)) { notification in
            UserDefaults.standard.removeObject(forKey: "max.pendingQuickReply")
            if let prompt = notification.object as? String { showProfile = false; viewModel.inputText = prompt; viewModel.sendTextMessage() }
        }
    }

    private var homePresentations: some View {
        homeLifecycle
        .sheet(isPresented: $showHistory) {
            ConversationHistoryView(onNewChat: {
                showHistory = false
                isTyping = false
                composerFocused = false
                viewModel.startNewChat()
            })
        }
        .sheet(item: Binding(get: { reminderApproval.pending }, set: { if $0 == nil { reminderApproval.cancel() } })) { proposal in
            ReminderApprovalView(proposal: proposal) { approved in reminderApproval.resolve(id: proposal.id, approved: approved) }
                .onDisappear { reminderApproval.resolve(id: proposal.id, approved: false) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            ImageSourcePicker(selectedImage: $capturedImage, isPresented: $showCamera)
                .ignoresSafeArea()
        }
        .sheet(item: Binding(get: { lifeApproval.pending }, set: { if $0 == nil { lifeApproval.cancel() } })) { proposal in
            LifeEventEditor(event: proposal.event, scope: proposal.scope) { savedID in lifeApproval.resolve(id: proposal.id, savedID: savedID) }
                .onDisappear { lifeApproval.resolve(id: proposal.id, savedID: nil) }
        }
        .sheet(item: Binding(get: { factApproval.pending }, set: { if $0 == nil { factApproval.cancel() } })) { proposal in
            FactReviewView(proposal: proposal) { factApproval.finish(id: proposal.id, value: $0) }
                .onDisappear { factApproval.finish(id: proposal.id, value: nil) }
        }
        .sheet(item: $inspectedMemory) { link in MemoryView(initialFactID: link.id) }
        .onChange(of: capturedImage) { _, img in
            guard let img else { return }
            pendingImage = img
            capturedImage = nil
        }
        .onAppear {
            viewModel.loadMessages()
            if scenePhase == .active { liveActivity.startPersistentSession() }
            handlePendingShortcut()
            if UserDefaults.standard.bool(forKey: "max.pendingBriefing") {
                showProfile = false
                UserDefaults.standard.removeObject(forKey: "max.pendingBriefing")
                viewModel.startMorningBriefing()
            }
            if let prompt = UserDefaults.standard.string(forKey: "max.pendingQuickReply") {
                showProfile = false
                UserDefaults.standard.removeObject(forKey: "max.pendingQuickReply")
                viewModel.inputText = prompt; viewModel.sendTextMessage()
            }
        }
    }

    private var projectPresentations: some View {
        homePresentations
            .sheet(isPresented: $showProjectResume) {
                ProjectResumeView(account: StorageService.shared.accountScope)
            }
            .sheet(item: $viewModel.thoughtDraft) { draft in
                AddFactView(account: draft.account, capturedText: draft.text, captureNotice: draft.notice) {}
            }
    }

    var body: some View {
        projectPresentations
            .sheet(item: $inspectedLifeMemory) { link in
                MemoryReplayView(eventID: link.id, scope: link.account)
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
            showProfile = false
            UserDefaults.standard.removeObject(forKey: "max.pendingBriefing")
            viewModel.startMorningBriefing()
        }
        // Start listening when user taps the home screen widget
        .onReceive(NotificationCenter.default.publisher(for: .maxWidgetActivate)) { _ in
            handlePendingShortcut()
        }
    }

    private func handlePendingShortcut() {
        // Home only exists after the existing authentication/demo/subscription gate.
        guard let action = MaxShortcutRequest.takePending(
            canEnterHome: !authService.isRestoringSession && !authService.isUpgradingDemo &&
                !authService.isDemoExpired && authService.currentUser?.allowsAccess(
                hasSubscription: StoreKitService.shared.isSubscribed, at: Date()) == true,
            isActive: scenePhase == .active
        ) else { return }
        showProfile = false
        showCompanion = false
        showHistory = false
        showCamera = false
        composerFocused = false
        let result = liveActivity.startPersistentSession()
        if action == .saveThought {
            viewModel.startThoughtCapture()
        } else if action == .voice {
            viewModel.activateVoice()
        } else {
            switch result {
            case .started, .resumed: break
            case .disabled:
                islandNotice = "Allow Live Activities for Max in iPhone settings, then run Start Max Island again."
            case .failed:
                islandNotice = "iOS couldn't start Max's Live Activity. Try again while Max is open."
            }
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
                showProfile = false
                isTyping = false
                composerFocused = false
                viewModel.startNewChat()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 44, height: 44)
                    .glassCard(cornerRadius: 22, interactive: true)
            }
            .accessibilityLabel("New conversation")

            Spacer()
            MaxJourneyLogo(width: 44)
                .accessibilityLabel("Max")
            Spacer()

            Button { viewModel.endConversation(); composerFocused = false; showProfile = true } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 44, height: 44)
                    .glassCard(cornerRadius: 22, interactive: true)
            }
            .accessibilityLabel("Your space and settings")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 8)
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
                                VStack(alignment: .leading, spacing: 4) {
                                    TranscriptBubble(message: msg, isStreaming: msg.isStreaming)
                                    meetingLinks(for: msg)
                                    ForEach(msg.memoryReferences ?? [], id: \.self) { id in
                                        if let fact = StorageService.shared.recallFacts().first(where: { $0.id == id }) {
                                            Button {
                                                inspectedMemory = MemoryLink(id: id)
                                            } label: {
                                                Label("Memory consulted: \(fact.key) · \(fact.scopeLabel)", systemImage: "brain")
                                                    .font(.caption)
                                            }
                                            .padding(.horizontal, 20)
                                        }
                                    }
                                }
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

    private func meetingLinks(for message: Message) -> some View {
        let ids = message.lifeMemoryReference.map { [$0] } ?? message.followUpMeetingReferences ?? []
        return ForEach(ids, id: \.self) { id in
            if let meeting = StorageService.shared.loadLifeEvents().first(where: { $0.id == id }) {
                Button {
                    inspectedLifeMemory = MemoryLink(id: id, account: StorageService.shared.accountScope)
                } label: {
                    Label("Open saved meeting: \(meeting.title)", systemImage: "person.crop.rectangle")
                        .font(.caption)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func emptyState(availableHeight: CGFloat) -> some View {
        let compact = availableHeight < 420 || dynamicTypeSize.isAccessibilitySize
        return VStack(spacing: 18) {
            Spacer(minLength: 16)
            if !compact {
                Text("A LITTLE SPACE FOR YOUR DAY")
                    .font(.caption2.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(.secondary)
            }
            Text("Make room for\nwhat matters.")
                .font(.system(compact ? .title : .largeTitle, design: .rounded).weight(.medium))
                .tracking(-1)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("A thought, a plan, a little help.\nStart wherever you are.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if !compact && !viewModel.isDictating && viewModel.inputText.isEmpty {
                HStack(spacing: 10) {
                    draftSuggestion("Plan my day", icon: "sun.horizon")
                    draftSuggestion("Write a thought", icon: "square.and.pencil")
                }.padding(.top, 10)
            }
            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private func draftSuggestion(_ title: String, icon: String) -> some View {
        Button {
            viewModel.inputText = title == "Write a thought" ? "Remember this: " : "Help me plan my day. "
            isTyping = true
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
        VStack(spacing: 8) {
            if viewModel.conversationState != .idle || viewModel.isTranscribing {
                statusPill.transition(.opacity)
            } else if !isTyping {
                Text(viewModel.inputText.isEmpty ? "Tap the orb to hear Max · AI voice" : "Draft ready · tap Type to edit")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if isTyping {
                textComposer
            } else {
                orbDock
            }
            floatingShortcuts
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: viewModel.conversationState)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: isTyping)
    }

    private var orbDock: some View {
        HStack(spacing: 12) {
            conversationActions
                .glassCard(cornerRadius: 22, interactive: true)
            Spacer(minLength: 0)
            Button { viewModel.handleOrbTap() } label: {
                OrbView(state: viewModel.orbState, size: 64)
            }
            .accessibilityLabel(viewModel.orbAccessibilityLabel)
            .accessibilityHint(viewModel.orbAccessibilityHint)
            Spacer(minLength: 0)
            microphoneButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var conversationActions: some View {
        Menu {
            Button("Type a message", systemImage: "keyboard") { openTextEntry() }
            Button("New conversation", systemImage: "square.and.pencil") {
                pendingImage = nil
                composerFocused = false
                isTyping = false
                viewModel.startNewChat()
            }
            Button("Save a thought", systemImage: "mic.badge.plus") { viewModel.startThoughtCapture() }
            Button("Project Resume", systemImage: "arrow.uturn.right") {
                viewModel.endConversation()
                composerFocused = false
                showProjectResume = true
            }
            Button("Attach a photo", systemImage: "photo") { showCamera = true }
            Button("Conversation history", systemImage: "clock.arrow.circlepath") {
                viewModel.endConversation(); showHistory = true
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Conversation actions")
    }

    private var microphoneButton: some View {
        Button { viewModel.handleMicTap() } label: {
            Image(systemName: viewModel.conversationState != .idle ? "stop.fill" : "mic.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(UIColor.systemBackground))
                .frame(width: 44, height: 44)
                .background(Color(UIColor.label), in: Circle())
        }
        .disabled(viewModel.isTranscribing)
        .accessibilityLabel(viewModel.conversationState != .idle ? "Stop voice or response" : "Dictate a message")
        .accessibilityHint("Turn your voice into editable text")
    }

    private var textComposer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    composerFocused = false
                    isTyping = false
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Return to orb")
                .accessibilityHint("Keep your draft and hide text entry")
                TextField("Write a message…", text: $viewModel.inputText, axis: .vertical)
                    .font(.body)
                    .lineLimit(1...4)
                    .fixedSize(horizontal: false, vertical: true)
                    .focused($composerFocused)
                    .submitLabel(.send)
                    .onSubmit { sendDraft() }
                    .disabled(viewModel.conversationState != .idle || viewModel.isTranscribing)
                    .accessibilityLabel("Message Max")
                if !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.conversationState == .idle {
                    Button { sendDraft() } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color(hex: "#315E73"), in: Circle())
                    }
                    .disabled(viewModel.isTranscribing)
                    .accessibilityLabel("Send message")
                } else {
                    microphoneButton
                }
            }
            if viewModel.prefersTextReplyForDraft {
                Text("Voice draft · edit, then send")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 34, depth: .regular)
    }

    private var floatingShortcuts: some View {
        HStack(spacing: 20) {
            if dynamicTypeSize.isAccessibilitySize {
                Button(action: openTextEntry) {
                    Label("Type", systemImage: "keyboard").frame(minHeight: 44)
                }
                Menu {
                    Button("Your day", systemImage: "square.grid.2x2") {
                        viewModel.endConversation(); showCompanion = true
                    }
                    Button("Morning briefing", systemImage: "sun.horizon") { viewModel.startMorningBriefing() }
                } label: {
                    Label("More", systemImage: "ellipsis").frame(minHeight: 44)
                }
                .accessibilityLabel("More companion tools")
            } else {
                Button { viewModel.endConversation(); showCompanion = true } label: {
                    Label("Your day", systemImage: "square.grid.2x2").frame(minHeight: 44)
                }
                Button(action: openTextEntry) {
                    Label("Type", systemImage: "keyboard").frame(minHeight: 44)
                }
                Button { viewModel.startMorningBriefing() } label: {
                    Label("Briefing", systemImage: "sun.horizon").frame(minHeight: 44)
                }
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
    }

    private func openTextEntry() {
        viewModel.endConversation()
        isTyping = true
        composerFocused = true
    }

    private func sendDraft() {
        viewModel.sendTextMessage()
        if viewModel.inputText.isEmpty {
            composerFocused = false
            isTyping = false
        }
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
                if viewModel.inputText.isEmpty { isTyping = false; composerFocused = false }
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
    struct ThoughtDraft: Identifiable {
        let id = UUID()
        let account: String
        let text: String
        let notice: String?
    }
    @Published var thoughtDraft: ThoughtDraft?
    private var capturingThought = false

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
        if voice.isPreparingSpeech { return "Getting Max’s voice ready · tap to stop" }
        if let notice = voice.playbackNotice, conversationState == .speaking { return notice + " · tap to stop" }
        return conversationState == .speaking ? "Max is speaking · tap to stop" : "Tap the orb to hear Max · AI voice"
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
        let reply = messages.last(where: { $0.role == "assistant" && !$0.isStreaming && !$0.content.isEmpty && !$0.content.hasPrefix("⚠️") && !$0.content.hasPrefix("Error:") })
        guard reply?.isPrivateRecall != true else { return }
        playSpeech(reply?.content ?? "Hi, I'm Max. I'm here. What's on your mind?")
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

    func startThoughtCapture() {
        guard conversationState == .idle, !startingVoice, !isDictating, !isTranscribing, thoughtDraft == nil else { return }
        guard storage.usesSavedMemory else {
            dictationError = "Saved Memory is paused. Turn it on in Your Space → Memory to save a thought."
            return
        }
        capturingThought = true
        startDictation()
    }

    func endConversation() {
        capturingThought = false
        thoughtDraft = nil
        FactApproval.shared.cancel()
        LifeMemoryApproval.shared.cancel()
        ReminderApprovalService.shared.cancel()
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
        capture.onRecordingLimit = { [weak self] in
            guard let self, self.isDictating, !self.isTranscribing else { return }
            self.finishDictation()
        }
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
                self.capturingThought = false
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
        let isThought = capturingThought
        capturingThought = false
        guard scope == storage.accountScope else { inputText = ""; prefersTextReplyForDraft = false; return }
        let text = result?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { dictationError = "Couldn't catch that. Your draft is still here — try again."; return }
        if isThought {
            thoughtDraft = ThoughtDraft(account: storage.accountScope, text: text, notice: capture.transcriptionNotice)
            return
        }
        inputText = dictationBaseDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText += (inputText.isEmpty ? "" : " ") + text
        prefersTextReplyForDraft = true
        dictationError = capture.transcriptionNotice
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
                capture.onRecordingLimit = { [weak self] in self?.stopListening() }
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
            if let notice = capture.transcriptionNotice {
                // A fallback or limited recording always gets a review step,
                // including direct-voice shortcut sessions.
                continuousActive = false
                inputText += (inputText.isEmpty ? "" : " ") + transcription
                prefersTextReplyForDraft = true
                dictationError = notice
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

    private func respondToFollowUps(_ question: String) -> Bool {
        guard let person = FollowUps.requestedPerson(question),
              let current = messages.indices.last, messages[current].role == "user" else { return false }
        let enabled = storage.usesSavedMemory
        let open = enabled ? FollowUps.open(for: person, reminders: storage.loadReminders()) : []
        let people = Set(open.compactMap { $0.followUpPerson.map(MemoryIdentity.normalize) })
        let shown = Array(open.prefix(10))
        let text: String
        if !enabled {
            text = "Saved Memory is paused. Turn it on to look up personal follow-ups."
        } else if people.count > 1 {
            text = "More than one person matches. Ask again with their full name."
        } else if shown.isEmpty {
            text = "I found no open follow-ups for that person."
        } else {
            let name = shown.first?.followUpPerson ?? person
            let lines = shown.map { reminder in
                "• \(reminder.title) — \(reminder.fireDate < Date() ? "Overdue · " : "")\(reminder.triggerSummary())"
            }
            let more = open.count > shown.count ? "\nMore follow-ups are in Reminders." : ""
            text = "Open follow-ups with \(name)\n\n" + lines.joined(separator: "\n") + more
        }
        var reply = Message(role: "assistant", content: text)
        if people.count == 1 {
            let savedIDs = Set(storage.loadLifeEvents().map(\.id))
            var seen: Set<String> = []
            reply.followUpMeetingReferences = shown.compactMap(\.followUpMeetingID)
                .filter { savedIDs.contains($0) && seen.insert($0).inserted }
        }
        appendPrivateMemoryReply(reply, userIndex: current)
        return true
    }

    private func appendPrivateMemoryReply(_ message: Message, userIndex: Int) {
        messages[userIndex].isPrivateRecall = true
        var reply = message
        reply.isPrivateRecall = true
        messages.append(reply)
        storage.saveMessages(messages)
        archiveCurrentConversation()
        continuousActive = false
        conversationState = .idle
    }

    private func respondToPeopleRecall(_ question: String) -> Bool {
        guard let current = messages.indices.last, messages[current].role == "user" else { return false }
        let previous = messages.dropLast().last
        let choices = previous?.role == "assistant" ? previous?.peopleRecallChoices ?? [] : []
        let enabled = storage.usesSavedMemory
        guard let answer = PeopleRecall.answer(question, events: enabled ? storage.loadLifeEvents() : [],
                                               previousChoices: choices) else { return false }
        var reply = Message(role: "assistant", content: enabled ? answer.text : "Saved memory is paused. Turn it on to look up a past meeting.")
        if enabled {
            reply.lifeMemoryReference = answer.eventID
            reply.peopleRecallChoices = answer.choices
        }
        appendPrivateMemoryReply(reply, userIndex: current)
        return true
    }

    private func streamResponse(userText: String, imageData: Data? = nil, allowSpeech: Bool = true) {
        if imageData == nil, respondToFollowUps(userText) || respondToPeopleRecall(userText) { return }
        let settings = storage.loadSettings()
        let thisTurn = UUID(); turnID = thisTurn
        conversationState = .thinking

        let streamId = UUID().uuidString
        streamingMessageId = streamId
        messages.append(Message(id: streamId, role: "assistant", content: "", isStreaming: true))

        var fullText = ""

        // Keep the last 40 messages (20 exchanges) to stay within token limits
        let history = messages.filter { $0.id != streamId && $0.isPrivateRecall != true && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var trimmed = history.count > 40 ? Array(history.suffix(40)) : history
        if let index = trimmed.lastIndex(where: { $0.role == "user" }) { trimmed[index].content = userText }

        streamTask = claude.streamMessage(
            messages: trimmed,
            imageData: imageData
        ) { [weak self] chunk in
            Task { @MainActor [weak self] in
                guard let self = self, self.turnID == thisTurn, self.loadedScope == self.storage.accountScope else { return }
                switch chunk {
                case .memoryReferences(let ids):
                    if let index = self.messages.firstIndex(where: { $0.id == streamId }) {
                        let existing = self.messages[index].memoryReferences ?? []
                        self.messages[index].memoryReferences = existing + ids.filter { !existing.contains($0) }
                    }
                case .replaceText(let text):
                    fullText = text
                    self.streamingText = text
                    if let index = self.messages.firstIndex(where: { $0.id == streamId }) {
                        self.messages[index].content = text
                        self.messages[index].memoryReferences = nil
                    }
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

