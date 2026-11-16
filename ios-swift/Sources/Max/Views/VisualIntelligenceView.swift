import SwiftUI
import PhotosUI
import AVFoundation
import UIKit
import Vision

struct VisualIntelligenceView: View {
    private enum Mode: String, CaseIterable {
        case identify, readText, translatePhoto, translateSpeech

        var label: String {
            switch self {
            case .identify: return "Identify"
            case .readText: return "Read text"
            case .translatePhoto: return "Translate"
            case .translateSpeech: return "Speech"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthService
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var camera = VisualCamera()
    @ObservedObject private var voice = VoiceService.shared
    @State private var mode: Mode = .identify
    @State private var cameraAccess = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var showLibrary = false
    @State private var captureID: UUID?
    @State private var islandSession = UUID()
    @State private var isIdentifying = false
    @State private var announcedAnswer: String?
    @State private var showFullResult = false
    @State private var saveKind: VisualSaveKind?
    @State private var savedMessage: String?
    @State private var photo: UIImage?
    @State private var selection: PhotosPickerItem?
    @State private var transcript = ""
    @State private var question = ""
    @State private var language = "English"
    @State private var answer: String?
    @State private var error: String?
    @State private var notice: String?
    @State private var work: Task<Void, Never>?
    @State private var recording = false
    @State private var busy = false
    @State private var playingResult = false
    @State private var showAIPrivacy = false
    @State private var confirmPhotoUpload = false
    let account: String

    private let languages = ["English", "Hausa", "French", "Arabic", "Spanish", "German",
                             "Portuguese", "Chinese", "Japanese", "Korean"]

    private var cameraWanted: Bool {
        scenePhase == .active && mode != .translateSpeech && cameraAccess == .authorized &&
            photo == nil && !showLibrary
    }

    private struct IslandUpdate: Equatable {
        let stage: LiveActivityService.CameraCard.Stage
        let image: ObjectIdentifier?
        let result: String?
    }

    private var islandUpdate: IslandUpdate? {
        guard scenePhase != .background, mode == .identify, !showLibrary,
              StorageService.shared.accountScope == account else { return nil }
        let stage: LiveActivityService.CameraCard.Stage
        if answer != nil { stage = .result }
        else if isIdentifying { stage = .identifying }
        else if captureID != nil { stage = .capturing }
        else if photo != nil { stage = .captured }
        else { stage = .open }
        return IslandUpdate(stage: stage, image: photo.map(ObjectIdentifier.init), result: answer)
    }

    var body: some View {
        NavigationStack {
            Group {
                if mode == .translateSpeech {
                    VStack(spacing: 0) {
                        cameraHeader
                        ScrollView {
                            VStack(spacing: 16) {
                                speechInput
                                languagePicker
                                requestControls
                            }
                            .padding(16)
                        }
                    }
                    .background(Color(.systemGroupedBackground))
                } else {
                    cameraScreen
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showFullResult) {
                NavigationStack {
                    ScrollView {
                        if let answer { answerCard(answer) }
                    }
                    .padding(16)
                    .navigationTitle(mode == .readText ? "Text from photo" : "Max’s answer")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("Done") { showFullResult = false } }
                    }
                }
            }
            .sheet(item: $saveKind) { kind in
                VisualSaveView(kind: kind, text: answer ?? "", account: account) { savedMessage = $0 }
            }
            .sheet(isPresented: $showAIPrivacy) { AIPrivacyView(scope: account) }
            .confirmationDialog("Analyze this photo with cloud AI?", isPresented: $confirmPhotoUpload, titleVisibility: .visible) {
                Button(mode.label, action: analyze)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Max sends this photo and any question you entered through its server to OpenAI for this request.")
            }
            .photosPicker(isPresented: $showLibrary, selection: $selection, matching: .images)
            .task(id: mode) { await updateCameraPermission() }
            .onChange(of: islandUpdate, initial: true) { _, update in
                if let update {
                    let announce = update.result != nil && announcedAnswer != update.result
                    let presented = LiveActivityService.shared.updateCamera(session: islandSession, stage: update.stage,
                                                                            photo: photo, result: update.result,
                                                                            announce: announce && scenePhase == .active)
                    if announce && presented && scenePhase == .active { announcedAnswer = update.result }
                } else {
                    LiveActivityService.shared.clearCamera(session: islandSession)
                }
            }
            .onChange(of: cameraWanted, initial: true) { _, requested in camera.setRunning(requested) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { cameraAccess = AVCaptureDevice.authorizationStatus(for: .video) }
                if phase == .background { captureID = nil; stopResult() }
            }
            .onChange(of: mode) { _, _ in clearResult(); error = nil }
            .onChange(of: language) { _, _ in clearResult() }
            .onChange(of: question) { _, _ in clearResult() }
            .onChange(of: transcript) { _, _ in clearResult() }
            .onChange(of: selection) { _, item in loadPhoto(item) }
            .onChange(of: auth.currentUser?.storageScope) { _, _ in cancel(); dismiss() }
            .onChange(of: voice.isSpeaking) { _, active in if !active { playingResult = false } }
            .onChange(of: voice.isRecording) { _, active in
                if recording && !active && !busy {
                    recording = false
                    error = "Recording stopped. Try again or enter the words manually."
                }
            }
        }
        .onDisappear(perform: cancel)
        .tint(Color(hex: "#315E73"))
    }

    private var cameraHeader: some View {
        HStack(spacing: 12) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)
            .disabled(busy || recording || captureID != nil)
            .frame(minHeight: 44)
            Spacer()
            Button("Done") { dismiss() }.frame(minHeight: 44)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .background(.regularMaterial)
    }

