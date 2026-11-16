import AVFoundation
import Combine
import Foundation

@MainActor
final class ThoughtCapture: ObservableObject {
    @Published private(set) var recording = false
    @Published private(set) var starting = false
    @Published var error: String?
    @Published private(set) var transcript = ""
    #if os(iOS)
    private var previewSubscription: AnyCancellable?
    private var interruptionSubscription: AnyCancellable?
    #endif
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var recordingFile: URL?
    private var limit: Task<Void, Never>?

    func start(onLimit: @escaping @MainActor () -> Void) async {
        guard recorder == nil, !starting else { return }
        starting = true
        defer { starting = false }
        error = nil
        transcript = ""
        #if os(iOS)
        let voice = VoiceService.shared
        voice.onUtteranceEnd = nil
        voice.onRecordingLimit = onLimit
        do {
            try await voice.startRecording(localOnly: true)
            voice.onThoughtInterruption = onLimit
            previewSubscription = voice.transcriptUpdates.sink { [weak self] in self?.transcript = $0 }
            interruptionSubscription = voice.recordingUpdates.dropFirst().sink { [weak self] active in
                if !active, self?.recording == true { self?.recording = false }
            }
            error = voice.transcriptionNotice
            recording = true
            limit = Task {
                do { try await Task.sleep(for: .seconds(60)) }
                catch { return }
                onLimit()
            }
        } catch is CancellationError {
            return
        } catch {
            self.error = error.localizedDescription
        }
        #else
        guard await AVAudioApplication.requestRecordPermission(), !Task.isCancelled else {
            error = "Allow microphone access to record a thought."
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        do {
            let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 16000,
                                              AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 24000]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            guard recorder.record(forDuration: 60) else { throw CocoaError(.fileWriteUnknown) }
            self.recorder = recorder
            recordingFile = url
            recording = true
            limit = Task {
                do { try await Task.sleep(for: .seconds(60)) }
                catch { return }
                onLimit()
            }
        } catch {
            try? FileManager.default.removeItem(at: url)
            self.error = "Max couldn’t start recording."
        }
        #endif
    }

    func finish() -> Data? {
        limit?.cancel()
        limit = nil
        #if os(iOS)
        guard previewSubscription != nil else { return nil }
        previewSubscription = nil
        interruptionSubscription = nil
        recording = false
        let data = VoiceService.shared.finishThoughtAudio()
        VoiceService.shared.onRecordingLimit = nil
        return data.flatMap { compressedAudio($0) }
        #else
        recorder?.stop()
        recorder = nil
        recording = false
        guard let url = recordingFile else { return nil }
        recordingFile = nil
        defer { try? FileManager.default.removeItem(at: url) }
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            self.error = "Max couldn’t read the recording."
            return nil
        }
        return data
        #endif
    }

    #if os(iOS)
    private func compressedAudio(_ wave: Data) -> Data? {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let source = temporary.appendingPathExtension("wav")
        let destination = temporary.appendingPathExtension("m4a")
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: destination)
        }
        do {
            try wave.write(to: source)
            let input = try AVAudioFile(forReading: source)
            let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 16000,
                                          AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 24000]
            do {
                let output = try AVAudioFile(forWriting: destination, settings: settings)
                guard let buffer = AVAudioPCMBuffer(pcmFormat: input.processingFormat, frameCapacity: 4096) else { return wave }
                while input.framePosition < input.length {
                    try input.read(into: buffer)
                    guard buffer.frameLength > 0 else { break }
                    try output.write(from: buffer)
                }
            }
            return try Data(contentsOf: destination)
        } catch { return wave }
    }
    #endif

    func play(_ audio: Data) {
        do {
            player = try AVAudioPlayer(data: audio)
            if player?.play() != true { throw CocoaError(.fileReadUnknown) }
        } catch { self.error = "Max couldn’t play this recording." }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
    }
}
