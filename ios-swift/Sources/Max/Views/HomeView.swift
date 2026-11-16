import SwiftUI
import PhotosUI
import Combine
import UIKit
import WidgetKit

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject private var authService: AuthService

    @ObservedObject private var playback = VoiceService.shared
    @ObservedObject private var reminderApproval = ReminderApprovalService.shared
    @ObservedObject private var lifeApproval = LifeMemoryApproval.shared
    @StateObject private var viewModel: HomeViewModel
    @State private var showCompanion: Bool = false
    @State private var showThoughts = false
    @State private var showThoughtsDock = false
    @State private var recordThoughtRequested = false
    @State private var showAlarms = false
    @ObservedObject private var thoughtStore = ThoughtStore.shared

    private var thoughtScope: String? { authService.currentUser?.id?.lowercased() }
    @State private var showProfile = false
    @State private var showReport = false
    @State private var isTyping: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var islandNotice: String?
    @State private var showHistory: Bool = false
    @State private var showCamera = false
    @State private var showImageSources = false
    @State private var showPhotoLibrary = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoLoadFailed = false
    @State private var showVisualIntelligence = false
    @State private var capturedImage: UIImage? = nil
    @State private var pendingImage: UIImage? = nil
    @FocusState private var composerFocused: Bool

    private let liveActivity = LiveActivityService.shared

    init(viewModel: HomeViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? HomeViewModel())
        _isTyping = State(initialValue: !(viewModel?.inputText.isEmpty ?? true))
    }

    var body: some View {
        GeometryReader { geometry in
            let wide = horizontalSizeClass == .regular &&
                geometry.size.width >= (dynamicTypeSize.isAccessibilitySize ? 980 : 640)
            HStack(spacing: 0) {
                conversationPresentation
                    .frame(width: wide && showThoughtsDock ? geometry.size.width * 0.52 : geometry.size.width)
                if wide && showThoughtsDock {
                    Divider().accessibilityHidden(true)
                    thoughtsPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(CompanionCanvas())
                }
            }
            .onChange(of: wide, initial: true) { _, wide in
                showThoughtsDock = wide
                if wide { showThoughts = false }
            }
        }
            .sheet(isPresented: $showThoughts) {
                NavigationStack {
                    thoughtsPanel
                        .toolbar { ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showThoughts = false }
                        } }
                }
            }
            .sheet(isPresented: $showAlarms) {
                if let thoughtScope { HomeAlarmsView(store: thoughtStore, scope: thoughtScope) }
            }
            .onChange(of: thoughtScope, initial: true) { previous, current in
                thoughtStore.open(scope: current)
                if previous != current {
                    showAlarms = false
                    recordThoughtRequested = false
                }
            }
            .sheet(isPresented: $showReport) { SupportContactView(reporting: true) }
            .onAppear(perform: restoreConversation)
            .onChange(of: viewModel.conversationState) { _, state in updateLiveActivity(state) }
            .onChange(of: viewModel.streamingText) { _, text in updateLiveActivitySnippet(text) }
            .onReceive(NotificationCenter.default.publisher(for: .maxStartBriefing)) { _ in
                showProfile = false
                UserDefaults.standard.removeObject(forKey: "max.pendingBriefing")
                viewModel.startMorningBriefing()
            }
            .onReceive(NotificationCenter.default.publisher(for: .maxWidgetActivate)) { _ in
                handlePendingShortcut()
            }
    }

    private var thoughtsPanel: some View {
        ThoughtsView(store: thoughtStore, scope: thoughtScope,
                     canSync: authService.currentUser?.isDemo == false,
                     prepareRecording: { viewModel.endConversation() },
                     captureRequested: $recordThoughtRequested)
    }

    private var conversationLayout: some View {
        ZStack {
            CompanionCanvas()

            VStack(spacing: 0) {
                topBar
                if authService.currentUser?.isDemo == true {
                    trialBanner
                }
                transcriptArea
            }
            .frame(maxWidth: 740)
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
            .frame(maxWidth: 740)
            .frame(maxWidth: .infinity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: pendingImage != nil)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: viewModel.isDictating)
        }
    }

    private var conversationInteractions: some View {
        conversationLayout
            .onDisappear { viewModel.endConversation() }
            .onChange(of: viewModel.inputText) { _, text in
                if !text.isEmpty { isTyping = true }
            }
            .onChange(of: viewModel.isDictating) { _, active in if active { composerFocused = false } }
            .onChange(of: voiceTurnActive) { _, active in if active { composerFocused = false } }
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
            .onChange(of: authService.currentUser) { _, _ in viewModel.showAIPrivacy = false; pendingImage = nil; isTyping = false; composerFocused = false; viewModel.endConversation(); viewModel.loadMessages() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { viewModel.endConversation() }
                if phase == .active { handlePendingShortcut() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .maxQuickReply)) { notification in
                UserDefaults.standard.removeObject(forKey: "max.pendingQuickReply")
                if let prompt = notification.object as? String { showProfile = false; viewModel.inputText = prompt; viewModel.sendTextMessage() }
            }
    }

    private var conversationPresentation: some View {
        conversationInteractions
            .sheet(isPresented: $viewModel.showAIPrivacy) {
                AIPrivacyView(scope: StorageService.shared.accountScope)
            }
            .sheet(isPresented: $showCompanion) { CompanionView() }
            .sheet(isPresented: $showProfile) { CompanionProfileSheet(onClearHistory: viewModel.clearHistory) }
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
            .fullScreenCover(isPresented: $showVisualIntelligence) {
                VisualIntelligenceView(account: StorageService.shared.accountScope)
            }
            .confirmationDialog("Add a Photo", isPresented: $showImageSources, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") { showCamera = true }
                }
                Button("Choose from Library") { showPhotoLibrary = true }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView(selectedImage: $capturedImage, isPresented: $showCamera).ignoresSafeArea()
            }
            .photosPicker(isPresented: $showPhotoLibrary, selection: $selectedPhoto, matching: .images)
            .task(id: selectedPhoto) {
                guard let item = selectedPhoto else { return }
                let scope = StorageService.shared.accountScope
                let data = try? await item.loadTransferable(type: Data.self)
                guard !Task.isCancelled, StorageService.shared.accountScope == scope else { return }
                selectedPhoto = nil
                if let data, let image = UIImage(data: data) { pendingImage = image }
                else { photoLoadFailed = true }
            }
            .sheet(item: Binding(get: { lifeApproval.pending }, set: { if $0 == nil { lifeApproval.cancel() } })) { proposal in
                LifeEventEditor(event: proposal.event, scope: proposal.scope) { savedID in lifeApproval.resolve(id: proposal.id, savedID: savedID) }
                    .onDisappear { lifeApproval.resolve(id: proposal.id, savedID: nil) }
            }
            .alert("Max couldn’t open this photo", isPresented: $photoLoadFailed) {
                Button("OK", role: .cancel) {}
            } message: { Text("Try choosing the photo again.") }
            .onChange(of: authService.currentUser?.storageScope) { _, _ in
                selectedPhoto = nil
                capturedImage = nil
                pendingImage = nil
                showPhotoLibrary = false
                showCamera = false
            }
            .onChange(of: capturedImage) { _, img in
                guard let img else { return }
                pendingImage = img
                capturedImage = nil
            }
    }

    private func restoreConversation() {
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
            viewModel.inputText = prompt
            viewModel.sendTextMessage()
        }
    }

    private func updateLiveActivity(_ state: ConversationState) {
        switch state {
        case .idle: liveActivity.keepAlive()
        case .listening: liveActivity.start()
        case .thinking: liveActivity.update(phase: .thinking)
        case .speaking: liveActivity.update(phase: .speaking)
        }
    }

    private func updateLiveActivitySnippet(_ text: String) {
        let state = viewModel.conversationState
        guard state == .thinking || state == .speaking else { return }
        liveActivity.update(phase: state == .thinking ? .thinking : .speaking, snippet: text)
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
        showVisualIntelligence = false
        composerFocused = false
        let result = liveActivity.startPersistentSession()
        if action == .voice {
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
                    draftSuggestion("Save a thought", icon: "square.and.pencil")
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
            viewModel.inputText = title == "Save a thought" ? "Remember this: " : "Help me plan my day. "
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
            if voiceTurnActive {
                statusPill.transition(.opacity)
                if viewModel.conversationState == .listening, !viewModel.liveTranscript.isEmpty {
                    ScrollView {
                        Text(viewModel.liveTranscript)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 94)
                    .padding(.horizontal, 12)
                    .accessibilityLabel("Live transcription")
                }
            } else if !isTyping {
                Text(viewModel.inputText.isEmpty ? "Tap to hear Max · Hold for voice options" : "Draft ready · tap Type to edit")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if isTyping && !voiceTurnActive {
                textComposer
            } else {
                orbDock
            }
            if !voiceTurnActive && !isTyping { homeCaptureShortcuts }
            floatingShortcuts
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: viewModel.conversationState)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: isTyping)
    }

    private var voiceTurnActive: Bool {
        viewModel.conversationState != .idle || viewModel.isTranscribing || viewModel.startingVoice
    }

    private var orbDock: some View {
        HStack(spacing: 12) {
            conversationActions
                .glassCard(cornerRadius: 22, interactive: true)
            Spacer(minLength: 0)
            if voiceTurnActive {
                orbButton
            } else {
                orbButton
                    .contextMenu { voiceActions }
                    .accessibilityActions { voiceActions }
            }
            Spacer(minLength: 0)
            Button(action: openVisualIntelligence) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(Color(hex: "#315E73"))
                    .frame(width: 44, height: 44)
                    .glassCard(cornerRadius: 22, interactive: true)
            }
            .accessibilityLabel("Visual Intelligence")
            .accessibilityHint("Open Max’s camera")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func openVisualIntelligence() {
        viewModel.endConversation()
        composerFocused = false
        showVisualIntelligence = true
    }

    private var orbButton: some View {
        Button(action: viewModel.handleOrbTap) {
            OrbView(state: viewModel.orbState(isPlayingSpeech: playback.isSpeaking && !playback.isPreparingSpeech), size: 64)
                .contentShape(Circle())
        }
        .accessibilityLabel(viewModel.orbAccessibilityLabel)
        .accessibilityHint(viewModel.orbAccessibilityHint)
    }

    @ViewBuilder private var voiceActions: some View {
        Button("Talk to Max", systemImage: "waveform") {
            composerFocused = false
            viewModel.activateVoice()
        }
        Button("Dictate a message", systemImage: "text.bubble") {
            composerFocused = false
            viewModel.handleMicTap()
        }
    }

    private var conversationActions: some View {
        Menu {
            Button("Thoughts", systemImage: "waveform") {
                viewModel.endConversation()
                if !showThoughtsDock { showThoughts = true }
            }
            Button("Type a message", systemImage: "keyboard") { openTextEntry() }
            if !voiceTurnActive { voiceActions }
            Button("New conversation", systemImage: "square.and.pencil") {
                pendingImage = nil
                composerFocused = false
                isTyping = false
                viewModel.startNewChat()
            }
            Button("Visual Intelligence", systemImage: "viewfinder", action: openVisualIntelligence)
            Button("Attach a photo", systemImage: "photo") { showImageSources = true }
            Button("Report a response", systemImage: "flag") {
                viewModel.endConversation()
                showReport = true
            }
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
                }
            }
            if viewModel.prefersTextReplyForDraft {
                HStack(spacing: 16) {
                    Text("Voice draft").font(.caption).foregroundStyle(.secondary)
                    if !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Copy", systemImage: "document.on.document") {
                            UIPasteboard.general.string = viewModel.inputText
                        }
                        .frame(minHeight: 44)
                        ShareLink(item: viewModel.inputText) { Label("Share", systemImage: "square.and.arrow.up") }
                            .frame(minHeight: 44)
                    }
                }
                .font(.caption)
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 34, depth: .regular)
    }

    private var homeCaptureShortcuts: some View {
        HStack(spacing: 16) {
            Button {
                guard thoughtScope != nil else { return }
                composerFocused = false
                recordThoughtRequested = true
                if !showThoughtsDock { showThoughts = true }
            } label: {
                Label("Record", systemImage: "waveform").frame(minHeight: 44)
            }
            .accessibilityLabel("Record a thought")
            if #available(iOS 26.0, *), !ProcessInfo.processInfo.isiOSAppOnMac {
                Button {
                    viewModel.endConversation()
                    composerFocused = false
                    showAlarms = true
                } label: {
                    Label("Alarms", systemImage: "alarm").frame(minHeight: 44)
                }
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .disabled(thoughtScope == nil)
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
        if viewModel.startingVoice { return "Getting the microphone ready…" }
        if viewModel.isTranscribing { return "Transcribing…" }
        switch viewModel.conversationState {
        case .idle:      return "Idle"
        case .listening: return "Recording… tap to send"
        case .thinking:  return "Thinking…"
        case .speaking:
            if let fallback = playback.playbackNotice { return fallback }
            if playback.isPreparingSpeech { return "Getting Max’s voice ready…" }
            return "Max is speaking…"
        }
    }

    // MARK: - Camera Button

    private var cameraButton: some View {
        Button { showImageSources = true } label: {
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
                guard viewModel.reviewCloudAIIfNeeded() else { return }
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
    @Published private(set) var startingVoice = false
    @Published private(set) var liveTranscript = ""
    @Published private(set) var prefersTextReplyForDraft = false
    @Published var dictationError: String?
    @Published var showAIPrivacy = false

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
    private var loadedScope: String?
    private var streamingMessageId: String? = nil
    private var currentConversationId: String = UUID().uuidString
    private var conversationStartedAt: Date = Date()

    init(capture: (any VoiceCapturing)? = nil) {
        let capture = capture ?? VoiceService.shared
        self.capture = capture
        capture.transcriptUpdates.sink { [weak self] text in
            guard let self else { return }
            let scope = self.isDictating ? self.dictationScope : self.loadedScope
            guard scope == self.storage.accountScope,
                  self.isDictating || self.conversationState == .listening else { return }
            self.liveTranscript = text
        }.store(in: &voiceSubscriptions)
        capture.recordingUpdates.sink { [weak self] recording in
            guard let self, !recording, !self.isTranscribing, self.conversationState == .listening else { return }
            if self.isDictating {
                self.completeDictation(self.capture.currentTranscript, expectedTurn: self.turnID, scope: self.dictationScope)
            } else {
                // An interruption ends the listening turn without sending partial speech.
                self.continuousActive = false
                self.liveTranscript = ""
                self.conversationState = .idle
            }
        }.store(in: &voiceSubscriptions)
    }

    func orbState(isPlayingSpeech: Bool) -> OrbState {
        if startingVoice || isTranscribing { return .thinking }
        switch conversationState {
        case .idle:      return .idle
        case .listening: return .listening
        case .thinking:  return .thinking
        case .speaking:  return isPlayingSpeech ? .speaking : .thinking
        }
    }

    var orbAccessibilityLabel: String {
        if startingVoice || isTranscribing { return "Cancel voice input" }
        switch conversationState {
        case .idle: return "Hear Max"
        case .listening: return "Send voice message"
        case .thinking: return "Stop response"
        case .speaking: return "Stop Max speaking"
        }
    }

    var orbAccessibilityHint: String {
        if isDictating { return "Finish dictation and review your message before sending" }
        return conversationState == .idle && !startingVoice && !isTranscribing ? "Tap to hear Max. Voice options are also in Conversation actions." : ""
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

    func reviewCloudAIIfNeeded() -> Bool {
        guard storage.allowsCloudAI(scope: storage.accountScope) else {
            showAIPrivacy = true
            return false
        }
        return true
    }

    func sendTextMessage(image: UIImage? = nil) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || image != nil, conversationState == .idle, !isDictating, !isTranscribing, !startingVoice else { return }
        guard reviewCloudAIIfNeeded() else { return }
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

    func handleVoiceTap() {
        if startingVoice || isTranscribing {
            endConversation()
            return
        }
        switch conversationState {
        case .idle: activateVoice()
        case .listening: stopListening()
        case .thinking, .speaking: endConversation()
        }
    }

    func handleOrbTap() {
        if isDictating { handleMicTap(); return }
        guard conversationState == .idle, !startingVoice, !isTranscribing else {
            handleVoiceTap()
            return
        }
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
        guard reviewCloudAIIfNeeded() else { return }
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
            if kMaxAPIBaseURL.isEmpty || !storage.allowsCloudAI(scope: scope) {
                messages.append(Message(role: "assistant", content: snapshot))
                storage.saveMessages(messages)
                archiveCurrentConversation()
                if storage.loadSettings().voiceEnabled { playSpeech(snapshot) }
            } else { streamResponse(userText: "Summarize this verified snapshot warmly. Do not invent missing sources.\n" + snapshot) }
        }
    }

    func endConversation() {
        LifeMemoryApproval.shared.cancel()
        ReminderApprovalService.shared.cancel()
        continuousActive = false
        turnID = UUID()
        voiceInputTask?.cancel(); voiceInputTask = nil
        startingVoice = false
        isDictating = false
        liveTranscript = ""
        dictationScope = nil
        streamTask?.cancel(); streamTask = nil
        speechCompletionTask?.cancel(); speechCompletionTask = nil
        conversationState = .idle
        voice.stopSpeaking(); capture.stopRecording()
        isTranscribing = false
        streamingText = ""
        messages.removeAll { $0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        for index in messages.indices { messages[index].isStreaming = false }
        streamingMessageId = nil
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
            defer { if self.turnID == activationID { self.startingVoice = false } }
            do {
                try await self.capture.startRecording()
                guard self.turnID == activationID, self.storage.accountScope == scope, !Task.isCancelled else { return }
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
        dictationError = capture.transcriptionNotice
    }

    private func startListening() {
        guard !startingVoice, !isTranscribing else { return }
        liveTranscript = ""
        startingVoice = true
        dictationError = nil
        let activationID = UUID()
        turnID = activationID
        let scope = storage.accountScope
        voiceInputTask = Task {
            defer { if turnID == activationID { startingVoice = false } }
            do {
                continuousActive = storage.loadSettings().continuousConversation ?? false
                capture.onUtteranceEnd = { [weak self] in
                    guard let self, self.continuousActive else { return }
                    self.stopListening()
                }
                capture.onRecordingLimit = { [weak self] in self?.stopListening() }
                try await capture.startRecording()
                guard turnID == activationID, storage.accountScope == scope, !Task.isCancelled else { return }
                conversationState = .listening
            } catch {
                guard turnID == activationID, storage.accountScope == scope, !(error is CancellationError) else { return }
                continuousActive = false
                dictationError = error.localizedDescription
            }
        }
    }

    private func stopListening() {
        guard conversationState == .listening, !isDictating else { return }
        isTranscribing = true
        conversationState = .idle
        let listeningID = turnID
        let scope = storage.accountScope
        voiceInputTask = Task {
            let transcription = await capture.stopAndTranscribe()
            guard turnID == listeningID, storage.accountScope == scope, !Task.isCancelled else { return }
            isTranscribing = false
            liveTranscript = ""
            guard let transcription, !transcription.isEmpty else {
                addSystemError("Couldn't catch that — please try again.")
                return
            }
            if let notice = capture.transcriptionNotice {
                // A fallback or limited recording always gets a review step.
                continuousActive = false
                inputText += (inputText.isEmpty ? "" : " ") + transcription
                prefersTextReplyForDraft = true
                dictationError = notice
                return
            }
            guard reviewCloudAIIfNeeded() else {
                continuousActive = false
                inputText += (inputText.isEmpty ? "" : " ") + transcription
                prefersTextReplyForDraft = true
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
                    if errText == ClaudeError.consentRequired.errorDescription {
                        self.showAIPrivacy = true
                    }
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

