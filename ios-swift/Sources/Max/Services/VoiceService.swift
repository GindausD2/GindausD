import Foundation
import AVFoundation
import Combine

@MainActor
final class VoiceService: NSObject, ObservableObject {
    static let shared = VoiceService()

    @Published var isRecording: Bool = false
    @Published var isSpeaking: Bool = false

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private let speechSynthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
        speechSynthesizer.delegate = self
    }

    // MARK: - Recording

    func startRecording() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("max_recording_\(UUID().uuidString).m4a")
        self.recordingURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
        recorder.prepareToRecord()
        recorder.record()
        self.audioRecorder = recorder
        self.isRecording = true
    }

    func stopAndTranscribe(apiKey: String) async -> String? {
        guard let recorder = audioRecorder else { return nil }
        recorder.stop()
        audioRecorder = nil
        isRecording = false

        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false)

        guard let fileURL = recordingURL,
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        defer {
            try? FileManager.default.removeItem(at: fileURL)
            recordingURL = nil
        }

        do {
            let audioData = try Data(contentsOf: fileURL)
            let base64Audio = audioData.base64EncodedString()
            return try await transcribeAudio(base64Audio: base64Audio, mimeType: "audio/mp4", apiKey: apiKey)
        } catch {
            print("[VoiceService] Transcription error: \(error)")
            return nil
        }
    }

    private func transcribeAudio(base64Audio: String, mimeType: String, apiKey: String) async throws -> String? {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "claude-haiku-4-5",
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "document",
                            "source": [
                                "type": "base64",
                                "media_type": mimeType,
                                "data": base64Audio
                            ]
                        ],
                        [
                            "type": "text",
                            "text": "Transcribe exactly what was said. Output only the transcription."
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            return nil
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        recordingURL = nil

        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false)
    }

    // MARK: - Speech Synthesis

    func speak(_ text: String) {
        stopSpeaking()

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.1
        utterance.volume = 1.0

        speechSynthesizer.speak(utterance)
        isSpeaking = true
    }

    func stopSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}
