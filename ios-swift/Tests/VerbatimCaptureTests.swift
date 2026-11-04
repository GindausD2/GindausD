import XCTest
import AVFoundation
@testable import Max

final class VerbatimCaptureTests: XCTestCase {
    private func input() -> AVAudioPCMBuffer {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 2, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000)!
        buffer.frameLength = 48000
        for channel in 0..<2 {
            for frame in 0..<48000 { buffer.floatChannelData![channel][frame] = Float(sin(Double(frame) * 2 * .pi * 440 / 48000) * 0.2) }
        }
        return buffer
    }

    func testCaptureResamplesStereoToBoundedMonoPCM16Wave() throws {
        let buffer = input()
        let capture = try XCTUnwrap(VerbatimAudioCapture(inputFormat: buffer.format))
        XCTAssertFalse(capture.append(buffer))
        let wav = try XCTUnwrap(capture.finish())
        XCTAssertEqual(String(data: wav.prefix(4), encoding: .ascii), "RIFF")
        XCTAssertEqual(String(data: wav[8..<16], encoding: .ascii), "WAVEfmt ")
        let bytes = [UInt8](wav)
        func u32(_ offset: Int) -> Int { (0..<4).reduce(0) { $0 | Int(bytes[offset + $1]) << ($1 * 8) } }
        XCTAssertEqual(bytes[22], 1)
        XCTAssertEqual(u32(24), 16000)
        XCTAssertEqual(bytes[34], 16)
        XCTAssertEqual(u32(40), wav.count - 44)
        XCTAssertEqual(Double(wav.count - 44) / 32000, 1, accuracy: 0.02)
        XCTAssertTrue(wav.dropFirst(44).contains { $0 != 0 })
        XCTAssertNil(capture.finish())
    }

    func testCaptureLimitIsBoundedAndSignalsOnlyOnce() throws {
        let buffer = input()
        let capture = try XCTUnwrap(VerbatimAudioCapture(inputFormat: buffer.format, maxSeconds: 0.1))
        XCTAssertTrue(capture.append(buffer))
        XCTAssertFalse(capture.append(buffer))
        XCTAssertEqual(try XCTUnwrap(capture.finish()).count, 3244)
    }

    func testCancelDiscardsAudioAndRejectsLateBuffers() throws {
        let buffer = input()
        let capture = try XCTUnwrap(VerbatimAudioCapture(inputFormat: buffer.format))
        _ = capture.append(buffer)
        capture.cancel()
        XCTAssertFalse(capture.append(buffer))
        XCTAssertNil(capture.finish())
    }
}

@MainActor
final class SpeechRecognitionFinishTests: XCTestCase {
    func testFinalResultAfterOld250msWindowIsWaitedFor() async {
        let finish = SpeechRecognitionFinish()
        var receivedFinal = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            receivedFinal = true
            finish.complete()
        }
        await finish.wait()
        XCTAssertTrue(receivedFinal)
        finish.complete() // No duplicate continuation resume.
    }

    func testMissingFinalCallbackHasBoundedTimeout() async {
        let finish = SpeechRecognitionFinish()
        await finish.wait(timeout: .milliseconds(20))
        finish.complete()
    }

    func testCancellationUnblocksWaiter() async {
        let finish = SpeechRecognitionFinish()
        let pending = Task { await finish.wait(timeout: .seconds(30)) }
        await Task.yield()
        pending.cancel()
        await pending.value
        finish.complete()
    }
}
