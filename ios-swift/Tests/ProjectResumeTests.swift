import XCTest
@testable import Max

@MainActor
final class ProjectResumeTests: XCTestCase {
    private func isolated(_ body: (StorageService) async throws -> Void) async rethrows {
        let store = StorageService.shared
        let previous = store.accountScope
        let scope = "project-resume-" + UUID().uuidString
        store.setAccountScope(scope)
        defer {
            for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("max.account.\(scope).") {
                UserDefaults.standard.removeObject(forKey: key)
            }
            store.setAccountScope(previous)
        }
        try await body(store)
    }

    private func save(_ key: String, _ value: String, project: String, store: StorageService) throws -> String {
        guard case .review(let proposal) = store.resolveFact(key: key, value: value, project: project) else {
            throw NSError(domain: "ProjectResumeTests", code: 1)
        }
        return try XCTUnwrap(store.saveApprovedFact(proposal, value: value))
    }

    func testResumeUsesCurrentScopedFactsAndCitesThem() async throws {
        try await isolated { store in
            let decision = try save("Decision: storage", "PostgreSQL", project: "Project A", store: store)
            XCTAssertTrue(store.updateFact(id: decision, value: "SQLite", accountScope: store.accountScope))
            let action = try save("Next step: migration", "Test migration on a copy.", project: "Project A", store: store)
            _ = try save("Decision: storage", "MySQL", project: "Project B", store: store)
            let answer = try XCTUnwrap(store.projectResumeAnswer(messages: [
                Message(role: "user", content: "What should I try next on Project A?")
            ]))
            XCTAssertTrue(answer.0.contains("SQLite"))
            XCTAssertTrue(answer.0.contains("Test migration on a copy."))
            XCTAssertFalse(answer.0.contains("PostgreSQL"))
            XCTAssertFalse(answer.0.contains("MySQL"))
            XCTAssertEqual(Set(answer.1), Set([decision, action]))
            XCTAssertFalse(answer.0.contains("Suggested next step"))
        }
    }

    func testResumeClarifiesProjectAndHandlesAnExactFollowUp() async throws {
        try await isolated { store in
            _ = try save("Open item: prototype", "Review latency", project: "Project A", store: store)
            _ = try save("Idea: preview", "Build a preview", project: "Project B", store: store)
            let first = Message(role: "user", content: "Where did I stop yesterday?")
            let question = try XCTUnwrap(store.projectResumeAnswer(messages: [first]))
            XCTAssertTrue(question.0.hasPrefix(ProjectResume.clarification))
            XCTAssertTrue(question.1.isEmpty)
            let answer = try XCTUnwrap(store.projectResumeAnswer(messages: [
                first, Message(role: "assistant", content: question.0), Message(role: "user", content: "Project B")
            ]))
            XCTAssertTrue(answer.0.contains("Build a preview"))
            XCTAssertTrue(answer.0.contains("Suggested next step"))
            XCTAssertFalse(answer.0.contains("Review latency"))
            XCTAssertNil(store.projectResumeAnswer(messages: [Message(role: "user", content: "What should I do next to reset my iPhone?")]))
        }
    }

    func testThoughtCaptureMakesAReviewDraftWithoutSavingOrSending() async {
        await isolated { store in
            let capture = TestVoiceCapture()
            let model = HomeViewModel(capture: capture)
            model.loadMessages()
            model.inputText = "Unsent chat"
            model.startThoughtCapture()
            for _ in 0..<100 {
                if model.conversationState == .listening { break }
                try? await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertEqual(model.conversationState, .listening)
            capture.result = "Try the smaller prototype."
            model.handleMicTap()
            for _ in 0..<100 {
                if model.thoughtDraft != nil { break }
                try? await Task.sleep(for: .milliseconds(10))
            }
            XCTAssertEqual(model.thoughtDraft?.text, "Try the smaller prototype.")
            XCTAssertEqual(model.thoughtDraft?.account, store.accountScope)
            XCTAssertEqual(model.inputText, "Unsent chat")
            XCTAssertTrue(model.messages.isEmpty)
            XCTAssertTrue(store.recallFacts().isEmpty)
            model.endConversation()
            XCTAssertNil(model.thoughtDraft)
        }
    }
}
