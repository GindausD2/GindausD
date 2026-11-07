import Foundation
import XCTest
@testable import Max

@MainActor
final class AdvancedMemoryTests: XCTestCase {
    private func isolated(_ body: (StorageService, String) async throws -> Void) async rethrows {
        let store = StorageService.shared
        let previous = store.accountScope
        let scope = "memory-v2-" + UUID().uuidString
        store.setAccountScope(scope)
        defer {
            FactApproval.shared.cancel()
            for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("max.account.\(scope).") {
                UserDefaults.standard.removeObject(forKey: key)
            }
            store.setAccountScope(previous)
        }
        try await body(store, scope)
    }

    private func proposal(_ store: StorageService, key: String = "database", value: String,
                          project: String? = nil, text: String? = nil) throws -> FactProposal {
        guard case .review(let result) = store.resolveFact(key: key, value: value, project: project, userText: text) else {
            throw NSError(domain: "AdvancedMemoryTests", code: 1)
        }
        return result
    }

    func testCorrectionSurvivesStorageReloadAndHistoryIsExplicit() async throws {
        try await isolated { store, _ in
            let original = try proposal(store, value: "PostgreSQL", project: "Project A")
            let id = try XCTUnwrap(store.saveApprovedFact(original, value: original.value))
            let correction = try proposal(store, key: "database engine", value: "SQLite", project: "Project A",
                                          text: "Remember that Project A uses SQLite now.")
            XCTAssertEqual(store.saveApprovedFact(correction, value: correction.value), id)
            let latest = ToolsService.shared.scopedFacts(input: ["key": "database"], userText: "What database does Project A use?")
            XCTAssertTrue(latest.0.contains("SQLite"))
            XCTAssertFalse(latest.0.contains("PostgreSQL"))
            XCTAssertEqual(latest.1, [id])
            XCTAssertTrue(store.answerKnownFact("What does Project A use?")?.0.contains("SQLite") == true)
            XCTAssertFalse(store.answerKnownFact("What does Project A use?")?.0.contains("PostgreSQL") == true)
            let past = ToolsService.shared.scopedFacts(input: ["key": "database"], userText: "What did Project A use before?")
            XCTAssertTrue(past.0.contains("PostgreSQL"))
            XCTAssertTrue(past.0.contains("no longer current"))
        }
    }

    func testProjectAmbiguityAndIsolation() async throws {
        try await isolated { store, scope in
            let a = try proposal(store, value: "PostgreSQL", project: "Project A")
            let b = try proposal(store, value: "MySQL", project: "Project B")
            XCTAssertNotNil(store.saveApprovedFact(a, value: a.value))
            // Re-resolve after a write changed the ledger generation.
            let second = try proposal(store, value: b.value, project: b.project)
            let bid = try XCTUnwrap(store.saveApprovedFact(second, value: second.value))
            guard case .clarify = store.resolveFact(key: "database", value: "SQLite", project: "Project A",
                                                    userText: "My project uses SQLite now") else {
                return XCTFail("An unspoken project must not be guessed")
            }
            let named = try proposal(store, value: "SQLite", project: "Project A", text: "Project A")
            XCTAssertNotNil(store.saveApprovedFact(named, value: named.value))
            XCTAssertEqual(store.recallFacts().first { $0.id == bid }?.value, "MySQL")
            let aOnly = store.memoryLookup(project: "Project B", userText: "What about Project A?")
            XCTAssertEqual(aOnly.map(\.value), ["SQLite"])
            let unrelated = Message(role: "assistant", content: "Project B uses MySQL.")
            let next = Message(role: "user", content: "What should I try next on Project A?")
            XCTAssertEqual(store.chatContext([unrelated, next]).map(\.id), [next.id])
            store.setAccountScope(scope + "-other")
            XCTAssertTrue(store.recallFacts().isEmpty)
            XCTAssertFalse(store.updateFact(id: bid, value: "SQLite", accountScope: scope))
            XCTAssertNil(store.saveApprovedFact(named, value: named.value))
        }
    }

    func testDeleteDropsRetrievalAndInvalidatesOldReviewAndChatContext() async throws {
        try await isolated { store, scope in
            let fact = try proposal(store, key: "work schedule", value: "9 to 5")
            let id = try XCTUnwrap(store.saveApprovedFact(fact, value: fact.value))
            let old = Message(role: "user", content: "Remember that I work 9 to 5")
            let stale = try proposal(store, key: "working hours", value: "10 to 6")
            XCTAssertTrue(store.forgetFact(id: id, accountScope: scope))
            XCTAssertNil(store.saveApprovedFact(stale, value: stale.value))
            XCTAssertFalse(ToolsService.shared.scopedFacts(input: [:], userText: "What are my working hours?").0.contains("9 to 5"))
            let latest = Message(role: "user", content: "What are my working hours?")
            XCTAssertEqual(store.chatContext([old, latest]).map(\.id), [latest.id])
            XCTAssertEqual(old.content, "Remember that I work 9 to 5")
            let unreviewed = await ToolsService.shared.execute(name: "remember_fact", input: ["key": "work schedule", "value": "9 to 5"], accountScope: scope)
            XCTAssertFalse(unreviewed.contains("success"))
            XCTAssertTrue(store.recallFacts().isEmpty)
        }
    }

    func testDeclineAndFailedReviewDoNotConfirmSave() async throws {
        try await isolated { store, scope in
            let pending = Task { await ToolsService.shared.reviewFact(input: ["key": "job", "value": "Designer"],
                                                                      userText: "Remember my job is Designer", accountScope: scope) }
            for _ in 0..<100 {
                if FactApproval.shared.pending != nil { break }
                await Task.yield()
            }
            guard let id = FactApproval.shared.pending?.id else {
                pending.cancel()
                return XCTFail("Expected an editable proposal")
            }
            FactApproval.shared.finish(id: id, value: nil)
            let result = await pending.value
            XCTAssertEqual(result, "That fact wasn’t saved.")
            XCTAssertTrue(store.recallFacts().isEmpty)
            let failed = await ToolsService.shared.reviewFact(input: ["key": "job", "value": "Designer"],
                                                              userText: "Remember my job is Designer", accountScope: "wrong")
            XCTAssertTrue(failed.contains("Nothing was saved"))
        }
    }

    func testLegacyFactsSurviveMigrationAndEdits() async throws {
        try await isolated { store, scope in
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let legacy = UserMemory(key: "Job", value: "Designer", updatedAt: .distantPast)
            UserDefaults.standard.set(try encoder.encode([legacy]), forKey: "max.account.\(scope).max:memories")
            let fact = try XCTUnwrap(store.recallFacts().first)
            XCTAssertTrue(store.updateFact(id: fact.id, value: "Engineer", accountScope: scope))
            XCTAssertEqual(store.recallFacts().first?.value, "Engineer")
            XCTAssertEqual(store.recallFacts().first?.revisions?.first?.value, "Designer")
        }
    }
}
