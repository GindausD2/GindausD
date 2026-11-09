import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

struct VisualIntelligenceView: View {
    private enum Mode: String, CaseIterable {
        case identify, translatePhoto, translateSpeech

        var label: String {
            switch self {
            case .identify: return "Identify"
            case .translatePhoto: return "Read text"
            case .translateSpeech: return "Speech"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthService
    @ObservedObject private var voice = VoiceService.shared
    @State private var mode: Mode = .identify
    @State private var showCamera = false
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
    let account: String

    private let languages = ["English", "Hausa", "French", "Arabic", "Spanish", "German",
                             "Portuguese", "Chinese", "Japanese", "Korean"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                }.disabled(busy || recording)
                if mode == .translateSpeech { speechInput }
                else { photoInput }
                if mode != .identify {
                    Picker("Translate to", selection: $language) {
                        ForEach(languages, id: \.self) { Text($0) }
                    }.disabled(busy || recording)
                }
                Section {
                    Button(mode == .identify ? "Analyze photo" : "Translate", action: analyze)
                        .disabled(busy || recording || (mode == .translateSpeech
                            ? transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : photo == nil))
                    if busy { ProgressView("Working…") }
                    if let error { Text(error).foregroundStyle(.red) }
                } footer: {
                    Text("Max sends only the selected photo and question, or the reviewed transcript, for this request. Results can be uncertain.")
                }
                if let answer { Section("Max’s answer") { Text(answer).textSelection(.enabled) } }
            }
            .navigationTitle("Visual Intelligence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView(selectedImage: $photo, isPresented: $showCamera).ignoresSafeArea()
            }
            .onChange(of: mode) { _, _ in answer = nil; error = nil }
            .onChange(of: language) { _, _ in answer = nil }
            .onChange(of: selection) { _, item in loadPhoto(item) }
            .onChange(of: auth.currentUser?.storageScope) { _, _ in cancel(); dismiss() }
            .onChange(of: voice.isRecording) { _, active in
                if recording && !active && !busy {
                    recording = false
                    error = "Recording stopped. Try again or enter the words manually."
                }
            }
            .onDisappear(perform: cancel)
        }
        .tint(Color(hex: "#315E73"))
    }

    private var photoInput: some View {
        Section("What are you looking at?") {
            Button("Open camera", systemImage: "camera", action: openCamera)
            PhotosPicker(selection: $selection, matching: .images) { Label("Choose a photo", systemImage: "photo") }
            if let photo {
                Image(uiImage: photo).resizable().scaledToFit().frame(maxHeight: 250)
                    .accessibilityLabel("Selected photo")
            }
            if mode == .identify {
                TextField("Ask about the photo (optional)", text: $question, axis: .vertical)
            }
        }.disabled(busy)
    }

    private var speechInput: some View {
        Section {
            Button(recording ? "Stop and review" : "Record speech",
                   systemImage: recording ? "stop.fill" : "mic", action: toggleRecording)
                .disabled(busy)
            TextEditor(text: $transcript).frame(minHeight: 100)
                .accessibilityLabel("Transcript to translate")
                .disabled(busy || recording)
            if let notice { Text(notice).font(.footnote).foregroundStyle(.secondary) }
        } header: {
            Text("Review the words before translating")
        } footer: {
            Text("Use the microphone with permission from anyone speaking. Max may send the recording for transcription when you stop it. You can also type or paste the words.")
        }
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            error = "This device doesn’t have a camera available. Choose a photo instead."
            return
        }
        run {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            let allowed = status == .notDetermined ? await AVCaptureDevice.requestAccess(for: .video) : status == .authorized
            try checkScope()
            guard allowed else { error = "Allow camera access in iPhone Settings, or choose a photo."; return }
            answer = nil
            showCamera = true
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        run {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                error = "This photo couldn’t be opened."
                return
            }
            try checkScope()
            photo = image
            answer = nil
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
            run {
                try await voice.startRecording()
                try checkScope()
                recording = true
                notice = nil
                voice.onRecordingLimit = { if recording && !busy { toggleRecording() } }
            }
        }
    }

    private func analyze() {
        let selectedMode = mode
        let target = language
        let text = selectedMode == .translateSpeech ? transcript : (selectedMode == .identify ? question : "")
        answer = nil
        run {
            let jpeg: String?
            if selectedMode == .translateSpeech { jpeg = nil }
            else {
                guard let photo, let encoded = Self.boundedJPEG(photo) else {
                    error = "This photo is too large to analyze. Try a smaller photo."
                    return
                }
                jpeg = encoded
            }
            let session = try await auth.managedSession()
            let proof = await StoreKitService.shared.signedTransactionProof()
            try checkScope()
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
            if let proof { request.setValue(proof, forHTTPHeaderField: "X-Max-Transaction") }
            request.httpBody = try JSONEncoder().encode(Payload(mode: selectedMode.rawValue, text: text, language: target, jpeg: jpeg))
            let (data, response) = try await URLSession.shared.data(for: request)
            try checkScope()
            let result = try? JSONDecoder().decode(Result.self, from: data)
            guard (response as? HTTPURLResponse)?.statusCode == 200, let value = result?.answer else {
                error = result?.error ?? "Visual Intelligence isn’t available on this server yet."
                return
            }
            answer = value
        }
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
        work?.cancel()
        if mode == .translateSpeech && (recording || busy) {
            voice.onRecordingLimit = nil
            voice.stopRecording()
        }
    }

    private static func boundedJPEG(_ image: UIImage) -> String? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        for edge in [CGFloat(1280), 960, 720] {
            let ratio = min(1, edge / longest)
            let size = CGSize(width: max(1, image.size.width * ratio), height: max(1, image.size.height * ratio))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            if let data = normalized.jpegData(compressionQuality: 0.75), data.count <= 300_000 {
                return data.base64EncodedString()
            }
        }
        return nil
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
    }
}