    private var languagePicker: some View {
        Picker("Translate to", selection: $language) {
            ForEach(languages, id: \.self) { Text($0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .disabled(busy || recording)
    }

    private var cameraScreen: some View {
        GeometryReader { geometry in
            ZStack {
                viewfinder.ignoresSafeArea()
                VStack(spacing: 0) {
                    cameraHeader
                    Spacer(minLength: 12)
                    cameraBottom
                        .frame(maxHeight: geometry.size.height * (dynamicTypeSize.isAccessibilitySize ? 0.68 : 0.46))
                }
            }
        }
        .background(.black)
    }

    private var viewfinder: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .accessibilityLabel("Selected photo")
                } else if cameraWanted && !camera.unavailable {
                    VisualCameraPreview(session: camera.session, device: camera.device)
                        .accessibilityHidden(true)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "camera").font(.title2).accessibilityHidden(true)
                        Text(cameraAccess == .denied || cameraAccess == .restricted
                            ? "Camera access is off. Choose a photo or allow access in Settings."
                            : "Camera unavailable. Choose a photo to continue.")
                            .font(.callout)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .foregroundStyle(.white)
                }
            }
        }
    }

    @ViewBuilder private var cameraBottom: some View {
        if photo == nil {
            VStack(spacing: 10) {
                if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                if busy { ProgressView("Opening photo…") }
                if cameraWanted && !camera.unavailable {
                    Button(action: takePhoto) {
                        Circle().strokeBorder(.white, lineWidth: 3)
                            .frame(width: 64, height: 64)
                            .overlay { Circle().fill(.white).padding(6) }
                    }
                    .buttonStyle(.plain)
                    .disabled(camera.device == nil || busy || captureID != nil)
                    .accessibilityLabel("Take photo")
                }
                photoControls
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
        } else {
            ViewThatFits(in: .vertical) {
                capturedControls
                ScrollView { capturedControls }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollDismissesKeyboard(.interactively)
            }
            .background(.regularMaterial)
        }
    }

    private var capturedControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            photoControls
            if mode == .translatePhoto { languagePicker }
            if answer != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { resultActions }
                    VStack(alignment: .leading, spacing: 4) { resultActions }
                }
                if let savedMessage { Text(savedMessage).font(.footnote) }
            } else {
                requestControls
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder private var resultActions: some View {
        Button("View result") { showFullResult = true }
            .buttonStyle(.borderedProminent)
        Menu("Save", systemImage: "square.and.arrow.down") {
            ForEach(VisualSaveKind.allCases) { kind in
                Button(kind.title) { saveKind = kind }
            }
        }
        .frame(minHeight: 44)
    }

    private var photoControls: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Choose a photo", systemImage: "photo.on.rectangle") { stopResult(); showLibrary = true }
                Spacer()
                if photo != nil {
                    Button("Retake", systemImage: "camera", action: resetPhoto)
                } else if camera.unavailable {
                    Button("Retry camera") { camera.setRunning(cameraWanted) }
                }
            }
            .font(.callout.weight(.semibold))
            .frame(minHeight: 44)

            if mode == .identify && photo != nil && answer == nil {
                TextField("Ask about what you see (optional)", text: $question, axis: .vertical)
                    .lineLimit(1...3)
                    .padding(12)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .disabled(busy || captureID != nil)
    }

    private var requestControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            if mode == .translateSpeech || photo != nil {
                Button(mode == .translateSpeech ? "Translate" : mode.label, action: requestAnalysis)
                    .buttonStyle(.borderedProminent)
                    .disabled(busy || recording || (mode == .translateSpeech &&
                        transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
            if busy && (mode == .translateSpeech || photo == nil || dynamicTypeSize.isAccessibilitySize) {
                ProgressView(mode == .translateSpeech ? "Working…" : "Working on your photo…")
            }
            if let error { Text(error).foregroundStyle(.red) }
            Text(requestNotice)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let answer, mode == .translateSpeech || dynamicTypeSize.isAccessibilitySize {
                answerCard(answer)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var requestNotice: String {
        switch mode {
        case .readText: return "Max reads printed names and labels on this device. Check the spelling against the photo."
        case .identify: return "When you tap Identify, Max sends the selected photo and your question to its AI service. Identifications can be uncertain."
        case .translatePhoto: return "When you tap Translate, Max sends the selected photo to its AI service."
        case .translateSpeech: return "Max sends the reviewed transcript to its AI service for translation."
        }
    }

    private func answerCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if playingResult {
                    OrbView(state: voice.isPreparingSpeech ? .thinking : .speaking, size: 21)
                }
                Text(mode == .readText ? "Text from photo" : "Max’s answer")
                    .font(.caption.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button {
                    if playingResult { stopResult() } else { speakResult(text) }
                } label: {
                    Image(systemName: playingResult ? "stop.fill" : "speaker.wave.2")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(playingResult ? "Stop reading" : "Read aloud")
                if mode == .readText {
                    Button {
                        UIPasteboard.general.string = text
                    } label: {
                        Image(systemName: "document.on.document").frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy recognized text")
                }
            }
            if playingResult, let playbackNotice = voice.playbackNotice {
                Text(playbackNotice).font(.caption)
            }
            ScrollView {
                Text(text).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 420)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.primary)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
    }

    private var speechInput: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(recording ? "Stop and review" : "Record speech",
                   systemImage: recording ? "stop.fill" : "waveform", action: toggleRecording)
                .buttonStyle(.bordered)
                .disabled(busy)
            TextEditor(text: $transcript).frame(minHeight: 100)
                .accessibilityLabel("Transcript to translate")
                .disabled(busy || recording)
            if let notice { Text(notice).font(.footnote).foregroundStyle(.secondary) }
            Text("Ask anyone speaking for permission before recording. Max may send the audio for transcription when you stop. You can also type or paste the words.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func updateCameraPermission() async {
        guard mode != .translateSpeech else { return }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
            guard !Task.isCancelled else { return }
        }
        cameraAccess = AVCaptureDevice.authorizationStatus(for: .video)
    }

    private func takePhoto() {
        guard captureID == nil, cameraWanted else { return }
        let id = UUID()
        captureID = id
        error = nil
        camera.takePhoto { image in
            guard captureID == id, StorageService.shared.accountScope == account else { return }
            captureID = nil
            if let image { photo = image }
            else { error = "Max couldn’t take the photo. Try again or choose one." }
        }
    }

    private func resetPhoto() {
        photo = nil
        selection = nil
        question = ""
        clearResult()
        error = nil
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        run {
            defer { selection = nil }
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                error = "This photo couldn’t be opened."
                return
            }
            try checkScope()
            photo = image
            question = ""
            clearResult()
        }
    }

    private func toggleRecording() {
        if recording {
            run {
                let words = await voice.stopAndTranscribe()
                recording = false
                voice.onRecordingLimit = nil
                try checkScope()
                notice = voice.transcriptionNotice
                guard let words else { error = "Max couldn’t transcribe the speech. Try again or enter the words."; return }
                transcript = words
                answer = nil
            }
        } else {
            guard reviewAIPrivacy() else { return }
            run {
                try await voice.startRecording()
                try checkScope()
                recording = true
                notice = nil
                voice.onRecordingLimit = { if recording && !busy { toggleRecording() } }
            }
        }
    }

    private func reviewAIPrivacy() -> Bool {
        guard StorageService.shared.accountScope == account else { return false }
        guard StorageService.shared.allowsCloudAI(scope: account) else {
            showAIPrivacy = true
            return false
        }
        return true
    }

    private func requestAnalysis() {
        if mode == .readText {
            analyze()
        } else if reviewAIPrivacy() {
            if mode == .translateSpeech { analyze() }
            else { confirmPhotoUpload = true }
        }
    }

    private func analyze() {
        guard mode == .readText || reviewAIPrivacy() else { return }
        let selectedMode = mode
        let target = language
        let text = selectedMode == .translateSpeech ? transcript : (selectedMode == .identify ? question : "")
        clearResult()
        run {
            isIdentifying = selectedMode == .identify
            defer { isIdentifying = false }
            if selectedMode == .readText {
                guard let photo, let image = PhotoUpload.normalizedImage(photo, edge: 2400)?.cgImage else {
                    error = "Choose a photo with the writing in view."
                    return
                }
                let recognized = try await Task.detached(priority: .userInitiated) {
                    try VisualTextRecognition.read(image)
                }.value
                try checkScope()
                guard !recognized.isEmpty else {
                    error = "Max couldn’t read any text. Move closer or try better lighting."
                    return
                }
                answer = recognized
                return
            }

            let jpeg: String?
            if selectedMode == .translateSpeech { jpeg = nil }
            else {
                guard let photo, let encoded = PhotoUpload.jpeg(photo)?.base64EncodedString() else {
                    error = "This photo is too large to analyze. Try a smaller photo."
                    return
                }
                jpeg = encoded
            }
            let session = try await auth.managedSession()
            let proof = await StoreKitService.shared.signedTransactionProof()
            try checkScope()
            guard reviewAIPrivacy() else { return }
            guard session.userID == account,
                  let base = URL(string: kMaxAPIBaseURL), base.scheme == "https", base.host != nil else {
                error = "Visual Intelligence isn’t connected in this build."
                return
            }
            var request = URLRequest(url: base.appendingPathComponent("v1/visual"))
            request.httpMethod = "POST"
            request.timeoutInterval = 50
            request.setValue("Bearer " + session.token, forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(AIProcessingConsent.version, forHTTPHeaderField: AIProcessingConsent.header)
            if let proof { request.setValue(proof, forHTTPHeaderField: "X-Max-Transaction") }
            request.httpBody = try JSONEncoder().encode(Payload(mode: selectedMode.rawValue, text: text, language: target, jpeg: jpeg))
            let (data, response) = try await URLSession.shared.data(for: request)
            try checkScope()
            let result = try? JSONDecoder().decode(Result.self, from: data)
            let status = (response as? HTTPURLResponse)?.statusCode
            if status == 402 && result?.code == "demo_expired" {
                auth.markDemoExpired()
                return
            }
            guard status == 200, let value = result?.answer else {
                error = result?.error ?? "Visual Intelligence isn’t available on this server yet."
                return
            }
            answer = value
            if selectedMode == .identify && StorageService.shared.loadSettings().voiceEnabled {
                speakResult(value)
            }
        }
    }

    private func speakResult(_ text: String) {
        guard StorageService.shared.accountScope == account, scenePhase == .active else { return }
        let preferredVoice = StorageService.shared.loadSettings().preferredVoice
        if mode == .readText { voice.readTextOnDevice(text, preferredVoice: preferredVoice) }
        else { voice.speak(text, preferredVoice: preferredVoice) }
        playingResult = voice.isSpeaking
    }

    private func stopResult() {
        guard playingResult else { return }
        voice.stopSpeaking()
        playingResult = false
    }

    private func clearResult() {
        stopResult()
        announcedAnswer = nil
        savedMessage = nil
        answer = nil
    }

    private func run(_ operation: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true
        error = nil
        work = Task { @MainActor in
            defer { busy = false; work = nil }
            do { try await operation() }
            catch is CancellationError {}
            catch { self.error = error.localizedDescription }
        }
    }

    private func checkScope() throws {
        try Task.checkCancellation()
        guard StorageService.shared.accountScope == account else { throw CancellationError() }
    }

    private func cancel() {
        LiveActivityService.shared.clearCamera(session: islandSession)
        captureID = nil
        camera.setRunning(false)
        work?.cancel()
        stopResult()
        if mode == .translateSpeech && (recording || busy) {
            voice.onRecordingLimit = nil
            voice.stopRecording()
        }
    }

    private struct Payload: Encodable {
        let mode: String
        let text: String
        let language: String
        let jpeg: String?
    }

    private struct Result: Decodable {
        let answer: String?
        let error: String?
        let code: String?
    }
}

enum VisualTextRecognition {
    static func read(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
