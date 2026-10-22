import Foundation
import UIKit
import AVFoundation
import Combine
import Speech

@MainActor
protocol VoiceCapturing: AnyObject {
    var transcriptUpdates: AnyPublisher<String, Never> { get }
    var recordingUpdates: AnyPublisher<Bool, Never> { get }
    var currentTranscript: String { get }
    var onUtteranceEnd: (() -> Void)? { get set }
    func startRecording() async throws
    func stopAndTranscribe() async -> String?
    func stopRecording()
}

@MainActor
final class VoiceService: NSObject, ObservableObject, VoiceCapturing {
    static let shared = VoiceService()

    @Published var isRecording: Bool = false
    @Published var isSpeaking: Bool = false
    @Published private(set) var isPreparingSpeech = false
    @Published private(set) var playbackNotice: String?

    @Published private(set) var transcript: String = ""
    var transcriptUpdates: AnyPublisher<String, Never> { $transcript.eraseToAnyPublisher() }
    var recordingUpdates: AnyPublisher<Bool, Never> { $isRecording.eraseToAnyPublisher() }
    var currentTranscript: String { transcript }
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var inputTapInstalled = false
    private var silenceTask: Task<Void, Never>?
    private var recognitionID = UUID()
    var onUtteranceEnd: (() -> Void)?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    private let speakingFeedback = UIImpactFeedbackGenerator(style: .soft)
    private var lastHapticAt: TimeInterval = 0
    private var cloudSpeechTask: Task<Void, Never>?
    private var playbackID = UUID()
    private var audioPlayer: AVAudioPlayer?
    private var cloudHapticsTask: Task<Void, Never>?
    private var interruptionSubscriptions: Set<AnyCancellable> = []

