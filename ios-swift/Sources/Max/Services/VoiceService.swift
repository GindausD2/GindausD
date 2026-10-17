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

    private override init() {
        super.init()
        speechSynthesizer.delegate = self
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
        currentUtterance = nil
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
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
            self.currentUtterance = nil
            self.isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.currentUtterance === utterance else { return }
            self.currentUtterance = nil
            self.isSpeaking = false
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
