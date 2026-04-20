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

        speechSynthesizer.speak(utterance)
        isSpeaking = true
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
        s = s.replacingOccurrences(of: #"^\s*[-•]\s"#,  with: "", options: [.regularExpression, .anchorsMatchLines])
        s = s.replacingOccurrences(of: #"^\s*\d+\.\s"#, with: "", options: [.regularExpression, .anchorsMatchLines])
        // Links [label](url) → label
        s = s.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
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
