import AVFoundation
import Combine
import Foundation

@MainActor
final class ThoughtCapture: ObservableObject {
    @Published private(set) var recording = false
    @Published private(set) var starting = false
    @Published var error: String?
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var recordingFile: URL?
    private var limit: Task<Void, Never>?
    private var ownsAudioSession = false

    func start(onLimit: @escaping @MainActor () -> Void) async {
        guard recorder == nil, !starting else { return }
        starting = true
        defer { starting = false }
        error = nil
        guard await AVAudioApplication.requestRecordPermission(), !Task.isCancelled else {
            error = "Allow microphone access to record a thought."
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        do {
            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
            ownsAudioSession = true
            #endif
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
            releaseAudioSession()
            try? FileManager.default.removeItem(at: url)
            error = "Max couldn’t start recording."
        }
    }

    func finish() -> Data? {
        limit?.cancel()
        limit = nil
        recorder?.stop()
        recorder = nil
        releaseAudioSession()
        recording = false
        guard let url = recordingFile else { return nil }
        recordingFile = nil
        defer { try? FileManager.default.removeItem(at: url) }
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            error = "Max couldn’t read the recording."
            return nil
        }
        return data
    }

    private func releaseAudioSession() {
        #if os(iOS)
        if ownsAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            ownsAudioSession = false
        }
        #endif
    }

    func play(_ audio: Data) {
        do {
            player = try AVAudioPlayer(data: audio)
            if player?.play() != true { throw CocoaError(.fileReadUnknown) }
        } catch { error = "Max couldn’t play this recording." }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
    }
}