    private override init() {
        super.init()
        speechSynthesizer.delegate = self
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in
                self?.stopRecording(); self?.stopSpeaking()
            }.store(in: &interruptionSubscriptions)
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in
                self?.stopRecording(); self?.stopSpeaking()
            }.store(in: &interruptionSubscriptions)
    }

    // MARK: - Native speech recognition

    func startRecording() async throws {
        stopSpeaking()
        stopRecording()
        let permissionID = recognitionID
        let micAllowed = await AVAudioApplication.requestRecordPermission()
        guard recognitionID == permissionID, !Task.isCancelled else { throw CancellationError() }
        guard micAllowed else { throw VoiceError.microphoneDenied }
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard recognitionID == permissionID, !Task.isCancelled else { throw CancellationError() }
        guard speechStatus == .authorized else { throw VoiceError.speechDenied }
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current), recognizer.isAvailable else { throw VoiceError.unavailable }
        guard UIApplication.shared.applicationState != .background else { throw VoiceError.unavailable }
        transcript = ""
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try session.setActive(true)
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        recognitionRequest = request
        let thisRecognition = UUID(); recognitionID = thisRecognition
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard self?.recognitionID == thisRecognition else { return }
                if let result, let self {
                    self.transcript = result.bestTranscription.formattedString
                    self.silenceTask?.cancel()
                    if self.isRecording, self.onUtteranceEnd != nil, !self.transcript.isEmpty {
                        self.silenceTask = Task { @MainActor [weak self] in
                            do { try await Task.sleep(for: .seconds(2)) } catch { return }
                            if self?.isRecording == true { self?.onUtteranceEnd?() }
                        }
                    }
                }
                // Partial results remain available when the recognizer ends a turn.
                if error != nil, result == nil { self?.stopRecording() }
            }
        }
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { stopRecording(); throw VoiceError.unavailable }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
        inputTapInstalled = true
        do { audioEngine.prepare(); try audioEngine.start(); isRecording = true }
        catch { stopRecording(); throw error }
    }

    func stopAndTranscribe() async -> String? {
        guard recognitionRequest != nil else { return nil }
        let finishingID = recognitionID
        audioEngine.stop()
        if inputTapInstalled { audioEngine.inputNode.removeTap(onBus: 0); inputTapInstalled = false }
        recognitionRequest?.endAudio()
        isRecording = false
        // Allow the recognizer's final partial result to arrive without another API call.
        try? await Task.sleep(for: .milliseconds(250))
        guard recognitionID == finishingID, !Task.isCancelled else { return nil }
        let result = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        stopRecording()
        return result.isEmpty ? nil : result
    }

    func stopRecording() {
        recognitionID = UUID()
        silenceTask?.cancel(); silenceTask = nil
        audioEngine.stop()
        if inputTapInstalled { audioEngine.inputNode.removeTap(onBus: 0); inputTapInstalled = false }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: - Speech Synthesis

    func speak(_ text: String, preferredVoice: String = "female") {
        stopSpeaking()

        let clean = cleanForSpeech(text)
        guard !clean.isEmpty else { return }

        let settings = StorageService.shared.loadSettings()
        if (settings.voiceProvider ?? "openai") == "openai", clean.utf16.count <= 1000,
           !kMaxAPIBaseURL.isEmpty, AuthService.shared.currentUser != nil {
            let attempt = playbackID
            let scope = StorageService.shared.accountScope
            isSpeaking = true; isPreparingSpeech = true; playbackNotice = nil
            cloudSpeechTask = Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let session = try await AuthService.shared.managedSession()
                    guard let base = URL(string: kMaxAPIBaseURL), base.scheme == "https", base.host != nil else { throw URLError(.badURL) }
                    var request = URLRequest(url: base.appendingPathComponent("v1/speech"))
                    request.httpMethod = "POST"; request.timeoutInterval = 45
                    request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    if let proof = await StoreKitService.shared.signedTransactionProof() {
                        request.setValue(proof, forHTTPHeaderField: "X-Max-Transaction")
                    }
                    let selected = ["marin", "cedar"].contains(settings.openAIVoice ?? "") ? settings.openAIVoice! : "marin"
                    request.httpBody = try JSONEncoder().encode(["text": clean, "voice": selected])
                    let (data, response) = try await URLSession.shared.data(for: request)
                    try Task.checkCancellation()
                    guard self.playbackID == attempt, StorageService.shared.accountScope == scope,
                          UIApplication.shared.applicationState == .active else { return }
                    guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                    if http.statusCode == 402 {
                        let error = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                        if error?["code"] as? String == "demo_expired" {
                            AuthService.shared.markDemoExpired()
                            return
                        }
                        if error?["code"] as? String == "subscription_required" {
                            self.stopSpeaking()
                            await StoreKitService.shared.refreshEntitlements()
                            return
                        }
                    }
                    guard http.statusCode == 200, http.mimeType == "audio/wav", data.count <= 4_320_044 else { throw URLError(.badServerResponse) }
                    let audioSession = AVAudioSession.sharedInstance()
                    try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                    try audioSession.setActive(true)
                    let player = try AVAudioPlayer(data: data)
                    self.audioPlayer = player; player.delegate = self
                    player.prepareToPlay()
                    guard player.play() else { throw URLError(.cannotDecodeContentData) }
                    self.isPreparingSpeech = false
                    self.cloudHapticsTask = Task { @MainActor [weak self, weak player] in
                        while !Task.isCancelled, let self, player?.isPlaying == true, self.playbackID == attempt {
                            if UIApplication.shared.applicationState == .active,
                               StorageService.shared.loadSettings().speakingHapticsEnabled ?? true {
                                self.speakingFeedback.impactOccurred(intensity: 0.35)
                            }
                            do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
                        }
                    }
                } catch {
                    guard !Task.isCancelled, self.playbackID == attempt,
                          StorageService.shared.accountScope == scope,
                          UIApplication.shared.applicationState == .active else { return }
                    self.isPreparingSpeech = false
                    self.playbackNotice = "Using iPhone voice"
                    self.speakOnDevice(clean, preferredVoice: preferredVoice)
                }
            }
        } else {
            playbackNotice = nil
            speakOnDevice(clean, preferredVoice: preferredVoice)
        }
    }

    private func speakOnDevice(_ clean: String, preferredVoice: String) {

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: clean)

        let gender: AVSpeechSynthesisVoiceGender = preferredVoice == "male" ? .male : .female
        let voice = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") && $0.gender == gender }
            .sorted {
                let rank: (AVSpeechSynthesisVoice) -> Int = {
                    switch $0.quality {
                    case .premium:  return 2
                    case .enhanced: return 1
                    default:        return 0
                    }
                }
                return rank($0) > rank($1)
            }
            .first ?? AVSpeechSynthesisVoice(language: "en-US")

        utterance.voice = voice
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.05
        utterance.volume = 1.0

        currentUtterance = utterance
        lastHapticAt = 0
        speakingFeedback.prepare()
        isSpeaking = true
        speechSynthesizer.speak(utterance)
    }

    // MARK: - Markdown Stripper

    private func cleanForSpeech(_ text: String) -> String {
        var s = text
        // Bold / italic
        s = s.replacingOccurrences(of: "**", with: "")
        s = s.replacingOccurrences(of: "__", with: "")
        s = s.replacingOccurrences(of: "*",  with: "")
        s = s.replacingOccurrences(of: "_",  with: "")
        // Headings
        s = s.replacingOccurrences(of: #"#{1,6}\s"#, with: "", options: .regularExpression)
        // Code fences → "code block"
        s = s.replacingOccurrences(of: #"```[\s\S]*?```"#, with: "code block", options: .regularExpression)
        s = s.replacingOccurrences(of: "`", with: "")
        // Bullet / numbered list markers
        s = s.replacingOccurrences(of: #"(?m)^\s*[-•]\s"#,  with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"(?m)^\s*\d+\.\s"#, with: "", options: .regularExpression)
        // Links [label](url) → label
        s = s.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func stopSpeaking() {
        playbackID = UUID()
        cloudSpeechTask?.cancel(); cloudSpeechTask = nil
        cloudHapticsTask?.cancel(); cloudHapticsTask = nil
        audioPlayer?.stop(); audioPlayer = nil
        isPreparingSpeech = false; playbackNotice = nil
        currentUtterance = nil
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        if !isRecording { try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation]) }
    }
}

extension VoiceService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard self.audioPlayer === player else { return }
            self.stopSpeaking()
        }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            guard self.audioPlayer === player else { return }
            self.stopSpeaking()
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.currentUtterance === utterance, self.isSpeaking,
                  UIApplication.shared.applicationState == .active,
                  StorageService.shared.loadSettings().speakingHapticsEnabled ?? true else { return }
            let now = ProcessInfo.processInfo.systemUptime
            guard now - self.lastHapticAt >= 0.65 else { return }
            self.lastHapticAt = now
            self.speakingFeedback.impactOccurred(intensity: 0.35)
            self.speakingFeedback.prepare()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.currentUtterance === utterance else { return }
            self.stopSpeaking()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.currentUtterance === utterance else { return }
            self.stopSpeaking()
        }
    }
}

private enum VoiceError: LocalizedError {
    case microphoneDenied, speechDenied, unavailable
    var errorDescription: String? {
        switch self {
        case .microphoneDenied: return "Allow microphone access in iPhone Settings to talk to Max."
        case .speechDenied: return "Allow speech recognition in iPhone Settings to talk to Max."
        case .unavailable: return "Speech recognition is unavailable right now. Please type your message."
        }
    }
}
