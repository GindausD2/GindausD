import AVFoundation
import Foundation

/// The audio tap owns conversion; a lock protects its bounded, in-memory PCM
/// from a simultaneous Finish/Cancel. Audio is never written to a local file.
final class VerbatimAudioCapture: @unchecked Sendable {
    static let sampleRate = 16_000.0
    private let lock = NSLock()
    private let converter: AVAudioConverter
    private let format: AVAudioFormat
    private let maxBytes: Int
    private var pcm = Data()
    private var failed = false
    private var closed = false
    private(set) var limitReached = false

    init?(inputFormat: AVAudioFormat, maxSeconds: Double = 120) {
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0,
              let target = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Self.sampleRate, channels: 1, interleaved: true),
              let converter = AVAudioConverter(from: inputFormat, to: target) else { return nil }
        self.converter = converter
        self.format = target
        self.maxBytes = Int(Self.sampleRate * maxSeconds) * 2
    }

    /// Returns true only when this buffer first reaches the two-minute limit.
    func append(_ input: AVAudioPCMBuffer) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !closed, !failed, !limitReached else { return false }
        let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * Self.sampleRate / input.format.sampleRate)) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { failed = true; return false }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            guard !supplied else { inputStatus.pointee = .noDataNow; return nil }
            supplied = true
            inputStatus.pointee = .haveData
            return input
        }
        guard error == nil, status != .error else { failed = true; return false }
        collect(output)
        return limitReached
    }

    func finish() -> Data? {
        lock.lock(); defer { lock.unlock() }
        guard !closed else { return nil }
        closed = true
        // Drain the converter's final samples instead of dropping the audio tail.
        if !failed && !limitReached {
            for _ in 0..<8 {
                guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024) else { failed = true; break }
                var error: NSError?
                let status = converter.convert(to: output, error: &error) { _, inputStatus in
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                if error != nil || status == .error { failed = true; break }
                collect(output)
                if status == .endOfStream || output.frameLength == 0 || limitReached { break }
            }
        }
        defer { pcm.removeAll(keepingCapacity: false) }
        guard !failed, pcm.count >= 3200 else { return nil }
        return Self.wave(pcm)
    }

    func cancel() {
        lock.lock(); defer { lock.unlock() }
        closed = true
        pcm.removeAll(keepingCapacity: false)
    }

    private func collect(_ buffer: AVAudioPCMBuffer) {
        guard buffer.frameLength > 0, let samples = buffer.int16ChannelData else { return }
        let count = min(Int(buffer.frameLength) * 2, maxBytes - pcm.count)
        if count > 0 { pcm.append(UnsafeRawPointer(samples[0]).assumingMemoryBound(to: UInt8.self), count: count) }
        if pcm.count >= maxBytes { limitReached = true }
    }

    static func wave(_ pcm: Data) -> Data {
        var data = Data()
        func ascii(_ value: String) { data.append(contentsOf: value.utf8) }
        func u16(_ value: UInt16) { var le = value.littleEndian; withUnsafeBytes(of: &le) { data.append(contentsOf: $0) } }
        func u32(_ value: UInt32) { var le = value.littleEndian; withUnsafeBytes(of: &le) { data.append(contentsOf: $0) } }
        ascii("RIFF"); u32(UInt32(36 + pcm.count)); ascii("WAVEfmt "); u32(16)
        u16(1); u16(1); u32(16000); u32(32000); u16(2); u16(16)
        ascii("data"); u32(UInt32(pcm.count)); data.append(pcm)
        return data
    }
}

/// Finish waits for an actual final recognition callback, with a bounded fallback.
/// Every path resumes its waiter once, including interruption and cancellation.
@MainActor
final class SpeechRecognitionFinish {
    private var finished = false
    private var waiter: CheckedContinuation<Void, Never>?
    private var deadline: Task<Void, Never>?

    func complete() {
        finished = true
        deadline?.cancel(); deadline = nil
        let pending = waiter; waiter = nil
        pending?.resume()
    }

    func wait(timeout: Duration = .seconds(2)) async {
        guard !finished, !Task.isCancelled else { return }
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if finished || Task.isCancelled { continuation.resume(); return }
                waiter = continuation
                deadline = Task { @MainActor [weak self] in
                    do { try await Task.sleep(for: timeout) } catch { return }
                    self?.complete()
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.complete() }
        }
    }
}
