import XCTest
import Combine
@testable import Max

@MainActor
final class VoiceToTextTests: XCTestCase {
    private func settle(until ready: () -> Bool) async {
        for _ in 0..<100 {
            if ready() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(ready(), "Voice input state did not settle")
    }
    private func isolated(_ body: () async throws -> Void) async rethrows {
        let store = StorageService.shared
        let previous = store.accountScope
        let scope = "dictation-" + UUID().uuidString
        store.setAccountScope(scope)
        defer {
            for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("max.account.\(scope).") { UserDefaults.standard.removeObject(forKey: key) }
            store.setAccountScope(previous)
        }
        try await body()
    }

    func testDictationShowsPartialWordsAndCreatesEditableDraftWithoutSending() async throws {
        await isolated {
            let capture = TestVoiceCapture()
            let model = HomeViewModel(capture: capture)
            model.loadMessages()
            model.inputText = "Please"
            model.handleMicTap()
            await settle { model.conversationState == .listening }
            XCTAssertTrue(model.isDictating)
            XCTAssertEqual(model.conversationState, .listening)
            capture.text = "remind me"
            XCTAssertEqual(model.liveTranscript, "remind me")
            capture.text = "remind me to call David"
            capture.result = "remind me to call David"
            model.sendTextMessage() // Sending while recording must do nothing.
            XCTAssertTrue(model.messages.isEmpty)
            model.handleOrbTap() // The orb's Finish voice input action also creates a draft.
            await settle { !model.isDictating }
            XCTAssertEqual(model.inputText, "Please remind me to call David")
            XCTAssertTrue(model.prefersTextReplyForDraft)
            XCTAssertFalse(model.isDictating)
            XCTAssertEqual(model.conversationState, .idle)
            XCTAssertTrue(model.messages.isEmpty)
            XCTAssertTrue(StorageService.shared.loadMessages().isEmpty)
            XCTAssertNil(capture.onUtteranceEnd) // Dictation does not automatically send on silence.
            model.inputText = "Edited words"
            XCTAssertTrue(model.prefersTextReplyForDraft)
        }
    }

    func testCancelDiscardsPartialWordsAndLateFinalResult() async throws {
        await isolated {
            let capture = TestVoiceCapture()
            capture.finishDelay = .milliseconds(100)
            let model = HomeViewModel(capture: capture)
            model.loadMessages(); model.inputText = "Keep my draft"
            model.handleMicTap(); await settle { model.conversationState == .listening }
            capture.text = "do not send"; capture.result = "late words"
            model.handleMicTap()
            model.endConversation()
            try? await Task.sleep(for: .milliseconds(150))
            XCTAssertEqual(model.inputText, "Keep my draft")
            XCTAssertFalse(model.isDictating); XCTAssertFalse(model.isTranscribing)
            XCTAssertFalse(capture.recording)
            XCTAssertTrue(model.liveTranscript.isEmpty)
            XCTAssertTrue(model.messages.isEmpty)
        }
    }

    func testPermissionFailurePreservesDraftWithoutSavingAnErrorConversation() async throws {
        await isolated {
            let capture = TestVoiceCapture()
            capture.denied = true
            let model = HomeViewModel(capture: capture)
            model.loadMessages(); model.inputText = "Keep this"
            model.handleMicTap(); await settle { !model.isDictating }
            XCTAssertFalse(model.isDictating)
            XCTAssertEqual(model.inputText, "Keep this")
            XCTAssertNotNil(model.dictationError)
            XCTAssertTrue(model.messages.isEmpty)
            XCTAssertEqual(model.conversationState, .idle)
        }
    }

    func testCancelWhilePermissionIsPendingCannotOpenMicrophoneLater() async throws {
        await isolated {
            let capture = TestVoiceCapture()
            capture.startDelay = .milliseconds(100)
            let model = HomeViewModel(capture: capture)
            model.loadMessages(); model.inputText = "Keep this draft"
            model.handleMicTap()
            model.endConversation()
            try? await Task.sleep(for: .milliseconds(150))
            XCTAssertFalse(model.isDictating)
            XCTAssertFalse(capture.recording)
            XCTAssertEqual(model.conversationState, .idle)
            XCTAssertEqual(model.inputText, "Keep this draft")
            XCTAssertNil(model.dictationError)
        }
    }

    func testFinalTranscriptionCannotCrossAccounts() async throws {
        await isolated {
            let store = StorageService.shared
            let capture = TestVoiceCapture()
            let model = HomeViewModel(capture: capture)
            model.loadMessages(); model.inputText = "Private draft"
            model.handleMicTap(); await settle { model.conversationState == .listening }
            capture.result = "Private spoken words"
            store.setAccountScope("dictation-other-account")
            model.handleMicTap(); await settle { !model.isDictating }
            XCTAssertEqual(model.inputText, "")
            XCTAssertFalse(model.prefersTextReplyForDraft)
            XCTAssertFalse(model.isDictating)
            XCTAssertTrue(model.messages.isEmpty)
        }
    }

    func testEmptyAndInterruptedRecognitionLeaveUsableDrafts() async throws {
        await isolated {
            let capture = TestVoiceCapture()
            let model = HomeViewModel(capture: capture)
            model.loadMessages(); model.inputText = "Keep"
            model.handleMicTap(); await settle { model.conversationState == .listening }
            capture.result = "  "
            model.handleMicTap(); await settle { !model.isDictating }
            XCTAssertEqual(model.inputText, "Keep")
            XCTAssertNotNil(model.dictationError)
            model.handleMicTap(); await settle { model.conversationState == .listening }
            capture.text = "these words"
            capture.recording = false // Simulate a recognizer interruption.
            XCTAssertEqual(model.inputText, "Keep these words")
            XCTAssertFalse(model.isDictating)
            XCTAssertEqual(model.conversationState, .idle)
            XCTAssertTrue(model.messages.isEmpty)
        }
    }
}

@MainActor
final class TestVoiceCapture: VoiceCapturing {
    @Published var text = ""
    @Published var recording = false
    var transcriptUpdates: AnyPublisher<String, Never> { $text.eraseToAnyPublisher() }
    var recordingUpdates: AnyPublisher<Bool, Never> { $recording.eraseToAnyPublisher() }
    var currentTranscript: String { text }
    var onUtteranceEnd: (() -> Void)?
    var result: String?
    var denied = false
    var startDelay: Duration = .zero
    var finishDelay: Duration = .zero
    func startRecording() async throws {
        if startDelay != .zero { try await Task.sleep(for: startDelay) }
        try Task.checkCancellation()
        if denied { throw TestCaptureError.denied }
        text = ""; recording = true
    }
    func stopAndTranscribe() async -> String? {
        recording = false
        if finishDelay != .zero { try? await Task.sleep(for: finishDelay) }
        return result
    }
    func stopRecording() { recording = false }
}

private enum TestCaptureError: LocalizedError {
    case denied
    var errorDescription: String? { "Microphone permission was denied." }
}
